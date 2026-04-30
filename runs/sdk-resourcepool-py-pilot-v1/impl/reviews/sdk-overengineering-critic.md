<!-- Generated: 2026-04-29T16:02:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-impl-lead-toolchain-rerun (M7-DYN; replaces prior static ACCEPT) -->

# sdk-overengineering-critic — Wave M7-DYN (live toolchain)

**Verdict: ACCEPT** (confirmed; one new INFO).

## Re-confirmation post-M5b

OE-001 through OE-005 from the prior static review remain accurate:
- `AcquiredResource` 3-state machine — justified.
- Three `_async_on_*` cache flags — justified by perf-budget.md hot-path
  budget; M3.5-RERUN bench numbers (median 8.36 µs/round) confirm this
  is necessary headroom.
- `_outstanding_ids: set[int]` — required by TPRD §6.
- Hot-path stub functions — flagged in M3.5-RERUN as PA-003-MEDIUM
  (Phase 4 backlog) because they don't surface in py-spy, but the
  stubs themselves are not over-engineering — they're a profile-symbol
  resolution mechanism (a design contract, not a performance issue).

## New finding from M5b-followup

### OE-006 (INFO): `_is_closed_recheck()` helper added in M5b

`_pool.py:_is_closed_recheck` is a one-line method whose body is
`return self._closed`. Added solely to bypass mypy --strict's
`warn_unreachable` flow analysis on the double-checked-locking pattern.

Justification: routing through a method preserves both the runtime
double-check semantic and the static-analysis correctness. The
alternative — `# type: ignore[unreachable]` — would silence mypy at the
cost of a marker future readers must investigate. The method form is
self-documenting (the docstring explicitly explains the
double-checked-locking invariant).

**ACCEPT.** INFO-only; not over-engineering.

## `[perf-exception:]` cross-check (G110)

```
$ grep -rn "\[perf-exception:" src/ tests/
(no matches)
$ ls runs/sdk-resourcepool-py-pilot-v1/design/perf-exceptions.md
(no such file)
```

Vacuous **PASS**. Unchanged from prior static review.

## Counts

- BLOCKER: 0; HIGH: 0; MEDIUM: 0; LOW: 1 (OE-005, unchanged); INFO: 1 (OE-006, new).

Verdict: **ACCEPT.**
