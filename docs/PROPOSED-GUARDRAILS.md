# Proposed Guardrails (Human-Review Backlog)

Entries from pipeline runs are auto-filed here by `improvement-planner` (Wave F6). They never block a run and are never promoted at runtime. Promotion to `scripts/guardrails/G<NN>.sh` is a human PR action.

## Workflow

1. Entry lands here with `status: proposed` + motivation + source run + suggested phase + check pseudocode.
2. Human author drafts `scripts/guardrails/G<NN>.sh` following the existing guardrail script conventions (exit 0 = PASS, exit 1 = FAIL, exit 2 = WARN).
3. Human opens PR; reviewers include the phase-owner-agent owner and one devil-agent owner.
4. On merge: entry flipped to `status: promoted` with commit SHA + link to script.
5. Any TPRD §Guardrails-Manifest may then reference the new guardrail.

## Existing proposals

| ID | Guardrail | Phase | Motivation | Source run | Status |
|---|---|---|---|---|---|
| G25 | Perf-constraint vs dep-floor check | Intake (I3) | Catches aspirational TPRD §10 numeric constraints before Phase 3 | sdk-dragonfly-s2 | proposed |
| G35 | Tool preflight (govulncheck + osv-scanner + benchstat + staticcheck) | Pre-intake / H0 | Eliminates PENDING verdicts caused by tool absence at D2 | sdk-dragonfly-s2 | proposed |
| G36 | MVS simulation vs real target go.mod | Design (D2) | Surfaces forced dep bumps before impl phase | sdk-dragonfly-s2 | proposed |
| G44 | OTel static conformance test exists | Impl (M6 or M9) | Catches OTel wiring drift without live exporter | sdk-dragonfly-s2 | proposed |
| G66 | Bench constraint calibration warning | Testing (T5) | Pre-classifies mechanically unachievable constraints as CALIBRATION-WARN | sdk-dragonfly-s2 | proposed |
| G67 | Integration matrix completeness | Testing (T2) | Surfaces integration TLS/ACL matrix gaps vs TPRD §11.2 | sdk-dragonfly-s2 | proposed |
| G68 | TPRD §11.1 fake-client-exclusion enumeration | Intake (I2) | Requires TPRD §11.1 to list commands not covered by miniredis/fake | sdk-dragonfly-s2 | proposed |

## Policy

- **No auto-promotion.** Pipeline emits entries; does not write guardrail scripts.
- **No runtime creation.** `new_guardrails_per_run = 0` per `settings.json § safety_caps`.
- **Devil-fleet gate on first use.** Newly promoted guardrails should be exercised on the next pipeline run before counting as stable (pipeline does not run golden-corpus full-replay regression).

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-18

Source: `improvement-planner` Wave F6, derived from retro patterns P1/P2/P4/P5 and anomaly flags A1/A2/A3.

### G25 — Perf-constraint dep-floor check (HIGH confidence)

- **Phase**: Intake (Wave I3 — before H1 closes).
- **Motivation**: TPRD §10 declared `allocs_per_GET ≤ 3`. go-redis v9 floor is ~25-30. The constraint reached Phase 3 unverified and triggered an H8 waiver. Cost: ~30 min of H8 loop that could have closed at H1.
- **Check logic**:
  ```
  For each TPRD §10 constraint marker [constraint: <metric> <op> <value> | bench/<name>]:
    - Resolve the underlying dep from TPRD §6 (e.g. go-redis v9.18).
    - Look up baselines/go/performance-baselines.json[<dep>][<metric>] or dep release-notes floor.
    - If target < floor * 0.9: emit WARN with constraint, target, floor, reference.
    - If target > 2 * floor: emit INFO (over-specified; not a problem).
    - Else: PASS.
  ```
- **Pass criteria**: All constraints either pass floor check or have explicit `accept-aspirational: true` annotation in TPRD §10.
- **Fail criteria**: BLOCKER only if TPRD has an `accept-aspirational` annotation that was falsified by baselines data. Otherwise WARN (non-blocking, filed to intake report).
- **Consumer**: `sdk-intake-agent` (runs the check), `sdk-benchmark-devil` (honors the calibration at T5 per G66).

### G35 — Tool preflight (MEDIUM confidence)

- **Phase**: Pre-intake / H0.
- **Motivation**: `govulncheck` and `osv-scanner` were absent at D2 execution, causing G32/G33 PENDING for 2 waves until H6. Mid-run tooling installation is a process smell.
- **Check logic**:
  ```
  For each required tool in [govulncheck, osv-scanner, benchstat, staticcheck, go-mutesting-or-gremlins]:
    if not on PATH and not a null-fallback tool:
      emit WARN (or BLOCKER if tool is used by a declared BLOCKER guardrail this run).
  ```
- **Pass criteria**: All tools required by the TPRD §Guardrails-Manifest's BLOCKER entries are on PATH.
- **Fail criteria**: BLOCKER if a tool used by a BLOCKER guardrail is absent. WARN otherwise.
- **Consumer**: Pre-intake H0 preflight.

### G36 — MVS simulation vs real target go.mod (HIGH confidence)

- **Phase**: Design (D2, before H5).
- **Motivation**: `testcontainers-go@v0.42.0` forced otel × 3 + klauspost/compress bumps that were only discovered at impl wave M3. HITL re-opening + run-driver option-decision at H6 cost ~45 min of unplanned loop.
- **Check logic**:
  ```
  Clone target_repo/go.mod to runs/<run-id>/design/mvs-scratch/
  For each proposed new dep in design/dependencies.md:
    cd mvs-scratch && go get <dep>@<version> && go mod tidy -json > mvs-diff-<dep>.json
    diff vs baseline go.sum, record every existing-direct-dep forced bump.
  Cross-reference bumped list vs H1 dep-untouchable list:
    if intersection non-empty: emit BLOCKER with DEP-POLICY-CONFLICT-AT-DESIGN.
    if non-empty but no untouchable policy: emit WARN (must be explicitly approved at H6).
    if empty: PASS.
  ```
- **Pass criteria**: Forced-bump list is empty OR all bumps are explicitly approved at H6.
- **Fail criteria**: BLOCKER when bumped dep is on untouchable list; WARN otherwise.
- **Consumer**: `sdk-dep-vet-devil` (D2), `sdk-design-lead` (H6 prep).

### G44 — OTel static conformance (MEDIUM confidence)

- **Phase**: Impl (M6 Docs wave or M9 Mechanical wave — owner is `sdk-impl-lead`).
- **Motivation**: In sdk-dragonfly-s2 the static OTel conformance test was authored by `sdk-testing-lead` at T9 instead of by `sdk-impl-lead` at M6. Shift-left to impl ownership and catch wiring drift without needing a live exporter.
- **Check logic**:
  ```
  Scan <pkg>/*.go for all call sites of the instrumentation helper (instrumentedCall / runCmd / similar).
  Assert (via AST or grep with AST backup):
    - cmd arg is a compile-time string literal (reject identifiers, struct-field access, fmt.Sprintf).
    - span attribute names are NOT in forbidden-attr list {"password","secret","token","key","value","payload"}.
    - span names use the package's declared stable prefix (e.g. dfly., s3., kafka.).
    - error recording goes through motadatagosdk/otel wrapper, not raw go.opentelemetry.io/otel.
  Require existence of <pkg>/observability_test.go containing TestObservability_* functions covering above.
  ```
- **Pass criteria**: All assertions pass + `observability_test.go` exists and is part of `go test` run.
- **Fail criteria**: BLOCKER if wiring violates invariants; WARN if observability_test.go is missing but invariants hold in source.
- **Consumer**: `sdk-impl-lead`, `sdk-testing-lead` (read-only validation).

### G66 — Bench constraint calibration (MEDIUM confidence)

- **Phase**: Testing (T5).
- **Motivation**: allocs-per-GET ≤ 3 vs go-redis v9 floor of ~25-30 forced a reactive H8. Pre-classifying unachievable constraints at T5 converts reactive H8 into a CALIBRATION-WARN with Option A pre-recommended.
- **Check logic**:
  ```
  For each TPRD §10 constraint that just FAILED bench:
    look up dep floor from baselines/go/performance-baselines.json or G25's intake report.
    if measured ≈ floor AND target << floor:
      reclassify as CALIBRATION-WARN (not FAIL);
      emit H8 with Option A (baseline update) recommended.
    if measured >> floor:
      classify as FAIL (wrapper overhead is the defect).
  ```
- **Pass criteria**: N/A — this guardrail reclassifies, it does not add a new BLOCKER.
- **Fail criteria**: N/A.
- **Consumer**: `sdk-benchmark-devil`, `sdk-testing-lead`.

### G67 — Integration matrix completeness (LOW-MEDIUM confidence)

- **Phase**: Testing (T2).
- **Motivation**: TPRD §11.2 declared TLS/ACL matrix; actual integration covered basic-flow + HExpire only. Chaos-kill, TLS on/off, ACL on/off remain skeleton/skip. H9 accepted the gap but it is still a spec-coverage miss.
- **Check logic**:
  ```
  Parse TPRD §11.2 matrix cells. Count test functions in <pkg>/<pkg>_integration_test.go whose name or t.Run sub-name references each cell.
  Emit WARN if any cell has 0 test functions.
  ```
- **Pass criteria**: Every declared matrix cell has ≥1 integration test.
- **Fail criteria**: WARN (not BLOCKER) when a cell is empty.
- **Consumer**: `integration-test-agent`, `sdk-testing-lead`.

### G68 — TPRD §11.1 fake-client-exclusion enumeration (LOW confidence)

- **Phase**: Intake (I2, §Skills-Manifest validation adjacency).
- **Motivation**: `miniredis/v2` does not support Redis 7.4 HEXPIRE-family commands. TPRD §11.1 did not document this exclusion; the skip surprised the test phase.
- **Check logic**:
  ```
  If TPRD §11.1 references a fake-client (miniredis, localstack, etc.):
    require a subsection "not-covered-by-fake-client:" enumerating unsupported commands/APIs
    AND a "coverage-strategy:" line (integration | skip-with-comment | accept-gap).
  ```
- **Pass criteria**: Both subsections present.
- **Fail criteria**: WARN if TPRD references a fake without either subsection.
- **Consumer**: `sdk-intake-agent`.

---

## Cap respected

Per `settings.json § safety_caps.new_guardrails_per_run = 0`, none of the above are created at runtime. All entries are filed here for human PR promotion only.

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-18

Source: `improvement-planner` Wave F6, derived from retro patterns P1/P2/P4/P5 and anomaly flags A1/A2/A3.

### G25 — Perf-constraint dep-floor check (HIGH confidence)

(See body above.)

---

## Auto-filed from run `sdk-dragonfly-p1-v1` on 2026-04-22 (G24 BLOCKER halt)

Source: `sdk-intake-agent` Wave I3. G24 BLOCKER-failed on 10 declared guardrails whose scripts do not exist at `scripts/guardrails/<id>.sh`. Pipeline halted with exit 6 before Phase 0.5. Each entry below maps to pipeline `CLAUDE.md` rule-set 28 (learning-engine safeguards) and rule-set 32 (Performance-Confidence Regime) and requires human PR authorship before this TPRD (or any TPRD referencing these IDs) can clear intake.

| ID | Guardrail | Phase | Severity | Motivation | Source run | Status |
|---|---|---|---|---|---|---|
| G81 | Baselines updated or rationale | Feedback | BLOCKER | Rule 28 compensating baselines (1, 2, 4) require per-run updates to `baselines/go/output-shape-history.jsonl`, `baselines/go/devil-verdict-history.jsonl`, `baselines/go/coverage-baselines.json`. Guardrail asserts either the baseline file advanced or the feedback report carries a rationale for the skip. | sdk-dragonfly-p1-v1 | proposed |
| G83 | Every patch logged in skill evolution-log.md | Feedback | BLOCKER | Per Rule 23, any body-patch `learning-engine` applies to an existing skill must append a line to that skill's adjacent `evolution-log.md` with minor-bump semantics. Guardrail diffs the skill's git-HEAD version frontmatter against its log and fails if patches landed without a matching log entry. | sdk-dragonfly-p1-v1 | proposed |
| G84 | Per-run safety caps respected | Feedback | BLOCKER | Mechanical check against `settings.json § safety_caps` — counts of `prompt_patches`, `existing_skill_patches`, `new_skills`, `new_guardrails`, `new_agents` applied in the current run must not exceed the declared cap. Catches a runaway learning-engine before F-phase exit. | sdk-dragonfly-p1-v1 | proposed |
| G104 | Alloc-budget per declared `allocs_per_op` | Impl (M3.5) | BLOCKER | Rule 32 axis 3 (allocation). `sdk-profile-auditor` runs declared benches with `b.ReportAllocs()`, reads `design/perf-budget.md` per-symbol `allocs_per_op`, fails the gate on any symbol whose measured allocs exceeds budget. Runs BEFORE T5 so alloc overruns never reach testing phase. | sdk-dragonfly-p1-v1 | proposed |
| G105 | Soak-MMD (minimum-measurable-duration) enforcement | Testing (T-SOAK) | BLOCKER | Rule 32 axis 6 + rule 33 verdict taxonomy. Any soak verdict marked PASS must satisfy `actual_duration_s ≥ mmd_seconds` from `design/perf-budget.md`. Shorter runs return INCOMPLETE, not PASS. Prevents silent timeout-to-PASS promotion. P1 no-ops this gate (no soak-enabled symbol declared in TPRD). | sdk-dragonfly-p1-v1 | proposed |
| G106 | Soak-drift detector | Testing (T-SOAK) | BLOCKER | Rule 32 axis 6. `sdk-drift-detector` curve-fits declared soak signals (e.g. RSS, goroutine count, pool-checkout latency p99) over the soak window and fails on a statistically significant positive trend. P1 no-ops (no soak enabled). | sdk-dragonfly-p1-v1 | proposed |
| G107 | Complexity scaling sweep | Testing (T5) | BLOCKER | Rule 32 axis 4. `sdk-complexity-devil` runs each declared hot-path symbol at `N ∈ {10, 100, 1k, 10k}`, curve-fits measured latency vs N, and compares to the declared big-O in `perf-budget.md`. Catches accidental quadratic paths that pass wall-clock gates at microbench sizes. This TPRD declares `ZRangeWithScores` O(log N + M) and the `Scan` iterator O(N) amortized. | sdk-dragonfly-p1-v1 | proposed |
| G108 | Oracle-margin vs reference impl | Testing (T5) | BLOCKER | Rule 32 axis 5. Measured p50 must stay within `oracle.margin_multiplier × reference_impl_ns_per_op` declared in `perf-budget.md`. NOT waivable via `--accept-perf-regression`; oracle-waiver requires an H8 decision + written margin update. TPRD declares GetJSON≤1.5× raw Get, SetJSON≤1.5× raw Set. | sdk-dragonfly-p1-v1 | proposed |
| G109 | Profile-no-surprise hotspot check | Impl (M3.5) | BLOCKER | Rule 32 axis 2. `sdk-profile-auditor` reads CPU/heap/block/mutex pprof output; top-10 CPU samples must cover ≥0.8 of the declared hot paths in `perf-budget.md`; any hot function not in the declared set is a surprise hotspot and a BLOCKER. Catches design-reality drift before testing. TPRD declares hot paths: `instrumentedCall`, `mapErr`, keyprefix concat. | sdk-dragonfly-p1-v1 | proposed |
| G110 | `[perf-exception:]` marker ↔ `perf-exceptions.md` pairing | Impl (M7+M9) | BLOCKER | Rule 32 axis 7 + rule 29 marker protocol. Any source-line bearing `[perf-exception: <reason> bench/BenchmarkX]` must have a matching entry in `runs/<run-id>/design/perf-exceptions.md` declaring the exception at design time AND a profile-auditor-measured bench win. Orphan markers (no matching entry) fail the gate. P1 expects zero `[perf-exception:]` markers (no hand-optimized paths). | sdk-dragonfly-p1-v1 | proposed |

### Halt contract

Per command spec §Exit codes and `commands/run-sdk-addition.md`, this is an **exit 6** halt. The run-summary marks intake BLOCKED and H1 is not asked. The remaining waves (I4 clarifications, I5 mode detection, I6 completeness, I7 H1 gate) are skipped; Phase 0.5 extension-analyze does not run. Re-run requires either (a) human-authored scripts at `scripts/guardrails/G{81,83,84,104,105,106,107,108,109,110}.sh` + `chmod +x`, or (b) a TPRD revision that drops the unresolved IDs from §Guardrails-Manifest (not recommended — rule 32 axes 2-7 are load-bearing for the TPRD's declared perf targets in §10).

---

## Auto-filed from run `sdk-resourcepool-py-pilot-v1` on 2026-04-28 (F2 improvement-planner)

Source: `improvement-planner` Wave F2 of Phase 4 feedback. First Python pilot (v0.5.0 Phase B).
Derived from: intake-retro G90 BLOCKER pattern, impl-retro M10 Fix 3 (py-spy), testing-retro
heap_bytes drift false-positive, impl-retro M10 Fix 1 (bench-harness shape), intake-retro
G23 WARN on `feedback-analysis` SKILL.md frontmatter.

### G-SCHEMA-SECTION-COVERAGE — Skill-index schema-section coverage (HIGH confidence)

- **Phase**: Intake (Pre-G90; runs at I0/H1 preflight).
- **Severity**: BLOCKER.
- **Motivation**: G90 BLOCKER at H1 caused by hardcoded section list (`ported_verbatim`,
  `ported_with_delta`, `sdk_native`) failing to iterate the new `python_specific` section
  added in v0.5.0 Phase A schema 1.1.0. Required user-authorized out-of-band patch to G90.sh.
  Schema evolution outpacing guardrail body is a recurring class.
- **Check logic**:
  ```
  Read .claude/skills/skill-index.json → enumerate top-level keys under .skills.*
  For each guardrail at scripts/guardrails/G*.sh that references skill-index.json:
    grep the script for hardcoded section names matching .skills.*
    if any current schema section is NOT referenced (and the script iterates by literal name): emit BLOCKER
  ```
- **Pass criteria**: every `skills.*` schema section is iterated by every guardrail that walks
  the index (or the guardrail uses a generic `skills.*` glob).
- **Fail criteria**: BLOCKER on first hardcoded gap.
- **Consumer**: pre-G90 preflight; consumed by `sdk-intake-agent` H1 closure.

### G-PY-SPY-INSTALLED — py-spy installed in venv (HIGH confidence)

- **Phase**: Impl (M3.5 preflight; runs only when G109 is in active-packages).
- **Severity**: BLOCKER (gated on G109 active).
- **Motivation**: py-spy was not pre-installed; G109 returned "INCOMPLETE for strict
  surprise-hotspot" at M3.5; M10 ad-hoc install resolved. Preflight removes the round-trip.
- **Check logic**:
  ```
  if G109 in active-packages.json AND target_language == "python":
    which py-spy || pip show py-spy || emit BLOCKER "py-spy required for G109 strict mode"
  ```
- **Pass criteria**: py-spy on PATH or installed in venv.
- **Fail criteria**: BLOCKER if absent and G109 active.
- **Consumer**: `sdk-impl-lead` (M3.5 preflight); `sdk-profile-auditor`.

### G-DRIFT-MAGNITUDE — Drift-detector magnitude floor (MEDIUM confidence)

- **Phase**: Testing (T5.5 drift verdict).
- **Severity**: WARN-only (does not BLOCKER; reclassifies trivial drifts as PASS-with-note).
- **Motivation**: sdk-drift-detector triggered statistically significant positive trend on
  `heap_bytes` (\|t\|=14.97) at slope 0.07 bytes / million ops — operationally negligible
  GC oscillation. Controlling signals (Gen1, Gen2) flat. Annotated PASS in-phase but the
  alarm consumed reviewer attention.
- **Check logic**:
  ```
  For each drift signal that reports FAIL (significant slope):
    compute total_drift = slope × MMD_seconds × ops_per_sec
    if total_drift < magnitude_floor (configurable per signal; e.g. 1KB for heap_bytes):
      reclassify as PASS-WITH-NOTE; do not block.
  ```
- **Pass criteria**: N/A (reclassifier).
- **Fail criteria**: N/A.
- **Consumer**: `sdk-drift-detector`.

### G-HARNESS-SHAPE — Bench-harness shape sanity (MEDIUM confidence)

- **Phase**: Impl (M3.5 / M7 bench review).
- **Severity**: WARN.
- **Motivation**: `bench_try_acquire` measured 7.2 µs because async-release overhead
  polluted the timed window; counter-mode harness BATCH=128 isolated the actual op (71 ns).
  Catches harness-shape errors pre-devil-review. Recurring pattern: sdk-dragonfly-s2 also
  required late-stage bench harness rework.
- **Check logic**:
  ```
  For each bench function in tests/bench/ (Python: pytest-benchmark fixtures; Go: Benchmark*):
    parse the timed window (the fn body or pytest-benchmark.pedantic loop)
    if any await/<-chan/synchronous-blocking-IO/release call appears inside the timed window
      AND the function name contains keywords like "try", "fast", "sync":
      emit WARN: "potential async-overhead pollution; consider counter-mode harness"
  ```
- **Pass criteria**: timed window contains only the operation under measurement.
- **Fail criteria**: WARN (not BLOCKER); reviewer judges.
- **Consumer**: `sdk-impl-lead`, `sdk-benchmark-devil`.

### G-SKILLMD-VERSION — SKILL.md frontmatter version present (LOW confidence)

- **Phase**: Intake (I2 §Skills-Manifest validation adjacency).
- **Severity**: WARN.
- **Motivation**: `feedback-analysis` SKILL.md missing `version:` frontmatter field (G23
  WARN this run). skill-index.json had the correct version 1.0.0 so the run proceeded, but
  the SKILL.md body was the source of truth gap. Defense-in-depth on rule 23.
- **Check logic**:
  ```
  for each .claude/skills/<name>/SKILL.md:
    head -20 SKILL.md | grep -E "^version:\s*[0-9]+\.[0-9]+\.[0-9]+" || emit WARN
  ```
- **Pass criteria**: every SKILL.md has `version: X.Y.Z` in frontmatter.
- **Fail criteria**: WARN per missing skill (non-blocking).
- **Consumer**: `sdk-intake-agent` Wave I2.

---

## Cap respected

Per `settings.json § safety_caps.new_guardrails_per_run = 0`, none of the above are created at runtime. All entries are filed here for human PR promotion only.
