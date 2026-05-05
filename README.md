<!-- cross_language_ok: true — top-level pipeline doc references per-pack tooling and the multi-tenant SaaS platform context (per F-008 in migration-findings.md). Authoritative project description: SDK is built FOR multi-tenant SaaS consumers; multi-tenant guardrails (TenantID, JetStream, MsgPack, schema-per-tenant) are in-scope. -->

# motadata-sdk-pipeline

Multi-agent pipeline for adding/extending/updating clients in the [motadata-go-sdk](https://github.com/motadata/motadata-go-sdk) Go SDK.

## Purpose

Given a **detailed** Technical PRD (TPRD) — including `§Skills-Manifest` and `§Guardrails-Manifest` — describing a new client (e.g., "add S3 client"), an extension ("add JetStream batching to events/"), or an incremental update ("tighten dragonfly retry defaults"), this pipeline:

1. **Intakes** the TPRD — validates manifests, canonicalizes, asks clarifying questions only for residual ambiguities
2. **Designs** the API with adversarial review (design-devil, dep-vet-devil, semver-devil, convention-devil, security-devil, overengineering-critic)
3. **Implements** via TDD with marker-aware merging (respects `[traces-to: MANUAL-*]` and `[constraint: ...]` blocks)
4. **Tests** exhaustively (unit ≥90%, integration with testcontainers, bench + goleak + govulncheck)
5. **Evolves** existing skills via learning-engine + drift-detector; every applied patch is recorded in a per-run `learning-notifications.md` file that the user reviews at H10 (new skills are human-authored via PR only — see `docs/PROPOSED-SKILLS.md`)

This is an **NFR-driven pipeline**: §NFR and §Benchmarks in the TPRD are first-class numeric gates, not afterthoughts.

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
| 0 | Intake | TPRD → canonical spec; Skills-Manifest + Guardrails-Manifest validation; clarifying questions |
| 0.5 | Extension-analyze | (Mode B/C only) Snapshot existing API + tests + benchmarks |
| 1 | Design | API design + devil review |
| 2 | Implementation | TDD with marker-aware merge |
| 3 | Testing | Unit + integration + bench + leak check |
| 4 | Feedback | Drift + coverage + learning-engine patches (existing skills only) + per-patch user notifications |

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
evolution/              — Learning-engine state (patches, skill drafts)
state/ownership-cache.json — Target-SDK-wide marker ownership map
docs/                   — Pipeline docs (backlog, architecture notes)
```

## Contributing

All agents, skills, and guardrails follow `AGENT-CREATION-GUIDE.md` and `SKILL-CREATION-GUIDE.md`. New skills must be versioned (`version:` frontmatter) and authored via human PR — there is no runtime skill synthesis. See `docs/PROPOSED-SKILLS.md` for the human-review backlog.

## License

(Match target SDK license.)
