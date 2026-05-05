# Pollution Test — Specification

> **Purpose**: measure whether the *presence* of non-Go skills in the pipeline's awareness degrades output quality on a Go run. Resolves the A-vs-B-vs-C architecture question before committing to any refactor.
>
> **Status**: SPEC ONLY — no files authored, no run executed. Awaiting user go/no-go.

---

## Hypothesis and prediction

**H₀ (null)**: Adding non-Go skills to `.claude/skills/` and registering them in `skill-index.json` does **not** measurably change output on a Go-targeted TPRD run with the same seed.

**H₁ (alt)**: It does — either via skill-coverage leakage (a Go agent consults a Rust skill), or via prompt-context bloat affecting agent reasoning, or via subtle convention drift.

**Prediction**: H₀ likely holds because (a) agents load skills by name from `TPRD §Skills-Manifest`, not by scanning the directory; (b) `skill-index.json` already carries `tags_index` distinguishing `meta` / `go` / `sdk` / etc. — the seam is present, just unenforced.

But we need the empirical check because the prompt-bloat effect on leads (especially `sdk-design-lead`) is not derivable from static analysis.

---

## Test design — three variants, pick based on budget

### Variant 0 — static analysis only (0 tokens, ~30 min)
`grep -r` across every agent prompt for: (a) whether skills are consulted by name vs. by directory scan; (b) whether any agent is instructed to "consider all available skills". If every agent consumes a fixed manifest, H₀ is already strong and we can skip running.

### Variant 1 — single-agent spike (~150K tokens, ~20 min)
Run **only `sdk-design-lead`** on the Dragonfly P1 TPRD. This is the most skill-dependent single agent. If pollution doesn't move its output, downstream won't either.

### Variant 2 — Phase 0 + Phase 1 only (~650K tokens, ~80 min)
Run Intake + Design with the same seed on the same TPRD, twice. Compare design artifacts (`api.go.stub`, `dependencies.md`, devil verdicts).

### Variant 3 — full-pipeline rerun (~2.35M tokens, ~4.5h)
Only if Variants 1/2 show churn and we need to quantify blast radius downstream.

**Recommendation**: run Variant 0 first (free), then Variant 1 if V0 doesn't rule out pollution, then Variant 2 only if V1 shows churn.

---

## Baseline (X1)

Use `runs/sdk-dragonfly-s2/` — already completed, artifacts present:
- `design/` — Phase 1 outputs, the X1 for comparison
- `decision-log.jsonl` — token usage, agent activity
- `run-summary.md` — aggregate metrics
- `tprd.md` — canonical TPRD (same input as X2)

**Do not re-run the clean side.** X1 is the existing Dragonfly run.

## Treatment (X2)

Same TPRD, same seed, same pipeline version. The only change: 10 dummy Rust skills are present + registered.

---

## The 10 dummy Rust skills (names + descriptions)

Authored to look legitimately like Rust skills that *would* exist in a Rust pack. Purpose: maximize surface area for potential pollution (topically diverse, covering areas a Rust SDK would need).

| # | Name | Description (skill frontmatter) | Analog |
|---|---|---|---|
| 1 | `rust-error-handling` | Rust `Result<T, E>`, `?` operator, `thiserror` / `anyhow`, error enum hierarchies. | mirrors `go-error-handling-patterns` |
| 2 | `rust-async-tokio` | Tokio runtime, `async fn`, `.await`, `tokio::spawn`, `JoinHandle`, cancellation via `CancellationToken`. | mirrors `go-concurrency-patterns` |
| 3 | `rust-ownership-borrow` | Ownership, borrow checker, lifetimes, `Cow`, interior mutability (`RefCell` / `Mutex`). | no Go analog — pure Rust |
| 4 | `rust-trait-design` | Trait design, associated types, `dyn Trait` vs generics, supertraits, object safety. | mirrors `go-struct-interface-design` |
| 5 | `rust-cargo-workspace` | Cargo workspace layout, feature flags, `[dev-dependencies]`, `build.rs`. | mirrors `go-module-paths` |
| 6 | `cargo-audit-deps` | `cargo-audit`, `cargo-deny` license + advisory checks, supply-chain vetting. | mirrors `go-dependency-vetting` |
| 7 | `rust-test-patterns` | `#[test]`, `#[tokio::test]`, table-driven tests via macros, property testing with `proptest`. | mirrors `tdd-patterns` + `table-driven-tests` |
| 8 | `rust-criterion-bench` | `criterion` benchmarking, black_box, statistical harness, throughput measurement. | mirrors Go's `benchstat` workflow |
| 9 | `rust-tracing-opentelemetry` | `tracing` crate, `tracing-opentelemetry` bridge, span instrumentation, fields. | mirrors `otel-instrumentation` |
| 10 | `rust-unsafe-audit` | `unsafe` block justification, `miri` validation, FFI boundaries, soundness review. | no Go analog — pure Rust |

**Body size**: ~60-100 lines per skill, plausible technical content. Authoring cost: ~1 hour total if we proceed.

---

## Registration changes

**Append to `.claude/skills/skill-index.json`** (new top-level section + new tag):

```json
"rust_pack": [
  { "name": "rust-error-handling", "version": "1.0.0", "status": "experimental" },
  { "name": "rust-async-tokio", "version": "1.0.0", "status": "experimental" },
  ... (all 10)
],
"tags_index": {
  ...
  "rust": ["rust-error-handling", "rust-async-tokio", "rust-ownership-borrow", ...]
}
```

**Do NOT** add any dummy skill to any TPRD §Skills-Manifest or any agent prompt. The test is about *presence*, not *invocation*.

---

## Metrics (what to measure on X1 vs X2)

| # | Metric | Source | Threshold for "pollution detected" |
|---|---|---|---|
| 1 | Design stub byte-diff (`api.go.stub`) | `runs/<id>/design/api.go.stub` | any diff outside comments/whitespace |
| 2 | Exported-symbol set | diff of signatures from `api.go.stub` | any added/removed/renamed symbol |
| 3 | Devil verdicts (per devil, per finding) | `runs/<id>/design/reviews/` | any verdict flip (PASS↔FAIL) or >2 new findings |
| 4 | Dependencies list | `runs/<id>/design/dependencies.md` | any new/removed dep |
| 5 | Skill-coverage entries | `decision-log.jsonl` entries where `type: skill-evolution` or agents cite a skill | any reference to a `rust-*` skill by a Go agent = DEFINITIVE pollution |
| 6 | Per-agent `quality_score` (Phase 1 only) | computed per formula in PIPELINE-OVERVIEW §12 | ≥5% drop on any agent (matches G86 threshold) |
| 7 | Phase 1 token usage | `decision-log.jsonl` budget entries | ≥10% delta is suspicious (but expected variance is ~5-8%) |

### Decision rules

- **Metric 5 triggers alone** → H₁ confirmed, pollution is real. Unified pipeline (A) requires a strict filter. Verdict: C is the only safe option, and the filter in C must be strict "packs are mounted not merged".
- **Metrics 1-4 all clean, only 6-7 show small variance** → H₀ holds, pollution risk is small. Unified-with-filter (A) is viable. C remains recommended for maintenance reasons.
- **Metrics 1-4 show churn without metric 5** → pollution via prompt-bloat, harder to diagnose. Retry with Variant 2 and instrument agent prompts with explicit "you may only use skills in TPRD §Skills-Manifest" directives, compare.

---

## Rollback

If the run completes and we want to remove the pollution:
1. `rm -r .claude/skills/rust-*`
2. Revert the `skill-index.json` patch (keep a `.bak` before editing)
3. `rm -r runs/<pollution-run-id>/`

Zero risk to existing Dragonfly run or baselines.

---

## Open questions for user

1. **Which variant to run** (0 → 1 → 2 → 3)? Recommend starting with 0 (free) then 1 (~150K tokens).
2. **Am I allowed to create `runs/sdk-dragonfly-s2-polluted/`** as the X2 run, or should this go somewhere else (e.g., `runs/experiments/`)?
3. **Can I author the 10 dummy skills and modify `skill-index.json`**, given the rule that skill-index is human-curated? (I can mark them `status: experimental` and mark the commit so they're trivially revertible.)
4. **Should the dummy skills be plausible (hard to distinguish from real)** or clearly-dummy (`DUMMY-rust-error-handling`, skill body says "this is a pollution-test stub")? The plausible version is a stronger test (measures realistic pollution); the dummy version is safer (no risk a real run ever accidentally uses them). I lean plausible + `status: experimental` + a LOAD-BEARING comment at top of each SKILL.md body.

---

## Cost summary

| Variant | Prep | Run tokens | Run wall-clock |
|---|---|---:|---:|
| 0 (static only) | 30 min | 0 | 0 |
| 1 (design-lead spike) | 1h (authoring) + 10 min (registration) | ~150K | ~20 min |
| 2 (Phase 0+1) | same prep | ~650K | ~80 min |
| 3 (full pipeline) | same prep | ~2.35M | ~4.5h |

All variants use X1 = existing Dragonfly run (no re-run cost on the clean side).
