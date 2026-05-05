<!-- Generated: 2026-04-23T15:36:00Z | Run: sdk-dragonfly-p1-v1 -->
# Pipeline-tooling findings (Phase 3 T5)

Surfaced during this run but belong to `motadata-sdk-pipeline` infrastructure, not the SDK code. Filed for a future pipeline revision.

## G107 — exponent-cap regex ordering bug

**Where:** `scripts/guardrails/G107.sh` → `declared_exponent_cap(bigo)` function.

**Bug:** The regex ladder checks `\bo\(\s*log` BEFORE the more-specific `\bo\(\s*log\s*n\s*\+\s*m\s*\)`. So a declaration of `O(log N + M)` matches the generic `O(log …)` branch and gets cap=0.25 (plain log-N), instead of 1.25 (the correct cap for log N + M).

```python
# Current (buggy):
if re.search(r'\bo\(\s*1\s*\)', b):                       return 0.10
if re.search(r'\bo\(\s*log', b):                          return 0.25  # ← eats "O(log N + M)"
if re.search(r'\bo\(\s*n\s*log\s*n\s*\)', b):             return 1.25
if re.search(r'\bo\(\s*(n|m)\s*\)', b):                   return 1.10
if re.search(r'\bo\(\s*log\s*n\s*\+\s*m\s*\)', b):        return 1.25  # never reached
```

**Fix:** Reorder so the `log n + m` check precedes the bare `log` check.

**This-run workaround:** declared the ZRangeWithScores complexity as `O(M)` — accurate (M dominates in the bench-swept range) and matches the `(n|m)` branch with cap 1.10, which accommodates the measured exponent 0.79.

**Impact if unfixed:** any future TPRD that correctly declares `O(log N + M)` complexity will mis-FAIL G107 unless the author knows the workaround.

## G60/G63 — target-wide scope

**Where:** `scripts/guardrails/G60.sh` and `G63.sh` run `go test ./...` against `$TARGET` rooted at the whole SDK module directory, so they hit pre-existing failures or long-running tests in other SDK packages (events/, config/, etc.) unrelated to the pipeline's current target package.

**This-run workaround:** manually scoped `go test` to `./core/l2cache/dragonfly/...` for a clean race+leak verdict.

**Suggested fix:** accept an optional `$TARGET_PKG` arg and scope the `go test` invocation when present.

## G98 / G99 — target-wide traces-to scan

**Where:** `scripts/guardrails/G98.sh` and `G99.sh` walk every .go file under `$TARGET` looking for `[traces-to:]` markers. The SDK's `events/`, `config/`, `otel/` packages predate marker requirements and surface 68+988 findings that belong to a different backlog.

**This-run workaround:** noted in run-summary.md as "target-wide pre-existing findings, out of P1 scope."

**Suggested fix:** gate on the pipeline's current target package (like G60/G63), and/or accept a `--path-prefix` filter.

## G40 / G48 — same target-wide scope issue

G40 (godoc on exported symbols) and G48 (no TODO / ErrNotImplemented) scan whole SDK. Same suggested fix.
