<!-- Generated: 2026-04-18T15:05:00Z | Run: sdk-dragonfly-s2 -->
# sdk-skill-drift-detector — Phase 4 Wave F4a Context Summary

For downstream `improvement-planner` (F6) and `learning-engine` (F7). Self-contained.

## Status

Wave F4a COMPLETE. Artifact: `runs/sdk-dragonfly-s2/feedback/skill-drift.md`.
No ESCALATION. No HALT. Zero MAJOR drift.

## Scope

Examined 19 PRESENT skills from TPRD §Skills-Manifest against generated code at `motadata-go-sdk/src/motadatagosdk/core/l2cache/dragonfly/` (branch `sdk-pipeline/sdk-dragonfly-s2` HEAD `a4d5d7f`). 14 production `.go` files + 11 test files + integration build-tagged suite + 2 example tests.

Of the 19 PRESENT, **8 are draft seed-stubs (v0.1.0)** — placeholders with only a `Purpose (seed)` one-liner. Drift measured against seed-purpose plus the TPRD sections that invoked them. 11 skills are stable v1.0.0+ with full prescriptive bodies.

## Drift findings — summary

| Severity | Count | IDs |
|---|---:|---|
| NONE | 14 | SKD-002, 003, 004, 006, 007, 008, 009, 010, 011, 014, 015, 016, 017, 018, 019 |
| MINOR | 3 | SKD-001, 012, 013 |
| MODERATE | 1 | SKD-005 |
| MAJOR | 0 | — |

### MINOR findings

- **SKD-001** `sdk-config-struct-pattern`: code uses `Config struct + New(opts ...Option)` (functional options) not `New(cfg Config)`. **Authorized divergence** per TPRD §6 and CLAUDE.md Rule #6; matches sibling `motadatagosdk/events` convention.
- **SKD-012** `testcontainers-setup`: integration tests boot a fresh Dragonfly container per test (no sync.Once reuse). Integration suite is 14+ seconds for 2 live tests; doesn't scale if TPRD §11.2 TLS/ACL matrix is added. Recommendation flows to the future `testcontainers-dragonfly-recipe` skill (currently WARN-absent).
- **SKD-013** `table-driven-tests`: Zero `t.Parallel()` calls despite `newTestCache` booting a fresh miniredis per subtest (would be safe). Missed speed-up.

### MODERATE finding

- **SKD-005** `go-error-handling-patterns`: Not invoked despite being declared (per skill-coverage.md §Table 2). The skill's stable body prescribes an `AppError` hierarchy tuned for NATS/HTTP services. TPRD §1 explicitly rejects AppError for SDK clients ("no custom error types"). Actual code follows the mid-level guidance (sentinel + `fmt.Errorf("%w: %v", ...)`). **Skill-library drift**: either split into service-mode and SDK-client-mode sub-skills, or expand body with a decision branch.

### NONE — worth highlighting

Strong alignment on: OTel via `motadatagosdk/otel/*` only (SKD-002, 003; locked in by T9 AST suite), `mapErr` 26-sentinel taxonomy (SKD-004), goroutine leak prevention with bounded 5s scraper stop (SKD-007), credential rotation via `CredentialsProviderContext` + `ConnMaxLifetime` (SKD-011), 145 `[traces-to:]` markers with 100% exported-symbol coverage (SKD-017), fuzz corpus with 16 seeds + property assertions (SKD-015).

## WARN-absent skills — compensation map

All 8 WARN-absent skills were filed to `docs/PROPOSED-SKILLS.md` at intake. Per `design/skill-gaps-observed.md`, agents compensated by synthesizing from in-pipeline general patterns. Key observations for human skill authors:

- `sentinel-error-model-mapping` — dragonfly's 11-step precedence mapErr is the reference implementation.
- `pubsub-lifecycle` — caller-owns-Close contract documented in `pubsub.go:23` could seed the skill body.
- `hash-field-ttl-hexpire` — `secondsToDurations` helper preserves negative-wire sentinels (-1 no TTL, -2 no field).
- `testcontainers-dragonfly-recipe` — sync.Once shared-container pattern NOT yet codified (SKD-012 gap).
- `k8s-secret-file-credential-loader` — env-pointer + file-content + reloadPassword/reloadUsername is novel target-SDK idiom.

## Recommendations for improvement-planner (F6)

1. **Skill-library action (highest leverage):** promote the 8 draft seed-stubs that this run exercised (sdk-config-struct-pattern, sdk-otel-hook-integration, network-error-classification, goroutine-leak-prevention, client-shutdown-lifecycle, client-tls-configuration, connection-pool-tuning, credential-provider-pattern, sdk-marker-protocol, sdk-semver-governance, go-dependency-vetting) from draft v0.1.0 to stable v1.0.0 — use dragonfly code as the canonical worked example. This is a human-authored minor bump, not a learning-engine patch.
2. **SKD-005 skill-library action:** split or branch `go-error-handling-patterns` for service-mode vs SDK-client-mode.
3. **Minor code action (optional):** add `t.Parallel()` to table-driven tests in dragonfly (SKD-013). Not load-bearing.
4. **Defer:** SKD-012 integration-suite matrix (TLS/ACL) — will be addressed when `testcontainers-dragonfly-recipe` is authored.

## Recommendations for learning-engine (F7)

Constrained to patch-level (Z-bump) changes this run per F5 advisory (empty golden-corpus). F4a did not surface any drift that requires a minor/major skill patch. Safe patch candidates:

- `go-error-handling-patterns` v1.0.0 → v1.0.1 — append note to body: "For SDK clients that require sentinel-only error models, see TPRD §Skills-Manifest declaration of `network-error-classification` + dragonfly run `sdk-dragonfly-s2` for reference implementation." Patch-level, additive documentation only, no signature change.

## Guardrail interaction

No guardrail violated by this wave. G01 decision-log entries appended (5 entries, seq 90-94). G02 entry-cap respected (5 entries, well under 15).

## Handoff

Next wave: F6 `improvement-planner`. Inputs: this summary + `feedback/skill-coverage.md` Tables 2+4 + `feedback/metrics.json` + `feedback/golden-regression.json` (N/A empty-corpus) + `feedback/retro-{intake,design}.md`.

No blockers. Phase 4 proceeds.
