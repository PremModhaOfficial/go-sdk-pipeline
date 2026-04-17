# Golden Corpus

Canonical SDK-addition fixtures the pipeline regresses against to detect capability degradation.

## Layout

```
golden-corpus/
├── <addition-name>-v1/
│   ├── tprd.md           — Exact TPRD that produced this fixture
│   ├── gate-answers.yaml — User answers to HITL gates for reproducibility
│   ├── expected/         — Expected generated files (for diff)
│   └── metadata.json     — run_id, pipeline_version, timestamp, verdict
```

## Seed fixtures

- `dragonfly-v1/` — L2 cache client (use existing `core/l2cache/dragonfly/` slice-1 as expected)
- `s3-v1/` — S3 object-store client (synthetic)
- `kafka-consumer-v1/` — Kafka consumer (synthetic)

## When fixtures get added

After a run completes with all gates PASS + user approves the output as "canonical", `sdk-golden-regression-runner` captures it as a fixture.

## When fixtures get used

- Every 25 runs: `golden-corpus-refresh` cadence (per plan Continuous Improvement Playbook)
- On `--golden-only` flag: re-runs all fixtures and reports deltas
- Before `learning-engine` auto-applies a major skill bump: mandatory regression check

## When fixtures get retired

- When underlying SDK conventions change (e.g., `motadatagosdk` bumps major version)
- When a skill that generated the fixture is deprecated
- Retirement recorded in `retired.jsonl`
