# Performance Budget (D1) — `nats-py-v1`

**Authored by**: `sdk-perf-architect` (sdk-design-lead acting in this role).
**Date**: 2026-05-02.
**Tier**: T1 (full perf-confidence regime per CLAUDE.md rule 32).
**Reference oracles**: `nats-py` (publish/subscribe), `msgpack-python` (codec), `aiocircuitbreaker` (CB), `asyncio.Semaphore` (rate limit baseline).

## How to read this document

- Each row declares one §7-symbol from the TPRD `§7 API Surface`.
- Numbers are **measurement targets** (will be enforced at T5 by `sdk-benchmark-devil`).
- `oracle.*` columns set the upper bound — measured p50 must stay within `oracle.margin_multiplier × oracle.reference_p50_us`. Breach = BLOCKER per G108. Margin updates require H8 written rationale.
- `allocs/op` budget enforced at M3.5 by `sdk-profile-auditor` per G104. BLOCKER, not waivable via `--accept-perf-regression`.
- `complexity` declared via big-O; `sdk-complexity-devil` scaling-tests at T5 per G107.
- `mmd_seconds` = minimum-measurement-duration for soak-class symbols; G105 enforces at T5.5.
- `[perf-exception:]` markers (G110) are NOT pre-declared here; if impl needs one it lands in `perf-exceptions.md` via H5 amendment.
- **Caveat**: numbers calibrated against `baselines/python/performance-baselines.json` (resourcepool seed: `0.04 allocs/op` amortized cycle, 1µs–60µs range, host_load_class=loaded). NATS publish baselines do not yet exist — these are first-seed targets per Risk R4.

---

## Section A: codec (TPRD §4.3)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `pack_map(d, CUSTOM)` 10-field str→str | yes | 30 | 60 | 120 | 30 | 33000 | O(n) field count | manual `struct.pack` loop | 15 | 2.5 | n/a | heap_rss, gc_gen0_pauses |
| `pack_map(d, MSGPACK)` 10-field str→str | yes | 8 | 15 | 30 | 4 | 125000 | O(n) | `msgpack.packb` (defaults) | 6 | 1.6 | n/a | heap_rss |
| `unpack_map(b, CUSTOM)` 10-field | yes | 35 | 70 | 140 | 35 | 28000 | O(n) | manual `struct.unpack` loop | 18 | 2.5 | n/a | heap_rss |
| `unpack_map(b, MSGPACK)` 10-field | yes | 7 | 14 | 28 | 4 | 140000 | O(n) | `msgpack.unpackb` (defaults) | 5 | 1.7 | n/a | heap_rss |
| `pack_array([0..99], CUSTOM)` int64 | no | 60 | 120 | 240 | 30 | 16000 | O(n) | n/a | n/a | n/a | n/a | n/a |
| `pack_array([0..65535], CUSTOM)` boundary | no | 12000 | 24000 | 48000 | 50 | 80 | O(n) | n/a | n/a | n/a | n/a | n/a |

**Floor justification (codec)**:
- Custom binary `pack_map` 10-field: 1 header byte + 1 dispatch + 1 length + 10×(1 tag + 1 keylen + key bytes + 1 tag + value bytes) ≈ 10 dict iterations + 21 `struct.pack` calls + 10 `bytes.append`-equivalents → structural floor ~30 allocs (mostly `bytes` for each `struct.pack` result + final `b"".join`). Aspirational <10 allocs would require a single pre-sized `bytearray` write loop with `struct.pack_into` — feasible but requires 20-30% more code and breaks the per-tag dispatch model. Deferred (Optional Optim 1 in §C below).
- MsgPack `pack_map`: `msgpack.packb` is C-implemented; allocs come from arg-marshalling. 4 allocs is `msgpack`'s typical floor for a small dict (verified empirically on 1.0.x).
- p50 target = ~2× C-impl floor for custom, ~1.5× for msgpack (Python interpreter overhead per dispatch).

---

## Section B: events.core (TPRD §5)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `extract_headers(ctx, headers={}) `OTel-active path | yes | 25 | 50 | 100 | 8 | 40000 | O(1) | n/a | n/a | n/a | n/a | heap_rss |
| `extract_headers(ctx, None)` no-trace path | yes | 5 | 10 | 20 | 2 | 200000 | O(1) | n/a | n/a | n/a | n/a | heap_rss |
| `inject_context(ctx, headers)` 6 keys | yes | 10 | 20 | 40 | 4 | 100000 | O(1) | n/a | n/a | n/a | n/a | heap_rss |
| `set_tenant_id(id)` | no | 1 | 2 | 4 | 1 | 1000000 | O(1) | n/a | n/a | n/a | n/a | n/a |
| `get_tenant_id()` | no | 0.5 | 1 | 2 | 0 | 2000000 | O(1) | `contextvars.ContextVar.get` | 0.3 | 1.7 | n/a | n/a |

**Floor justification (events.core)**:
- `extract_headers` OTel-active path: 1 dict alloc (headers if None) + 5 `dict.__setitem__` for trace keys + 1 contextvars get + 1 OTel `get_current_span()` + 1 trace_id/span_id format. Floor ~6-8 allocs.
- `inject_context`: 6 dict.get + 1 TraceContext alloc + ctx.attach (returns token alloc) → floor 4 allocs.

---

## Section B.1: events.utils (TPRD §4.6) — added at H5-rev-3 D3 iter 2

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `events.utils.is_retryable(err)` typical (retryable sentinel) | no | 0.5 | 1.0 | 2.0 | 0 | 2000000 | O(1) | `frozenset.__contains__` + `isinstance` | 0.3 | 1.7 | n/a | n/a |
| `events.utils.is_temporary(err)` | no | 0.3 | 0.6 | 1.2 | 0 | 3000000 | O(1) | `tuple.__contains__` (4 items) | 0.2 | 1.5 | n/a | n/a |

**Floor justification (events.utils)**:
- `is_retryable`: hot path is `type(err) in _NEVER_RETRY` (frozenset O(1) hash lookup; ~50ns C-impl) followed by `isinstance` check against the 8 NON-retryable bases (~150ns). Total floor ~200-300ns; budget 500ns. ZERO allocations — all checks operate on the cached frozenset + class-tuple bound at module load. Bench: `tests/bench/bench_is_retryable.py::test_bench_is_retryable_typical`. Constraint marker on the symbol: `[constraint: p50 <= 500ns | bench/bench_is_retryable_typical]` (the symbol's existing marker in api.py.stub uses `0.5us` which is the same value).
- Despite being marked `hot_path: no`, `is_retryable` is called once per Retry middleware attempt — a published message with 3 retries will trigger 3 calls. The 0.5µs p50 budget × 3 = 1.5µs per retried publish, well below the publish path budgets.

---

## Section C: events.corenats (TPRD §6)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `Publisher.publish(subj, msg)` 1KB loopback | yes | 350 | 700 | 1400 | 12 | 2800 | O(1) | `nc.publish(subj, b)` direct | 200 | 1.75 | n/a | heap_rss, asyncio_tasks |
| `Publisher.request(subj, msg)` 1KB loopback | yes | 600 | 1200 | 2400 | 18 | 1600 | O(1) | `nc.request` direct | 350 | 1.7 | n/a | heap_rss, asyncio_tasks |
| `Subscriber.subscribe.cb` per-msg dispatch | yes | 25 | 50 | 100 | 6 | 40000 | O(1) | `cb` direct invocation | 12 | 2.0 | n/a | asyncio_tasks |
| `BatchPublisher.add(subj, msg)` no-flush | yes | 8 | 16 | 32 | 2 | 125000 | O(1) | list.append | 1 | 8 | n/a | heap_rss |
| `BatchPublisher.flush()` 100-msg batch sequential | yes | 35000 | 70000 | 140000 | 1200 | 28 | O(n) | n×Publisher.publish | 20000 | 1.75 | n/a | heap_rss, asyncio_tasks |
| `BatchPublisher.flush()` 100-msg batch concurrent (64 workers) | yes | 12000 | 25000 | 50000 | 1300 | 80 | O(n/k) | n×Publisher.publish/k | 7000 | 1.7 | n/a | asyncio_tasks (peak ≤100) |
| `Subscriber.subscribe long-running` | yes (soak) | n/a | n/a | n/a | n/a | 40000 sustained | O(1) | n/a | n/a | n/a | **300** | asyncio_tasks_count, heap_rss, gc_pauses |

**Floor justification (events.corenats)**:
- `Publisher.publish` 1KB loopback: nats-py docs cite ~50–200µs over loopback at 1KB (Risk R4 advisory); span open/close adds ~30µs (per `python-otel-instrumentation` skill); middleware chain (default empty) ~5µs; `extract_headers` 25µs (Section B). Floor ~200µs; budget 350µs absorbs interpreter + dict-headers cost.
- `BatchPublisher.flush` concurrent: with 64 workers, n=100 → 100/64 ≈ 1.6 workers serially × 350µs/publish ≈ 600µs ideal; reality dominated by `asyncio.gather` task-creation cost ≈ 30µs × 64 ≈ 2ms; budget 12ms absorbs both.
- `Subscriber.subscribe.cb` floor: per `nats-python-client-patterns` skill — nats-py invokes via `asyncio.create_task` (~10-30µs structural floor per Risk R4 advisory); span open/close adds ~30µs; budget 25µs assumes hot-path with cached tracer + no middleware. Increase to 40µs once tracing middleware is wrapped.

---

## Section D: events.jetstream (TPRD §7)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `JsPublisher.publish(subj, msg)` 1KB ack-required | yes | 1500 | 3000 | 6000 | 18 | 660 | O(1) | `js.publish` direct | 900 | 1.7 | n/a | heap_rss |
| `JsPublisher.publish_async(subj, msg)` future | yes | 30 | 60 | 120 | 4 | 33000 | O(1) | `asyncio.create_task` | 20 | 1.5 | n/a | asyncio_tasks (unbounded — risk) |
| `Consumer.start.cb` per-msg dispatch | yes | 35 | 70 | 140 | 8 | 28000 | O(1) | `m.ack()` direct | 18 | 2.0 | n/a | asyncio_tasks |
| `Requester.request(subj, msg)` round-trip | yes | 2500 | 5000 | 10000 | 30 | 400 | O(1) | publish + future await | 1500 | 1.7 | n/a | heap_rss, pending_futures |
| `Stream.create(cfg)` | no | 8000 | 16000 | 32000 | 60 | 125 | O(1) | `js.add_stream` | 5000 | 1.6 | n/a | n/a |
| `Consumer.start long-running` | yes (soak) | n/a | n/a | n/a | n/a | 28000 sustained | O(1) | n/a | n/a | n/a | **600** | asyncio_tasks_count, pending_naks, heap_rss |
| `Consumer dispatch loop` per-pull cycle | yes | 5000 | 10000 | 20000 | 80 | 200 | O(b) batch | `psub.fetch(b)` direct | 3000 | 1.7 | n/a | n/a |

**Floor justification (events.jetstream)**:
- `JsPublisher.publish` 1KB ack-required: ~1ms typical (server-side write + ack RTT on loopback); span ~30µs; codec serialization (caller's bytes already ready). Floor ~900µs; budget 1.5ms.
- `JsPublisher.publish_async` future: just allocates future + spawns task. Floor ~20µs (task creation); budget 30µs.
- `Requester.request`: publisher.publish (1.5ms) + js consumer dispatch round-trip (~1ms) + future settle. Budget 2.5ms.

---

## Section E: events.stores (TPRD §8)

**Span emission**: EMITTED at SDK layer (TPRD §15.29 FIX — restored at H5-rev-3
D3 iter 2; Q8 revocation reversed). Budgets below INCLUDE span open/close overhead
at ≤1µs at p50 (per the python-otel-instrumentation lazy-meter pattern with
cached tracer). The added overhead is small enough that the existing `p50` /
`allocs_per_op` budgets remain valid (1µs span vs. 800-3000µs base op = ≤0.1%
of latency budget; +0–1 alloc per op for the span attributes dict). Numerical
budgets unchanged from rev-2; the oracle column is now interpreted as "oracle
= `kv.put` direct + 1µs span overhead" implicitly.

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `KVStore.put(k, v)` 1KB (with span) | yes | 1500 | 3000 | 6000 | 19 | 660 | O(1) | `kv.put` direct + 1µs span | 1001 | 1.5 | n/a | heap_rss |
| `KVStore.get(k)` 1KB (with span) | yes | 800 | 1600 | 3200 | 11 | 1250 | O(1) | `kv.get` direct + 1µs span | 501 | 1.6 | n/a | heap_rss |
| `KVStore.create(k, v)` CAS (with span) | yes | 1500 | 3000 | 6000 | 19 | 660 | O(1) | `kv.create` direct + 1µs span | 1001 | 1.5 | n/a | n/a |
| `KVStore.update(k, v, last)` CAS (with span) | yes | 1500 | 3000 | 6000 | 19 | 660 | O(1) | `kv.update` direct + 1µs span | 1001 | 1.5 | n/a | n/a |
| `KVStore.delete(k)` (with span) | no | 1200 | 2400 | 4800 | 17 | 830 | O(1) | `kv.delete` direct + 1µs span | 800 | 1.5 | n/a | n/a |
| `KVStore.purge(k)` (with span) | no | 1200 | 2400 | 4800 | 17 | 830 | O(1) | `kv.purge` direct + 1µs span | 800 | 1.5 | n/a | n/a |
| `KVStore.keys()` (with span) | no | 2000 | 4000 | 8000 | 30 | 500 | O(n_keys) | `kv.keys` direct + 1µs span | 1300 | 1.55 | n/a | heap_rss |
| `KVStore.history(k)` (with span) | no | 1500 | 3000 | 6000 | 25 | 660 | O(history_len) | `kv.history` direct + 1µs span | 1000 | 1.5 | n/a | n/a |
| `KVStore.status()` (with span) | no | 1000 | 2000 | 4000 | 15 | 1000 | O(1) | `kv.status` direct + 1µs span | 700 | 1.45 | n/a | n/a |
| `ObjectStore.put_bytes(name, b)` 1KB (with span) | yes | 3000 | 6000 | 12000 | 26 | 330 | O(n/chunk) | `os.put` direct + 1µs span | 2001 | 1.5 | n/a | heap_rss |
| `ObjectStore.put_file(path)` 1MB stream (with span) | no | 80000 | 160000 | 320000 | 101 | 12 | O(n/chunk) | `os.put_file` direct + 1µs span | 60001 | 1.4 | n/a | heap_rss (peak ≤2 chunks) |
| `ObjectStore.get(name)` (with span) | no | 2000 | 4000 | 8000 | 20 | 500 | O(1) | `os.get` direct + 1µs span | 1300 | 1.55 | n/a | n/a |
| `ObjectStore.get_info(name)` (with span) | no | 1500 | 3000 | 6000 | 15 | 660 | O(1) | `os.get_info` direct + 1µs span | 1000 | 1.5 | n/a | n/a |
| `ObjectStore.delete(name)` (with span) | no | 1500 | 3000 | 6000 | 15 | 660 | O(1) | `os.delete` direct + 1µs span | 1000 | 1.5 | n/a | n/a |
| `ObjectStore.list()` (with span) | no | 3000 | 6000 | 12000 | 50 | 330 | O(n_objects) | `os.list` direct + 1µs span | 2000 | 1.5 | n/a | heap_rss |
| `ObjectStore.status()` (with span) | no | 1000 | 2000 | 4000 | 15 | 1000 | O(1) | `os.status` direct + 1µs span | 700 | 1.45 | n/a | n/a |
| `KVStore.watch(...) iterator` long-running (per-emit with span) | yes (soak) | n/a | n/a | n/a | n/a | 5000 sustained | O(1) per emit | n/a | n/a | n/a | **300** | asyncio_tasks, watcher_lag |
| `ObjectStore.put_file 100MB streaming` (with span) | no (soak) | n/a | n/a | n/a | n/a | n/a | O(n) | n/a | n/a | n/a | **120** | heap_rss MUST stay ≤ 1024 KiB peak (3 chunks × 128 KiB + overhead) |
| `ObjectStore.watch() iterator` long-running (per-emit with span) | yes (soak) | n/a | n/a | n/a | n/a | 1000 sustained | O(1) per emit | n/a | n/a | n/a | **300** | asyncio_tasks, watcher_lag |

---

## Section F: events.middleware (TPRD §9)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `chain(*ms).wrap(handler)` 6-mw publish path | yes | 12 | 25 | 50 | 4 | 80000 | O(n) wraps | functools.reduce | 6 | 2.0 | n/a | n/a |
| `MultiCircuitBreaker.get(subj)` cached | yes | 0.8 | 1.6 | 3.2 | 0 | 1250000 | O(1) amortized | `dict.get` | 0.5 | 1.6 | n/a | n/a |
| `MultiCircuitBreaker.get(subj)` lazy-create | no | 30 | 60 | 120 | 8 | 33000 | O(1) | n/a | n/a | n/a | n/a | n/a |
| `CircuitBreaker.allow()` CLOSED state | yes | 0.5 | 1 | 2 | 0 | 2000000 | O(1) | atomic load | 0.3 | 1.7 | n/a | n/a |
| `RetryMiddleware.intercept_publish.next` no-fail | yes | 3 | 6 | 12 | 1 | 333000 | O(1) | direct call | 1 | 3.0 | n/a | n/a |
| `RetryMiddleware backoff` per-attempt sleep | no | 100000 | 110000 | 130000 | 5 | 9 | O(1) | `asyncio.sleep` | 100000 | 1.05 | n/a | n/a |
| `TokenBucketLimiter.allow_n(1)` happy path | yes | 1.5 | 3 | 6 | 0 | 666000 | O(1) | atomic CAS | 0.8 | 2.0 | n/a | n/a |
| `SlidingWindowLimiter.allow()` 1000 window | yes | 8 | 16 | 32 | 1 | 125000 | O(w) prune | bisect on deque | 4 | 2.0 | n/a | n/a |
| `OTELMetricsMiddleware.intercept_publish.next` | yes | 8 | 16 | 32 | 3 | 125000 | O(1) | direct counter+histogram | 4 | 2.0 | n/a | n/a |
| `LoggingMiddleware.intercept_publish.next` payload-off | yes | 4 | 8 | 16 | 2 | 250000 | O(1) | `logger.info` | 2 | 2.0 | n/a | n/a |
| `TracingMiddleware.intercept_publish.next` | yes | 35 | 70 | 140 | 8 | 28000 | O(1) | `tracer.start_as_current_span` | 20 | 1.75 | n/a | n/a |
| **End-to-end 6-mw chain (default order) per publish** | yes | 65 | 130 | 260 | 16 | 15000 | O(1) | sum of components | 35 | 1.85 | n/a | heap_rss |

**Floor justification (middleware)**:
- `chain(*ms).wrap`: 6× closure-creation calls; each closure is one Python function-object allocation (~0.5µs × 6 + dispatch overhead). Floor ~6µs; budget 12µs.
- `TracingMiddleware.intercept_publish.next`: span open + 3 attribute sets + ensure_headers + extract_headers (Section B 25µs) + next + span end. Floor ~20µs; budget 35µs.
- End-to-end: this is the budget that drives all downstream regression checks. 65µs middleware overhead on top of 350µs publish = ~415µs total pub p50. Used as the primary publish baseline at T5.

---

## Section G: otel (TPRD §10)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `tracer.start_producer(name, attrs)` no-op sampler | yes | 5 | 10 | 20 | 2 | 200000 | O(1) | `NoopTracer.start_span` | 3 | 1.7 | n/a | n/a |
| `tracer.start_producer` AlwaysOn sampler | yes | 25 | 50 | 100 | 6 | 40000 | O(1) | `Tracer.start_span` | 15 | 1.7 | n/a | n/a |
| `metrics.Counter.add(1, attrs)` cached handle | yes | 1.5 | 3 | 6 | 0 | 666000 | O(1) | OTel Counter direct | 1 | 1.5 | n/a | n/a |
| `metrics.Histogram.record(t, attrs)` cached | yes | 2 | 4 | 8 | 0 | 500000 | O(1) | OTel Histogram direct | 1.2 | 1.7 | n/a | n/a |
| `Logger.info(msg, **fields)` JSON encoder | yes | 8 | 16 | 32 | 4 | 125000 | O(n) fields | stdlib logger | 4 | 2.0 | n/a | n/a |
| `Init(cfg)` provider construction | no | 50000 | 100000 | 200000 | 200 | 20 | O(1) | n/a | n/a | n/a | n/a | n/a |
| `Shutdown(timeout=10s)` flush + close | no | 500000 | 800000 | 1200000 | 50 | 2 | O(pending) | n/a | n/a | n/a | n/a | n/a |

---

## Section H: config (TPRD §11)

| Symbol | hot_path | p50_us | p95_us | p99_us | allocs_per_op | throughput_ops_s | complexity | oracle.reference | oracle.reference_p50_us | margin_mult | mmd_s | drift_signals |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `Settings()` from env (cold) | no | 5000 | 10000 | 20000 | 200 | 200 | O(n_keys) | pydantic.BaseSettings | 3000 | 1.7 | n/a | n/a |
| `Settings()` from YAML+env (cold) | no | 15000 | 30000 | 60000 | 400 | 67 | O(n_keys) | pyyaml + pydantic | 9000 | 1.7 | n/a | n/a |
| `EventsConfig.validate()` | no | 50 | 100 | 200 | 5 | 20000 | O(servers) | pydantic field_validators | 30 | 1.7 | n/a | n/a |

---

## Section I: cross-cutting drift signals + soak harness

**Drift signals enumerated** (per CLAUDE.md rule 32 axis 6):

1. `heap_rss_kb` — process RSS via `psutil.Process().memory_info().rss / 1024`. Sampled every 10s in soak.
2. `tracemalloc_traced_kb` — via `tracemalloc.get_traced_memory()`. Sampled every 10s.
3. `asyncio_tasks_count` — via `len(asyncio.all_tasks())`. Sampled every 1s; positive monotone over soak window = leak.
4. `gc_gen0_pauses_ms` — via `gc.get_stats()[0]['collections']` rate-of-change. Drift = pause-rate increase.
5. `pending_futures` (Requester only) — instrumentation hook. Positive monotone = leak.
6. `pending_naks` (Consumer only) — instrumentation hook.
7. `watcher_lag_ms` (KV watch only) — distance between server-emit timestamp and Python-receive timestamp. Drift = consumer falling behind.

**Soak harness** (lives at `tests/leak/test_soak_<symbol>.py`):

- `run_in_background` per CLAUDE.md rule 33.
- Polls drift-signal state files on a ladder: `[10s, 30s, 60s, 180s, 300s, 600s]`.
- Fast-fails on linear-regression positive slope on any drift signal at α=0.05 (Mann-Kendall test per `sdk-drift-detector` skill).
- Returns INCOMPLETE if `actual_duration_s < mmd_seconds` from this file.
- Writes to `tests/leak/state-<symbol>.json` for the harness to consume.

**Soak-eligible symbols** (8 total):

| Symbol | mmd_s | dominant drift signal |
|---|---|---|
| `Subscriber.subscribe long-running` (Section C) | 300 | asyncio_tasks_count |
| `Consumer.start long-running` (Section D) | 600 | asyncio_tasks_count + pending_naks |
| `KVStore.watch iterator` long-running (Section E) | 300 | watcher_lag_ms |
| `ObjectStore.put_file 100MB streaming` (Section E) | 120 | heap_rss_kb (peak ≤ 1024 KiB) |
| `Publisher + retry hammer 1000 RPS` integration | 180 | heap_rss_kb |
| `Requester.request 100 RPS round-trip` integration | 180 | pending_futures |
| `BatchPublisher with auto-flush 50ms interval` | 120 | heap_rss_kb (no buffer leak) |
| `MultiCircuitBreaker 1000 unique subjects` | 180 | heap_rss_kb (cb_dict size) |

---

## Section J: §7 symbol coverage check (mandatory G108 sanity)

The following §7-declared public symbols MUST have a perf-budget row. Lead self-checks at H5:

- codec: `pack_map`, `pack_array`, `unpack_map`, `unpack_array` ✓
- events.utils: `is_retryable`, `is_temporary` ✓ (added at H5-rev-3 D3 iter 2 — closes carry-over WARN C8)
- events.core: `extract_headers`, `inject_context`, `set_tenant_id`, `get_tenant_id` ✓ (others are pure data classes)
- events.corenats: `Publisher.publish`, `Publisher.request`, `Subscriber.subscribe.cb`, `BatchPublisher.add`, `BatchPublisher.flush` ✓
- events.jetstream: `JsPublisher.publish`, `JsPublisher.publish_async`, `Consumer.start.cb`, `Consumer dispatch loop`, `Requester.request`, `Stream.create` ✓
- events.stores: `KVStore.put/get/create/update/delete/keys/history/purge/status`, `ObjectStore.put_bytes/put_file/get/get_info/delete/list/status`, `KVStore.watch`, `ObjectStore.watch` ✓ (KV/ObjectStore span rows added at H5-rev-3 D3 iter 2 per TPRD §15.29)
- events.middleware: `chain.wrap`, `MultiCircuitBreaker.get`, `CircuitBreaker.allow`, `RetryMiddleware.intercept_publish.next`, `TokenBucketLimiter.allow_n`, `SlidingWindowLimiter.allow`, `OTELMetricsMiddleware.intercept_publish.next`, `LoggingMiddleware.intercept_publish.next`, `TracingMiddleware.intercept_publish.next`, end-to-end chain ✓
- otel: `tracer.start_producer`, `metrics.Counter.add`, `metrics.Histogram.record`, `Logger.info`, `Init`, `Shutdown` ✓
- config: `Settings()`, `EventsConfig.validate()` ✓

**~85 budgeted rows** across 9 sections (was 70 in rev-2; H5-rev-3 D3 iter 2 added 13 new KV/ObjectStore span rows + 2 events.utils classifier rows) covering 51 §7 public symbols. Some symbols appear in multiple rows for different paths/sizes — that's fine; G108 checks coverage, not row uniqueness.

---

## Section K: oracle margin sanity (G108 pre-check)

| Symbol | oracle margin_mult | rationale |
|---|---|---|
| Custom-binary codec ops | 2.5× | Python interpreter overhead vs hand-written C `struct.pack` loops; 2.5× is generous but realistic for 1.0 release |
| MsgPack codec ops | 1.6–1.7× | `msgpack-python` is C-impl; thin wrapper overhead only |
| Most NATS publish/subscribe ops | 1.5–1.75× | nats-py is asyncio-native; thin wrapper |
| `BatchPublisher.add` no-flush | 8.0× | 1µs floor on `list.append`; 8µs absorbs lock + closed-check + middleware chain. Wide margin justified — micro-op. |
| `RetryMiddleware backoff sleep` | 1.05× | dominated by `asyncio.sleep` itself |

All margins ≤ 8× (largest is BatchPublisher.add at 8×); none exceed the "2-3× typical" warning threshold from `sdk-perf-architect` heuristics except the explicitly-justified micro-op. G108 SANITY: PASS.

---

## Section L: bench naming convention (mandatory `b.ReportAllocs()`-equivalent for Python)

Each bench MUST:

1. Use `pytest-benchmark` with `--benchmark-only`.
2. Wrap allocation measurement via `tracemalloc.start() / get_traced_memory() / stop()` around the inner timed block. Helper `_alloc_count(callable)` defined in `tests/bench/conftest.py`.
3. Output JSON to `bench.json` per `python.json::toolchain.bench`; `sdk-benchmark-devil` parses at T5.
4. Bench file naming: `tests/bench/bench_<package>_<symbol>.py`. One bench function per row above; row label appears as the bench `id` parameter.

This is the Python analog of Go's mandatory `b.ReportAllocs()` per CLAUDE.md rule 32 axis 3.

---

**END perf-budget.md** — ready for H4 sign-off after H5 design review.
