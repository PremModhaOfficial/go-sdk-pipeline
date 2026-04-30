<!-- Generated: 2026-04-29T18:03:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-testing-lead -->

# Phase 3 Testing — Summary

## Top-line

**OVERALL VERDICT: PASS-WITH-2-CALIBRATION-WARN + 1-INCOMPLETE-INHERITED + 1-INCOMPLETE-NEW.**

Functional surfaces all green. The CALIBRATION-WARNs surface at H8 (oracle-margin classification on 2 floor-bound symbols). The INCOMPLETEs are tooling-mismatches (G43-py inherited from H7, G32-py new — pytest dev-time CVE), not SUT defects.

| Wave | Verdict | Iter | Notes |
|---|---|---|---|
| **T1** | PASS | 1 | 62/62 PASS, coverage 92.05–92.10% |
| **T3** | PASS | 1 | 28 invocations, 0 flakes (--count=10 isolation clean) |
| **T5** | PASS-WITH-2-CALIBRATION-WARN | 1 | 11/13 benches PASS; 2 INCOMPLETE-by-harness inherited (PA-001/002); G108 CALIBRATION-WARN on `PoolConfig.__init__` (Go-floor-bound) and `AcquiredResource.__aenter__` (8% over decl, within IQR); G107 PASS (slope −0.06, declared O(1)) |
| **T5.5** | PASS | 2 (run-1 sampling defect, run-2 canonical) | G105 PASS (600s = MMD); G106 PASS (all 6 signals static or negative); 131k ops/sec sustained over 16 workers |
| **T6** | PASS | 1 | 15/15 PASS at --count=5; 0 leaks |
| **T7** | SKIP | 0 | not applicable (no parser surface) |
| **T-SUPPLY** | PASS-WITH-DEV-CVE | 1 | runtime deps = []; pytest 8.4.2 has dev-time CVE-2025-71176 (PA-009 → bump to 9.0.3); license re-audit 11/11 allowlist |
| **T-DOCS** | PASS | 1 | 2/2 doctests run cleanly |
| **T-GR** | PASS-WITH-1-INCOMPLETE | 1 | 8/9 PASS, 1 INCOMPLETE-by-tooling-policy on G32-py (same dev-time CVE as T-SUPPLY) |
| **T-DEVIL** | PASS | 1 | 5 review reports consolidated under `reviews/`; 0 BLOCKER, 0 HIGH, 2 CALIBRATION-WARN at G108 |

## Public symbol checklist (TPRD §7) — Phase 3 dynamic

| Symbol | T1 | T5 bench | T5 complexity | T5.5 soak | T6 leak |
|---|---|---|---|---|---|
| Pool.acquire | PASS | PASS (5.94× headroom) | n/a (driver, not target) | PASS (drift signals all PASS) | PASS |
| Pool.acquire_resource | PASS | PASS (5.23× headroom) | covered via scaling sweep | PASS | PASS |
| Pool.try_acquire | PASS | INCOMPLETE-by-harness PA-001 | n/a | n/a (sync) | n/a |
| Pool.release | PASS | PASS (3.92× headroom) | covered | PASS | PASS |
| Pool.aclose | PASS | INCOMPLETE-by-harness PA-002 | n/a | n/a (one-shot) | PASS (idempotent leak test green) |
| Pool.stats | PASS | PASS (3.13× headroom) | n/a (O(1)) | n/a | n/a |
| PoolConfig.__init__ | PASS | CALIBRATION-WARN (Go-floor-bound) | n/a | n/a | n/a |
| AcquiredResource.__aenter__ | PASS | CALIBRATION-WARN (8% over, within IQR) | n/a | n/a | n/a |

## H8 — Performance gate (REQUIRED — calibration-class)

The pipeline classifies G108 CALIBRATION-WARN per the learned pattern (sdk-dragonfly-s2): **measured ≈ language-floor, gap-to-Go-oracle is mechanically unreachable**. H8 is REQUIRED to render the calibration disposition.

H8 ask in plain language:

> Two §7 symbols measured at-or-near the Python language floor; the Go × `margin_multiplier=10` oracle is mechanically unreachable for one (`PoolConfig.__init__`: 2.337µs measured vs Go×10 = 1µs; floor 2µs from frozen+slotted dataclass machinery) and the other is 8% over its own declared budget but within IQR (`AcquiredResource.__aenter__`: 8.664µs vs 8µs declared, IQR 0.615µs).
>
> Both are floor-bound, not wrapper defects. Tightening the implementation cannot move them.
>
> **Choose:**
> 1. **Accept calibration-revision (recommended)** — baseline-manager seeds `baselines/python/performance-baselines.json` using these measurements; perf-architect amends `design/perf-budget.md` to acknowledge Python-floor for `PoolConfig.__init__` (oracle floor revised from 1µs → 2µs as Python-language-floor; declared retained at 3µs) and bumps `AcquiredResource.__aenter__` declared p50 from 8µs → 10µs to leave statistical headroom. PA-013 filed for amendment.
> 2. **Tighten implementation** — likely impossible; would require dropping `@dataclass(frozen=True, slots=True)` (loses immutability semantics) or using `__init__` instead of dataclass (loses type-checker support). Not recommended.
> 3. **Reject** — preserve branch; back to design phase.

Soak/drift PASS so the perf gate's only outstanding item is calibration class.

## H9 — Testing sign-off (REQUIRED — human ask)

Phase 3 is functionally complete and dynamically verified. Three items require user disposition at H9:

> 1. **G108 calibration** — see H8 ask above. Recommended: Option 1 (accept calibration; PA-013).
> 2. **G32-py / pytest CVE-2025-71176** — dev-time-only vulnerability in pytest 8.4.2 (UNIX `/tmp/pytest-of-{user}` predictable path → local DoS). Runtime `dependencies = []` so SDK consumers are not exposed. Fix path: bump dev-extras to pytest >= 9.0.3; revalidate pytest-asyncio compatibility. Recommended: accept INCOMPLETE-on-G32-py for this run with PA-009 in Phase 4 backlog (parallels H7 disposition for G43-py).
> 3. **PA-001 + PA-002 bench-harness gaps** — `Pool.try_acquire` and `Pool.aclose` benches still INCOMPLETE-by-harness (inherited from Phase 2). Both are bench-driver fixes only, not SUT defects. Recommended: keep on Phase 4 backlog.
>
> Other state — all green:
> - 62/62 unit + integration tests PASS, coverage 92.10%
> - 11/13 benches PASS (2 INCOMPLETE-by-harness inherited)
> - G107 PASS (declared O(1) confirmed; slope = −0.0585 across N ∈ {10,100,1k,10k}; max/min ratio 1.527× < 2.0× threshold)
> - G105 PASS (soak elapsed 600s = MMD 600s)
> - G106 PASS (all 6 drift signals static or negative; 131k ops/sec sustained over 16 workers / max_size=4)
> - T6 leak hunt: 15/15 PASS at --count=5; 0 leaks
> - 8/9 mechanical guardrails PASS; 1 INCOMPLETE-on-G32-py (dev-time CVE, item 2 above)
> - 5/5 review-fleet reports green (0 BLOCKER, 0 HIGH, 2 CALIBRATION-WARN at G108)
> - License re-audit: 11/11 dev deps on allowlist
> - Branch preserved at HEAD `11c772c` regardless of choice
>
> **The user must choose:** approve advance to Phase 4 (with PA-009/013 filed), or reject and route back.

## Phase 4 backlog appended this phase

Inherited from Phase 2 (carried forward unchanged): PA-001, PA-002, PA-003, PA-004, PA-005, PA-006

New from Phase 3:
- **PA-007** — modernize `tests/conftest.py` event-loop fixture (DeprecationWarning under pytest-asyncio 0.23+)
- **PA-008** — pip-audit + editable install workflow (resolver chokes on local SDK)
- **PA-009** — bump pytest >= 9.0.3 in dev extras + revalidate pytest-asyncio 0.23.x compat
- **PA-010** — replace `safety check` (deprecated) with `safety scan`
- **PA-011** — promote pool-flavor soak driver into pack-supplied skill (currently bespoke at `runs/.../testing/soak/soak_driver.py`)
- **PA-012** — fix sampler-starvation under hot asyncio worker loops (move sampler to dedicated thread or add cooperative yield)
- **PA-013** — perf-budget.md amendment for `PoolConfig.__init__` Python-floor + `AcquiredResource.__aenter__` declared bump (gated on H8 Option 1 acceptance)

Total Phase 4 backlog at this point: **13 items.**

## Lifecycle

```
Phase 3 Testing: started     2026-04-29T17:00:05Z
                 unit-pass    2026-04-29T17:01:00Z
                 integration  2026-04-29T17:01:30Z
                 bench+complexity 2026-04-29T17:08:00Z
                 leak         2026-04-29T17:11:30Z
                 supply       2026-04-29T17:13:00Z
                 docs+gr      2026-04-29T17:14:30Z
                 soak-run-1   2026-04-29T17:00–17:10
                 soak-run-2   2026-04-29T17:20–17:30
                 completed    2026-04-29T18:03:00Z
                 status       awaiting-H8 + H9
```

## Pointers

- `runs/.../testing/unit-results.md`
- `runs/.../testing/integration-results.md`
- `runs/.../testing/bench-results.md` + `bench-results.json`
- `runs/.../testing/soak-results.md` + `drift-analysis.md`
- `runs/.../testing/leak-results.md`
- `runs/.../testing/fuzz-results.md`
- `runs/.../testing/supply-chain-results.md`
- `runs/.../testing/doctest-results.md`
- `runs/.../testing/guardrail-results.md` + `guardrail-report.json`
- `runs/.../testing/baselines-summary.md`
- `runs/.../testing/reviews/{sdk-benchmark-devil-python,sdk-complexity-devil-python,sdk-asyncio-leak-hunter-python,sdk-integration-flake-hunter-python,sdk-soak-runner-python,sdk-drift-detector}.md`
- `runs/.../testing/soak/soak_driver.py` + `state.jsonl` + `state.run1.jsonl`

Branch unchanged at HEAD `11c772c` on `sdk-pipeline/sdk-resourcepool-py-pilot-v1` (read-only from Phase 3 POV per Rule 17).
