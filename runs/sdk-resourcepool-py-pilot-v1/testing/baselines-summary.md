<!-- Generated: 2026-04-29T17:15:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-testing-lead -->

# Baselines summary — first Python run

Per CLAUDE.md Rule 28 (D1=B partitioning) and `runs/.../context/active-packages.json:notes` ("First Python pilot. baselines/python/ is empty — first-run baselines SEED, not compare").

## Per-language baselines (`baselines/python/`) — SEED MODE

| File | Status | Action at Phase 4 |
|---|---|---|
| `baselines/python/performance-baselines.json` | **SEEDS** (does not exist yet) | `baseline-manager` will populate from 11 measured benches in `testing/bench-results.json` |
| `baselines/python/coverage-baselines.json` | **SEEDS** | populates with 92.10% measured |
| `baselines/python/output-shape-history.jsonl` | **SEEDS** | first SHA256 of sorted exported-symbol signatures |
| `baselines/python/devil-verdict-history.jsonl` | **SEEDS** | first run record |

**Regression gates** (G65, G86 at Phase 4) **NO-FIRE** — ≥3-prior-runs precondition unmet for the python pack.

## Shared baselines (`baselines/shared/`) — COMPARE MODE (lenient cross-language D2)

| File | Status |
|---|---|
| `baselines/shared/quality.json` | compares against existing Go-run history per Decision D2 (Lenient) |
| `baselines/shared/skill-health.json` | compares against existing Go-run history |
| `baselines/shared/baseline-history.jsonl` | append-mode (run-meta history shared) |

D2=Lenient cross-language baseline: "is `sdk-design-devil`'s quality_score systematically lower in Python runs?" is **explicitly NOT a v0.5.0 goal**; each adapter compares against its own language's history. The shared baselines record this run for future cross-language analysis but do not BLOCKER on cross-language drift.

## Counts

- Files SEEDED (per-language): **4**
- Files COMPARED (shared): **3**
- Total baseline files touched at Phase 4: **7**

## Phase 4 dispatch

`baseline-manager` (`F7_baselines` wave) reads `runs/.../testing/{bench-results.json,unit-results.md,reviews/}` and seeds the 4 per-language files. The first commit message should clearly mark seeding versus comparing. No regression verdicts fire on this run.
