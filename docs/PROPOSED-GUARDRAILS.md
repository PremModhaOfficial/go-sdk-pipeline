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
    - Look up baselines/performance-baselines.json[<dep>][<metric>] or dep release-notes floor.
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
    look up dep floor from baselines/performance-baselines.json or G25's intake report.
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
