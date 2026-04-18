# Evolution State

Persistent state maintained by `learning-engine` across runs.

**Scope (post-Phase-1-removal)**: `learning-engine` patches **existing** skills and agent prompts based on defect signals. It does **not** create new skills or new agents at runtime. New skills and agents arrive only via human-authored PRs.

## Layout

```
evolution/
├── knowledge-base/
│   ├── agent-performance.jsonl       — Per-run per-agent quality scores
│   ├── defect-patterns.jsonl         — Recurring defect signatures
│   ├── communication-patterns.jsonl  — Inter-agent message patterns
│   ├── failure-patterns.jsonl        — Failure modes + recovery outcomes
│   ├── refactor-patterns.jsonl       — Refactor triggers + impact
│   ├── skill-effectiveness.jsonl     — Which skills helped / hurt
│   └── prompt-evolution-log.jsonl    — Every agent-prompt patch applied
├── prompt-patches/<agent>.md         — Applied prompt patches (append-only)
├── skill-candidates/<name>/          — Human-review drafts (see below)
└── evolution-reports/<run-id>.md     — Per-run evolution summary
```

## skill-candidates/ semantics

This directory is **a human-review inbox, not a runtime promotion target.** Drafts that appear here must be audited, edited, and PR-merged into `.claude/skills/<name>/` by a human. The pipeline never auto-promotes from this directory.

Current contents (8 drafts from prior Dragonfly-class runs): see `docs/PROPOSED-SKILLS.md` for the human-review backlog view.

## Safety gates (kept from archive, narrowed to skills-are-human-only)

| Gate | Before | After |
|---|---|---|
| Auto-apply confidence | `high` required | unchanged |
| Recurrence requirement | 2+ runs (except CRITICAL) | unchanged |
| Deletion | never (append-only; `status: deprecated`) | unchanged |
| Baseline reset | every 5 runs | unchanged |
| Per-run cap — prompt patches | ≤10 | unchanged |
| Per-run cap — **new skills** | ≤3 (bootstrap synthesis) | **0 (removed)** |
| Per-run cap — **new guardrails** | ≤2 | **0 (now human-only; propose via `docs/PROPOSED-GUARDRAILS.md`)** |
| Per-run cap — **new agents** | ≤2 | **0 (removed)** |
| Per-run cap — existing-skill body patches | — | ≤3 (minor-version-bump only) |
| Golden regression gate | required before auto-apply | unchanged |

## skill-candidates directory — transition note

The `evolution/skill-candidates/` directory (8 existing drafts from prior Dragonfly-class runs) is retained as a human-review inbox only. The pipeline does not auto-promote. A human must audit, revise if needed, move to `.claude/skills/<name>/`, and update `skill-index.json` via PR.
