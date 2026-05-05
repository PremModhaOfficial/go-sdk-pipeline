<!-- Generated: 2026-04-18T08:30:00Z | Run: sdk-dragonfly-s2 -->
# DEP-BUMP-UNAPPROVED — Phase 2 Impl Escalation

**Run:** sdk-dragonfly-s2
**Branch:** sdk-pipeline/sdk-dragonfly-s2
**Base SHA:** bd3a4f7f618e9f7342750922db9461474ce87f0c
**Triggered by:** `go get github.com/testcontainers/testcontainers-go@latest` (resolves to v0.42.0)
**Status:** HALTED — awaiting run-driver approval

## Summary

Integration tests for TPRD §11.2 require `testcontainers-go`. The user directive 2026-04-18 authorises adding `testcontainers-go` at latest stable (v0.42.0) and promoting `goleak` to direct. However, the same directive forbids touching `golang.org/x/crypto`, the `go 1.26` toolchain directive, `redis/go-redis`, `miniredis`, `stretchr/testify`, **or any other existing direct or indirect dep**.

`go mod tidy` after `go get testcontainers-go@v0.42.0` forces Go MVS to bump the following **untouched pins**:

| Dep | Previous pin | New required | Channel |
|---|---|---|---|
| `go.opentelemetry.io/otel` | v1.39.0 | v1.41.0 | **direct** |
| `go.opentelemetry.io/otel/metric` | v1.39.0 | v1.41.0 | **direct** |
| `go.opentelemetry.io/otel/trace` | v1.39.0 | v1.41.0 | **direct** |
| `github.com/klauspost/compress` | v1.18.4 | v1.18.5 | indirect |

Plus ~25 new indirect deps introduced by testcontainers (docker/moby/containerd/opencontainers/ebitengine tree + shirou/gopsutil v4 + sirupsen/logrus etc). These are normal testcontainers transitive costs and are compatible with the current license allowlist (MIT / Apache-2.0 / BSD), but per the directive they still fall under "any other existing…or indirect dep" — none are pre-existing, so they add new rows rather than bump — however the four bumps above ARE pre-existing and do violate the directive.

## Root cause per dep

### go.opentelemetry.io/otel v1.39.0 → v1.41.0
- Triggered by: `github.com/testcontainers/testcontainers-go v0.42.0` → `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.60.0` → requires `go.opentelemetry.io/otel >= v1.41.0`.
- `go mod why go.opentelemetry.io/otel` (post-tidy) confirms the chain.

### go.opentelemetry.io/otel/metric + otel/trace v1.39.0 → v1.41.0
- Same root cause as above; otel-contrib v0.60.0 pins the entire otel/* family at v1.41.0. The three `otel/*` modules are released in lockstep.

### github.com/klauspost/compress v1.18.4 → v1.18.5
- Triggered by: `testcontainers-go v0.42.0` → `github.com/moby/go-archive v0.2.0` → `github.com/moby/go-archive/compression` → imports `github.com/klauspost/compress/zstd` from a version that has been cut since v1.18.4 (v1.18.5 is the current floor that satisfies the moby/go-archive module's go.mod).
- `go mod why github.com/klauspost/compress` confirms the chain.

## Downstream impact analysis

- `motadatagosdk/otel/*` packages import `go.opentelemetry.io/otel`, `otel/metric`, and `otel/trace`. A v1.39 → v1.41 bump is **within the same v1 semantic-version lane** — the OTel Go SIG commits to backward-compatible minor releases. `metrics/metrics.go` already uses the public `metric.Meter` interface; no API differences at the source level are expected.
- `klauspost/compress v1.18.4 → v1.18.5` is a patch bump with no public API change.
- No direct dep has a major-version bump.
- No deps in the forbid list (x/crypto, go 1.26 toolchain, go-redis, miniredis, testify) are touched.

## Mitigation options (for run-driver to choose)

**Option A — Approve the 4 bumps.**
Rationale: They are unavoidable under Go MVS for `testcontainers-go@v0.42.0`. All four are semver-minor-or-patch within the same v1 lane. Empirically, otel minor bumps have been backward-compatible for the full v1 line since release.
Action: `govulncheck ./...` + `osv-scanner --lockfile=go.sum` before confirm; if clean, proceed.

**Option B — Pin an older testcontainers-go that depends on otel v1.39.0.**
Research: The last testcontainers-go release that pinned `otelhttp v0.58.x` (which targets otel v1.39) was v0.38.0 (2025-10-14). Trying `testcontainers-go@v0.38.0` would avoid the otel bump but may not compile against go 1.26 (deprecation warnings became hard errors in otel v1.40 which otel v1.39 predates — likely fine). The klauspost/compress bump would also be avoided because moby/go-archive's pin in that era is v1.17.x compatible.
Risk: v0.38 is 6 months old; CVE exposure higher.

**Option C — Move integration tests to a separate module.**
Rationale: Place `cache_integration_test.go` (the sole testcontainers consumer) in a child module (e.g., `core/l2cache/dragonfly/integration/go.mod`) so the testcontainers dep tree does not contaminate the main module. The child module would satisfy TPRD §11.2 but would have a separate go.sum.
Cost: Two go.mod files for the dragonfly package; slight tooling complexity; not the target-SDK convention.

**Option D — Drop integration tests for this run; ship unit tests + bench only.**
Rationale: Defer the testcontainers addition to a follow-up TPRD. TPRD §11.2 becomes aspirational. `miniredis` covers unit paths adequately. HEXPIRE wire-compat check (TPRD §14 risk item) is deferred to manual QA.
Cost: Weakens the test pyramid; TPRD §11.2 not fully delivered.

## Recommendation

**Option A** — approve the 4 bumps. The otel v1.39 → v1.41 drift is semver-safe and the testcontainers ecosystem has broad adoption; pinning to older versions for this single concern would introduce more fragility than it avoids. `govulncheck` + `osv-scanner` verdicts on v1.41 are expected clean (no known CVEs in the otel 1.4x line as of 2026-04-18).

If Option A is approved, the escalation resolution is: re-run `go get testcontainers-go@v0.42.0` + `go mod tidy`, capture the diff, proceed with Wave M3 Green.

## Decision-log entries

- seq 38: ESCALATION: DEP-BUMP-UNAPPROVED filed; Wave M3 halted; awaiting approval.

## Reset state

**Target repo HEAD is unchanged at bd3a4f7** — no commits made on branch.

Working-tree modifications present (uncommitted, safe to revert):
- `src/motadatagosdk/go.mod` — carries the dep-bump diff from the last `go get`/`go mod tidy` attempt. The sandbox denied a second destructive revert, so this file is dirty in the working tree. Run driver can reset via `git checkout src/motadatagosdk/go.mod && rm -f src/motadatagosdk/go.sum`.
- 9 `*_test.go` files in `src/motadatagosdk/core/l2cache/dragonfly/` — untracked; do not affect build state because no source stubs exist to compile against. These SHOULD be kept to seed Wave M1 once Wave M3 restart is authorised.
- `src/motadatagosdk/core/l2cache/dragonfly/cache_integration_test.go` — untracked; build-tagged `//go:build integration`. If Option A/B/C is chosen, KEEP. If Option D, delete this file.

**Awaiting decision from run-driver. Do not proceed with Wave M3 until a resolution path (A/B/C/D) is confirmed.**
