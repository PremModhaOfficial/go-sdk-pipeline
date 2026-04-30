<!-- Generated: 2026-04-29T17:13:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-testing-lead (Wave T-SUPPLY) -->

# Wave T-SUPPLY — Supply chain

## Verdict: PASS-WITH-1-DEV-CVE (runtime PASS; dev-only finding informational)

## pip-audit (G33-py equivalent)
`.venv/bin/pip-audit` (`--strict --skip-editable` chokes on the editable local SDK; this is a known limitation. Filed separately as PA-008 for Phase 4: "pip-audit + editable install workflow")

| Package | Version | Vuln ID | Fix versions | Severity | Scope |
|---|---|---|---|---|---|
| pytest | 8.4.2 | CVE-2025-71176 | 9.0.3 | Local DoS (UNIX `/tmp/pytest-of-{user}` predictable path) | **dev-only** |

**Runtime `dependencies = []`** in pyproject.toml — the SDK has zero runtime third-party deps. The pytest CVE applies ONLY to the test-runner; SDK consumers are not exposed.

The fix path (pytest 9.0.3) is incompatible with the dev-extras pin `pytest>=8.0,<9.0`. Bumping to >=9.0 requires re-validating pytest-asyncio (currently `>=0.23,<0.24`, compatible with pytest 8.x line per upstream matrix). Filed as PA-009 for Phase 4: "pytest >= 9.0.3 dev pin; revalidate pytest-asyncio compatibility".

## safety (G34-py equivalent)
`.venv/bin/safety check --full-report` → 1 vulnerability reported, identical CVE-2025-71176 in pytest 8.4.2. Same dev-only scope. (Note: `safety check` is deprecated post-2024-06-01; superseded by `safety scan`. Already on Phase 4 list — PA-010.)

## License audit (G31-py equivalent)
All 11 dev deps on the allowlist (`MIT / Apache-2.0 / BSD / ISC / 0BSD / MPL-2.0`):

| Package | Version | License | OK |
|---|---|---|---|
| pytest | 8.4.2 | MIT | YES |
| pytest-asyncio | 0.23.8 | Apache 2.0 | YES |
| pytest-benchmark | 4.0.0 | BSD-2-Clause | YES |
| pytest-cov | 5.0.0 | MIT | YES |
| pytest-repeat | 0.9.4 | MPL-2.0 | YES |
| hypothesis | 6.152.4 | MPL-2.0 | YES |
| mypy | 1.20.2 | MIT | YES |
| ruff | 0.4.10 | MIT | YES |
| pip-audit | 2.10.0 | Apache 2.0 | YES |
| safety | 3.7.0 | MIT | YES |
| psutil | 5.9.8 | BSD-3-Clause | YES |

License re-audit re-confirms H6 ACCEPT verdict: 11 of 11 on allowlist.

## Verdict
- **Runtime supply-chain: PASS** (zero runtime deps; nothing to vet)
- **Dev-time supply-chain: PASS-WITH-INFO** (1 dev-time CVE, scope is local UNIX test-runner only, not a customer-facing risk; remediation pinned to PA-009)
- **License gate: PASS** (11/11 dev deps on allowlist)

## Phase 4 backlog filed
- **PA-008** — pip-audit + editable install incompat
- **PA-009** — bump pytest to >=9.0.3 (CVE-2025-71176)
- **PA-010** — replace `safety check` (deprecated) with `safety scan`
