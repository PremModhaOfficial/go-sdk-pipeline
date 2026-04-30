"""Profile driver — repeated acquire/release cycle for py-spy + scalene profiling.

Used by sdk-profile-auditor-python at M3.5 (re-run with venv) to verify:
    G109 — top-10 CPU samples cover declared hot paths
    G104 — heap_bytes_per_call <= declared budget

Lives in runs/<run-id>/impl/profiling/ rather than tests/perf/ to avoid
polluting the production tree with pipeline-only tooling.

Run:
    PYTHONPATH=motadata-sdk/src .venv/bin/py-spy record -o /tmp/profile.svg \\
        --rate 250 --duration 8 \\
        -- .venv/bin/python <thispath>
"""

from __future__ import annotations

import asyncio
import sys
import tracemalloc

from motadata_py_sdk.resourcepool import Pool, PoolConfig


async def factory() -> int:
    return 42


async def main(iterations: int = 200_000) -> None:
    pool = Pool(PoolConfig[int](max_size=4, on_create=factory))
    # Pre-warm: one resource sits idle.
    r = await pool.acquire_resource()
    await pool.release(r)

    tracemalloc.start()
    snap_before = tracemalloc.take_snapshot()

    # Hot loop: idle-fast-path acquire+release.
    for _ in range(iterations):
        async with pool.acquire(timeout=1.0):
            pass

    snap_after = tracemalloc.take_snapshot()
    diff = snap_after.compare_to(snap_before, "lineno")
    total = sum(stat.size_diff for stat in diff)
    per_call = total / iterations
    print(f"iterations={iterations} total_size_diff_bytes={total} heap_bytes_per_call={per_call:.1f}")

    await pool.aclose()
    tracemalloc.stop()


if __name__ == "__main__":
    iters = int(sys.argv[1]) if len(sys.argv) > 1 else 200_000
    asyncio.run(main(iters))
