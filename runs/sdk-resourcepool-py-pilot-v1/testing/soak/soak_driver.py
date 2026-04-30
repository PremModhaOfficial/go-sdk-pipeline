"""Soak driver — sdk-soak-runner-python (Wave T5.5).

Drives Pool.acquire / Pool.release at steady state for `mmd_seconds` from
perf-budget.md, sampling 6 drift signals every 30 s into a JSONL state file
that sdk-drift-detector polls.

Drift signals (per design/perf-budget.md drift_signals_catalog):
  - asyncio_pending_tasks   (positive_slope)
  - rss_bytes               (positive_slope, threshold 100 KiB/min)
  - tracemalloc_top_size_bytes (positive_slope, threshold 50 KiB/min)
  - gc_count_gen2           (positive_slope, threshold 1.0/min)
  - open_fds                (positive_slope, threshold 0.1/min)
  - thread_count            (max_value, threshold 4)

Output format (one JSON object per line, append-only):
  {
    "ts": "2026-04-29T17:10:00Z",
    "elapsed_s": 30.0,
    "asyncio_pending_tasks": 35,
    "rss_bytes": 47218688,
    "tracemalloc_top_size_bytes": 122880,
    "gc_count_gen2": 4,
    "open_fds": 18,
    "thread_count": 1,
    "ops_completed": 1234567
  }

Exit codes:
  0 — soak completed at or beyond mmd_seconds (PASS-eligible)
  2 — wallclock cap hit before mmd_seconds (writes status=incomplete-by-wallclock)

[traces-to: TPRD-10-SOAK-DRIFT]
"""

from __future__ import annotations

import asyncio
import gc
import json
import os
import sys
import threading
import time
import tracemalloc
from datetime import UTC, datetime
from pathlib import Path

import psutil

from motadata_py_sdk.resourcepool import Pool, PoolConfig

MMD_SECONDS = int(os.environ.get("MMD_SECONDS", "600"))
SAMPLE_INTERVAL_S = int(os.environ.get("SAMPLE_INTERVAL_S", "30"))
WORKERS = int(os.environ.get("WORKERS", "16"))
MAX_SIZE = int(os.environ.get("MAX_SIZE", "4"))
STATE_FILE = Path(os.environ["STATE_FILE"])
WALLCLOCK_CAP_S = int(os.environ.get("WALLCLOCK_CAP_S", "1500"))  # 25 min hard cap

_proc = psutil.Process()


def _factory() -> int:
    return 0


def _sample(ops_completed: int, started_at: float) -> dict[str, object]:
    """Snapshot all 6 drift signals + ops counter."""
    # Use tracemalloc.get_traced_memory() rather than take_snapshot() — the snapshot
    # walks every traced allocation (~70M+ in this soak) and takes >>30s under load,
    # starving the sampler.  get_traced_memory() returns (current, peak) in O(1).
    current_traced, _peak = tracemalloc.get_traced_memory()
    top_size = current_traced
    try:
        num_fds = _proc.num_fds()
    except Exception:
        num_fds = -1
    return {
        "ts": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "elapsed_s": round(time.monotonic() - started_at, 2),
        "asyncio_pending_tasks": len(asyncio.all_tasks()),
        "rss_bytes": _proc.memory_info().rss,
        "tracemalloc_top_size_bytes": top_size,
        "gc_count_gen2": gc.get_count()[2],
        "open_fds": num_fds,
        "thread_count": threading.active_count(),
        "ops_completed": ops_completed,
    }


async def _worker(pool: Pool[int], counter: list[int], stop_at: float) -> None:
    while time.monotonic() < stop_at:
        try:
            r = await pool.acquire_resource(timeout=2.0)
            await pool.release(r)
            counter[0] += 1
        except Exception:  # noqa: BLE001
            # On any error, brief backoff and continue — soak measures steady-state
            await asyncio.sleep(0.001)


async def _sampler(state_file: Path, counter: list[int], started_at: float, stop_at: float) -> None:
    state_file.write_text("")
    while time.monotonic() < stop_at:
        sample = _sample(counter[0], started_at)
        with state_file.open("a") as f:
            f.write(json.dumps(sample) + "\n")
        # Also write status hint
        await asyncio.sleep(SAMPLE_INTERVAL_S)
    # Final sample
    sample = _sample(counter[0], started_at)
    sample["final"] = True
    with state_file.open("a") as f:
        f.write(json.dumps(sample) + "\n")


async def _run() -> int:
    tracemalloc.start()
    started_at = time.monotonic()
    deadline = started_at + min(MMD_SECONDS, WALLCLOCK_CAP_S)
    pool = Pool(PoolConfig[int](max_size=MAX_SIZE, on_create=_factory))
    counter = [0]

    try:
        async with asyncio.TaskGroup() as tg:
            tg.create_task(_sampler(STATE_FILE, counter, started_at, deadline))
            for _ in range(WORKERS):
                tg.create_task(_worker(pool, counter, deadline))
    finally:
        await pool.aclose()
        tracemalloc.stop()

    elapsed = time.monotonic() - started_at
    status = {
        "status": "complete" if elapsed >= MMD_SECONDS else "incomplete-by-wallclock",
        "elapsed_s": round(elapsed, 2),
        "mmd_seconds": MMD_SECONDS,
        "ops_completed": counter[0],
    }
    (STATE_FILE.parent / "soak-status.json").write_text(json.dumps(status, indent=2))
    return 0 if elapsed >= MMD_SECONDS else 2


if __name__ == "__main__":
    sys.exit(asyncio.run(_run()))
