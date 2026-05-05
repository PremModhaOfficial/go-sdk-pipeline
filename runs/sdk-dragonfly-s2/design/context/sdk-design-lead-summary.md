<!-- Generated: 2026-04-18T07:20:00Z | Run: sdk-dragonfly-s2 -->
# sdk-design-lead — Phase 1 Context Summary

For downstream (`sdk-impl-lead`). Self-contained.

## Design complete — status

- All 5 D1 agents' artifacts produced and context-summarized.
- D2 guardrail-validator: 4 PASS, 2 PENDING (G32/G33 tool-install).
- D3 devils: 2 NEEDS-FIX (F-D3, S-9) + 1 CONDITIONAL (dep-vet → H6).
- D4 iter-1: both NEEDS-FIX resolved. Devil re-run: all ACCEPT.
- D5: design-summary.md + H5-summary.md authored.

## The 93-symbol API surface

Matches intake/mode.json `new_exports` enumeration exactly:
- 4 types (`Cache`, `Config`, `Option`, `TLSConfig`)
- 2 package funcs (`New`, `LoadCredsFromEnv`)
- 15 `With*` options (+ internal `WithPoolStatsInterval` advisory)
- 46 receiver methods on `*Cache` (2 lifecycle + 19 string + 13 hash + 3 pipeline + 3 pubsub + 4 script + 2 raw)
- 26 `Err*` sentinels

## Must-preserve contracts for Phase 2 impl

1. **Signature freeze** — `api.go.stub` is authoritative. Any impl deviation requires design re-opening.
2. **G42** — every data-path method has `ctx context.Context` first (already in stub).
3. **G43** — impl must add `var _ io.Closer = (*Cache)(nil)` + `var _ stopper = (*poolStatsScraper)(nil)`.
4. **G98/G99** — every exported symbol keeps its `[traces-to: TPRD-§<n>-<id>]` marker; every .go file has a top-of-file `[traces-to: TPRD-§<n>]` marker.
5. **G97** — hot-path constraints on `Get`, `Set`, `HExpire`, `EvalSha` already embedded in stub godocs (`[constraint: … | bench/BenchmarkX]`).
6. **Shutdown ordering** — `(*Cache).Close()` stops scraper (bounded 5s wait) BEFORE `rdb.Close()`.
7. **Credential rotation** — Dialer closure re-reads password file on every dial when `LoadCredsFromEnv` was used. `WithPassword(static)` path documented as non-rotating.
8. **`mapErr` rule 0a** — `errors.Is(err, redis.TxFailedErr)` → `ErrTxnAborted` BEFORE default.
9. **`classify`** — bounded 6-value label set; never user-input.
10. **Scraper uses `context.Background()`** — not inherited from caller.
11. **`sync.Once` for metrics init** — no `init()` functions (G41).
12. **PubSub caller-owned `ps.Close()`** — godoc loud.
13. **`Cache.Client()` godoc warns** about instrumentation bypass.
14. **`Config.validate()`** enforces: `Addr != ""`, `TLS.ServerName != "" unless SkipVerify`, `PoolStatsInterval >= minPoolStatsInterval (1s)`, `MaxRetries != 0 → Warn log in New()`.

## Deferred-to-H6 items

- G32 govulncheck against full go.mod (with testcontainers + goleak added).
- G33 osv-scanner against full go.mod.
- Phase 2 re-runs both after `go mod tidy`.

## Deviation acknowledgment

Dragonfly introduces **functional `With*` options** — a first in target SDK. `Config` struct still exported. Justified by TPRD §6 directive. Phase 4 feedback candidate: cross-SDK design-standards doc to codify when each constructor style applies.

## Decision-log entries written by this lead

- seq 13 (D1 dispatch), 14 (D1 complete), 15 (D2 complete), 16 (D3 complete), 17 (D4 iter-1 refactor), 18 (D4 rerun all-accept).
- Plus: 19, 20 planned for H5 + phase-complete.

6-8 lead entries total, within ≤15 cap.

## Sub-agent entries (proxied through lead, tagged with owning agent)

- sdk-designer: seq 20, 21
- interface-designer: seq 22
- algorithm-designer: seq 23
- concurrency-designer: seq 24
- pattern-advisor: seq 25
- guardrail-validator: seq 50
- sdk-design-devil: seq 60
- sdk-dep-vet-devil: seq 61
- sdk-semver-devil: seq 62
- sdk-convention-devil: seq 63
- sdk-security-devil: seq 64

## Recommendation to `sdk-impl-lead`

APPROVE via H5 (pending H6 on dep-vet tooling). Design is stable; no outstanding NEEDS-FIX. Phase 2 may start from `api.go.stub` as the frozen signature target. Contract list above must be enforced.
