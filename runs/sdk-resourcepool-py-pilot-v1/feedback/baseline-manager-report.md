<!-- Generated: 2026-04-28T15:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: baseline-manager | Wave: F4 -->
# Baseline Manager Report — `sdk-resourcepool-py-pilot-v1`

**Role**: Per-language Python baseline pack materialized this run (testing-lead T2 seeded;
metrics-collector F1 updated shared). Baseline-manager F4 verifies + appends history,
runs the 4 compensating-baseline signal checks, evaluates the 5-run reset cap, and
attests zero unauthorized lowerings.

**Verdict**: ALL-PASS — no unauthorized lowerings, no compensating-baseline BLOCKERs,
5-run reset NOT-DUE, all writes append-only.

---

## 1. Per-baseline file: read-state → action → final-state

| File | Scope | Pre-run state | Action this run | Final state |
|---|---|---|---|---|
| `baselines/shared/quality-baselines.json` | shared | sdk-dragonfly-s2 first-run seed; 4 primary agents at 1.00 / 0.85 / 0.975 / 0.975 | **VERIFY-ONLY** (metrics-collector F1 owns writes; per-agent quality is authoritative). Cross-checked: pipeline_quality 0.95→0.978 (raise); sdk-design-lead 0.85→0.975 (raise +12.5%); 3 others held; 9 Python-design sub-agents seeded at 1.00. | Held authoritative — 0 unauthorized lowerings detected. |
| `baselines/shared/skill-health.json` (legacy stub) | shared-stub | sdk-dragonfly-s2 single-skill metrics; per_skill map for Go skills only | **VERIFY-ONLY** (metrics-collector F1 updated to add this-run invocation deltas + per_skill rows for python-* and shared skills). | Held authoritative; pointer to skill-health-baselines.json preserved. |
| `baselines/shared/skill-health-baselines.json` | shared (authoritative) | sdk-dragonfly-s2 first-run; runs_tracked=1; insufficient-data | **VERIFY-ONLY** — no metric exceeded thresholds; trend remains insufficient-data after run #2. (Updates that would raise targets are owned by F1; baseline-manager only flags unauthorized lowerings.) | Held; runs_tracked still recorded as 1 in file body — note: F1 did not bump runs_tracked here; we flag this as a non-blocking inconsistency for F1 to reconcile next run. |
| `baselines/shared/baseline-history.jsonl` | shared | 19 entries from sdk-dragonfly-s2 | **APPEND** (this report wave): added 13 new entries — 4 quality, 1 cross-language sub-agent seed, 2 coverage, 3 performance, 2 compensating-baseline, 1 skill-health, 1 reset-evaluation. | 32 total entries; append-only contract honored. |
| `baselines/python/performance-baselines.json` | per-language | Did not exist before this run | **SEED** (testing-lead T2 wrote; baseline-manager verifies). 8 symbols measured; 7 PASS, 1 PASS_WITHIN_P95_MARGIN (Pool.stats), 1 CALIBRATION_WARN (contention 32x). Alloc-budget PASS at 0.04/op vs 4 budget (100x headroom). | Held as written. Future Python runs gate against this seed via `sdk-benchmark-devil` (>5% per-symbol regression on hot path = BLOCKER). |
| `baselines/python/coverage-baselines.json` | per-language | Did not exist | **SEED** (testing-lead T2). Aggregate 92.33% combined (95.74% statements / 79.41% branches). Per-file map for 6 files. `example_count_per_package=3`. | Held as written. |
| `baselines/python/output-shape-history.jsonl` | per-language | Did not exist | **SEED** (testing-lead T2). 9 exported symbols; SHA placeholder `TBD-impl-marker-scanner-output` with named symbol list (canonical until next run computes the SHA). | Held as written; carry-over note for F1 next-run to materialize the actual SHA256. |
| `baselines/python/devil-verdict-history.jsonl` | per-language | Did not exist | **SEED** (testing-lead T2). 2 entries: impl wave (6 skills, all PASS/ACCEPT) + testing wave (8 skills, 7 PASS / 1 MIXED for benchmark-devil with CALIBRATION-WARN; block_rate=0.0 throughout). | Held as written. |
| `baselines/python/do-not-regenerate-hashes.json` | per-language | Did not exist | **SEED-EMPTY** (testing-lead T2). Mode A new package; zero `[do-not-regenerate]` markers (G100 PASS vacuously). Scaffold-only. | Held as written. |
| `baselines/python/stable-signatures.json` | per-language | Did not exist | **SEED** (testing-lead T2). 9 symbols at `[stable-since: v1.0.0]`. PoolConfig + Pool + PoolStats + AcquiredResource + 5 exception classes. Future signature changes require major bump per G101. | Held as written. |

**Net writes by baseline-manager this wave**: 1 file appended (`baselines/shared/baseline-history.jsonl`). All other baseline files were verified-only (metrics-collector F1 / testing-lead T2 own those writes per ownership matrix; lowering them would be a contract violation).

---

## 2. Compensating-baseline signal results (CLAUDE.md rule 28)

All four signals are **N/A first-run** for the per-language Python pack. Independent verification matches `learning-notifications.md` §Regression-signals exactly.

| # | Signal | Source baseline file | Status this run | BLOCKER threshold | Note |
|---|---|---|---|---|---|
| 1 | **output-shape-churn** | `baselines/python/output-shape-history.jsonl` | **N/A first-run** (WARN-level) | runs_tracked ≥ 2 with shared invoked-skills | Seed only; no prior shape exists to diff. Future runs SHA the sorted exported-symbol list and compare. The 3 skill patches (network-error-classification, pytest-table-tests, decision-logging) and 4 prompt patches will only be evaluated against shape from the next Python run that invokes any patched skill. |
| 2 | **devil-verdict-regression** | `baselines/python/devil-verdict-history.jsonl` | **N/A first-run** (WARN-level) | runs_tracked ≥ 2 + same skill invoked + ≥20pp block_rate jump | Seed only (2 entries: impl + testing waves). All 14 skill invocations show block_rate=0.0 baseline. Future runs evaluate post-patch jumps. |
| 3 | **quality-regression ≥5% per-agent** | `baselines/shared/quality-baselines.json` (per-agent) | **N/A first-run for sub-agents; HOLD-with-flag for impl-lead** (BLOCKER once sample-size satisfied) | runs_tracked ≥ 3 (G86) | impl-lead this-run 0.925 vs baseline 0.975 = -5.1% (would trigger G86 BLOCKER), but G86 precondition (runs_tracked ≥ 3) NOT met (runs_tracked = 2). Baseline held at 0.975 per do-not-lower contract; trend = `regression-flag`. Root: M10 rework on asyncio.Lock floor (hardware reality, not code regression). Documented in agents.sdk-impl-lead.reference_notes. **Action next-run**: if a third Python or Go run hits sdk-impl-lead < 0.926, G86 fires as BLOCKER. |
| 4 | **example_count_per_package drop** | `baselines/python/coverage-baselines.json` | **N/A first-run** (WARN-level) | runs_tracked ≥ 2 + drop in count | Seed value = 3. Future runs that drop below 3 trigger WARN. |

**Aggregate verdict**: REGRESSION_SIGNALS = [shape-churn:0, devil-regression:0, quality-regression:0-blocker (precondition-not-met), example-drop:0]. **No BLOCKER fires this run.** Matches `learning-notifications.md` §Regression-signals statement exactly — independent verification PASS.

---

## 3. 5-run reset evaluation

Per agent-spec + `quality-baselines.json.raise_policy.reset_interval_runs=5`:

| Pack | runs_tracked at end of this run | Reset due? | Action |
|---|---|---|---|
| shared (`baselines/shared/*`) | 2 (sdk-dragonfly-s2 + sdk-resourcepool-py-pilot-v1) | NOT-DUE (3 runs to next reset) | None |
| per-language go (`baselines/go/*`) | unchanged this run (1 prior Go run via shared inheritance) | NOT-DUE | None |
| per-language python (`baselines/python/*`) | 1 (this run is the first) | NOT-DUE (4 runs to next reset) | None |

**No reset performed.** Surfaced as a normal `reset-evaluation` history entry (append-only).

---

## 4. Zero-unauthorized-lowerings attestation

Cross-checked every numeric baseline value against the authoritative sources:

- `baselines/shared/quality-baselines.json`: pipeline_quality (0.95 → 0.978 RAISE); per-agent baselines 1.00 / 0.975 / 0.975 / 0.975 retained or raised — **0 lowered**.
- `baselines/shared/skill-health-baselines.json`: numeric metrics carry forward unchanged (skill_stability 0.105, accept_rate 1.0, manifest_miss blocking 0.0) — **0 lowered**.
- `baselines/python/*` (all 6 files): SEED writes (no prior values to lower against) — **0 lowered by definition**.
- `baselines/shared/baseline-history.jsonl`: append-only; preserved 19 prior entries verbatim, added 13 new entries — **0 prior entries deleted or rewritten**.

**Total unauthorized lowerings detected: 0.**

---

## 5. ESCALATIONS

**None.** No data-integrity issues, no contract violations, no blocked baselines.

One **non-blocking inconsistency** noted for next-run F1 reconciliation:
`baselines/shared/skill-health-baselines.json.runs_tracked` still reads `1` even though
this is the second pipeline run consuming this shared baseline. This is a metrics-collector
write-scope concern (F1 owns writes to that file body); baseline-manager flags but does
not edit (write-scope discipline). Recommended fix at next run F1: increment runs_tracked
to 2 (or 3 if next run lands first), re-evaluate trend from insufficient-data → stable.

---

## 6. Hand-off

- This wave (F4) closes Phase 4 baseline accounting for run `sdk-resourcepool-py-pilot-v1`.
- Next consumer: H10 reviewer reads `learning-notifications.md` first; this report is supplementary evidence that compensating-baseline signals were verified independently and concur with the learning-engine self-report.
- No baseline-manager action carries over to next run beyond the noted F1 reconciliation suggestion.

---

## 7. F4 continuation (orchestrator-applied; sub-agent quota hit at 24 tool uses)

The baseline-manager sub-agent above completed the verification + history append work, then hit the per-conversation sub-agent quota. The orchestrator (Claude) finished the residual mechanical work in-process per CLAUDE.md rule 10 degraded-mode policy. All four follow-up actions were either user-authorized or carry zero policy risk.

### 7.1 Resolved the TBD-impl-marker-scanner-output placeholder

`baselines/python/output-shape-history.jsonl` had `"exported_symbols_signature_sha256": "TBD-impl-marker-scanner-output"` from the testing-lead seed (T2). Per RULE 0, a TBD placeholder in a baseline file is tech debt. Orchestrator computed the SHA over the 9 declared exports + their `inspect.signature()` repr from `motadata-py-sdk@bd14539`:

```
SHA256: 374d5962917f4c40beb5be28e58fbf0d295ef67bd6b5ca6951a7e75573e7c8bc
```

Patched the file in place with the real hash + a `signature_method` attribution field. Future runs diff against this hash; churn surfaces as WARN per CLAUDE.md rule 28 signal #1.

### 7.2 Wrote `feedback/metrics.json` for G86

G86 (quality-regression check) expects `runs/<id>/feedback/metrics.json` (JSON shape: `.agents[].name + .quality_score`). `metrics-collector` (F1) wrote `metrics-report.md` (markdown). Orchestrator extracted the 28 per-agent quality scores from the .md into the JSON shape G86 expects. G86 then SKIPPED gracefully (need ≥3 prior runs; this is shared run #2). G86 will arm at run #4.

(Recommendation for next-run F1: have metrics-collector emit BOTH metrics-report.md AND metrics.json so G86 doesn't depend on orchestrator post-processing. Filed as a soft improvement candidate; not a learning-engine-applied patch this run.)

### 7.3 Patched `scripts/guardrails/G81.sh` (USER-AUTHORIZED)

G81 (compensating-baseline-advanced) hardcoded root-level paths (`baselines/output-shape-history.jsonl`, etc.) — predates v0.4.0 partition. With per-language partition, this run wrote to `baselines/python/output-shape-history.jsonl` and equivalents, so G81 saw "no baselines advanced" and FAILed. User authorized (AskUserQuestion answer "Patch G81.sh to recognize v0.4.0 per-language paths" on 2026-04-28).

Patch shape: extended `_candidate_paths(filename)` helper that searches `baselines/<filename>`, `baselines/<lang>/<filename>`, `baselines/shared/<filename>` for each named history file. Also added v0.4.0 per-package shape recognition for `coverage-baselines.json` (`packages.<pkg>.first_seeded_by_run == run_id`).

After patch: G81 PASS (3 baselines advanced for this run).

### 7.4 Patched `scripts/guardrails/G90.sh` (USER-AUTHORIZED)

G90 (skill-index ↔ filesystem strict equality) saw `.claude/skills/.idea/` (JetBrains IDE config materialized during this session at 13:47–13:50) as an unindexed skill subdir. User authorized (AskUserQuestion answer "Patch G90 to skip hidden dirs (recommended)" on 2026-04-28).

Patch shape: 1-line change adding `and not p.name.startswith(".")` to the iterdir filter. IDE configs / dot dirs are never skills.

After patch: G90 PASS (45 skills, no false-positives from `.idea/` or any future hidden dir).

### 7.5 Final Phase 4 guardrail re-run (post-fixes)

| Gate | Pre-fix | Post-fix |
|---|---|---|
| drift-check (G06+G90+G116) | FAIL (G90 .idea) | **PASS** |
| G80 | PASS | PASS |
| G81 | FAIL (root-path drift) | **PASS** (3 baselines advanced) |
| G83 | PASS | PASS |
| G84 | PASS | PASS |
| G85 | PASS | PASS |
| G86 | FAIL (metrics.json missing) | **SKIP** (need ≥3 prior runs; gracefully no-ops) |

All Phase 4 BLOCKER gates GREEN. H10 unblocked.

### 7.6 ESCALATIONS

None. All in-process work was either explicitly user-authorized (G81 + G90) or strictly mechanical (TBD resolution, JSON extraction).

baseline-skip-rationale: per v0.4.0 partition contract, baselines updated at baselines/python/* + baselines/shared/* (not baselines/* root); see entries advanced above.
