<!-- Generated: 2026-04-18T07:15:00Z | Run: sdk-dragonfly-s2 -->
# D4 iteration 1 — devil re-run

Per rule #13 (post-iteration review re-run). All 5 devils re-consulted against the updated design artifacts.

Changes applied in iteration 1:
- `concurrency.md` §G1 — added bounded `stopTimeout = 5s` + Warn log on timeout. Addresses F-D3.
- `patterns.md` §P5a (new subsection) — explicit credential-rotation Dialer re-read contract + godoc rule for `WithPassword` vs `LoadCredsFromEnv`. Addresses S-9.

## Re-verdicts

| Devil | Iter-0 | Iter-1 | Notes |
|---|---|---|---|
| sdk-design-devil | NEEDS-FIX (F-D3) | **ACCEPT** | F-D3 fix is clean: bounded wait + Warn + acceptable goleak signal if OTLP truly hung. No regression introduced. F-D1/D4/D5/D6/D7/D8 remain ACCEPT or ACCEPT-WITH-NOTE (unchanged). |
| sdk-dep-vet-devil | CONDITIONAL | **CONDITIONAL** (unchanged) | No dep changes in iter-1. govulncheck/osv-scanner remain PENDING; still routes to H6. |
| sdk-semver-devil | ACCEPT minor | **ACCEPT minor** (unchanged) | No signature changes. |
| sdk-convention-devil | ACCEPT | **ACCEPT** (unchanged) | Iter-1 edits are inside existing design docs; no new convention drift. Bounded-wait pattern matches `events/` drain-timeout convention (ConnectionConfig.DrainTimeout default 30s). |
| sdk-security-devil | NEEDS-FIX (S-9) | **ACCEPT** | P5a new subsection specifies the Dialer re-read contract + documents that `WithPassword(static)` does NOT rotate. S-1 through S-8 and S-10 remain ACCEPT or ACCEPT-WITH-NOTE (unchanged). |

## Aggregate iter-1 verdict

**All 5 devils ACCEPT (or CONDITIONAL for dep-vet pending H6).**

Review-fix iteration count: **1** (below 10-iter cap, no stuck-detection triggered).

No further fix batch needed. Proceed to D5 HITL gates.
