<!-- Generated: 2026-04-18T06:40:00Z | Run: sdk-dragonfly-s2 -->
# sdk-designer — D1 Summary

Outputs authored: `design/package-layout.md`, `design/api.go.stub`, `design/dependencies.md`.

## Headlines

- **24-file layout** (14 production .go + 7 unit tests + 1 integration test + 1 bench test + README + USAGE). Maps 1:1 to TPRD §12 with the addition of `errors_test.go` + `loader_test.go` implied by §11.1 "table-driven per method" coverage of `mapErr` and `LoadCredsFromEnv`.
- **API stub compiles** against target go.mod (`go 1.26`, `redis/go-redis/v9 v9.18.0`) — verified in scratch module at `/tmp/dragonfly-stub-*`. Exit 0.
- **46 receiver methods on `*Cache`** + `New` + `LoadCredsFromEnv` + 26 sentinels + 15 options + 2 types (`Config`, `TLSConfig`) + 1 `Option` alias. Exact count matches intake mode.json enumeration.
- **Dep delta: +2 test-only** (`testcontainers-go`, `goleak`). Both MIT. `govulncheck`/`osv-scanner` deferred to Phase 2 post go.mod bump.
- **No `[owned-by: MANUAL]` markers anywhere** (Mode A override). Every symbol + every file carries `[traces-to: TPRD-§<n>-<id>]`.

## Key design decisions

1. Flat package layout (no `internal/`, no subpackages). Matches `motadatagosdk/events/` discoverability.
2. `Config` struct + `Option` functional options **both** exported — reconciles TPRD §6 "fields in Config" with "setters in options.go".
3. `Cache.Client()` returns raw `*redis.Client` — intentional escape hatch (TPRD §5.7); bypasses instrumentation; documented.
4. `Pipeline()` / `TxPipeline()` return raw `redis.Pipeliner` — no wrapper (TPRD §5.4 explicitly wants pass-through).
5. Hot paths (`Get`, `Set`, `HExpire`, `EvalSha`) carry `[constraint:]` markers for G97 bench proofs.

## Handoff to devils

- `sdk-dep-vet-devil` → consume `dependencies.md`. Section G has the checklist.
- `sdk-semver-devil` → Mode A; fresh package; minor bump from 0.x.0 → 0.(x+1).0 expected ACCEPT.
- `sdk-convention-devil` → one intentional deviation noted (`Option` functional options, first in target SDK); full rationale in `patterns.md` §P1.
- `sdk-security-devil` → check §Security block in `api.go.stub` `TLSConfig` + `LoadCredsFromEnv`; verify no credentials logged.
- `sdk-design-devil` → overall design plausibility.
