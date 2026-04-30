# Skill Coverage Report

Run: `sdk-resourcepool-py-pilot-v1` | Language: `python` | Pipeline: `0.5.0`
Generated: `2026-04-29` | Reporter: `sdk-skill-coverage-reporter`

---

## Summary

| Metric | Count |
|---|---|
| Skills in active-packages (shared-core + python union) | 36 |
| Declared in §Skills-Manifest | 22 |
| Skills invoked this run (of declared 22) | 22 |
| Unused-but-relevant (TRIGGERS-GAP) | 2 |
| Used-but-undeclared (lateral use / agent wave only) | 0 |
| Expected-but-not-loaded (TRIGGERS-MANIFEST-GAP) | 0 |

---

## Expected (from TPRD §Skills-Manifest — 22 declared)

All 22 skills resolved in active-packages union at intake (I2 PASS: 22/22 OK, 0 missing,
0 under-versioned). See `runs/sdk-resourcepool-py-pilot-v1/intake/skills-manifest-check.md`.

| # | Skill | Version | Source pack |
|---|---|---|---|
| 1 | `python-asyncio-patterns` | 1.0.0 | python |
| 2 | `python-sdk-config-pattern` | 1.0.0 | python |
| 3 | `python-exception-patterns` | 1.0.0 | python |
| 4 | `python-pytest-patterns` | 1.0.0 | python |
| 5 | `python-asyncio-leak-prevention` | 1.0.0 | python |
| 6 | `python-mypy-strict-typing` | 1.0.0 | python |
| 7 | `tdd-patterns` | 1.0.0 | shared-core |
| 8 | `idempotent-retry-safety` | 1.0.0 | shared-core |
| 9 | `network-error-classification` | 1.0.0 | shared-core |
| 10 | `spec-driven-development` | 1.0.0 | shared-core |
| 11 | `decision-logging` | 1.1.0 | shared-core |
| 12 | `guardrail-validation` | 1.1.0 | shared-core |
| 13 | `review-fix-protocol` | 1.0.0 | shared-core |
| 14 | `lifecycle-events` | 1.0.0 | shared-core |
| 15 | `feedback-analysis` | 1.0.0 | shared-core |
| 16 | `sdk-marker-protocol` | 1.0.0 | shared-core |
| 17 | `sdk-semver-governance` | 1.0.0 | shared-core |
| 18 | `api-ergonomics-audit` | 1.0.0 | shared-core |
| 19 | `conflict-resolution` | 1.0.0 | shared-core |
| 20 | `environment-prerequisites-check` | 1.0.0 | shared-core |
| 21 | `mcp-knowledge-graph` | 1.0.0 | shared-core |
| 22 | `context-summary-writing` | 1.0.0 | shared-core |

---

## Full Coverage Table

Legend: `used` = invoked and cited by agents | `unused-but-relevant` = loaded + signal match, no invocation = TRIGGERS-GAP |
`unused-correctly` = loaded but signal does NOT match scope (Non-Goal / out-of-scope) |
`used-but-undeclared` = invoked but absent from §Skills-Manifest

| Skill | §Skills-Manifest? | Tech-signal-relevant? | Invoked? | Classification |
|---|---|---|---|---|
| `python-asyncio-patterns` | yes | yes — §5 async API, §11.1 cancellation, `asyncio.timeout`, TaskGroup | yes | **used** |
| `python-sdk-config-pattern` | yes | yes — §5.1 PoolConfig frozen+slotted dataclass | yes | **used** |
| `python-exception-patterns` | yes | yes — §5.4 PoolError hierarchy; 5 sentinel classes | yes | **used** |
| `python-pytest-patterns` | yes | yes — §11.1 table-driven unit tests; 62 tests across 8 modules | yes | **used** |
| `python-asyncio-leak-prevention` | yes | yes — §11.4 leaked-task fixture; CancelledError propagation | yes | **used** |
| `python-mypy-strict-typing` | yes | yes — §2 mypy --strict pass; Generic[T] + overloads | yes | **used** |
| `tdd-patterns` | yes | yes — red/green/refactor per slice (S1-S6); table-driven tests | yes | **used** |
| `idempotent-retry-safety` | yes | yes — §5.2 aclose idempotency; §3 non-retry non-goal confirmed | yes | **used** |
| `network-error-classification` | yes | yes — §7 cancellation / timeout error taxonomy; design-lead error model | yes | **used** |
| `spec-driven-development` | yes | yes — TPRD as canonical contract; [traces-to:] markers tracing to §-ids | yes | **used** |
| `decision-logging` | yes | yes — every agent appended decision-log.jsonl; 59 entries total | yes | **used** |
| `guardrail-validation` | yes | yes — G* guardrails run at D2/M9/T-GR; 12 pass at intake | yes | **used** |
| `review-fix-protocol` | yes | yes — M7/M8 loop; review-fix-protocol Rule 6 cited in decision-log | yes | **used** |
| `lifecycle-events` | yes | yes — lifecycle entries by every agent; phase start/end pattern | yes | **used** |
| `feedback-analysis` | yes | yes — Phase 4 F1/F2/F3 waves; testing-lead hands off backlog | yes | **used** |
| `sdk-marker-protocol` | yes | yes — `[traces-to: TPRD-§...]` on all 9 public symbols; M4 wave ran | yes | **used** |
| `sdk-semver-governance` | yes | yes — sdk-semver-devil ACCEPT 1.0.0; Mode A initial version | yes | **used** |
| `api-ergonomics-audit` | yes | yes — sdk-api-ergonomics-devil-python ACCEPT; Q3/Q6 ergonomics decided | yes | **used** |
| `conflict-resolution` | yes | yes — escalation protocol invoked (H7 ask → orchestrator escalation path) | yes | **used** |
| `environment-prerequisites-check` | yes | yes — toolchain gap (pytest/mypy/ruff absent) surfaced at M3.5 / H7 | yes | **used** |
| `mcp-knowledge-graph` | yes | yes — Phase 4 cross-run JSONL fallback path used; G04 WARN-degrade | yes | **used** |
| `context-summary-writing` | yes | yes — summaries written by design-lead, impl-lead (×2), testing-lead | yes | **used** |
| `python-client-shutdown-lifecycle` | no | yes — §5.2 aclose() is a first-class §7 symbol; graceful-drain, outstanding-resource tracking, idempotent close all in scope | **no** | **unused-but-relevant (TRIGGERS-GAP)** |
| `python-dependency-vetting` | no | yes — pyproject.toml present; sdk-dep-vet-devil-python ran D3; pip-audit + safety ran T-SUPPLY | **no** | **unused-but-relevant (TRIGGERS-GAP)** |
| `python-otel-instrumentation` | no | no — TPRD §8 explicitly defers OTel; §3 Non-Goal | no | **unused-correctly** |
| `python-testcontainers-setup` | no | no — zero external services; stdlib-only package | no | **unused-correctly** |
| `python-hypothesis-patterns` | no | no — hypothesis not installed on host; no property-based tests authored | no | **unused-correctly** |
| `python-mock-strategy` | no | no — tests use real Pool objects; no mock citations | no | **unused-correctly** |
| `python-doctest-patterns` | no | no — pytest only; no doctests in test suite | no | **unused-correctly** |
| `python-hexagonal-architecture` | no | no — single-package primitive; no port/adapter boundary | no | **unused-correctly** |
| `python-connection-pool-tuning` | no | no — tuning skill targets connection pools (DB/HTTP); this is an in-memory primitive | no | **unused-correctly** |
| `python-credential-provider-pattern` | no | no — §9 no secrets/credentials; zero external deps | no | **unused-correctly** |
| `python-client-tls-configuration` | no | no — stdlib-only; no TLS in scope | no | **unused-correctly** |
| `python-client-rate-limiting` | no | no — §3 explicit Non-Goal | no | **unused-correctly** |
| `python-circuit-breaker-policy` | no | no — §3 explicit Non-Goal | no | **unused-correctly** |
| `python-backpressure-flow-control` | no | no — §3 explicit Non-Goal (no load-shedding / queue-depth backpressure) | no | **unused-correctly** |

---

## Invoked Skills (22 / 22 declared)

All 22 §Skills-Manifest-declared skills were invoked this run. No declared skill went uncited.

Top-cited skills (by evidence weight across phases):

1. `decision-logging` — cited in all 4 phases; 59 decision-log entries across 10+ agents
2. `python-asyncio-patterns` — cited in design algorithm, impl _pool.py, testing T1/T3/T6 waves
3. `guardrail-validation` — cited at I-RG, D2, M9-RERUN, T-GR across 4 phase boundaries
4. `lifecycle-events` — lifecycle entry per agent per phase; pattern used by all 10+ agents
5. `review-fix-protocol` — Rule 6 explicitly cited in decision-log; M7/M8 loop ran twice

---

## Expected-but-Unused (TRIGGERS-GAP) — 2 skills

### 1. `python-client-shutdown-lifecycle` — TRIGGERS-GAP

- Skill version: 1.0.0 (python pack, loaded in active set)
- TPRD signal: `aclose()` is a top-level §5.2 exported symbol with the most detailed behavioral
  contract in the TPRD (4-step drain sequence, outstanding-resource tracking, idempotent
  guarantee, timeout-bounded cancel). This is precisely the domain `python-client-shutdown-lifecycle`
  covers.
- Why unused: no agent cited this skill by name in rationale, tags, or review body. The impl-lead
  correctly produced idempotent aclose behavior (per the decision-log M5 refactor entry), but
  attributed the pattern to `python-asyncio-patterns` and `idempotent-retry-safety` rather than
  the dedicated lifecycle skill.
- Investigation: skill description may not include the keyword `aclose` or `graceful shutdown`;
  agents looking for lifecycle guidance found it via asyncio patterns instead. Consider adding
  `trigger-keywords: [aclose, shutdown, graceful, drain, outstanding, lifecycle]` to the skill
  frontmatter to surface it alongside `python-asyncio-patterns` on shutdown-related work.
- Improvement-planner candidate: enhance `python-client-shutdown-lifecycle` trigger-keywords.

### 2. `python-dependency-vetting` — TRIGGERS-GAP

- Skill version: 1.0.0 (python pack, loaded in active set)
- TPRD signal: pyproject.toml present (declared in `python.json:module_file`); 11 dev deps
  vetted; `pip-audit` + `safety check` ran at T-SUPPLY; `sdk-dep-vet-devil-python` ran D3 wave.
  The vetting activity was performed end-to-end.
- Why unused: agents invoked `sdk-dep-vet-devil-python` (the agent) and the toolchain commands
  directly, but no agent cited `python-dependency-vetting` (the skill) in rationale or tags.
  The dep-vet work was done via agent dispatch, not via a skill-guided prompt path.
- This is also a §Skills-Manifest gap: the TPRD declares dep-vetting via `sdk-dep-vet-devil-python`
  (agent) but does not declare `python-dependency-vetting` (skill) even though the activity is
  in scope.
- Investigation: skill may not appear in `sdk-dep-vet-devil-python` agent prompt body; the agent
  does its work procedurally without referencing the skill. Add a `skill: python-dependency-vetting`
  cross-reference in the agent prompt OR add to §Skills-Manifest on next TPRD.
- Improvement-planner candidate: (a) add `python-dependency-vetting` to §Skills-Manifest template
  for any TPRD with a pyproject.toml; (b) reference skill in `sdk-dep-vet-devil-python` prompt.

---

## Used-but-Undeclared — 0 skills

No skills outside the §Skills-Manifest were cited by agents this run. All lateral use was through
declared skills. This is a positive signal: the 22-skill manifest was well-calibrated to the
actual work performed.

---

## Expected-but-Not-Loaded (TRIGGERS-MANIFEST-GAP) — 0 skills

All TPRD tech signals matched skills present in the active-packages union. No signal pointed to a
skill that exists on disk but was not loaded, and no signal pointed to a skill that needs to be
authored. The python pack's 20-skill set adequately covers all pilot scope.

---

## Recommendations for improvement-planner

### P1 — Enhance `python-client-shutdown-lifecycle` trigger coverage
Add `trigger-keywords: [aclose, graceful, shutdown, drain, outstanding, lifecycle, teardown]`
to skill frontmatter. The aclose() symbol is the most documented behavior in the TPRD; the skill
should surface automatically when agents see `aclose` in the design stub.
Classification: `scope: SKILL-TRIGGER-PATCH` (patch-level frontmatter addition; no body change).

### P2 — Add `python-dependency-vetting` to §Skills-Manifest template + agent cross-reference
Two sub-actions:
  (a) Add `python-dependency-vetting` to the TPRD §Skills-Manifest boilerplate for any TPRD
      where `§Required-Packages` includes `python` and the package has a `pyproject.toml`.
  (b) Add `# skill: python-dependency-vetting` reference line in `sdk-dep-vet-devil-python`
      agent prompt so citations flow into the decision log automatically.
Classification: `scope: TPRD-TEMPLATE-PATCH + AGENT-PROMPT-PATCH`.

### P3 — Note for baseline-manager (first-run seed)
`baselines/python/devil-verdict-history.jsonl` does not yet exist. This is the first Python run;
baseline-manager seeds from this run's findings data. No regression gate fires. See procedure
§Devil-verdict stability for the seed entry format — one line per invoked skill, all 22 declared
skills have invocation evidence; `regression_candidate` is false for all (no skill was auto-patched
this run per `evolution/knowledge-base/prompt-evolution-log.jsonl`).

---

## Devil-Verdict Stability (first-run seed — no prior baseline to compare)

This is the first `python` run. `baselines/python/devil-verdict-history.jsonl` does not exist.
The entries below ARE the seed. No delta/regression analysis is possible; baseline-manager
initializes the file from these figures.

Invoked skills with devil-finding evidence (NEEDS-FIX findings whose fix_agent cites a symbol
in a skill-prescribed region):

| Skill | Symbols scoped | NEEDS-FIX findings | devil_fix_rate | BLOCKER findings | devil_block_rate | regression_candidate |
|---|---|---|---|---|---|---|
| `python-asyncio-patterns` | 4 (`acquire`, `acquire_resource`, `release`, `aclose`) | 1 (CR-001: TimeoutError alias) | 0.25 | 0 | 0.00 | false |
| `python-asyncio-leak-prevention` | 2 (`acquire`, `aclose`) | 0 | 0.00 | 0 | 0.00 | false |
| `python-exception-patterns` | 5 (PoolError, PoolClosedError, PoolEmptyError, ConfigError, ResourceCreationError) | 0 | 0.00 | 0 | 0.00 | false |
| `python-sdk-config-pattern` | 1 (PoolConfig) | 0 | 0.00 | 0 | 0.00 | false |
| `python-mypy-strict-typing` | 9 (all exported symbols) | 1 (CV-001: Callable import; was real correctness bug) | 0.11 | 0 | 0.00 | false |
| `python-pytest-patterns` | 62 (test count) | 0 | 0.00 | 0 | 0.00 | false |
| `sdk-marker-protocol` | 9 (all exported symbols carry [traces-to:]) | 0 | 0.00 | 0 | 0.00 | false |
| `api-ergonomics-audit` | 7 (Pool methods) | 1 (DD-005: acquire docstring) | 0.14 | 0 | 0.00 | false |
| `review-fix-protocol` | n/a (process skill) | 0 | 0.00 | 0 | 0.00 | false |
| `guardrail-validation` | n/a (process skill) | 0 | 0.00 | 0 | 0.00 | false |

All other declared skills (12 remaining) had no associated NEEDS-FIX findings — `devil_fix_rate: 0.00`, `devil_block_rate: 0.00`.

No skill was auto-patched this run (`prompt-evolution-log.jsonl` has no entries with `run_id: sdk-resourcepool-py-pilot-v1`). `regression_candidate: false` on all entries.

---

## Output-Shape Backfill

`baselines/python/output-shape-history.jsonl` entry for this run should have `skills_invoked`
backfilled with all 22 declared skills (metrics-collector seeded the entry before this reporter
ran). Baseline-manager is responsible for the write per procedure §Devil-verdict stability.

Feeds: `improvement-planner` (P1, P2 above) | `baseline-manager` (devil-verdict seed + output-shape backfill).
