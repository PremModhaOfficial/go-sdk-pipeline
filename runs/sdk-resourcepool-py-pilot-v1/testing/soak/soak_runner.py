"""Wave T3 soak runner — minimum 600s of continuous acquire/release cycling.

v2 design (after v1 starvation bug): the poller runs on a SEPARATE OS THREAD
so it cannot be starved by the asyncio event loop's worker pressure. The
thread reads the asyncio loop's pool state via ``loop.call_soon_threadsafe``
to a sampler coroutine. Worker tasks throttle themselves with periodic
``await asyncio.sleep(0.001)`` every 1000 cycles to give the timer callbacks
a chance to fire.

Per ``design/perf-budget.md §3 Drift signals (G105 / G106) + MMD``:

- Workload: 32 acquirers continuously cycling against max_size=4 pool.
- Drift signals captured every 30s on a thread-driven cadence:
  ``ops_completed``, ``concurrency_units``, ``outstanding_acquires``,
  ``heap_bytes`` (via tracemalloc), ``gc_count``.
- MMD: 600 seconds.
- Output: JSONL state stream at sibling path ``state.jsonl``; one record per
  poll. Each record carries ``elapsed_s`` so the drift-detector can fit a
  trend.

Status sentinel: writes ``status: running`` initially, ``status: complete``
on graceful end, ``status: error`` on exception.
"""

from __future__ import annotations

import asyncio
import gc
import json
import sys
import threading
import time
import tracemalloc
from pathlib import Path

# Make the SDK src importable when running standalone.
_SDK_SRC = Path("/home/prem-modha/projects/nextgen/motadata-py-sdk/src")
sys.path.insert(0, str(_SDK_SRC))

from motadata_py_sdk.resourcepool import Pool, PoolConfig  # noqa: E402

STATE_FILE = Path(__file__).parent / "state.jsonl"
MMD_SECONDS = 600
POLL_INTERVAL_S = 30
GRACE_AFTER_MMD_S = 10
NUM_ACQUIRERS = 32
MAX_SIZE = 4
THROTTLE_EVERY_N_CYCLES = 1000


def _emit(record: dict[str, object]) -> None:
    with STATE_FILE.open("a") as fh:
        fh.write(json.dumps(record) + "\n")


# Shared state read by the polling thread (asyncio loop writes; thread reads).
_state_lock = threading.Lock()
_shared_state: dict[str, object] = {
    "ops_completed": 0,
    "in_use": 0,
    "idle": 0,
    "waiting": 0,
    "created": 0,
    "closed": False,
}


def _polling_thread(start_ns: int, mmd_s: int, stop_flag: threading.Event) -> None:
    """OS-thread poller — immune to asyncio loop starvation."""
    sample_ix = 0
    while not stop_flag.is_set():
        if stop_flag.wait(timeout=POLL_INTERVAL_S):
            break
        elapsed_s = (time.perf_counter_ns() - start_ns) / 1e9
        traced_now, _peak = tracemalloc.get_traced_memory()
        gc_counts = gc.get_count()
        with _state_lock:
            snap = dict(_shared_state)
        sample_ix += 1
        _emit(
            {
                "ts": time.time(),
                "elapsed_s": elapsed_s,
                "sample_ix": sample_ix,
                "ops_completed": snap["ops_completed"],
                "concurrency_units": int(snap["in_use"]) + int(snap["waiting"]),
                "outstanding_acquires": snap["in_use"],
                "heap_bytes": traced_now,
                "gc_count_gen0": gc_counts[0],
                "gc_count_gen1": gc_counts[1],
                "gc_count_gen2": gc_counts[2],
                "in_use": snap["in_use"],
                "idle": snap["idle"],
                "waiting": snap["waiting"],
                "created": snap["created"],
                "closed": snap["closed"],
                "status": "running",
            },
        )


async def _state_publisher(pool: Pool[int], completed_box: list[int], stop_event: asyncio.Event) -> None:
    """Periodically publish pool stats to the shared dict for the OS-thread poller.

    Runs on the asyncio loop. Updates every 0.5 s — fast enough for 30s polling
    cadence to see fresh-ish data; slow enough to not bottleneck the workers.
    """
    while not stop_event.is_set():
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=0.5)
            break
        except TimeoutError:
            pass
        s = pool.stats()
        with _state_lock:
            _shared_state["ops_completed"] = completed_box[0]
            _shared_state["in_use"] = s.in_use
            _shared_state["idle"] = s.idle
            _shared_state["waiting"] = s.waiting
            _shared_state["created"] = s.created
            _shared_state["closed"] = s.closed


async def _worker(pool: Pool[int], stop_event: asyncio.Event, completed_box: list[int]) -> None:
    """Worker: acquire→release loop with periodic yield to keep timers responsive."""
    ar = pool.acquire_resource
    rl = pool.release
    cycle_count = 0
    while not stop_event.is_set():
        try:
            r = await ar()
            await rl(r)
            completed_box[0] += 1
            cycle_count += 1
            if cycle_count % THROTTLE_EVERY_N_CYCLES == 0:
                # Brief yield to let the publisher / timer callbacks fire.
                await asyncio.sleep(0)
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001
            _emit({"ts": time.time(), "worker_exception": repr(exc)})
            await asyncio.sleep(0.01)


async def main() -> None:
    tracemalloc.start()
    start_ns = time.perf_counter_ns()
    _emit(
        {
            "ts": time.time(),
            "elapsed_s": 0.0,
            "event": "soak_started",
            "status": "running",
            "mmd_seconds": MMD_SECONDS,
            "num_acquirers": NUM_ACQUIRERS,
            "max_size": MAX_SIZE,
            "poll_interval_s": POLL_INTERVAL_S,
            "drift_signals": [
                "ops_completed",
                "concurrency_units",
                "outstanding_acquires",
                "heap_bytes",
                "gc_count_gen0",
            ],
            "harness_version": "v2-thread-poller",
        },
    )

    pool = Pool(PoolConfig[int](max_size=MAX_SIZE, on_create=lambda: 0, name="soak-pool"))
    completed_box = [0]
    stop_event = asyncio.Event()
    thread_stop = threading.Event()

    # Start OS-thread poller BEFORE workers so first 30s sample is timed from t=0.
    poller = threading.Thread(
        target=_polling_thread,
        args=(start_ns, MMD_SECONDS, thread_stop),
        daemon=True,
        name="soak-poller",
    )
    poller.start()

    workers = [
        asyncio.create_task(_worker(pool, stop_event, completed_box))
        for _ in range(NUM_ACQUIRERS)
    ]
    publisher = asyncio.create_task(_state_publisher(pool, completed_box, stop_event))

    try:
        await asyncio.sleep(MMD_SECONDS + GRACE_AFTER_MMD_S)
    finally:
        stop_event.set()
        thread_stop.set()
        for w in workers:
            w.cancel()
        await asyncio.gather(*workers, publisher, return_exceptions=True)
        await pool.aclose(timeout=10.0)
        poller.join(timeout=POLL_INTERVAL_S + 5)

        elapsed_s = (time.perf_counter_ns() - start_ns) / 1e9
        traced_final, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        _emit(
            {
                "ts": time.time(),
                "elapsed_s": elapsed_s,
                "event": "soak_complete",
                "status": "complete",
                "ops_completed": completed_box[0],
                "heap_bytes_final": traced_final,
                "heap_bytes_peak": peak,
            },
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except BaseException as exc:  # noqa: BLE001
        _emit({"ts": time.time(), "status": "error", "error": repr(exc)})
        raise
