<!-- Generated: 2026-04-18T06:50:00Z | Run: sdk-dragonfly-s2 -->
# D2 — guardrail-validator verdicts

Design-phase mechanical checks. All guardrails executed against `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/runs/sdk-dragonfly-s2/design/` and the target dir where applicable.

| Guardrail | Severity | Scope | Verdict | Notes |
|---|---|---|---|---|
| **G30** | BLOCKER | api.go.stub compiles | **PASS** | Built in scratch module with `github.com/redis/go-redis/v9 v9.18.0` require; `go build ./...` exit 0. Note: shipped `scripts/guardrails/G30.sh` does a bare `go mod init stubcheck` with no require-line — it would fail on our stub; the design-lead startup protocol explicitly permits a scratch module with the go-redis require, which we used. Filed as learning-engine signal: `G30.sh` should parse imports from `api.go.stub` and auto-populate require-lines. |
| **G31** | BLOCKER | dependencies.md exists + non-empty | **PASS** | 142 lines. All runtime + test deps enumerated. |
| **G32** | BLOCKER | govulncheck on declared deps | **PENDING** | `govulncheck` binary not installed on runner. Routes to H6 (dep-vet HITL) for user decision. Recommendation: install + run against existing go.mod baseline + recompute at Phase 2 post-dep-add. |
| **G33** | BLOCKER | osv-scanner on declared deps | **PENDING** | `osv-scanner` binary not installed. Same disposition as G32. |
| **G34** | BLOCKER | License allowlist | **PASS** | All declared deps in MIT / Apache-2.0 / BSD-2-Clause. See `dependencies.md` §D. |
| **G38** | BLOCKER | §Security review present + sentinel-only error model | **PASS** | (a) 26 `Err*` sentinels in stub — matches intake mode.json `error_sentinels` enumeration exactly. (b) §Security discussed in `api.go.stub` (TLSConfig + LoadCredsFromEnv), `patterns.md` §P5, `dependencies.md` §B, `package-layout.md`. (c) Tenant-leak scoped scan against the package dir + design artifacts: PASS (no `TenantID`/`tenant_id` tokens). The shipped `G38.sh` scans the entire target repo as a "placeholder" — pre-existing tenancy usage in `events/`, `otel/logger/`, `l1cache/` is out of scope for this run. |

## Net verdict

**4 PASS, 2 PENDING** (G32/G33 — tool unavailability, not design defect).

Design artifacts are mechanically valid. Proceed to D3 devil wave. G32/G33 will be resolved at H6 (dep-vet HITL) — user either installs tools or accepts PENDING verdict based on dependency risk assessment in `dependencies.md` §G.

## Tooling gaps filed

- `G30.sh` should accept a `--require` flag or parse stub imports. File as learning-engine candidate.
- `G38.sh` placeholder scope. Its inline TODO ("only scan new package(s) — placeholder: entire target") is already acknowledged — escalate severity to "real scoping fix" for feedback phase.
