# Toolchain (resolved from package: python@1.0.0)

Run-id: `sdk-resourcepool-py-pilot-v1`
Pipeline: 0.5.0 · Target-language: python · Target-tier: T1
Source manifest: `.claude/package-manifests/python.json`

## Build
`python -m build`

## Test
`pytest -x --no-header`

## Lint
`ruff check .`

## Vet (type-check)
`mypy --strict .`

## Format
`ruff format --check .`

## Coverage
`pytest --cov=src --cov-report=json --cov-report=term`
- Coverage minimum: **90%**

## Bench
`pytest --benchmark-only --benchmark-json=bench.json`

## Supply chain
- `pip-audit`
- `safety check --full-report`

## Leak check
`pytest tests/leak --asyncio-mode=auto`

## File extensions
.py

## Marker comment syntax
- line: `#`
- block-open: `"""`
- block-close: `"""`

## Module file
`pyproject.toml`

## Notes
- This file is INFORMATIONAL. Phase leads dispatch toolchain via `scripts/run-toolchain.sh` reading `active-packages.json`.
- For TPRD §10 perf gates: oracle margin 10× vs the Go reference (per TPRD §10) — Python is allowed to be slower by an order of magnitude but not more.
- For TPRD §11.4 leak detection: `pytest tests/leak --asyncio-mode=auto` is the canonical invocation; per python-asyncio-leak-prevention skill, `assert_no_leaked_tasks` fixture snapshots `asyncio.all_tasks()` pre/post.
- pytest-benchmark JSON regression compare is NOT yet a guardrail script (G65 is Go-only); regression renders through `sdk-benchmark-devil-python` agent verdict on the Phase 3 wave.
