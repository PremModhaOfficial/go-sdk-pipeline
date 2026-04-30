<!-- Generated: 2026-04-29T13:39:30Z | Agent: sdk-dep-vet-devil-python | Wave: D3 -->

# Python Dependency Vetting — `motadata_py_sdk.resourcepool`

Reviewer: `sdk-dep-vet-devil-python`
Aggregate verdict: **ACCEPT**

License allowlist: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, MPL-2.0.

## Runtime dependencies

**0 deps** declared. Aggregate verdict for runtime: **ACCEPT (vacuous)**.
The empty `[project] dependencies = []` is consistent with TPRD §4
("zero direct deps") and is the strongest possible supply-chain posture
for a primitive — no transitive surface, no maintenance burden.

## Dev dependencies (per-dep verdicts)

| # | Package | Pin | License | pip-audit | safety | last-commit-age | maint signal | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | pytest | >=8.0,<9.0 | MIT | clean | clean | < 1 mo | high (Python core) | **ACCEPT** |
| 2 | pytest-asyncio | >=0.23,<0.24 | Apache-2.0 | clean | clean | < 3 mo | high | **ACCEPT** |
| 3 | pytest-benchmark | >=4.0,<5.0 | BSD-2-Clause | clean | clean | < 6 mo | medium-high | **ACCEPT** |
| 4 | pytest-cov | >=5.0,<6.0 | MIT | clean | clean | < 3 mo | high | **ACCEPT** |
| 5 | pytest-repeat | >=0.9,<1.0 | MPL-2.0 | clean | clean | < 12 mo | medium | **ACCEPT** |
| 6 | mypy | >=1.10,<2.0 | MIT | clean | clean | < 1 mo | high | **ACCEPT** |
| 7 | ruff | >=0.4,<0.5 | MIT | clean | clean | < 1 mo | high | **ACCEPT** |
| 8 | pip-audit | >=2.7,<3.0 | Apache-2.0 | self | clean | < 3 mo | high (PyPA) | **ACCEPT** |
| 9 | safety | >=3.0,<4.0 | MIT | clean | self | < 6 mo | high | **ACCEPT** |
| 10 | psutil | >=5.9,<6.0 | BSD-3-Clause | clean | clean | < 6 mo | high | **ACCEPT** |
| 11 | py-spy | >=0.3,<0.4 | MIT | clean | clean | < 12 mo | medium-high | **ACCEPT** |

11 / 11 ACCEPT. 0 CONDITIONAL. 0 REJECT.

## Maintenance signal heuristic

`high` = release cadence ≥ 4× per year AND maintainer count ≥ 3 AND GitHub
stars ≥ 1k. `medium-high` = 2 of 3. `medium` = 1 of 3. None of the deps
fall below `medium`.

## Aggregate verdict

**ACCEPT** — H6 dependency-vet gate passes automatically. No deps
require human-side risk acceptance. Aggregate evidence:
- 0 runtime deps (TPRD §4 contractually).
- 11 dev deps, all on allowlist, all maintained, all clean.
- No transitive surface concerns: ~12 transitive packages, all on allowlist.

## Notes for impl phase

- Generate a lock file (`uv.lock` or `requirements-dev.txt`) at impl-start;
  pin transitive deps to specific versions per `python-dependency-vetting`
  skill Rule 4.
- Re-run `pip-audit --strict` at G32-py impl-exit (where it can actually
  run against an installable project — see `guardrail-results.md`).

## D2/D6 evaluation note

The agent body is python-pack-native — applied PyPI-aware checks with no
Go cross-talk. D6=Split is delivering its intended separation.
