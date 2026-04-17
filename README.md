# motadata-sdk-pipeline

Multi-agent pipeline for adding/extending/updating clients in the [motadata-go-sdk](https://github.com/motadata/motadata-go-sdk) Go SDK.

## Purpose

Given a Technical PRD (TPRD) describing a new client (e.g., "add S3 client"), an extension ("add JetStream batching to events/"), or an incremental update ("tighten dragonfly retry defaults"), this pipeline:

1. **Bootstraps** any missing agentic skills required for the request (with devil review + user gate)
2. **Intakes** the TPRD — asking clarifying questions for ambiguous fields
3. **Designs** the API with adversarial review (design-devil, dep-vet-devil, semver-devil, convention-devil, security-devil)
4. **Implements** via TDD with marker-aware merging (respects `[traces-to: MANUAL-*]` and `[constraint: ...]` blocks)
5. **Tests** exhaustively (unit ≥90%, integration with testcontainers, bench + goleak + govulncheck)
6. **Evolves** itself via learning-engine, drift-detector, and golden-corpus regression

## Quick Start

```bash
# Prerequisites: SDK_TARGET_DIR env var pointing at your motadata-go-sdk working tree
export SDK_TARGET_DIR=/path/to/motadata-go-sdk/src/motadatagosdk

# From Claude Code:
/run-sdk-addition --target $SDK_TARGET_DIR "add Redis streams consumer client"

# Or with a pre-written TPRD:
/run-sdk-addition --target $SDK_TARGET_DIR --spec runs/my-tprd.md

# Dry-run (no writes):
/run-sdk-addition --dry-run "add S3 client"
```

## Phases

| # | Phase | Purpose |
|---|-------|---------|
| -1 | Bootstrap | Create/evolve agentic skills needed for this request |
| 0 | Intake | TPRD → canonical spec; clarifying questions |
| 0.5 | Extension-analyze | (Mode B/C only) Snapshot existing API + tests + benchmarks |
| 1 | Design | API design + devil review |
| 2 | Implementation | TDD with marker-aware merge |
| 3 | Testing | Unit + integration + bench + leak check |
| 4 | Feedback | Drift + golden + learning-engine patches |

## Request Modes

- **Mode A** — greenfield new package
- **Mode B** — extension (new capability in existing package)
- **Mode C** — incremental update (modify existing, respects markers)

## Directory Layout

```
.claude/agents/         — Agent prompts
.claude/skills/         — Skill files (versioned)
phases/                 — Phase docs
commands/               — Slash commands
runs/<run-id>/          — Per-run state + logs
baselines/              — Quality/coverage/perf baselines
golden-corpus/          — Canonical fixtures for regression
evolution/              — Learning-engine state (patches, skill drafts)
state/ownership-cache.json — Target-SDK-wide marker ownership map
docs/                   — Pipeline docs (backlog, architecture notes)
```

## Inspiration

Ported + evolved from `motadata-ai-pipeline-ARCHIVE/` (full SaaS multi-agent fleet). See `PROVENANCE.md` for what was ported and from which source SHA.

## Contributing

All agents, skills, and guardrails follow `AGENT-CREATION-GUIDE.md` and `SKILL-CREATION-GUIDE.md`. New skills must be versioned (`version:` frontmatter) and must pass `sdk-skill-devil` review before merge.

## License

(Match target SDK license.)
