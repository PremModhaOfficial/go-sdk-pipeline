<!-- Generated: 2026-04-18T06:40:00Z | Run: sdk-dragonfly-s2 -->
# pattern-advisor — D1 Summary

Output: `design/patterns.md`.

## Convention cross-check verdicts

| Concern | Existing SDK | Dragonfly | Deviation |
|---|---|---|---|
| Constructor style | Config struct → `events.Connect(ctx, cfg)` / `resourcepool.New(cfg)` / `otel.Init(cfg)` | `dragonfly.New(opts ...Option)` | **yes (intentional, TPRD §6-directed)** |
| TLS shape | `events.TLSConfig{CertFile,KeyFile,CAFile,SkipVerify}` | adds `ServerName`, `MinVersion` | superset only |
| Error model | package-level `var Err* = errors.New(...)` | same | none |
| OTel | `motadatagosdk/otel/{tracer,metrics,logger}` | same | none |
| Pool | go-redis internal (TPRD §3 non-goal blocks `core/pool/*`) | go-redis internal | none |
| Tests | testify + table + `*benchmark_test.go` | same | none |
| Docs | README + (sometimes) USAGE | README + USAGE | none |

## Single intentional deviation

Dragonfly is the **first target-SDK package** to export functional `With*` options. Justification:
- TPRD §6 + Appendix B explicitly prescribe it.
- Slice-1 baseline already shipped 15 `With*` options (intake mode.json `options_expected`).
- 16-knob config surface: functional options scale better than positional args or constructor-param bloat.

`Config` remains exported, so power callers can still pass a pre-built struct via a single `func(c *Config){*c = myCfg}` option.

Convention-devil: **accept with note**. Future packages may follow or stay with Config-struct.

## Credential loader placement

`LoadCredsFromEnv(userEnv, passPathEnv)` lives in `dragonfly` package (NOT `config/`). Reason: specific to `dragonfly.Config.Username`/`Password`; placing in `config/` would create shape inversion.

## Explicitly NOT included (§3 non-goals verified)

- No `retry.go`, `circuitbreaker.go`, `rate_limit.go`, `l1.go`, `tiering.go`, `cluster.go`, `scriptregistry.go`.
- `WithMaxRetries(n)` exposed but `New()` logs a warn when `n!=0` (defensive guard).
