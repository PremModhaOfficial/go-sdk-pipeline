# Toolchain (resolved from package: python@1.0.0)

Source manifest: `.claude/package-manifests/python.json` (v0.5.0 Phase A scaffold).
Target SDK: `motadata-py-sdk` (Python 3.11+ per TPRD §4 Compat Matrix).

## Build
`python -m build`

## Test
`pytest -x --no-header`

## Lint
`ruff check .`

## Vet (type-check)
`mypy --strict .`

## Format check
`ruff format --check .`

## Coverage
`pytest --cov=src --cov-report=json --cov-report=term`

## Coverage minimum
90 %

## Bench
`pytest --benchmark-only --benchmark-json=bench.json`

## Supply chain
- `pip-audit`
- `safety check --full-report`

## Leak check
`pytest tests/leak --asyncio-mode=auto`

## File extensions
`.py`

## Marker comment syntax
- line: `#`
- block_open: `"""`
- block_close: `"""`

## Module file
`pyproject.toml`

## Tier semantics
- target_tier = **T1** → full perf-confidence regime per pipeline rule 32.
- All seven falsification axes apply: declaration (perf-budget.md at D1) · profile shape (G109) · allocation (G104) · complexity (G107) · regression+oracle (G108) · drift+MMD (G105/G106) · profile-backed exceptions (G110).
- Per python.json `notes.tier_default`: Python perf-budget MMD authoring + py-spy/scalene profile parser + asyncio leak harness materialize lazily during this Phase B pilot. Adapter scripts to bridge Python tooling to G104/G105/G107/G109 are in pilot scope (T2-7).

## Notes for downstream phase leads
- TPRD §4 pins Python 3.11+ (asyncio.timeout + TaskGroup + exception groups). CI matrix per TPRD §14: 3.11, 3.12, 3.13.
- TPRD §4: zero direct deps in package; dev deps = mypy / pytest / pytest-asyncio / pytest-benchmark / ruff / pip-audit / safety.
- Leak detection harness (T2-7): the tests/leak/ adapter is the Python analog of `goleak.VerifyTestMain`. Snapshots `asyncio.all_tasks()` before/after each test; fails on residual non-current tasks. Backs G63 equivalent until a Python-aware G63.sh ships.
- Bench output (T2-7): `pytest-benchmark --benchmark-json=bench.json` produces structured output that `sdk-benchmark-devil` will parse against `baselines/python/performance-baselines.json` (materializes on first run; first run = seed, no regression possible).
- Marker scanner: TPRD §12 directs every `.py` file to carry `# [traces-to: TPRD-<section>]` markers. Marker syntax for Python is `#` (line comments), declared above. G95-G103 may need migration from go pack to shared-core OR Python-specific siblings — decision deferred to Phase B per python.json `notes.marker_protocol_note`.
