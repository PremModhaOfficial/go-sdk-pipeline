# Pending List — Roadmap to Production-Ready Multi-Language Code Generation

> **Captured**: 2026-04-24 (end of `pkg-layer-v0.4` scaffolding pass)
> **Branch context**: pipeline at v0.4.0 scaffolding (package-manifest layer shipped; ast-hash toolkit committed; no dispatch refactor yet)
> **Purpose**: honest assessment of what's left between today and "pipeline ships a working client in any supported language from a TPRD, production-grade."

---

## What's needed for production-ready multi-language code generation

Realistic gap assessment. Roughly 3 independent workstreams — you can move them in parallel if you have the people.

### Workstream 1 — Language-agnosticism (~12 working days)

Make shared-core actually shared.

| Step | Days | Unblocks |
|---|---:|---|
| TPRD `§Target-Language` + preflight parse | 0.5 | Pipeline knows what it's running |
| `sdk-intake-agent` writes `active-packages.json` + `toolchain.md` | 1 | Dispatchable per-run package set |
| `guardrail-validator` filters through active-packages | 0.5 | Go gates stop firing on non-Go |
| Phase leads filter agent invocations | 2 | Go devils stop firing on non-Go |
| Generalize 4 devils + 3 skills (split Go content out) | 2 | Shared-core actually neutral |
| Split DESIGN/IMPL/TESTING phase contracts invariant + pack blocks | 2 | Phase contracts stop hardcoding `go test` |
| Wire AST-hash into G95/G96 with byte-hash fallback | 1 | Marker protocol language-neutral |
| E2E determinism check vs. Dragonfly baseline | 1 | Proves rule 25 holds after refactor |
| Version bump + evolution report | 0.5 | v0.4.1 release |

**Outcome**: Go still works byte-identically. The boundary is real. Adding a 2nd language becomes "author one package manifest + the content it references."

### Workstream 2 — Python pack (~3 weeks, can start after WS1 step 4)

Pick Python because `runs/c-refactor-plan.md` already targets redis-py as the pilot.

| Item | Days | Notes |
|---|---:|---|
| `python.json` manifest | 0.5 | Mirror `go.json` shape |
| Python AST-hash backend (`packs/python/ast-hash-backend.py`) | 1 | ~150 LOC using stdlib `ast` module |
| Python equivalents of the 31 go-package guardrails | 5 | `pytest`, `mypy`, `bandit`, `safety`, `ruff`, `coverage.py`, `py-spy` for profiling, `pytest-benchmark` |
| Python-pack skills (~20 skills covering asyncio, type hints, packaging, testing, observability) | 6 | Mirror `go-concurrency-patterns` / `go-error-handling-patterns` / etc. |
| Python-pack agents (~15) — benchmark-devil, leak-hunter (asyncio task leaks), convention-devil, etc. | 4 | Parallel to Go devils |
| Pilot TPRD (redis-py-style client) | 2 | Write a real 14-section TPRD |
| E2E pilot run + iterate | 3 | First real multi-language run |

### Workstream 3 — Operational / production-readiness (~4-6 weeks)

These exist regardless of language count. They're what stops this being "works on my machine" and makes it ship-grade.

| Gap | Why it matters | Effort |
|---|---|---|
| **CI integration** | `/preflight-tprd` should run on every TPRD PR; drift gates should run on every pipeline-repo PR | 3d |
| **Only 2 real runs ever** (Dragonfly s2 + p1-v1). Rule 25 determinism unverified across version bumps. | Pipeline hasn't seen sustained load. Need 10+ diverse runs to trust it. | Ongoing, weeks |
| **Cross-run learning never fired** — 2-run-recurrence rule needs 2+ runs of the same pattern. | Self-improvement loop is architecturally present but empirically untested. | Emerges from runs |
| **HITL timeouts never triggered** — H1/H5/H7/H9/H10 timeout policies exist but haven't fired. | Production WILL hit a forgotten gate. | Exercise them intentionally. |
| **Secrets management** for integration tests (TLS certs, cloud creds) | Right now .env is gitignored; no rotation, no vault integration | 2d |
| **Cost tracking per run** — budget is soft-capped with WARN only | One runaway run can burn $100s of tokens. Hard cap enforcement + per-run cost telemetry. | 2d |
| **Monitoring / alerting** — no dashboard, no paging on halts | Pipeline halts silently → someone has to notice | 3d (Grafana from neo4j graph) |
| **Human-review throughput** — 7 HITL gates × runs/week = hours. No prioritization, no parallelization | Becomes the bottleneck after week 2. | Design decision + tooling |
| **Rollback story** — if a merged run produces bad code, what's the revert path? | Git revert on `sdk-pipeline/<run-id>` → main. Untested. | 1d exercise |
| **Compute allocation** — background soak runs + parallel agents need isolated environments | Currently all runs on one machine | Depends on your infra |
| **Audit retention policy** — `runs/<id>/decision-log.jsonl` is forever; ~100KB/run, grows | Define archive rule (e.g., after 6 months move to `runs/archive/`, gitignored) | 0.5d |
| **Determinism across pipeline-version bumps** — rule 25 says same TPRD + same seed → byte-equivalent. Never verified 0.2.0 → 0.3.0 → 0.4.0. | Hidden regressions sneak in on version bumps | 1d E2E run per bump |

### Workstream 4 — Trust validation (ongoing, calendar-time)

Can't be compressed. Needs real runs over real time.

- **10+ diverse Go TPRDs** through the pipeline, each reviewed end-to-end before anyone trusts auto-merge
- **Side-by-side quality comparison** vs. hand-written equivalents (code quality, bug rate, review round-trips)
- **At least 1 production incident + post-mortem** to test the blast-radius containment (dedicated branches, marker protocol, HITL)
- **Cross-version determinism proof** across 2–3 pipeline bumps

Timescale: 2-3 months of consistent use, regardless of engineering effort.

## Totals

| Milestone | Engineering | Calendar |
|---|---|---|
| Language-agnostic Go (v0.4.1) | ~12 days | ~3 weeks single-engineer |
| Python pack + pilot shipping (v0.5.0) | ~3 weeks | ~6 weeks if WS1 is serial; 4 weeks if parallel |
| Operational maturity (CI, cost caps, monitoring, rollback) | ~4 weeks | Can parallel with WS1/WS2 |
| Trust validation | ~10 diverse runs | ~3 months calendar |
| **"Production-ready, multi-language"** | **~10 engineering weeks** | **~3–4 months elapsed** |

## Order of operations recommended

1. **Push `pkg-layer-v0.4`**. Fixes the `mcp-enhanced-graph` divergence.
2. **Workstream 1 now** (~3 weeks calendar) — highest ROI. Unlocks everything else. Also the most concrete thing to do with the scaffolding just shipped.
3. **Workstream 3 operational items in parallel** — doesn't block on WS1. Most valuable: CI integration + cost caps + run-3+ to exercise the learning loop.
4. **Workstream 2 (Python) starts when WS1 step 4 is done** — dispatch needs to work before a 2nd language is meaningful.
5. **Workstream 4 accumulates over the whole calendar** — each merged run ratchets up trust.

The fastest path to "production multi-language" is **not** to minimize engineering. It's to start running the pipeline against real Go TPRDs frequently so cross-run learning and trust accumulate on the calendar, while the engineering workstreams run in parallel.
