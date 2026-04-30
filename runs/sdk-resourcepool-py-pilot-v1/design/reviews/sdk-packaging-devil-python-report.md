<!-- Generated: 2026-04-29T13:41:00Z | Agent: sdk-packaging-devil-python | Wave: D3 (mode_a) -->

# Python Packaging Devil Review — `motadata_py_sdk.resourcepool`

Reviewer: `sdk-packaging-devil-python` (Mode A activated)
Verdict: **ACCEPT-WITH-NOTE**

This agent runs only in Mode A on Python (per `python.json` `D3_devils_mode_a`
wave assignment). Greenfield Python packages need PEP 517/518/621/639 + py.typed
validation that non-greenfield extensions inherit from the host project.

## PEP 517 / 518 (build system)

`package-layout.md` declares:
```toml
[build-system]
requires = ["hatchling>=1.21"]
build-backend = "hatchling.build"
```
- `requires` declared. ✓
- `build-backend` declared. ✓
- Backend is on the allowlist (hatchling). ✓
- Backend version pinned to a sane floor. ✓

**PASS**

## PEP 621 (project metadata)

| Field | Status |
|---|---|
| `name` | "motadata-py-sdk" — hyphenated distribution name ✓ |
| `version` | "1.0.0" — static (not dynamic). ✓ |
| `description` | One-line summary ✓ |
| `requires-python` | ">=3.11" — TPRD §4 says 3.11+, matches ✓ |
| `readme` | "README.md" referenced ✓ |
| `license` | `{ file = "LICENSE" }` Apache-2.0 ✓ |
| `authors` | Declared ✓ |
| `classifiers` | Programming Language, License (OSI Approved), Framework, Topic, Typing ✓ |
| `dependencies` | `[]` — empty (TPRD §4) ✓ |
| `optional-dependencies` | `dev = [...]` 11 entries ✓ |
| `[project.urls]` | Homepage / Repository / Issues ✓ |

**PASS** with note: `requires-python` is `>=3.11` rather than the Python pack
default `>=3.12` (declared in `python.json` as the floor). TPRD §4 explicitly
sets 3.11+ as the requirement (for `asyncio.timeout()` + `TaskGroup`). This
is a **legitimate TPRD-driven exception** to the pack default. ACCEPT.

## PEP 639 (license metadata)

License is declared via `license = { file = "LICENSE" }` form (PEP 621
classic), NOT via the newer SPDX-expression form `license = "Apache-2.0"`
(PEP 639). Both are valid; SPDX is preferred where the toolchain supports
it. hatchling supports both since 1.21. **SUGGESTION**: switch to SPDX
expression at impl time:
```toml
license = "Apache-2.0"
license-files = ["LICENSE"]
```
Non-blocking.

## PEP 561 (typed package)

`py.typed` marker declared at `src/motadata_py_sdk/py.typed`. Empty file.
`mypy --strict` consumers will pick up our hints.

**PASS**

## src/ layout (PEP 517 wheel-build)

`packages = ["src/motadata_py_sdk"]` declared under
`[tool.hatch.build.targets.wheel]`. `[tool.hatch.build.targets.sdist]`
includes src/, tests/, docs/, pyproject.toml, README.md, LICENSE.

**PASS**

## Tooling configuration

| Tool | Block | Status |
|---|---|---|
| pytest | `[tool.pytest.ini_options]` with `asyncio_mode = "strict"` | PASS |
| coverage | `[tool.coverage.run]` source + branch coverage | PASS |
| coverage threshold | `fail_under = 90` (TPRD §11.1 ≥90%) | PASS |
| mypy | `[tool.mypy] strict = true` | PASS |
| ruff | line-length=100, target-version="py311", lint rules selected | PASS |

## SUGGESTIONS

- **PK-001 (suggestion)**: At impl, prefer PEP 639 SPDX `license = "Apache-2.0"` form.
- **PK-002 (suggestion)**: Add `[tool.uv]` block at impl time if using uv as
  the canonical resolver (declared `uv.lock` in dependencies.md). Not BLOCKER.

## Verdict

**ACCEPT-WITH-NOTE** — packaging plan is correct. Both suggestions are
impl-time refinements, not design changes.
