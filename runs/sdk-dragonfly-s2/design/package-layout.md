<!-- Generated: 2026-04-18T06:10:00Z | Run: sdk-dragonfly-s2 | Agent: sdk-designer -->
# Package Layout — `motadatagosdk/core/l2cache/dragonfly`

Authoritative TPRD §12. One package, one directory, no subpackages. All files live under `src/motadatagosdk/core/l2cache/dragonfly/`.

## File inventory

| File | Declares | TPRD ref | [traces-to] anchor |
|---|---|---|---|
| `const.go` | All default values (`defaultDialTimeout`, `defaultPoolSize`, `defaultConnMaxLifetime=10m`, `defaultPoolStatsInterval=10s`, `defaultReadTimeout`, `defaultWriteTimeout`, `defaultPoolTimeout`, `defaultProtocol=3`, `minPoolStatsInterval=1s`) | §6 | `TPRD-§6-const` |
| `config.go` | `type Config struct`, `type TLSConfig struct`, `(Config) validate()`, `(Config) applyDefaults()` | §6, §9 | `TPRD-§6-Config`, `TPRD-§9-TLS` |
| `options.go` | `type Option func(*Config)` + 15 `With*` setters (see §6 enumeration) | §6 | `TPRD-§6-Option-<Name>` |
| `errors.go` | 26 `Err*` sentinels, `mapErr(err error) error`, `classify(err error) string` | §7 | `TPRD-§7-Err<Name>`, `TPRD-§7-mapErr` |
| `loader.go` | `func LoadCredsFromEnv(userEnv, passPathEnv string) (username, password string, err error)` + helpers reading files | §9 | `TPRD-§9-LoadCredsFromEnv` |
| `cache.go` | `type Cache struct`, `func New(opts ...Option) (*Cache, error)`, `(*Cache).Ping`, `(*Cache).Close`, internal helpers (`instrumentedCall`) | §5.1, §8 | `TPRD-§5.1-New`, `TPRD-§5.1-Ping`, `TPRD-§5.1-Close` |
| `string.go` | All 19 string/key methods (§5.2) on `*Cache` | §5.2 | `TPRD-§5.2-<Method>` |
| `hash.go` | 8 base hash methods + 5 HEXPIRE family = 13 methods on `*Cache` | §5.3 | `TPRD-§5.3-<Method>` |
| `pipeline.go` | `(*Cache).Pipeline`, `(*Cache).TxPipeline`, `(*Cache).Watch` | §5.4 | `TPRD-§5.4-<Method>` |
| `pubsub.go` | `(*Cache).Publish`, `(*Cache).Subscribe`, `(*Cache).PSubscribe` | §5.5 | `TPRD-§5.5-<Method>` |
| `script.go` | `(*Cache).Eval`, `(*Cache).EvalSha`, `(*Cache).ScriptLoad`, `(*Cache).ScriptExists` | §5.6 | `TPRD-§5.6-<Method>` |
| `raw.go` | `(*Cache).Do`, `(*Cache).Client` | §5.7 | `TPRD-§5.7-<Method>` |
| `poolstats.go` | `type poolStatsScraper struct`, `(*poolStatsScraper).run`, scraper goroutine lifecycle helpers | §8.2 | `TPRD-§8.2-poolstats` |
| `USAGE.md` | Cookbook: connecting, TLS, ACL, pipeline, HEXPIRE, PubSub, EVALSHA, known Dragonfly gaps | §2, §14 | — (non-Go doc) |
| `README.md` | Package one-pager: what it is, what it isn't, quickstart link → USAGE.md | — | — |
| `cache_test.go` | Lifecycle tests: `New` validation, `Ping`, `Close`, idempotent close, goleak | §11.1 | — |
| `string_test.go` | Table-driven §5.2 coverage (miniredis) | §11.1 | — |
| `hash_test.go` | Table-driven §5.3 coverage (miniredis) | §11.1 | — |
| `pipeline_test.go` | §5.4 unit coverage | §11.1 | — |
| `pubsub_test.go` | §5.5 unit coverage + subscriber leak test | §11.1 | — |
| `script_test.go` | §5.6 unit coverage | §11.1 | — |
| `errors_test.go` | `TestMapErr` table, `FuzzMapErr` | §11.1, §11.4 | — |
| `loader_test.go` | `LoadCredsFromEnv` file/env resolution | §11.1 | — |
| `cache_integration_test.go` | `//go:build integration` — testcontainers Dragonfly; matrix TLS×ACL; chaos kill | §11.2 | — |
| `cachebenchmark_test.go` | `BenchmarkGet/Set/Pipeline_100/HSet/HExpire/EvalSha` with `-benchmem`; overhead A/B vs raw go-redis | §10, §11.3 | — (bench proof feeds G97) |

**Count:** 14 production `.go` files + 1 USAGE.md + 1 README.md + 7 unit tests + 1 integration test + 1 bench test = **24 files** (TPRD §12 enumerates 20 files + README+USAGE; the delta is `errors_test.go` and `loader_test.go` which the TPRD implies via §11.1 "table-driven per method" coverage).

## Package identity

- Import path: `motadatagosdk/core/l2cache/dragonfly`
- Package clause: `package dragonfly`
- No subpackages. All symbols live at the package root. No internal/.
- No `doc.go`; package godoc lives at the top of `cache.go` (per existing SDK convention — see `motadatagosdk/events/events.go`).

## Allowed external imports

Runtime (production files):
- `context`, `crypto/tls`, `crypto/x509`, `errors`, `fmt`, `net`, `os`, `strings`, `sync`, `sync/atomic`, `time` (stdlib)
- `github.com/redis/go-redis/v9` — core dep
- `motadatagosdk/otel/tracer` — spans
- `motadatagosdk/otel/metrics` — counters / histograms / gauges
- `motadatagosdk/otel/logger` — lifecycle logs

Test-only:
- `github.com/alicebob/miniredis/v2`
- `github.com/testcontainers/testcontainers-go` (+ dragonfly module; import-gated via `//go:build integration`)
- `go.uber.org/goleak`
- `github.com/stretchr/testify` (already in go.mod)

**Disallowed:** `motadatagosdk/core/circuitbreaker`, `motadatagosdk/core/pool/*` (orthogonal concern, §3 non-goals), `motadatagosdk/events/*` (different domain), raw `go.opentelemetry.io/otel` (must go through `motadatagosdk/otel`).

## Module-graph impact

- **New deps in go.mod?** No — all runtime deps already present in target go.mod (go-redis v9.18.0 at line 13; testcontainers and goleak need to be added as `require` entries — see `dependencies.md` for vetting verdict).
- **go.sum:** Will grow for testcontainers (net-new) + goleak (net-new). `sdk-dep-vet-devil` validates.
- **Does not affect:** `motadatagosdk/core/l1cache`, `motadatagosdk/events`, `motadatagosdk/otel/*`.

## Provenance / marker plan (Mode A)

- Every pipeline-authored symbol gets `[traces-to: TPRD-§<N>-<id>]` in the godoc (G99).
- Every `.go` file gets a top-of-file `[traces-to: TPRD-§<N>]` block marker (G98).
- NO `[owned-by: MANUAL]` markers anywhere in this package (mode override per intake/mode.json).
- Hot-path methods (`Get`, `Set`, `HExpire`) receive `[constraint: ...]` markers referencing `BenchmarkGet` / `BenchmarkSet` / `BenchmarkHExpire` (feeds G97).

## Non-goals reminder (enforced by structure)

- No `retry.go` / `circuitbreaker.go` / `tiering.go` (§3).
- No `cluster.go` (§3 — no sharding logic).
- No `scriptregistry.go` (§3 — caller owns EVALSHA cache).
- No subpackage `dragonfly/internal/*` — flat layout for discoverability.
