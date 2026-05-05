<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->
# phase-retrospector — Phase 4 Context Summary

For downstream: improvement-planner, learning-engine, sdk-skill-coverage-reporter.

## Run identity
- **run_id:** sdk-dragonfly-s2
- **pipeline_version:** 0.1.0
- **phases covered:** intake, design, impl, testing

## Top 5 Cross-Phase Patterns (improvement-planner priority order)

### P1 — TPRD perf constraint unverified against dependency floor (SYSTEMIC, cross-phase)
**Phases:** Intake (accepted without check) → Testing (H8 forced waiver).
**Manifestation:** `≤ 3 allocs per GET` in TPRD §10. go-redis v9 floor is ~25-30 allocs/roundtrip; constraint was mechanically unachievable with the pinned client. Waiver accepted (new target ≤ 35).
**Root cause:** No pipeline step cross-references TPRD numeric constraints against known dep floors before Phase 3.
**Proposed fixes:**
  - G25 (intake I3): constraint feasibility check against `baselines/` or dep docs.
  - G66 (testing T5): bench-devil checks measured floor vs TPRD target; emits CALIBRATION-WARN.
  - `sdk-intake-agent` prompt: add perf-constraint feasibility section.
  - `sdk-benchmark-devil` prompt: pre-classify constraints as CALIBRATION vs REGRESSION before running.

### P2 — MVS-forced dep bumps discovered at impl, not design (SYSTEMIC, cross-phase)
**Phases:** Design (dep-vet CONDITIONAL; scratch-module simulation used, not real go.mod) → Impl (HALT; DEP-BUMP-UNAPPROVED escalation).
**Manifestation:** `testcontainers-go@v0.42.0` forced otel x3 v1.39→v1.41 + klauspost/compress v1.18.4→v1.18.5 via MVS. Halted impl; required unplanned HITL escalation and Option A approval.
**Root cause:** H6 dep-vet ran in a scratch module that did not reflect the full target go.mod; "do not touch untouched deps" directive was issued after H6 was already in progress.
**Proposed fixes:**
  - G36 (design D2): MVS simulation guardrail — `go get <dep> && go mod tidy -json` against a clone of real target go.mod; list forced bumps in D2 output.
  - H1 checklist: add dep-policy section (which deps are untouchable, policy on forced bumps).
  - `sdk-dep-vet-devil` prompt: require real-go.mod simulation alongside license/CVE check.

### P3 — Mode selection ad-hoc rather than formal (intake)
**Phase:** Intake (Mode B in TPRD §16; Mode A per user message).
**Manifestation:** No formal mode-override mechanism. User issued a plain-language directive; pipeline applied it via mode.json with a rationale string. No conflict was missed, but the process is fragile.
**Proposed fixes:**
  - Add `--mode` CLI flag or `§16-override` TPRD field.
  - `sdk-intake-agent` prompt: if §16 mode != run-driver mode, produce `mode-override.md` and require explicit H1 annotation.

### P4 — OTel conformance test produced by testing-lead, not impl-lead (impl skill drift)
**Phases:** Impl (M6 — no static OTel wiring test) → Testing (T9 — observability_test.go authored by testing-lead).
**Manifestation:** impl-lead did not produce a static OTel conformance test asserting span-prefix, bounded labels, and no-key-in-attrs. testing-lead filled the gap via AST analysis (270 LOC, 4 tests).
**Root cause:** impl-lead prompt does not require an OTel conformance test as part of M6 docs wave.
**Proposed fixes:**
  - G44 (impl M9): OTel static conformance guardrail — scan all `runCmd`/`instrumentedCall` sites; assert cmd is string literal, error_class is bounded.
  - `sdk-impl-lead` prompt: add M6 requirement to produce static OTel conformance test.

### P5 — miniredis HPExpire-family gap undocumented in TPRD §11.1 (testing)
**Phase:** Testing (T1 skip, T2 matrix partial).
**Manifestation:** miniredis v2.37.0 does not implement HPExpire/HExpireAt/HTTL/HPersist. This caused 1 graceful test skip at unit level and a matrix gap at integration level. TPRD §11.1 does not enumerate this limitation.
**Proposed fixes:**
  - Require TPRD §11.1 to list commands not covered by the chosen fake client + coverage strategy.
  - G67 (testing T2): integration matrix completeness guardrail.
  - New proposed skill: `miniredis-testing-patterns` (already filed to docs/PROPOSED-SKILLS.md at seq 5).

## Secondary Observations (for improvement-planner consideration)

- **Dep-vet tooling preflight absent:** govulncheck, osv-scanner, benchstat not checked at H0. Propose G35 (tool preflight at pipeline start). Would eliminate the D2 G32/G33 PENDING situation entirely.
- **SDK-overhead-vs-raw constraint UNMEASURED:** TPRD §10 declares ≤5% wrapper overhead; no A/B bench harness was produced. Phase 4 backlog item (Option c intent from H8). Improvement-planner should track this as a gap in the testing skill set.
- **8 missing skills synthesized from adjacent patterns:** `sentinel-error-model-mapping`, `pubsub-lifecycle`, `hash-field-ttl-hexpire` are the highest-priority candidates for human authoring. All 8 filed to `docs/PROPOSED-SKILLS.md`.
- **govulncheck scope ambiguity:** reachability scope for G32 is currently "anywhere in target", which causes pre-existing otel/sdk vuln to appear in dragonfly-phase govulncheck output. Propose explicit dual-scope: dragonfly-deps-only (BLOCKER gate) vs full-target (WARN/observation).

## Artifacts produced
- `runs/sdk-dragonfly-s2/feedback/retro-intake.md`
- `runs/sdk-dragonfly-s2/feedback/retro-design.md`
- `runs/sdk-dragonfly-s2/feedback/retro-impl.md`
- `runs/sdk-dragonfly-s2/feedback/retro-testing.md`
- `runs/sdk-dragonfly-s2/feedback/context/phase-retrospector-summary.md` (this file)
- Decision log entries seq 80–87 (8 entries, within ≤10 cap)

## Improvement counts
- **Guardrail additions proposed:** 7 (G25, G35, G36, G44, G66, G67, and govulncheck scope split)
- **Agent prompt improvements:** 8 (intake x2, dep-vet-devil x1, guardrail-validator x1, impl-lead x2, benchmark-devil x1, integration-test-agent x1)
- **Process changes:** 7 (mode selection, H1 dep-policy, H6 MVS simulation, cross-SDK design standards, TPRD §11.1 fake-client limits, A/B bench harness, H8 pre-classification)
- **Systemic patterns (cross-phase):** 2 (P1 constraint-vs-dep-floor; P2 MVS-forced-bumps)
