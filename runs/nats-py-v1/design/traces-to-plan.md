# traces-to Plan (D1) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead`.
**Purpose**: pre-allocate the `[traces-to: TPRD-<section>-<id>]` mapping for impl per CLAUDE.md rule 29 + G99. This file is the contract; impl-lead applies the markers verbatim per slice.

## Marker syntax (per `python.json::marker_comment_syntax`)

- Line comment: `# [traces-to: TPRD-§<sec>-<id>]`
- Block (docstring): `[traces-to: TPRD-§<sec>-<id>]` on its own line inside the triple-quoted docstring.
- `sdk-marker-scanner` reads BOTH forms (line comment AND docstring) per the `marker_comment_syntax` declaration.

## Mapping convention

`<id>` is one of:
- The exact symbol name (`Publisher`, `extract_headers`, `pack_map`).
- The conformance-check number when the marker is on a TEST (`check-118`).
- A short descriptor when the symbol is conceptual (`Header-Byte`, `Sentinel-Inventory`).

## Per-package marker plan

### codec (`motadata_py_sdk/codec/`)

| File | Symbol | Marker |
|---|---|---|
| `_encoder.py` | class `Encoder` | `[traces-to: TPRD-§4.3-Header-Byte]` |
| `_encoder.py` | class `DataType` | `[traces-to: TPRD-§4.3.1-DataType-Tags]` |
| `_facade.py` | def `pack_map` | `[traces-to: TPRD-§4.3.1-pack-map]` |
| `_facade.py` | def `pack_array` | `[traces-to: TPRD-§4.3.1-pack-array]` |
| `_facade.py` | def `unpack_map` | `[traces-to: TPRD-§4.3.1-unpack-map]` |
| `_facade.py` | def `unpack_array` | `[traces-to: TPRD-§4.3.1-unpack-array]` |
| `_custom.py` | def `_encode_value` | `[traces-to: TPRD-§4.3.1-getDataTypeINT64]` |
| `_msgpack.py` | def `_pack_msgpack` | `[traces-to: TPRD-§4.3.2-MsgPack]` |
| `_errors.py` | class `ErrUnpackFailed` | `[traces-to: TPRD-§4.3.3-ErrUnpackFailed]` |
| `_errors.py` | (4 more codec sentinels) | `[traces-to: TPRD-§4.3.3-Err<Name>]` each |

### events.utils (`motadata_py_sdk/events/utils/`)

| File | Symbol | Marker |
|---|---|---|
| `_const.py` | `WildcardSingle` etc. | `[traces-to: TPRD-§4.4]` (one per file is sufficient given they're all const) |
| `_errors.py` | each of 33 sentinels | `[traces-to: TPRD-§4.6-Err<Name>]` |
| `_errors.py` | `Error` / `TenantError` / `SerializationError` / `ConfigError` / `ValidationError` / `MultiError` | `[traces-to: TPRD-§4.6-<Wrapper>]` |
| `_classifiers.py` | def `is_retryable` | `[traces-to: TPRD-§4.6-is-retryable]` |
| `_classifiers.py` | def `is_temporary` | `[traces-to: TPRD-§4.6-is-temporary]` |

### events.core (`motadata_py_sdk/events/core/`)

| File | Symbol | Marker |
|---|---|---|
| `_headers.py` | each of 15 HEADER_* | `[traces-to: TPRD-§4.1-<HEADER_NAME>]` |
| `_types.py` | class `TraceContext` | `[traces-to: TPRD-§5.1-TraceContext]` |
| `_types.py` | class `Metadata` | `[traces-to: TPRD-§5.1-Metadata]` |
| `_context.py` | each set/get pair (12 total) | `[traces-to: TPRD-§5.1-<Setter>]` |
| `_interfaces.py` | Publisher/Subscriber/Subscription/MessageHandler protocols | `[traces-to: TPRD-§5.2-<Protocol>]` |
| `_extract_inject.py` | def `extract_headers` | `[traces-to: TPRD-§4.2-extract-headers]` |
| `_extract_inject.py` | def `inject_context` | `[traces-to: TPRD-§4.2-inject-context]` |
| `_extract_inject.py` | def `extract_otel_trace_context` | `[traces-to: TPRD-§5.1-ExtractOTELTraceContext]` |

### events.corenats (`motadata_py_sdk/events/corenats/`)

| File | Symbol | Marker |
|---|---|---|
| `_const.py` | constants | `[traces-to: TPRD-§6.1]` |
| `_publisher.py` | class `Publisher` | `[traces-to: TPRD-§6.2-Publisher]` |
| `_publisher.py` | def `Publisher.publish` | `[traces-to: TPRD-§6.2-publish]` |
| `_publisher.py` | def `Publisher.request` | `[traces-to: TPRD-§6.2-request]` |
| `_publisher.py` | def `Publisher.close` | `[traces-to: TPRD-§6.2-close]` |
| `_batch_publisher.py` | class `BatchPublisher` | `[traces-to: TPRD-§6.3-BatchPublisher]` |
| `_batch_publisher.py` | def `BatchPublisher.add` | `[traces-to: TPRD-§6.3-add]` |
| `_batch_publisher.py` | def `BatchPublisher.add_multiple` | `[traces-to: TPRD-§6.3-add-multiple]` |
| `_batch_publisher.py` | def `BatchPublisher.flush` | `[traces-to: TPRD-§6.3-flush]` |
| `_batch_publisher.py` | def `BatchPublisher.close` | `[traces-to: TPRD-§6.3-close]` |
| `_subscriber.py` | class `Subscriber` | `[traces-to: TPRD-§6.4-Subscriber]` |
| `_subscriber.py` | def `Subscriber.subscribe` | `[traces-to: TPRD-§6.4-subscribe]` |
| `_subscriber.py` | def `Subscriber.queue_subscribe` | `[traces-to: TPRD-§6.4-queue-subscribe]` |
| `_subscriber.py` | def `Subscriber.unsubscribe` | `[traces-to: TPRD-§6.4-unsubscribe]` |
| `_subscriber.py` | def `Subscriber.close` | `[traces-to: TPRD-§6.4-close]` |

### events.jetstream (`motadata_py_sdk/events/jetstream/`)

| File | Symbol | Marker |
|---|---|---|
| `_stream.py` | class `StreamConfig` | `[traces-to: TPRD-§7.1-StreamConfig]` |
| `_stream.py` | class `Stream` | `[traces-to: TPRD-§7.1-Stream]` |
| `_stream.py` | each free factory | `[traces-to: TPRD-§7.1-<factory_name>]` |
| `_publisher.py` | class `JsPublisher` | `[traces-to: TPRD-§7.2-Publisher]` |
| `_publisher.py` | def `JsPublisher.publish` | `[traces-to: TPRD-§7.2-publish]` |
| `_publisher.py` | def `JsPublisher.publish_async` | `[traces-to: TPRD-§7.2-publish-async]` |
| `_publisher.py` | class `PubAck` | `[traces-to: TPRD-§7.2-PubAck]` |
| `_consumer.py` | class `Consumer` | `[traces-to: TPRD-§7.3-Consumer]` |
| `_consumer.py` | def `Consumer.start` | `[traces-to: TPRD-§7.3-start]` |
| `_consumer.py` | class `ConsumerConfig` | `[traces-to: TPRD-§7.3-ConsumerConfig]` |
| `_consumer.py` | class `TenantConsumerConfig` | `[traces-to: TPRD-§7.3-TenantConsumerConfig]` |
| `_consumer.py` | def `consumer_name` | `[traces-to: TPRD-§7.3-consumer-name]` |
| `_consumer.py` | each factory | `[traces-to: TPRD-§7.3-<factory>]` |
| `_requester.py` | class `RequesterConfig` | `[traces-to: TPRD-§7.4-RequesterConfig]` |
| `_requester.py` | class `Requester` | `[traces-to: TPRD-§7.4-Requester]` |
| `_requester.py` | def `Requester.create` | `[traces-to: TPRD-§7.4-create]` |
| `_requester.py` | def `Requester.request` | `[traces-to: TPRD-§7.4-request]` |
| `_requester.py` | def `Requester.close` | `[traces-to: TPRD-§7.4-close]` |
| `_requester.py` | class `Response` | `[traces-to: TPRD-§7.4-Response]` |

### events.stores (`motadata_py_sdk/events/stores/`)

| File | Symbol | Marker |
|---|---|---|
| `_kv.py` | class `KVStore` | `[traces-to: TPRD-§8.1-KVStore]` |
| `_kv.py` | each method (get/put/create/update/delete/keys/history/watch/purge/status) | `[traces-to: TPRD-§8.1-<method>]` |
| `_kv.py` | class `KeyValueConfig` | `[traces-to: TPRD-§8.1-KeyValueConfig]` |
| `_kv.py` | class `KeyValueEntry` | `[traces-to: TPRD-§8.1-KeyValueEntry]` |
| `_object.py` | class `ObjectStore` | `[traces-to: TPRD-§8.2-ObjectStore]` |
| `_object.py` | each method | `[traces-to: TPRD-§8.2-<method>]` |
| `_object.py` | class `ObjectStoreConfig` / `ObjectMeta` / `ObjectInfo` | `[traces-to: TPRD-§8.2-<class>]` |
| `_tenant.py` | class `TenantKVStore` | `[traces-to: TPRD-§8.3-TenantKVStore]` |
| `_tenant.py` | class `TenantObjectStore` | `[traces-to: TPRD-§8.3-TenantObjectStore]` |
| `_errors.py` | each of 7 sentinels | `[traces-to: TPRD-§8.<sec>-<Err>]` |

### events.middleware (`motadata_py_sdk/events/middleware/`)

| File | Symbol | Marker |
|---|---|---|
| `_stack.py` | class `Stack` / `Interceptor` / `chain` / `chain_subscribe` | `[traces-to: TPRD-§9.1-<sym>]` |
| `_circuit_breaker.py` | class `CircuitBreaker` / `MultiCircuitBreaker` / `CircuitBreakerConfig` / `State` | `[traces-to: TPRD-§9.2-<sym>]` |
| `_circuit_breaker.py` | class `ErrCircuitOpen` | `[traces-to: TPRD-§9.2-ErrCircuitOpen]` |
| `_circuit_breaker.py` | def `circuit_breaker_middleware` | `[traces-to: TPRD-§9.2-circuit-breaker-middleware]` |
| `_retry.py` | class `RetryMiddleware` / `RetryConfig` / `compute_backoff` | `[traces-to: TPRD-§9.3-<sym>]` |
| `_rate_limit.py` | each class + func | `[traces-to: TPRD-§9.4-<sym>]` |
| `_metrics.py` | each class | `[traces-to: TPRD-§9.5-<sym>]` |
| `_logging.py` | class `LoggingMiddleware` / `LogLevel` | `[traces-to: TPRD-§9.6-<sym>]` |
| `_tracing.py` | class `TracingMiddleware` | `[traces-to: TPRD-§9.7-TracingMiddleware]` |
| `_tracing.py` | def `extract_w3c_traceparent` / `format_w3c_traceparent` | `[traces-to: TPRD-§9.7-<func>]` |

### otel (`motadata_py_sdk/otel/`)

| File | Symbol | Marker |
|---|---|---|
| `_common.py` | class `ServiceInfo` | `[traces-to: TPRD-§10.1-ServiceInfo]` |
| `_common.py` | class `ShutdownCollector` | `[traces-to: TPRD-§10.8-ShutdownCollector]` |
| `_common.py` | class `ErrOTELUnsupportedProtocol` | `[traces-to: TPRD-§10.7-ErrOTELUnsupportedProtocol]` |
| `_common.py` | def `resolve_protocol` | `[traces-to: TPRD-§10.7-resolve-protocol]` |
| `tracer.py` | class `TracerInitConfig` / def `Init` / def `get_tracer` | `[traces-to: TPRD-§10-<sym>]` |
| `tracer.py` | def `start_producer` / `start_consumer` / `start_internal` | `[traces-to: TPRD-§10.4-<func>]` |
| `metrics.py` | class `MetricsInitConfig` / def `MetricsInit` / class `Registry` | `[traces-to: TPRD-§10-<sym>]` |
| `logger.py` | class `LoggerInitConfig` / def `LoggerInit` / def `L` | `[traces-to: TPRD-§10.6-<sym>]` |

### config (`motadata_py_sdk/config/`)

| File | Symbol | Marker |
|---|---|---|
| `_models.py` | each of 9 sub-models | `[traces-to: TPRD-§11.<sec>-<Model>]` |
| `_settings.py` | class `Settings` | `[traces-to: TPRD-§11.6-Settings]` |
| `_loader.py` | def `load` | `[traces-to: TPRD-§11.4-load]` |

### Test markers (in tests/unit/.../)

Each parametrized check 1-170 from TPRD §14 lives in a test row. The TEST FUNCTION is marked with `[traces-to: TPRD-§14-check-<N>]` so `sdk-marker-scanner` can build the conformance-coverage report at F2.

Example:
```python
# [traces-to: TPRD-§14-check-119]
@pytest.mark.parametrize("attempt,expected_lo,expected_hi", [
    (0, 0.090, 0.110),
    (1, 0.180, 0.220),
    (2, 0.360, 0.440),
])
def test_retry_backoff_default_schedule(attempt, expected_lo, expected_hi): ...
```

## Marker counts per package (G99 budget)

| Package | Symbols requiring markers | Approx file count |
|---|---|---|
| codec | 11 + 5 sentinels = 16 | 6 files |
| events.utils | 33 + 6 + 2 + ~6 const = 47 | 3 files |
| events.core | 15 + 5 + 12 + 3 = 35 | 5 files |
| events.corenats | 3 classes + 12 methods = 15 | 4 files |
| events.jetstream | 4 classes + ~25 methods/factories + 8 dataclasses = ~37 | 4 files |
| events.stores | 4 classes + 18 methods + 7 errors + 6 dataclasses = 35 | 4 files |
| events.middleware | 13 classes + 10 funcs + 7 errors/configs = 30 | 7 files |
| otel | 4 init configs + 4 init funcs + 5 helpers + 3 protos + 5 const = 21 | 4 files |
| config | 9 models + 1 BaseSettings + 1 loader = 11 | 4 files |
| **Total** | **~247 markers** | **41 files** |

Plus ~170 test markers (one per conformance check). Grand total ~420 markers.

**H5-rev-3 D3 iter 2 delta**: +0 net traces-to markers. The TPRD §15 FIX restorations
(A1-B4) augmented EXISTING symbol docstrings with additional `§15.<NN>` cross-references
(e.g., `[traces-to: TPRD-§8.1-put §15.29]`) — these are inline annotations that travel
with the existing primary `[traces-to:]`, so the marker count stays at ~247 source +
~170 test = ~417 total. Inline `§15.<NN>` cross-references are NOT counted as separate
markers by `sdk-marker-scanner` (G99 grep pattern matches one per symbol; the secondary
`§15.NN` token is informational metadata).

## What G99 enforces at run-end

`sdk-marker-scanner` walks every `.py` in `src/motadata_py_sdk/{codec,events/*,otel,config}/` and:

1. For every public symbol (no leading `_`), verify a `[traces-to:]` marker exists in the symbol's docstring OR adjacent line comment.
2. Public-symbol detection: top-level `class`/`def` + class methods that are not `_*` prefixed.
3. Failure mode: BLOCKER per G99.
4. Marker syntax check: `r"\[traces-to:\s*TPRD-§\d+(\.\d+)*-[A-Za-z0-9_-]+\s*\]"`.

This file is the AUTHORITATIVE list — any divergence at impl time is corrected in this file FIRST, then in the impl.
