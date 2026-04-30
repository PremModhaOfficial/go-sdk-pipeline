<!-- Generated: 2026-04-29T16:20:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-impl-lead-toolchain-rerun (Wave M9-RERUN; replaces prior surrogate report) -->

# Wave M9-RERUN — Implementation-Phase Guardrails (live toolchain)

```
bash scripts/run-guardrails.sh impl /abs/path/to/runs/sdk-resourcepool-py-pilot-v1 \
  /abs/path/to/motadata-sdk
```

filtered by active-packages union (shared-core ∪ python at T1) ∩ phase header `impl`.

## Aggregate

| metric | count |
|---|---:|
| Active guardrails this phase | 30 |
| Actually executed (this phase, this active-set) | 7 |
| **PASS** | **6** |
| FAIL | 1 (G43-py — INCOMPLETE-by-tooling, see below) |
| Skipped (phase-mismatch) | 23 |
| Skipped (not in active packages) | 24 |
| WARN-FAIL | 0 |

## Per-guardrail detail

| ID | Severity | Outcome | Notes |
|---|---|---|---|
| G01 | BLOCKER | **PASS** | decision-log.jsonl schema valid |
| G07 | BLOCKER | **PASS** | target-dir-discipline (no writes outside motadata-sdk + runs) |
| G200-py | BLOCKER | **PASS** | python packaging (pyproject.toml shape) |
| G40-py | BLOCKER | **PASS** | dependency-vetting (deps = [], no new deps) |
| G41-py | BLOCKER | **PASS** | `python -m build` produces sdist + wheel cleanly (was INCOMPLETE-as-FAIL prior; now PASS with `build` installed beside dev extras) |
| G42-py | BLOCKER | **PASS** | `mypy --strict .` — Success: no issues found in 28 source files (was INCOMPLETE-as-FAIL prior; now PASS) |
| G43-py | BLOCKER | **FAIL → INCOMPLETE-by-tooling-pinning** | see detail below |

## G43-py — INCOMPLETE-by-tooling-version-mismatch

**Verdict per Rule 33**: NOT silently promoted to PASS. Surfaced at H7 for user decision.

`ruff check .` from the SDK root parses `pyproject.toml` and emits:
```
pyproject.toml:18:17: RUF200 Failed to parse pyproject.toml: wanted string or table
```

Root cause: `pyproject.toml:18` declares `license-files = ["LICENSE"]` per PEP 639 (released Aug 2025). Ruff 0.4.10 (June 2024) predates PEP 639 support and rejects the section. The pyproject.toml's dev-extras range pins `ruff>=0.4,<0.5` → ruff 0.4.10 is the only resolvable version.

Verification this is a tooling-mismatch, not a real lint regression:
- `.venv/bin/ruff check src/ tests/` (excluding pyproject.toml from scan) — **PASS** (All checks passed!)
- Upgrading to `ruff>=0.6.5,<0.14` (e.g. ruff 0.13.3) parses pyproject.toml cleanly but introduces 26 NEW lint issues including ASYNC109 (which would conflict with TPRD §10's mandated `timeout: float | None` parameter on `acquire_resource` / `aclose`) and UP046 (PEP 695 type-parameter syntax).
- The dev-extras pin was set during design phase to match the lint policy at run start; bumping it requires a Phase 4 re-design pass.

**Recommended resolution at H7**:
- (a) Accept INCOMPLETE for this run; file Phase 4 task to bump ruff with associated stylistic refactors (PEP 695 generics, asyncio.timeout context manager). OR
- (b) Add `[tool.ruff] extend-exclude = ["pyproject.toml"]` to the SDK's pyproject.toml, instructing ruff 0.4.x to skip parsing its own config file. Production-tree change but non-functional.

I have **NOT** taken action (a) or (b) — H7 decision required.

## Side-flag the prior agent filed (now reproduced and confirmed)

`scripts/run-guardrails.sh` exports `ACTIVE_PACKAGES_JSON="$RUN_DIR/context/active-packages.json"`. When the script is invoked with a relative `RUN_DIR` (e.g. `runs/sdk-resourcepool-py-pilot-v1` from the pipeline root), child guardrails like G41-py / G42-py / G43-py invoke `cd "$TARGET"` before executing the toolchain dispatcher — at which point the relative `ACTIVE_PACKAGES_JSON` no longer resolves and run-toolchain.sh emits `cannot locate active-packages.json`.

**Reproduction**:
- `cd go-sdk-pipeline && bash scripts/run-guardrails.sh impl runs/<id> /abs/sdk` → 3 spurious FAILs (G41/G42/G43).
- `cd go-sdk-pipeline && bash scripts/run-guardrails.sh impl /abs/runs/<id> /abs/sdk` → guardrails resolve; PASS where tooling allows.

**One-line fix proposal** (filed for Phase 4 improvement-planner; do **NOT** apply this run per orchestrator brief): in `scripts/run-guardrails.sh` near line 87, after `APJ="$RUN_DIR/context/active-packages.json"`, add `APJ=$(realpath "$APJ" 2>/dev/null || readlink -f "$APJ")`. OR call `RUN_DIR=$(cd "$RUN_DIR" && pwd)` immediately after argument parsing. Either eliminates the relative-path landmine.

## What this means for H7

- **6 of 7** active impl-phase guardrails PASS cleanly.
- The 7th (G43-py) is a **tooling-version-vs-config-format mismatch** — ruff 0.4.10 cannot parse PEP 639 `license-files`. The lint itself, when scoped to source dirs, is clean. Per Rule 33 this remains INCOMPLETE.

H7 must accept INCOMPLETE-on-G43-py with rationale, OR direct one of:
- bump ruff (with associated stylistic churn)
- add `extend-exclude = ["pyproject.toml"]` (workaround)
- defer to Phase 4 (improvement-planner)

## Inputs

- Report JSON: `runs/.../impl/guardrail-report.json`
- Active-packages: `runs/.../context/active-packages.json` (shared-core@1.0.0 ∪ python@1.0.0, target_tier=T1, mode=A)
