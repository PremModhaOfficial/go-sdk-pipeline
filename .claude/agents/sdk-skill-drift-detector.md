---
name: sdk-skill-drift-detector
description: Phase 4. Compares what each invoked skill PRESCRIBED against what the generated code ACTUALLY does. Writes drift findings to feedback for improvement-planner.
model: opus
tools: Read, Glob, Grep, Write
---

# sdk-skill-drift-detector

## Input
- `runs/<run-id>/decision-log.jsonl` (mine for which skills were invoked by which agents)
- Generated code on branch
- Skills from `.claude/skills/<name>/SKILL.md`

## Procedure

For each skill invoked this run:
1. Parse SKILL.md for explicit prescriptions (MUST/MUST NOT clauses, code patterns in GOOD/BAD examples)
2. Grep generated code for violation patterns
3. Record findings with file:line references

### Example drift detection

Skill `sdk-config-struct-pattern` prescribes:
> MUST: Config struct fields are immutable post-construction. Callers pass Config by value to New().

Check generated code:
```bash
grep -n "func.*) Set.*(.*" "$SDK_TARGET_DIR/<pkg>/config.go"
# Finds: func (c *Config) SetRetries(n int)
```

Drift found: `Config` has exported mutable setter, violates immutability prescription.

## Output
`runs/<run-id>/feedback/skill-drift.md`:
```md
# Skill Drift Report

## Invoked skills (this run)
- sdk-config-struct-pattern v1.0.0
- go-concurrency-patterns v1.0.0
- otel-instrumentation v1.0.0

## Drift findings

### SKD-001: sdk-config-struct-pattern violated
Skill prescribes immutable Config.
Code has: `(*Config).SetRetries` (mutable setter) in `core/<pkg>/config.go:42`
Severity: HIGH
Recommendation: remove setter; require callers to construct new Config

### SKD-002: otel-instrumentation incomplete
Skill prescribes every error path emits span event.
Code missing: 3 error returns in `core/<pkg>/cache.go` do not record span events.
Severity: MEDIUM
```

Feeds `improvement-planner` in next wave.
