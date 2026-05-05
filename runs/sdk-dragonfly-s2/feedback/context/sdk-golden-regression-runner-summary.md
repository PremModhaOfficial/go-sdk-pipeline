<!-- Generated: 2026-04-18T14:50:00Z | Run: sdk-dragonfly-s2 -->

# sdk-golden-regression-runner — Wave F5 Summary

## Verdict

**N/A — empty corpus.** First-ever pipeline run on this target SDK; no prior canonical fixtures exist to regress against.

## Inputs observed

- `golden-corpus/README.md` — present, declares intended seed fixtures `dragonfly-v1/`, `s3-v1/`, `kafka-consumer-v1/` (synthetic, except dragonfly-v1 which points at `core/l2cache/dragonfly/` Slice-1 baseline).
- `golden-corpus/<fixture>/` — **none materialized.** No `tprd.md`, `gate-answers.yaml`, `expected/`, or `metadata.json` trees.
- `settings.golden_corpus_refresh_every_n_runs = 25`; run counter = 1; refresh NOT due.
- `runs/sdk-dragonfly-s2/state/run-manifest.json` — testing phase completed, feedback phase pending.

## Procedure executed

1. Enumerated `golden-corpus/` — empty of fixtures.
2. Refresh cadence check — not due (0 of 25 runs since last refresh).
3. Skipped diff / tolerance / proof-rerun stages (nothing to diff).
4. Recorded seed candidacy for post-H10 human action (not performed here).

## Procedure skipped (and why)

- Temp target dir setup `/tmp/golden-sdk-dragonfly-s2-<fixture>` — no fixture to mount.
- Deterministic replay with `--seed` — no replay target.
- Byte-compare of pipeline-owned regions — no expected tree.
- MANUAL-region hash preservation check — no golden tree holds MANUAL regions to preserve.
- Constraint region proof-rerun — governed by testing phase (G97 already PASS-WITH-WAIVER on allocs_per_GET); not a golden-corpus concern this run.
- `feedback/golden-diffs/*.patch` emission — nothing to diff.

## Downstream implications

- **F6 improvement-planner**: may note "seed golden-corpus from this run post-H10" as a backlog item.
- **F7 learning-engine**: **NOT HALTED by F5.** Golden regression is silent this run. Other F4 signals (drift detector, coverage reporter, metrics-collector) govern F7 independently. Per CLAUDE.md §28, learning-engine still requires golden-regression PASS before auto-applying skill-version changes — but with an empty corpus there is no PASS to gate on; conservatively, learning-engine SHOULD restrict itself to patch-level (Z-bump) changes this run and defer any minor/major skill bumps until corpus is seeded. This is advisory to improvement-planner.
- **F8 baseline-manager**: unaffected.
- **F9 H10 merge recommendation**: unaffected by F5.
- **Post-H10 seeding (human action)**: if this run's output is approved as canonical, capture `golden-corpus/dragonfly-v1/` per README layout so the next dragonfly-related run has a regression target.

## Escalation

None. No ESCALATION emitted. learning-engine free to proceed in F7 with the advisory above.

## Seed-fixture candidacy

| Fixture           | Status          | Source                                |
|-------------------|-----------------|---------------------------------------|
| dragonfly-v1/     | CANDIDATE       | Pending H10 approval; commit a4d5d7f  |
| s3-v1/            | NOT-THIS-RUN    | Synthetic, unrelated to this TPRD     |
| kafka-consumer-v1/| NOT-THIS-RUN    | Synthetic, unrelated to this TPRD     |

## Artifacts

- `runs/sdk-dragonfly-s2/feedback/golden-regression.json`
- `runs/sdk-dragonfly-s2/feedback/context/sdk-golden-regression-runner-summary.md`
- Decision log entries seq 110–114 appended.

## Note on pipeline_version stamp

Run manifest records `pipeline_version: 0.1.0` (legacy stamp from run start); current settings are `0.2.0`. This agent stamps `0.2.0` on new entries per fleet rule 12; inconsistency noted for improvement-planner review but out-of-scope for F5.
