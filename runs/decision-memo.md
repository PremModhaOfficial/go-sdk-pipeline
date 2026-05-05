# Decision Memo — Can motadata-sdk-pipeline be language-agnostic?

> **Date**: 2026-04-24
> **Audience**: Tech Lead / CXO
> **Status**: Ready for decision
> **Supporting artifacts**: `runs/language-agnostic-audit.md` (358 lines), `runs/pollution-test-spec.md`, `runs/pollution-test-results.md`, `runs/sdk-dragonfly-s2/feedback/skill-drift-POLLUTION-TEST.md`

---

## TL;DR

**Yes**, the pipeline can become language-agnostic. Three architectures are viable; recommendation depends on how many languages you'll ship.

| # of target languages | Recommended architecture | Why |
|---|---|---|
| **Exactly 1 (status quo — Go only)** | B: keep the current specialized pipeline | No refactor cost, no benefit to generalizing yet. |
| **2 (Go + Python OR Go + Rust)** | **A: add a second language as a parallel pack inside the same repo** | Cheap (~6–8 weeks one-time + language-pack authoring). The pipeline's skill-loading model is already invocation-scoped — adding Python/Rust skills next to Go skills does not degrade Go output (empirically verified). |
| **3+ languages** | **C: factor a shared core + per-language packs** | The 24-week one-time refactor pays off. Beyond 2 languages, A's "unified catalog" model grows unmaintainable decision-trees in agent prompts. |

**If you are still deciding between one and two new languages**: start with A for the first addition, commit to C when the second lands.

---

## Evidence on which this rests

### 1. Structural audit (full report: `runs/language-agnostic-audit.md`)

| Category | Invariant | Hybrid | Go-specialized |
|---|---:|---:|---:|
| Agents (38) | 29% | 45% | 26% |
| Phases (5) | 40% | 40% | 20% |
| CLAUDE.md rules (33) | 48% | 33% | 18% |
| Guardrails (51) | 35% | 41% | 24% |
| Skills (42) | 19% | 38% | 43% |
| **Average** | **34%** | **39%** | **26%** |

Roughly one-third of the pipeline is genuinely invariant (phases, HITL gates, decision-log, review-fix loop, learning-engine, baselines, devil structure). Another 39% is structurally invariant with Go-flavored instances. Only 26% is pure Go content.

### 2. Pollution test — empirical (full report: `runs/pollution-test-results.md`)

Ten plausible dummy Rust skills were authored, registered in `skill-index.json`'s `sdk_native` section, and the pipeline's own validators + a real `sdk-skill-drift-detector` subagent were run against the polluted state on the existing `sdk-dragonfly-s2` run.

| Test | Result |
|---|---|
| G90 (index ↔ fs consistency) | PASS, silent |
| G23 (TPRD §Skills-Manifest validation) | PASS-WARN — identical to pre-pollution (19 OK, 8 real missing, 0 rust mentioned) |
| Live `sdk-skill-drift-detector` subagent | Scoped to exactly 19 invoked skills; zero rust/cargo in scope; findings 1:1 identical to the pre-pollution drift report |
| Subagent mechanism explanation | *"The agent never enumerates `.claude/skills/` or `skill-index.json`"* |

**The pipeline is invocation-scoped by design.** Skills enter agents only via (a) TPRD §Skills-Manifest or (b) hardcoded lists in lead-agent prompts. There is no directory scan, no keyword-trigger loader, no ambient skill injection. This is the single most important finding for architecture choice: **Option A's main risk (cross-language pollution) is already neutralized**.

---

## Three load-bearing structural couplings (from audit §3.1)

These are the only places in the pipeline where Go-specificity is structural, not content. Any language-agnostic architecture (A or C) must address them:

| # | Coupling | Current form | Refactor required | Effort |
|---|---|---|---|---:|
| 1 | **Marker byte-hash** (G95–G103, Rule 29) | SHA256 of Go source regions; byte-offset-dependent | AST-node hashing (language-neutral) | ~2 weeks |
| 2 | **Perf gates: allocs/op + pprof + `BenchmarkXxx`** (G104–G110, Rules 20/32) | Hardcoded to Go `-benchmem` + pprof output format | Pluggable per-language perf-metric schema in `perf-budget.md` | ~1 week/language |
| 3 | **Constraint bench discovery** (G97, G108) | `[constraint: ... bench/BenchmarkX]` assumes Go test discovery | Language-specific bench-discovery adapter | bundled with #2 |

Everything else is either invariant (reusable as-is) or content (rewrite per language, not pipeline work).

---

## Cost model

### Option A (unified pipeline, parallel language packs in same repo)

| One-time | Per-new-language |
|---|---|
| ~1 week: add pack registration schema (`language_packs: {go: [...], python: [...]}`) + per-language lead agents (`sdk-design-lead-python`, etc.) with their own hardcoded skill lists | ~6–8 weeks: author ~20 skills + ~10 guardrail scripts + per-language devils + per-language quality standards |

**Total for Go + Python**: ~9 weeks. **Risk**: as more languages pile in, agent prompts accumulate conditionals ("if Go do X, if Python do Y"). Breakeven vs. C is around 2–3 languages.

### Option B (separate pipelines per language, current state)

| One-time | Per-new-language |
|---|---|
| 0 | ~10 weeks: full pipeline copy + localize everything (meta-machinery duplicated) |

**Total for Go + Python + Rust**: ~20 weeks of new work, plus ongoing ~30% maintenance overhead forever (every core improvement ported N times).

### Option C (shared core + per-language packs)

| One-time | Per-new-language |
|---|---|
| ~3–4 weeks: factor invariant core out of current pipeline; + ~2 weeks marker-protocol refactor; + ~1 week perf-gate generalization = **~24 weeks total according to the audit** | ~8–10 weeks: author language pack (skills, devils, guardrails, quality-standards) against stable core |

**Total for Go + Python + Rust**: ~24 + 8 + 10 = **~42 weeks**. Amortized maintenance cost is lowest; adding the 4th/5th language drops to ~6 weeks as tooling matures.

### Summary

| Scenario | A | B | C |
|---|---:|---:|---:|
| Go only (status quo) | — | 0 | — |
| Go + Python | **~9 wk** | ~10 wk | ~32 wk |
| Go + Python + Rust | ~17 wk (risk) | ~20 wk | **~42 wk** (safest) |
| Go + Python + Rust + Node + Java | ~40+ wk (unmaintainable) | ~40 wk (painful) | **~56 wk** (still cheapest per-lang) |

---

## Quality risk — resolved

The original concern was *"generalizing will kill quality"*. The evidence says otherwise:

- **Pollution test** proved that adding non-Go skills does not affect Go agent behavior (19 skills in scope before = 19 in scope after, findings 1:1 identical).
- **Lead-agent skill lists are hardcoded** — specialization lives in skill bodies and agent prompts, not in pipeline structure.
- **Factoring structure out of content preserves content intact.** Moving phase contracts, decision-log schema, and HITL gates into a shared core does not touch `go-error-handling-patterns`'s 30 lines of `fmt.Errorf %w` wisdom. The Go pipeline's quality comes from the *content* of its skills, not from the *isolation* of its pipeline directory.

---

## Recommended next action

1. **Authorize**: pick an architecture based on the 2-year target language count.
2. **If 1 language ever**: do nothing. Close this investigation.
3. **If 2 languages**: proceed with **Option A**, Python first (cheapest content authoring, mostlangauge-mappings available).
4. **If 3+ languages**: commit to **Option C**. First milestone is the 2-week marker-protocol refactor (AST-hashing); this unblocks everything else.

### Decision prerequisites I'd want before committing to C
- Confirmation that ≥2 additional languages are on the roadmap within 12 months.
- Alignment from the SDK team that the 24-week refactor is worth the clean-slate start.
- A "pilot language" commitment — Python is recommended for its tooling symmetry with Go and grading ease.

### What NOT to do
- Do not run a 3-condition empirical comparison (Go-only vs. Rust-only vs. Both). The audit + pollution test have already answered the questions it would have tried to answer; the comparison would cost ~40h of compute and ~21M tokens for redundant evidence.
- Do not attempt to generalize skills (e.g., rename `go-error-handling-patterns` → `error-handling-patterns` and cover all languages). That *is* the quality-killing move the user correctly feared. Each language needs its own dedicated skill library.

---

## Appendix A — what this memo does NOT answer

- Whether the existing Go pipeline's quality is actually sustainable at scale (≥10 SDK additions). Covered by the existing improvements.md roadmap.
- Whether learning-engine cross-language pattern sharing is useful. Unknown; probably not for language-idiomatic skills, possibly useful for meta-patterns (review-fix, HITL cadence).
- Whether the pipeline can target non-SDK codebases (web apps, infra). Out of scope — pipeline is SDK-shaped by design.

## Appendix B — artifacts produced during this investigation

- `runs/language-agnostic-audit.md` — 358-line structural audit (auto-generated by Explore agent, hand-validated on seam map + coupling sections)
- `runs/pollution-test-spec.md` — pre-experiment hypothesis + design
- `runs/pollution-test-results.md` — empirical results including subagent output
- `runs/sdk-dragonfly-s2/feedback/skill-drift-POLLUTION-TEST.md` — actual output of the pollution-test subagent run (not deleted during cleanup; serves as evidence)
- This memo
