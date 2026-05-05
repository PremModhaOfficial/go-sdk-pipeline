<!-- Generated: 2026-05-02T00:05:00Z | Run: nats-py-v1 -->
# sdk-intake-agent — context summary for downstream phases

## What this run is

Mode A new-package addition to `motadata-py-sdk`. Goal: Python port of the
NATS subsystem from `motadata-go-sdk/src/motadatagosdk/` that is wire-compatible
with the Go reference. Source TPRD is 2128 lines covering 5 events modules +
codec + consolidated OTel + config — 5–10× typical scope.

## Resolved facts (downstream phases consume these)

- **Pipeline version**: `0.5.0` (settings.json single source of truth).
- **Target language**: `python` (DERIVED — TPRD lacked `§Target-Language`).
- **Target tier**: `T1` (DERIVED — full perf-confidence regime).
- **Active package set**: `shared-core@1.0.0` + `python@1.0.0`. See `context/active-packages.json`.
- **Toolchain**: see `context/toolchain.md`. Build `python -m build`; test `pytest -x`; lint `ruff check`; vet `mypy --strict`; coverage min 90%; supply-chain `pip-audit` + `safety check`.
- **Mode**: A (new package). Target `motadata_py_sdk.events` (and adjacencies `codec`, `otel`, `config`) does not exist in target tree. Existing `motadata_py_sdk.resourcepool` is untouched.
- **Marker syntax**: line `#`, block `"""..."""` (per python.json).
- **Module file**: `pyproject.toml`.

## Scope decision (still gated at H1)

Intake recommended **Option B (decompose)**: `nats-py-v1` covers
`codec` + `events/utils` + `events/core` + `events/corenats` only. Subsequent
runs `nats-py-v2/v3/v4` cover jetstream / stores+middleware / otel+config.
Default under auto-mode if H1 silent: Option B.

If H1 accepts Option A (full scope), downstream phases must:
- Plan multiple H7b mid-impl checkpoints (after every major slice).
- Expect phase budgets in `.claude/settings.json` to be exceeded; record budget overruns to decision-log.

## Manifests (DERIVED at intake)

- **Skills-Manifest**: 31 skills, all PASS at G23. Full list in `tprd.md::§Skills-Manifest`. Notable: 4 Python-specific (`python-asyncio-patterns`, `asyncio-cancellation-patterns`, `python-class-design`, `pytest-table-tests`); rest from shared-core.
- **Guardrails-Manifest**: 53 declared (parser greedy-expanded `G95–G103` range mention to all 9 marker-protocol IDs); G24 PASS (all scripts on disk). **Informational exclusion** for Mode A run: G95, G96, G100, G101, G103 (marker-preservation suite — no preserved symbols on a fresh port). Design-phase `guardrail-validator` MUST be configured to skip these 5.

## Constraint feasibility (advisory for `sdk-perf-architect` at D1)

Source TPRD has NO `[constraint:]` markers; no I3 CALIBRATION-WARN fires. But:

- nats-py publish floor over loopback: ~50–200µs at 1KB. Budget ≥ 200µs.
- Codec pack_map allocs/op: target ≤ 30 for 10-field map; do NOT mirror Go <10.
- Subscriber per-msg dispatch: ~10–30µs asyncio.create_task floor; do not aspire <10µs.

## Risks captured in TPRD §15

- R1 — Run scope (5–10× typical; H1 decides).
- R2 — Marker protocol on Python (G95–G103 currently Go-only; resolution path documented).
- R3 — `nats-py` version pin not specified in TPRD; design-phase `sdk-dep-vet-devil` MUST pin specific minor.
- R4 — Python perf-baseline seed quality (existing baseline from sdk-resourcepool-py-pilot-v1 was on a "loaded testing host"; calibration-aware methodology required for first NATS perf seed).
- R5 — Skills-Manifest absence (resolved at intake; H1 confirms).
- R6 — Guardrails-Manifest absence (resolved at intake; H1 EXPLICIT accept).

## What downstream phases should know

### sdk-design-lead (next phase)

1. Read `tprd.md` AND source `input.md` together. Source TPRD §4-§11 + §14 (170 conformance checks) is the API surface specification. Canonical TPRD §7 references it explicitly.
2. Honor scope decision from H1 — if Option B (default), DO NOT design jetstream / stores / middleware / otel / config in this run. Design boundary: `codec`, `events/utils`, `events/core`, `events/corenats`.
3. At Wave D1, author `runs/nats-py-v1/design/perf-budget.md`. Consult the constraint feasibility advisories above — do NOT propagate Go-derived numbers without checking nats-py / asyncio floors.
4. At Wave D-DEP, pin `nats-py` to a specific minor (TPRD says "latest"); also pin OTel `1.30+` family (all opentelemetry-* must be aligned); pydantic-settings v2 (NOT v1).
5. Skills available are STRICTLY the 31 declared in `tprd.md::§Skills-Manifest`. No others.
6. Marker `[traces-to: TPRD-<section>-<id>]` MUST be attached to every pipeline-authored symbol per CLAUDE.md rule 29 / G99. Use Python `#` line-comment syntax (declared in python.json).

### sdk-impl-lead (Phase 2)

- Slice 1 first if H1 is Option B: `codec` (no NATS dependency; pure byte-format).
- Coverage minimum 90% on every new package per `python.json::toolchain.coverage_min_pct`.
- Test commands: `pytest -x --no-header` (test); `pytest --benchmark-only --benchmark-json=bench.json` (bench); `pytest tests/leak --asyncio-mode=auto` (leak).
- Branch will be `sdk-pipeline/nats-py-v1` (created by impl phase; target dir is currently on leftover `sdk-pipeline/sdk-resourcepool-py-pilot-v1` branch — do NOT operate on that branch; check out a fresh one).

### sdk-testing-lead (Phase 3)

- Each of source TPRD §14's 170 numbered conformance checks is an acceptance criterion. Map to:
  - Unit conformance (default): pytest table-driven (one row per check).
  - Integration (~40 checks involving live NATS): testcontainers nats-server + JetStream.
  - Cross-language fixture conformance (~10 codec checks): byte-fixtures emitted from Go SDK on a one-time CI job, committed under `tests/fixtures/`.
- Per Mode A: no marker preservation tests; no `[stable-since:]` semver gate tests.
- Perf-budget MMD declarations (if any from D1) gate Soak wave T5.5 + G105/G106.

### feedback / learning-engine (Phase 4)

- Baseline writes go to `baselines/python/` (per python.json `owns_per_language`). DO NOT write to `baselines/go/`.
- Skill quality regression compares against `baselines/shared/quality-baselines.json` (Lenient default per Decision D2; flips to per-language Progressive only on ≥3pp divergence on a debt-bearer).
- Per-patch H10 notification for any learning-engine prompt patches.

## Decision log usage budget

Intake used 8 of 15 entries this wave (7 clarification defaults + 1 H1 outcome to be appended on approval). Remaining budget downstream: 7 entries from this agent's quota across all subsequent phases (intake doesn't normally append outside its phase, but the budget rule applies if the orchestrator re-invokes for revision).
