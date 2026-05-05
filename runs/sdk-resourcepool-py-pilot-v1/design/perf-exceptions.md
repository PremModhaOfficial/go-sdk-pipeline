<!-- Generated: 2026-04-27T00:01:31Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-perf-architect (D1) -->

# Performance Exceptions — `motadata_py_sdk.resourcepool`

Per CLAUDE.md rule 29 (Code Provenance Markers) and pipeline rule 32 (Perf-Confidence Regime axis 7).

This file declares any symbols that carry a `# [perf-exception: <reason> bench/<bench>]` marker — exempting them from `sdk-overengineering-critic` findings BUT requiring (a) a design-time entry here, (b) a named bench that measurably justifies the complexity, (c) profile-auditor evidence at impl phase.

G110 enforces the marker ↔ this-file pairing. Orphan `[perf-exception:]` markers without an entry here = BLOCKER.

---

## Status: empty (intentional)

No perf exceptions are declared for the resourcepool pilot v1.

**Rationale**:
- Every symbol in the design uses Pythonic, readable patterns (deque, Condition, asyncio.Lock, dataclass).
- No premature optimization is present. The hot paths are simple by design.
- If profile-auditor (M3.5) or overengineering-critic (T6) surface findings post-impl, perf-architect will revisit this file at H8 to decide: (a) accept the finding and refactor, or (b) declare a perf exception with measured justification.

If a perf exception is later proposed, the entry shape is:

```yaml
# Example (not active):
- symbol: motadata_py_sdk.resourcepool._pool.Pool._acquire_with_timeout
  marker: "# [perf-exception: hand-tuned counter mutation order avoids one extra Lock acquire bench/test_acquire.py::bench_acquire_happy_path]"
  reason: |
    The counter mutation ordering in _acquire_with_timeout intentionally interleaves
    self._waiting++ and the wait_for() call to avoid a second lock acquire.
    Refactoring to "lock, increment, wait, lock, decrement" was measured 18%
    slower at p50 in bench_acquire_happy_path.
  evidence_bench: tests/bench/bench_acquire.py::bench_acquire_happy_path
  evidence_speedup_pct: 18
  profile_auditor_verdict: "TO BE FILLED at M3.5"
```

The active list above is empty. Zero perf exceptions in v1.0.0.
