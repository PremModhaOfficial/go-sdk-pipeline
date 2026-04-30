<!-- Generated: 2026-04-29T18:04:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-testing-lead -->

# sdk-testing-lead — Phase 3 context summary (handoff to Phase 4)

## Branch state
- Branch: `sdk-pipeline/sdk-resourcepool-py-pilot-v1` HEAD `11c772c`
- No commits made by Phase 3 (Rule 17 + Rule 21 — read-only branch)

## Top-line verdict
PASS-WITH-2-CALIBRATION-WARN + 1-INCOMPLETE-INHERITED + 1-INCOMPLETE-NEW. H8 + H9 REQUIRED.

## Wave outcomes
- T1: 62/62 PASS, coverage 92.10%
- T3: integration 2/2; flake hunt --count=10 CLEAN
- T5: 11/13 benches PASS; 2 inherited INCOMPLETE; G108 CALIBRATION-WARN ×2 (PoolConfig.__init__ floor-bound, AcquiredResource.__aenter__ within-IQR); G107 PASS
- T5.5: G105 PASS (600s = MMD), G106 PASS (all 6 signals static/negative); 131k ops/sec sustained
- T6: 15/15 PASS at --count=5; 0 leaks
- T7: SKIP-not-applicable
- T-SUPPLY: PASS-WITH-DEV-CVE; 0 runtime deps
- T-DOCS: 2/2
- T-GR: 8/9 PASS, 1 INCOMPLETE on G32-py (dev-time CVE)

## Baselines status (Phase 4 input)
- `baselines/python/performance-baselines.json` — does NOT exist; Phase 4 baseline-manager seeds from `bench-results.json`
- `baselines/python/coverage-baselines.json` — seeds at 92.10%
- `baselines/python/output-shape-history.jsonl` — seeds (first SHA)
- `baselines/python/devil-verdict-history.jsonl` — seeds (first run)
- Shared baselines (`baselines/shared/`) — append run-meta; D2=Lenient (no cross-language regression gate fires)

## H8 disposition required
G108 CALIBRATION-WARN on 2 symbols. Recommended: Option 1 (accept-with-calibration; perf-budget.md amendment via PA-013).

## H9 disposition required
3 items: G108 calibration (above), G32-py dev-time CVE (PA-009), PA-001/002 bench-harness gaps (carried).

## Phase 4 backlog (13 items)
PA-001 through PA-006 inherited; PA-007 through PA-013 added in Phase 3 (see `phase-summary.md` § Phase 4 backlog).

## Risks for Phase 4
- `improvement-planner` will need to scope-classify PA-009 (dev-extras pin bump cascading to ASYNC109 + UP046 churn from a newer ruff — see H7 Option 3 commentary).
- `learning-engine` should inspect this run's CALIBRATION-WARN classification rate for `python` adapter relative to `go` history; D2=Lenient means no BLOCKER, but a high calibration-miss rate on first-Python run is worth a `skill-evolution` note for `python-perf-architect-python` (consider documenting Python-floor heuristics).

## Decision-log entries authored: 11 (well under 15 cap)
