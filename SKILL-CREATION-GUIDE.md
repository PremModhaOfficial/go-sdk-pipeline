# Skill Creation Guide (SDK pipeline)

Ported from `motadata-ai-pipeline-ARCHIVE/SKILL-CREATION-GUIDE.md` @ b2453098. See that file for the base 16-check validator and template. This document layers the SDK-mode deltas on top.

## SDK-mode deltas (vs. archive)

### 1. Mandatory `version:` frontmatter

Every skill MUST declare a semver:

```yaml
---
name: sdk-config-struct-pattern
description: ...
version: 1.0.0
created-in-run: <run-id>
last-evolved-in-run: <run-id>
source-pattern: core/l2cache/dragonfly/
status: stable | draft | deprecated
tags: [sdk, client, config, constructor]
---
```

- Patch bump (1.0.0 → 1.0.1): append-only, no semantic change
- Minor bump: new examples, extended scope
- Major bump: breaking reinterpretation; requires user approval + golden-corpus regression

### 2. Mandatory `evolution-log.md` sibling

Each `.claude/skills/<name>/` dir MUST contain `evolution-log.md`:

```
## 1.2.0 — run-<id> — 2026-MM-DD
Triggered by: <agent> finding <id>
Change: <one-line summary>
Devil verdict (sdk-skill-devil): ACCEPT / NEEDS-FIX / REJECT
Applied by: learning-engine / user / agent-bootstrapper
## 1.1.0 — ...
```

### 3. DROP multi-tenancy-mandatory clause

Archive guide requires data/API skills include multi-tenancy patterns. SDK is a library — tenant context is caller-supplied. Drop this requirement.

### 4. ADD target-SDK-convention clause

Every skill whose domain touches target SDK structure (package layout, constructor pattern, OTel wiring) MUST include a section:

```
## Target SDK Convention

Current convention in motadatagosdk: <what the SDK does today>
If TPRD requests divergence: <decision procedure>
```

### 5. ADD 3+ GOOD/BAD examples sourced from target SDK

Examples must cite actual files in the target SDK where possible. Purely synthetic examples ok only when no target-SDK equivalent exists.

### 6. Devil review on every new skill

Before a skill is merged into `.claude/skills/`, `sdk-skill-devil` produces a verdict. Verdicts recorded in `evolution-log.md` + `decision-log.jsonl` with `type: skill-evolution`.

## Skill file layout

```
.claude/skills/<skill-name>/
├── SKILL.md              ← required
├── evolution-log.md      ← required, append-only
├── reference/            ← optional, longer examples
│   └── *.md
└── examples/             ← optional, runnable Go snippets
    └── *.go
```

## Final checklist

The archive's 16-check validator + these SDK-mode checks:

17. `version:` frontmatter present and semver-valid
18. `evolution-log.md` exists with at least one entry
19. Target SDK Convention section present if domain touches SDK structure
20. ≥3 GOOD/BAD examples, ≥1 sourced from target SDK (when applicable)
21. `sdk-skill-devil` verdict ACCEPT (recorded in evolution-log.md)
22. No prescription requires `encoding/json` for internal patterns (SDK prefers MsgPack for NATS-adjacent code)
23. No tenant_id column / schema-per-tenant artifacts proposed
