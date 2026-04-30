<!-- Generated: 2026-04-29T15:15:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-impl-lead-toolchain-rerun (M3.5-RERUN) -->
<!-- Replaces prior surrogate INCOMPLETE-by-toolchain report -->

# sdk-profile-auditor-python — Wave M3.5 (live toolchain)

## Verdict

**MIXED**:
- **G104 (alloc budget)** — PASS for 6 of 8 §7 symbols; INCOMPLETE-by-harness for `try_acquire` and `aclose` (PA-001, PA-002).
- **G109 (profile-shape no-surprise)** — substantive PASS (no surprise hotspots, design's hot path is the measured hot path); literal coverage threshold INCOMPLETE because perf-budget.md declared stub symbols (PA-003).

Full report: `runs/.../impl/profile-audit.md`.

## Headline numbers

- Idle fast-path acquire+release: median **8.36 µs/round** (declared budget 50 µs → **6.0× headroom**).
- Steady-state heap delta: **0.0 B/call** (declared 1024 B → **PASS**).
- Top-15 CPU samples are entirely in `resourcepool/_pool.py`, `resourcepool/_acquired.py`, and `asyncio/locks.py`. **No surprise hotspots.**

## What needs fixing (Phase 4 backlog)

PA-001-MEDIUM, PA-002-MEDIUM, PA-003-MEDIUM — all are M1/D1 design+harness gaps surfaced by live profiling, NOT production-code defects. Phase 2 cannot rework M1 per orchestrator brief; surfaced for `improvement-planner` in Phase 4.

## Tooling provenance

py-spy 0.4.2 (1497–1998 samples per pass), scalene 2.2.1 full pass, pytest-benchmark 4.0.0 (11 of 13 benches green). Driver at `runs/.../impl/profiling/profile_driver.py`.
