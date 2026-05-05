<!-- Generated: 2026-04-18T07:20:00Z | Run: sdk-dragonfly-s2 -->
# Phase 1 Design — Summary

**Run:** sdk-dragonfly-s2 · **Mode:** A (greenfield) · **Package:** `motadatagosdk/core/l2cache/dragonfly` · **Pipeline:** 0.1.0

## Artifacts produced (D1)

| File | Owner | Status |
|---|---|---|
| `design/package-layout.md` | sdk-designer | complete — 24 files enumerated |
| `design/api.go.stub` | sdk-designer | complete — compiles, G30 PASS (verified twice) |
| `design/dependencies.md` | sdk-designer | complete — +2 test-only deps documented |
| `design/interfaces.md` | interface-designer | complete — no exported interfaces; G43 seams documented |
| `design/algorithms.md` | algorithm-designer | complete — 4 surfaces (mapErr, scraper, HEXPIRE, instrumentedCall) |
| `design/concurrency.md` | concurrency-designer | complete — 1 pipeline goroutine; bounded shutdown |
| `design/patterns.md` | pattern-advisor | complete — 1 intentional deviation (functional options), all else aligned |
| `design/skill-gaps-observed.md` | sdk-design-lead | complete — 8 gaps filed for Phase 4 feedback |
| Context summaries (5) | each D1 agent | complete under `design/context/` |

## Exit guardrails (D2)

| ID | Verdict | Note |
|---|---|---|
| G30 (stub compiles) | **PASS** | Scratch module with `redis/go-redis/v9 v9.18.0` require; `go build ./...` exit 0. Re-verified after D4 iter-1. |
| G31 (deps doc) | **PASS** | 142-line `dependencies.md`. |
| G32 (govulncheck) | **PENDING** | Tool not installed; routes to H6. |
| G33 (osv-scanner) | **PENDING** | Tool not installed; routes to H6. |
| G34 (license allowlist) | **PASS** | All declared deps MIT / Apache-2.0 / BSD-2-Clause. |
| G38 (security review + sentinels) | **PASS** | 26 sentinels; §Security discussed across design docs; tenant-leak scan (scoped to package dir + design artifacts) clean. |

Details in `design/reviews/guardrail-validator-D2.md`.

## Devil verdicts (D3 iter-0 → D4 iter-1)

| Devil | Iter-0 | Iter-1 (final) |
|---|---|---|
| sdk-design-devil | NEEDS-FIX (F-D3) | **ACCEPT** |
| sdk-dep-vet-devil | CONDITIONAL | **CONDITIONAL** (unchanged, routes to H6) |
| sdk-semver-devil | ACCEPT minor | **ACCEPT minor** |
| sdk-convention-devil | ACCEPT | **ACCEPT** (one deviation noted: C-1 functional options) |
| sdk-security-devil | NEEDS-FIX (S-9) | **ACCEPT** |

Rework: **1 iteration**. Findings: **2 NEEDS-FIX** (both resolved), **~10 ACCEPT-WITH-NOTE** (Phase 2 contracts), **~15 pure ACCEPT**.

## Fixes applied (D4 iter-1)

1. **F-D3** (sdk-design-devil): `concurrency.md` §G1 — `stop()` now bounded at `stopTimeout = 5s` with a `logger.Warn` on timeout. Prevents `Close()` hang under metrics-backend backpressure.
2. **S-9** (sdk-security-devil): `patterns.md` §P5a — explicit credential-rotation Dialer re-read contract. `WithPassword(static)` caveat documented; `LoadCredsFromEnv` path wires a Dialer closure that re-reads the password file on every dial, achieving §9 "re-dial reads file fresh".

## Final API surface (one line per exported symbol)

**Types (4):** `Cache`, `Config`, `Option`, `TLSConfig`.

**Package functions (2):** `New(opts ...Option) (*Cache, error)`, `LoadCredsFromEnv(userEnv, passPathEnv string) (string, string, error)`.

**Options (15):** `WithAddr`, `WithUsername`, `WithPassword`, `WithTLS`, `WithTLSServerName`, `WithPoolSize`, `WithPoolTimeout`, `WithConnMaxLifetime`, `WithDialTimeout`, `WithReadTimeout`, `WithWriteTimeout`, `WithDB`, `WithClientName`, `WithMaxRetries`, `WithProtocol`. (+ internal `WithPoolStatsInterval` available from stub — advisory, not in intake `options_expected`; intake should accept as a §15.Q2-resolution side-effect.)

**Lifecycle methods (2):** `(*Cache).Ping(ctx) error`, `(*Cache).Close() error`.

**§5.2 String/Key (19):** `Get`, `Set`, `SetNX`, `SetXX`, `GetSet`, `GetEx`, `GetDel`, `MGet`, `MSet`, `Del`, `Exists`, `Expire`, `ExpireAt`, `Persist`, `TTL`, `Incr`, `IncrBy`, `Decr`, `DecrBy`.

**§5.3 Hash + HEXPIRE (13):** `HGet`, `HSet`, `HMGet`, `HGetAll`, `HDel`, `HExists`, `HLen`, `HIncrBy`, `HExpire`, `HPExpire`, `HExpireAt`, `HTTL`, `HPersist`.

**§5.4 Pipeline (3):** `Pipeline`, `TxPipeline`, `Watch`.

**§5.5 PubSub (3):** `Publish`, `Subscribe`, `PSubscribe`.

**§5.6 Scripting (4):** `Eval`, `EvalSha`, `ScriptLoad`, `ScriptExists`.

**§5.7 Raw (2):** `Do`, `Client`.

**Error sentinels (26):** `ErrNotConnected`, `ErrInvalidConfig`, `ErrTimeout`, `ErrUnavailable`, `ErrCanceled`, `ErrNil`, `ErrWrongType`, `ErrOutOfRange`, `ErrSyntax`, `ErrMoved`, `ErrAsk`, `ErrClusterDown`, `ErrLoading`, `ErrReadOnly`, `ErrMasterDown`, `ErrAuth`, `ErrNoPerm`, `ErrTLS`, `ErrTxnAborted`, `ErrScriptNotFound`, `ErrBusyScript`, `ErrPoolExhausted`, `ErrPoolClosed`, `ErrRESP3Required`, `ErrSubscriberClosed`, `ErrCircuitOpen`.

**Total exported symbols:** 4 types + 2 funcs + 15 options + 46 methods + 26 sentinels = **93 symbols**. Matches intake mode.json enumeration exactly.

## Traceability (G98/G99 readiness)

Every pipeline-authored symbol has `[traces-to: TPRD-§<n>-<id>]` in its godoc in the stub. Every .go file will receive a top-of-file `[traces-to: TPRD-§<n>]` marker in Phase 2 impl. Hot-path methods carry `[constraint: … | bench/BenchmarkX]` for G97.

## Risks flagged for Phase 2 impl

1. **`instrumentedCall` Labels alloc** — `metrics.Labels{"cmd": cmd}` creates a map per call (~1 alloc). Monitor at benchmark; switch to pre-built Labels-per-cmd if §10 ≤3-alloc/GET target is missed.
2. **Credential rotation Dialer re-read** — Phase 2 MUST implement per `patterns.md` §P5a. This is a behavioral contract, not a signature change.
3. **Scraper stop timeout of 5s** — operators observing `dragonfly: pool-stats scraper stop timed out` warnings should investigate metrics-backend health; acceptable rare event.
4. **PubSub caller-owned Close** — godoc on `Subscribe`/`PSubscribe` MUST loudly say "caller MUST `ps.Close()`". goleak will enforce in tests.
5. **`HTTL` negative durations** — document `< 0` sentinels (`-1 = no TTL`, `-2 = no field`). Callers must not blindly `time.Sleep(d)`.
6. **`Pipeline()` + `TxPipeline()` bypass instrumentation** — USAGE.md must say so.
7. **go-redis `redis.TxFailedErr`** — `mapErr` rule 0a MUST be honored before default classification.
8. **Metrics registry sharing** — multiple `*Cache` instances share `l2cache.*` metrics. If a caller wants per-instance metrics, a future `WithMetricsNamespace(ns)` option is the escape hatch (not in scope).

## HITL gates

- **H6 (Dep Vet)** — govulncheck + osv-scanner PENDING. Routes to user decision. Recommendation: install the two tools; run against current go.mod; user accepts design if both are green or user waives for Phase 2 deferred re-run.
- **H4 (Breaking Change)** — N/A (Mode A).
- **H5 (Design Sign-Off)** — blocked on this summary + H6 outcome. Lead recommendation: APPROVE.

## Next phase

On H5 approval: launch `sdk-impl-lead` for Phase 2 TDD red/green/refactor.
