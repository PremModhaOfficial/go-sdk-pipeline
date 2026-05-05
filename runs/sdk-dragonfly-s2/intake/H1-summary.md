<!-- Generated: 2026-04-18T05:53:17Z | Run: sdk-dragonfly-s2 -->
# H1 — TPRD + Manifests Acceptance Summary

**Run:** `sdk-dragonfly-s2`  **Pipeline:** 0.1.0  **Date:** 2026-04-18
**Target:** `motadatagosdk/core/l2cache/dragonfly` (branch `sdk-pipeline/sdk-dragonfly-s2` off base `l2Cache`)
**TPRD:** `runs/sdk-dragonfly-s2/tprd.md` (477 lines, verbatim copy of target-repo source)

## Mode

**Effective mode: A (greenfield / full regeneration).** TPRD §16 declares Mode B with Slice-1 MANUAL preservation; **overridden** by user directive 2026-04-18 ("the manual owned files are to be generated too"). Phase 0.5 Extension-analyze is skipped. No `[owned-by: MANUAL]` markers will be emitted. Every pipeline-authored symbol will carry a `[traces-to: TPRD-*]` marker (G98 + G99).

## Scope

Slices S1–S7 all in scope as greenfield regeneration (S1 lifecycle, S2 strings + raw escape, S3 hash + HEXPIRE, S4 pipeline + txn, S5 pubsub, S6 scripting, S7 integration + bench + USAGE.md). New exports: 4 types + `New` + loader + ~15 `With*` options + 40 methods on `*Cache` + 26 error sentinels. Full enumeration in `intake/mode.json`.

## Validation verdicts

| Check | Verdict | Detail |
|---|---|---|
| G20 TPRD completeness | **PASS** | all 14 TPRD sections (§1–§16 plus Skills/Guardrails Manifests + Appendices A/B) populated; no `[ambiguous]`/TBD/??? markers found |
| G21 §Non-Goals ≥3 | **PASS** | §3 has 13 bullets |
| G23 §Skills-Manifest | **WARN** | 19/27 present; 8 WARN-expected misses filed to `docs/PROPOSED-SKILLS.md` (redis-pipeline-tx-patterns, hash-field-ttl-hexpire, pubsub-lifecycle, miniredis-testing-patterns, lua-script-safety, testcontainers-dragonfly-recipe, k8s-secret-file-credential-loader, sentinel-error-model-mapping). Non-blocking. |
| G24 §Guardrails-Manifest | **PASS** | all 38 declared guardrails (G01/02/03/07/20-24/30-34/38/40-43/48/60/61/63/65/69/80/82/90/93/95-103) have executable scripts. |
| G22 clarifications ≤3 | **PASS (info)** | **0 clarifications** asked; TPRD §15 three open questions have inline proposed answers (treated as resolved) |

## Compat matrix (TPRD §4)

- Go 1.26 (per `go.mod`)
- `github.com/redis/go-redis/v9` pinned **v9.18.0**
- Dragonfly latest stable at GA (greenfield)
- RESP2 + RESP3, Redis 9 command set

## Key invariants downstream phases must preserve

1. **Sentinel-only error model** — 26 `Err*` exported sentinels; callers use `errors.Is`; wrapping via `fmt.Errorf("%w: %v", Sentinel, cause)` (§7).
2. **OTel on every data-path op** — client span `dfly.<cmd>`, bounded labels (`cmd`, `error_class`), no key/value/payload in attrs or metric labels (§8).
3. **Credential hygiene** — no plaintext in source/logs/errors/span-attrs; `LoadCredsFromEnv` reads mounted-secret file paths (§9, G69).
4. **Config + `With*` options** — package constants in `const.go`, struct in `config.go`, setters in `options.go` (§6, §12 layout).
5. **No retry at SDK layer** — `MaxRetries = 0` fixed default (§3 non-goal).
6. **Pool-stats scraper goroutine** — leak-free under `goleak.VerifyTestMain` (§8.2, §11.5, G63).
7. **Perf gates** — P50 GET ≤200µs, P99 ≤1ms, SDK overhead ≤5% vs raw go-redis, ≤3 alloc/GET (§10, G65, G97).
8. **Coverage ≥90%** on new files (§11, G60).

## Open-question resolutions inlined (TPRD §15)

- Q1 HEXPIRE return shape → keep raw `[]int64` for go-redis parity.
- Q2 PoolStats scrape interval → default 10s; Slice S2 design wave confirms.
- Q3 Expose `redis.Cmdable`? → no; return concrete `*Cache`; tests use miniredis.

## Files produced (Phase 0 Intake)

- `runs/sdk-dragonfly-s2/tprd.md`
- `runs/sdk-dragonfly-s2/intake/mode.json`
- `runs/sdk-dragonfly-s2/intake/skills-manifest-check.md`
- `runs/sdk-dragonfly-s2/intake/guardrails-manifest-check.md`
- `runs/sdk-dragonfly-s2/intake/clarifications.jsonl`
- `runs/sdk-dragonfly-s2/intake/H1-summary.md` (this file)
- `runs/sdk-dragonfly-s2/intake/context/sdk-intake-agent-summary.md`
- `docs/PROPOSED-SKILLS.md` (appended — 8 entries under run `sdk-dragonfly-s2`)

## Next phase recommendation

Skip Phase 0.5 Extension (Mode A). Proceed to **Phase 1 Design** with `sdk-design-lead`. Design waves must consume `intake/mode.json` for the authoritative export list and pull the 27 TPRD skill references via `sdk-skill-coverage-reporter`.

**HALTING for H1 human approval. Do not proceed past this gate without explicit authorization.**
