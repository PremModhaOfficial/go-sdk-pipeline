<!-- Generated: 2026-04-18T15:10:45Z | Run: sdk-dragonfly-s2 -->
# sdk-skill-coverage-reporter — Wave F4b Context Summary

For downstream `improvement-planner` (F6) and `learning-engine` (F7). Self-contained.

## One-line status

Wave F4b complete. 19 declared skills examined; 16 confirmed invoked-and-used; 3 declared-but-unused (TRIGGERS-GAP or partial-gap); 4 undeclared-but-used (2 expected pipeline-meta laterals, 2 manifest gaps). 8 WARN-absent skills confirmed as active gaps producing synthesized workarounds.

## Counts

| Category | Count |
|---|---|
| Declared in manifest (PRESENT) | 19 |
| Declared in manifest (MISSING/WARN) | 8 |
| Invoked across all phases | 18 |
| Declared-and-invoked (healthy) | 16 |
| Declared-but-unused (TRIGGERS-GAP) | 3 |
| Invoked-but-undeclared (lateral) | 4 |

## Top findings for improvement-planner

1. `go-error-handling-patterns` TRIGGERS-GAP — declared, present, but never cited despite the mapErr 11-step switch being a central impl surface. Root cause: skill description keywords do not match Redis sentinel-switch pattern terminology.

2. `go-example-function-patterns` TRIGGERS-GAP — not in manifest, in index. M6 docs wave produced correct Example_ functions without skill guidance. Root cause: skill not in TPRD template; trigger keywords missing "godoc example", "ExampleCache".

3. `review-fix-protocol` manifest gap — structural D3→D4 devil loop consumed this skill silently. Should be in every Phase-1 run's manifest as an always-on entry.

4. `context-deadline-patterns` manifest gap — 46 methods with ctx-first enforced throughout but skill never declared. Should be in every SDK-client TPRD manifest.

5. `tdd-patterns` partial-gap in Testing — invoked in Impl (M1 red wave, correct) but not cited in Testing phase despite coverage-audit work.

## 8 WARN-absent confirmed active

All 8 WARN-absent skills (sentinel-error-model-mapping, pubsub-lifecycle, hash-field-ttl-hexpire, testcontainers-dragonfly-recipe, k8s-secret-file-credential-loader, redis-pipeline-tx-patterns, lua-script-safety, miniredis-testing-patterns) materialized as real gaps during design and implementation. All are documented in `design/skill-gaps-observed.md`. Priority for human authoring is: `sentinel-error-model-mapping` first (highest reuse), `pubsub-lifecycle` second.

## Healthy skills (no action needed)

sdk-marker-protocol, sdk-semver-governance, sdk-config-struct-pattern, otel-instrumentation, network-error-classification, go-concurrency-patterns, connection-pool-tuning, client-tls-configuration, credential-provider-pattern, go-dependency-vetting, tdd-patterns (impl phase), table-driven-tests, goroutine-leak-prevention, client-shutdown-lifecycle, sdk-otel-hook-integration, testcontainers-setup, testing-patterns, fuzz-patterns — all invoked in expected phases with evidence of application.

## Decision-log entries

seq 100–109 (10 entries; within per-agent-per-run cap of 15).

## Artifacts

- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/runs/sdk-dragonfly-s2/feedback/skill-coverage.md`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/runs/sdk-dragonfly-s2/feedback/context/sdk-skill-coverage-reporter-summary.md`
