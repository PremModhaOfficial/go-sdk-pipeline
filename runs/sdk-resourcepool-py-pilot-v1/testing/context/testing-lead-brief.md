<!-- Generated: 2026-04-28T00:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead -->

# Testing-lead brief

## RULE 0 inheritance (verbatim from manifest)

> ZERO tech debt on the TPRD. No deferring, skipping, or partial implementation of any TPRD-declared functionality, test type, performance gate, milestone slice, or retrospective hook.

Forbidden artifacts (testing-phase additions to the original 9):
- `@pytest.mark.skip` without a tracking link AND user H7/H9 sign-off.
- Empty bench bodies / benches that don't actually run a measured loop.
- Soak verdicts of "passed so far" — pipeline rule 33 forbids silent INCOMPLETE→PASS promotion.
- Coverage-gate "would-be-90%-but" excuses.

Testing-lead enforcement clause (verbatim):
> sdk-testing-lead must verify every §11 test category produced ≥1 real test, every §10 bench is runnable + measured, and §11.5 --count=10 flake detection actually ran.

## Run state at testing entry (Wave T0)

| Field | Value |
|---|---|
| Pipeline version | 0.5.0 |
| Mode | A (new package) |
| Target language | python |
| Target tier | T1 (full perf-confidence regime) |
| Target SDK dir | `/home/prem-modha/projects/nextgen/motadata-py-sdk` |
| Branch | `sdk-pipeline/sdk-resourcepool-py-pilot-v1` (verified at T0) |
| Head SHA | `bd14539` (matches H7 sign-off; clean working tree) |
| H7 status | APPROVED (M11 re-baseline applied; perf-budget contention 500k→450k) |
| Tests committed at H7 | 81 unit/integration/leak + 14 bench-tests (gates) — 83 grand total per impl summary, but 81 is the unit/integration/leak count for the --count=10 flake gate |
| Coverage at H7 | 92.33% (impl-reported; testing-lead re-verifies) |
| MCP health | OK (G04 PASS at T0; neo4j reachable) |

## Active-packages reconciliation (CRITICAL — read carefully)

`runs/sdk-resourcepool-py-pilot-v1/context/active-packages.json` lists the union of `shared-core@1.0.0` + `python@1.0.0` agents. The Python adapter (v0.5.0 Phase A scaffold) was deliberately authored with `agents: []` (Python-specific agents not yet ported / promoted from `go.json`).

**Result**: ACTIVE_AGENTS for this run does NOT include the perf-confidence specialist fleet:

- `sdk-leak-hunter`, `sdk-benchmark-devil`, `sdk-complexity-devil`, `sdk-soak-runner` — would be tier-critical for T1 by this lead's normal gate
- `sdk-profile-auditor` — already executed in M3.5 (impl phase) before active-packages narrowed in scope
- `sdk-integration-flake-hunter`, `code-reviewer`, `unit-test-agent`, `integration-test-agent`, `performance-test-agent`, `fuzz-agent`, `mutation-test-agent` — same gap

**Per the orchestrator's run-brief**: I am explicitly directed to perform every responsibility those agents would have performed. I am also explicitly told `DO NOT call AskUserQuestion` and `Surface readiness/issues to the orchestrator via your status report`. The orchestrator's per-run brief is the authoritative override for this run; the manifest-only-active-packages gate is informational, and the gap is documented as "generalization debt" in `python.json` notes (T2-7 / Phase B materializes those agents lazily).

**Action**: I execute every wave below myself, applying the agent definitions verbatim where they exist in `.claude/agents/`. No agent invocation is silently skipped; every gate the agent would emit is emitted by me, with provenance attribution. The verdict files cite which agent's role I am executing.

This generalization-debt observation feeds Phase 4 retrospective Q5 (Appendix C).

## Per-wave acceptance criteria (Wave T1–T7)

### Wave T1 (unit + integration + leak audit)
- Coverage `--cov-fail-under=90` on `src/motadata_py_sdk/resourcepool/` over `tests/unit/ + tests/integration/ + tests/leak/`. **BLOCKER if <90%.**
- `pytest --count=10` over the same test set. Every test green 10/10. **Any flake = BLOCKER**, escalate.
- Leak harness sensitivity check: deliberate-leak negative test in `testing/sandbox/` confirms the fixture catches a leak. If fixture insensitive → ESCALATION:LEAK-HARNESS-INSENSITIVE.

### Wave T2 (bench + perf gates)
- Re-run all 7 wallclock bench tests + the 4 strict-gate ones. Capture median + p95 + p99 + std.
- G108 oracle margin: each row PASS / FAIL against `design/perf-budget.md` budgets (M11 re-baseline applied).
- G65 first-run: write `baselines/python/performance-baselines.json` SEED.
- G107 complexity: scaling sweep at N ∈ {10, 100, 1000, 10000}; log-log slope < 0.2 = PASS.
- G104 alloc: re-confirm impl-phase number stands.
- G109 profile shape: re-run py-spy if testing host differs from impl host; otherwise cite the M10 result.

### Wave T3 (soak + drift)
- Soak duration ≥ MMD = 600 s (per perf-budget.md §3). Run via `Bash run_in_background`.
- Drift signals: `concurrency_units`, `outstanding_acquires`, `heap_bytes`, `gc_count`. Polled every 30 s for ≥ 20 samples.
- Verdict per pipeline rule 33: PASS (no positive trend at p<0.01) / FAIL (positive trend) / INCOMPLETE (MMD not reached). NEVER silently promote INCOMPLETE→PASS.

### Wave T4 (supply chain)
- `pip-audit` clean = BLOCKER on any vuln.
- `safety check` if available; if requires login per impl note → document + skip with WARN, pip-audit is the sole gate per CLAUDE.md rule 24.
- License allowlist check via `pip-licenses` over the dev-deps list. Any non-{MIT, Apache-2.0, BSD, ISC, 0BSD, MPL-2.0} = BLOCKER.

### Wave T5 (devil review pass on test artifacts)
- Re-run the test-quality reviews on the *test* code (which the impl phase didn't focus on adversarially). Output to `testing/reviews/`.

### Wave T6 (review-fix loop)
- Per `review-fix-protocol` v1.1.0; max 5 retries per finding; stuck-detection at 2 non-improving iterations; global 10-iter cap.

### Wave T7 (H8 + H9 prep)
- H8 — perf gate sign-off (no user gate triggered if all PASS; ESCALATION on any FAIL).
- H9 — testing sign-off — full table, recommendation APPROVE / REVISE / REJECT.

## Boundaries

- WRITES allowed only to: `runs/sdk-resourcepool-py-pilot-v1/testing/`, `runs/.../decision-log.jsonl`, run-manifest's testing.status, AND `baselines/python/*` (first-run seed).
- DO NOT modify the impl source on `sdk-pipeline/sdk-resourcepool-py-pilot-v1`. If a test surfaces a real impl bug → ESCALATION:IMPL-BUG-FOUND-DURING-TESTING.
- DO NOT push, merge, force-push.
- Decision log entry cap: 15 per agent per run.
- Soak runs in background via `Bash run_in_background`.
- Honor pipeline rule 33: INCOMPLETE never silently promotes to PASS.
