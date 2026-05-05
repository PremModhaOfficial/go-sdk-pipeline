# Skill Coverage Report
<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->

**Pipeline version:** 0.1.0  
**Skill-index schema:** 1.1.0  
**Run mode:** A (greenfield)  
**Declared in manifest:** 27 (19 PRESENT, 8 WARN-absent)  

---

## Summary Counts

| Category | Count |
|---|---|
| Declared (manifest, PRESENT) | 19 |
| Declared (manifest, MISSING) | 8 |
| Invoked across all phases | 16 |
| Declared-and-invoked (healthy) | 16 |
| Declared-but-unused (TRIGGERS-GAP) | 3 |
| Invoked-but-undeclared (lateral transfer) | 4 |

---

## Table 1: Invoked Skills — Per Phase

Evidence source: `decision-log.jsonl` seq 1–68, `design/context/*-summary.md`, `impl/context/sdk-impl-lead-summary.md`, `testing/context/sdk-testing-lead-summary.md`, `design/skill-gaps-observed.md`.

| Skill | Intake | Design | Impl | Testing | Evidence |
|---|:---:|:---:|:---:|:---:|---|
| `sdk-marker-protocol` | yes | yes | yes | — | seq 5 G23; seq 22 G43 interface assertions; seq 47 145 markers, G99/G103; impl-summary §marker-guardrail-compliance |
| `sdk-semver-governance` | yes | yes | — | — | seq 5 manifest validation; seq 62 sdk-semver-devil ACCEPT minor; intake-summary semver section |
| `sdk-config-struct-pattern` | yes | yes | yes | — | intake-summary §design-invariant 1 Config+With*; sdk-designer-summary §key-decisions 2; impl-summary runCmd/config |
| `otel-instrumentation` | yes | yes | yes | yes | seq 23 algorithms instrumentedCall; seq 62 T9 observability tests; sdk-designer-summary OTel signals; intake-summary §3 OTel directive |
| `network-error-classification` | yes | yes | yes | — | seq 23 mapErr switch + classify(); skill-gaps-observed §G-1 synthesized from network-error-classification; intake-summary §2 sentinel/mapErr |
| `go-concurrency-patterns` | — | yes | yes | — | seq 24 concurrency.md done+stopped+sync.Once; concurrency-designer-summary goroutine inventory; impl-summary §8 scraper shutdown |
| `connection-pool-tuning` | yes | yes | yes | — | intake-summary §pool-stats-scrape-interval; seq 23 poolstats 10s; pattern-advisor-summary Pool row; impl-summary §8 scraperStopTimeout |
| `client-tls-configuration` | yes | yes | yes | — | intake-summary §6 TLS directive; sdk-designer-summary §key-decisions TLSConfig; pattern-advisor-summary TLS shape row; impl-summary tlsClientConfig |
| `credential-provider-pattern` | yes | yes | yes | — | intake-summary §7 ConnMaxLifetime rotation; seq 27 S-9 credential rotation finding; pattern-advisor-summary §P5a; impl-summary §9 WithCredsFromEnv Dialer |
| `go-dependency-vetting` | yes | yes | — | yes | seq 5 manifest check; seq 61 dep-vet-devil CONDITIONAL; seq 33 H6 osv-scanner/govulncheck; seq 61 T8 supply chain |
| `tdd-patterns` | — | — | yes | — | seq 42 c2 red-phase tests committed before impl (M1 red wave); impl-summary §test-surface red-before-green |
| `table-driven-tests` | — | — | yes | yes | impl-summary §test-surface "table-driven per method"; seq 53 T1 coverage audit referencing table-driven structure |
| `goroutine-leak-prevention` | yes | yes | yes | yes | seq 24 goleak.VerifyTestMain; concurrency-designer-summary goleak G63; impl-summary §2 goleak; seq 59 T6 leak hunt PASS |
| `client-shutdown-lifecycle` | yes | yes | yes | — | intake-summary §close-ordering; seq 24 Close ordering; concurrency-designer-summary close ordering; impl-summary §8 close ordering |
| `sdk-otel-hook-integration` | yes | yes | yes | yes | intake-summary §3 motadatagosdk/otel only; seq 23 instrumentedCall via otel/metrics; seq 62 T9 AST conformance (all spans prefixed dfly., tracer.Start calls) |
| `testcontainers-setup` | — | yes | — | yes | seq 61 dep-vet-devil on testcontainers-go; sdk-designer-summary dep delta; seq 54 T2 real Dragonfly container; seq 56 T3 flake hunt |
| `testing-patterns` | — | — | yes | yes | impl-summary table-driven tests; seq 53 T1 coverage; seq 62 T9 observability suite 270 LOC |
| `fuzz-patterns` | — | — | yes | yes | impl-summary §4 FuzzMapErr+FuzzKeyEncoding; seq 60 T7 fuzz 60s runs |

---

## Table 2: Declared-but-Unused — TRIGGERS-GAP

These skills are PRESENT in the skill-index AND declared in the TPRD §Skills-Manifest, yet no agent cited them by name or rationale in any phase output.

| Skill | Version | Bucket | Phase expected | Gap analysis |
|---|---|---|---|---|
| `go-error-handling-patterns` | 1.0.0 | ported_verbatim | Impl | TRIGGERS-GAP: `mapErr` switch is the primary error-handling surface (11-step precedence chain, fmt.Errorf %w wrapping). The skill exists and covers exactly this pattern. `algorithm-designer` and `sdk-impl-lead` both worked on `mapErr` but cited `network-error-classification` and the TPRD directly rather than invoking this skill. Investigate: skill description may not keyword-match "sentinel", "mapErr", or "switch" chains that appear in Go Redis client contexts. |
| `tdd-patterns` (testing phase only) | 1.0.0 | ported_verbatim | Testing | PARTIAL-GAP: skill was invoked in Impl (M1 red wave), which is correct. However, `sdk-testing-lead` authored T1/T2 coverage audits and gap analysis without any explicit citation of `tdd-patterns`. The testing phase extended existing tests rather than authoring from TDD discipline, so the gap is minor — but indicates the skill's trigger keywords may not activate for coverage-audit work. |
| `go-example-function-patterns` | 1.0.0 | sdk_native | Impl/Testing | TRIGGERS-GAP: TPRD Rule #14 and CLAUDE.md Rule #14 both require `Example_*` functions where applicable. The impl (seq 45, M6 docs wave) explicitly produced `ExampleCache_HExpire` and `godoc Example`. The skill exists in the index but no agent named it. Indicates the skill's description may not be surfaced during docs-wave work. Investigate: add trigger keywords "ExampleCache", "godoc example", "Example_ function" to skill description. |

---

## Table 3: Declared-and-Used (Healthy Baseline)

| Skill | Phase(s) | Notes |
|---|---|---|
| `sdk-marker-protocol` | intake, design, impl | 145 markers, G99/G103 all PASS |
| `sdk-semver-governance` | intake, design | sdk-semver-devil ACCEPT minor |
| `sdk-config-struct-pattern` | intake, design, impl | Config+With* constructor correctly implemented |
| `otel-instrumentation` | intake, design, impl, testing | instrumentedCall + T9 AST conformance suite |
| `network-error-classification` | intake, design, impl | mapErr 11-step switch + classify() 6 labels |
| `go-concurrency-patterns` | design, impl | scraper goroutine pattern + sync.Once |
| `connection-pool-tuning` | intake, design, impl | pool-stats scraper, 10s interval, 1s floor |
| `client-tls-configuration` | intake, design, impl | TLSConfig superset, ServerName enforcement |
| `credential-provider-pattern` | intake, design, impl | Dialer re-read on every dial, K8s rotation |
| `go-dependency-vetting` | intake, design, testing | dep-vet-devil + H6 + T8 supply chain |
| `tdd-patterns` | impl | M1 red-phase committed before M3 green |
| `table-driven-tests` | impl, testing | table-driven per method throughout |
| `goroutine-leak-prevention` | intake, design, impl, testing | goleak.VerifyTestMain + T6 PASS |
| `client-shutdown-lifecycle` | intake, design, impl | Close ordering: scraper.stop → rdb.Close |
| `sdk-otel-hook-integration` | intake, design, impl, testing | motadatagosdk/otel only; T9 AST suite |
| `testcontainers-setup` | design, testing | testcontainers-go v0.42.0; real Dragonfly container |
| `testing-patterns` | impl, testing | 77 passing tests; observability conformance |
| `fuzz-patterns` | impl, testing | FuzzMapErr 659k execs; FuzzKeyEncoding 179k execs |

---

## Table 4: Invoked-but-Undeclared (Lateral Transfer)

Skills from the skill-index that were demonstrably applied but NOT listed in the TPRD §Skills-Manifest. These indicate either good lateral transfer or TPRD manifest gaps.

| Skill | Bucket | Phase | Evidence | Assessment |
|---|---|---|---|---|
| `guardrail-validation` | ported_with_delta | intake, design, testing | seq 6 G24 PASS; seq 21 D2 verdicts; seq 61 T8 supply chain; guardrail-validator agent explicitly operates per this skill | EXPECTED LATERAL — pipeline meta-skill, always active. TPRD manifest focuses on domain skills; this is an infrastructure skill. Not a manifest gap. |
| `decision-logging` | ported_with_delta | all phases | 68 decision-log entries across all agents; every agent respects the JSONL schema | EXPECTED LATERAL — pipeline meta-skill. Same as above. |
| `review-fix-protocol` | ported_verbatim | design | seq 28 D3 NEEDS-FIX; seq 29 D4 iter-1 fix; seq 30 D4 re-run all-accept; design-lead summary review-fix loop | LEGITIMATE TRANSFER — review-fix-protocol governs the D3→D4 devil loop. Should be added to TPRD §Skills-Manifest for any run that will have >0 NEEDS-FIX findings. Signals a TPRD manifest gap: the skill is structurally always used in Phase 1 design. |
| `context-deadline-patterns` | sdk_native | design, impl | intake-summary §context G42 directive; all 46 methods carry ctx first; impl-summary Rule-of-thumb: every I/O method ctx-first | LEGITIMATE TRANSFER — context.Context discipline is exercised throughout. While `go-concurrency-patterns` was declared and covers some of this, `context-deadline-patterns` is the dedicated skill. Signals a TPRD manifest gap for any SDK client TPRD. |

---

## Recommendations for improvement-planner

1. **`go-error-handling-patterns`** — Enhance skill description with keywords "mapErr", "sentinel switch", "fmt.Errorf %w wrapping chain", "precedence order" so agents building Redis/gRPC client error mappers trigger this skill alongside `network-error-classification`.

2. **`go-example-function-patterns`** — Add trigger keywords: "ExampleCache", "godoc example", "Example_ function", "example_test.go", "docs wave". The impl team produced the right output but did so without the skill, meaning its guidance (naming conventions, error-return suppression in examples, testable example pattern) was not consulted.

3. **`review-fix-protocol`** — Add to the standard TPRD §Skills-Manifest template for all Phase 1 design runs. It is structurally consumed in every D3→D4 iteration and should be declared, not lateral.

4. **`context-deadline-patterns`** — Add to the TPRD §Skills-Manifest template for all SDK client TPRDs. Every client with ctx-first I/O methods benefits from the canonical timeout/deadline propagation patterns this skill prescribes.

5. **Missing 8 skills (WARN-absent)** — All 8 are confirmed as active gaps (design/skill-gaps-observed.md documents each "would-have-helped" materialization). Priority for human authoring:
   - `sentinel-error-model-mapping` (highest reuse; affects every SDK client with error mapping)
   - `pubsub-lifecycle` (caller-owns-Close pattern is subtle and recurring)
   - `hash-field-ttl-hexpire` (narrow but prevents Redis 7.4 quirk re-discovery)
   - `testcontainers-dragonfly-recipe` (needed by Phase 3 regardless; currently synthesized from `testcontainers-setup`)
   - `k8s-secret-file-credential-loader`, `redis-pipeline-tx-patterns`, `lua-script-safety`, `miniredis-testing-patterns` — lower priority, closely derived from existing skills

6. **`tdd-patterns` in testing phase** — Review skill description to ensure its trigger activates for coverage-audit and test-extension work, not only for red/green authoring. The testing phase operated in TDD discipline but did not cite the skill.
