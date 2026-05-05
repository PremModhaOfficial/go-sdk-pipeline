# Pollution Test — Empirical Results

> **Date**: 2026-04-24
> **Question**: Does adding non-Go (Rust) skills to `.claude/skills/` degrade pipeline behavior on a Go-targeted run?
> **Answer**: **No. H₀ confirmed empirically.** The pipeline's skill-loading model is invocation-scoped, not directory-scoped. Dummy Rust skills were invisible to every validator, to the real drift-detector subagent, and to every metric collected.

---

## Hypothesis

| | Statement |
|---|---|
| **H₀ (null)** | Presence of non-Go skills in `.claude/skills/` does not measurably change pipeline behavior on a Go-declared TPRD. |
| **H₁ (alt)** | Presence degrades behavior via directory scan, keyword trigger, or prompt-context leakage. |

---

## Setup

1. **10 dummy Rust skills** authored under `.claude/skills/`:
   - `rust-error-handling`, `rust-async-tokio`, `rust-ownership-borrow`, `rust-trait-design`, `rust-cargo-workspace`, `cargo-audit-deps`, `rust-test-patterns`, `rust-criterion-bench`, `rust-tracing-opentelemetry`, `rust-unsafe-audit`
   - Each plausibly-authored (~30 lines each), frontmatter complete (`version: 1.0.0`, `status: experimental`, Rust-themed `trigger-keywords`)
   - Each marked with a visible `<!-- POLLUTION-TEST-STUB -->` comment + revert instructions

2. **Registration** in `.claude/skills/skill-index.json`:
   - **Round 1**: separate top-level section `experimental_rust_pack` + new `rust` tag in `tags_index`
   - **Round 2 (maximum adversarial)**: promoted into `sdk_native` alongside real skills (29 entries total)

3. **Baseline**: the completed `runs/sdk-dragonfly-s2/` run (Go-only TPRD, 27 declared skills, 19 invoked). Used as X1 reference.

---

## Tests executed

### 1. Guardrail G90 — skill-index ↔ filesystem consistency

| Round | exit | stdout | Interpretation |
|---|---|---|---|
| R1 (experimental_rust_pack) | **0** | empty | G90 hardcodes 3 sections (`ported_verbatim`, `ported_with_delta`, `sdk_native`); the new section is outside its scope. Filesystem "extras" handled gracefully (comment line 21: `allow extras in fs ... just warn`). |
| R2 (promoted to sdk_native) | **0** | empty | 10 new entries now in-scope; filesystem matches; PASS. |

### 2. Guardrail G23 — TPRD §Skills-Manifest validation

| Round | exit | Declared | OK | Missing | Rust mentioned in OK list |
|---|---|---:|---:|---:|---|
| R1 | 0 (WARN) | 27 | 19 | 8 | 0 |
| R2 | 0 (WARN) | 27 | 19 | 8 | 0 |

Both rounds produced byte-identical output. G23 scopes strictly to what the TPRD declares; undeclared skills (even when registered in the catalog) are invisible to validation.

### 3. Grep sweep — does any pipeline content reference Rust?

- `grep -ril '\brust\b|tokio|cargo|criterion' .claude/agents/ phases/ commands/ CLAUDE.md` → 1 false positive (English word "criterion" in `code-reviewer.md`, unrelated to the Rust crate).
- Pre-pollution `decision-log.jsonl` (`sdk-dragonfly-s2`) — 0 matches on `rust|tokio|cargo|criterion` (as expected; run predates pollution).

### 4. Decisive behavioral test — live `sdk-skill-drift-detector` subagent on polluted state

A real subagent was spawned with instructions to follow the `sdk-skill-drift-detector.md` procedure literally against the polluted `runs/sdk-dragonfly-s2/`. Its behavioral report:

| Measure | Result |
|---|---|
| Skills scanned | **19 exactly** — sdk-config-struct-pattern, otel-instrumentation, sdk-otel-hook-integration, network-error-classification, go-error-handling-patterns, go-concurrency-patterns, goroutine-leak-prevention, client-shutdown-lifecycle, client-tls-configuration, connection-pool-tuning, credential-provider-pattern, testcontainers-setup, table-driven-tests, testing-patterns, fuzz-patterns, tdd-patterns, sdk-marker-protocol, sdk-semver-governance, go-dependency-vetting |
| Any `rust-*` or `cargo-*` in scope | **0** |
| Pollution mechanism encountered | **None.** Agent explicitly reports: *"The agent never enumerates `.claude/skills/` or `skill-index.json`, so the 10 planted skills and the `sdk_native: experimental` manifest bucket are both invisible by construction."* |
| Drift findings vs. original `skill-drift.md` | **1:1 identical** — NONE=14, MINOR=3, MODERATE=1, MAJOR=0. Same SKD-IDs, same severities. |
| Output artifact | `runs/sdk-dragonfly-s2/feedback/skill-drift-POLLUTION-TEST.md` |
| Subagent verdict | **H₀ holds (no pollution).** *"Agent is immune to skill-directory pollution because it is invocation-scoped, not directory-scoped."* |

---

## Mechanism — why the pipeline is immune

Skills enter an agent's context only via two channels, both of which require explicit human action:

1. **TPRD §Skills-Manifest** (the run contract). Validated by `G23.sh` at intake. Any skill not declared here is invisible to the run.
2. **Hardcoded lists in lead-agent prompts** (`sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead`). These lists are static text in the agent `.md` file — changing them requires a human PR.

There is no third channel:
- `trigger-keywords` frontmatter field exists on every SKILL.md but no code reads it (zero consumers across the pipeline).
- No agent contains `ls .claude/skills/`, `glob .claude/skills/*`, or equivalent directory-traversal logic.
- `skill-index.json` is consulted only by `G23` (manifest validation), `G90` (consistency), and `sdk-intake-agent` (TPRD tech-reference validation) — never to drive code-generation agent context.

The `sdk-skill-drift-detector` and `sdk-skill-coverage-reporter` both cross-reference "skills actually invoked this run" (from `decision-log.jsonl` + TPRD manifest) and read only those SKILL.md files — they do not enumerate the directory.

`settings.json` hard-codes `new_skills_per_run: 0` and the CLAUDE.md opens with: *"No runtime skill synthesis. Skills and agents are human-authored, promoted via PR, and static at runtime."*

---

## Implications for the A / B / C architecture decision

The pollution risk was the main argument against Option A (unified pipeline + filter). **That risk is empirically near-zero in this pipeline.** The "filter" is already implicit: the TPRD §Skills-Manifest is a whitelist, lead-agent prompts are whitelists, and no skill enters an agent's context without appearing in one of those two.

Updated architecture scoring:

| | A: Unified + filter | B: Separate pipelines | C: Shared core + packs |
|---|---|---|---|
| Quality risk | **low** (empirically verified) | zero | zero |
| One-time refactor | ~0 (filter already implicit) | 0 | ~24 wk (per audit) |
| Per-language pack | ~6–8 wk | ~10 wk full pipeline | ~8–10 wk |
| Maintenance tax | shared core with minor conditionals | N× duplication forever | lowest long-term |
| Structural risk for ≥3 languages | medium (sdk_native grows unboundedly, agent prompts become decision trees) | low (isolated) | low (clean boundaries) |

**At 2 languages, A is now a viable cheap option.** At 3+ languages, C still wins on maintenance.

---

## Cleanup

- [ ] `rm -r .claude/skills/rust-* .claude/skills/cargo-*` (10 directories)
- [ ] Restore `skill-index.json` from `skill-index.json.bak.pollution-test`
- [ ] Verify no `rust|cargo|tokio|criterion` traces in pipeline content post-cleanup
- [ ] Preserve `runs/sdk-dragonfly-s2/feedback/skill-drift-POLLUTION-TEST.md` as evidence (not deleted)
- [ ] Preserve this results doc

See `## Cleanup execution` below (written after cleanup runs).

---

## Cleanup execution

Confirmed:
- All 10 `rust-*` / `cargo-*` directories removed from `.claude/skills/`
- `skill-index.json` restored from `.bak.pollution-test` (no rust/cargo entries remain)
- `.bak.pollution-test` file removed
- Post-cleanup G90: exit 0 (silent PASS)
- Post-cleanup G23: identical to pre-pollution (19 OK / 8 missing / 0 rust)
- Preserved as evidence: `runs/sdk-dragonfly-s2/feedback/skill-drift-POLLUTION-TEST.md`, this results doc, `runs/language-agnostic-audit.md`, `runs/pollution-test-spec.md`
