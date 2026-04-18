<!-- Source: retro-testing P1 (TPRD §10 allocs ≤ 3 unachievable vs go-redis floor); anomaly A3 -->
<!-- Confidence: MEDIUM -->
<!-- Run: sdk-dragonfly-s2 | Wave: F6 -->
<!-- Status: DRAFT — learning-engine (F7) decides whether to apply. Append-only to agent's ## Learned Patterns section. -->

## Learned Patterns

### Pattern: CALIBRATION-WARN classification for dep-floor-unachievable constraints (T5)

**Rule**: When a TPRD §10 numeric constraint fails bench evaluation AND the failure mode is "target < underlying dep's measured floor" (not a regression or a wiring defect in the pipeline's code), classify the outcome as **CALIBRATION-WARN**, not FAIL. Emit an H8 gate with Option A (accept-as-calibration-miss with baseline update) pre-selected as the recommended path — the constraint is mechanically unreachable and a code fix cannot resolve it.

**How to classify (T5 + benchmark-devil handoff)**:
1. On bench result miss, consult `baselines/performance-baselines.json` and the proposed `G66` guardrail's calibration file for the underlying client's floor.
2. If `measured_value ≈ dep_floor` and `tprd_target << dep_floor`, mark the finding `CALIBRATION-WARN` in `testing/bench-calibration.md` with: constraint, target, measured, dep_floor, delta-to-floor-vs-delta-to-target.
3. Do NOT emit H8 with BLOCKER tone. The gate is still required (H8 is user-facing constraint-acceptance) but recommendation is Option A (waiver + baseline update), not Option D (halt).
4. If `measured_value >> dep_floor` (the SDK wrapper is the problem, not the dep), continue to classify as FAIL — the wrapper has a correctable allocation/latency issue.

**Evidence from sdk-dragonfly-s2**: BenchmarkGet showed 32 allocs/op against TPRD target ≤ 3. go-redis v9 measured floor in the same bench context is ~25-30. Gap to floor ≈ 2-7 allocs (wrapper overhead), gap to target = 29. This is a calibration miss, not a wrapper defect. H8 Option A (accept with baseline revised to ≤ 35) was approved correctly, but the original classification was "constraint failure" — future runs should pre-classify and reduce H8 friction.

### Pattern: miniredis-family gap enumeration in TPRD §11.1

**Rule**: At T2 integration-test start, scan TPRD §11.1 for a `not-covered-by-fake-client:` list. If absent, log an ESCALATION to phase-retrospector recommending TPRD §11.1 amendment with explicit fake-client coverage exclusions. In the meantime, any SKIP caused by a fake-client limitation MUST be accompanied by a `//` comment that cites the specific command and the fake-client's lack of support, plus an `integration/` counterpart test gated on `//go:build integration`.

**Evidence from sdk-dragonfly-s2**: `miniredis/v2` does not implement the Redis 7.4 HPExpire-family commands (`HPEXPIRE`, `HEXPIREAT`, `HTTL`, `HPERSIST`). TestHash_HExpireFamily has a partial `t.Skip` with a comment; the integration test `TestIntegration_HExpire` covers the live case. TPRD §11.1 did not document this known gap, so the skip looked surprising during T2. A single line in TPRD §11.1 ("miniredis v2.37 does NOT support HEXPIRE family — covered by integration") would have set the expectation.

---

**Apply behavior**: learning-engine should append the above two subsections to the end of `.claude/agents/sdk-testing-lead.md` under a `## Learned Patterns` heading. Do NOT modify existing agent content. On apply, log `prompt-evolution-log.jsonl` entry with source-run `sdk-dragonfly-s2`, patch-id `PP-04-testing`, and the exact diff applied. **Confidence is MEDIUM** — the CALIBRATION-WARN classification should ideally be backed by guardrail G66 (proposed in PROPOSED-GUARDRAILS.md); learning-engine may prefer to wait for G66 promotion before applying this patch.
