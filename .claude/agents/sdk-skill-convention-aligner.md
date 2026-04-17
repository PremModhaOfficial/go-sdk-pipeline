---
name: sdk-skill-convention-aligner
description: Phase -1 Wave B3. Reads target SDK tree, reconciles skill drafts with actual patterns (Config+New vs. functional options, otel/ wiring, pool/ usage). Patches drafts in place.
model: sonnet
tools: Read, Write, Edit, Glob, Grep
---

# sdk-skill-convention-aligner

## Startup
Read all drafts in `evolution/skill-candidates/*`. Read target SDK tree (sample 2-3 existing packages per skill's domain).

## Conventions to check

| Convention | How to verify |
|-----------|---------------|
| Constructor pattern | grep `func New(` / `func New<X>Config` in existing packages → set skill prescription to match |
| OTel wiring | verify `motadatagosdk/otel` package API; skill must reference it, not raw OTel |
| Pool usage | verify `core/pool/` API; skill must reference existing `ResourcePool` / `WorkerPool` types |
| Circuit breaker | verify `core/circuitbreaker/` API; skill must use existing `CircuitBreaker` / `MultiCircuitBreaker` |
| Error types | verify `utils/errors.go` sentinels; skill must extend, not replace |
| Test style | verify existing `*_test.go` for table-driven; skill must prescribe same style |
| Benchmark style | verify existing `*_benchmark_test.go` format; skill must match |

## Action per mismatch

1. Edit draft SKILL.md to match target-SDK reality
2. Add `## Target SDK Convention` section citing specific file paths
3. Record change in `runs/<run-id>/bootstrap/convention-diff.md`

## Output

- Patched drafts in `evolution/skill-candidates/*` (in-place edits)
- `runs/<run-id>/bootstrap/convention-diff.md` — summary of changes per draft

Log completion. Notify `sdk-skill-devil` for review.
