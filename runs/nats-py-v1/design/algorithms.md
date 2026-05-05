# Algorithms (D1) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead` (acting in `algorithm-designer` role).

## A1. Custom binary codec encoding (TPRD §4.3.1)

### A1.1 `pack_map(d, CUSTOM)`

```
in: d: dict[str, V], where V ∈ {bool, int, float, str, bytes, datetime, timedelta, list, dict}
out: bytes

if len(d) > 65535: raise ErrDataTooLarge
buf = bytearray()
buf.append(0x00)                    # header byte = CUSTOM
buf.extend(uint16_le(len(d)))       # count
buf.append(0x0F)                    # MAP tag
for k, v in d.items():
    if not isinstance(k, str): raise ErrUnsupportedDataType
    kb = k.encode('utf-8')
    if len(kb) > 65535: raise ErrDataTooLarge
    buf.extend(uint16_le(len(kb)))
    buf.extend(kb)
    tag, payload = _encode_value(v)
    buf.append(tag)
    buf.extend(payload)
return bytes(buf)

complexity: O(N) where N = sum(field-payload sizes); bounded.
allocs: dominated by ascii_encode + uint16_le + struct.pack per field — ~3 per field.
budget: see perf-budget.md Section A row 1 (10-field 30µs / 30 allocs).
```

### A1.2 `_encode_value(v)` — width selection for int

Mirrors Go `getDataTypeINT64` exactly:

```
boundaries: ±2^7, ±2^15, ±2^23, ±2^31, ±2^39, ±2^47, ±2^55, else 64-bit
```

Implementation as a static table lookup (`bisect` over `[2**7, 2**15, 2**23, ...]`) → tag → struct format string. Single dispatch.

For float: always FLOAT64 unless caller passes a `numpy.float32` (which we DON'T support — strings, ints, floats, bytes, lists, dicts, datetimes, timedeltas only). FLOAT32 tag is reserved for round-trip from Go; our encoder never emits it.

### A1.3 `unpack_map(b)` — defer-recover analog

```
try:
    if len(b) < 1: raise ErrUnpackFailed
    if b[0] != 0x00: raise ErrUnsupportedCodec(f"unsupported codec type: 0x{b[0]:02x}")
    pos = 1
    count = uint16_le_decode(b, pos); pos += 2
    if b[pos] != 0x0F: raise ErrUnpackFailed
    pos += 1
    out = {}
    for _ in range(count):
        klen = uint16_le_decode(b, pos); pos += 2
        k = b[pos:pos+klen].decode('utf-8'); pos += klen
        tag = b[pos]; pos += 1
        v, pos = _decode_value(b, pos, tag)
        out[k] = v
    return out
except (IndexError, UnicodeDecodeError, struct.error, ValueError) as e:
    # SEC-7 fix (H5-rev-3 D3 iter 2): added ValueError. msgpack-python raises
    # ValueError on cap violations (e.g., array32 length-prefix exceeds
    # max_array_len). Verified empirically by security-devil iter-2: crafted
    # array32 declaring 1M entries triggers ValueError(1048576 exceeds
    # max_array_len(65536)), NOT msgpack.UnpackException. Catch at the codec
    # boundary so callers see one sentinel class. Option A from the SEC-7
    # remediation menu: extend the except clause (more honest than mapping
    # ValueError → UnpackException inside the wrapper).
    raise ErrUnpackFailed from e

complexity: O(N) bytes consumed; bounded by len(b).
allocs: per-field bytes-slice + decode result — ~3 per field; budget 35 for 10-field.
```

### A1.4 Worked-byte test fixtures (LOCKED at design — verified by §14.2 checks 13-17)

| Test fixture | Bytes (hex) | Length |
|---|---|---|
| `pack_map({}, CUSTOM)` | `00 00 00 0F` | 4 |
| `pack_array([], CUSTOM)` | `00 00 00 0D` | 4 |
| `pack_map({"k":"v"}, CUSTOM)` | `00 01 00 0F 01 00 6B 0C 01 00 00 00 76` | 13 |
| `pack_map({}, MSGPACK)` | `01 80` | 2 |
| `pack_array([], MSGPACK)` | `01 90` | 2 |

These appear as `pytest.param(...)` rows in `tests/unit/codec/test_byte_fixtures.py`.

## A2. ExtractHeaders priority order (TPRD §4.2)

```
def extract_headers(headers):
    headers = headers if headers is not None else {}
    if (tid := get_tenant_id()): headers[HEADER_TENANT_ID] = tid

    # Trace headers — OTel-active path takes priority
    span = trace.get_current_span()
    sc = span.get_span_context()
    if sc.is_valid:
        # OTel-active: emit ALL 5 trace keys + traceparent (always sampled flag "01")
        trace_id_hex = format(sc.trace_id, "032x")
        span_id_hex = format(sc.span_id, "032x")  # MIRROR Go: 32-hex span (Known issue Q4)
        headers[HEADER_TRACE_ID] = trace_id_hex
        headers[HEADER_B3_TRACE_ID] = trace_id_hex
        headers[HEADER_SPAN_ID] = span_id_hex
        headers[HEADER_B3_SPAN_ID] = span_id_hex
        headers[HEADER_B3_SAMPLED] = "1"
        headers[HEADER_TRACEPARENT] = f"00-{trace_id_hex}-{span_id_hex}-01"
        # NOTE: returns immediately; manual TraceContext NOT consulted (mirror Go).
    elif (tc := get_trace_context()):
        # Manual TraceContext: same shape, sampled-conditional
        headers[HEADER_TRACE_ID] = tc.trace_id
        headers[HEADER_B3_TRACE_ID] = tc.trace_id
        headers[HEADER_SPAN_ID] = tc.span_id
        headers[HEADER_B3_SPAN_ID] = tc.span_id
        if tc.sampled: headers[HEADER_B3_SAMPLED] = "1"
        flag = "01" if tc.sampled else "00"
        headers[HEADER_TRACEPARENT] = f"00-{tc.trace_id}-{tc.span_id}-{flag}"
        if tc.state: headers[HEADER_TRACESTATE] = tc.state

    if (cid := get_correlation_id()): headers[HEADER_CORRELATION_ID] = cid
    if (mid := get_message_id()): headers[HEADER_MESSAGE_ID] = mid
    if (rt := get_reply_to()): headers[HEADER_REPLY_TO] = rt
    return headers
```

Order is REPRODUCED verbatim from §4.2; conformance check 2-6 enforce.

## A3. InjectContext (TPRD §4.2)

```
def inject_context(headers):
    if headers is None: return                 # check 11
    if (tid := headers.get(HEADER_TENANT_ID)):
        set_tenant_id(tid)
    trace_id = headers.get(HEADER_TRACE_ID) or headers.get(HEADER_B3_TRACE_ID, "")
    span_id = headers.get(HEADER_SPAN_ID) or headers.get(HEADER_B3_SPAN_ID, "")
    sampled = headers.get(HEADER_B3_SAMPLED) in ("1", "true")
    state = headers.get(HEADER_TRACESTATE, "")
    if trace_id or span_id:
        set_trace_context(TraceContext(
            trace_id=trace_id, span_id=span_id, sampled=sampled, state=state))
    if (cid := headers.get(HEADER_CORRELATION_ID)): set_correlation_id(cid)
    if (mid := headers.get(HEADER_MESSAGE_ID)): set_message_id(mid)
    if (rt := headers.get(HEADER_REPLY_TO)): set_reply_to(rt)
    # CRITICAL: traceparent is NOT parsed (mirror Go bug; check 10).
```

## A4. Retry backoff (TPRD §9.3) — must match exactly

```
def compute_backoff(attempt: int, cfg: RetryConfig) -> float:
    attempt = max(0, attempt)                                    # check 124
    backoff = cfg.initial_interval * (cfg.multiplier ** attempt) # step 1
    if backoff > cfg.max_interval:                               # step 2
        backoff = cfg.max_interval
    if cfg.jitter > 0:                                           # step 3 (only if jitter > 0)
        rng = secrets.SystemRandom()
        try:
            r = rng.random()  # uniform [0, 1)
        except OSError:
            r = 0.5  # fallback (matches Go behavior; jitter contribution = 0)
        jitter_range = backoff * cfg.jitter
        jitter_val = jitter_range * (r * 2 - 1)  # uniform [-range, +range)
        backoff += jitter_val
        if backoff < cfg.initial_interval:                       # step 4 (floor only when jitter)
            backoff = cfg.initial_interval
    return backoff
```

Default schedule (initial=0.1, mult=2, max=5, jitter=0.1, max_attempts=3):

| Attempt failed | Wait (no jitter) | Wait (with jitter) |
|---|---|---|
| 0 | 0.1s | [0.09, 0.11) |
| 1 | 0.2s | [0.18, 0.22) |
| 2 | 0.4s | [0.36, 0.44) |
| 3 | (return last_err) | (return last_err) |

Verified by check 119 (jitter on, ±10%) and check 120 (jitter=0, deterministic).

## A5. Token bucket refill (TPRD §9.4)

```
def _refill_locked(self, now_ns: int):
    elapsed_s = (now_ns - self._last_update_ns) / 1e9
    if elapsed_s <= 0: return
    new_tokens = elapsed_s * self._cfg.rate * 1000  # milliTokens
    self._milli_tokens = min(
        self._milli_tokens + int(new_tokens),
        self._cfg.burst * 1000,
    )
    self._last_update_ns = now_ns

async def allow_n(self, n: int = 1) -> bool:
    needed = n * 1000  # milliTokens
    async with self._lock:
        self._refill_locked(time.monotonic_ns())
        if self._milli_tokens < needed: return False
        self._milli_tokens -= needed
        return True
```

`burst <= 0` in cfg → `cfg.burst = max(1, int(cfg.rate))`. `rate <= 0` → `cfg.rate = 100.0`. Verified by check 130.

## A6. Sliding window (TPRD §9.4)

```
def allow(self) -> bool:
    now_ns = time.monotonic_ns()
    cutoff = now_ns - int(self._window * 1e9)
    # Prune leading expired
    while self._requests and self._requests[0] <= cutoff:
        self._requests.popleft()
    if len(self._requests) >= self._limit:
        return False
    self._requests.append(now_ns)
    return True
```

`deque[int]` with `popleft()` for O(1) front-removal. Worst-case prune is O(window/avg_interval); amortized O(1). Bench shown at perf-budget §F row 9.

## A7. Circuit breaker state machine (TPRD §9.2)

```
async def allow(self):
    async with self._lock:
        if self._state == State.CLOSED:
            return  # pass; on_success/on_failure will be called by caller
        elif self._state == State.OPEN:
            elapsed = time.monotonic() - self._last_failure_time
            if elapsed > self._cfg.timeout:
                self._transition_to_locked(State.HALF_OPEN)
                return  # allow this call
            else:
                raise ErrCircuitOpen("circuit breaker open")
        elif self._state == State.HALF_OPEN:
            # NO HalfOpenMaxRequests cap (mirror Go gap; scope.md Q6)
            return

def on_success_locked(self):
    if self._state == State.CLOSED:
        self._failures = 0
    elif self._state == State.HALF_OPEN:
        self._successes += 1
        if self._successes >= self._cfg.success_threshold:
            self._transition_to_locked(State.CLOSED)

def on_failure_locked(self, err):
    if not self._cfg.should_trip(err):
        return
    if self._state == State.CLOSED:
        self._failures += 1
        if self._failures >= self._cfg.failure_threshold:
            self._last_failure_time = time.monotonic()
            self._transition_to_locked(State.OPEN)
    elif self._state == State.HALF_OPEN:
        # ANY failure in HALF_OPEN → OPEN immediately
        self._last_failure_time = time.monotonic()
        self._transition_to_locked(State.OPEN)

def _transition_to_locked(self, new_state):
    if new_state == self._state: return
    old = self._state
    self._state = new_state
    self._failures = 0
    self._successes = 0
    if self._cfg.on_state_change:
        self._cfg.on_state_change(old, new_state)
```

Verified by checks 111-115.

## A8. Subscriber callback wrapping (TPRD §6.4)

```
def subscribe(self, subject, handler):
    # ... ready check, span open ...
    cancel_event = asyncio.Event()
    middleware_chain = self._snapshot_subscribe_chain()  # tuple of mws
    wrapped = chain_subscribe(*middleware_chain)(handler)

    async def cb(msg):  # nats-py invokes via asyncio.create_task per msg
        if cancel_event.is_set():
            return  # drop; sub is being torn down
        with start_consumer(ctx, "nats.receive",
                            attrs={ATTR_MESSAGING_DESTINATION: subject}) as span:
            try:
                await wrapped(ctx, msg)
                span.set_ok()
            except BaseException as e:
                span.set_error(e)
                # Handler errors NOT propagated to NATS (no NAK in core NATS)

    nats_sub = await self._nc.subscribe(subject, cb=cb)
    sub = _Subscription(nats_sub, cancel_event)
    async with self._subs_lock:
        self._subs[id(nats_sub)] = sub
    LOG.info("NATS subscription created", subject=subject)
    return sub
```

Verified by checks 28-37.

## A9. Requester dispatch + reply-routing (TPRD §7.4)

```
async def _dispatch_loop(self):
    async for msg in self._consume_iter:  # raw nats-py consumer
        try:
            request_id = self._parse_request_id(msg.subject)
            if request_id is None:
                LOG.warn("requester: unknown reply subject", subject=msg.subject)
                await msg.ack()
                continue
            async with self._pending_lock:
                fut = self._pending.pop(request_id, None)
            if fut is None:
                LOG.warn("requester: no pending request for reply", request_id=request_id)
                await msg.ack()
                continue
            resp = self._build_response(msg)
            if not fut.cancelled():
                fut.set_result(resp)
            await msg.ack()
        except asyncio.CancelledError:
            break
        except Exception as e:
            LOG.error("requester: dispatch error", err=e)
            with contextlib.suppress(Exception):
                await msg.nak()

def _parse_request_id(self, subject):
    # subject = f"{prefix}.{instance_id}.{request_id}"
    # → request_id is anything after f"{prefix}.{instance_id}."
    expected_prefix = f"{self._cfg.reply_subject_prefix}.{self._cfg.instance_id}."
    if not subject.startswith(expected_prefix):
        return None
    return subject[len(expected_prefix):]

def _build_response(self, msg):
    if msg.headers is None:
        return Response(status_code=200, data=msg)
    sc = 200
    if (raw := msg.headers.get(HEADER_STATUS_CODE)) is not None:
        try:
            sc = int(raw)
        except ValueError:
            pass  # silently keep 200 (check 91)
    message = msg.headers.get(HEADER_MESSAGE, "")
    err = None
    if sc >= 400:
        err = Exception(f"status {sc}: {message or 'request failed'}")
    return Response(status_code=sc, message=message, data=msg, err=err)

def _next_request_id(self):
    return f"{self._cfg.instance_id}-{time.time_ns()}-{next(self._seq)}"
```

Verified by checks 84-93.

## A10. JetStream Consumer dispatch loop (TPRD §7.3)

```
async def _consume_loop(self, handler):
    # nats-py invokes the per-msg callback concurrently per delivered message;
    # we DO NOT spawn additional tasks. The dispatch logic is the wrapped handler.
    async def _dispatch(msg):
        if asyncio.current_task().cancelled():
            try: await msg.nak()
            except Exception as e: LOG.warn("consumer: nak failed on context cancellation",
                                            consumer=self._name, err=e)
            return
        try:
            await handler(ctx_from_msg(msg), msg)  # ack on success
            try: await msg.ack()
            except Exception as e: LOG.warn("consumer: ack failed", consumer=self._name, err=e)
        except BaseException as e:
            try: await msg.nak()
            except Exception as e2: LOG.warn("consumer: nak failed", consumer=self._name, err=e2)
    self._raw_psub = await self._js.pull_subscribe(...)
    # nats-py's consume() loop runs in the background; we await its disposal task.
    self._consume_task = asyncio.create_task(
        self._raw_psub.consume(_dispatch),
        name=f"consumer_dispatch_{self._name}",
    )
```

Per check 68-70: handler return None → ack; raise → nak; ctx.cancelled between deliveries → nak without invoking handler.

## A11. BatchPublisher concurrent flush (TPRD §6.3)

```
async def flush(self):
    async with self._buffer_lock:
        if not self._buffer: return None
        batch = self._buffer
        self._buffer = []  # swap; preserve cap
    if self._concurrent_flush:
        return await self._flush_concurrent(batch)
    else:
        return await self._flush_sequential(batch)

async def _flush_sequential(self, batch):
    errs = []
    for subj, msg in batch:
        try:
            await self._publisher.publish(subj, msg)
        except Exception as e:
            errs.append(e)
    return self._aggregate(errs)

async def _flush_concurrent(self, batch):
    n_workers = min(self._max_flush_workers, len(batch))
    sem = asyncio.Semaphore(n_workers)
    async def _bounded(subj, msg):
        async with sem:
            try: await self._publisher.publish(subj, msg)
            except Exception as e: return e
            return None
    results = await asyncio.gather(*[_bounded(s, m) for s, m in batch])
    errs = [r for r in results if r is not None]
    return self._aggregate(errs)

def _aggregate(self, errs):
    if not errs: return None
    if len(errs) == 1: return errs[0]
    return MultiError(errs)
```

Verified by checks 23-25.

## A12. Stream factory validation (TPRD §7.1)

```
async def create_stream(js, cfg):
    if js is None: raise ErrJetStreamNotEnabled  # Python uses sentinel; Go used string err
    if not cfg.name: raise ErrInvalidArgument(details={"reason": "name is required"})
    if not cfg.subjects: raise ErrInvalidArgument(details={"reason": "at least one subject is required"})
    with start_internal(ctx, "stream.create", attrs={"stream": cfg.name}) as span:
        try:
            replicas = max(1, cfg.replicas)
            storage = cfg.storage if cfg.storage in (StorageType.FILE, StorageType.MEMORY) else StorageType.FILE
            raw_cfg = nats.js.api.StreamConfig(
                name=cfg.name,
                subjects=cfg.subjects,
                retention=_retention_to_raw(cfg.retention),
                # ... map other fields ...
                discard=nats.js.api.DiscardPolicy.OLD,           # HARD-CODED INV-8
                duplicate_window=120.0,                          # HARD-CODED INV-8
                allow_direct=True,                               # HARD-CODED INV-8
                replicas=replicas,
                storage=_storage_to_raw(storage),
            )
            # Drop limits-only fields if retention != LIMITS (mirror Go silently-dropped)
            if cfg.retention != Retention.LIMITS:
                raw_cfg.max_msgs_per_subject = 0
                raw_cfg.discard_new_per_subject = False
                # ... etc.
            info = await js.add_stream(raw_cfg)  # Fails on existing stream
            span.set_ok()
            LOG.info("stream created", stream=cfg.name)
            return Stream(js, info)
        except BaseException as e:
            span.set_error(e); raise
```

Verified by checks 38-48.

## A13. Header-byte dispatch in `unpack` facade

```
def unpack_map(buf):
    if len(buf) < 1: raise ErrUnpackFailed
    enc = buf[0]
    if enc == 0x00: return _unpack_map_custom(buf[1:])
    if enc == 0x01: return _unpack_map_msgpack(buf[1:])
    raise ErrUnsupportedCodec(f"unsupported codec type: 0x{enc:02x}")
```

`_unpack_map_msgpack(b)` — MUST go through the SEC-2 wrapper:
```
return _unpack_with_caps(b)
# msgpack handles all defer-recover semantics internally; on failure it raises
# msgpack.exceptions.UnpackException — we re-raise as ErrUnpackFailed.
# The DoS caps below (§A16) prevent attacker-controlled length fields from
# triggering pre-allocation OOM.
```

See §A16 for the `_unpack_with_caps` body and the cap rationale.

## A14. W3C traceparent helpers (TPRD §9.7)

```
def extract_w3c_traceparent(s):
    if len(s) < 55: return None
    parts = s.split("-")
    if len(parts) != 4: return None
    version, trace_id, span_id, flags = parts
    sampled = flags == "01"
    return TraceContext(trace_id=trace_id, span_id=span_id, sampled=sampled)

def format_w3c_traceparent(tc):
    if tc is None or not tc.trace_id or not tc.span_id: return ""
    flag = "01" if tc.sampled else "00"
    return f"00-{tc.trace_id}-{tc.span_id}-{flag}"
```

Verified by checks 146-147.

## A15. Config YAML loading — `yaml.safe_load` ONLY (SEC-1 D3 fix loop iter 1)

**Hard prescription**: every YAML parse in `motadata_py_sdk.config` MUST use
`yaml.safe_load(stream)`. The following loaders are BANNED at impl-review
time (`sdk-security-devil` enforces):

| Banned API | Why |
|---|---|
| `yaml.load(stream)` | Default loader is `Loader=yaml.Loader` (full); arbitrary type construction. |
| `yaml.load(stream, Loader=yaml.Loader)` | Same as above. |
| `yaml.load(stream, Loader=yaml.FullLoader)` | FullLoader still permits `!!python/object` tags via `yaml.YAMLObject` subclasses. |
| `yaml.load(stream, Loader=yaml.UnsafeLoader)` | Explicitly unsafe. |
| `yaml.full_load(stream)` | Convenience alias for FullLoader. |
| `yaml.unsafe_load(stream)` | Convenience alias for UnsafeLoader. |

**Allowed**: `yaml.safe_load(stream)` — restricts to YAML's standard tag
set (str, int, float, bool, null, list, dict, datetime, binary). No
arbitrary Python object construction.

**Algorithm** (config loader, mirrors §A12 stream-validation pattern):

```
def load(*, dir=None, env=None) -> Settings:
    yaml_overlays: list[dict] = []
    if dir is not None:
        base = Path(dir) / "config.yaml"
        if base.exists():
            with base.open("rb") as f:
                # SECURITY: safe_load ONLY; full_load = RCE.
                doc = yaml.safe_load(f) or {}
            yaml_overlays.append(_expand_env(doc))
        if env is not None:
            envf = Path(dir) / f"config.{env}.yaml"
            if envf.exists():
                with envf.open("rb") as f:
                    doc = yaml.safe_load(f) or {}
                yaml_overlays.append(_expand_env(doc))
    # Merge: later overlay wins per-key. Then env-var precedence applied
    # by pydantic-settings (env wins over YAML).
    return Settings.model_validate(_deep_merge_then_env(yaml_overlays))
```

**Rationale**: pyyaml's full loader supports tags like
`!!python/object/apply:os.system [["rm", "-rf", "/"]]` which deserialize
into live Python `subprocess.call`-equivalent constructions at parse time.
An attacker who can write a config.yaml on the deploy host has RCE.
`safe_load` is the Python equivalent of Go's `gopkg.in/yaml.v3 Unmarshal`
default behavior (safe; no type-construction).

**Cross-language MIRROR**: Go uses `gopkg.in/yaml.v3` `yaml.Unmarshal`
which is safe-by-default. `yaml.safe_load` IS the Python mirror of that
behavior. No FIX-divergence.

**Impl-review enforcement**: `sdk-security-devil` runs at M1 + M3.5 with a
grep gate: any occurrence of `yaml.load(`, `yaml.full_load(`,
`yaml.unsafe_load(`, `yaml.Loader`, `yaml.FullLoader`, `yaml.UnsafeLoader`
inside `src/motadata_py_sdk/config/` = BLOCKER.

## A16. msgpack DoS caps (SEC-2 D3 fix loop iter 1)

**Hard prescription**: every `msgpack.unpackb()` call inside
`motadata_py_sdk.codec` MUST go through `msgpack_unpack_safe(data)` (defined
in `src/motadata_py_sdk/codec/_msgpack.py`). Calling `msgpack.unpackb`
directly is BANNED at impl-review time (`sdk-security-devil` grep gate).

```
DEFAULT_MAX_MSG_BYTES   = 4 * 1024 * 1024   # 4 MiB; matches NATS default max_msg_size
DEFAULT_MAX_ARRAY_LEN   = 64 * 1024
DEFAULT_MAX_MAP_LEN     = 64 * 1024
DEFAULT_MAX_STR_LEN     = 256 * 1024
DEFAULT_MAX_BIN_LEN     = DEFAULT_MAX_MSG_BYTES

def msgpack_unpack_safe(data: bytes) -> Any:
    return msgpack.unpackb(
        data,
        max_str_len=DEFAULT_MAX_STR_LEN,
        max_bin_len=DEFAULT_MAX_BIN_LEN,
        max_array_len=DEFAULT_MAX_ARRAY_LEN,
        max_map_len=DEFAULT_MAX_MAP_LEN,
        raw=False,             # decode str → str, not str → bytes (matches §A13)
        timestamp=3,           # ext type -1 → datetime (matches Go vmihailenco v5 default)
        strict_map_key=False,  # matches §A13
    )
```

**Rationale**: without these caps, an attacker-controlled msgpack frame
declaring a 4-GiB string in the length prefix triggers a 4-GiB
pre-allocation in libmsgpack BEFORE the buffer-length-mismatch check fires
(msgpack-c eagerly resizes the output buffer based on declared length to
optimize the common-case single-pass decode). On a typical 16 GiB pod this
is an OOM kill. The caps cause an early `ValueError` exception which the
codec facade re-raises as `ErrUnpackFailed` per §A1.3.

**SEC-7 finding (H5-rev-3 D3 iter 2)**: msgpack-python raises `ValueError`
(NOT `msgpack.exceptions.UnpackException`) on cap violations. Verified
empirically: feeding a crafted array32 declaring 1M entries against
`max_array_len=65536` raises `ValueError("1048576 exceeds max_array_len(65536)")`.
The §A1.3 except clause therefore lists `ValueError` alongside
`(IndexError, UnicodeDecodeError, struct.error)`. We chose to extend the
except clause (Option A) rather than re-raise inside the wrapper as
`UnpackException` (Option B), because Option A is more honest — the
ValueError IS what msgpack raises; we map at the boundary.

**Why these specific values**:
- `4 MiB` matches the NATS server default `max_msg_size`. A larger codec
  payload couldn't have arrived through NATS in the first place; rejecting
  at the codec is defense-in-depth.
- `64 K array / map entries` is well above the 10-field benchmark
  (perf-budget.md Section A row 1) and any reasonable application
  payload, but small enough that 64K × 8-byte-pointers = 512 KiB worst
  case is within budget.
- `256 KiB string` accommodates JSON-shaped event bodies up to ~256 K of
  text per field; rare to exceed.
- `bin` cap = `msg` cap (binary blobs can be up to the full message).

**Cross-language MIRROR**: Go's `vmihailenco/msgpack v5` `Unmarshal` does
NOT have configurable per-container caps — the protection in Go comes from
NATS server-side `max_msg_size`. Python's `msgpack` library exposes these
caps explicitly because the C-extension's eager-allocation behavior is more
exploitable than Go's bytes-driven decode loop. So adding the caps in
Python IS a Python-idiomatic translation of Go's effective behavior, not a
FIX-divergence.

**Impl-review enforcement**: `sdk-security-devil` runs at M1 + M3.5 with a
grep gate: any occurrence of `msgpack.unpackb(` not inside the
`msgpack_unpack_safe` definition itself = BLOCKER. The wrapper is the
single chokepoint.

## A17. OTel tracing + metric conventions (TPRD §15.28 + §15.29 + §15.30 + §15.34)

**Authored at**: H5-rev-3 D3 iter 2 (2026-05-02). All four §15 FIX items
related to OTel are pre-authorized by the TPRD; this section is the
authoritative reference for impl.

### A17.1 Span attribute discipline (TPRD §15.28)

Every span produced by a Pub/Sub/JsPub/Consumer code path emits THREE
mandatory attributes (in addition to whatever else the path adds):

```
attributes = {
    "messaging.system": "nats",                # ALWAYS this exact string
    "messaging.destination": <subject>,         # NOT messaging.destination.name (mirror Go)
    "messaging.operation": <op>,                # 'publish' | 'receive' | 'process'
    ...                                         # path-specific attrs added afterward
}
```

Span-name → operation map:

| Span name | messaging.operation |
|---|---|
| `nats.publish` | `publish` |
| `nats.subscribe` | n/a (this is a setup span, not a per-msg op) |
| `nats.receive` | `receive` |
| `jetstream.publish` | `publish` |
| `jetstream.receive` | `receive` |
| `events.publish` (TracingMiddleware producer) | `publish` |
| `events.receive` (TracingMiddleware consumer) | `receive` |
| `kv.<op>` | (no messaging.operation; INTERNAL spans) |
| `objectstore.<op>` | (no messaging.operation; INTERNAL spans) |

### A17.2 Producer→consumer span linking (TPRD §15.30)

On the consumer side, BEFORE opening the consumer span, extract the producer
trace context from the inbound NATS headers:

```python
class NatsHeaderGetter:
    """TextMapGetter adapter for NATS msg.headers (per python-otel-instrumentation)."""
    def get(self, carrier: dict[str, str] | None, key: str) -> list[str]:
        if carrier is None: return []
        v = carrier.get(key)
        return [v] if v is not None else []
    def keys(self, carrier: dict[str, str] | None) -> list[str]:
        return list(carrier.keys()) if carrier else []

# In TracingMiddleware.intercept_subscribe wrapper:
parent_ctx = propagator.extract(
    carrier=msg.headers,
    getter=NatsHeaderGetter(),
)
with tracer.start_as_current_span(
    "events.receive",
    context=parent_ctx,                  # << remote-parent context
    kind=SpanKind.CONSUMER,
    attributes={
        "messaging.system": "nats",
        "messaging.destination": subject,
        "messaging.operation": "receive",
    },
) as span:
    ...
```

The propagator is the global TextMapPropagator (defaulted to W3C
tracecontext + baggage; configurable via `TracerInitConfig.propagators`).
After extract, the consumer span participates in the producer trace.

### A17.3 KV / ObjectStore span emission (TPRD §15.29)

Each KVStore / ObjectStore method opens an INTERNAL-kind span. Common
attribute set: `messaging.system='nats'` + `nats.bucket=<bucket>`. KV adds
`nats.key`; ObjectStore adds `nats.object`. Span overhead target: ≤1µs at
p50 (cached tracer per the python-otel-instrumentation lazy-meter pattern).
See perf-budget.md Section E rows added at H5-rev-3 D3 iter 2 + the
`bench_stores_kv_*` and `bench_stores_object_*` rows.

### A17.4 Per-error-class metric labels (TPRD §15.34)

Every `*_errors_total` counter increment carries an `error_kind` attribute:

```python
_publish_error_counter().add(1, {
    "messaging.destination": subject,
    "error_kind": type(exc).__name__,           # bounded sentinel name
})
```

**Bounded-cardinality discipline**: `error_kind` value is the SENTINEL CLASS
NAME ONLY (one of the 52-class hierarchy in events.utils + middleware +
codec + stores). NEVER `str(exc)` — that would inject unbounded payload-derived
strings into label cardinality. The python-otel-instrumentation skill enforces
this rule.

### A17.5 Configuration validation (TPRD §15.31)

`TracerInitConfig`, `MetricsInitConfig`, `LoggerInitConfig` all carry
`__post_init__` per `api.py.stub` §8. Validation is fail-fast at the boundary
between caller config and OTel SDK init — bad config raises `ValidationError`
before any provider is constructed. Go's `Validate()` is a stub; Python
tightens. The pydantic config models in §9 of `api.py.stub` rely on
pydantic's `model_validator(mode='after')` for the same effect (CONV-5
overlaps §15.31 — closing both with one round of validators).

## Algorithmic complexity summary (mirrors big-O column in perf-budget.md)

| Operation | Complexity | Note |
|---|---|---|
| pack/unpack map | O(N) bytes | bounded by msg size |
| extract/inject headers | O(1) | bounded by 8 keys |
| Subscriber dispatch | O(1) per-msg | nats-py concurrent |
| BatchPublisher.flush sequential | O(n) | n = batch size |
| BatchPublisher.flush concurrent | O(n / workers) | bounded by Semaphore |
| MultiCircuitBreaker.get cached | O(1) amortized | dict lookup |
| MultiCircuitBreaker.get lazy create | O(1) | one-shot |
| TokenBucketLimiter.allow_n | O(1) | refill is constant |
| SlidingWindowLimiter.allow | O(w) prune amortized O(1) | deque pop |
| Retry backoff compute | O(1) | no loops |
| Stream.create | O(1) | one RPC |
| Consumer dispatch loop | O(b) per pull | b = batch size |
| Requester request | O(1) | future + dispatch |
| KVStore.put / get / create / update | O(1) | one RPC |
| KVStore.watch | O(1) per emit | streaming |
| ObjectStore.put_file | O(n / chunk) | chunk_size = 128 KiB default |

`sdk-complexity-devil` will scaling-test rows with N ∈ {10, 100, 1000, 10000} at T5 and curve-fit per G107.
