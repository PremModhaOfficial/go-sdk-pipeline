<!-- Generated: 2026-05-02T01:30:00Z | Run: nats-py-v1 -->

# sdk-design-lead — Phase 1 Design Context Summary

**Mode**: A (greenfield port to motadata-py-sdk).
**Tier**: T1 (full perf-confidence regime).
**Pipeline version**: 0.5.0.
**Active packages**: shared-core@1.0.0 + python@1.1.0.
**Lead**: sdk-design-lead. **Wall**: ~90 minutes. **Tokens**: ~160k of 500k design budget.

## What was decided

8 Python packages designed in a single run: `motadata_py_sdk.{codec, events.{utils,core,corenats,jetstream,stores,middleware}, otel, config}`. ~224 public symbols across ~38 source files; ~30 test files. 170 conformance checks from TPRD §14 mapped 1:1 to test rows. ~417 `[traces-to:]` markers pre-allocated.

Constructor pattern: Config struct + factory OR positional + KW-only optionals (NO functional options). Async-first (no sync surface). Protocol-based interfaces (5 in `events.core`). 33 sentinel exceptions in single hierarchy (wire-observable byte-exact strings per TPRD §4.6). All exceptions inherit from `EventsError` (or `CodecError` for codec layer). `ErrCircuitOpen` and `ErrRateLimitExceeded` inherit from `ErrPublishFailed` (mirror Go composition footgun; documented).

## What MIRRORS Go

12 open questions in TPRD §16 / canonical TPRD §15:
- 9 MIRROR Go behavior verbatim: codec non-determinism (Q2), no schema-version (Q3), 32-hex span ID (Q4), no CB HalfOpenMaxRequests (Q6), deprecated `messaging.destination` semconv (Q7), `create_consumer` actually create-or-update (Q10), `Subscriber.unsubscribe` actually drains (Q11), `Requester.close` does not delete consumer (Q12), `BatchPublisher.add` size-trigger drops caller ctx.
- 3 FIX divergences-up: Q1 (TenantID validation enforced), Q5 (consumer span linked via propagator.extract), Q8 (KV/Object Store OTel spans). Toggle-able at H5.
- 1 (Q9) Python-only addition: `TenantKVStore` + `TenantObjectStore` overlays.

15 NATS header constants byte-exact. Codec wire format byte-exact (custom binary tags + msgpack defaults `use_bin_type=True, raw=False, datetime=True, timestamp=3, strict_map_key=False`). 33 sentinel error strings byte-exact. 15 OTel span names byte-exact. 8 OTel metric names byte-exact (histogram unit "ms"). Hard-coded JS Stream fields (Discard=Old, Duplicates=120s, AllowDirect=True). Default timeouts 30s/5s/10s.

## Perf-budget (D1 BLOCKER artifact for Phase 2 entry)

70 rows covering 49 §7 hot-path symbols. Calibrated against:
- `nats-py` ~50-200µs publish floor over loopback (advisory R4).
- `msgpack-python` ~6µs codec floor.
- `asyncio.create_task` ~10-30µs structural floor for per-msg dispatch.
- `baselines/python/performance-baselines.json` resourcepool seed (0.04 allocs/op amortized; loaded host class).

Oracle margins 1.5-2.5× for most NATS surfaces; 8× for `BatchPublisher.add` micro-op (justified). 8 soak-eligible symbols with mmd 120-600s. 7 drift signals: heap_rss, tracemalloc, asyncio_tasks, gc_pauses, pending_futures, pending_naks, watcher_lag.

## What downstream agents need to know

### sdk-impl-lead (Phase 2)

1. Read `design/scope.md §Slice plan` for 10 slices in dependency order.
2. Read `design/api.py.stub` as the canonical contract; do NOT re-author signatures.
3. Read `design/algorithms.md` for byte-exact algorithms (codec, retry backoff, CB state machine, Requester dispatch, etc.).
4. Read `design/concurrency.md` for asyncio task accounting + cancellation rules.
5. Apply `[traces-to:]` markers per `design/traces-to-plan.md` verbatim. Do NOT invent new mappings — change `traces-to-plan.md` first if needed.
6. H7b mid-impl checkpoint after Slice 5 (events.jetstream Stream + Publisher + Consumer).
7. M1 binding gates: `pip-audit` + `safety check --full-report` clean per `design/dependencies.md` conditions.
8. M3.5: `sdk-profile-auditor` enforces alloc budgets per `perf-budget.md` (G104). 

### sdk-testing-lead (Phase 3)

1. 170 conformance checks from TPRD §14 → 170 parametrized test rows. Map 1:1 to `tests/unit/.../test_*.py` per `design/package-layout.md §tests/unit`.
2. ~40 integration tests via `testcontainers[nats]` per `design/dependencies.md` row 17.
3. ~10 cross-language byte-fixture tests under `tests/fixtures/codec/`. Fixtures emitted by Go SDK CI (one-time job).
4. Bench naming convention `bench_<package>_<symbol>` per `design/perf-budget.md §L`. Allocation measurement via `tracemalloc` helper in `tests/bench/conftest.py::_alloc_count`.
5. 8 soak harnesses in `tests/leak/test_soak_*.py` per `design/perf-budget.md §I`.
6. Coverage gate ≥90% per `python.json::toolchain.coverage_min_pct`.

### sdk-marker-scanner (run-end)

Marker syntax (Python): both `# [traces-to: ...]` line comments AND `[traces-to: ...]` lines inside `"""..."""` docstrings. Scan all `.py` files in `src/motadata_py_sdk/{codec,events/*,otel,config}/`. G99 enforces every public symbol has a `[traces-to:]`.

### sdk-perf-architect / sdk-benchmark-devil (Phase 3)

`design/perf-budget.md` is the source-of-truth. Oracle breach (G108) is BLOCKER, not waivable via `--accept-perf-regression`. Margin updates require H8 written rationale.

### sdk-profile-auditor (M3.5)

`design/perf-budget.md` `allocs_per_op` column is the binding budget per row. G104 BLOCKER on overage. `sdk-perf-architect` Section A-H rows are calibrated to Python interpreter realities; Go-derived numbers were NOT propagated.

## Devil verdicts (D2 self-review at this scope)

| Devil | Verdict | BLOCKERs | Notes |
|---|---|---|---|
| sdk-design-devil | ACCEPT-WITH-NOTES | 0 | 5 issues; all documented |
| sdk-dep-vet-devil | ACCEPT-WITH-CONDITIONS | 0 | 4 conditions deferred to M1 |
| sdk-semver-devil | ACCEPT | 0 | Mode A v0.1.0 baseline |
| sdk-convention-devil | ACCEPT-WITH-NOTES | 0 | 7 cross-SDK deviations recorded |
| sdk-security-devil | ACCEPT | 0 | TLS validation + cred hygiene OK |
| sdk-constraint-devil | ACCEPT | 0 | 70 rows, 8 soaks, all margins sane |

`sdk-breaking-change-devil`: SKIPPED (Mode A; not in active set).
`sdk-marker-hygiene-devil`: SKIPPED at design (no impl yet).

## Open items handed forward

1. opentelemetry-instrumentation-logging upper-bound pin at M1 (`<0.55`).
2. nats-py specific minor pin at M1 if a new release lands.
3. Cross-language byte-fixtures from Go SDK CI (one-time; T2 dependency).
4. Docker availability on test host (testcontainers; G69 + environment-prerequisites-check).
5. notify-send to user at H5 per memory preference.
6. Decision-log entry budget consumed: ~5 of 15. Plenty of headroom for Phase 2 hand-off + close.

## What was deferred (NOT in design phase)

- Branch creation (deferred to first impl write per rule 17).
- pyproject.toml dependency add (deferred to M1; `design/dependencies.md` shows the diff).
- Test fixture generation (deferred to T2).
- Soak runs (deferred to T5.5).
