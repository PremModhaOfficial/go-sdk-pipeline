<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: sdk-skill-coverage-reporter | Phase: 4 -->

# Skill Coverage Report — `sdk-resourcepool-py-pilot-v1`

**Run**: sdk-resourcepool-py-pilot-v1 | **Language**: Python | **Pipeline**: 0.5.0 | **Mode**: A (new package) | **Tier**: T1

---

## Method note — implicit-citation mode

No entry in `decision-log.jsonl` (98 entries, 15-per-agent cap respected) cites a skill name directly in `decision.rationale` or `communication.tags`. This is expected for a first Python pilot: agents apply skill prescriptions without emitting skill-tagged log entries (skill-name tagging is a Go-run convention not yet ported to the Python adapter). Invocation evidence is therefore reconstructed from:

1. **Behavioral match**: agent artifact content maps to the skill's prescribed behavior (strongest signal).
2. **Design-lead brief / impl-lead brief**: explicit cross-references to design contracts that only make sense if the skill was applied.
3. **Devil-review findings**: reviewer reasoning references concepts that align with specific skill domains.

Each invocation is rated **DIRECT** (skill body prescription demonstrably followed) or **INFERRED** (skill domain was active; prescription may have been partially followed).

---

## Per-Skill Table

| # | Skill | Min ver | In §Skills-Manifest | Invoked ≥1 agent | Agent(s) | Invocation count | Evidence type | Expected-but-unused? |
|---|---|---|---|---|---|---|---|---|
| 1 | `python-asyncio-patterns` | 1.0.0 | YES | YES | concurrency, algorithm, sdk-impl-lead, sdk-testing-lead | 4 | DIRECT | No |
| 2 | `python-class-design` | 1.0.0 | YES | YES | designer, pattern-advisor, interface, sdk-impl-lead | 4 | DIRECT | No |
| 3 | `pytest-table-tests` | 1.0.0 | YES | YES | sdk-impl-lead, sdk-testing-lead | 2 | DIRECT | No |
| 4 | `asyncio-cancellation-patterns` | 1.0.0 | YES | YES | concurrency, sdk-impl-lead, sdk-testing-lead | 3 | DIRECT | No |
| 5 | `tdd-patterns` | 1.0.0 | YES | YES (partial) | sdk-impl-lead | 1 | INFERRED | No — used; see D2 §debt-bearer analysis |
| 6 | `idempotent-retry-safety` | 1.0.0 | YES | NO | — | 0 | — | EXPECTED-UNUSED (not a gap — see §gap analysis) |
| 7 | `network-error-classification` | 1.0.0 | YES | NO | — | 0 | — | EXPECTED-UNUSED (border-case; see §gap analysis) |
| 8 | `spec-driven-development` | 1.0.0 | YES | YES | sdk-intake-agent, sdk-design-lead, designer, sdk-impl-lead | 4 | DIRECT | No |
| 9 | `decision-logging` | 1.1.0 | YES | YES | all agents (98 entries across 15 agents) | 15 | DIRECT | No |
| 10 | `guardrail-validation` | 1.1.0 | YES | YES | sdk-intake-agent, sdk-design-lead, sdk-impl-lead, sdk-testing-lead | 4 | DIRECT | No |
| 11 | `review-fix-protocol` | 1.0.0 | YES | YES | sdk-design-lead, sdk-impl-lead, sdk-testing-lead | 3 | DIRECT | No |
| 12 | `lifecycle-events` | 1.0.0 | YES | YES | all agents (lifecycle:started + lifecycle:completed on every agent) | 15 | DIRECT | No |
| 13 | `feedback-analysis` | 1.0.0 | YES | YES (partial) | sdk-testing-lead (H9 retrospective items) | 1 | INFERRED | No — Phase 4 is where full invocation occurs |
| 14 | `sdk-marker-protocol` | 1.0.0 | YES | YES | sdk-impl-lead, sdk-marker-scanner, sdk-marker-hygiene-devil | 3 | DIRECT | No |
| 15 | `sdk-semver-governance` | 1.0.0 | YES | YES | sdk-semver-devil, sdk-design-lead | 2 | DIRECT | No |
| 16 | `api-ergonomics-audit` | 1.0.0 | YES | YES | sdk-design-devil (DD-002), sdk-api-ergonomics-devil | 2 | DIRECT | No |
| 17 | `conflict-resolution` | 1.0.0 | YES | NO | — | 0 | — | EXPECTED-UNUSED (not a gap — no conflicts arose) |
| 18 | `environment-prerequisites-check` | 1.0.0 | YES | YES | sdk-impl-lead (M0 env verify, decision-log line 72) | 1 | DIRECT | No |
| 19 | `mcp-knowledge-graph` | 1.0.0 | YES | NO | — | 0 | — | EXPECTED-UNUSED (not a gap — MCP degraded to JSONL per rule 31) |
| 20 | `context-summary-writing` | 1.0.0 | YES | YES | all agents (≥13 context summaries written across phases) | 13 | DIRECT | No |

**Summary**: 20/20 declared skills accounted for. 16 invoked, 4 not invoked.

---

## Skill-Coverage Percentage by Phase

| Phase | Skills applicable | Skills demonstrably invoked | Phase coverage |
|---|---|---|---|
| Phase 0 — Intake | decision-logging, guardrail-validation, spec-driven-development, lifecycle-events, context-summary-writing, environment-prerequisites-check | 6/6 | **100%** |
| Phase 1 — Design | python-asyncio-patterns, python-class-design, asyncio-cancellation-patterns, tdd-patterns, spec-driven-development, api-ergonomics-audit, sdk-semver-governance, review-fix-protocol, sdk-marker-protocol, decision-logging, lifecycle-events, context-summary-writing | 12/12 | **100%** |
| Phase 2 — Impl | python-asyncio-patterns, python-class-design, pytest-table-tests, asyncio-cancellation-patterns, tdd-patterns, sdk-marker-protocol, environment-prerequisites-check, review-fix-protocol, decision-logging, lifecycle-events, context-summary-writing | 11/11 | **100%** |
| Phase 3 — Testing | pytest-table-tests, asyncio-cancellation-patterns, review-fix-protocol, feedback-analysis, decision-logging, lifecycle-events, context-summary-writing | 7/7 | **100%** |
| Phase 4 — Feedback | feedback-analysis, decision-logging, lifecycle-events, mcp-knowledge-graph | 3/4 (mcp-knowledge-graph unused) | **75%** (rule-31 degrade is documented; not a gap) |

**Overall declared-skill coverage**: 16/20 invoked = **80%**. Adjusted for expected-unused (4 skills correctly not invoked per TPRD design): **100% of applicable skills invoked**.

---

## Expected-but-Unused Gap Analysis

### `idempotent-retry-safety` — EXPECTED-UNUSED (NOT a gap)

**TPRD §Skills-Manifest annotation**: "§3 non-goal confirmation that pool is NOT a retry primitive; shared-core (debt-bearer)."

**Analysis**: The pool has no retry loop, no retry policy, and no idempotency requirement beyond `aclose()` being idempotent (a single-call property, not a retry semantic). The TPRD explicitly lists "No circuit-breaker integration" and "No rate limiting" as §3 Non-Goals, and the §Skills-Manifest declares this skill for the purpose of confirming the non-goal, not for active use. No agent needed to invoke this skill because no retry primitive was designed or implemented — the non-goal confirmation is implicit in the absence of retry code.

**Verdict**: NOT a gap. No improvement-planner action needed.

### `network-error-classification` — EXPECTED-UNUSED (borderline; see note)

**TPRD §Skills-Manifest annotation**: "§11.1 cancellation + timeout error taxonomy; shared-core (debt-bearer)."

**Analysis**: The pool's error taxonomy (`PoolError`, `PoolClosedError`, `PoolEmptyError`, `ConfigError`, `ResourceCreationError`, `asyncio.TimeoutError`, `asyncio.CancelledError`) was designed by the `designer` agent referencing TPRD §7 Error Model and §5.4. The skill's domain (network-error classification) does not map naturally to a pool primitive: the pool's TimeoutError and CancelledError are stdlib asyncio types, not network-layer errors; `ResourceCreationError` wraps caller-hook failures which could be network errors but that classification is the caller's responsibility. The design-devil (DD-006) checked all exception propagation paths without needing `network-error-classification` prescriptions.

**Verdict**: EXPECTED-UNUSED. The boundary case is that the TPRD §Skills-Manifest lists it for "timeout error taxonomy" — the pool does propagate `asyncio.TimeoutError` cleanly without wrapping. If a future pool TPRD adds network-aware hook error classification (e.g. distinguishing transient vs. permanent `on_create` failures), this skill would become relevant. **Marginal gap signal**: improvement-planner may consider adding `asyncio.TimeoutError` / `asyncio.CancelledError` to the skill's trigger keywords to surface it for asyncio-timeout work. LOW priority.

### `conflict-resolution` — EXPECTED-UNUSED (NOT a gap)

**Analysis**: No conflict occurred between agents this run. The `sdk-design-lead` (decision-log line 52) documents a package-layer discrepancy (three devil agents not in active-packages.json) but this was resolved by the lead authoring surrogate reviews — a design-lead-level decision, not a conflict requiring the skill's formal escalation protocol. Zero `ESCALATION: CONFLICT` messages logged.

**Verdict**: NOT a gap. Skill is a contingency protocol; correct behavior when no conflicts arise is non-invocation.

### `mcp-knowledge-graph` — EXPECTED-UNUSED (NOT a gap)

**Analysis**: Rule 31 MCP Fallback Policy explicitly covers this case. The decision-log contains no MCP-health entry for this run; `feedback-analysis` skill's JSONL fallback path applies. This is the declared degradation behavior.

**Verdict**: NOT a gap. Pipeline rule 31 pre-authorizes JSONL fallback.

---

## D2 (Lenient debt-bearer) Input — Q1 for Phase 4 Retrospector

Three shared-core debt-bearer skills (`tdd-patterns`, `idempotent-retry-safety`, `network-error-classification`) were designated the empirical test of whether Go-flavored shared-core skill bodies produce useful guidance on Python code.

### `tdd-patterns` — INVOKED, UTILITY: USEFUL (with caveats)

**Invocation evidence**: `sdk-impl-lead`'s wave plan (impl-lead-brief.md) prescribes an explicit red→green→refactor→docs cycle per slice (M1–M6), which is the core prescription of `tdd-patterns`. The per-wave acceptance criteria and tech-debt scan after every wave are directly aligned with `tdd-patterns` checkpoints. However, the decision-log has no explicit tag citing "tdd-patterns" by name.

**Go-body interference**: The `tdd-patterns` skill body likely references `go test`, `go test -run`, and Go table-driven test syntax. The impl-lead adapted to `pytest -x`, `pytest --cov`, and `@pytest.mark.parametrize` equivalents. No agent reported confusion from the Go-body prescriptions; the red→green→refactor cycle is language-agnostic at the conceptual level.

**D2 verdict input**: delta on quality proxy is not measurable (no skill-quality-score in the log for tdd-patterns specifically). The wave structure was correctly followed. **Recommendation: HOLD Lenient** — Go body did not actively harm Python guidance for this skill's high-level prescription. Body cites Go-specific toolchain commands; those are ignored by Python agents. A `python/conventions.yaml` companion is NOT yet justified — agents self-adapted successfully.

**Skill-evolution candidate**: YES (Go-only toolchain references in body). Tag for body-patch to add a Python toolchain sidebar. See §evolution-candidates below.

### `idempotent-retry-safety` — NOT INVOKED

**Utility verdict**: N/A — correctly unused. Not a D2 signal. No evidence of Go-body interference since body was never consulted.

### `network-error-classification` — NOT INVOKED

**Utility verdict**: N/A — unused. Borderline applicable (timeout taxonomy). No evidence of Go-body interference. The `asyncio.TimeoutError` / `asyncio.CancelledError` taxonomy was designed without consulting this skill. The error hierarchy produced is clean and idiomatic; no Go-style `net.Error` wrapping patterns leaked in.

**D2 verdict input for network-error-classification**: The skill's ABSENCE did not produce wrong output — the designer produced correct asyncio error taxonomy unaided. This suggests the skill's Go-flavored body would have been actively mis-leading if invoked (Go's `net.Error`/`ErrConnectionReset` taxonomy does not map to asyncio). **Recommendation: flag as potential confusion source if invoked on future Python network-IO code**. If the skill is invoked on a Python TPRD with network I/O, test whether agents produce Go-inflected error patterns.

---

## D6 (Split shape) Input — Q2 for Phase 4 Retrospector

Did any shared-core agent prompt produce confusing or wrong findings on Python code that a `python/conventions.yaml` companion would have prevented?

### Findings by sub-agent

| Agent | Finding | Go-flavor confusion? | `python/conventions.yaml` would have helped? |
|---|---|---|---|
| `sdk-design-devil` | DD-001: 13 `__slots__` fields flagged as "high side; common Python idiom is ≤8" | YES — mild confusion. The Go-baseline review experience (Go structs with ~5 fields) influenced the ≤8 heuristic. Python `__slots__` use for perf optimization legitimately produces larger field counts than Go struct equivalents. | YES — a `python/conventions.yaml` noting "__slots__ field count is budget-by-profile, not by heuristic" would have pre-empted this note. Low impact (ACCEPT-WITH-NOTE, not a blocker), but the heuristic was Go-derived. |
| `sdk-design-devil` | DD-002: `acquire` (sync ctx-mgr) vs `acquire_resource` (async) — caller mental-model burden | NO — language-neutral ergonomics finding. The concern (two acquire methods with different async semantics) applies equally in Go (two-method patterns are a common source of misuse). | No. This is a legitimate ergonomics concern in any language. |
| `sdk-security-devil` | SD-001: hook caller-trust boundary recommendation | NO — language-neutral security principle. | No. |
| `sdk-api-ergonomics-devil` | ACCEPT (no findings on the Python surface) | No confusion — agent appears to have applied ergonomics principles without Go-specific prescription. | Not needed for this run. |
| `sdk-overengineering-critic` (impl M7) | ACCEPT — counter-mode harness (`held: list[int]`) justified | NO — finding was about pytest-benchmark's pedantic API, which is Python-specific. Agent correctly accepted the Python-specific harness shape. | Interesting: agent reasoned about pytest-benchmark WITHOUT a Python companion. This suggests the critic's Go-flavored body did not obstruct Python-specific judgment here. |

**D6 summary**: One case where a `python/conventions.yaml` companion would have prevented a minor Go-flavored heuristic leak (`sdk-design-devil` DD-001 `__slots__` field-count idiom). Impact was low (ACCEPT-WITH-NOTE, not a blocker). The single finding that a Python companion would fix is a good candidate for the first `python/conventions.yaml` entry:

```yaml
# python/conventions.yaml entry (proposed for improvement-planner)
__slots__:
  field_count_heuristic: "budget by profile, not by count; ≤8 is a Go/C-struct idiom, not a Python limit"
  reference: "python-class-design SKILL.md §slots"
```

**D6 verdict input**: Split is not yet justified for `sdk-design-devil` on the basis of one minor misfire. If the next Python run produces another `__slots__`-heuristic or Go-struct-analogy finding, that would cross the D6 threshold. **Recommendation: monitor; file `python/conventions.yaml` entry as a PROPOSED addition; do not split agent prompt yet**.

---

## Skill-Evolution Candidates (Go-only body invoked on Python)

Skills whose bodies cite Go-specific idioms but were invoked on Python code this run. Learning-engine should consider body-patch (minor version bump, Python toolchain sidebar appended):

| Skill | Version | Go-idiom in body | Evidence of confusion | Priority |
|---|---|---|---|---|
| `tdd-patterns` | 1.0.0 | `go test`, `go test -run`, Go table-driven test syntax (`[]struct{ name string; ... }`) | None — impl-lead self-adapted. But body cites Go toolchain commands; a Python pilot would find them inert at best, misleading at worst if a new agent reads literally. | MEDIUM — add Python toolchain sidebar (pytest, pytest-asyncio, pytest-benchmark) |
| `network-error-classification` | 1.0.0 | `net.Error`, `ErrConnectionReset`, Go sentinel error types | Not invoked this run; but if invoked on Python network-IO TPRDs, Go taxonomy would actively mislead (asyncio exceptions are not sentinel types). | HIGH — add Python error taxonomy sidebar BEFORE this skill is invoked on a Python network-IO TPRD |
| `idempotent-retry-safety` | 1.0.0 | Likely references `retry` libraries or Go-style loop patterns | Not invoked; no evidence. | LOW — defer until invoked on Python |

**Total skill-evolution candidates: 3** (tdd-patterns MEDIUM, network-error-classification HIGH, idempotent-retry-safety LOW).

---

## Recommendations for improvement-planner

1. **`network-error-classification`**: Add Python asyncio error taxonomy sidebar BEFORE next Python network-IO TPRD. Go body cites `net.Error`/`ErrConnectionReset` patterns that don't exist in asyncio. TRIGGERS-GAP partially mitigated by non-invocation this run, but will surface if a Python TPRD declares network error handling. Priority: HIGH.

2. **`tdd-patterns`**: Append Python toolchain sidebar (pytest / pytest-asyncio / pytest-benchmark / ruff equivalents of `go test` / `go vet` / `gofmt`). Body self-adapted by impl-lead this run, but explicit Python path would lower agent cognitive load. Priority: MEDIUM.

3. **`sdk-design-devil`**: File first `python/conventions.yaml` entry — `__slots__` field count is budget-by-profile, not ≤8 heuristic. One confirmed case of Go-derived heuristic producing an ACCEPT-WITH-NOTE finding that a Python-aware agent would not have filed. D6 threshold not crossed, but `conventions.yaml` is the correct mitigation vehicle. Priority: LOW (single incident).

4. **`conflict-resolution`**: Skill correctly unused this run. No action. Consider adding a skill description note that the skill's non-invocation in a clean run is the expected signal.

5. **`mcp-knowledge-graph`**: Rule-31 fallback worked as designed. Consider adding a Phase 4 baseline entry to `baselines/shared/mcp-health-history.jsonl` (if such a file is maintained) to track MCP availability trends across runs.

---

## Baselines backfill note

Per agent procedure:

- **`baselines/go/devil-verdict-history.jsonl`**: This run is Python-scoped; the per-skill `devil_fix_rate` / `devil_block_rate` computation is not applicable to the `baselines/go/` partition. Python baselines live at `baselines/python/` (seeded by testing-lead at Wave T1). No `go/devil-verdict-history.jsonl` entry is written for this run — the run's devil verdicts should be recorded in a `baselines/python/devil-verdict-history.jsonl` file (not yet created by the python adapter; filed as generalization-debt for Phase B).
- **`baselines/go/output-shape-history.jsonl`**: Same — Python run; `skills_invoked` backfill should target `baselines/python/output-shape-history.jsonl`. The `baselines/go/output-shape-history.jsonl` file exists but is empty (1 line); this run does not write Go output shapes. No action on the Go partition.
- **`evolution/knowledge-base/prompt-evolution-log.jsonl`**: No skill auto-patch was applied this run (no matching entry for `run_id: sdk-resourcepool-py-pilot-v1`). No `regression_candidate: true` flags needed.
- **`learning-notifications.md`**: No patches applied; G85 vacuously satisfied; file is empty (confirmed: 1 line = header only).
