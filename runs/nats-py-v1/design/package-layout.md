# Package Layout (D1) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead`.

Final on-disk layout for `motadata-py-sdk/src/motadata_py_sdk/`. Follows TPRD §12 with adjustments for Python idioms (e.g., `_internal.py` for private impls, `__init__.py` re-exports for public API).

```
motadata-py-sdk/
├── src/motadata_py_sdk/
│   ├── __init__.py                       (no changes — empty marker)
│   ├── resourcepool/                     (UNTOUCHED — Mode A baseline; rule 17)
│   │   └── ... (5 modules pre-existing)
│   │
│   ├── codec/                            (NEW — TPRD §4.3)
│   │   ├── __init__.py                   (re-exports: Encoder, DataType, pack_map,
│   │   │                                   pack_array, unpack_map, unpack_array,
│   │   │                                   ErrUnpackFailed, ErrUnsupportedCodec,
│   │   │                                   ErrUnsupportedDataType, ErrValueOutOfRange,
│   │   │                                   ErrDataTooLarge,
│   │   │                                   msgpack_unpack_safe, DEFAULT_MAX_MSG_BYTES,
│   │   │                                   DEFAULT_MAX_ARRAY_LEN, DEFAULT_MAX_MAP_LEN,
│   │   │                                   DEFAULT_MAX_STR_LEN, DEFAULT_MAX_BIN_LEN)
│   │   │                                   (D3 iter 1 / SEC-2 fix: msgpack_unpack_safe
│   │   │                                    is the single chokepoint for msgpack.unpackb;
│   │   │                                    DoS caps prevent attacker-controlled
│   │   │                                    length-prefix → pre-allocation OOM.
│   │   │                                    See algorithms.md §A16.)
│   │   ├── _encoder.py                   (Encoder/DataType enums; Final[str] tag table)
│   │   ├── _custom.py                    (custom binary pack_map/array, unpack_map/array)
│   │   ├── _msgpack.py                   (msgpack pack/unpack with default options;
│   │   │                                   defines msgpack_unpack_safe + DEFAULT_MAX_*)
│   │   ├── _facade.py                    (header-byte dispatch; defer-recover analog)
│   │   └── _errors.py                    (5 codec sentinels with byte-exact strings)
│   │
│   ├── events/
│   │   ├── __init__.py                   (no re-export — submodules are the public surface)
│   │   ├── utils/                        (NEW — TPRD §4.6)
│   │   │   ├── __init__.py               (re-exports all 36 sentinels +
│   │   │   │                               wrapper types + is_retryable, is_temporary +
│   │   │   │                               constants WildcardSingle/Multi/MaxTenantIDLength/...
│   │   │   │                               + ErrCircuitOpen + ErrRateLimitExceeded
│   │   │   │                               (re-exported here per CONV-12 fix D3 iter 3;
│   │   │   │                                middleware modules import them FROM utils))
│   │   │   │                               (D3 iter 1: 33→34 — added ErrNoMessages
│   │   │   │                                per DD-3.)
│   │   │   │                               (D3 iter 2 H5-rev-3: TPRD §15.32 restored;
│   │   │   │                                _TENANT_ID_REGEX kept PRIVATE; consumed
│   │   │   │                                by stores._tenant.TenantKVStore /
│   │   │   │                                TenantObjectStore via internal import.)
│   │   │   │                               (D3 iter 3 CONV-5 fix: 6 dataclass-validation
│   │   │   │                                regexes added (_STREAM/_CONSUMER/_SUBJECT/
│   │   │   │                                _BUCKET/_OBJECT_NAME_REGEX +
│   │   │   │                                _MAX_DESCRIPTION_LEN), all PRIVATE.)
│   │   │   │                               (D3 iter 3 CONV-12 fix: 34→36 — ErrCircuitOpen
│   │   │   │                                + ErrRateLimitExceeded RELOCATED here from
│   │   │   │                                events.middleware so _NEVER_RETRY is populated
│   │   │   │                                at definition time. Middleware now IMPORTS
│   │   │   │                                them. _NEVER_RETRY upgraded to Final[frozenset].)
│   │   │   ├── _const.py                 (WildcardSingle, MaxSubjectLength,
│   │   │   │                               MaxTenantIDLength, CONTENT_TYPE_*,
│   │   │   │                               _TENANT_ID_REGEX [private],
│   │   │   │                               _STREAM_NAME_REGEX, _CONSUMER_NAME_REGEX,
│   │   │   │                               _SUBJECT_REGEX, _BUCKET_NAME_REGEX,
│   │   │   │                               _OBJECT_NAME_REGEX, _MAX_DESCRIPTION_LEN
│   │   │   │                               [all private; CONV-5 fix D3 iter 3])
│   │   │   ├── _errors.py                (36 sentinels + 6 wrappers;
│   │   │   │                               ErrNoMessages new D3 iter 1;
│   │   │   │                               ErrCircuitOpen + ErrRateLimitExceeded
│   │   │   │                               relocated here D3 iter 3 per CONV-12 fix)
│   │   │   └── _classifiers.py           (is_retryable, is_temporary,
│   │   │                                   _NEVER_RETRY = Final[frozenset({
│   │   │                                     ErrCircuitOpen, ErrRateLimitExceeded
│   │   │                                   })] populated at definition time per CONV-12 fix)
│   │   │
│   │   ├── core/                         (NEW — TPRD §5 + §4.1, §4.2)
│   │   │   ├── __init__.py               (re-exports: 15 HEADER_* + TraceContext, Metadata
│   │   │   │                               + 6 contextvars set/get pairs +
│   │   │   │                               extract_otel_trace_context +
│   │   │   │                               extract_headers, inject_context +
│   │   │   │                               Publisher, Subscriber, Subscription,
│   │   │   │                               MessageHandler protocols)
│   │   │   ├── _headers.py               (15 Final[str] header constants)
│   │   │   ├── _types.py                 (TraceContext, Metadata dataclasses)
│   │   │   ├── _context.py               (6 ContextVar + 12 set/get helpers)
│   │   │   ├── _interfaces.py            (Publisher/Subscriber/Subscription/MessageHandler protocols)
│   │   │   └── _extract_inject.py        (extract_headers, inject_context, extract_otel_trace_context)
│   │   │
│   │   ├── corenats/                     (NEW — TPRD §6)
│   │   │   ├── __init__.py               (re-exports: Publisher, BatchPublisher, Subscriber,
│   │   │   │                               DEFAULT_REQUEST_TIMEOUT, DEFAULT_FLUSH_TIMEOUT,
│   │   │   │                               DEFAULT_MAX_CONCURRENT_FLUSH,
│   │   │   │                               PublishMiddleware, SubscribeMiddleware,
│   │   │   │                               PublishHandler, SubscribeHandler types)
│   │   │   ├── _const.py
│   │   │   ├── _publisher.py
│   │   │   ├── _batch_publisher.py
│   │   │   └── _subscriber.py            (includes _Subscription internal impl)
│   │   │
│   │   ├── jetstream/                    (NEW — TPRD §7)
│   │   │   ├── __init__.py               (re-exports: StreamConfig, Stream, create_stream,
│   │   │   │                               create_or_update_stream, get_stream, delete_stream,
│   │   │   │                               list_streams, JsPublisher (aliased Publisher), PubAck,
│   │   │   │                               ConsumerConfig, TenantConsumerConfig, Consumer,
│   │   │   │                               JsMsg, MessageBatch, JsMessageHandler,
│   │   │   │                               create_consumer, create_tenant_consumer,
│   │   │   │                               get_consumer, delete_consumer, list_consumers,
│   │   │   │                               consumer_name, RequesterConfig, RequesterConfigError,
│   │   │   │                               Requester, Response, Retention, StorageType, DeliverPolicy)
│   │   │   ├── _stream.py                (StreamConfig, Stream, create/update/delete/get/list)
│   │   │   ├── _publisher.py             (JsPublisher with publish + publish_async)
│   │   │   ├── _consumer.py              (Consumer, ConsumerConfig, TenantConsumerConfig, factories)
│   │   │   └── _requester.py             (Requester, RequesterConfig, Response, build_response)
│   │   │
│   │   ├── stores/                       (NEW — TPRD §8)
│   │   │   ├── __init__.py               (re-exports: KVStore, KeyValueConfig, KeyValueEntry,
│   │   │   │                               new_kv_store, get_kv_store, delete_kv_store,
│   │   │   │                               ObjectStore, ObjectStoreConfig, ObjectMeta, ObjectInfo,
│   │   │   │                               ObjectResult, new_object_store, get_object_store,
│   │   │   │                               delete_object_store, ErrKeyNotFound, ErrKeyExists,
│   │   │   │                               ErrInvalidKey, ErrHistoryToLarge, ErrObjectNotFound,
│   │   │   │                               ErrBadObjectMeta, ErrDigestMismatch,
│   │   │   │                               TenantKVStore, TenantObjectStore)
│   │   │   ├── _kv.py                    (KVStore + factories)
│   │   │   ├── _object.py                (ObjectStore + factories)
│   │   │   ├── _tenant.py                (TenantKVStore, TenantObjectStore overlays)
│   │   │   └── _errors.py                (7 stores-specific sentinels)
│   │   │
│   │   └── middleware/                   (NEW — TPRD §9)
│   │       ├── __init__.py               (re-exports: Stack, Interceptor, chain, chain_subscribe,
│   │       │                               PublishMiddleware, SubscribeMiddleware,
│   │       │                               CircuitBreaker, MultiCircuitBreaker, CircuitBreakerConfig,
│   │       │                               State, ErrCircuitOpen (RE-EXPORT from events.utils
│   │       │                                                       per CONV-12 fix D3 iter 3),
│   │       │                               circuit_breaker_middleware,
│   │       │                               RetryMiddleware, RetryConfig, compute_backoff,
│   │       │                               TokenBucketLimiter, SlidingWindowLimiter,
│   │       │                               PerSubjectRateLimiter, RateLimiterConfig,
│   │       │                               ErrRateLimitExceeded (RE-EXPORT from events.utils
│   │       │                                                      per CONV-12 fix D3 iter 3),
│   │       │                               rate_limit_middleware,
│   │       │                               rate_limit_wait_middleware,
│   │       │                               MetricsCollector, OTELMetricsMiddleware,
│   │       │                               PerSubjectMetrics, Metrics,
│   │       │                               LoggingMiddleware, LogLevel,
│   │       │                               TracingMiddleware, extract_w3c_traceparent,
│   │       │                               format_w3c_traceparent)
│   │       │                              (CONV-12 fix D3 iter 3: NO MORE __init__-time
│   │       │                               mutation of events.utils._NEVER_RETRY. The
│   │       │                               previous _register_never_retry callback /
│   │       │                               _utils._NEVER_RETRY = ... rebind is REMOVED.
│   │       │                               Sentinel ownership lives in events.utils now;
│   │       │                               re-exports here are pure aliases for caller
│   │       │                               convenience.)
│   │       ├── _stack.py                 (Stack + chain + chain_subscribe + Interceptor protocol)
│   │       ├── _circuit_breaker.py       (CircuitBreaker, MultiCircuitBreaker, CircuitBreakerConfig, State;
│   │       │                               IMPORTS ErrCircuitOpen from events.utils per CONV-12 fix
│   │       │                               D3 iter 3 — does NOT define it)
│   │       ├── _retry.py                 (RetryMiddleware, RetryConfig, compute_backoff)
│   │       ├── _rate_limit.py            (TokenBucketLimiter, SlidingWindowLimiter,
│   │       │                               PerSubjectRateLimiter, both wrappers;
│   │       │                               IMPORTS ErrRateLimitExceeded from events.utils
│   │       │                               per CONV-12 fix D3 iter 3 — does NOT define it)
│   │       ├── _metrics.py               (MetricsCollector, OTELMetricsMiddleware, PerSubjectMetrics)
│   │       ├── _logging.py               (LoggingMiddleware, LogLevel)
│   │       └── _tracing.py               (TracingMiddleware, W3C helpers)
│   │
│   ├── otel/                             (NEW — TPRD §10)
│   │   ├── __init__.py                   (re-exports: ServiceInfo, ShutdownCollector,
│   │   │                                   ErrOTELUnsupportedProtocol, resolve_protocol,
│   │   │                                   tracer module's: TracerInitConfig, init_tracer,
│   │   │                                   get_tracer, start_producer, start_consumer,
│   │   │                                   start_internal,
│   │   │                                   metrics module's: MetricsInitConfig, init_metrics,
│   │   │                                   Registry,
│   │   │                                   logger module's: LoggerInitConfig, init_logger,
│   │   │                                   get_logger,
│   │   │                                   constants OTEL_DEFAULT_*)
│   │   │                                   (D3 iter 1 / CONV-1+SEMVER-1+DD-4+DD-5 fix:
│   │   │                                    Init→init_tracer, MetricsInit→init_metrics,
│   │   │                                    LoggerInit→init_logger, L→get_logger;
│   │   │                                    PEP 8 snake_case for module-level functions)
│   │   ├── _common.py                    (ServiceInfo, ShutdownCollector,
│   │   │                                   ErrOTELUnsupportedProtocol, resolve_protocol)
│   │   ├── tracer.py                     (TracerInitConfig, init_tracer, get_tracer, start_*)
│   │   ├── metrics.py                    (MetricsInitConfig, init_metrics, Registry)
│   │   └── logger.py                     (LoggerInitConfig, init_logger, get_logger)
│   │
│   └── config/                           (NEW — TPRD §11)
│       ├── __init__.py                   (re-exports: Settings, load,
│       │                                   ServiceConfig, TracerConfig, ReconnectConfig,
│       │                                   TLSConfig, StreamSubConfig, EventsConfig,
│       │                                   LoggerConfig, MetricsConfig,
│       │                                   PublishConfig, SubscribeConfig)
│       │                                   (CONV-3 fix at H5-rev-3 D3 iter 2:
│       │                                    leading underscore dropped on all 9
│       │                                    pydantic sub-models — they were always
│       │                                    public re-exports, the underscore
│       │                                    contradicted their public role.)
│       ├── _models.py                    (10 sub-models per §11; class names now
│       │                                   public — no leading underscore)
│       ├── _settings.py                  (Settings BaseSettings)
│       ├── _loader.py                    (YAML + env precedence loader)
│       └── _env_source.py                (custom EnvSettingsSource for inverted aliases)
│
├── tests/
│   ├── unit/                             (~110 conformance checks per TPRD §13)
│   │   ├── codec/test_byte_fixtures.py   (checks 13-17, 25, 26)
│   │   ├── codec/test_round_trip.py      (check 12)
│   │   ├── codec/test_errors.py          (checks 18-24)
│   │   ├── events/utils/test_sentinels.py (checks 27-33)
│   │   ├── events/core/test_headers.py   (check 1)
│   │   ├── events/core/test_extract_inject.py (checks 2-11)
│   │   ├── events/corenats/test_publisher.py (checks 11-19)
│   │   ├── events/corenats/test_batch.py (checks 20-27)
│   │   ├── events/corenats/test_subscriber.py (checks 28-37)
│   │   ├── events/jetstream/test_stream.py (checks 38-48)
│   │   ├── events/jetstream/test_publisher.py (checks 49-63)
│   │   ├── events/jetstream/test_consumer.py (checks 64-79)
│   │   ├── events/jetstream/test_requester.py (checks 80-96)
│   │   ├── events/stores/test_kv.py      (checks 97-104)
│   │   ├── events/stores/test_object.py  (checks 105-107)
│   │   ├── events/middleware/test_chain.py (checks 108-110)
│   │   ├── events/middleware/test_cb.py  (checks 111-117)
│   │   ├── events/middleware/test_retry.py (checks 118-124)
│   │   ├── events/middleware/test_rate_limit.py (checks 125-130)
│   │   ├── events/middleware/test_metrics.py (checks 131-135)
│   │   ├── events/middleware/test_logging.py (checks 136-141)
│   │   ├── events/middleware/test_tracing.py (checks 142-150)
│   │   ├── events/middleware/test_composition.py (checks 151-155)
│   │   ├── otel/test_inventory.py        (checks 156-164)
│   │   ├── config/test_validation.py     (checks 165-167, 170)
│   │   └── config/test_precedence.py     (checks 168-169)
│   │
│   ├── integration/                      (~40 testcontainers/nats checks)
│   │   ├── conftest.py                   (testcontainers nats-server fixture)
│   │   ├── test_corenats_e2e.py
│   │   ├── test_jetstream_e2e.py
│   │   ├── test_stores_e2e.py
│   │   └── test_middleware_e2e.py
│   │
│   ├── bench/                            (perf-budget.md row → bench)
│   │   ├── conftest.py                   (_alloc_count helper, fixture for nats container)
│   │   ├── bench_codec_*.py              (Section A rows)
│   │   ├── bench_corenats_*.py           (Section C rows)
│   │   ├── bench_jetstream_*.py          (Section D rows)
│   │   ├── bench_stores_*.py             (Section E rows)
│   │   ├── bench_middleware_*.py         (Section F rows)
│   │   ├── bench_otel_*.py               (Section G rows)
│   │   └── bench_config_*.py             (Section H rows)
│   │
│   ├── leak/                             (asyncio task leak; pytest-asyncio --asyncio-mode=auto)
│   │   ├── test_subscriber_leak.py
│   │   ├── test_consumer_leak.py
│   │   ├── test_requester_leak.py
│   │   ├── test_batch_publisher_leak.py
│   │   └── test_soak_*.py                (8 soak harnesses per perf-budget.md §I)
│   │
│   └── fixtures/                         (cross-language byte-fixtures)
│       ├── codec/                        (Go-emitted .bin files for §14.2 checks 13-17, 25, 26)
│       └── README.md                     (how to regenerate; CI job spec)
│
├── pyproject.toml                        (UPDATE — extend dependencies + tool sections)
└── README.md                             (NO PIPELINE WRITES — caller-owned)
```

## Module dependency graph (one-way; enforced by import-linter at G122)

```
codec ─────────────────────────────────────────────┐
                                                   │
events.utils ──────────────────────────────────────┤
                                                   ▼
                                              events.core
                                                   │
                              ┌────────────────────┼─────────────┐
                              ▼                    ▼             ▼
                       events.corenats     events.jetstream  events.stores
                              │                    │             │
                              └────────────┬───────┘             │
                                           ▼                     │
                                    events.middleware            │
                                           │                     │
                                           ▼                     │
                                          otel ◄─────────────────┘
                                           │
                                           ▼
                                         config
```

- **No back-edges**. `events.core` MUST NOT import `events.corenats` etc.
- `otel` is leaf-most (no deps in `events/`); `events.middleware.tracing` depends on `otel`.
- `config` depends on `otel.common.ServiceInfo` only; not on any `events.*`.
- `codec` is fully independent (no events dep).
- import-linter rule (`pyproject.toml::tool.importlinter.contracts`) enforces; G122 (mypy) backs it via type checks on layered imports.

## Public-API summary (§7 surface count)

| Module | Symbols re-exported | Notes |
|---|---|---|
| codec | 11 | 4 funcs + 2 enums + 5 errors |
| events.utils | 47 | 33 sentinels + 6 wrappers + 2 helpers + 6 constants |
| events.core | 28 | 15 headers + 5 types/protocols + 12 helpers + 3 funcs |
| events.corenats | 12 | 3 classes + 4 constants + 5 type aliases |
| events.jetstream | 32 | 4 classes + 3 enums + 12 factories + 13 dataclasses |
| events.stores | 24 | 4 classes + 4 dataclasses + 7 errors + 6 factories + 3 misc |
| events.middleware | 38 | 13 classes + 6 funcs + 7 errors/configs + 12 misc |
| otel | 21 | 4 init configs + 4 init funcs + 4 helpers + 4 protos + 5 constants |
| config | 11 | 1 BaseSettings + 9 BaseModel + 1 loader |

**Total**: ~224 public symbols. Each carries `[traces-to: TPRD-§<sec>-<id>]` per G99.

## File count

- 38 source files in `src/motadata_py_sdk/{codec,events/*,otel,config}/`
- ~30 test files in `tests/{unit,integration,bench,leak}/`

## Markers per package (G99 budget)

Each non-trivial public symbol gets at minimum `[traces-to: ...]`. Hot paths additionally get `[constraint: ...]`. Total expected markers: ~240 (224 traces-to + 30+ constraint pairs as per perf-budget.md §J coverage).
