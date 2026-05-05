<!-- Generated: 2026-04-18T07:25:00Z | Run: sdk-dragonfly-s2 -->
# H5 — Design Sign-Off Summary

**Gate:** H5 (Design) · **Status:** awaiting human approval · **Lead recommendation:** APPROVE

## Final API surface (one line per exported symbol)

| Category | Symbols |
|---|---|
| Types | `Cache`, `Config`, `Option`, `TLSConfig` |
| Package funcs | `New(opts ...Option) (*Cache, error)` · `LoadCredsFromEnv(userEnv, passPathEnv string) (string, string, error)` |
| Options (15) | `WithAddr`, `WithUsername`, `WithPassword`, `WithTLS`, `WithTLSServerName`, `WithPoolSize`, `WithPoolTimeout`, `WithConnMaxLifetime`, `WithDialTimeout`, `WithReadTimeout`, `WithWriteTimeout`, `WithDB`, `WithClientName`, `WithMaxRetries`, `WithProtocol` |
| Lifecycle methods | `(*Cache).Ping(ctx) error` · `(*Cache).Close() error` |
| §5.2 String (19) | `Get`, `Set`, `SetNX`, `SetXX`, `GetSet`, `GetEx`, `GetDel`, `MGet`, `MSet`, `Del`, `Exists`, `Expire`, `ExpireAt`, `Persist`, `TTL`, `Incr`, `IncrBy`, `Decr`, `DecrBy` |
| §5.3 Hash + HEXPIRE (13) | `HGet`, `HSet`, `HMGet`, `HGetAll`, `HDel`, `HExists`, `HLen`, `HIncrBy`, `HExpire`, `HPExpire`, `HExpireAt`, `HTTL`, `HPersist` |
| §5.4 Pipeline (3) | `Pipeline`, `TxPipeline`, `Watch` |
| §5.5 PubSub (3) | `Publish`, `Subscribe`, `PSubscribe` |
| §5.6 Scripting (4) | `Eval`, `EvalSha`, `ScriptLoad`, `ScriptExists` |
| §5.7 Raw (2) | `Do`, `Client` |
| Error sentinels (26) | all 26 per TPRD §7, matching intake/mode.json |

**Total exported symbols:** **93** (matches intake/mode.json exactly).

## Dep vet verdict (H6 input)

**CONDITIONAL** — `sdk-dep-vet-devil` output at `design/reviews/sdk-dep-vet-devil-D3.md`.
- License allowlist: PASS (MIT / Apache-2.0 / BSD-2-Clause).
- Net deps added: +2 test-only (`testcontainers-go`, `goleak`).
- govulncheck / osv-scanner: **PENDING** — neither tool installed on current runner.
- Recommendation: install both tools; re-run against current go.mod (baseline). Phase 2 re-runs after `go mod tidy` for testcontainers + goleak.

## Convention verdict

**ACCEPT with 1 note** — `sdk-convention-devil` output at `design/reviews/sdk-convention-devil-D3.md`.
- Dragonfly is the first target-SDK package to export functional `With*` options.
- TPRD §6 explicitly directs this; intake enumerated 15 expected `With*` options.
- `Config` struct still exported for power users.
- Recommendation: Phase 4 feedback → cross-SDK design-standards doc codifying when each constructor style applies.

## Security verdict

**ACCEPT (post iter-1 fix)** — `sdk-security-devil` output at `design/reviews/sdk-security-devil-D3.md` + re-run verdict at `design/reviews/devil-rerun-iter1.md`.
- Initial NEEDS-FIX on S-9 (credential rotation Dialer semantic) resolved in `patterns.md` §P5a.
- 6 ACCEPT-WITH-NOTE items are Phase 2 impl contracts (TLS validator, cred file perms warn, no-trim password, log/metric redaction, escape-hatch doc, plain-TCP warning).

## Semver verdict

**ACCEPT minor** — `sdk-semver-devil` output at `design/reviews/sdk-semver-devil-D3.md`.
- v0.x.0 → v0.(x+1).0.
- All new exports additive; Slice-1 signatures preserved (even in Mode A regeneration).
- TPRD §1 confirms zero downstream callers.

## Design rework iterations

**1** (below 10-iter global cap; no stuck detection triggered).

## Risks flagged for Phase 2 impl

See `design-summary.md` final section. Eight specific risks enumerated; most are Phase 2 contracts the impl reviewer will verify.

## Decision

Lead recommends **APPROVE H5** subject to H6 disposition on dep-vet tooling.

If user:
- Installs govulncheck + osv-scanner → H6 runs both, records green, H5 approves.
- Defers tooling to Phase 2 → H5 approves with explicit PENDING verdict noted; Phase 3 boundary becomes the hard gate for both tools.

## Launch next phase

On H5 approval → launch `sdk-impl-lead` with:
- Frozen signature: `design/api.go.stub`
- Contract list: `design/context/sdk-design-lead-summary.md` §"Must-preserve contracts"
- Branch: `sdk-pipeline/sdk-dragonfly-s2`
- Target package dir: `src/motadatagosdk/core/l2cache/dragonfly/`

Phase 2 halts at H7 (impl diff) and H7b (mid-impl checkpoint, N/A for Mode A).
