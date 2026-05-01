# Phase 1: Design

## Purpose

Turn canonical TPRD into an implementation-ready API design. Adversarial review catches painful APIs, unjustified deps, breaking changes, convention deviations, and security gaps BEFORE code is written.

## Input

- `runs/<run-id>/tprd.md`
- `runs/<run-id>/extension/current-api.json` (Mode B/C only, from Phase 0.5)
- `runs/<run-id>/ownership-map.json` (Mode B/C only)
- Target SDK tree (read)
- Skill library (invoked by agents)

## Waves

### Wave D1 — Parallel Design Agents
Run concurrently, one context summary each. All write to `runs/<run-id>/design/`.

| Agent | Output |
|-------|--------|
| `sdk-designer` | `package-layout.md`, `api.<lang>.stub`, `dependencies.md` |
| `interface-designer` | `interfaces.md` — port/adapter interfaces, error types |
| `algorithm-designer` | `algorithms.md` — retry/backoff, CB thresholds, pool sizing, health probe |
| `concurrency-designer` | `concurrency.md` — concurrency-unit ownership, context cancellation, graceful-close sequence |
| `pattern-advisor` | `patterns.md` — functional options vs. Config+New rationale, hexagonal layering for the new package |

### Wave D2 — Mechanical Checks
**Agent**: `guardrail-validator`
Runs G30–G38, G32 (vulnerability scanner on proposed deps), G33 (lockfile vulnerability scanner), G34 (license allowlist). Any BLOCKER failure → back to D1 for the relevant agent.

### Wave D3 — Devil Review (parallel)

| Agent | Role | Output |
|-------|------|--------|
| `sdk-design-devil` | Find painful APIs: param count >4, exposed internals, concurrency-unit ownership ambiguity, non-idiomatic naming | `reviews/design-devil.md` |
| Dep-Vet Devil (per-pack) | License / CVE / maintenance / size on new deps | `reviews/dep-vet-devil.md` |
| `sdk-semver-devil` | API-diff vs. existing; flag breaking changes | `reviews/semver-devil.md` |
| Convention Devil (per-pack) | Match target SDK conventions (Config+New, otel/, pool/, circuitbreaker/) | `reviews/convention-devil.md` |
| `sdk-security-devil` | TLS defaults, credential handling, log-PII, input validation | `reviews/security-devil.md` |
| Breaking-Change Devil (Mode B/C, per-pack) | Mode B/C only: enumerate breakage vs. `current-api.json` | `reviews/breaking-change-devil.md` |
| Constraint Devil (per-pack) | Mode B/C only: verify each `[constraint]` in target files can still hold | `reviews/constraint-devil.md` |

Verdict format per devil: ACCEPT / NEEDS-FIX / REJECT with prefix-id findings (`DD-<n>`).

### Wave D4 — Review-Fix Loop
Ported `review-fix-protocol`:
- Dedup findings across devils
- Per-finding retry cap 5
- Stuck detection at 2 non-improving iterations
- Fixes routed to the owning design agent (usually `sdk-designer`)
- Re-run ALL devils after each fix batch (rule #13)

### Wave D5 — HITL Gates

| Gate | Trigger | Artifact |
|------|---------|----------|
| H6 Dep Vet | Dep-Vet Devil (per-pack) = CONDITIONAL (not REJECT) | `reviews/dep-rationale.md` |
| H4 Breaking | Mode B/C + Breaking-Change Devil (Mode B/C, per-pack) finds break | `breaking-changes.md` |
| H5 Design | End of design phase | `design-summary.md` + `api.<lang>.stub` |

## Exit artifacts

- `runs/<run-id>/design/api.<lang>.stub` (compiles via `toolchain.build`)
- `runs/<run-id>/design/package-layout.md`
- `runs/<run-id>/design/interfaces.md`
- `runs/<run-id>/design/algorithms.md`
- `runs/<run-id>/design/concurrency.md`
- `runs/<run-id>/design/dependencies.md` (every new dep justified)
- `runs/<run-id>/design/reviews/*.md` (devil outputs)
- `runs/<run-id>/design/design-summary.md` (lead's rollup)

## Guardrails (exit gate)

G30 (stub compiles), G31 (deps documented), G32 (vulnerability scanner — `toolchain.supply_chain[0]`), G33 (lockfile vulnerability scanner), G34 (license), G35 (semver), G36 (conventions), G37 (naming), G38 (no multi-tenancy).

## Metrics

- `design_findings_total` (by severity)
- `design_devil_block_rate` (target <20%)
- `design_rework_iterations` (target <3)
- `design_token_consumption`
- `proposed_deps_count` / `deps_rejected_count`

## Mode B/C additions

Mode B/C runs Wave 0.5 BEFORE this phase. That phase produces `current-api.json`, `test-baseline.json`, `bench-baseline.txt`, `ownership-map.json`. Design agents read all these. `sdk-semver-devil` + Breaking-Change Devil (Mode B/C, per-pack) compare proposed API against `current-api.json`. Constraint Devil (per-pack) loads `ownership-map.json` and verifies every `[constraint]` invariant will hold post-change.

## Typical durations

- Mode A simple (e.g., S3 client): ~45 min + review time
- Mode B (JetStream batching on existing events/): ~60 min (extra analyzer phase + breaking-change-devil)
- Mode C (dragonfly retry tighten): ~30 min (smaller scope, constraint-heavy)
