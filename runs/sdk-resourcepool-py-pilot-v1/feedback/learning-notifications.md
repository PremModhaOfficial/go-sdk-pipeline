<!-- Generated: 2026-04-29T19:14:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python | Mode A · Tier T1 -->
<!-- Author: learning-engine | Per CLAUDE.md rule 28: review each line below before approving merge at H10 -->

# Learning-Engine Notifications — H10 Review Surface

This file records every patch `learning-engine` applied in run `sdk-resourcepool-py-pilot-v1` plus every proposal it filed for human PR. Per CLAUDE.md rule 28, you (the user) read this list at H10 and may revert any individual `[APPLIED-*]` line by restoring the named `.bak-v<old>` backup OR by `git revert <commit>`. `[PROPOSAL-*]` lines are non-applied — they sit in the named docs file awaiting human PR authorship.

## Applied — Category A existing-skill body patches (3 of 3 cap; minor version bumps; append-only)

- [APPLIED-A1] python-asyncio-leak-prevention v1.0.0 → v1.1.0 — Gate 1 `autouse=True` directive strengthened with BAD/GOOD pair + opt-out marker plumbing + anti-pattern caption (defect SKD-001). Revert: restore `.claude/skills/python-asyncio-leak-prevention/SKILL.md.bak-v1.0.0` AND revert evolution-log entry, OR `git revert <commit>`.
- [APPLIED-A2] python-exception-patterns v1.0.0 → v1.1.0 — Rule 4 refactoring recipe added: drop `except BaseException` to `except Exception` (the preceding `CancelledError` arm becomes redundant since 3.8) (defect SKD-002 — _pool.py L247/L381/L451/L536). Revert: restore `.claude/skills/python-exception-patterns/SKILL.md.bak-v1.0.0` AND revert evolution-log entry, OR `git revert <commit>`.
- [APPLIED-A3] python-doctest-patterns v1.0.0 → v1.1.0 — new mandatory §CI Wiring section at head of body prescribing `pyproject.toml` `addopts` MUST include `--doctest-modules`; GOOD/BAD pyproject snippets + asyncio-flavored examples interaction note (defect SKD-003 — 9/9 public symbols had Examples blocks but build did not run them). Revert: restore `.claude/skills/python-doctest-patterns/SKILL.md.bak-v1.0.0` AND revert evolution-log entry, OR `git revert <commit>`.

## Proposed — Category B new artifacts (4 of 4; 0 of 0 created at runtime per safety_caps; filed to docs/ for human PR)

- [PROPOSAL-B1] python-bench-harness-shapes — filed to docs/PROPOSED-SKILLS.md §"Proposed: python-bench-harness-shapes" (HIGH confidence; addresses PA-001 + PA-002 — pytest-benchmark per-call timing assumption breaks for sync-fast-path-in-async + bulk-teardown shapes). New SKILL.md must be human-authored before any TPRD references it.
- [PROPOSAL-B2] G-toolchain-probe — filed to docs/PROPOSED-GUARDRAILS.md §"Proposed: G-toolchain-probe" (HIGH confidence; shared-core, intake phase; addresses TOOLCHAIN-ABSENCE root-cause — single-largest cost driver in this run, 3 impl sub-runs cascade). New script must be human-authored before runtime invocation.
- [PROPOSAL-B3] python-floor-bound-perf-budget — filed to docs/PROPOSED-SKILLS.md §"Proposed: python-floor-bound-perf-budget" (HIGH confidence; addresses PA-013 / FLOOR-BOUND-ORACLE — Go×10 oracle margin mechanically unreachable for symbols hitting Python language floor). New SKILL.md required for `floor_type` schema extension to perf-budget.md.
- [PROPOSAL-B4] soak-sampler-cooperative-yield — filed to docs/PROPOSED-SKILLS.md §"Proposed: soak-sampler-cooperative-yield" (MEDIUM confidence; shared-core; addresses PA-012 / SAMPLER-STARVATION — Python pack rediscovered a Go-pack soak bug because Go skill body was Go-specific). Shared-core skill prevents future language packs from re-deriving the warning.

## Proposed — Category D process / threshold / agent-prompt changes (3 of 3; filed to docs/PROPOSED-PROCESS.md for human PR)

- [PROPOSAL-D1] toolchain.<command>.min_version enforcement — filed to docs/PROPOSED-PROCESS.md §"Proposed: D1" (HIGH confidence; manifest schema change; addresses PA-004 ruff 0.4 vs PEP 639 mismatch surfacing late at M9). Owner: shared-core schema PR.
- [PROPOSAL-D2] guardrail header schema mode_skip + min_phase predicates — filed to docs/PROPOSED-PROCESS.md §"Proposed: D2" (HIGH confidence; addresses G200-py/G32-py false-BLOCKER waiver overhead on every Mode A Python run). Owner: package-authoring-guide doc owner + python pack maintainer.
- [PROPOSAL-D3] sdk-impl-lead halt policy on ≥2 INCOMPLETE-by-tooling per wave — filed to docs/PROPOSED-PROCESS.md §"Proposed: D3" (MEDIUM confidence; addresses TOOLCHAIN-CASCADE — impl-lead correctly tagged INCOMPLETE but kept marching across M3.5/M5/M7/M9). Owner: sdk-impl-lead author.

## Compensating-baseline regression scan

This is the first Python adapter run; per-language history files at `baselines/python/{output-shape-history.jsonl,devil-verdict-history.jsonl,coverage-baselines.json}` carry zero or one prior entries — below the rolling-N pre-conditions for shape-churn / devil-regression / example-drop signals. No `⚠ shape-churn`, `⚠ devil-regression`, or `⚠ example-drop` lines emitted. Quality-regression scan against `baselines/shared/quality-baselines.json` similarly has fewer than 3 prior Python runs; G86 BLOCKER pre-condition not met. Net: no regression signals to surface. Subsequent Python runs will gain signal coverage as history accumulates.

## NOTIFY summary

3 patches applied (A1, A2, A3); 4 Category-B proposals filed; 3 Category-D proposals filed; 0 regression signals; 0 cap exceedances. Safety caps respected: `existing_skill_patches_per_run = 3` of 3 used, `new_skills_per_run = 0` of 0, `new_guardrails_per_run = 0` of 0, `new_agents_per_run = 0` of 0, `prompt_patches_per_run = 0` of 10.
