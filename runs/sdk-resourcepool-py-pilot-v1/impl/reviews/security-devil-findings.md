<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M7 | Reviewer: sdk-security-devil (READ-ONLY) -->

# Security Devil — Impl-phase Findings

Re-runs the design-phase security review against the actual implementation. Carries forward SD-001 (hook trust boundary) and verifies it was documented per the recommendation.

## Verdict: ACCEPT (1 design-phase note carried + verified addressed; 0 new findings)

---

## SD-001 (carried from design phase): Hook execution is caller-trusted code

**Where**: `_pool.py` Pool — `on_create`, `on_reset`, `on_destroy` hooks.

**Design-phase recommendation**: "Add a 'Security Model' section to Pool's docstring noting hooks run in caller-trust boundary."

**Impl-phase verification**: addressed in three places:

1. `Pool` class docstring: `Security model: hooks run in the caller-trust boundary (this process, this loop). Pool does not sandbox.`
2. `_pool.py` module docstring: full multi-paragraph treatment with cross-reference to `security-findings.md`.
3. `docs/USAGE.md` Security model section: caller-facing version.

PASS.

---

## SD-002 — Re-checked: deserialization of untrusted input

PASS. The pool stores `T` (caller-typed); no JSON / pickle / msgpack / XML parsing anywhere in the package. `grep -rn "pickle\|json.loads\|msgpack\|xml" src/motadata_py_sdk/resourcepool/` returns zero hits.

---

## SD-003 — Re-checked: PII paths

PASS. The pool logs only `config.name` (caller-supplied label) in the WARN message from `_destroy_resource_via_hook`. Resource bodies are NEVER logged, NEVER serialized. Counters are integers. Verified by:

```
$ grep -n "logging\|_LOG\|log\." src/motadata_py_sdk/resourcepool/_pool.py
26: import logging
48: _LOG = logging.getLogger(__name__)
588:        _LOG.warning(
589:            "on_destroy raised in pool '%s'; resource dropped",
590:            self._config.name,
591:            exc_info=True,
592:        )
```

The `exc_info=True` includes the user's traceback. If a user's `on_destroy` exception itself contains PII in its message, that PII will appear in the WARN log. **This is the user's responsibility per the security model docstring** — the pool surfaces what the user threw.

---

## SD-004 — Re-checked: supply chain

PASS.

- `pip-audit`: clean (no known vulnerabilities).
- `pyproject.toml dependencies = []` — zero direct runtime deps.
- Dev deps (`optional-dependencies.dev`): pytest, pytest-asyncio, pytest-benchmark, pytest-cov, ruff, mypy, pip-audit, safety. All license-allowlisted (MIT / Apache-2.0 / BSD).
- `safety scan` requires login; `pip-audit` covers the supply-chain check sufficiently per CLAUDE.md rule 24.

---

## SD-005 — Re-checked: input validation

PASS. `Pool.__init__` validates:

- `max_size <= 0` -> `ConfigError`
- `on_create is None` -> `ConfigError`
- `name` non-string OR empty -> coerced to `"resourcepool"` (no error)

`try_acquire` validates `_on_create_is_async` -> `ConfigError`.

No SSRF surface (the pool does no I/O of its own). No deserialization. No exec/eval. No subprocess spawning.

---

## Verdict summary

ACCEPT. Design-phase SD-001 carried forward + verified addressed. No new security findings.
