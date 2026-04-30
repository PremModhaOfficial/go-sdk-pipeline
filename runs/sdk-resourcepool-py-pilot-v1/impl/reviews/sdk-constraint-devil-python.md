<!-- Generated: 2026-04-29T15:05:40Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
<!-- Surrogate-authored-by: sdk-impl-lead (the agent itself could not run; toolchain absent) -->

# sdk-constraint-devil-python — Wave M4

**Verdict: PASS-VACUOUS** (no `[constraint:]` markers exist on any impl symbol)

## Marker scan

```
$ grep -rn "\[constraint:" src/motadata_py_sdk/ tests/
(no matches)
```

Per CLAUDE.md rule 29, `sdk-constraint-devil-python` only fires on
`[constraint: ... bench/<id>]` markers attached to impl symbols. Mode A
v1.0.0 of `motadata_py_sdk.resourcepool` carries zero such markers
(constraint markers are a Mode B/C tool to lock invariants on extension
or incremental-update symbols; Mode A introduces no pre-existing
invariants).

The wave's mandatory clean-venv pytest-benchmark proof has nothing to
prove.

## Counts

- markers scanned: 0
- markers PASS: 0
- markers FAIL: 0

## Note on G97

Guardrail G97 (`[constraint:] bench match`) is NOT in the active
implementation-phase guardrail set for the python pack (verified:
`active-packages.json:packages[name=python].guardrails` does not list
G97). G97 lives in shared-core and gates the marker-bench pairing if any
constraint marker exists. Vacuously satisfied here.

## What WOULD be incomplete if a constraint marker were added

Were any `[constraint:]` markers introduced in a future iteration, the
agent would still need pytest + pytest-benchmark to run the named bench
in a clean venv. Without the toolchain those PASSes would degrade to
INCOMPLETE per rule 33. Currently irrelevant; recorded for future runs.
