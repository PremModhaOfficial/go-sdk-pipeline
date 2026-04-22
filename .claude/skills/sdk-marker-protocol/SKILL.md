---
name: sdk-marker-protocol
description: Code provenance markers — `[traces-to:]`, `[constraint:]`, `[stable-since:]`, `[owned-by:]`, `[deprecated-in:]`, `[do-not-regenerate]`, `[perf-exception:]`. Drives marker-scanner + constraint-devil + marker-hygiene-devil.
version: 0.2.0
created-in-run: bootstrap-seed
status: draft
source-pattern: synthesized-for-sdk-pipeline
priority: MUST
tags: [markers, provenance, merge, mode-b, mode-c, perf-exception]
---

# sdk-marker-protocol (DRAFT — skeleton; synthesized on first Phase -1 use)

This skill is a placeholder. Its full body will be authored by `sdk-skill-synthesizer` during the first Phase -1 bootstrap that touches this domain. The `sdk-skill-devil` will then review for ACCEPT / NEEDS-FIX / REJECT before the skill enters the active library.

**Canonical source of marker rules**: `CLAUDE.md` rule 29 (Code Provenance Markers).

## Purpose (seed)

Code provenance markers — `[traces-to:]`, `[constraint:]`, `[stable-since:]`, `[owned-by:]`, `[deprecated-in:]`, `[do-not-regenerate]`, `[perf-exception:]`. Drives marker-scanner + constraint-devil + marker-hygiene-devil.

### Marker: `[perf-exception: <reason> bench/BenchmarkX]` (added v0.2.0)

Exempts a symbol from `sdk-overengineering-critic` findings when the complexity is **measurably justified** by a benchmark win.

**Pairing requirement (enforced by G110)**: every `[perf-exception:]` marker in source MUST have a matching entry in `runs/<run-id>/design/perf-exceptions.md` authored by `sdk-perf-architect` at design time. The entry records:
- `symbol`: fully qualified symbol name
- `marker`: exact marker text (so grep can verify)
- `reason`: engineer-readable justification
- `justified_by_bench`: the bench name referenced in the marker
- `reverts_cleanliness_rule`: which critic finding this overrides (e.g., `overengineering-critic:hand-rolled-abstraction`)
- `must_reprove_on_change`: boolean — if true, any edit to the symbol re-triggers profile-auditor + benchmark-devil

**Orphan detection** (G110 BLOCKER cases):
- Marker in source with no matching perf-exceptions.md entry — "sneak-through" attempt
- Entry in perf-exceptions.md with no matching marker in source — stale declaration; should be removed
- Marker bench name mismatches the entry's `justified_by_bench` — inconsistent

Rule 32 (Performance-Confidence Regime) positions `[perf-exception:]` as one of the seven falsification axes — it's the escape hatch that keeps clean-code gates and perf gates from becoming contradictory.

## Activation signals

- When an SDK addition touches the domain this skill covers
- When a devil / reviewer agent cites a gap that this skill should fill
- When the skill auditor (Phase -1) flags this skill as MUST for the current TPRD

## Required content (per SKILL-CREATION-GUIDE.md)

- Rationale — why the pattern exists
- GOOD examples — 3+ code snippets drawn from the target SDK
- BAD examples — 3+ anti-patterns with explanation
- Decision criteria — when to apply vs. not
- Cross-references to other skills
- Guardrail hooks — which G-checks enforce this skill

## Synthesis prompt hint

`sdk-skill-synthesizer` should consult:
- The target SDK tree at `$SDK_TARGET_DIR` for existing conventions
- `docs/MISSING-SKILLS-BACKLOG.md` for the original gap description
- Context7 / Exa for community patterns (aws-sdk-go-v2, stripe-go, kubernetes client-go)

## Status

`draft` — not yet usable by downstream agents. Devil MUST review before promotion to `stable`.
