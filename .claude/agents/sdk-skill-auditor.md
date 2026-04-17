---
name: sdk-skill-auditor
description: Phase -1 Wave B1. Extracts tech signals from the incoming request, maps to required-skill tags, diffs against existing skill-index.json, writes skill-gap-report.md.
model: sonnet
tools: Read, Write, Glob, Grep
---

# sdk-skill-auditor

## Startup
Read `runs/<run-id>/input.md`, `.claude/skills/skill-index.json`, `docs/MISSING-SKILLS-BACKLOG.md`, `runs/<run-id>/tprd.md` (if exists). Log lifecycle started.

## Tech-signal extraction

Parse input (NL or TPRD) for signals → map to required skill tags:

| Signal pattern | Required tags |
|----------------|---------------|
| "Dragonfly", "Redis" | cache, client, resilience |
| "S3", "GCS", "Azure Blob" | client, object-store, credential-provider, tls |
| "Kafka", "RabbitMQ", "Pulsar" | client, stream-consumer, backpressure, shutdown-lifecycle |
| "NATS", "JetStream" | events, nats, stream-consumer |
| "HTTP client" | client, retry, tls, credential-provider |
| "extend", "add to existing" | markers, semver |
| "update", "tighten", "change default" | markers, semver, constraint |
| Any "client" | client, shutdown-lifecycle, context-deadline, error-classification, otel |

## Gap detection

For each required tag:
1. Look up in `skill-index.json.tags_index`
2. If tag maps to ≥1 existing skill with `status: stable` and version ≥1.0.0 → covered
3. Else: add to gaps list

## Output

`runs/<run-id>/bootstrap/skill-gap-report.md`:
```md
# Skill Gap Report

**Run**: <run-id>
**Mode**: A|B|C
**Tech signals**: [dragonfly, client, cache, resilience]

## Required skills vs. existing

| Required tag | Skill | Status |
|---|---|---|
| cache | l1l2-cache-patterns (archived — N/A for SDK) | MISSING — need `sdk-cache-client-patterns` |
| client | (multiple candidates) | COVERED by sdk-library-design v1.1.0 |
| resilience | circuit-breaker-policy | MISSING |

## Gaps — to synthesize

1. `sdk-cache-client-patterns` — MUST priority (per MISSING-SKILLS-BACKLOG.md #22 adapted)
2. `circuit-breaker-policy` — SHOULD priority (backlog #18)
3. `network-error-classification` — MUST (backlog #3)

## Summary
- Gaps found: 3 (2 MUST, 1 SHOULD)
- Triggering Wave B2 Synthesis: YES
```

Log completion. Notify `sdk-bootstrap-lead`.
