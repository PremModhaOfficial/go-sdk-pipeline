# Evolution State

Persistent state maintained by `learning-engine` across runs.

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
├── skill-candidates/<name>.json      — Drafts waiting for next run's bootstrap phase
├── guardrail-candidates/<name>.json  — Proposed new guardrails
└── evolution-reports/<run-id>.md     — Per-run evolution summary
```

## Safety gates (preserved from archive learning-engine)

- confidence=high required for auto-apply
- 2+ run recurrence (except CRITICAL)
- never deletes (append-only; use `status: deprecated`)
- resets baselines every 5 runs
- caps per run: ≤10 prompt patches, ≤3 new skills (non-bootstrap), ≤2 new guardrails, ≤2 new agents

## Paths ported from archive

`motadata-ai-pipeline-ARCHIVE/.feedback/learning/*` — same filenames, rebased under `evolution/`.
