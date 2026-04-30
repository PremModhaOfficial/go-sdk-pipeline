# Python pack — `motadatapysdk` adapter

**Status**: v0.5.0 Phase B in progress. Foundations shipped 2026-04-28 (this PR). Agent / skill / guardrail authoring lands in subsequent PRs as the first Python TPRD exposes need.

This directory holds the **Python language-adapter overlay**: the per-language conventions referenced by the four shared-core debt-bearer agents (`sdk-design-devil`, `sdk-overengineering-critic`, `sdk-semver-devil`, `sdk-security-devil`) when a run targets Python. The matching adapter manifest is `.claude/package-manifests/python.json` one level up.

## Files in this directory

| File | Status | Purpose |
|---|---|---|
| `conventions.yaml` | shipped | Python overlay for the 4 debt-bearer agents — Python idioms (`@dataclass`, `asyncio.TaskGroup`, `__repr__`, `hmac.compare_digest`, `yaml.safe_load`, etc.) keyed by agent + rule. Mirror of `go/conventions.yaml`. |
| `README.md` | shipped (this file) | Pack overview + Phase B authoring pointers. |

## Pack pointers

- **Manifest**: `.claude/package-manifests/python.json` declares `agents`, `skills`, `guardrails`, `toolchain`, `baselines`, `marker_comment_syntax`. v0.5.0 Phase A ships with the artifact arrays empty; Phase B fills them.
- **AST tooling**: `scripts/ast-hash/python-backend.py` (single-symbol hash) and `scripts/ast-hash/python-symbols.py` (file/dir enumerator) — both stdlib-only. See `scripts/ast-hash/README.md` § "Python backend" for the canonicalization-rule answers.
- **Toolchain**: `python.json:toolchain` declares the build/test/lint/coverage/bench/supply-chain commands the dispatchers (`scripts/run-toolchain.sh`, `scripts/run-guardrails.sh`) resolve at runtime.
- **Baselines**: per-language at `baselines/python/<file>` (created on first Python pilot run). Decision D2=Lenient — Python pack starts with its own baseline partition; cross-language metric comparison stays opt-in.

## Phase B authoring path (what comes next)

Phase B fills `python.json`'s empty arrays. The full checklist lives in `docs/PACKAGE-AUTHORING-GUIDE.md` § "Phase B Python authoring checklist". Summary of the work waves:

1. **B-1 Foundations** *(this PR — DONE)*
   - `scripts/ast-hash/python-backend.py` ✓
   - `scripts/ast-hash/python-symbols.py` ✓
   - `scripts/ast-hash/README.md` § Python backend ✓
   - `python/conventions.yaml` ✓
   - `python/README.md` ✓
   - `docs/PACKAGE-AUTHORING-GUIDE.md` § Phase B checklist ✓

2. **B-2 Mirror agents** — 16 `-python` siblings of go-pack agents (`code-reviewer-python`, `documentation-agent-python`, `sdk-perf-architect-python`, etc.). Same role, Python-flavored body. See the table in `multi-lang-remaining.md` § 2B.

3. **B-3 Python-native skills + guardrails + oracles** — ~20 `python-*` prefixed skills (`python-asyncio-patterns`, `python-pytest-fixtures`, `python-mypy-strict-typing`, etc.); ~30 `G*-py.sh` guardrails (or generalized via toolchain dispatch — TBD per script); `python/oracle-catalog.yaml` + `docs/perf-budget-python-schema.md`.

4. **B-4 First Python pilot run** — author a small Python TPRD (e.g., "add a Redis client to motadatapysdk"), run intake → full pipeline → calibrate Python perf-oracle numbers from the run.

## Naming conventions for new Python artifacts

Per `docs/PACKAGE-AUTHORING-GUIDE.md` § Naming convention:

- **Agents** get a `-python` SUFFIX. Example: `sdk-perf-architect-python.md`, `code-reviewer-python.md`.
- **Skills** get a `python-` PREFIX. Example: `python-asyncio-patterns/`, `python-pytest-fixtures/`.
- **Guardrails** that need a Python sibling use a `-py` suffix on the script name: `G30-py.sh`. (Or, preferred, generalize the existing `Gxx.sh` to dispatch via `scripts/run-toolchain.sh` so one script serves both languages.)

After authoring an artifact, add it to the appropriate array in `python.json` and run `bash scripts/validate-packages.sh` — orphan / duplicate / dangling references are detected.

## Generalization debt

Python pack starts debt-free at v0.5.0 Phase A. Generalization debt is tracked on `shared-core` (the package whose role is neutral but whose body cites idioms of a specific language) — not on language-adapter packs. If a Python-specific skill is later authored that turns out to also be useful for Rust/TS/Java, it gets moved to shared-core with an entry in `shared-core.json:generalization_debt`.

## Toolchain expectations

The `python.json:toolchain` block declares the canonical commands. Phase B authors should match these in agent prompts and guardrail scripts:

| Command | Tool |
|---|---|
| `build` | `python -m build` (PEP 517) |
| `test` | `pytest -x --no-header` |
| `lint` | `ruff check .` |
| `vet` | `mypy --strict .` |
| `fmt` | `ruff format --check .` |
| `coverage` | `pytest --cov=src --cov-report=json --cov-report=term` (≥90 % gate) |
| `bench` | `pytest --benchmark-only --benchmark-json=bench.json` |
| `supply_chain` | `pip-audit`, `safety check --full-report` |
| `leak_check` | `pytest tests/leak --asyncio-mode=auto` (custom asyncio task tracker) |

## Known Python-pack edge cases

These come up routinely in Python SDK authoring; Phase B agents and guardrails should be aware of them:

- **Mutable default arguments** (`def f(x=[])`) — silent state leak across calls. Caught by `sdk-design-devil` rule `mutable_default_argument`.
- **Bare `except:`** — swallows `KeyboardInterrupt` and `asyncio.CancelledError`. Use `except Exception:` minimum, or specific exception types.
- **`pickle.loads()` on untrusted input** — RCE. Always use a strict serialization format (JSON, msgpack with schema) for cross-process data.
- **`yaml.load()` without Loader** — code execution. Use `yaml.safe_load()`.
- **Module-level I/O / network calls** — runs at import, hard to test. Caught by `sdk-design-devil` rule `forbidden_module_side_effects`.
- **`==` for credential / signature comparison** — timing attack. Use `hmac.compare_digest`.
- **`asyncio.create_task()` without holding the reference** — task may be GC'd while still running. Use `asyncio.TaskGroup` (3.11+) or store the task in a long-lived collection.

All of these are catalogued with violation/fix examples in `conventions.yaml`.
