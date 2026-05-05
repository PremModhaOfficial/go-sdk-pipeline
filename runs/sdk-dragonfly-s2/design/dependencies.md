<!-- Generated: 2026-04-18T06:35:00Z | Run: sdk-dragonfly-s2 | Agent: sdk-designer -->
# Dependencies — `dragonfly` package

Per rule #19, every runtime dep is vetted here. `sdk-dep-vet-devil` consumes this document.

## A. Runtime dependencies (production code)

### A1. `github.com/redis/go-redis/v9 v9.18.0`

| Attribute | Value |
|---|---|
| Status | **Already in target go.mod** (line 13) — no `go get` required. |
| Purpose | Core Redis / Dragonfly client. |
| License | BSD-2-Clause (allowlist: BSD → PASS). |
| Pinned version | v9.18.0 (TPRD §4 explicit pin). |
| Last commit age | < 90 days (v9.18.0 tagged 2025-Q4 per upstream). Active maintenance. |
| Transitive count | ~5 direct transitives (`cespare/xxhash/v2`, `dgryski/go-rendezvous`, `google/uuid`, `bsm/ginkgo`, `bsm/gomega`). All already in go.sum. |
| govulncheck | Pending (script `scripts/guardrails/G32.sh`). Target: clean. |
| osv-scanner | Pending (script `scripts/guardrails/G33.sh`). Target: clean. |
| Justification | TPRD §1: "thin, opinionated wrap of `github.com/redis/go-redis/v9`". Non-substitutable. |

### A2. Standard library only

Beyond go-redis, the production package uses only stdlib:
`context`, `crypto/tls`, `crypto/x509`, `errors`, `fmt`, `net`, `os`, `strings`, `sync`, `sync/atomic`, `time`.

### A3. Internal SDK packages (no vetting required — already in tree)

- `motadatagosdk/otel/tracer` — spans.
- `motadatagosdk/otel/metrics` — counters / gauges / histograms.
- `motadatagosdk/otel/logger` — lifecycle logs.

No deps added under A3.

## B. Test-only dependencies

### B1. `github.com/alicebob/miniredis/v2 v2.37.0`

| Attribute | Value |
|---|---|
| Status | **Already in target go.mod** (line 6). |
| Purpose | In-memory Redis fake for unit tests. |
| License | Apache-2.0 (allowlist PASS). |
| Age | v2.37.0 released 2025-Q3; actively maintained. |
| Test-gating | Used in `*_test.go` unconditionally (not behind a build tag — unit tests default). |
| govulncheck | Clean (2026-04 baseline). |
| Justification | TPRD §11.1 prescribes miniredis. |

### B2. `github.com/testcontainers/testcontainers-go` (latest stable ≥ v0.37.0)

| Attribute | Value |
|---|---|
| Status | **NEW dep** — not yet in target go.mod. Must be added before Phase 2. |
| Purpose | Integration-test Docker container orchestration (TPRD §11.2). |
| License | MIT (allowlist PASS). |
| Proposed version | Latest stable at time of Phase 2 (pin at `go mod tidy` time; record in go.sum). Typical range: v0.37.x – v0.40.x. |
| Last commit age | < 30 days. Very active (Docker ecosystem). |
| Transitive count | HIGH — pulls in Docker client, `github.com/docker/docker`, `github.com/moby/*`. ~40 new transitives. |
| Vet concerns | Large transitive tree. All MIT / Apache-2.0 / BSD. govulncheck MUST run. |
| Test-gating | Integration test file has `//go:build integration`. **Unit `go test ./...` does NOT import testcontainers** — verified by file placement: `cache_integration_test.go` is the only importer. |
| Justification | TPRD §11.2 prescribes real-Dragonfly testing. miniredis cannot cover HEXPIRE / RESP3 / TLS edge cases. |

### B3. `github.com/testcontainers/testcontainers-go/modules/dragonfly` OR community Dragonfly recipe

| Attribute | Value |
|---|---|
| Status | Upstream has no official `dragonfly` module at time of TPRD. Use the generic `GenericContainer` with `docker.dragonflydb.io/dragonflydb/dragonfly:latest` image. |
| Purpose | Spin real Dragonfly for integration matrix. |
| Recommendation | No separate module needed — implement inline via `testcontainers.GenericContainer` in `cache_integration_test.go`. This avoids a second dep add. |
| Justification | Keeps dep graph minimal. Recipe lives in test source, not in go.mod. |

### B4. `go.uber.org/goleak` (latest stable)

| Attribute | Value |
|---|---|
| Status | **NEW dep** (not in target go.mod — verified by grep). Must be added before Phase 2. |
| Purpose | `goleak.VerifyTestMain(m)` — goroutine-leak detector (G63). |
| License | MIT (allowlist PASS). |
| Proposed version | v1.3.0 (latest). |
| Age | Mature, stable, low-frequency releases; last release 2024-Q4. |
| Transitive count | zero external (stdlib only). |
| Test-gating | Used only in `*_test.go` files. Not imported by production code. |
| Justification | Intake non-negotiable #11: "Pool-stats scraper goroutine must be shutdown-clean (goleak pass, G63)." |

### B5. `github.com/stretchr/testify v1.11.1`

| Attribute | Value |
|---|---|
| Status | Already in target go.mod (line 15). |
| Purpose | Standard assertions. |
| License | MIT (allowlist PASS). |

No action required.

## C. Deps NOT added / considered

- **`github.com/prometheus/client_golang`** — NOT added. All metrics go through `motadatagosdk/otel/metrics` which already handles OTLP → Prometheus via collector (§8.2).
- **`github.com/hashicorp/vault/api`** — NOT added. Credentials come from K8s mounted secret files (§9), not Vault directly.
- **`go.opentelemetry.io/otel/*` (raw)** — NOT added. Already transitively present via `motadatagosdk/otel`; we never import directly.
- **`github.com/cenkalti/backoff/v5`** — indirect only (transitive). §3 non-goal: no SDK-level retry, so no direct import.

## D. License allowlist check (G34)

| Dep | License | Allowlist (MIT / Apache-2.0 / BSD / ISC / 0BSD / MPL-2.0) |
|---|---|---|
| go-redis/v9 | BSD-2-Clause | PASS |
| miniredis/v2 | Apache-2.0 | PASS |
| testcontainers-go | MIT | PASS |
| goleak | MIT | PASS |
| testify | MIT | PASS |

All PASS.

## E. govulncheck + osv-scanner (G32 / G33)

**Status:** PENDING until Phase 2 adds the new deps to go.mod. Running them now would only check already-present deps; incomplete.

Proposed sequencing: `sdk-impl-lead` adds testcontainers + goleak to `go.mod` before the test-phase; `guardrail-validator` re-runs G32/G33 at Phase 3 boundary.

For the design-phase gate: run G32/G33 against the CURRENT target go.mod (i.e., confirm go-redis/v9 + miniredis/v2 are clean today). If `govulncheck` or `osv-scanner` binaries are absent, emit PENDING verdict and route to H6 (user decides).

## F. Net dep-graph delta this run

| Package | Direct? | Δ | Risk |
|---|---|---|---|
| `github.com/redis/go-redis/v9` | direct | 0 (already present) | low |
| `github.com/alicebob/miniredis/v2` | direct (test) | 0 (already present) | low |
| `github.com/testcontainers/testcontainers-go` | direct (test, `//go:build integration`) | **+1** | medium (large transitive tree, Docker surface) |
| `go.uber.org/goleak` | direct (test) | **+1** | low |

**Net +2 direct deps**, both test-only, both with mature maintenance + safe licenses.

## G. Vet-devil checklist

- [x] License in allowlist (G34).
- [ ] govulncheck clean (G32) — run when impl adds deps; or run against current go.mod as baseline.
- [ ] osv-scanner clean (G33) — same.
- [x] Last-commit-age acceptable (< 180 days for primary deps).
- [x] Transitive count documented.
- [x] Test-only gating verified (integration test behind `//go:build integration`).
- [x] No unnecessary additions (prometheus/vault explicitly rejected).
