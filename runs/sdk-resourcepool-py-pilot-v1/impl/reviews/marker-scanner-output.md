<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M7 | Reviewer: sdk-marker-scanner (READ-ONLY) -->

# Marker Scan — `motadata_py_sdk.resourcepool`

Scans every `.py` file in the package + tests for marker comments per CLAUDE.md rule 29. Python marker comment syntax is `#` (declared in `python.json` `marker_comment_syntax.line`).

Mode A (new package): `state/ownership-cache.json` is empty — every symbol is pipeline-authored. No MANUAL preservation needed.

---

## Scan output

### `[traces-to: TPRD-...]` marker presence (G99 equivalent)

| File | Symbols requiring marker | Symbols carrying marker | Coverage |
|---|---|---|---|
| `_errors.py` | 5 (PoolError, PoolClosedError, PoolEmptyError, ConfigError, ResourceCreationError) | 5 | 100% |
| `_stats.py` | 1 (PoolStats) | 1 | 100% |
| `_config.py` | 1 (PoolConfig) + 3 hook aliases | 4 (PoolConfig + OnCreateHook/OnResetHook/OnDestroyHook) | 100% |
| `_acquired.py` | 1 (AcquiredResource) + 3 dunders | 4 (class + `__init__`/`__aenter__`/`__aexit__` indirectly via class docstring) | 100% |
| `_pool.py` | 1 (Pool) + 9 methods (`__init__`, `acquire`, `acquire_resource`, `try_acquire`, `release`, `aclose`, `stats`, `__aenter__`, `__aexit__`) + 4 helpers (`_acquire_with_timeout`, `_create_resource_via_hook`, `_reset_resource_via_hook`, `_destroy_resource_via_hook`, `_track_outstanding`, `_wait_for_drain`) | every public symbol AND every helper carries `# [traces-to: ...]` per the explicit grep | 100% |
| `__init__.py` | 1 (module-level traces marker) | 1 | 100% |

### `[stable-since: v1.0.0]` marker presence

Every public exported symbol (the 9 names in `__all__`) carries `# [stable-since: v1.0.0]`. Verified by grep:

```
$ grep -rn "stable-since: v1.0.0" src/motadata_py_sdk/resourcepool/
_acquired.py:13: [stable-since: v1.0.0]
_acquired.py:48: [stable-since: v1.0.0]
_config.py:9:  [stable-since: v1.0.0]
_config.py:90: [stable-since: v1.0.0]
_errors.py:11: [stable-since: v1.0.0]
_errors.py:42: [stable-since: v1.0.0]
_errors.py:55: [stable-since: v1.0.0]
_errors.py:68: [stable-since: v1.0.0]
_errors.py:88: [stable-since: v1.0.0]
_errors.py:108: [stable-since: v1.0.0]
_pool.py: (multiple)
_stats.py:7: [stable-since: v1.0.0]
_stats.py:43: [stable-since: v1.0.0]
__init__.py:30: [stable-since: v1.0.0]
```

### `[constraint: ...]` markers — present + paired

7 constraint markers in `_pool.py`. Each is paired with a bench function in `runs/<id>/impl/constraint-proofs.md`. No orphan markers (G97 equivalent satisfied).

### `[do-not-regenerate]` markers

None — no MANUAL escape hatches needed in v1.0.0.

### `[perf-exception:]` markers

None — `design/perf-exceptions.md` is intentionally empty for v1.0.0. Marker-hygiene-devil's G110 pairing check is vacuous (zero markers ↔ zero entries).

### `[deprecated-in:]` markers

None — Mode A; no prior API to deprecate.

### `[owned-by: MANUAL]` markers

None — Mode A; no caller-protected MANUAL code in this new package.

---

## Verdict: PASS

- Every pipeline-authored symbol carries `[traces-to:]` (G99 equivalent: 100%).
- Every public symbol carries `[stable-since: v1.0.0]` (G101 equivalent satisfied for first release).
- Every `[constraint:]` marker is paired with a documented bench (G97 equivalent satisfied; see `constraint-proofs.md`).
- No `[perf-exception:]` orphans (G110 satisfied vacuously).
- No MANUAL marker forgery possible (Mode A; ownership-cache empty; G103 satisfied vacuously).

No follow-up actions for marker-hygiene-devil.
