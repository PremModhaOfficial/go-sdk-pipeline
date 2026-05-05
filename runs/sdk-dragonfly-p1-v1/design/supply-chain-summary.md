<!-- Generated: 2026-04-23T15:55:00Z | Run: sdk-dragonfly-p1-v1 -->
# Supply-chain scan — P1

Both tools executed for real. Raw outputs in this dir: `govulncheck.txt` + `osv-scanner.txt`.

## govulncheck (Go 1.26 toolchain, scoped to `core/l2cache/dragonfly/...`)

- **10 call-reachable vulnerabilities** in 1 module + Go stdlib
- **3 reachable through imports** (code doesn't call these)
- **1 in modules required but not called**

All 10 reachable vulns are inherited from the **pre-existing target-SDK dependency surface**, not introduced by P1:

| Source | Reached via | P1-introduced? |
|---|---|---|
| Go stdlib (x509, tls, crypto, template, fmt) | TLS dial path in `cache.go:New`, `fmt.Errorf` template chain in `sortedset.go`/`errors.go` | **No** — these paths exist in every net/tls user and every package that uses `fmt.Errorf` |
| `go.opentelemetry.io/otel/sdk` v1.39.0 | `otel/logger`, `otel/tracer` `init()` chains | **No** — P0 target-wide tech debt (same vuln reported in `sdk-dragonfly-s2` run-summary) |
| `google.golang.org/grpc` v1.78.0 | transitive OTel exporter dep | **No** — target-wide |

**Verdict:** G32 passthrough confirmed — no new vuln surface introduced by P1. Remediation is a target-wide `go get -u` for Go stdlib + OTel SDK, scheduled outside P1.

## osv-scanner (go.mod lockfile)

- **~30 CVE rows** across `nats-io/nats-server/v2 2.12.5`, `otel/exporters/*`, `otel/sdk`, and `google.golang.org/grpc`
- Highest severity: 9.1 (grpc), 8.6 (nats-server)
- All entries are target-SDK-wide dependencies; dragonfly imports none of `nats-server` / grpc directly

**Verdict:** G33 passthrough confirmed — no P1-introduced CVE. License allowlist (G34) — P1 adds zero third-party deps, so the existing allowlist holds.

## Action items (not blockers for this run)

Filed as target-wide backlog:

1. Bump `go.opentelemetry.io/otel/sdk` to a post-GO-2026-4394 / GO-2026-4762 release across the SDK's `go.mod`. Coordinate with `otel/` package owner.
2. Decide whether to bump `nats-server/v2` — affects `events/` package only, not dragonfly.
3. Go stdlib vulns at 1.26.0 are fixed in 1.26.1 / 1.26.2. Toolchain bump belongs to the target-SDK release cycle.

None of these gate H10 for P1. They're the same class of pre-existing target debt that `sdk-dragonfly-s2` documented under "Waivers + deferred items."
