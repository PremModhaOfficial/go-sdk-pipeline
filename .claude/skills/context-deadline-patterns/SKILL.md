---
name: context-deadline-patterns
description: `ctx.Deadline()` inheritance, cancellation safety, deadline-to-timeout bridging for SDK methods.
version: 0.1.0
created-in-run: bootstrap-seed
status: draft
source-pattern: synthesized-for-sdk-pipeline
priority: MUST
tags: [context, deadline, cancellation]
---

# context-deadline-patterns (DRAFT — skeleton; synthesized on first Phase -1 use)

This skill is a placeholder. Its full body will be authored by `sdk-skill-synthesizer` during the first Phase -1 bootstrap that touches this domain. The `sdk-skill-devil` will then review for ACCEPT / NEEDS-FIX / REJECT before the skill enters the active library.

## Purpose (seed)

`ctx.Deadline()` inheritance, cancellation safety, deadline-to-timeout bridging for SDK methods.

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
