<!-- Generated: 2026-04-29T13:38:30Z | Agent: sdk-design-devil | Wave: D3 -->

# Design Devil Review — `motadata_py_sdk.resourcepool`

Reviewer: `sdk-design-devil` (shared-core, debt-bearer per D2 evaluation)
Verdict: **ACCEPT-WITH-NOTE**
Quality score (self-assessed): 87 / 100

This is the first Python pilot run for this agent. The review applies the
universal rule body via `python/conventions.yaml` overlay (D6=Split).

## Findings

### DD-001 (low / observation, ACCEPTED): Two acquire methods is unusual surface

`Pool.acquire()` returns an `AcquiredResource` context manager;
`Pool.acquire_resource()` returns the bare `T`. TPRD §15 Q6 already
considered and rejected the dual-mode trick. The split is documented and
the second method is named to discourage casual use. No fix required.

### DD-002 (low, ACCEPTED): `release` is async even though most code paths don't await

The `release` method is `async def` because `on_reset` may be a coroutine.
On the budget path (`on_reset is None`), the await dispatch costs ~3-5µs
that a sync `release` would save. TPRD §15 Q4 explicitly accepted this
trade-off (hook flexibility > hot-path overhead). The 30µs `release` p50
budget already accounts for it.

### DD-003 (medium → resolved by error-taxonomy.md): `ResourceCreationError` not in TPRD §5.4

TPRD §5.4 lists only 4 exception classes. The design adds a 5th
(`ResourceCreationError`). However, TPRD §7 inline note already references
the symbol by name: "`acquire()` raises the user-thrown exception wrapped
in a `ResourceCreationError(PoolError)` if `on_create` failed". Lifting it
to first-class export is consistent with the §7 note. `error-taxonomy.md`
documents this delta. **Resolved** before review-fix loop.

### DD-004 (low / observation, ACCEPTED): `stats()` reads private `_waiters` attribute

`PoolStats.waiting` reads `_slot_available._waiters` — a CPython-private
attr. `concurrency-model.md` documents the fallback (track `_waiting: int`
ourselves if private attr proves unstable). Acceptable. The design says
"if that's unstable across CPython versions, fall back...".

### DD-005 (medium → recommend FIX before impl): Lock held during `on_create` await

`algorithm-design.md` says `on_create` is awaited under `_slot_available`
lock. Documented as intentional, but: under capacity-create slow-path with a
slow `on_create`, every other acquirer queues. This is the **same** semantic
as the Go pool, so the choice is defensible by precedent. However, recommend
adding to docstring of `acquire`: "If your `on_create` performs I/O, prefer
calling it eagerly at startup to warm the pool — the first concurrent
acquirers will serialize through it." → Documentation finding only; not a
design change. **Acceptable as-is**, recorded as note.

## Quality score breakdown (self-assessed)

| Dimension | Score | Note |
|---|---|---|
| API ergonomics | 18/20 | Two-acquire-method surface explicit; OK. |
| Algorithm correctness | 19/20 | Lock-around-on_create is documented trade-off. |
| Concurrency safety | 19/20 | Cancellation invariant clearly stated and testable. |
| Error model | 17/20 | ResourceCreationError lift is the only TPRD-vs-design delta; documented. |
| Future-proofing | 14/20 | aclose semantics on out-of-deadline acquirers ("slot count permanently off") is documented but is a foot-gun. Consider adding a "force_kill" mode in v2. |
| **Total** | **87/100** | |

## Cross-language fairness check (D2 evaluation)

This agent's body is shared-core. Did the universal rules + python overlay
produce useful, non-noisy findings on Python source?

- **Useful**: DD-001 (parameter_count → single-Config rule), DD-005 (lock
  scope around external call). Both apply equally well to Python and Go.
- **No noise**: zero findings I'd characterize as "Go-flavored false alarm".
- **D2 verdict from this agent**: Lenient holds — quality_score 87
  vs Go-pool baseline (~85 on similar review). Within ±3pp.

## Verdict

**ACCEPT-WITH-NOTE** — design is approved. DD-005 is a documentation
addition for `acquire`'s docstring at impl time, not a design change.
DD-003 is resolved by error-taxonomy.md authoring.
