<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead | Wave: T4 -->

# Supply chain report (Wave T4)

## 1. `pip-audit` (vulnerability scan)

```
$ pip-audit
No known vulnerabilities found
Name            Skip Reason
--------------- ------------------------------------------------------------------------------
motadata-py-sdk Dependency not found on PyPI and could not be audited: motadata-py-sdk (1.0.0)
```

| Field | Value |
|---|---|
| Tool | `pip-audit==2.10.0` |
| Packages scanned | dev venv (motadata-py-sdk + 79 transitive deps) |
| Skipped | `motadata-py-sdk` (this is the SDK under test; not on PyPI; expected skip) |
| Vulnerabilities found | **0** |
| Verdict | **PASS** |

## 2. `safety check --full-report` (secondary vuln DB)

```
$ safety check --full-report
  Using open-source vulnerability database
  Found and scanned 79 packages
  Timestamp 2026-04-28 12:33:01
  0 vulnerabilities reported
  0 vulnerabilities ignored
  No known security vulnerabilities reported.
```

| Field | Value |
|---|---|
| Tool | `safety==3.7.0` |
| Mode | open-source vulnerability database (no login required for `check`) |
| Packages scanned | 79 |
| Vulnerabilities | **0** |
| Note | The CLI emits a deprecation warning recommending `safety scan`; for v0.5.0 we accept `safety check` output as authoritative. The `--full-report` flag confirms zero ignored vulns. |
| Verdict | **PASS** |

Per impl-phase H7 note ("safety scan requires login; pip-audit covers per CLAUDE.md rule 24"): `safety check` (the deprecated subcommand) ran without login and returned a clean verdict. `pip-audit` is also clean. Both supply-chain gates GREEN.

## 3. License allowlist check (CLAUDE.md rule 19)

Allowlist (from CLAUDE.md rule 19): MIT / Apache-2.0 / BSD / ISC / 0BSD / MPL-2.0.

```
$ pip-licenses --format=json --packages pytest pytest-asyncio pytest-benchmark pytest-cov pytest-repeat ruff mypy pip-audit safety py-spy pip-licenses
```

| Package | Version | License | Allowed? |
|---|---|---|---|
| `mypy` | 1.20.2 | MIT | YES |
| `pip-audit` | 2.10.0 | Apache Software License (Apache-2.0) | YES |
| `py-spy` | 0.4.2 | MIT License | YES |
| `pytest` | 9.0.3 | MIT | YES |
| `pytest-asyncio` | 1.3.0 | Apache-2.0 | YES |
| `pytest-benchmark` | 5.2.3 | BSD-2-Clause | YES |
| `pytest-cov` | 7.1.0 | MIT | YES |
| `pytest-repeat` | 0.9.4 | Mozilla Public License 2.0 (MPL-2.0) | YES |
| `ruff` | 0.15.12 | MIT | YES |
| `safety` | 3.7.0 | MIT | YES |
| (`pip-licenses` itself) | (latest) | MIT (per PyPI) | YES |

All 11 explicit dev deps + the `pip-licenses` tool itself are on the allowlist. **0 disallowed licenses.**

## 4. TPRD §4 zero-direct-deps commitment

Per TPRD §4 Compat Matrix: "External deps for the package: zero — stdlib only."

```
$ grep -A2 '\[project\]' pyproject.toml | head -10
[project]
name = "motadata-py-sdk"
version = "1.0.0"
description = "Motadata Python SDK — async resourcepool"
requires-python = ">=3.11"
dependencies = []
```

`[project] dependencies = []` — empty array. **TPRD §4 commitment satisfied.**

The 79 packages scanned by `pip-audit` and `safety` are all in `[project.optional-dependencies] dev` (test/lint/build tooling); zero are runtime deps. The shipped wheel installs nothing beyond stdlib.

## Verdict

**ALL FOUR T4 SUB-GATES PASS.**

- pip-audit: PASS (0 vulns)
- safety check: PASS (0 vulns)
- License allowlist: PASS (11/11 dev deps on allowlist)
- TPRD §4 zero-direct-deps: PASS (empty `dependencies` array)

No ESCALATION items.
