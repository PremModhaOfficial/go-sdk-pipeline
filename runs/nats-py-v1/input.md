# Python SDK TPRD — NATS Subsystem Port from `motadata-go-sdk`

> **Source of truth:** `motadata-go-sdk/src/motadatagosdk/` (current on-disk state).
> **Goal:** produce a Python SDK that is **wire-compatible** with the Go SDK (publishers in one language, consumers in the other, sharing a NATS server).
> **Audience:** Python engineers porting the messaging surface. Assume familiarity with NATS / JetStream concepts.
> **Status:** behavioral spec, not surface-mirror. Idiomatic Python is allowed, but anything tagged **byte-exact** must match Go output verbatim.

---

## 0. How to read this document

| Tag | Meaning |
|---|---|
| **byte-exact** | The Python implementation MUST produce identical bytes/strings to the Go implementation. Headers, span names, error strings, codec output, metric names. |
| **behavioral** | Same observable semantics, idiomatic Python signatures encouraged. |
| **gap** | Go-side has a defect or omission. The Python port should improve OR mirror — flagged for the Go team. |
| **Known issue** | Documented quirk. Mirror unless explicitly told otherwise. |

Each module section ends with a **Conformance** subsection — those bullets are testable acceptance criteria. The master consolidated list lives in §10.

---

## 1. Scope

### In scope
- `events/core` — messaging interfaces, header constants, context propagation
- `events/corenats` — Core NATS Publisher / BatchPublisher / Subscriber
- `events/jetstream` — Stream mgmt, Publisher (sync + async), Consumer (pull), Requester (sync-over-async req/reply)
- `events/stores` — KV + Object Store wrappers
- `events/middleware` — chain framework + 6 middlewares (circuit breaker, retry, ratelimit, metrics, logging, tracing)
- `events/utils` — sentinel errors, `MultiError`, retryability classifiers, constants
- `core/codec` — Custom binary codec + MsgPack codec (wire-format-defining)
- `core/types` — generic data utilities (only enumerated; not full port)
- `otel/{tracer,metrics,logger,common}` — instrumentation surface used by the NATS code paths
- `config` — NATS-relevant subset (connection, JetStream, OTel exporters, service identity)

### Out of scope
- L1/L2 cache, `dragonfly` integration, worker pools, generic resource pools
- Non-NATS DB / HTTP / gRPC modules
- Any code outside `src/motadatagosdk/`

---

## 2. Architecture overview

```
┌─────────────────────────── Application ───────────────────────────┐
│                                                                   │
│   publisher.publish(ctx, subject, msg)        subscriber.subscribe(ctx, subject, handler)
│             │                                              ▲
│             ▼                                              │
│   ┌─── Middleware chain (decorator stack) ─────────────────┴───┐
│   │  Tracing → CircuitBreaker → RateLimit → Metrics → Retry →   │
│   │  Logging → terminal handler                                  │
│   └──────────────────────────┬──────────────────────────────────┘
│                              ▼
│   ┌─ events/corenats ────┐  ┌─ events/jetstream ─┐  ┌─ events/stores ─┐
│   │ Publisher            │  │ Publisher          │  │ KVStore         │
│   │ BatchPublisher       │  │ Consumer (pull)    │  │ ObjectStore     │
│   │ Subscriber           │  │ Requester          │  │                 │
│   │                      │  │ Stream mgmt        │  │                 │
│   └──────────┬───────────┘  └──────────┬─────────┘  └────────┬────────┘
│              │                         │                     │
│              └─────────────────────────┼─────────────────────┘
│                                        ▼
│                            ┌── nats.go / JetStream ──┐
│                            │   (caller-owned conn)   │
│                            └────────────┬────────────┘
└─────────────────────────────────────────┼─────────────────────────┘
                                          ▼
                                 ┌──── NATS server ────┐
                                 │   + JetStream       │
                                 └─────────────────────┘

Cross-cutting: events/core (interfaces, context keys, header constants, ExtractHeaders/InjectContext)
              core/codec (wire body codec)
              otel/{tracer,metrics,logger} (instrumentation; called from middleware + corenats + jetstream)
              config (settings; loaded once at startup)
```

**Key invariants**
1. The `nats.Conn` is **caller-owned** — Publisher/Subscriber wrappers do not open or close the connection. `Close()` only flushes / drains.
2. **Header propagation is opt-in via the tracing middleware.** A bare Publisher/Subscriber with no middleware will not inject or extract trace/tenant headers.
3. **The codec output never includes a schema-version field.** The wire format evolves additively via headers.
4. **Multi-tenant isolation is currently subject-scoped, not connection-scoped.** Tenant ID is propagated as `X-Tenant-ID` header and embedded in subject tokens (`{stream}.{tenantID}.>`) by the JetStream `TenantConsumerConfig`.

---

## 3. Glossary

| Term | Meaning |
|---|---|
| **Subject** | NATS routing key, dot-delimited. Wildcards: `*` (single token), `>` (multi-token, must be terminal). |
| **Stream** | JetStream persistent log capturing messages on a set of subjects. |
| **Consumer** | JetStream-side state machine tracking delivery per stream. SDK uses pull-only. |
| **Bucket** | KV / Object Store namespace. Backed by an internal stream `KV_<bucket>` / `OBJ_<bucket>`. |
| **Tenant** | Multi-tenant isolation key. Bare `string`, propagated via `X-Tenant-ID` header and subject tokens. |
| **Envelope** | The header set + body bytes. **There is no `Envelope` struct** — see §4. |
| **PubAck** | JetStream publish acknowledgement: `{Stream, Sequence, Domain}`. |
| **Requester** | Sync-over-async req/reply built on JetStream + an ephemeral reply consumer. |

---

## 4. Wire contracts (LOCKED — must be byte-exact)

This section defines what crosses the wire. Anything else is implementation detail.

### 4.1 NATS header constants (byte-exact)

Defined in `events/core/core.go`. Header keys are case-sensitive on the NATS wire. The Python port must export these as a frozen module of `Final[str]` constants with **identical spelling**.

| Python constant | Header value (byte-exact) | Purpose |
|---|---|---|
| `HEADER_CONTENT_TYPE` | `"Content-Type"` | MIME of body. |
| `HEADER_MESSAGE_ID` | `"Nats-Msg-Id"` | JetStream dedup ID; max length 64. |
| `HEADER_CORRELATION_ID` | `"Correlation-ID"` | Cross-service correlation. |
| `HEADER_TENANT_ID` | `"X-Tenant-ID"` | Multi-tenant isolation key; max length 128 (declared, not enforced — see §11). |
| `HEADER_TRACE_ID` | `"X-Trace-ID"` | 128-bit trace ID, 32 lowercase hex. |
| `HEADER_SPAN_ID` | `"X-Span-ID"` | Span ID. **Note:** Go SDK emits 128-bit / 32 hex, not the W3C-standard 64-bit / 16 hex (Known issue). |
| `HEADER_TRACEPARENT` | `"traceparent"` | W3C: `"00-<traceID>-<spanID>-<flag>"`, flag `"01"`/`"00"`. |
| `HEADER_TRACESTATE` | `"tracestate"` | W3C tracestate (vendor data). |
| `HEADER_B3_TRACE_ID` | `"X-B3-TraceId"` | Zipkin B3 trace ID. |
| `HEADER_B3_SPAN_ID` | `"X-B3-SpanId"` | Zipkin B3 span ID. |
| `HEADER_B3_SAMPLED` | `"X-B3-Sampled"` | Set to `"1"` when sampled. Read accepts `"1"` or `"true"`. |
| `HEADER_B3_PARENT_SPAN_ID` | `"X-B3-ParentSpanId"` | Declared but never written or read (Known issue). |
| `HEADER_REPLY_TO` | `"X-Reply-To"` | Reply subject for sync req/reply via Requester. |
| `HEADER_STATUS_CODE` | `"X-Status-Code"` | Numeric response status; Requester reads. |
| `HEADER_MESSAGE` | `"X-Message"` | Human-readable response message. |

**Content-Type values** (in `events/utils/const.go`): `"application/json"`, `"application/msgpack"`, `"application/octet-stream"`, `"application/protobuf"`, `"text/plain"`.

### 4.2 ExtractHeaders / InjectContext semantics (byte-exact)

`core.ExtractHeaders(ctx, headers)` is the **publisher-side** writer. Order of operations (must be reproduced):

1. If `headers is None` allocate a new dict.
2. If tenant_id present in ctx → set `X-Tenant-ID`.
3. Run `extractTraceHeaders` (below).
4. If correlation_id present → set `Correlation-ID`.
5. If message_id present → set `Nats-Msg-Id`.
6. If reply_to present → set `X-Reply-To`.

`extractTraceHeaders` branches:

- **OTel-active path** (active OTel span context with non-empty trace+span IDs): set `X-Trace-ID`, `X-B3-TraceId`, `X-Span-ID`, `X-B3-SpanId`, `X-B3-Sampled="1"`, `traceparent="00-<traceID>-<spanID>-01"`. Always sampled flag `"01"`. **Returns** without consulting manual TraceContext.
- **Manual TraceContext path** (no active OTel span; manual `TraceContext` in ctx): same headers, but `X-B3-Sampled="1"` only if `tc.sampled`, `traceparent` flag is `"01"`/`"00"` from sampled flag, `tracestate` set if `tc.state != ""`.
- **Neither**: trace headers untouched.

`core.InjectContext(ctx, headers)` is the **subscriber-side** reader. Order:

1. If `headers is None` → return ctx unchanged.
2. `X-Tenant-ID` → tenant_id in ctx.
3. Build `TraceContext`:
   - `trace_id = headers["X-Trace-ID"] or headers["X-B3-TraceId"]`
   - `span_id = headers["X-Span-ID"] or headers["X-B3-SpanId"]`
   - `sampled = (headers["X-B3-Sampled"] in ("1", "true"))`
   - `state = headers["tracestate"]`
   - if `trace_id != "" or span_id != ""` → install TraceContext.
4. `Correlation-ID` → correlation_id.
5. `Nats-Msg-Id` → message_id.
6. `X-Reply-To` → reply_to.

**Critical asymmetry**: `traceparent` is **NOT parsed** on the subscriber side. Producers emitting only W3C traceparent (no `X-Trace-ID`) will lose trace context on Motadata consumers. The Python port MUST mirror this if it wants byte-exact behavior — but should also flag it as a real bug (recommend: extract via OTel propagator first, fall back to legacy headers).

### 4.3 Codec wire format (byte-exact)

Output of `pack_map` / `pack_array` is:

```
+--------+------------------------+
| header | payload                |
| 1 byte | encoder-specific       |
+--------+------------------------+
```

**Header byte:** `0x00` = Custom binary, `0x01` = MsgPack. Other values → `ErrUnsupportedCodec`. The full byte is the encoder; high nibble currently reserved/zero. (The README claims compression in the high nibble; **compression is NOT implemented**.)

#### 4.3.1 Custom binary payload

DataType tags (1 byte each):

| Tag | Value | Width | Encoding |
|---|---|---|---|
| `INVALID` | 0 | 0 | nil |
| `BOOLEAN` | 1 | 1 | `0x00` / `0x01` |
| `INT8` | 2 | 1 | signed LE |
| `INT16` | 3 | 2 | signed LE |
| `INT24` | 4 | 3 | signed LE, sign-extend on read |
| `INT32` | 5 | 4 | signed LE |
| `INT40` | 6 | 5 | signed LE, sign-extend |
| `INT48` | 7 | 6 | signed LE, sign-extend |
| `INT56` | 8 | 7 | signed LE, sign-extend |
| `INT64` | 9 | 8 | signed LE |
| `FLOAT32` | 10 | 4 | IEEE-754 binary32 LE |
| `FLOAT64` | 11 | 8 | IEEE-754 binary64 LE |
| `STRING` | 12 | 4 + N | `uint32` LE length + UTF-8 |
| `ARRAY` | 13 | 2 + 1 + payload | `uint16` count + tag(13) + N elements |
| `BYTE_ARRAY` | 14 | 4 + N | `uint32` LE length + raw bytes |
| `MAP` | 15 | 2 + 1 + payload | `uint16` count + tag(15) + N pairs |
| `DATETIME` | 16 | 4 + N | RFC3339Nano UTF-8, `uint32` LE length |
| `DATETIME_DURATION` | 17 | 8 | nanoseconds as `int64` LE |

**Width selection** (mirrors Go's `getDataTypeINT64`): pick the smallest signed-int width that fits. Boundaries: `±2^7`, `±2^15`, `±2^23`, `±2^31`, `±2^39`, `±2^47`, `±2^55`, else 64-bit.

**Top-level map layout (after header byte):**
```
uint16 LE count | tag=Map(0x0F) | <count> pairs
each pair: uint16 LE keylen | UTF-8 key bytes | tag | value bytes
```

**Top-level array layout:**
```
uint16 LE count | tag=Array(0x0D) | <count> elements
each element: tag | value bytes
```

**Worked examples (verify byte-for-byte):**
- `pack_map({}, CUSTOM)` → `00 00 00 0F` (4 bytes)
- `pack_array([], CUSTOM)` → `00 00 00 0D` (4 bytes)
- `pack_map({"k":"v"}, CUSTOM)` → `00 01 00 0F 01 00 6B 0C 01 00 00 00 76` (13 bytes)
- `pack_map({}, MSGPACK)` → `01 80` (2 bytes)
- `pack_array([], MSGPACK)` → `01 90` (2 bytes)

#### 4.3.2 MsgPack payload

Header byte `0x01`, then `msgpack.Marshal(data)` from `github.com/vmihailenco/msgpack/v5 v5.4.1` with **default options** — no encoder customization anywhere in the SDK.

Python equivalent (`msgpack-python`):
```python
# encode
msgpack.packb(obj, use_bin_type=True, datetime=True)
# decode
msgpack.unpackb(data, raw=False, timestamp=3, strict_map_key=False)
```

Reasoning:
- `use_bin_type=True` — `bytes` round-trip via msgpack `bin` family (matches vmihailenco's `[]byte` handling).
- `raw=False` — `str` family decodes to Python `str` (matches Go decoding to `string`).
- `datetime=True` / `timestamp=3` — `datetime.datetime` round-trips via msgpack timestamp ext type **-1** (matches vmihailenco's `time.Time` encoding).
- `strict_map_key=False` — defensive; the SDK uses string keys but vmihailenco does not enforce.

**Determinism: NEITHER codec path is deterministic.** Go map iteration order is randomized; Python `dict` preserves insertion order. The same logical input produces equivalent unpacked-equal but potentially byte-different output. **Do not use codec output for cache keys, dedup IDs, or content hashes.** Recommendation: add an opt-in `deterministic=True` flag that sorts map keys; the Go side must add the same flag for cross-language hash compatibility.

#### 4.3.3 Codec error sentinels (byte-exact strings)

In `motadatagosdk/utils/errors.go` (top-level utils, not `events/utils`):

| Sentinel | String |
|---|---|
| `ErrUnpackFailed` | `"unpack failed: invalid or corrupted data"` |
| `ErrUnsupportedCodec` | `"unsupported codec type"` (wrapped: `"unsupported codec type: 0x<NN>"`) |
| `ErrUnsupportedDataType` | `"unsupported data type"` |
| `ErrValueOutOfRange` | `"value out of supported range"` |
| `ErrDataTooLarge` | `"data too large for codec length fields"` |

`UnpackMap`/`UnpackArray` install a `defer recover()` that returns `ErrUnpackFailed` on any panic. Python: catch all `IndexError`/`UnicodeDecodeError`/`struct.error` and re-raise as `ErrUnpackFailed`.

#### 4.3.4 Codec known issues / quirks

1. **`pack_array` length is checked against `2^32` but written as `uint16`.** Effective array length cap is **65535**, not 4 billion. Document and enforce in Python.
2. Inner-array length is `int16(len)` cast that round-trips through `uint16` on read — works due to two's complement, but use straightforward `uint16` LE in Python.
3. `unpacker.go` comment says key length is 4 bytes; code reads 2 bytes (`uint16`). Trust the code.
4. `time.Duration` (Go) ↔ `timedelta` (Python) is **microsecond-resolution lossy** (Python timedelta cannot store nanoseconds). Consider exposing a raw `int_ns` accessor.
5. Compression-related errors / config mentioned in README are **not implemented**.

### 4.4 Subject conventions

`events/utils/const.go`:
- `WildcardSingle = "*"`, `WildcardMulti = ">"`, `DefaultSeparator = "."`
- `MaxSubjectLength = 256` (declared, not enforced anywhere)
- Suggested prefixes (informational only, not enforced): `service`, `endpoint`, `events`, `request`, `broadcast`, `_internal`

**Tenant-scoped subject pattern (auto, from `TenantConsumerConfig`):**
```
{Stream}.{TenantID}.>
```
Note the leading token is the **stream name**, not a configurable prefix. This is a footgun when stream name differs from subject namespace (Known issue — see §6.3).

### 4.5 Tenant model

- `TenantID` is a bare `string`. **No named type, no validation, no length enforcement** in the Go SDK.
- Declared limit `MaxTenantIDLength = 128` is unused. (Gap — Python port should enforce.)
- Carried via:
  - `WithTenantID(ctx, id)` / `TenantIDFromContext(ctx)` — context plumbing
  - `X-Tenant-ID` header — wire propagation (set by tracing middleware via `core.ExtractHeaders`)
  - Subject token at position 2 in tenant-scoped JetStream consumers
  - Consumer name suffix: `"{Module}-{TenantID}"`
  - `TenantError{TenantID, Op, Err}` error wrapper, format `"tenant <id>: <op>: <err>"`
- Zero value `""` means "no tenant".

**Recommendation for Python port:** introduce a `TenantID` `NewType` with `__post_init__` validating: non-empty, ≤128 chars, regex `^[A-Za-z0-9][A-Za-z0-9_-]*$` (subject-token-safe). Stricter than Go — flag back as gap.

### 4.6 Sentinel error inventory

Defined in `events/utils/errors.go`. The Python port should expose these as exception subclasses with **byte-exact** `.Error()` strings and an `is_retryable(exc) -> bool` helper.

| Sentinel | String (byte-exact) | Retryable? | Temporary? |
|---|---|---|---|
| `ErrNotConnected` | `"not connected"` | yes | no |
| `ErrAlreadyConnected` | `"already connected"` | yes | no |
| `ErrConnectionClosed` | `"connection closed"` | **no** | no |
| `ErrConnectionTimeout` | `"connection timeout"` | yes | **yes** |
| `ErrReconnectFailed` | `"reconnect failed"` | yes | **yes** |
| `ErrPublishFailed` | `"publish failed"` | yes | no |
| `ErrPublishTimeout` | `"publish timeout"` | yes | **yes** |
| `ErrNoAck` | `"no acknowledgment received"` | yes | **yes** |
| `ErrDuplicateMsg` | `"duplicate message"` | **no** | no |
| `ErrStreamNotFound` | `"stream not found"` | yes | no |
| `ErrInvalidSubject` | `"invalid subject"` | **no** | no |
| `ErrInvalidMessage` | `"invalid message"` | yes | no |
| `ErrMessageTooLarge` | `"message too large"` | yes | no |
| `ErrRequestTimeout` | `"request timeout"` | yes | no |
| `ErrNoReply` | `"no reply received"` | yes | no |
| `ErrSubscriptionClosed` | `"subscription closed"` | yes | no |
| `ErrSubscriptionInvalid` | `"subscription invalid"` | yes | no |
| `ErrMaxMessagesExceeded` | `"max messages exceeded"` | yes | no |
| `ErrAuthFailed` | `"authentication failed"` | yes | no |
| `ErrAuthExpired` | `"authentication expired"` | yes | no |
| `ErrInvalidCredentials` | `"invalid credentials"` | yes | no |
| `ErrPermissionDenied` | `"permission denied"` | **no** | no |
| `ErrTenantNotFound` | `"tenant not found"` | yes | no |
| `ErrTenantExists` | `"tenant already exists"` | yes | no |
| `ErrTenantDisconnected` | `"tenant disconnected"` | yes | no |
| `ErrInvalidConfig` | `"invalid configuration"` | **no** | no |
| `ErrMissingConfig` | `"missing required configuration"` | **no** | no |
| `ErrSerializationFailed` | `"serialization failed"` | **no** | no |
| `ErrDeserializationFailed` | `"deserialization failed"` | yes | no |
| `ErrJetStreamNotEnabled` | `"jetstream not enabled"` | yes | no |
| `ErrShutdownInProgress` | `"shutdown in progress"` | **no** | no |
| `ErrInvalidArgument` | `"invalid argument"` | yes | no |
| `ErrClosed` | `"closed"` | **no** | no |

`is_retryable(err)` returns `False` for the sentinels marked **no**, plus any `SerializationError` / `ConfigError` typed wrapper. Defaults `True` otherwise.

`is_temporary(err)` returns `True` only for the sentinels marked **yes** in the Temporary column.

**Wrapping types** (mirror as exception subclasses):
- `Error{Op, Kind, Err, Details}` — format `"<kind>: <op>: <err>"` or `"<kind>: <err>"` if no Op.
- `TenantError{TenantID, Op, Err}` — format `"tenant <id>: <op>: <err>"` or `"tenant <id>: <err>"`.
- `SerializationError{Operation, Type, Err}` — format `"<operation> <type>: <err>"`.
- `ConfigError{Field, Message}` — format `"config error: <field>: <msg>"`.
- `ValidationError{Field, Message, Value}` — format `"validation error: <field>: <msg>"`.
- `MultiError{Errors []error}` — format `"<n> errors occurred: <slice>"` for n>1, single-error verbatim for n==1, `"no errors"` for n==0. `Unwrap()` returns the **first** error so `errors.Is(multi, sentinel)` matches the most significant failure.

---

## 5. Module: `events/core` — Messaging Contract

**Behavioral.** Pure-contract package. No I/O. Defines interfaces, header constants, and `context` ↔ `nats.Header` adapters.

### 5.1 Public types

#### `TraceContext`
```python
@dataclass(frozen=True)
class TraceContext:
    trace_id: str = ""        # 32-hex (Go SDK emits 128-bit IDs even for span — see Known issue)
    span_id: str = ""         # nominally 16-hex; Go emits 32-hex
    parent_id: str = ""       # not populated by InjectContext currently
    sampled: bool = False
    state: str = ""           # W3C tracestate
```

#### `Metadata` (in-process aggregate; NOT a wire schema)
```python
@dataclass
class Metadata:
    tenant_id: str = ""
    correlation_id: str = ""
    message_id: str = ""
    timestamp: datetime | None = None
    custom: dict[str, str] = field(default_factory=dict)
```
**Gap:** `ExtractHeaders` does NOT serialize `Metadata.timestamp` or `Metadata.custom`. Setting a `Metadata` does not auto-populate headers — only the individual `with_tenant_id`/`with_correlation_id`/`with_message_id` setters are read. Mirror Go behavior; flag for future.

#### Context helpers
Use `contextvars.ContextVar[str | None]` per key (Go uses unexported `contextKey int` per slot — Python equivalent is one ContextVar per key, do not collapse):

| Go | Python |
|---|---|
| `WithTenantID(ctx, id)` / `TenantIDFromContext(ctx)` | `set_tenant_id(id)` / `get_tenant_id() -> str | None` |
| `WithTraceContext(ctx, *TraceContext)` / `TraceContextFromContext(ctx)` | `set_trace_context(tc)` / `get_trace_context() -> TraceContext | None` |
| `WithMessageID(ctx, id)` / `MessageIDFromContext(ctx)` | `set_message_id(id)` / `get_message_id()` |
| `WithCorrelationID(ctx, id)` / `CorrelationIDFromContext(ctx)` | `set_correlation_id` / `get_correlation_id` |
| `WithReplyTo(ctx, subject)` / `ReplyToFromContext(ctx)` | `set_reply_to` / `get_reply_to` |
| `WithMetadata(ctx, *Metadata)` / `MetadataFromContext(ctx)` | `set_metadata` / `get_metadata` |

#### `ExtractOTELTraceContext`
Reads the active OTel span (via `opentelemetry.trace.get_current_span()`) and returns a `TraceContext{trace_id, span_id, sampled=True}`. Returns `None` when no active span (both IDs empty).

#### `ExtractHeaders` / `InjectContext`
See §4.2 — those byte-exact rules are the contract.

### 5.2 Public interfaces

```python
class Publisher(Protocol):
    async def publish(self, subject: str, msg: NatsMsg) -> None: ...
    async def request(self, subject: str, msg: NatsMsg) -> NatsMsg: ...
    async def close(self) -> None: ...

class Subscriber(Protocol):
    async def subscribe(self, subject: str, handler: MessageHandler) -> "Subscription": ...
    async def queue_subscribe(self, subject: str, queue: str, handler: MessageHandler) -> "Subscription": ...
    async def close(self) -> None: ...

class Subscription(Protocol):
    def subject(self) -> str: ...
    async def unsubscribe(self) -> None: ...   # immediate teardown, drops pending
    async def drain(self) -> None: ...         # graceful: stop new deliveries, finish in-flight
    def is_valid(self) -> bool: ...

MessageHandler = Callable[[Context, NatsMsg], Awaitable[None]]
# Raise an exception to signal failure (Go returns `error`).
```

### 5.3 Concurrency / threading

- All exported functions are pure.
- No goroutines / no tasks.
- `nats.Header` is mutated in place by `ExtractHeaders` — caller must not concurrently mutate the same header dict.

### 5.4 Conformance — events/core

1. The 15 header constants in §4.1 are exposed with **byte-exact** values.
2. `extract_headers` round-trips every context-bound metadata field per the rules in §4.2.
3. `extract_headers` writes both `X-Trace-ID`+`X-Span-ID` AND `X-B3-TraceId`+`X-B3-SpanId` AND `X-B3-Sampled="1"` AND `traceparent="00-<T>-<S>-01"` when an OTel span is active.
4. With manual `TraceContext{sampled=False}`, `traceparent` flag is `"00"` and `X-B3-Sampled` is NOT set.
5. `extract_headers` with `tracestate` set → emits `tracestate` header.
6. `inject_context(headers={X-Trace-ID: T, X-Span-ID: S, X-B3-Sampled: "1"})` populates a TraceContext with sampled=True; `"true"` is also accepted.
7. `inject_context` falls back to `X-B3-TraceId`/`X-B3-SpanId` when `X-Trace-ID`/`X-Span-ID` are absent.
8. `inject_context` does NOT parse `traceparent` (mirror Go bug).
9. `inject_context(None)` returns ctx unchanged.
10. `Metadata.timestamp` and `Metadata.custom` are NOT auto-propagated to headers.

---

## 6. Module: `events/corenats` — Core NATS Pub/Sub

**Behavioral.** Concrete impls of `Publisher` / `Subscriber` over plain NATS (no JetStream). Plus `BatchPublisher` for buffered publishing.

### 6.1 Constants
```python
DEFAULT_REQUEST_TIMEOUT     = 30.0   # seconds (Go: 30 * time.Second)
DEFAULT_FLUSH_TIMEOUT       = 5.0    # seconds (Go: 5 * time.Second)
DEFAULT_MAX_CONCURRENT_FLUSH = 64    # BatchPublisher worker cap
ATTR_MESSAGING_DESTINATION  = "messaging.destination"
```

### 6.2 `Publisher`

```python
class Publisher:
    def __init__(self, nc: NATS, max_payload: int): ...
    def use_middleware(self, mw: PublishMiddleware) -> None: ...
    async def publish(self, subject: str, msg: NatsMsg) -> None: ...
    async def request(self, subject: str, msg: NatsMsg) -> NatsMsg: ...
    async def request_with_timeout(self, subject: str, msg: NatsMsg, timeout: float) -> NatsMsg: ...
    async def close(self) -> None: ...
```

**`publish(subject, msg)` semantics:**
1. Acquire read lock on `closed`. If closed → `ErrConnectionClosed`. Snapshot middleware ref.
2. Inner handler:
   - Start producer span `"nats.publish"` with attr `messaging.destination=<subject>`.
   - If `nc is None` → `ErrNotConnected`.
   - **Mutate** `msg.subject = subject` (overwrites caller's value).
   - `nc.publish_msg(msg)`.
   - On error: `span.set_error`, log error with `subject` + `err`, return.
   - On success: `span.set_ok`.
3. If middleware non-nil, wrap then invoke; else direct.

**`request(subject, msg)` semantics:**
1. Closed check → `ErrConnectionClosed`. `nc is None` → `ErrNotConnected`.
2. Mutate `msg.subject = subject`.
3. **Middleware on Request runs as a pre-send hook only** — wraps a no-op terminal handler. Cannot wrap the response. Error from middleware short-circuits.
4. Compute timeout: from ctx.deadline if positive remaining; else `DEFAULT_REQUEST_TIMEOUT` (30s).
5. `nc.request_msg(msg, timeout)`.
6. Translate errors:
   - `nats.ErrTimeout` → `ErrRequestTimeout`
   - `nats.ErrNoResponders` → `ErrNoReply`
   - other → as-is
7. Return reply.

**`request_with_timeout`:** thin wrapper with `asyncio.wait_for`.

**`close()`:** idempotent. Acquire write lock; flip closed flag; `nc.flush(timeout)` where timeout = ctx.deadline remaining or `DEFAULT_FLUSH_TIMEOUT` (5s). Returns flush result.

**`use_middleware(mw)`:** appends to chain. **New mw becomes innermost** of existing chain (existing runs first on the way out). Compose `existing(mw(next))`.

**Known issue:** `max_payload` is stored but never enforced in `publish`. Oversized message fails at NATS layer. Python port may pre-validate up-front returning `ErrMessageTooLarge`.

### 6.3 `BatchPublisher`

```python
class BatchPublisher:
    def __init__(
        self,
        publisher: Publisher,
        *,
        max_batch_size: int = 0,        # 0 = no size trigger
        flush_interval: float = 0.0,    # 0 = no timer
        concurrent_flush: bool = False,
        max_flush_workers: int = 64,    # ignored if <= 0
        on_flush_error: Callable[[BaseException], None] | None = None,
    ): ...
    async def add(self, subject: str, msg: NatsMsg) -> None: ...
    async def add_multiple(self, messages: Mapping[str, NatsMsg]) -> None: ...
    async def flush(self) -> None: ...
    def count(self) -> int: ...
    async def close(self) -> None: ...
```

**Semantics:**
- Pre-allocates buffer (Go: cap 100). Spawns auto-flush task only if `flush_interval > 0`.
- `add(subject, msg)`: lock, append, compute `should_flush = max_batch_size > 0 and len >= max_batch_size`, unlock. If should_flush → call `flush()` synchronously **with a fresh background context** (caller's ctx is dropped).
- `add_multiple(messages)`: same as add but for a dict. Iteration order is whatever the dict yields — Go uses random order; Python preserves insertion order. The Python port can either match (use plain dict iteration) or take an ordered iterable.
- `flush()`: lock, if empty → unlock, return. Atomically swap buffer (replace with new slice, preserve cap). Unlock. Then `flush_concurrent(batch)` or `flush_sequential(batch)`.
- Sequential: loop, `publisher.publish(subj, msg)`, accumulate errors.
- Concurrent: `n_workers = min(max_flush_workers, len(batch))`. Buffered work channel pre-filled, then closed. N workers pull, push errs into err channel.
- Error aggregation: 0 → `None`; 1 → that error; >1 → `MultiError`.
- `close()`: cancel auto-flush task; await; final `flush()`. Idempotent.

**Auto-flush task:**
```python
while True:
    await asyncio.sleep(flush_interval)  # or use a cancel-aware wait
    if self.count() == 0:
        continue
    try:
        await self.flush()
    except Exception as e:
        if self.on_flush_error: self.on_flush_error(e)
        else: logger.error("batch auto-flush failed", error=e)
```

**Known issues:**
- No max-buffer-size cap. Sustained `add` without flush can OOM.
- `add` triggers synchronous flush on caller's coroutine using a fresh ctx (drops deadline).
- `add_multiple` order is non-deterministic in Go (map iteration). Python port: document the choice.

### 6.4 `Subscriber`

```python
class Subscriber:
    def __init__(self, nc: NATS): ...
    def use_middleware(self, mw: SubscribeMiddleware) -> None: ...
    async def subscribe(self, subject: str, handler: SubscribeHandler) -> Subscription: ...
    async def queue_subscribe(self, subject: str, queue: str, handler: SubscribeHandler) -> Subscription: ...
    async def unsubscribe(self, sub: Subscription) -> None: ...   # actually calls Drain (named "unsubscribe"!)
    async def close(self) -> None: ...
```

**`subscribe(subject, queue, handler)` semantics:**
1. Span `"nats.subscribe"` (or `"nats.queue_subscribe"` if queue) with `messaging.destination=<subject>` (+ `messaging.queue=<queue>` if applicable). Span ends when method returns.
2. `check_ready`: `ErrConnectionClosed` if closed; `ErrNotConnected` if `nc is None` or not connected.
3. Create per-subscription cancel token.
4. Wrap handler with current middleware chain (snapshot under lock).
5. Build NATS callback:
   - If sub-cancel fired → drop message early.
   - Else start consumer span `"nats.receive"` with same attrs.
   - Call wrapped handler. Set span error/ok. End span.
   - **Handler errors are NOT propagated to NATS** (no NAK in core NATS; fire-and-forget).
6. Register: `nc.queue_subscribe(subject, queue, cb)` or `nc.subscribe(subject, cb)`.
7. On reg error: cancel token, span error, log, return error.
8. Store in slice + index map (keyed by underlying NATS subscription pointer, O(1) lookup).
9. Log info `"NATS subscription created"` with `subject`, `queue`.

**`unsubscribe(sub)` semantics (named "unsubscribe" but actually calls Drain):**
1. Type-check; if not internal subscription → silent no-op.
2. Lock; if not in index → unlock, no-op.
3. Delete from index and slice (swap-with-last-then-truncate).
4. Unlock.
5. **Call `sub.drain()`** (graceful, not abrupt unsubscribe).

**`close()` semantics:**
1. Span `"nats.subscriber.close"`.
2. Write lock entire close.
3. Set `closed=True`.
4. For each sub: cancel its token, then `sub.drain()`. Collect errors.
5. If any drain errors: log warn `"errors draining subscriptions during close"` with `error_count`. **Errors are NOT returned.**
6. Null out index + slice. `span.set_ok`.
7. Log info `"NATS subscriber closed"` with `subscriptions_closed`.
8. Return None unconditionally.

### 6.5 Conformance — events/corenats

11. `publish(subject="", msg)` returns `ErrInvalidSubject` (after `nc.publish_msg` rejects empty); `publish(s, None)` → `ErrInvalidMessage`.
12. After `close()`, both `publish` and `request` return `ErrConnectionClosed`.
13. `publish` overwrites `msg.subject` with the argument (verify via server echo).
14. `request` translates `nats.ErrTimeout` → `ErrRequestTimeout`.
15. `request` translates `nats.ErrNoResponders` → `ErrNoReply`.
16. `request` honors ctx.deadline over default 30s; with no deadline, defaults to 30s.
17. `close` is idempotent; calls `nc.flush(5s)` when ctx has no deadline.
18. `use_middleware` composes new mw as innermost (calls go A→B→handler for `Use(A); Use(B)`).
19. Middleware on `request` runs as pre-send hook only — does not wrap response.
20. `BatchPublisher` with `max_batch_size=N` triggers synchronous flush exactly when buffer reaches N.
21. `flush_interval=d` spawns a task; `flush_interval=0` does not.
22. Empty `flush()` returns None without invoking publisher.
23. Single failure → that error verbatim; multiple → `MultiError`; none → `None`.
24. `concurrent_flush=True` uses `min(max_flush_workers, batch_size)` workers.
25. `max_flush_workers=0` → ignored, default 64 stays.
26. `BatchPublisher.close` cancels auto-flush, awaits, final-flushes.
27. Auto-flush errors → `on_flush_error` callback if set; else error log. Not surfaced via add/add_multiple return.
28. `Subscriber.subscribe` after `close` → `ErrConnectionClosed`.
29. Disconnected `nc` → `ErrNotConnected`.
30. Returned subscription's `subject()` matches input.
31. `is_valid()` true while subscribed, false after `drain()` or `unsubscribe()`.
32. `Subscriber.close` cancels per-sub tokens before drain — no callback fires after close.
33. `Subscriber.close` returns `None` even when individual drains fail (errors logged).
34. `Subscriber.unsubscribe(sub)` calls `sub.drain()` (not abrupt unsub).
35. `Subscriber.unsubscribe(non_internal_sub)` returns silently.
36. Subject wildcards `*` and `>` route correctly.
37. Queue subscriptions distribute load across members of the same queue group.

---

## 7. Module: `events/jetstream` — Streams, Publisher, Consumer, Requester

**Behavioral.** Wraps JetStream from the underlying NATS client. Pull-only consumer model.

### 7.1 Stream management

#### `StreamConfig`
```python
@dataclass
class StreamConfig:
    name: str                          # required
    subjects: list[str]                # required, ≥1
    retention: Retention = Retention.LIMITS
    max_msgs: int = 0                  # 0 = unlimited
    max_bytes: int = 0
    max_age: float = 0.0               # seconds
    max_msg_size: int = 0              # 0 = server default
    replicas: int = 1                  # forced to 1 if <= 0
    storage: StorageType = StorageType.FILE
    description: str = ""
    # Limits-retention-only fields (silently dropped on other policies):
    max_msgs_per_subject: int = 0
    discard_new_per_subject: bool = False
    allow_rollup: bool = False
    deny_delete: bool = False
    deny_purge: bool = False
```

**Hard-coded fields** (not configurable, must be set on every stream):
| Field | Value |
|---|---|
| `Discard` | `DiscardOld` |
| `Duplicates` | `120.0` seconds (2 minutes — JetStream dedup window for `Nats-Msg-Id`) |
| `AllowDirect` | `True` |

`Retention` enum: `WORK_QUEUE`, `LIMITS` (default), `INTEREST`.

#### `Stream` class

```python
class Stream:
    def name(self) -> str: ...
    async def info(self) -> StreamInfo: ...
    async def purge(self) -> None: ...               # span "stream.purge"
    async def delete(self) -> None: ...              # span "stream.delete"
    async def subjects(self) -> list[str]: ...
    async def add_subjects(self, *subjects: str) -> None: ...   # idempotent (dedups)
    async def remove_subjects(self, *subjects: str) -> None: ... # refuses to remove last subject
    async def set_subjects(self, subjects: list[str]) -> None: ...
```

**`add_subjects`**: idempotent (dedups against existing list).
**`remove_subjects`**: rejects empty input; rejects removal of all subjects with `ErrInvalidArgument` and details `{"reason": "cannot remove all subjects"}`.
**`set_subjects([])`**: rejects with `ErrInvalidArgument`.

#### Factory functions

```python
async def create_stream(js, cfg: StreamConfig) -> Stream: ...
async def create_or_update_stream(js, cfg: StreamConfig) -> Stream: ...
async def get_stream(js, name: str) -> Stream: ...
async def delete_stream(js, name: str) -> None: ...
async def list_streams(js) -> list[str]: ...
```

**Validation:**
- Empty `name` → `ErrInvalidArgument` with details `{"reason": "name is required"}`
- Empty `subjects` → `ErrInvalidArgument` with details `{"reason": "at least one subject is required"}`
- `js is None` → Go uses string error `"jetstream not available"` (Known issue: should use sentinel `ErrJetStreamNotEnabled`). Python port: use the sentinel.

**Span emissions:**
| Operation | Span name | Attributes |
|---|---|---|
| `create_stream` | `"stream.create"` | `stream` |
| `create_or_update_stream` | `"stream.create_or_update"` | `stream` |
| `Stream.purge` | `"stream.purge"` | `stream` |
| `Stream.delete` | `"stream.delete"` | `stream` |

**Log emissions:**
| Site | Level | Message | Fields |
|---|---|---|---|
| `create_stream` success | INFO | `"stream created"` | `stream` |
| `Stream.purge` success | INFO | `"stream purged"` | `stream` |
| `Stream.delete` success | INFO | `"stream deleted"` | `stream` |

**Known issues (mirror or fix):**
- `Stream.info`, `subjects`, `add_subjects`, `remove_subjects`, `set_subjects` emit no spans.
- `delete_stream` (factory) emits no span and no log; `Stream.delete` does. Asymmetric.
- `create_or_update_stream` does not log on success (vs. `create_stream` which does).
- `Stream.AddSubjects/RemoveSubjects/SetSubjects` are not concurrency-safe in Go (`s.raw` reassigned without lock). Python should add a lock or document single-writer requirement.

### 7.2 Publisher

```python
class Publisher:
    def __init__(self, nc: NATS, js: JetStream, max_payload: int): ...
    def use_middleware(self, mw: PublishMiddleware) -> None: ...
    async def publish(self, subject: str, msg: NatsMsg) -> PubAck: ...
    def publish_async(self, subject: str, msg: NatsMsg) -> PubAckFuture: ...
    async def close(self) -> None: ...

@dataclass(frozen=True)
class PubAck:
    stream: str
    sequence: int
    domain: str
```

**Constants (file-scoped):**
- `defaultPublishTimeout = 10s` (Publisher applies if ctx has no deadline)
- `defaultFlushTimeout = 5s`

**`publish` semantics:**
1. Closed check → `ErrConnectionClosed`. Snapshot middleware.
2. Wrap ctx with 10s timeout if no deadline.
3. Internal handler:
   - `subject == ""` → `ErrInvalidSubject`
   - `msg is None` → `ErrInvalidMessage`
   - `max_payload > 0 and len(msg.data) > max_payload` → `ErrMessageTooLarge` with format `"<sentinel>: <N> bytes exceeds <limit> limit"`
   - `js is None` → `ErrJetStreamNotEnabled`
   - Set `msg.subject = subject`.
   - If `msg.headers["Nats-Msg-Id"]` set → pass `with_msg_id(id)` to JS publish (engages dedup).
   - Span: `tracer.start_producer(ctx, "jetstream.publish", attrs={"messaging.destination": subject})`.
   - Call `js.publish_msg(...)`.
   - Return `PubAck{stream, sequence, domain}`.

**`publish_async` semantics:**
1. Allocate future (e.g., `asyncio.Future[PubAck]`).
2. Closed check; on closed → set `ErrConnectionClosed` on future, return.
3. Spawn task:
   - If `js is None` → set `ErrJetStreamNotEnabled` on future.
   - Build terminal handler that calls `js.publish_msg`, sets future result/exception.
   - Wrap with middleware if any.
   - On error, log ERROR `"async JetStream publish failed"` with `subject`, `err`.

**Known issue:** `publish_async` skips pre-validation (`subject==""`, `msg is None`, oversized payload) — falls through to NATS layer. Inconsistent with `publish`. Python port should add same validations to async path for parity, OR document divergence.

**Known issue:** `publish_async` has no caller-side concurrency limit — unbounded spawned tasks. Python port should consider a semaphore knob.

**`close()`:** idempotent. Flushes underlying connection with 5s timeout (or ctx deadline).

### 7.3 Consumer (pull-only)

#### Constants
```python
DEFAULT_ACK_WAIT       = 30.0    # seconds
DEFAULT_MAX_DELIVER    = 5
DEFAULT_MAX_ACK_PENDING = 1000
```

#### `MessageHandler`
```python
MessageHandler = Callable[[Context, JsMsg], Awaitable[None]]
# Return None → message is Acked.
# Raise → message is Nacked (redelivered up to MaxDeliver).
# Ctx cancellation between messages → Nack without invoking handler.
```

#### `ConsumerConfig`
```python
@dataclass
class ConsumerConfig:
    stream: str                      # required
    name: str                        # required (used as Name AND Durable)
    filter_subjects: list[str] = field(default_factory=list)
    ack_wait: float = 30.0           # seconds, applied if 0
    max_deliver: int = 5             # applied if <= 0
    max_ack_pending: int = 1000      # applied if <= 0
    deliver_policy: DeliverPolicy = DeliverPolicy.ALL
    description: str = ""
    metadata: dict[str, str] = field(default_factory=dict)
```

**Hard-coded:** `AckPolicy = AckExplicitPolicy`. `Durable = name`. Always durable; no ephemeral mode exposed.

#### `TenantConsumerConfig`
```python
@dataclass
class TenantConsumerConfig:
    stream: str                      # required
    module: str                      # required
    tenant_id: str                   # required
    filter_subjects: list[str] = field(default_factory=list)
    # ...same defaults as ConsumerConfig
```

**Auto-derives:**
- `name = f"{module}-{tenant_id}"` (via `consumer_name(module, tenant_id)`)
- `filter_subjects = [f"{stream}.{tenant_id}.>"]` if empty

> **Known issue / footgun:** the auto-filter uses **stream name** as the leading subject token. If your stream name doesn't match the subject namespace, this will not match. Document explicitly.

#### `Consumer` class

```python
class Consumer:
    def name(self) -> str: ...
    def stream(self) -> str: ...
    async def info(self) -> ConsumerInfo: ...
    async def start(self, handler: MessageHandler, **opts) -> None: ...
    def stop(self) -> None: ...                       # idempotent
    async def delete(self) -> None: ...               # calls stop + js.delete_consumer
    async def fetch(self, batch: int, **opts) -> MessageBatch: ...
    async def fetch_no_wait(self, batch: int) -> MessageBatch: ...
    async def next(self, **opts) -> JsMsg: ...        # returns "no messages available" if empty
```

**`start` dispatch loop (per delivered message):**
1. Check ctx.cancelled — if yes: `msg.nak()`, log warn `"consumer: nak failed on context cancellation"` if Nak fails, return.
2. Call `handler(ctx, msg)`.
3. If handler raised: `msg.nak()`, log warn `"consumer: nak failed"` if Nak fails.
4. Else: `msg.ack()`, log warn `"consumer: ack failed"` if Ack fails.

**Delivery guarantees:** at-least-once. Combination of `AckExplicitPolicy` + `MaxDeliver=5` default + stream `Duplicates=2m`.

**Concurrency:** underlying NATS library invokes callback concurrently per delivered message (bounded by `MaxAckPending`, default 1000). Handler MUST be concurrent-safe.

**Known issues:**
- No `InProgress` / `Term` exposed to handler — only Ack/Nak via return value/raise. Python port could extend `JsMsg` with `in_progress()` / `term()` methods if needed.
- `start` after `stop` returns plain string error `"consumer stopped"` (not a sentinel). Python port should normalize to `ErrClosed`.
- `start`/`stop` race can leak the consume context (Go bug). Python port should hold lock through full lifecycle.
- Many `ConsumerConfig` fields are NOT exposed: `ReplayPolicy`, `OptStartSeq`, `OptStartTime`, `RateLimit`, `SampleFrequency`, `HeadersOnly`, `BackOff`, `InactiveThreshold`, `DeliverGroup`, `MemoryStorage`. Decide explicitly per-field.

#### Factory functions

```python
async def create_consumer(js, cfg: ConsumerConfig) -> Consumer: ...               # actually CreateOrUpdate
async def create_tenant_consumer(js, cfg: TenantConsumerConfig) -> Consumer: ...   # delegates to create_consumer
async def get_consumer(js, stream: str, name: str) -> Consumer: ...
async def delete_consumer(js, stream: str, name: str) -> None: ...
async def list_consumers(js, stream: str) -> list[str]: ...
```

**Validation:**
- `create_consumer` empty `stream`/`name` → `"consumer: stream and name are required"`
- `create_tenant_consumer` any of `stream`/`module`/`tenant_id` empty → `"consumer: stream, module, and tenant_id are required"`

**Known issue:** `create_consumer` is named "create" but actually does create-or-update (`js.create_or_update_consumer`). Mismatch with `create_stream` (which uses `js.create_stream` and fails on existing). Python port should either rename to `create_or_update_consumer` or split. Recommend the latter.

### 7.4 Requester (sync-over-async req/reply)

#### `RequesterConfig`
```python
@dataclass
class RequesterConfig:
    nc: NATS                              # required
    js: JetStream                         # required
    max_payload: int = 0                  # forwarded to internal Publisher
    reply_stream: str                     # required, captures `{prefix}.>`
    reply_subject_prefix: str             # required, e.g. "_REPLY.bridge"
    instance_id: str                      # required, unique per pod/process
    request_timeout: float = 30.0         # default 30s
    inactive_threshold: float = 300.0     # default 5m, server-side cleanup
```

**Validation errors (plain strings, NOT sentinels in Go):**
- `"requester: nats connection is required"`
- `"requester: jetstream is required"`
- `"requester: reply_stream is required"`
- `"requester: reply_subject_prefix is required"`
- `"requester: instance_id is required"`

Python port should expose these as a typed `RequesterConfigError(ValueError)`.

#### `Requester` class

```python
class Requester:
    @classmethod
    async def create(cls, cfg: RequesterConfig) -> "Requester": ...
    async def request(self, subject: str, msg: NatsMsg) -> "Response": ...
    async def close(self) -> None: ...
```

**`create` semantics:**
1. Apply defaults; validate.
2. Span `"requester.init"` with attrs `stream`, `instance_id`.
3. Compute:
   - `filter_subject = f"{prefix}.{instance_id}.>"`
   - `consumer_name = f"reply-{instance_id}"`
4. Build hard-coded ConsumerConfig:
   - `name = consumer_name`
   - `ack_policy = AckExplicit`
   - `filter_subjects = [filter_subject]`
   - `inactive_threshold = cfg.inactive_threshold`
   - `deliver_policy = ALL`
   - `max_ack_pending = 1024`
   - `headers_only = False`
   - **No Durable** — ephemeral consumer.
5. `js.create_or_update_consumer(reply_stream, consumer_cfg)`.
6. Construct internal Publisher; init `pending: dict[str, asyncio.Future]`.
7. Start consume via `raw.consume(dispatch)`. **If consume() fails, delete the just-created consumer to avoid leak.**
8. Log INFO `"requester started"` with `stream`, `filter`, `instance_id`.

#### `Response`

```python
@dataclass
class Response:
    status_code: int = 200
    message: str = ""
    data: JsMsg = None
    err: Exception | None = None

    def ok(self) -> bool:
        return 200 <= self.status_code < 300
```

`build_response(msg)` semantics:
- Default `status_code=200`, `data=msg`.
- If headers None → return defaults.
- Read `X-Status-Code`; on int parse success override `status_code`. **On parse failure, silently keep 200.**
- Read `X-Message` into `message`.
- If `status_code >= 400`: set `err = Exception(f"status {status_code}: {message or 'request failed'}")`.

#### `request` semantics
1. Generate `request_id = f"{instance_id}-{ns_unix}-{seq}"` (monotonic per-instance counter, locked).
2. Compute `reply_subject = f"{prefix}.{instance_id}.{request_id}"`. Allocate buffer-1 future.
3. Single lock acquire: if closed → `ErrClosed`; else register `pending[request_id] = future`. Release.
4. If ctx no deadline → wrap with `request_timeout` (default 30s).
5. Span `"requester.request"` with attr `messaging.destination=<subject>`.
6. Defer cleanup: `del pending[request_id]` under lock.
7. Set `msg.headers["X-Reply-To"] = reply_subject`.
8. `self.publisher.publish(subject, msg)` — wrap error: `"requester: publish: <err>"`.
9. Wait on future or ctx:
   - On reply: build Response; span error if `resp.err is not None`.
   - On timeout: return `ErrRequestTimeout` (NOT ctx.err — important for `is_instance` check).

#### `close` semantics
- Idempotent. Flip `closed=True` under lock. Stop consume. Close internal publisher (which flushes).

**Known issues:**
- `close` does NOT delete the ephemeral consumer it created — relies on server `inactive_threshold` (5m).
- Late replies (after request timed out) are dropped silently (future already removed).
- `dispatch` warns use `context.Background()`, dropping trace context.
- `nextID` uses Unix-nanos + counter — Python equivalent: `time.time_ns()` + `itertools.count()`.

### 7.5 Headers used by JetStream layer (byte-exact)

| Header | Producer | Consumer | Notes |
|---|---|---|---|
| `Nats-Msg-Id` | Publisher (if set on msg) | n/a | Engages JetStream dedup window (2m). |
| `X-Reply-To` | Requester (always) | Responder reads | Format `{prefix}.{instance_id}.{request_id}`. |
| `X-Status-Code` | Responder | Requester | `200` default if absent or non-integer. |
| `X-Message` | Responder | Requester | Used in error string when status >= 400. |

JetStream-native headers NOT used: `Nats-Expected-Stream`, `Nats-Expected-Last-Sequence`, `Nats-Expected-Last-Subject-Sequence`, `Nats-Expected-Last-Msg-Id`, `Nats-Rollup`. Python port should mirror this minimal surface.

### 7.6 Span / log emissions

Spans (OTel): see §7.1 stream spans, §7.2 `"jetstream.publish"`, §7.4 `"requester.init"` and `"requester.request"`. **No spans on consumer factories, `Consumer.start/stop/delete`, `fetch*`, `next`, async-publish terminal.**

Logs:
| Level | Message | Fields | Site |
|---|---|---|---|
| ERROR | `"async JetStream publish failed"` | `subject`, `err` | `publish_async` task on error |
| WARN | `"consumer: nak failed on context cancellation"` | `consumer`, `err` | dispatch loop |
| WARN | `"consumer: nak failed"` | `consumer`, `err` | dispatch loop after handler error |
| WARN | `"consumer: ack failed"` | `consumer`, `err` | dispatch loop after handler success |
| WARN | `"requester: unknown reply subject"` | `subject` | dispatch when subject doesn't match prefix |
| WARN | `"requester: no pending request for reply"` | `request_id` | dispatch when request_id not in map |

**No metrics** emitted by this module.

### 7.7 Conformance — events/jetstream

(See §10 master list — JS conformance numbered 38–96.)


---

## 8. Module: `events/stores` — KV + Object Store

**Behavioral.** Thin wrappers over the underlying NATS client's KV / Object stores. Almost no business logic. Multi-tenant scoping is **NOT** implemented at this layer.

### 8.1 KVStore

```python
class KVStore:
    def bucket_name(self) -> str: ...
    async def get(self, key: str) -> KeyValueEntry: ...
    async def put(self, key: str, value: bytes) -> int: ...                # returns revision
    async def create(self, key: str, value: bytes) -> int: ...             # fails if exists
    async def update(self, key: str, value: bytes, last_revision: int) -> int: ...   # CAS
    async def delete(self, key: str, *, last_revision: int | None = None) -> None: ...  # soft (tombstone)
    async def keys(self) -> list[str]: ...
    async def history(self, key: str) -> list[KeyValueEntry]: ...
    async def watch(self, keys: str) -> AsyncIterator[KeyValueEntry]: ...
    async def watch_all(self) -> AsyncIterator[KeyValueEntry]: ...
    async def purge(self, key: str, *, last_revision: int | None = None) -> None: ...   # hard (drop history)
    async def status(self) -> KeyValueStatus: ...
```

#### Constructors
```python
async def new_kv_store(js, cfg: KeyValueConfig) -> KVStore: ...
async def get_kv_store(js, bucket: str) -> KVStore: ...
async def delete_kv_store(js, bucket: str) -> None: ...
```

`js is None` → `ErrJetStreamNotEnabled` with message `"jetstream not enabled"`.

#### `KeyValueConfig` (delegated to underlying client)

| Field | Type | Default | Meaning |
|---|---|---|---|
| `bucket` | str | required | Maps to stream `KV_<bucket>`. |
| `description` | str | `""` | |
| `max_value_size` | int | `-1` (server default ~1MB) | Per-value cap. |
| `history` | int | `1` | Revisions retained per key (1–64). |
| `ttl` | float | `0` | Per-entry TTL in seconds. |
| `max_bytes` | int | `0` | Bucket cap. |
| `storage` | StorageType | `FILE` | File or memory. |
| `replicas` | int | `1` | HA replicas. |
| `compression` | bool | `False` | s2 compression. |

#### Watch semantics
Returns watcher with stream of `KeyValueEntry` updates. Empty / `None` "marker" value signals end of initial replay → live mode.

Watch options:
- `include_history` — replay all historical revisions
- `ignore_deletes` — skip tombstones
- `meta_only` — entries without payload
- `updates_only` — skip initial replay
- `resume_from_revision(rev)` — replay from revision

#### Errors
| Error | Condition |
|---|---|
| `ErrKeyNotFound` | `get` on missing or last-deleted key |
| `ErrKeyExists` | `create` on existing key |
| `ErrInvalidKey` | key contains forbidden chars (subject-token-unsafe) |
| `ErrHistoryToLarge` | `history > 64` |

### 8.2 ObjectStore

```python
class ObjectStore:
    def bucket_name(self) -> str: ...
    async def get(self, name: str) -> ObjectResult: ...     # streamable
    async def get_info(self, name: str, *, show_deleted: bool = False) -> ObjectInfo: ...
    async def put(self, meta: ObjectMeta, data: AsyncIterable[bytes] | bytes) -> ObjectInfo: ...
    async def put_bytes(self, name: str, data: bytes) -> ObjectInfo: ...
    async def delete(self, name: str) -> None: ...           # soft (tombstone)
    async def list(self) -> list[ObjectInfo]: ...
    async def watch(self) -> AsyncIterator[ObjectInfo]: ...
    async def status(self) -> ObjectStoreStatus: ...
```

#### `ObjectStoreConfig`
| Field | Default | Meaning |
|---|---|---|
| `bucket` | required | Maps to stream `OBJ_<bucket>`. |
| `description` | `""` | |
| `ttl` | `0` | Object TTL. |
| `max_bytes` | `0` | Bucket cap. |
| `storage` | `FILE` | |
| `replicas` | `1` | |
| `compression` | `False` | |
| `metadata` | `None` | Bucket-level static metadata. |

#### Chunking
- Default chunk size **128 KiB** (configurable via `meta.opts.chunk_size`).
- Chunks delivered on subject `$O.<bucket>.C.<NUID>`.
- SHA256 digest stored as `"SHA-256=<base64-url-no-pad>"` in `ObjectInfo.digest`. Verified on get.
- Replacement (PUT same name) writes new chunks under fresh NUID, atomic metadata flip, tombstones old NUID's chunks.

#### Errors
| Error | Condition |
|---|---|
| `ErrObjectNotFound` | get/get_info on missing |
| `ErrBadObjectMeta` | put with empty name or invalid headers |
| `ErrDigestMismatch` | get chunk SHA256 fails verification |

### 8.3 Multi-tenant gaps

**The stores layer has NO tenant-awareness in the Go SDK.**

- Bucket names are NOT auto-scoped per tenant.
- Key prefixes are NOT auto-injected.
- No metadata stamping with `X-Tenant-ID`.
- The `tenant_id` in ctx is not extracted by the wrapper.

**Recommendation for Python port:** add a tenant-aware wrapper layer:

```python
class TenantKVStore:
    def __init__(self, tenant_id: str, kv: KVStore): ...
    async def get(self, key: str) -> KeyValueEntry:
        return await self._kv.get(f"{self._tenant_id}.{key}")
    # ... same prefix on all ops; reject cross-tenant reads
```

Decide bucket-per-tenant vs. shared-bucket-with-key-prefix vs. hybrid before porting. Flag back to Go team.

### 8.4 OTel gaps

Stores layer emits **no spans, no metrics, no logs**. Compare to `events/jetstream/stream.go` which does emit spans.

**Recommendation:** Python port should add spans `kv.<op>` / `objectstore.<op>` with attributes:
- `nats.bucket=<bucket>`
- `nats.key=<key>` (KV) or `nats.object=<name>` (Object)
- `tenant.id=<tenant>` (if tenant wrapper installed)
- `nats.revision=<rev>` (KV write ops)

Match the pattern from `stream.go`: `span.SetError(err)` / `span.SetOK()` and INFO-level success log.

### 8.5 Conformance — events/stores

97. `new_kv_store(None, cfg)` → `ErrJetStreamNotEnabled`, message exactly `"jetstream not enabled"`.
98. Same for `get_kv_store`, `delete_kv_store`, three `*_object_store` factories.
99. `kv.bucket_name()` returns the constructor-supplied name.
100. All delegate methods forward errors verbatim from underlying client.
101. CAS: `create(k, v)` → rev `r1`. `create(k, v')` → `ErrKeyExists`. `update(k, v', r1)` → `r2 > r1`. `update(k, v'', r1)` (stale) → error.
102. Watch with no opts: 1 entry (latest) + marker, then nothing live.
103. Watch with `include_history`: all entries + marker.
104. Watch after marker emits live updates.
105. Object 1 MiB at default chunk size → `ObjectInfo.chunks == 8`. SHA256 matches.
106. Soft-delete: `delete(k)` → `get(k)` returns NotFound. `history(k)` shows `PUT` then `DELETE`.
107. Hard-delete via `purge(k)`: history retains only purge marker.

---

## 9. Module: `events/middleware` — Chain + 6 middlewares

**Behavioral.** Functional decorator-style middleware. Composable on publish path and subscribe path independently.

### 9.1 Chain framework

```python
PublishHandler = Callable[[Context, NatsMsg], Awaitable[None]]
PublishMiddleware = Callable[[PublishHandler], PublishHandler]
SubscribeHandler = Callable[[Context, NatsMsg], Awaitable[None]]
SubscribeMiddleware = Callable[[SubscribeHandler], SubscribeHandler]

class Interceptor(Protocol):
    def intercept_publish(self) -> PublishMiddleware: ...
    def intercept_subscribe(self) -> SubscribeMiddleware: ...

class Stack:
    def use_publish(self, mw: PublishMiddleware) -> None: ...
    def use_subscribe(self, mw: SubscribeMiddleware) -> None: ...
    def use_interceptor(self, ic: Interceptor) -> None: ...
    def publish_chain(self) -> PublishMiddleware: ...
    def subscribe_chain(self) -> SubscribeMiddleware: ...
    def wrap_publish(self, h: PublishHandler) -> PublishHandler: ...
    def wrap_subscribe(self, h: SubscribeHandler) -> SubscribeHandler: ...

def chain(*ms: PublishMiddleware) -> PublishMiddleware: ...
def chain_subscribe(*ms: SubscribeMiddleware) -> SubscribeMiddleware: ...
```

**Order:** first registered = outermost wrapper. `chain(*ms)` reduces in reverse: `for m in reversed(ms): next = m(next)`. Publish and subscribe lists are independent.

**Note (Go README is stale):** the actual Go signature is `func(ctx, msg)`, not `func(ctx, subject, msg)`. Subject lives on `msg.subject`.

### 9.2 Circuit breaker

**Sentinel error:** `ErrCircuitOpen = wraps ErrPublishFailed`, kind `"circuit_breaker"`, op `"allow"`. `is_instance(e, ErrPublishFailed)` is True.

```python
@dataclass
class CircuitBreakerConfig:
    failure_threshold: int = 5             # consecutive failures in CLOSED → OPEN
    success_threshold: int = 2             # consecutive successes in HALF_OPEN → CLOSED
    timeout: float = 30.0                  # seconds in OPEN before HALF_OPEN probe
    on_state_change: Callable[[State, State], None] | None = None
    should_trip: Callable[[Exception], bool] = lambda e: e is not None  # default: count any error
```

**State machine:**
- States: `CLOSED (0)`, `OPEN (1)`, `HALF_OPEN (2)`. `str()` returns `"closed"` / `"open"` / `"half-open"` / `"unknown"`.
- CLOSED: pass; on success reset failures; on `should_trip(err)` increment; if `failures >= failure_threshold` → OPEN, stamp `last_failure_time`.
- OPEN: if elapsed > timeout → HALF_OPEN, allow this call; else `ErrCircuitOpen`.
- HALF_OPEN: every call allowed (no per-call cap — `HalfOpenMaxRequests` mentioned in doc.go is **NOT implemented**). On success increment; if `successes >= success_threshold` → CLOSED. **Any** failure → OPEN immediately.
- `transition_to` zeros both counters; mutex-guarded; `on_state_change` fires once per transition.
- `reset()` force-transitions to CLOSED.

`MultiCircuitBreaker` keys per `msg.subject`. Lazy creation via concurrent dict.

**No metrics, no logs, no spans of its own.** Only `on_state_change` callback.

**Composition warning:** `ErrCircuitOpen` wraps `ErrPublishFailed` which is in the retryable set — retry middleware OUTSIDE CB will retry on it. Place retry INSIDE CB, or filter via `with_should_retry`.

### 9.3 Retry

```python
@dataclass
class RetryConfig:
    max_attempts: int = 3                   # max RETRIES after initial call (so up to 4 total)
    initial_interval: float = 0.1           # seconds
    max_interval: float = 5.0
    multiplier: float = 2.0
    jitter: float = 0.1                     # proportional, ±jitter * backoff. 0 disables.
    # built-in:
    should_retry: Callable[[Exception], bool] = default_should_retry  # is_retryable(err)
```

**Algorithm:**
- Outer loop: `for attempt in range(max_attempts + 1)`. Loop runs at most `max_attempts + 1` times — first iteration is initial call.
- Per iteration: check ctx.cancelled; if cancelled return `last_err or ctx.err`. Call `next`. On success return. On error save `last_err`. If `not should_retry(last_err) or attempt >= max_attempts` → return `last_err`. Otherwise `wait_backoff(attempt)`; if ctx fires during wait → return `last_err` (NOT ctx.err — asymmetric with pre-attempt check).
- **Backoff formula** (must match exactly):
  1. `backoff = initial_interval * (multiplier ** attempt)`
  2. Cap: `if backoff > max_interval: backoff = max_interval`
  3. Jitter (only if `jitter > 0`): `jitter_range = backoff * jitter; jitter_val = jitter_range * (random()*2 - 1)` (uniform in `[-range, +range)`); `backoff += jitter_val`
  4. Floor (only if jitter enabled): `if backoff < initial_interval: backoff = initial_interval`
  5. Return `backoff`.
- **Default schedule** (initial=100ms, mult=2, max=5s, jitter=0.1, max_attempts=3):
  - Attempt 0 fails → wait `100ms ± 10ms` (≥100ms)
  - Attempt 1 fails → wait `200ms ± 20ms`
  - Attempt 2 fails → wait `400ms ± 40ms`
  - Attempt 3 fails → return `last_err`

**Jitter RNG:** Go uses `crypto/rand` (8 bytes interpreted as `binary.LittleEndian.Uint64 / MaxUint64`); falls back to `0.5` (no jitter contribution since `0.5*2-1 = 0`) on entropy failure. Python: `secrets.SystemRandom().random()` or `os.urandom(8)`-derived float, with same fallback.

**No retry metric counter** is incremented or exposed.

**`intercept_subscribe()` returns a pure pass-through** (`return next`). Retry has no effect on the consume path — for redelivery rely on JetStream nak/term.

**Default `should_retry`:** `err is not None and is_retryable(err)`. `is_retryable` returns False for: `ErrInvalidSubject`, `ErrInvalidMessage`, `ErrInvalidConfig`, `ErrMissingConfig`, `ErrSerializationFailed`, `ErrPermissionDenied`, `ErrDuplicateMsg`, `ErrShutdownInProgress`, `ErrConnectionClosed`, plus any `SerializationError` / `ConfigError` typed wrapper.

### 9.4 Rate limit

**Sentinel:** `ErrRateLimitExceeded = wraps ErrPublishFailed`, kind `"rate_limiter"`, op `"allow"`. Also retryable by default — caveat as above.

#### Token bucket
```python
@dataclass
class RateLimiterConfig:
    rate: float = 100.0      # tokens/sec sustained refill
    burst: int = 50          # bucket capacity (default config); int(rate) when constructor sees <=0
```

**Algorithm:**
- Internally stores **milliTokens** (1 token = 1000 milliTokens) for sub-token precision in atomic int64.
- Initial: `burst * 1000` milliTokens; `last_update = now_ns`.
- **Refill** (on every Allow*/Tokens read): `elapsed = (now - last_update) / 1s`; `new_tokens = elapsed * rate * 1000`; CAS-add capped at `burst*1000`; on success store `last_update = now`. No-op if `elapsed <= 0`.
- **AllowN(n)**: refill; CAS-subtract `n*1000`; return False if current < needed (no reservation/borrow).
- **WaitN(ctx, n)**: spin: if `AllowN(n)` return; else `deficit = needed - current`, `wait_time = deficit/rate * 1ms` (clamp >=1ms), `await wait_for(ctx_done, wait_time)` and retry.
- Lock-free; atomic CAS.

#### Sliding window
```python
class SlidingWindowLimiter:
    def __init__(self, limit: int, window: float): ...
    def allow(self) -> bool: ...
    def count(self) -> int: ...
```
- State: `requests: list[int]` (ns timestamps), mutex-guarded.
- Allow: lock; prune leading expired (`ts <= now - window`); if `len >= limit` return False; else append `now`, return True.

#### Per-subject
- `PerSubjectRateLimiter.get(subject)` lazy-creates a token bucket per subject (independent caps).

#### Wrapper modes
- **Reject mode** (`rate_limit_middleware`): immediate `ErrRateLimitExceeded`.
- **Wait mode** (`rate_limit_wait_middleware`): blocks via `wait`, propagates ctx err.

**No metrics, no logs, no spans.**

### 9.5 Metrics

#### In-process collector
```python
class MetricsCollector:
    def on_publish(self, fn): ...
    def on_receive(self, fn): ...
    def collect(self) -> Metrics: ...
    def reset(self) -> None: ...
```
- `intercept_publish`: timestamp start; call next; atomic-increment `publish_count`, `publish_latency` (sum of nanos), `bytes_sent` (`len(msg.data)`); on err `publish_errors`; invoke callback.
- `intercept_subscribe`: increment `receive_count` and `bytes_received` **before** next runs (asymmetric with publish). Process time + errors after.

#### OTEL collector (`OTELMetricsMiddleware`)
**Metric inventory (byte-exact names):**

| Name | Type | Unit | Attributes | Description |
|---|---|---|---|---|
| `events_publish_total` | counter | none | `subject` | "Total number of messages published" |
| `events_publish_errors_total` | counter | none | `subject` | "Total number of publish errors" |
| `events_publish_duration_ms` | histogram | `"ms"` | `subject` | "Request duration in milliseconds" |
| `events_receive_total` | counter | none | `subject` | "Total number of messages received" |
| `events_receive_errors_total` | counter | none | `subject` | "Total number of receive errors" |
| `events_receive_duration_ms` | histogram | `"ms"` | `subject` | "Request duration in milliseconds" |
| `events_bytes_sent_total` | counter | none | `subject` | "Total bytes sent" |
| `events_bytes_received_total` | counter | none | `subject` | "Total bytes received" |

**Critical:** histogram unit is **milliseconds** (not seconds). README claims `events_publish_duration_seconds` — that's wrong; trust the code.

**No per-error-class label.** Only `subject` dimension.
**No CB / RL / retry metrics.** Those are emitted only via in-process or callback paths.

#### Per-subject metrics
- `PerSubjectMetrics.intercept_publish`: lookup-or-create `MetricsCollector` keyed on `msg.subject`, delegate.

**Note:** in `metrics.Init`, the global Registry is instantiated with namespace = `cfg.service_name`. Resulting on-wire names are `<service>_events_publish_total`, etc. Python port should match.

### 9.6 Logging

```python
class LoggingMiddleware:
    def __init__(self, logger: Logger): ...
    def with_level(self, level: LogLevel) -> "LoggingMiddleware": ...
    def with_payload(self, enabled: bool, max_size: int = 1024) -> "LoggingMiddleware": ...
```

**Levels:** `DEBUG=0, INFO=1, WARN=2, ERROR=3`. Default level INFO.

**Per-call fields (byte-exact keys):**
- `subject` (string)
- `msg_id` (from `msg.headers["Nats-Msg-Id"]`)
- `size` (`len(msg.data)`)
- `latency_ms` (publish only) / `process_time_ms` (subscribe only)
- `error` (string, on failure)
- `payload` (only when `log_payload=True`, truncated to `max_payload_size` bytes with `"..."` suffix)
- `trace_id`, `span_id` (from `core.TraceContextFromContext` if present)
- `tenant_id` (from `core.TenantIDFromContext` if present)

**Log messages (byte-exact):**

| Path | Level | Message |
|---|---|---|
| Publish pre-call | DEBUG | `"publishing message"` |
| Publish success | INFO | `"message published"` |
| Publish failure | ERROR | `"publish failed"` |
| Subscribe pre-call | DEBUG | `"processing message"` |
| Subscribe success | DEBUG (note: not INFO — by design quiet) | `"message processed"` |
| Subscribe failure | ERROR | `"message processing failed"` |

**OTEL bridge:** `OTELLogger` forwards to `otel/logger.L().Named("events")`. Note: bridge always passes `context.Background()` to underlying logger, so trace correlation relies on the explicit `trace_id`/`span_id` fields, not on baggage.

**Logging never short-circuits the chain** — always calls next, returns its error verbatim.

### 9.7 Tracing

```python
class TracingMiddleware:
    def __init__(self): ...
    # config attrs: trace_id_generator, span_id_generator, sampler, use_otel
```

Defaults: 128-bit hex IDs from `crypto/rand` (Python: `secrets.token_hex(16)`), always-sample, `use_otel=True`.

**OTEL mode publish (`publish_with_otel`):**
1. Span: `tracer.start_producer(ctx, "events.publish", attrs={"messaging.system": "nats", "messaging.destination": <subject>, "messaging.operation": "publish"})`.
2. Read active OTel SpanContext; if valid, build `core.TraceContext{trace_id, span_id, sampled}` and store in ctx.
3. `ensure_headers(msg)`; `core.extract_headers(ctx, msg.headers)` (writes all the X-Trace/X-B3/traceparent headers + tenant + correlation + msg_id + reply_to).
4. `next(ctx, msg)`. `span.set_error(err)` or `span.set_ok()`. `span.end()`.

**OTEL mode subscribe:**
1. If headers exist: `core.inject_context(ctx, msg.headers)`.
2. `tracer.start_consumer(ctx, "events.receive", attrs={"messaging.system": "nats", "messaging.destination": <subject>, "messaging.operation": "receive"})`.
3. **Caveat — known bug:** the consumer span is NOT linked to the producer span via OTel context propagation. The middleware reads custom `core.TraceContext` from headers but does NOT call `propagator.extract`. Consumer span ends up as a new root by default. **Recommendation for Python port: call `propagator.extract(carrier=msg.headers)` before `start_as_current_span(...)` so consumer span links to producer.** Flag back to Go team as bug.
4. Read active span; re-stash into `core.TraceContext` for downstream logs.
5. `next`. Set status. End.

**Manual mode:** if no OTel span context available, mint TraceID + SpanID via `secrets.token_hex(16)` (32 hex chars / 128 bits — Known issue, W3C spec says span = 64 bits / 16 hex). For child operations: copy parent trace_id, generate new span_id, set parent_id.

**W3C helpers:**
- `extract_w3c_traceparent(s) -> TraceContext | None`: parse `version-traceID-parentID-flags` (e.g. `"00-4bf9...-00f0...-01"`). Returns None if `len(s) < 55` or split count != 4.
- `format_w3c_traceparent(tc) -> str`: emit `"00-{trace_id}-{span_id}-01"` if sampled else `"-00"`. Empty if `tc is None`, `trace_id==""`, or `span_id==""`.

**Span names (byte-exact):**
- Producer: `"events.publish"`
- Consumer: `"events.receive"`

**Span attributes (byte-exact keys):**
- `messaging.system="nats"`
- `messaging.destination="<subject>"`
- `messaging.operation="publish"` or `"receive"`

**Note:** uses **deprecated** OTel semconv key `messaging.destination` (not `messaging.destination.name` as in semconv ≥1.20). Match Go for byte-exact parity, BUT Python OTel auto-instrumentation may rewrite — disable it on these spans.

### 9.8 Composition rules

Recommended publish order (outermost → innermost):
1. **Tracing** (must be outermost — establishes ctx that all subsequent middlewares read)
2. **Circuit breaker** (fail fast)
3. **Rate limit**
4. **Metrics** (captures retries since metrics is outside retry)
5. **Retry** (innermost; observes raw upstream errors)
6. **Logging** (innermost — sees every retry attempt as separate log lines)
7. terminal handler

**Hard constraints:**
- **Tracing must be outermost** — logging will otherwise miss `trace_id`/`span_id`.
- **Retry must be inside CB** for breaker to count one logical failure per call.
- **Rate limit reject mode + retry**: place RL inside retry, OR filter `ErrRateLimitExceeded` via `with_should_retry`.

**Subscribe order:** Tracing → CB → RL → Metrics → Logging → Handler. Retry has no effect (`intercept_subscribe` is pass-through).

### 9.9 Multi-tenant gaps
- No middleware reads `core.TenantID` for keying. Per-subject CB/RL/metrics use `msg.subject` only.
- TenantID propagated only as side effect via tracing middleware (`core.extract_headers` writes `X-Tenant-ID`).
- Logging adds `tenant_id` field when present in ctx.
- **Recommendation:** extend `MultiCircuitBreaker` / `PerSubjectRateLimiter` to support a key derivation function `key_fn(ctx, msg) -> str` that defaults to `msg.subject` but can be overridden to e.g. `f"{tenant_id}:{msg.subject}"`.

### 9.10 Conformance — events/middleware

(See §10 master list — middleware conformance numbered 108–155.)


---

## 10. OTel instrumentation (consolidated)

### 10.1 Resource attributes (auto-set on every signal)

| Key | Source | Default |
|---|---|---|
| `service.name` | `SERVICE_NAME` env / config | `"app"` |
| `service.version` | `SERVICE_VERSION` env / config | `"0.0.0"` |
| `deployment.environment` | `SERVICE_ENVIRONMENT` env / config | `"development"` |

Plus SDK-default `telemetry.sdk.*` attributes (added by OTel SDK; `telemetry.sdk.language` will differ Go vs Python — that's expected).

### 10.2 Propagators

Set globally via `otel.set_text_map_propagator`. Mapping by config string:

| String | Propagator |
|---|---|
| `"tracecontext"` / `"traceparent"` | W3C TraceContext |
| `"baggage"` | W3C Baggage |
| `"b3"` | B3 single-header format |
| `"b3multi"` | B3 multi-header format |
| `"jaeger"` | Jaeger |

Default if list is empty or all unrecognized: composite of `tracecontext` + `baggage`.

### 10.3 Sampler

`tracer/provider.go::create_sampler(ratio)`:
- `ratio <= 0` → `ALWAYS_OFF`
- `ratio >= 1` → `ALWAYS_ON` (default)
- `0 < r < 1` → `TraceIdRatioBased(ratio)`

Wrapped in `ParentBased(sampler)` — children inherit parent decision.

### 10.4 Span inventory (NATS code paths, byte-exact)

| Span name | Kind | Attributes | Source |
|---|---|---|---|
| `"nats.connect"` | INTERNAL | `connection.name` | `events/connection.go` |
| `"events.publish"` | PRODUCER | `messaging.system="nats"`, `messaging.destination=<subject>`, `messaging.operation="publish"` | tracing middleware |
| `"events.receive"` | CONSUMER | `messaging.system="nats"`, `messaging.destination=<subject>`, `messaging.operation="receive"` | tracing middleware |
| `"nats.publish"` | PRODUCER | `messaging.destination=<subject>` | corenats Publisher |
| `"nats.subscribe"` (or `"nats.queue_subscribe"`) | INTERNAL | `messaging.destination=<subject>`, optional `messaging.queue=<queue>` | corenats Subscriber registration |
| `"nats.receive"` | CONSUMER | `messaging.destination=<subject>`, optional `messaging.queue=<queue>` | corenats Subscriber callback |
| `"nats.subscriber.close"` | INTERNAL | — | corenats Subscriber.close |
| `"jetstream.publish"` | PRODUCER | `messaging.destination=<subject>` | JS Publisher |
| `"requester.request"` | INTERNAL | `messaging.destination=<subject>` | Requester.request |
| `"requester.init"` | INTERNAL | `stream`, `instance_id` | NewRequester |
| `"stream.create"` | INTERNAL | `stream` | CreateStream |
| `"stream.create_or_update"` | INTERNAL | `stream` | CreateOrUpdateStream |
| `"stream.delete"` | INTERNAL | `stream` | Stream.delete |
| `"stream.purge"` | INTERNAL | `stream` | Stream.purge |

**Span status semantics:**
- Success: `span.set_ok()` → status `Ok`, description `""`.
- Error: `span.set_error(err)` → calls **both** `set_status(Error, err.message)` AND `record_exception(err)`. Nil error ignored.
- Spans always `end()`-ed via context manager / try-finally.

**Known gaps (mirror or fill):**
1. Inner spans (`nats.publish`, `nats.receive`, `jetstream.publish`) miss `messaging.system="nats"` and `messaging.operation` attrs that the outer middleware spans have.
2. `Stream.info`, `subjects`, `add_subjects`, `remove_subjects`, `set_subjects` emit no spans.
3. JS Consumer factories, `Consumer.start/stop/delete`, `fetch`, `next` emit no spans.
4. KV / Object Store emit no spans at all.
5. Span IDs are 128-bit (32 hex), not W3C-standard 64-bit (16 hex).
6. Consumer span is not parented to producer trace (middleware doesn't call `propagator.extract`).

### 10.5 Metrics inventory

See §9.5 for the 8 events_* metrics. **No connection-state metrics. No JS-publish-ack-latency metrics. No KV/Object metrics. No CB/RL/retry metrics.**

### 10.6 Log fields

**Auto-attached on every record (logger-level):**
- `service`, `version`, `env` (zap-side, not OTel resource keys)
- `timestamp` (RFC3339Nano)
- `level` (lowercase: debug/info/warn/error/fatal)
- `logger` (named-logger key)
- `caller` (e.g. `pkg/file.go:42`)
- `message`
- `stacktrace` (auto-included at ErrorLevel+)

**Auto-extracted from ctx:**
- `trace_id`, `span_id` (32-hex / 16-hex from active OTel span)
- `tenant_id`, `request_id`, `user_id`, `correlation_id` (from logger-side context helpers)

Python port: emit identical field names in JSON output (logfile / console) and as log-record attributes (OTLP).

### 10.7 OTel error sentinels
- `ErrOTELUnsupportedProtocol` (from `otel/common`) — wrapping value when `resolve_protocol` rejects an unknown protocol string.

### 10.8 Default batch / queue settings

| Constant | Value | Used by |
|---|---|---|
| `OTELDefaultMaxQueueSize` | `2048` | trace + log batch processors |
| `OTELDefaultMaxExportBatch` | `512` | trace + log batch processors |
| `OTELDefaultExportInterval` | `1.0s` | log batch processor |
| `OTELDefaultBatchTimeout` | `30.0s` | trace + log batch processors |
| `OTELDefaultShutdownTimeout` | `10.0s` | logger graceful close |
| Tracer `BatchTimeout` | **`5.0s`** (overrides) | trace batch processor |
| Metrics `ExportInterval` | **`15.0s`** | metrics periodic reader |

---

## 11. Configuration

Two parallel config systems coexist in Go:
- `config.Config` — Service / Logger / Metrics / Tracer; YAML + env (env overrides).
- `config.EventsConfig` + `events/connection.ConnectionConfig` — NATS connection / TLS / JetStream / publish / subscribe / KV / Object Store; **env-only loader** in `EventsConfig`, programmatic in `ConnectionConfig`.

These are independent. **Recommendation for Python port:** unify into a single Pydantic-Settings tree.

### 11.1 NATS connection / events config

| Key | Type | Env (`EVENTS_` prefix) | Default | Meaning |
|---|---|---|---|---|
| `servers` | `list[str]` | `EVENTS_SERVERS` (comma-sep) | `["nats://localhost:4222"]` | Allowed schemes: `nats://`, `tls://`, `ws://`, `wss://`. ≥1 required. |
| `name` | `str` | `EVENTS_NAME` | `""` (`ConnectionConfig` defaults to `"events"`) | Client name. |
| `connect_timeout` | `float` | `EVENTS_CONNECT_TIMEOUT` | `10.0` | Per-attempt timeout. >0. |
| `drain_timeout` | `float` | `EVENTS_DRAIN_TIMEOUT` | `30.0` | Graceful drain. >0. |
| `idle_timeout` | `float` | `EVENTS_IDLE_TIMEOUT` | `1800.0` | Close idle conns. >0. |
| `cleanup_interval` | `float` | `EVENTS_CLEANUP_INTERVAL` | `60.0` | Idle-conn scan interval. >0. |
| `tls.enabled` | `bool` | `EVENTS_TLS_ENABLED` | `False` | |
| `tls.cert_file` | `str` | `EVENTS_TLS_CERT_FILE` | `""` | mTLS client cert. |
| `tls.key_file` | `str` | `EVENTS_TLS_KEY_FILE` | `""` | mTLS client key. |
| `tls.ca_file` | `str` | `EVENTS_TLS_CA_FILE` | `""` | CA bundle. |
| `tls.skip_verify` | `bool` | `EVENTS_TLS_SKIP_VERIFY` | `False` | |
| `reconnect.max_attempts` | `int` | `EVENTS_RECONNECT_MAX_ATTEMPTS` | `-1` (infinite) | |
| `reconnect.initial_interval` | `float` | `EVENTS_RECONNECT_INITIAL` | `0.1` | Backoff start. >0. |
| `reconnect.max_interval` | `float` | `EVENTS_RECONNECT_MAX` | `30.0` | Backoff cap. ≥initial. |
| `reconnect.multiplier` | `float` | `EVENTS_RECONNECT_MULTIPLIER` | `2.0` | ≥1.0. |
| `reconnect.jitter` | `float` | `EVENTS_RECONNECT_JITTER` | `0.1` | [0, 1]. |
| `stream.enabled` | `bool` | `EVENTS_STREAM_DISABLED` (**inverted!**) | `True` | |
| `stream.domain` | `str` | `EVENTS_STREAM_DOMAIN` | `""` | |
| `stream.prefix` | `str` | `EVENTS_STREAM_PREFIX` | `""` | |

### 11.2 Publish/subscribe defaults (no env loaders; set programmatically)

| Key | Default |
|---|---|
| `publish.retry.max_attempts` | `3` |
| `publish.retry.initial_interval` | `0.1` |
| `publish.retry.max_interval` | `5.0` |
| `publish.retry.multiplier` | `2.0` |
| `publish.retry.jitter` | `0.1` |
| `publish.ack_timeout` | `5.0` |
| `publish.enable_deduplication` | `True` |
| `publish.deduplication_window` | `120.0` (2m) |
| `subscribe.queue_group` | `""` |
| `subscribe.max_concurrent` | `10` (>0) |
| `subscribe.ack_wait` | `30.0` (>0) |
| `subscribe.batch_size` | `100` |
| `subscribe.batch_wait` | `0.1` |

### 11.3 OTel exporter config

| Key | Env | Default |
|---|---|---|
| `service.name` | `SERVICE_NAME` | `"app"` |
| `service.version` | `SERVICE_VERSION` | `"0.0.0"` |
| `service.environment` | `SERVICE_ENVIRONMENT` | `"development"` |
| `logger.level` | `LOG_LEVEL` | `"info"` |
| `logger.console_enabled` | `LOG_CONSOLE_ENABLED` | `True` |
| `logger.console_format` | `LOG_CONSOLE_FORMAT` | `"json"` (or `"console"`) |
| `logger.otel_enabled` | `LOG_OTEL_ENABLED` | `False` |
| `logger.otel_endpoint` | `LOG_OTEL_ENDPOINT` | `"localhost:4317"` |
| `logger.otel_insecure` | `LOG_OTEL_INSECURE` | `True` |
| `logger.otel_protocol` | `LOG_OTEL_PROTOCOL` | `"grpc"` |
| `logger.otel_debug` | `LOG_OTEL_DEBUG` | `False` |
| `logger.file_enabled` | `LOG_FILE_ENABLED` | `False` |
| `logger.file_path` | `LOG_FILE_PATH` | `"logs/app.log"` |
| `logger.file_max_size_mb` | `LOG_FILE_MAX_SIZE_MB` | `100` |
| `logger.file_max_backups` | `LOG_FILE_MAX_BACKUPS` | `5` |
| `logger.file_max_age_days` | `LOG_FILE_MAX_AGE_DAYS` | `7` |
| `logger.file_compress` | `LOG_FILE_COMPRESS` | `True` |
| `logger.add_caller` | `LOG_ADD_CALLER` | `True` |
| `logger.caller_skip` | `LOG_CALLER_SKIP` | `2` |
| `logger.module_levels[<NAME>]` | `LOG_MODULE_<NAME>` (lowercased) | `{}` |
| `metrics.enabled` | `METRICS_ENABLED` | `True` |
| `metrics.otel_enabled` | `METRICS_OTEL_ENABLED` | `False` |
| `metrics.otel_endpoint` | `METRICS_OTEL_ENDPOINT` | `"localhost:4317"` |
| `metrics.otel_insecure` | `METRICS_OTEL_INSECURE` | `True` |
| `metrics.otel_protocol` | `METRICS_OTEL_PROTOCOL` | `"grpc"` |
| `metrics.export_interval` | `METRICS_EXPORT_INTERVAL` | `15.0` |
| `metrics.default_labels` | (none) | `{}` |
| `tracer.enabled` | `TRACER_ENABLED` | `False` |
| `tracer.otel_endpoint` | `TRACER_OTEL_ENDPOINT` | `"localhost:4317"` |
| `tracer.otel_insecure` | `TRACER_OTEL_INSECURE` | `True` |
| `tracer.otel_protocol` | `TRACER_OTEL_PROTOCOL` | `"grpc"` |
| `tracer.otel_debug` | `TRACER_OTEL_DEBUG` | `False` |
| `tracer.sampling_ratio` | `TRACER_SAMPLING_RATIO` | `1.0` |
| `tracer.propagators` | (YAML/code only) | `["tracecontext", "baggage"]` |
| `tracer.batch_timeout` | `TRACER_BATCH_TIMEOUT` | `5.0` |
| `tracer.max_export_batch` | `TRACER_MAX_EXPORT_BATCH` | `512` |
| `tracer.max_queue_size` | `TRACER_MAX_QUEUE_SIZE` | `2048` |

**Note:** Go SDK ignores OTel-standard env vars (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, etc.). Python port should accept BOTH the OTel-standard names AND the SDK's prefixed names (Python OTel SDK auto-loads OTel-standard ones anyway).

**Metrics dead config:** `prometheus_enabled`, `prometheus_port`, `prometheus_path` are accepted but the Prometheus exporter is **not wired**. Drop or implement.

### 11.4 Loading precedence

1. Hardcoded defaults.
2. YAML file (with env-var expansion via `os.path.expandvars`-equivalent before parsing).
3. Environment variables (highest priority).

For `LoadWithEnv(dir, env)`: base file `<dir>/config.yaml`, then overridden by `<dir>/config.<env>.yaml`.

### 11.5 Validation rules

`config.Config.Validate()` is a **stub** (returns nil). Logger / Metrics / Tracer get no validation. **Python port should add proper validation as a deliberate divergence-up.**

`EventsConfig.validate()`:
- `servers` non-empty; each must start with allowed scheme; no empty entries.
- `connect_timeout`, `drain_timeout`, `idle_timeout`, `cleanup_interval` all >0.
- `reconnect.initial_interval > 0`, `reconnect.max_interval >= initial_interval`.
- `reconnect.multiplier >= 1.0`.
- `reconnect.jitter ∈ [0.0, 1.0]`.
- If `tls.enabled`: cert+key both empty or both set; if any of cert/key/ca set, file must exist.

### 11.6 Suggested Python implementation

**Recommendation: `pydantic-settings` v2.**

Reasoning:
- Direct support for env + YAML + precedence ordering (env wins).
- Free validation matching Go-side rules (range checks, regex, enums).
- Pydantic v2 errors map well to Go's `ConfigError{Field, Message}`.
- Fast (Rust-backed) validation.

```python
from typing import Annotated, Literal
from pydantic import BaseModel, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class ServiceConfig(BaseModel):
    name: str = "app"
    version: str = "0.0.0"
    environment: str = "development"

class TracerConfig(BaseModel):
    enabled: bool = False
    otel_endpoint: str = "localhost:4317"
    otel_insecure: bool = True
    otel_protocol: Literal["grpc", "http", "http/protobuf"] = "grpc"
    otel_debug: bool = False
    sampling_ratio: Annotated[float, Field(ge=0.0, le=1.0)] = 1.0
    propagators: list[str] = Field(default_factory=lambda: ["tracecontext", "baggage"])
    batch_timeout_seconds: float = 5.0
    max_export_batch: int = 512
    max_queue_size: int = 2048

class ReconnectConfig(BaseModel):
    max_attempts: int = -1
    initial_interval_seconds: float = 0.1
    max_interval_seconds: float = 30.0
    multiplier: Annotated[float, Field(ge=1.0)] = 2.0
    jitter: Annotated[float, Field(ge=0.0, le=1.0)] = 0.1

class EventsConfig(BaseModel):
    servers: list[str] = Field(default_factory=lambda: ["nats://localhost:4222"])
    name: str = ""
    connect_timeout_seconds: float = 10.0
    drain_timeout_seconds: float = 30.0
    # ... + tls, reconnect, stream

    @field_validator("servers")
    @classmethod
    def _validate_servers(cls, v: list[str]) -> list[str]:
        if not v: raise ValueError("at least one server is required")
        for i, s in enumerate(v):
            if not s: raise ValueError(f"server URL cannot be empty (index {i})")
            if not any(s.startswith(p) for p in ("nats://", "tls://", "ws://", "wss://")):
                raise ValueError(f"server {i} must have valid scheme")
        return v

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_nested_delimiter="__", env_file=".env", extra="ignore")
    service: ServiceConfig = Field(default_factory=ServiceConfig)
    tracer: TracerConfig = Field(default_factory=TracerConfig)
    events: EventsConfig = Field(default_factory=EventsConfig)
    # ... logger, metrics
```

To stay byte-compatible with Go-style flat env names (`LOG_LEVEL`, `METRICS_OTEL_ENDPOINT`), add per-field `validation_alias=AliasChoices(...)` overrides or implement a custom `EnvSettingsSource`.

---

## 12. Suggested Python project layout

```
motadata-py-sdk/
├── motadata_sdk/
│   ├── __init__.py
│   ├── codec/
│   │   ├── __init__.py
│   │   ├── custom.py            # Custom binary codec (§4.3.1)
│   │   ├── msgpack.py           # MsgPack codec (§4.3.2)
│   │   └── errors.py            # ErrUnpackFailed, ErrUnsupportedCodec, etc.
│   ├── events/
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── headers.py       # 15 header constants
│   │   │   ├── context.py       # WithTenantID, TenantIDFromContext, etc. via contextvars
│   │   │   ├── extract_inject.py  # extract_headers, inject_context
│   │   │   ├── interfaces.py    # Publisher, Subscriber, Subscription Protocols
│   │   │   └── types.py         # TraceContext, Metadata
│   │   ├── corenats/
│   │   │   ├── publisher.py
│   │   │   ├── batch_publisher.py
│   │   │   └── subscriber.py
│   │   ├── jetstream/
│   │   │   ├── stream.py
│   │   │   ├── publisher.py
│   │   │   ├── consumer.py
│   │   │   └── requester.py
│   │   ├── stores/
│   │   │   ├── kv.py
│   │   │   ├── object_store.py
│   │   │   └── tenant_aware.py  # TenantKVStore, TenantObjectStore (NEW — Python-only)
│   │   ├── middleware/
│   │   │   ├── stack.py
│   │   │   ├── circuit_breaker.py
│   │   │   ├── retry.py
│   │   │   ├── rate_limit.py
│   │   │   ├── metrics.py
│   │   │   ├── logging.py
│   │   │   └── tracing.py
│   │   └── utils/
│   │       ├── errors.py        # All sentinels with byte-exact strings
│   │       ├── classifiers.py   # is_retryable, is_temporary
│   │       └── const.py
│   ├── otel/
│   │   ├── common.py            # ServiceInfo, resolve_protocol, ShutdownCollector
│   │   ├── tracer.py            # Init, Shutdown, span helpers, w3c helpers
│   │   ├── metrics.py
│   │   └── logger.py
│   └── config/
│       ├── settings.py          # pydantic-settings models
│       └── loader.py            # YAML + env precedence
├── tests/
│   ├── conformance/             # The §13 master conformance suite
│   │   ├── codec/
│   │   ├── headers/
│   │   ├── corenats/
│   │   ├── jetstream/
│   │   ├── stores/
│   │   └── middleware/
│   ├── fixtures/                # Go-emitted byte-fixture vectors
│   └── integration/             # against testcontainers nats-server
├── pyproject.toml
└── README.md
```

---

## 13. Dependencies / version pins

| Concern | Python lib | Min version | Notes |
|---|---|---|---|
| NATS client | `nats-py` | latest | asyncio-native; provides JetStream + KV + Object Store |
| MsgPack codec | `msgpack` | ≥1.0 | Default settings via `use_bin_type=True, raw=False, datetime=True, timestamp=3, strict_map_key=False` |
| OTel API | `opentelemetry-api` | ≥1.30 | Match Go SDK semconv 1.24.0 (uses deprecated `messaging.destination` key) |
| OTel SDK | `opentelemetry-sdk` | ≥1.30 | |
| OTel OTLP exporter (gRPC) | `opentelemetry-exporter-otlp-proto-grpc` | ≥1.30 | |
| OTel OTLP exporter (HTTP) | `opentelemetry-exporter-otlp-proto-http` | ≥1.30 | |
| B3 propagator | `opentelemetry-propagator-b3` | ≥1.30 | |
| Jaeger propagator | `opentelemetry-propagator-jaeger` | ≥1.30 | |
| Config | `pydantic` + `pydantic-settings` | v2 | |
| Tests | `pytest` + `pytest-asyncio` + `testcontainers[nats]` | latest | |

**Go-side pins (for reference):**
- OTel API/trace/metric: `v1.41.0`
- OTel SDK: `v1.39.0`
- OTel log SDK + log exporters: `v0.15.0`
- otelzap bridge: `v0.14.0`
- B3 propagator: `v1.39.0`
- Jaeger propagator: `v1.39.0`
- semconv: `v1.24.0`
- vmihailenco/msgpack: `v5.4.1`

---

## 14. Master conformance checklist

Numbered for reference. The Python port must pass every applicable check.

### 14.1 Wire contracts
1. The 15 NATS header constants (§4.1) are exposed with byte-exact values.
2. `extract_headers` round-trips tenant_id, correlation_id, message_id, reply_to per the rules in §4.2.
3. With active OTel span: writes `X-Trace-ID` + `X-B3-TraceId` + `X-Span-ID` + `X-B3-SpanId` + `X-B3-Sampled="1"` + `traceparent="00-<T>-<S>-01"`.
4. With manual `TraceContext{sampled=False}`: `traceparent` flag is `"00"`, no `X-B3-Sampled` set.
5. With manual `TraceContext` having non-empty `state`: emits `tracestate` header.
6. Empty ctx: no trace/tenant/correlation/message/reply-to entries; never returns None.
7. `inject_context({X-Trace-ID, X-Span-ID, X-B3-Sampled: "1"})`: TraceContext populated, sampled=True.
8. `X-B3-Sampled="true"` also accepted.
9. Falls back to `X-B3-TraceId`/`X-B3-SpanId` when `X-Trace-ID`/`X-Span-ID` absent.
10. Does NOT parse `traceparent` (mirror Go behavior; flag as bug to Go team).
11. `inject_context(None)` returns ctx unchanged.

### 14.2 Codec
12. Round-trip equality for every supported type at boundary values (-2^7..2^7-1, etc.).
13. Byte-fixture: `pack_map({}, CUSTOM)` == `00 00 00 0F`.
14. Byte-fixture: `pack_array([], CUSTOM)` == `00 00 00 0D`.
15. Byte-fixture: `pack_map({}, MSGPACK)` == `01 80`.
16. Byte-fixture: `pack_array([], MSGPACK)` == `01 90`.
17. Byte-fixture: `pack_map({"k":"v"}, CUSTOM)` == `00 01 00 0F 01 00 6B 0C 01 00 00 00 76`.
18. Header `0x02..0xFF` → `ErrUnsupportedCodec` with `"unsupported codec type: 0x<NN>"`.
19. Empty bytes → `ErrUnpackFailed`.
20. Truncated map (count=1, body short) → `ErrUnpackFailed`.
21. Non-string map key → `ErrUnsupportedDataType`.
22. 65536-element array → `ErrDataTooLarge`.
23. 65536-byte key → `ErrDataTooLarge`.
24. `int(2**63)` (uint64 > MaxInt64) → `ErrValueOutOfRange`.
25. MsgPack interop: Go-emitted `0x01 || marshal({"k":"v"})` decodes to `{"k":"v"}` in Python.
26. MsgPack interop: bytes/datetime/lists round-trip via cross-language fixtures.

### 14.3 Error sentinels
27. Each sentinel exception's `str()` matches the byte-exact string in §4.6.
28. `is_retryable(e)` returns False for the 8 non-retryable sentinels.
29. `is_temporary(e)` returns True only for the 4 temporary sentinels.
30. `MultiError(n>1).str()` matches `"<n> errors occurred: <slice>"`.
31. `MultiError(n==1).str()` matches the inner error verbatim.
32. `MultiError(n==0).str()` returns `"no errors"`.
33. `is_instance(multi, sentinel)` matches the FIRST collected error.

### 14.4 events/core
34. (See §5.4 1-10.)

### 14.5 events/corenats
35. (See §6.5 11-37.)

### 14.6 events/jetstream
38. `create_stream` empty `name` → `ErrInvalidArgument` + details `{"reason": "name is required"}`.
39. `create_stream` empty `subjects` → `ErrInvalidArgument` + details `{"reason": "at least one subject is required"}`.
40. `create_stream` against existing stream → error (does NOT create-or-update).
41. `create_or_update_stream` against existing → success.
42. `replicas=0` → server-side replicas=1.
43. `storage=0` → `FILE`.
44. Created stream has `discard=DiscardOld`, `duplicates=120s`, `allow_direct=True`.
45. `retention != LIMITS` → `max_msgs_per_subject`, `discard_new_per_subject`, `allow_rollup`, `deny_delete`, `deny_purge` silently dropped.
46. `add_subjects("a","a")` is idempotent.
47. `remove_subjects(<all>)` → `ErrInvalidArgument` + details `{"reason": "cannot remove all subjects"}`.
48. `set_subjects([])` → `ErrInvalidArgument`.
49. `publish("", msg)` → `ErrInvalidSubject`.
50. `publish(subj, None)` → `ErrInvalidMessage`.
51. `publish(subj, msg)` with oversized payload → `ErrMessageTooLarge`.
52. `publish` with `js=None` → `ErrJetStreamNotEnabled`.
53. `publish` after `close` → `ErrConnectionClosed`.
54. `publish` with no ctx deadline applies 10s timeout.
55. `publish` with `Nats-Msg-Id` set engages dedup (verify second publish of different payload, same id, within 2m returns same sequence).
56. `publish_async` returns immediately; `await future` blocks until ack.
57. `publish_async` after `close` → future errors with `ErrConnectionClosed`.
58. `publish_async` with `js=None` → future errors with `ErrJetStreamNotEnabled`.
59. `PubAck` returned has `stream`, `sequence`, `domain` matching server.
60. `Publisher.close` is idempotent.
61. `Publisher.close` calls `nc.flush(5s)` when ctx has no deadline.
62. Middleware via `use_middleware` runs around terminal `js.publish_msg` (verify spy sees msg before publish, after ack).
63. Two `use_middleware` calls compose left-to-right (first registered = outermost).
64. `create_consumer` with empty `stream` or `name` → `"consumer: stream and name are required"`.
65. Created consumer has `ack_policy=AckExplicit`, `durable=name`.
66. Defaults: `ack_wait=30s`, `max_deliver=5`, `max_ack_pending=1000` when caller passes 0.
67. `create_consumer` is actually create-or-update (idempotent).
68. `Consumer.start(handler)` invokes per-msg; return None Acks, raise Naks.
69. After raise + Nak, message redelivered up to `max_deliver` times.
70. Cancelling ctx between deliveries Naks next message without invoking handler.
71. `Consumer.stop` is idempotent.
72. `start` after `stop` → error (Go: `"consumer stopped"`; Python: `ErrClosed`).
73. `Consumer.delete` calls `stop` then `js.delete_consumer`.
74. `Consumer.next` on empty queue with no-wait → `"no messages available"`.
75. `create_tenant_consumer` with stream=`"INCIDENTS"`, module=`"processor"`, tenant_id=`"tenant1"`, empty filters → consumer named `"processor-tenant1"`, filter_subjects=`["INCIDENTS.tenant1.>"]`.
76. `create_tenant_consumer` with explicit filters overrides default.
77. Any of `stream`/`module`/`tenant_id` empty → `"consumer: stream, module, and tenant_id are required"`.
78. `consumer_name("a","b")` returns exactly `"a-b"`.
79. Ack failures logged at WARN (verify via log capture).
80. `new_requester` with any required field empty → corresponding `"requester: ..."` error.
81. Defaults: `request_timeout=30s` if 0; `inactive_threshold=300s` if 0.
82. Reply consumer: name=`"reply-{instance_id}"`, filter=`["{prefix}.{instance_id}.>"]`, ack=AckExplicit, deliver=ALL, max_ack_pending=1024, no Durable.
83. If consume() fails after consumer creation → consumer is deleted (no orphan).
84. `request(subj, msg)` sets `msg.headers["X-Reply-To"] = "{prefix}.{instance_id}.{request_id}"`.
85. `request_id` format `"{instance_id}-{ns_unix}-{seq}"`; seq monotonic per Requester.
86. `request` after `close` → `ErrClosed`.
87. `request` ctx deadline expires → `ErrRequestTimeout` (NOT ctx err).
88. Reply with no `X-Status-Code` → `ok()=True`, `status_code=200`.
89. Reply with `X-Status-Code=404`, `X-Message="not found"` → `ok()=False`, `err.message=="status 404: not found"`.
90. Reply with `X-Status-Code=500`, no `X-Message` → `err.message=="status 500: request failed"`.
91. Reply with `X-Status-Code="abc"` (non-int) → silently `status_code=200`.
92. Late reply → acked + dropped + warn `"requester: no pending request for reply"`.
93. Reply with subject not matching prefix → acked + warn `"requester: unknown reply subject"`.
94. `Requester.close` is idempotent; closes internal Publisher.
95. `Requester.close` does NOT call `delete_consumer`.
96. Concurrent `request` and `close`: Request returns reply OR `ErrClosed`, never panics.

### 14.7 events/stores
97. (See §8.5 97-107.)

### 14.8 events/middleware
108. Composition: first registered is outermost wrapper.
109. `chain(*ms)` reduces in reverse so registration order = execution order.
110. Publish and subscribe lists are independent.
111. CB transitions: 5 failures → OPEN; wait timeout, next call → HALF_OPEN; 2 successes → CLOSED.
112. CB failure in HALF_OPEN → immediate OPEN.
113. CB defaults: 5 failures, 2 successes, 30s timeout.
114. CB negative/zero config values coerced to defaults.
115. `OnStateChange` fires on every transition, never twice for the same.
116. `ErrCircuitOpen` chains to `ErrPublishFailed`.
117. `MultiCircuitBreaker.get(k)` is goroutine-safe (lazy create via concurrent dict).
118. Retry: `max_attempts=3` ⇒ at most 4 total invocations.
119. Backoff sequence at defaults: ~100ms, ~200ms, ~400ms (within ±10%).
120. `jitter=0` ⇒ deterministic backoff; floor not enforced.
121. Non-retryable error (`ErrInvalidSubject`) ⇒ no retry.
122. `with_should_retry(custom)` overrides default classifier.
123. `intercept_subscribe` is pass-through.
124. Negative `attempt` normalized to 0.
125. RL token bucket: starts with `burst` tokens; first `burst` calls succeed; next fails until refill.
126. RL `AllowN` is atomic.
127. RL `wait(ctx)` returns ctx err on cancel.
128. Per-subject independent caps.
129. Sliding window: limit=10, window=1s — 10 calls at t=0 OK; 11th fails; 11th OK at t=1.1s.
130. RL constructor coerces `rate<=0 → 100`, `burst<=0 → int(rate)`.
131. Metrics counters increment on every call; error counters only on err.
132. `reset()` zeros counters but doesn't detach callbacks.
133. Per-subject metrics independent.
134. OTEL labels include `subject`; no other dims.
135. Histogram observes milliseconds (not seconds).
136. Logging default level INFO drops Debug pre-call logs.
137. Payload disabled by default; enabling truncates at exactly `max_payload_size` with `"..."` suffix.
138. Trace fields populated only when ctx has `core.TraceContext`.
139. `msg_id` field present even if header missing (will be `""`).
140. `latency_ms`/`process_time_ms` are integer ms.
141. OTEL log bridge passes `context.Background()` (mirror Go).
142. Tracing publish produces span `"events.publish"` PRODUCER kind with `messaging.system="nats"`, `messaging.destination=<subject>`, `messaging.operation="publish"`.
143. Tracing subscribe produces span `"events.receive"` CONSUMER kind with same attrs.
144. Outgoing message has `X-Trace-ID` + `X-Span-ID` headers.
145. Inbound headers populate `core.TraceContext` in ctx for handler.
146. W3C parser rejects strings shorter than 55 bytes.
147. W3C formatter returns `""` for incomplete TraceContext.
148. Manual mode preserves trace ID across child operations; assigns parent_id to prior span_id.
149. Default sampler is "always sample".
150. Default ID generator is 32-hex (128-bit; Known issue; mirror).
151. Composition: tracing must be outermost (verify logging sees `trace_id`/`span_id`).
152. Composition: retry inside CB (verify CB sees one logical failure per call, not N).
153. Composition: rate-limit reject + retry — without filter, retry hammers limiter.
154. RL Wait mode never returns `ErrRateLimitExceeded`; always blocks/ctx-err.
155. Subscribe path: retry has no effect (pass-through).

### 14.9 OTel
156. Resource attrs: `service.name`, `service.version`, `deployment.environment` from §11.3.
157. Default propagators: composite of `tracecontext` + `baggage` if config empty.
158. Sampler: ratio<=0 → ALWAYS_OFF; >=1 → ALWAYS_ON; else ratio-based.
159. Sampler is wrapped in `ParentBased`.
160. All NATS span names match §10.4 byte-exact.
161. Metrics names match §9.5 byte-exact.
162. Histogram unit is `"ms"`.
163. Log fields `service`, `version`, `env` auto-attached.
164. Log fields `trace_id`, `span_id` auto-extracted from ctx.

### 14.10 Configuration
165. `EventsConfig` validates servers (scheme + non-empty).
166. Reconnect timing constraints enforced (initial>0, max>=initial, multiplier>=1.0, jitter∈[0,1]).
167. TLS validation: cert+key paired; files exist if any of cert/key/ca set.
168. Env precedence: env > YAML > defaults.
169. `LoadWithEnv(dir, env)` merges `config.yaml` + `config.<env>.yaml`.
170. **Python improvement**: Logger/Metrics/Tracer config validates (Go side is stub-validated).

---

## 15. Known issues / recommended divergences

These are real defects or omissions in the Go SDK. The Python port should usually mirror for byte compatibility, but several are flagged as fix-up candidates.

### MIRROR (preserve for byte compatibility)
1. `Stream.discard` hard-coded to `DiscardOld`.
2. `Stream.duplicates` hard-coded to 2 minutes.
3. `Stream.allow_direct` hard-coded to True.
4. `traceparent` is **not parsed** on subscribe side — only `X-Trace-ID`/`X-B3-TraceId` consulted. Mirror but flag.
5. `HeaderB3ParentSpanID` constant exists but never written/read. Dead constant; expose for compatibility.
6. `Metadata.timestamp` and `Metadata.custom` are NOT auto-propagated to headers.
7. Span IDs are 128-bit (32 hex), not W3C-standard 64-bit (16 hex).
8. `messaging.destination` (deprecated semconv key) is used; not `messaging.destination.name`.
9. `events_*` metrics get prefixed with `service_name` from registry namespace.
10. Histogram unit is `"ms"`, not `"s"`.
11. `Subscriber.unsubscribe` named "unsubscribe" but actually calls `drain()`.
12. `Subscriber.close` swallows drain errors (logged, not returned).
13. `BatchPublisher.add` triggers synchronous flush on caller's coroutine using fresh ctx.
14. `BatchPublisher` has no max-buffer-size cap.
15. `Publisher.max_payload` stored but not enforced in `publish` (relies on NATS).
16. `Publisher.publish_async` skips pre-validation that sync `publish` does.
17. `Publisher.publish_async` has no caller-side concurrency limit.
18. `create_consumer` is actually create-or-update (naming mismatch with `create_stream`).
19. `Consumer` doesn't expose `InProgress`/`Term` to handler.
20. `Requester.close` does NOT delete the ephemeral consumer (relies on `inactive_threshold`).
21. `Requester` drops late replies silently (channel buffered 1, request entry already removed).
22. `RetryMiddleware.executeWithRetry` returns `last_err` (not `ctx.err`) when ctx fires during backoff sleep.
23. CB has no `HalfOpenMaxRequests` cap (despite doc.go mentioning it).
24. `ErrCircuitOpen` and `ErrRateLimitExceeded` both wrap retryable `ErrPublishFailed` — retry middleware outside them will retry.
25. `MetricsCollector.intercept_subscribe` increments `receive_count` BEFORE `next` (asymmetric with publish).
26. Tenant default filter uses **stream name** as leading subject token: `"{Stream}.{TenantID}.>"`.
27. `nil`-`js` errors are non-sentinel in stream factory + consumer factory paths (vs publisher uses sentinel).

### FIX in Python port (improve)
28. **Add** `messaging.system="nats"` and `messaging.operation` to inner spans (`nats.publish`, `nats.receive`, `jetstream.publish`).
29. **Add** spans for JS Consumer, KV, ObjectStore operations.
30. **Add** OTel-native producer→consumer span linking via `propagator.extract` on inbound headers.
31. **Add** validation to `Logger`/`Metrics`/`Tracer` config (Go's `Validate()` is stub).
32. **Add** TenantID type with `__post_init__` validation (length, regex). Go has no enforcement.
33. **Add** tenant-aware wrappers for KV / Object stores. Go leaves to caller.
34. **Add** per-error-class metric labels (`error_kind`).
35. **Add** connection-state metrics (disconnect / reconnect / closed).
36. **Add** retry-attempt counter.
37. **Add** CB state-transition counter.
38. **Add** rate-limit hit/wait histograms.
39. **Drop** `prometheus_*` config fields (unwired in Go).
40. **Accept** OTel-standard env vars (`OTEL_EXPORTER_OTLP_ENDPOINT`, etc.) in addition to Go-style prefixes.
41. **Unify** `EventsConfig` and `ConnectionConfig` (Go has them as separate structs with different defaults).
42. **Add** opt-in deterministic codec mode (sort map keys) — and coordinate with Go side.
43. **Decide explicitly**: sync flush during async batch trigger? Pre-validation in `publish_async`? Fix the `Subscriber.unsubscribe` naming?

---

## 16. Open questions for the Go team

Resolve before locking the Python port:

1. **TenantID validation rules.** Stricter than Go is fine, but agree on a regex (`^[A-Za-z0-9][A-Za-z0-9_-]*$`?) and length (`<=128`?). Should Go also enforce?
2. **Deterministic codec.** If Python adds `deterministic=True`, will Go match? Cross-language hash compatibility requires both.
3. **Schema versioning.** Add `X-Schema-Version` header? Or stay versionless? Decide before Python ships.
4. **Span ID width.** Move to W3C-standard 64-bit, or keep 128-bit for compatibility with deployed traces?
5. **Consumer span parenting.** Fix the missing `propagator.extract` call in Go, or document as intentional?
6. **CB half-open cap.** Add `HalfOpenMaxRequests` (matching doc.go) or remove from doc?
7. **`messaging.destination` vs `messaging.destination.name`.** Move to current semconv on both sides?
8. **Stores OTel.** Add spans/metrics in Go, or accept Python-only divergence?
9. **Tenant-aware KV/Object stores.** Owned by Python only, or backport to Go?
10. **`create_consumer` vs `create_or_update_consumer` naming.** Rename in Go or split?
11. **`Subscriber.unsubscribe` actually drains.** Rename to `remove`/`drop`, or document?
12. **Deprecated `BatchPublisher.add` ctx behavior** (uses fresh background ctx for size-trigger flush). Honor caller ctx instead?

---

## 17. Appendix: source-of-truth files

```
src/motadatagosdk/
├── events/
│   ├── core/
│   │   ├── core.go              # Header constants, TraceContext, Metadata, ExtractHeaders, InjectContext
│   │   ├── messaging.go         # Publisher, Subscriber, Subscription, MessageHandler interfaces
│   │   └── README.md
│   ├── corenats/
│   │   ├── publisher.go
│   │   ├── batch_publisher.go
│   │   ├── subscriber.go
│   │   └── README.md
│   ├── jetstream/
│   │   ├── stream.go
│   │   ├── publisher.go
│   │   ├── consumer.go
│   │   ├── requester.go
│   │   └── README.md
│   ├── stores/
│   │   ├── kv.go
│   │   ├── objectstore.go
│   │   └── README.md
│   ├── middleware/
│   │   ├── middleware.go        # Stack, Chain, Interceptor
│   │   ├── circuitbreaker.go
│   │   ├── retry.go
│   │   ├── ratelimit.go
│   │   ├── metrics.go
│   │   ├── logging.go
│   │   ├── tracing.go
│   │   └── README.md
│   └── utils/
│       ├── errors.go            # All sentinel errors with byte-exact strings
│       └── const.go
├── core/
│   ├── codec/
│   │   ├── codec.go             # Encoder enum, BuildHeader, ParseHeader
│   │   ├── packer.go            # PackMap, PackArray, custom encoder
│   │   ├── unpacker.go          # UnpackMap, UnpackArray
│   │   └── README.md
│   └── types/
│       ├── types.go             # Generic constraints; NOT envelope (despite directory name)
│       ├── slices.go
│       ├── map.go
│       └── ...
├── otel/
│   ├── common/                  # ServiceInfo, ResolveProtocol, ShutdownCollector
│   ├── tracer/                  # Init, Start, StartProducer, StartConsumer, W3C helpers
│   ├── metrics/                 # Init, Counter, Gauge, Histogram, Timer
│   └── logger/                  # Init, levels, structured fields, OTEL bridge
├── config/
│   ├── config.go                # Service / Logger / Metrics / Tracer
│   ├── events_config.go         # EventsConfig (env-only)
│   ├── loader.go
│   ├── events_loader.go
│   └── events_options.go
└── utils/                       # Top-level utils (codec errors, WrapErr)
    └── errors.go
```

---

**END OF TPRD.**

Generated 2026-05-01 from `motadata-go-sdk` current on-disk state. If a Python team starts implementation, treat this document as a starting contract: each numbered conformance check should be a test; each "Known issue" should be a code-review reference. Open questions in §16 should be resolved with the Go team before locking sentinel error strings, header names, or wire-format bytes — those are the parts that, once shipped, cannot evolve without coordinated upgrades across the fleet.
