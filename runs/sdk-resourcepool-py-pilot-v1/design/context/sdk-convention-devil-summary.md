<!-- Generated: 2026-04-27T00:02:14Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: sdk-convention-devil (NOTE: not in active-packages.json; design-lead authored as surrogate per orchestrator brief) -->

# Convention-Devil summary — D2 wave (surrogate)

## Output produced
- `design/reviews/convention-findings.md` (139 lines)

## Verdict: ACCEPT

10/10 convention checks passed:
- CF-001: snake_case modules + methods, PascalCase classes, _private underscore ✓
- CF-002: type hints on every public signature ✓
- CF-003: frozen+slots on Config + Stats ✓
- CF-004: sentinel error class hierarchy from PoolError ✓
- CF-005: marker syntax `#` (Python line-comment), zero Go-style `//` ✓
- CF-006: docstring first-word = symbol name on every public symbol ✓
- CF-007: Example_*-style runnable docstring examples on every public symbol ✓
- CF-008: no init() functions, no global mutable state ✓
- CF-009: timeout via asyncio kwarg (Python equivalent of context.Context) ✓
- CF-010: structural duck-typing + mypy strict (Python equivalent of compile-time interface assertions) ✓

## Note on agent provenance
sdk-convention-devil is NOT in active-packages.json. Orchestrator brief explicitly requested this review for Python-convention validation per TPRD §16. Design-lead authored as surrogate.

## Decision-log entries this agent contributed (logged under sdk-design-lead)
1. event: convention-as-surrogate (agent not in active set; orchestrator-required)
2. event: all-10-conventions-passed
3. decision: ACCEPT
