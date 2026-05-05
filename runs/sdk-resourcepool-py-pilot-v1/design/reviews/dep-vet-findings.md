<!-- Generated: 2026-04-27T00:02:03Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Reviewer: sdk-dep-vet-devil (READ-ONLY) | Note: agent not in active-packages.json; orchestrator brief requested explicit dep vet — providing as design-lead surrogate review -->

# Dep-Vet Findings — `motadata_py_sdk.resourcepool`

## Verdict: ACCEPT

Zero direct deps. Dev deps confined to `[project.optional-dependencies] dev`. License posture clean.

---

## DV-001 — Confirmed: zero direct dependencies for the package

**TPRD §4 Compat Matrix**: "External deps for the package: zero — stdlib only."

**Verified against `patterns.md` §11 pyproject.toml shape**:
```toml
[project]
dependencies = []   # zero direct deps
```

✓ PASS. The package ships with zero runtime deps.

---

## DV-002 — Confirmed: dev deps live under `optional-dependencies.dev`

```toml
[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "pytest-benchmark>=4.0",
    "pytest-cov>=4.1",
    "pytest-randomly>=3.15",
    "ruff>=0.5",
    "mypy>=1.10",
    "pip-audit>=2.7",
    "safety>=3.2",
]
```

✓ PASS. `pip install motadata-py-sdk` does NOT pull these. Only `pip install motadata-py-sdk[dev]` does.

---

## DV-003 — License audit (dev deps only — package itself has no deps)

| Dev dep | License | Allowlist (MIT/Apache-2.0/BSD/ISC/0BSD/MPL-2.0) |
|---|---|---|
| pytest | MIT | ✓ |
| pytest-asyncio | Apache-2.0 | ✓ |
| pytest-benchmark | BSD-2-Clause | ✓ |
| pytest-cov | MIT | ✓ |
| pytest-randomly | MIT | ✓ |
| ruff | MIT | ✓ |
| mypy | MIT | ✓ |
| pip-audit | Apache-2.0 | ✓ |
| safety | MIT | ✓ |

All dev deps on the allowlist. ✓ PASS.

---

## DV-004 — Last-commit-age + transitive count

Not applicable for the package itself (zero direct deps). Dev deps are widely-used tools (pytest stack, ruff, mypy) — all have active maintenance + small transitive footprints. Not gating.

---

## DV-005 — Supply chain cleanliness gate (impl + test phases)

Action items for downstream:
- Impl phase: confirm `pyproject.toml` matches patterns.md §11 (`dependencies = []`).
- Testing phase: `pip-audit` MUST run clean (trivially clean — no deps).
- Testing phase: `safety check --full-report` MUST run clean (same).

---

## Final verdict: ACCEPT

No design rework required. Zero direct dep bloat risk. Dev deps fully on license allowlist.
