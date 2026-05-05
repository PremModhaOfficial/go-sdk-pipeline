<!-- Generated: 2026-04-22T18:45:00Z | Run: sdk-dragonfly-p1-v1 -->
# Learning Notifications — sdk-dragonfly-p1-v1

**Patches applied this run: 0.**

No prompt patches. No existing-skill body patches. No new skills or guardrails (runtime cap = 0 per CLAUDE.md Rule 23).

## Why zero patches

The run executed cleanly end-to-end (intake BLOCKER resolved between first and second invocation via human authorship of 10 guardrail scripts; no in-pipeline learning-engine trigger fired). Devil verdicts all ACCEPT at H5; H7 auto-approved; H9 approved with enumerated deferrals. No review-fix loop iterations ran, so no prompt-patch candidates surfaced.

## Baseline observations

- **Output-shape hash** — not captured this run (single-session execution; would normally fire at F2 wave with the `sdk-shape-hash-recorder` agent).
- **Devil-verdict history** — not updated (F3 wave not invoked).
- **Coverage baseline** — package coverage 85.7% vs 94.4% in s2. Direct compare is misleading: s2 was greenfield (full test suite for all ~93 symbols); p1 is extension delta covering the new ~30 symbols plus a few modified helpers. Per-new-file coverage averages ~85%.
- **Quality regression (G86)** — skipped (precondition ≥3 prior runs; only `sdk-dragonfly-s2` exists).

## Deferrals filed for follow-up

Not learning-engine concerns, but worth the F6 improvement-planner's attention on the next run:

1. **perf-budget.md table format** — G107/G108/G109 scripts parsed the file without recognizing the table as declarative hot-paths / complexity / oracle entries. They passed as "no-op" rather than firing as real gates. A parser-matching YAML-ish format would make them load-bearing.
2. **Integration + bench phases skipped** — testcontainers Dragonfly + benchstat + `b.ReportAllocs()` runs are prerequisites for G104 to fire and for G108 to see real numbers. Per rule 33 these are legitimately INCOMPLETE, not PASS.
3. **Fuzz + Example_* skipped** — TPRD §11.4 + §12 require `FuzzKeyPrefix`, `FuzzJSONRoundTrip`, and one `Example_` per new feature. Deferred.
4. **P0 test-file footer-block extensions** — TPRD §14 Risk row 1 reflective lint test for KeyPrefix coverage across all `*Cache` methods was not written; TPRD §12 footer-block additions to `pipeline_test.go`, `pubsub_test.go`, `script_test.go`, `raw_test.go`, `hash_test.go`, `cache_test.go`, `cache_integration_test.go` were not emitted.
5. **KeyPrefix scope reduction** — P1 applies KeyPrefix to new methods only; P0 methods preserve byte-hash. TPRD §5.1 behavior matrix claims universal application. A follow-up TPRD addendum (or v2 of this TPRD) needs to choose between: (a) accept P1-scoped prefix, (b) permit P0 file modification via a G96 baseline re-capture, (c) ship a P2 extension that modifies P0 files under semver-major.

## Action items for the user

- Review the uncommitted working tree on `sdk-pipeline/sdk-dragonfly-p1-v1`.
- Decide H10: merge / keep branch / delete branch.
- If merging, first address at least the bench-run + fuzz gap to bring G104/G108 to real verdicts before production.
