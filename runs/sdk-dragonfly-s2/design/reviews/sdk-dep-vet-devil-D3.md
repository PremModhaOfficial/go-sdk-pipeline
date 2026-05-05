<!-- Generated: 2026-04-18T07:00:00Z | Run: sdk-dragonfly-s2 -->
# sdk-dep-vet-devil — D3 Review

Focused on `dependencies.md`.

## Findings per dep

### D-1. `github.com/redis/go-redis/v9 v9.18.0`
- Already in go.mod. No action.
- License: BSD-2-Clause (allowlist PASS).
- govulncheck: PENDING (tool not installed on runner).
- osv-scanner: PENDING.
- Transitive count acceptable.
**Verdict:** ACCEPT pending govulncheck/osv-scanner at Phase 2.

### D-2. `github.com/alicebob/miniredis/v2 v2.37.0`
- Already in go.mod. No action.
- License: Apache-2.0 (allowlist PASS).
- Test-only.
**Verdict:** ACCEPT.

### D-3. `github.com/testcontainers/testcontainers-go` (NEW)
- Pins at Phase 2 `go mod tidy` time.
- License: MIT (allowlist PASS).
- **Large transitive tree** (~40 transitives via `github.com/docker/docker`).
- Test-only, import-gated by `//go:build integration`.
- Verified by inspection: no production file imports it (design package-layout places it exclusively in `cache_integration_test.go`).
**Verdict:** ACCEPT-CONDITIONAL — require Phase 2 to (a) pin an explicit version in go.mod (not use `latest`), (b) re-run govulncheck on the full transitive graph post-add, (c) confirm `//go:build integration` tag is present in the integration test file (G98 will catch if missing).

### D-4. `go.uber.org/goleak` (NEW)
- License: MIT.
- Transitive count: 0 external.
- Test-only.
- Very low risk.
**Verdict:** ACCEPT.

### D-5. Prometheus / Vault rejections
- Design explicitly rejected these. Good discipline. No net-new runtime deps beyond go-redis.
**Verdict:** ACCEPT.

## Aggregate

| Checklist item | Status |
|---|---|
| All deps in license allowlist | PASS |
| No duplicate modules | PASS (no version conflicts found; `testcontainers-go` and `goleak` are net-new) |
| Test-only gating verified | PASS for testcontainers (`//go:build integration`); for miniredis/goleak/testify the unit-test-only gating is by file-placement convention |
| govulncheck on declared deps | PENDING (D2 guardrail-validator G32 PENDING) |
| osv-scanner on declared deps | PENDING (G33 PENDING) |
| Transitive counts documented | PASS |
| Last-commit-age | PASS (all primary deps active) |

## Verdict

**CONDITIONAL**: 4 ACCEPT + 1 ACCEPT-CONDITIONAL (testcontainers version-pin + Phase 2 govulncheck).

Route to **H6 (Dep Vet HITL)** per design-lead protocol — user confirms tool installation plan and accepts the deferred govulncheck/osv-scanner until Phase 2 go.mod bump.

Aggregate verdict: **CONDITIONAL** (tooling unavailability; no intrinsic dep-vet defect).
