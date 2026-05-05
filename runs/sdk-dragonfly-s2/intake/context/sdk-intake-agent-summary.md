<!-- Generated: 2026-04-18T05:53:17Z | Run: sdk-dragonfly-s2 -->
# sdk-intake-agent — Phase 0 Context Summary

For downstream phases (sdk-design-lead, sdk-impl-lead, sdk-testing-lead, learning-engine). Self-contained.

## Run identity

- **run_id:** sdk-dragonfly-s2
- **pipeline_version:** 0.1.0
- **target_repo:** /home/prem-modha/projects/nextgen/motadata-go-sdk
- **target_package_dir:** src/motadatagosdk/core/l2cache/dragonfly
- **target_branch:** sdk-pipeline/sdk-dragonfly-s2 (off base `l2Cache`)
- **TPRD source:** target_repo's `src/motadatagosdk/core/l2cache/dragonfly/TPRD.md` (read-only, copied verbatim to run dir)

## Mode

**Effective = A (greenfield / full regeneration).** TPRD §16 states Mode B with Slice-1 MANUAL preservation; user override 2026-04-18 supersedes. Phase 0.5 Extension-analyze is SKIPPED. No `[owned-by: MANUAL]` markers downstream. Every pipeline-authored symbol gets `[traces-to: TPRD-<section>]`.

Record: `intake/mode.json` carries `mode:"A"`, `override_reason`, and a full enumeration of all exported symbols grouped by slice.

## TPRD shape

- 14 sections present + Skills/Guardrails manifests + Appendices A/B. All non-empty.
- No `[ambiguous]`/TBD/??? markers.
- §15 has 3 open questions, each with an inline proposed answer — treated as resolved in `clarifications.jsonl`.
- §16 "Mode B" declaration is **noted but overridden** — design/impl phases must NOT reintroduce MANUAL preservation language.

## Scope — Slices S1–S7 all in play

- **S1** Lifecycle: `New`, `(*Cache).Ping`, `(*Cache).Close`, `Config`, `Option`, `ErrNotConnected`, `ErrInvalidConfig` → regenerate (not preserved)
- **S2** §5.2 strings (19 methods) + §5.7 raw (`Do`, `Client`) + `poolstats.go` scraper + full `mapErr` switch
- **S3** §5.3 hash + HEXPIRE family (13 methods)
- **S4** §5.4 Pipeline + TxPipeline + Watch
- **S5** §5.5 Publish/Subscribe/PSubscribe
- **S6** §5.6 Eval/EvalSha/ScriptLoad/ScriptExists
- **S7** Integration (testcontainers Dragonfly) + benchmarks + USAGE.md

Full symbol list in `intake/mode.json → new_exports`.

## Manifest verdicts

- **§Skills-Manifest (G23, WARN):** 19/27 PRESENT, 8 MISSING (all WARN-expected). Misses filed to `docs/PROPOSED-SKILLS.md` under section "Auto-filed from run `sdk-dragonfly-s2`". Pipeline proceeds. Downstream phases fall back to general patterns (go-concurrency-patterns, testing-patterns, network-error-classification, credential-provider-pattern, testcontainers-setup) + TPRD prescriptions.
- **§Guardrails-Manifest (G24, BLOCKER):** 38/38 PASS. All scripts present in `scripts/guardrails/`.

## Non-negotiable design invariants (for sdk-design-lead)

1. `Config` struct + `With*` options — match existing SDK convention; constants live in `const.go`.
2. Sentinel-only errors — 26 `Err*` exported; `mapErr` is a single switch over `redis.Nil`, `redis.ErrClosed`, `context.*`, server-error prefixes (`MOVED `, `ASK `, `CLUSTERDOWN`, `LOADING`, `READONLY`, `WRONGPASS`, `NOAUTH`, `NOPERM`, `WRONGTYPE`, `NOSCRIPT`, `BUSY`), `net.Error.Timeout()`, pool errors; default → `ErrUnavailable`.
3. OTel via `motadatagosdk/otel` ONLY (not raw OTel API). Metrics namespace `l2cache`. Bounded labels: `cmd`, `error_class` ∈ {timeout, unavailable, nil, wrong_type, auth, other}. **No label derived from user input.**
4. No internal retries (`MaxRetries=0`). No circuit breaker. No L1 coherence. No Sentinel. No cluster helpers. No cross-slot TX. No Lua registry (caller owns EVALSHA cache).
5. Explicit `Pipeliner` via go-redis — no SDK wrapper; callers get full command surface.
6. TLS optional; min 1.2, prefer 1.3; ServerName required unless `SkipVerify`; validator warns in prod. No cleartext creds anywhere.
7. `ConnMaxLifetime = 10m` default to pick up rotated K8s-mounted secrets on re-dial.
8. Return types mirror `go-redis/v9` (`string`, `int64`, `time.Duration`, `[]any`, `map[string]string`, `[]int64` for HEXPIRE), no remapping.
9. `context.Context` first param on every I/O method (G42).
10. Compile-time interface assertions on test seams (G43).
11. Pool-stats scraper goroutine must be shutdown-clean (`goleak` pass, G63).

## Perf gates (bench before GA — §10)

- P50 GET local Dragonfly ≤ 200µs
- P99 GET local Dragonfly ≤ 1ms
- SDK overhead vs raw go-redis ≤ 5%
- ≤ 3 alloc per GET (`-benchmem`)
- 10k ops/sec sustained per pod

Enforced by G65 (bench regression) and G97 (`[constraint: … bench/BenchmarkX]` proof).

## Test strategy handoff (§11)

- Unit: `miniredis/v2` backend, table-driven. Expected ≥90% coverage (G60).
- Integration (`//go:build integration`): `testcontainers-go` with real Dragonfly; matrix (TLS on/off × ACL on/off); chaos kill test.
- Bench (`cachebenchmark_test.go`): BenchmarkGet/Set/Pipeline_100/HSet/HExpire/EvalSha.
- Fuzz: `FuzzMapErr`, `FuzzKeyEncoding`.
- Race: all tests under `-race` in CI (G61).
- Credentials: `.env.example` fake + `.env` gitignored (G69).

## Dependency commitments

- `github.com/redis/go-redis/v9` @ v9.18.0 — already present at target.
- `github.com/alicebob/miniredis/v2` — already present.
- `github.com/testcontainers/testcontainers-go` + `dragonfly` module — Phase 1 `sdk-dep-vet-devil` must re-attest license/CVE/maintenance.
- `go.uber.org/goleak` — present.

No new runtime deps expected beyond those. Any additions require `runs/sdk-dragonfly-s2/design/dependencies.md` per rule #19.

## Downstream flags

- **Semver:** minor bump (v0.x.0 → v0.(x+1).0) per TPRD §16. Even in Mode-A greenfield regeneration, `sdk-semver-devil` MUST verify at H5.
- **Breaking-change:** no external callers of Slice-1 (per TPRD §1 "Zero downstream callers"); ACCEPT minor.
- **Marker-scanner:** run empty in this Mode-A pass (no MANUAL candidates). G95/G96 trivially green.
- **Pool-stats scrape interval:** **10s default** — confirm at Slice S2 design. Make it a `With*` option with sane minimum (e.g. ≥1s) to avoid tight loops.
- **HEXPIRE shape:** **keep `[]int64`** per TPRD §15.Q1; do not wrap in enum.
- **No `redis.Cmdable` exposure** — return concrete `*Cache`; tests use miniredis.

## HITL

- H0 (target-dir preflight) already PASS (driver, seq 2).
- H1 (this gate) — summary at `intake/H1-summary.md`. **Pending human approval.** Pipeline HALTS here.
- H5 (design), H6 (dep-vet), H7 (impl diff), H8 (bench), H9 (testing), H10 (merge) remain pending.

## Decision-log entries written by this agent

seq 4–9 (6 entries: lifecycle-started, skills-manifest WARN, guardrails-manifest PASS, clarifications 0, completeness G20/G21 PASS, lifecycle-completed with H1 pending).

Within rule #11 cap (≤15/agent/run).
