<!-- Generated: 2026-04-29T13:39:00Z | Agent: sdk-convention-devil-python | Wave: D3 -->

# Python Convention Devil Review — `motadata_py_sdk.resourcepool`

Reviewer: `sdk-convention-devil-python`
Verdict: **ACCEPT** (1 SUGGESTION, 0 NEEDS-FIX, 0 BLOCKER)

## Convention checks

| # | Check | Verdict | Note |
|---|---|---|---|
| C-1 | pyproject.toml-only (PEP 517/518/621) | PASS | `package-layout.md` declares full `[build-system]`, `[project]`, classifiers, `[project.urls]`, dynamic versioning option. Build backend hatchling >=1.21. |
| C-2 | src/ layout | PASS | `src/motadata_py_sdk/resourcepool/` correctly nested. Distribution name `motadata-py-sdk` (hyphenated); package `motadata_py_sdk` (underscored). Both declared. |
| C-3 | __init__.py + __all__ + py.typed | PASS | `__init__.py` re-exports all 9 public symbols (8 from TPRD §7 + ResourceCreationError); `__all__` explicit; `py.typed` declared at `src/motadata_py_sdk/py.typed`. |
| C-4 | Single-Config constructor | PASS | `Pool(config: PoolConfig)` — single arg. Frozen+slotted dataclass. Matches `python-sdk-config-pattern` skill. |
| C-5 | Async-first surface (TPRD §3) | PASS | All I/O methods are coroutines. Only `try_acquire` and `stats` are sync — both are no-I/O paths. `acquire` returns context manager (not coroutine) — idiomatic per asyncio.timeout precedent. |
| C-6 | Type hints (PEP 484/526) | PASS | Every public signature in api.py.stub is fully annotated. `Generic[T]` propagation correct through Pool, PoolConfig, AcquiredResource. mypy --strict will pass. |
| C-7 | Docstrings (PEP 257) | PASS | Every public symbol has a triple-quoted docstring. Args/Returns/Raises sections present. |
| C-8 | __aenter__ / __aexit__ pair | PASS | Both Pool itself AND AcquiredResource implement the protocol. `__aexit__` signature uses correct PEP 484 BaseException + TracebackType types. |
| C-9 | Exception hierarchy (PEP 3134) | PASS | All custom exceptions inherit from `PoolError` → `Exception`. ResourceCreationError uses `raise ... from e` chaining (documented in `error-taxonomy.md`). No `BaseException` subclassing. |
| C-10 | No mutable default arguments | PASS | All function signatures with default values use `None` + late-bind, or use immutable defaults (string `"resourcepool"`). |
| C-11 | logging via stdlib `logging`, not `print` | PASS | `concurrency-model.md` and `algorithm-design.md` consistently use `_log.warning(...)`, never `print()`. |
| C-12 | OTel via package wrapper, NOT raw `opentelemetry.*` | N/A | TPRD §3 explicitly defers OTel to follow-up TPRD. Marked "out of pilot scope" — acceptable. |

## SUGGESTIONS (non-blocking)

- **CV-001 (suggestion)**: Consider `from collections.abc import Callable` instead of `from typing import Callable` (PEP 585 deprecates `typing.Callable` in favor of `collections.abc.Callable` for runtime, while keeping `typing` for type-hint use). Not BLOCKER — both still work in 3.11+.

## Verdict

**ACCEPT** — design conforms to every Python pack convention. C-12 (OTel)
gracefully marked N/A per TPRD scope. CV-001 is a low-effort impl-time
nit, not a design issue.

## D2/D6 evaluation note

This is a Python-pack-native devil — its review was sharply on-target with
zero shared-core noise. Confirms D6=Split is working: the python-flavored
agent body produces python-flavored findings.
