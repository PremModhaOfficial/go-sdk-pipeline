<!-- Source: retro-intake P1 (TPRD perf-constraint vs dep-floor mismatch); anomaly A3 (allocs ≤ 3 vs go-redis v9 floor ~25-30 forced H8 waiver); retro-testing §Systemic Patterns -->
<!-- Confidence: HIGH -->
<!-- Run: sdk-dragonfly-s2 | Wave: F6 -->
<!-- Status: DRAFT — learning-engine (F7) decides whether to apply. Append-only to agent's ## Learned Patterns section. -->

## Learned Patterns

### Pattern: TPRD §10 numeric-constraint vs dependency-baseline cross-check (I3)

**Rule**: For every numeric constraint in TPRD §10 (allocs/op, ns/op, bytes/op, P50/P99, throughput), before accepting the TPRD at H1, look up the underlying client library's known baseline and flag WARN when the TPRD target is mechanically unreachable without swapping clients.

**How to check (intake wave I3)**:
1. Parse TPRD §10 for every `[constraint: <metric> <op> <value> | bench/<BenchmarkName>]` marker.
2. For each, identify the underlying library the constraint is measured against (go-redis, aws-sdk-go-v2, confluent-kafka-go, etc. — declared in TPRD §6 deps).
3. Compare the constraint to `baselines/performance-baselines.json` entry for that library OR to known floor values cited in the library's own benchmark docs / release notes.
4. If `target < floor × 0.9`: emit a **CALIBRATION-WARN** in `intake/constraint-feasibility.md` with: constraint, target, observed floor, reference, and recommended action (re-target, swap client, or accept-aspirational-with-H8-waiver at H1).

**Evidence from sdk-dragonfly-s2**: TPRD §10 declared `allocs_per_GET ≤ 3`. go-redis v9's known allocation floor is ~25-30 per call (measured at 32 in Phase 3 BenchmarkGet). The aspirational target propagated unchecked through 3 phases and surfaced as an H8 gate failure, forcing a mid-run waiver to ≤35. If intake had run this check, H8 option-A could have been approved at H1 alongside TPRD acceptance with zero bench-wave disruption.

**Anti-pattern**: Do NOT silently accept aspirational constraints. Do NOT derive the "floor" from a single search result — prefer `baselines/performance-baselines.json` (authoritative) over dep README claims.

### Pattern: Mode override formalization (I1)

**Rule**: When TPRD §16 declares a mode (A / B / C) but the run-driver's directive or the `--mode` CLI flag specifies a different mode, generate `intake/mode-override.md` containing:
- TPRD §16 declared mode + rationale
- Directive-supplied mode + rationale
- Diff implications (e.g., Mode B preserves `[owned-by: MANUAL]`; Mode A regenerates all files)
- Explicit HITL confirmation request before proceeding past I4.

**Evidence from sdk-dragonfly-s2**: TPRD §16 declared Mode B with Slice-1 MANUAL preservation; run-manifest recorded a user directive to treat the run as Mode A greenfield. Resolution was correct but ad-hoc — no formal artifact captured the override. Future TPRDs should carry a `§16-override:` field to make this first-class.

---

**Apply behavior**: learning-engine should append the above two subsections to the end of `.claude/agents/sdk-intake-agent.md` under a `## Learned Patterns` heading (creating the heading if absent). Do NOT modify existing agent content. On apply, log `prompt-evolution-log.jsonl` entry with source-run `sdk-dragonfly-s2`, patch-id `PP-01-intake`, and the exact diff applied.
