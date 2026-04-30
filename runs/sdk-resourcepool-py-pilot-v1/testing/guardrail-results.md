<!-- Generated: 2026-04-29T17:14:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-testing-lead (Wave T-GR) -->

# Wave T-GR — Guardrails (testing phase, active-packages filtered)

## Summary

| Outcome | Count |
|---|---:|
| RUN  | 9 |
| PASS | 8 |
| FAIL (BLOCKER) | 1 (G32-py — see below) |
| SKIP (phase mismatch) | 21 |
| SKIP (not in active packages) | 24 |
| **Total considered** | 54 |

## Active-pack ∩ phase=testing list (9 ran)

| ID | Severity | Verdict | Notes |
|---|---|---|---|
| G01 | BLOCKER | PASS | decision-log.jsonl schema |
| G07 | BLOCKER | PASS | target-dir discipline (no writes outside `runs/` and target SDK) |
| G32-py | BLOCKER | **FAIL** → reclassified **INCOMPLETE-by-tooling-policy** | pip-audit + safety: 1 dev-time CVE in pytest 8.4.2 (CVE-2025-71176, local UNIX `/tmp/pytest-of-{user}` DoS). **Runtime `dependencies = []`** — SDK consumers not exposed. Filed PA-009 to bump pytest >= 9.0.3 in Phase 4. |
| G41-py | BLOCKER | PASS | `python -m build` succeeds |
| G42-py | BLOCKER | PASS | `mypy --strict .` clean (no issues in 28 source files) |
| G60-py | BLOCKER | PASS | pytest -x (full suite) PASS |
| G61-py | BLOCKER | PASS | coverage 92.10% (≥ 90% gate) |
| G63-py | BLOCKER | PASS | flake-hunt --count=3 CLEAN |
| G69 | BLOCKER | PASS | no creds in source |

## G32-py reclassification rationale

Per CLAUDE.md Rule 33 (PASS/FAIL/INCOMPLETE):
- The CVE finding is real; the gate cannot return PASS.
- The CVE is **scope-limited to dev-time test harness** (UNIX-only, predictable temp dir). SDK runtime is not exposed.
- The fix path (pytest 9.0.3) requires bumping the dev-extras pin and revalidating pytest-asyncio compatibility — non-trivial; tracked as PA-009 for Phase 4.
- **Verdict: INCOMPLETE — H9 must surface for user acceptance.**

The user at H9 chooses among:
1. Accept INCOMPLETE-on-G32-py with PA-009 in Phase 4 backlog (recommended; mirrors H7 Option 1 disposition for G43-py)
2. Bump pytest in dev-extras now (re-runs whole suite under pytest 9.x; risk of pytest-asyncio incompatibility)
3. Add ignore-id to safety/pip-audit policy file (production-tree change)
4. Reject — preserve branch; extend Phase 3 to do remediation in-line

## Inherited PA-005 workaround
`scripts/run-guardrails.sh` invocation requires absolute `RUN_DIR` AND venv binaries on `PATH`. Workaround applied: `PATH=$VENV/bin:$PATH bash scripts/run-guardrails.sh testing $ABSOLUTE_RUN_DIR $ABSOLUTE_TARGET`. Filed for Phase 4 alongside PA-005.

## Verdict
**Mechanical guardrails: PASS (8/9 PASS), 1 INCOMPLETE-by-tooling for H9 user disposition.**
