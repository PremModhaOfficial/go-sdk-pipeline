---
name: sdk-golden-regression-runner
description: Phase 4 (and on --golden-only). Re-runs N latest canonical additions from golden-corpus/ against current agent+skill set. Flags divergence beyond tolerance.
model: opus
tools: Read, Glob, Grep, Bash, Write
---

# sdk-golden-regression-runner

## Input
- `golden-corpus/*/` fixtures
- Current `.claude/agents/` and `.claude/skills/` snapshot
- `runs/<run-id>/manifest.json`

## Procedure

For each fixture in `golden-corpus/` (in cadence: all on `--golden-only`; last 3 on normal Phase 4):

1. Set up temp target dir (`/tmp/golden-<run-id>-<fixture>`) mimicking target SDK base
2. Load `tprd.md` + `gate-answers.yaml` from fixture
3. Replay pipeline in deterministic mode (`--seed <fixed>`)
4. Diff produced output against `fixture/expected/`
5. Apply tolerance:
   - Pipeline-owned code regions → byte-compared (normalized for whitespace + timestamps)
   - MANUAL-marked regions → skipped (preserved in golden)
   - Constraint regions → proof re-run
6. Classify: PASS (diff within tolerance) / FAIL (substantive divergence)

## Output
`runs/<run-id>/feedback/golden-regression.json`:
```json
{
  "run_id": "...",
  "fixtures_tested": ["dragonfly-v1", "s3-v1", "kafka-consumer-v1"],
  "results": [
    { "fixture": "dragonfly-v1", "verdict": "PASS", "diff_bytes": 0, "diff_areas": [] },
    { "fixture": "s3-v1", "verdict": "FAIL", "diff_bytes": 1247, "diff_areas": ["s3/client.go:42-68 — retry logic differs"] },
    { "fixture": "kafka-consumer-v1", "verdict": "PASS", "diff_bytes": 120, "diff_areas": ["only comment formatting"] }
  ],
  "overall_verdict": "FAIL (1/3)"
}
```

## Escalation

If ANY fixture FAIL:
- Emit `ESCALATION: golden-corpus regression on <fixture>`
- `learning-engine` MUST HALT auto-apply of any patches this run
- User triage required at H9

## On --golden-only mode
Skip all other phases; run this agent only; exit with regression report.

## Output files
- `runs/<run-id>/feedback/golden-regression.json`
- `runs/<run-id>/feedback/golden-diffs/<fixture>.patch` (per-fixture git-style diff)
