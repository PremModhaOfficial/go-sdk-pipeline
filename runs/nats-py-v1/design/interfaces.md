# Interfaces (D1) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead` (acting in `interface-designer` role).
**Skill consulted**: `python-class-design`.

## Why Protocol over ABC

All interfaces in `events.core` use `typing.Protocol` (structural typing) rather than `abc.ABC` (nominal). Reasons:

1. **Caller flexibility** — testing fakes don't need to inherit; any class with the matching shape passes mypy.
2. **No diamond hazard** — concrete classes never need multiple-inheritance to satisfy multiple Protocols.
3. **Compile-time check** — mypy `strict` enforces protocol conformance at every assignment site (Python equivalent of Go's `var _ Interface = (*Impl)(nil)` check).
4. **Aligns with `python-class-design` skill** which prescribes Protocols for SDK contracts.

## Compile-time interface assertions (Python analog of Go's `var _ I = (*T)(nil)`)

At the bottom of every concrete impl module, add:

```python
# Compile-time check: corenats.Publisher implements core.Publisher Protocol.
def _check_publisher_protocol() -> Publisher:
    return Publisher(nc=None, max_payload=0)  # type: ignore[arg-type]

if False:  # pragma: no cover  -- never executed; only checked by mypy
    from motadata_py_sdk.events import core
    _: core.Publisher = _check_publisher_protocol()
```

mypy `strict` will flag a missing/mismatched method at lint time per G122.

## Public Protocol surface (re-stated for canonical reference)

### `Publisher` (events.core)

```python
class Publisher(Protocol):
    async def publish(self, subject: str, msg: NatsMsg) -> None: ...
    async def request(self, subject: str, msg: NatsMsg) -> NatsMsg: ...
    async def close(self) -> None: ...
```

Implemented by:
- `motadata_py_sdk.events.corenats.Publisher` (concrete; plain NATS)
- `motadata_py_sdk.events.jetstream.JsPublisher` (concrete; JetStream)
- Test fakes in `tests/unit/events/*/fakes.py` (mocks)

NOTE: `JsPublisher.publish` returns `PubAck`, NOT `None`. So `JsPublisher` does NOT structurally satisfy `Publisher` Protocol on the publish() return type. This is INTENTIONAL — the two are siblings, not subtypes. A separate Protocol could be carved (`JsPublisher(Protocol)`) if a unified handle is ever needed, but design opts for SEPARATE protocols since the use sites differ.

### `Subscriber` (events.core)

```python
class Subscriber(Protocol):
    async def subscribe(self, subject: str, handler: MessageHandler) -> Subscription: ...
    async def queue_subscribe(self, subject: str, queue: str, handler: MessageHandler) -> Subscription: ...
    async def close(self) -> None: ...
```

Implemented by:
- `motadata_py_sdk.events.corenats.Subscriber` (only concrete impl)
- Test fakes

#### Concrete `Subscriber` constructor signature (additive `on_error` hook — DD-1 fix, D3 iter 1)

The concrete `corenats.Subscriber` constructor exposes an additive optional
`on_error` callback parameter:

```python
class Subscriber:
    def __init__(
        self,
        nc: Any,
        *,
        on_error: Callable[[BaseException], Awaitable[None]] | None = None,
    ) -> None: ...

    def set_error_handler(
        self,
        cb: Callable[[BaseException], Awaitable[None]] | None,
    ) -> None: ...
```

- `on_error=None` (default) preserves Go SDK behavior: `close()` and
  dispatch paths log + return `None`; errors NEVER propagate to the caller.
- Setting the hook (at construction or via `set_error_handler`) opts in to
  error surfacing without changing the public Protocol method signatures.
- The hook MUST NOT raise — if it does, the exception is swallowed via
  `log.exception` to avoid recursion in the close/dispatch path.

The Protocol definition in `events.core` (above) does NOT include
`on_error` — it is a concrete-impl convenience. Test fakes implementing
the `Subscriber(Protocol)` need not expose it.

#### Concrete `Consumer` constructor signature (additive `on_error` hook — DD-1 fix, D3 iter 1)

`events.jetstream.Consumer` mirrors the Subscriber additive-hook pattern:

```python
class Consumer:
    def __init__(
        self,
        *,
        on_error: Callable[[BaseException], Awaitable[None]] | None = None,
    ) -> None: ...

    def set_error_handler(
        self,
        cb: Callable[[BaseException], Awaitable[None]] | None,
    ) -> None: ...
```

- Default `on_error=None` preserves Go behavior (silent WARN log on
  ack/nak/handler failure; errors NEVER propagate).
- Same hook contract: must not raise; if it does, `log.exception` swallows.
- Concrete construction is via `await create_consumer(js, cfg)` etc.; the
  factory threads the hook through (or callers use `set_error_handler`
  post-construction).

### `Subscription` (events.core)

```python
class Subscription(Protocol):
    def subject(self) -> str: ...
    async def unsubscribe(self) -> None: ...
    async def drain(self) -> None: ...
    def is_valid(self) -> bool: ...
```

Implemented by:
- `motadata_py_sdk.events.corenats._Subscription` (private impl returned from `subscribe`)
- Test fakes

### `MessageHandler` / `JsMessageHandler` (events.core / events.jetstream)

```python
MessageHandler = Callable[[Context, NatsMsg], Awaitable[None]]
JsMessageHandler = Callable[[Context, JsMsg], Awaitable[None]]
```

Type aliases (NOT Protocols). Caller passes any matching async callable.

### `NatsMsg` / `JsMsg` (events.core / events.jetstream)

```python
class NatsMsg(Protocol):
    subject: str
    data: bytes
    headers: dict[str, str] | None
    reply: str

class JsMsg(NatsMsg, Protocol):
    metadata: Any
    async def ack(self) -> None: ...
    async def nak(self, delay: float | None = None) -> None: ...
    async def term(self) -> None: ...
    async def in_progress(self) -> None: ...
```

Bound to `nats.aio.msg.Msg` and `nats.aio.msg.Msg` (with the JS metadata extension) at runtime. Defining a Protocol decouples our code from nats-py imports for typing.

### `Interceptor` (events.middleware)

```python
class Interceptor(Protocol):
    def intercept_publish(self) -> PublishMiddleware: ...
    def intercept_subscribe(self) -> SubscribeMiddleware: ...
```

Implemented by every middleware class:
- `RetryMiddleware` (subscribe is pass-through per §9.3)
- `MetricsCollector`, `OTELMetricsMiddleware`, `PerSubjectMetrics`
- `LoggingMiddleware`
- `TracingMiddleware`

`circuit_breaker_middleware()` and `rate_limit_middleware()` are FREE FUNCTIONS that return a `PublishMiddleware` directly (not class-based), since they are stateless wrappers around config. They DO NOT implement `Interceptor` (no subscribe equivalent).

### `Context` (events.core)

```python
class Context(Protocol): ...  # opaque
```

Concrete representation = whatever the caller is using (typically just the implicit asyncio context + contextvars). This Protocol is a TYPING MARKER ONLY — it has no methods. We pass `Context` as a type hint to make signatures self-documenting; impl reads contextvars directly.

## DataClass shape rules (per `python-class-design` skill)

| Class | Frozen? | Slots? | Reason |
|---|---|---|---|
| `TraceContext` | yes | yes | Wire-shape; immutable; small |
| `Metadata` | no | yes | Mutable accumulator; `custom` dict mutated |
| `PubAck` | yes | yes | Wire-result; immutable |
| `Response` | no | n/a | Has computed `ok()`; mutable for ergonomics |
| `KeyValueEntry` | yes | yes | Server-returned snapshot |
| `ObjectInfo` | yes | yes | Server-returned snapshot |
| `MessageBatch` | yes | yes | Pull-fetch result |
| `StreamConfig` | no | n/a | Builder-style; caller mutates field-by-field then passes once. `__post_init__` validation per CONV-5 fix (D3 iter 3) — name/subjects regex + non-negative numeric knobs + replicas ∈ {1,3,5} + description length cap. Raises `ValidationError`. |
| `ConsumerConfig` | no | n/a | Same; `__post_init__` per CONV-5 — stream/name regex, filter-subjects regex, ack_wait/max_ack_pending non-negative, max_deliver ≥ -1, description cap. Raises `ValidationError`. |
| `TenantConsumerConfig` | no | n/a | Same; `__post_init__` per CONV-5 — inherits ConsumerConfig field rules + `tenant_id` validated via `_TENANT_ID_REGEX` and `MaxTenantIDLength` (single source of truth shared with TenantKVStore / TenantObjectStore per TPRD §15.32). Raises `ValidationError`. |
| `RequesterConfig` | no | n/a | Same; `__post_init__` per CONV-5 — reply_stream / reply_subject_prefix / instance_id regex, request_timeout ∈ (0, 300], inactive_threshold > 0. Raises `ValidationError`. |
| `KeyValueConfig` | no | n/a | Same; `__post_init__` per CONV-5 — bucket regex, history ∈ [1, 64], non-negative ttl/max_bytes, max_value_size ≥ -1, replicas ∈ {1,3,5}, description cap. Raises `ValidationError`. |
| `ObjectStoreConfig` | no | n/a | Same; `__post_init__` per CONV-5 — bucket regex, non-negative ttl/max_bytes, replicas ∈ {1,3,5}, description cap. Raises `ValidationError`. |
| `ObjectMeta` | no | n/a | Same; `__post_init__` per CONV-5 — object name regex (allows `/` `.` `_` `-`), description cap, chunk_size > 0. Raises `ValidationError`. |
| `CircuitBreakerConfig` | no | n/a | Same |
| `RetryConfig` | no | n/a | Same |
| `RateLimiterConfig` | no | n/a | Same |
| `Metrics` | no | yes | Counter aggregate |
| Pydantic config models | yes via Pydantic | n/a | Pydantic v2 freezes on `model_config = ConfigDict(frozen=True)` |
| `ServiceInfo` | yes | yes | Init-time snapshot |
| All `*Config` (TracerInitConfig, MetricsInitConfig, LoggerInitConfig) | yes | yes | Frozen+slots per CONV-2 fix (H5-rev-3 D3 iter 2); `__post_init__` validation per TPRD §15.31 |

## Equality + hash behavior

- Frozen+slots dataclasses: `eq=True` (default), `frozen=True` → hashable, usable as dict keys / set members.
- Mutable dataclasses (Configs): `eq=True` (default for value-equality), `frozen=False` → NOT hashable. Caller never uses configs as dict keys.
- All custom Exception sentinels: identity equality (default Python). `errors.Is(multi, sentinel)`-equivalent uses `isinstance(multi.errors[0], type(sentinel))` per the `MultiError.unwrap` semantics.

## Constructor pattern decision (`Config struct + new_client(config)` vs functional options)

Per `python-class-design` skill rule + TPRD §11 + CLAUDE.md project rule: **`Config struct + new_client(config)` is primary**.

Specifically:
- `Publisher(nc, max_payload)` — minimal positional args (mirrors Go `NewPublisher(nc, maxPayload)`).
- `Subscriber(nc)` — positional.
- `BatchPublisher(publisher, *, max_batch_size=0, flush_interval=0.0, ...)` — KEYWORD-ONLY for the optional knobs (Pythonic equivalent of Go's variadic functional options). 5 knobs, all KW.
- `Stream/Consumer/Requester` — config-struct-then-factory: `await create_stream(js, StreamConfig(name=..., subjects=...))`.
- `KVStore/ObjectStore` — same: `await new_kv_store(js, KeyValueConfig(bucket=..., ...))`.
- All middlewares — config-struct: `RetryMiddleware(RetryConfig(max_attempts=3))`.
- `Settings` (pydantic-settings) — env-driven; constructed via `Settings()` zero-arg call.

NO functional options anywhere. Reason: target SDK convention (resourcepool uses `PoolConfig`-then-`Pool(cfg)`); cross-SDK consistency.

## Inheritance hierarchies (sentinel exceptions)

```
Exception
├── EventsError (events.utils._errors.EventsError)
│   ├── ErrNotConnected           ── retryable
│   ├── ErrAlreadyConnected       ── retryable
│   ├── ErrConnectionTimeout      ── retryable, temporary
│   ├── ErrReconnectFailed        ── retryable, temporary
│   ├── ErrPublishFailed          ── retryable
│   │   ├── ErrCircuitOpen        ── (events.utils._errors; CONV-12 fix D3 iter 3)
│   │   │                            (NON-retryable; in _NEVER_RETRY at definition time)
│   │   │                            (RAISED BY events.middleware._circuit_breaker; IMPORTED there)
│   │   └── ErrRateLimitExceeded  ── (events.utils._errors; CONV-12 fix D3 iter 3)
│   │                                (NON-retryable; in _NEVER_RETRY at definition time)
│   │                                (RAISED BY events.middleware._rate_limit; IMPORTED there)
│   ├── ErrPublishTimeout         ── retryable, temporary
│   ├── ErrNoAck                  ── retryable, temporary
│   ├── ErrConnectionClosed       ── NON-retryable
│   ├── ErrDuplicateMsg           ── NON-retryable
│   ├── ErrInvalidSubject         ── NON-retryable
│   ├── ErrPermissionDenied       ── NON-retryable
│   ├── ErrInvalidConfig          ── NON-retryable
│   ├── ErrMissingConfig          ── NON-retryable
│   ├── ErrSerializationFailed    ── NON-retryable
│   ├── ErrShutdownInProgress     ── NON-retryable
│   ├── ErrClosed                 ── NON-retryable
│   ├── ErrStreamNotFound         ── retryable
│   ├── ErrInvalidMessage         ── retryable
│   ├── ErrMessageTooLarge        ── retryable
│   ├── ErrRequestTimeout         ── retryable
│   ├── ErrNoReply                ── retryable
│   ├── ErrSubscriptionClosed     ── retryable
│   ├── ErrSubscriptionInvalid    ── retryable
│   ├── ErrMaxMessagesExceeded    ── retryable
│   ├── ErrNoMessages             ── retryable  (NEW; D3 iter 1; raised by Consumer.next on empty fetch)
│   ├── ErrAuthFailed             ── retryable
│   ├── ErrAuthExpired            ── retryable
│   ├── ErrInvalidCredentials     ── retryable
│   ├── ErrTenantNotFound         ── retryable
│   ├── ErrTenantExists           ── retryable
│   ├── ErrTenantDisconnected     ── retryable
│   ├── ErrDeserializationFailed  ── retryable
│   ├── ErrJetStreamNotEnabled    ── retryable
│   ├── ErrInvalidArgument        ── retryable
│   ├── Error                     ── wrapper
│   ├── TenantError               ── wrapper
│   ├── SerializationError        ── wrapper (NON-retryable per is_retryable rule)
│   ├── ConfigError               ── wrapper (NON-retryable)
│   ├── ValidationError           ── wrapper
│   ├── MultiError                ── aggregate
│   ├── ErrKeyNotFound            ── (stores)
│   ├── ErrKeyExists              ── (stores)
│   ├── ErrInvalidKey             ── (stores)
│   ├── ErrHistoryToLarge         ── (stores)
│   ├── ErrObjectNotFound         ── (stores)
│   ├── ErrBadObjectMeta          ── (stores)
│   ├── ErrDigestMismatch         ── (stores)
│   └── ErrOTELUnsupportedProtocol ── (otel.common)
└── CodecError (codec._errors.CodecError)
    ├── ErrUnpackFailed
    ├── ErrUnsupportedCodec
    ├── ErrUnsupportedDataType
    ├── ErrValueOutOfRange
    └── ErrDataTooLarge
```

`ErrCircuitOpen` and `ErrRateLimitExceeded` MUST inherit from `ErrPublishFailed` so that `isinstance(e, ErrPublishFailed)` returns True (mirror Go wrapping semantics; verified by checks 116, 152). They live in **`events.utils._errors`** (CONV-12 fix, D3 iter 3 — relocated from `events.middleware`) so `_NEVER_RETRY` can be populated at definition time without import-order fragility. The middleware modules `events.middleware._circuit_breaker` and `events.middleware._rate_limit` IMPORT these sentinels (they are RAISED from middleware code, but OWNED by events.utils).

**Retry exclusion (DD-2 fix D3 iter 1; ownership relocated CONV-12 fix D3 iter 3)**: even though both inherit from `ErrPublishFailed` (which `is_retryable` returns True for), the retry middleware MUST NOT retry these. The exclusion is enforced via `events.utils._NEVER_RETRY: Final[frozenset[type[BaseException]]]` — populated at module-definition time with both fail-fast wrapper sentinels (since CONV-12 fix), checked in `is_retryable()` BEFORE the inheritance walk. This preserves the Go wrap semantics (isinstance works) while fixing the composition footgun where `Retry(CircuitBreaker(...))` would retry through an OPEN breaker. The previous design forward-declared `_NEVER_RETRY = frozenset()` and mutated it from `events.middleware.__init__.py` at import time — that pattern was import-order-fragile (caller importing `events.utils.is_retryable` BEFORE any middleware module loaded would see an empty set, defeating the breaker) AND violated CLAUDE.md rule 6 ("No global mutable state"). The cross-module rebind / `_register_never_retry()` callback pattern is REMOVED.

**`ErrNoMessages` (DD-3 fix, D3 iter 1)**: NEW sentinel added to the EventsError tree. Raised by `Consumer.next()` on the empty-fetch case (Python-idiomatic translation of Go's plain-string `errors.New("no messages available")` — Python lacks plain-string sentinels). NOT in `_NEVER_RETRY`; `is_retryable(ErrNoMessages())` returns True (the empty-queue case is transient; a Retry wrapper retrying after the next ack_wait window IS the right behavior). Catchable via `except EventsError`.

**Sentinel count delta**: 33 (rev-2) → **34** (D3 iter 1, +ErrNoMessages) → **36** (D3 iter 3, +ErrCircuitOpen + ErrRateLimitExceeded relocated from middleware per CONV-12). The D1 sentinel-inventory test (`test_errors.py::SENTINEL_TABLE`) parametrizes ALL 36 rows and is enforced as a SEMVER-8-closure invariant — `test_module_inventory_matches_table` asserts the source module's set of `EventsError`-but-not-wrapper subclasses equals the 36-row table, so adding/removing a sentinel without updating the table is a hard test-failure (not a silent drift).

`RequesterConfigError(ValueError)` lives in events.jetstream and DOES NOT inherit from EventsError (it's a typed wrapper around Go's plain string errors per scope.md). It pre-dates any I/O — it's a config-validation error. ValueError inheritance follows Python idiom.

## TenantID typing + runtime validation (TPRD §15.32 — H5-rev-3 D3 iter 2 restored)

```python
# Type-only alias (caller may use this for IDE/mypy clarity):
TenantID = NewType("TenantID", str)

# Runtime validation regex (lives in events.utils; re-exported from
# motadata_py_sdk.events.utils):
_TENANT_ID_REGEX: Final[re.Pattern[str]] = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
MaxTenantIDLength: Final[int] = 128

# TenantKVStore.__init__ + TenantObjectStore.__init__ raise ValidationError
# on bad input — see api.py.stub §6.3 docstrings.
```

The runtime check fires regardless of whether the caller used the `TenantID`
NewType wrapper. Go SDK has no equivalent; Python tightens per TPRD §15.32.

## OTel attribute conventions (TPRD §15.28 + §15.30 + §15.34 — H5-rev-3 D3 iter 2)

Every span emitted by Pub/Sub/JsPub/Consumer/KV/ObjectStore code paths includes:
- `messaging.system='nats'` (always)
- `messaging.destination=<subject>` (always for messaging spans; mirror Go — NOT `messaging.destination.name`)
- `messaging.operation='publish'|'receive'|'process'` (where applicable)

Every `*_errors_total` counter increment includes:
- `error_kind=type(exc).__name__` — bounded sentinel name from the 52-class
  hierarchy. NEVER `str(exc)` (would inject unbounded payload).

See `algorithms.md §A17` for the full convention reference; impl follows that
section verbatim.

## Type-checking strictness (mypy strict requirements)

All public APIs MUST:

1. Have full PEP 484 annotations.
2. Have `Returns:` documented in docstring (Google-style).
3. Have `Raises:` documented for every exception declared in algorithms.md.
4. Use `Final[...]` for module-level constants.
5. Use `Literal[...]` for restricted-string parameters (e.g., `otel_protocol: Literal["grpc", "http", "http/protobuf"]`).
6. Use `assert_type(...)` in unit tests on tricky generics (none in this design — no generic classes).

## Import side-effect prohibition

`__init__.py` files MUST NOT trigger any I/O at import time. Specifically:

- NO `nats.connect()` at import.
- NO `OTel Init()` at import.
- NO YAML parse at import.
- NO file open.

The pattern is `from motadata_py_sdk.events.corenats import Publisher` is a pure module-load with no side effects. The CALLER decides when to construct.

`functools.cache` decorators on `get_tracer` / `get_meter` / `Registry.counter()` etc. are LAZY — first call constructs, subsequent calls return the cached handle.

## Docstring style

Google-style + PEP 257. Every public class/method gets:

```
"""<one-line summary>.

<paragraph: extended description.>

[traces-to: TPRD-§<sec>-<id>]
[constraint: <metric> <op> <value> | bench/<BenchmarkName>]   (if applicable)

Args:
    <name>: <description>.

Returns:
    <description>.

Raises:
    <ExceptionType>: <when>.
"""
```

The `[traces-to:]` marker MUST appear in the body of the docstring — `sdk-marker-scanner` reads docstrings for Python-comment markers per `python.json::marker_comment_syntax.block_open/close`.
