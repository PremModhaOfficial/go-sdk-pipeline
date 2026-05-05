---
name: nats-python-client-patterns
description: >
  Use this when wiring an SDK component on top of `nats-py` v2.x — async connect with
  TLS / NKey / JWT credentials; core publish/subscribe/request; JetStream Stream /
  Publisher / pull-Consumer / Requester; KV bucket get/put/watch with optimistic
  CAS; ObjectStore put_file/get_file; NATS headers semantics (incl. JetStream
  `Nats-Msg-Id` dedup); graceful drain vs hard close; reconnect callbacks for
  circuit-breaker integration.
  Triggers: nats.connect, nc.publish, nc.subscribe, nc.request, jetstream, js.add_stream, js.pull_subscribe, ConsumerConfig, AckPolicy, KeyValueConfig, ObjectStoreConfig, msg.ack, msg.nak, msg.term, drain, NoRespondersError, msg.headers.
---

# nats-python-client-patterns (v1.0.0)

## Rationale

`nats-py` is the official async-only Python client. Wrapping it in an SDK is mostly about (a) keeping the `nc` and `js` (JetStream) handles co-owned by one client class, (b) bridging its callback-based subscription model to `asyncio.TaskGroup`-friendly handlers, (c) hooking its three `*_cb` connection callbacks into observability + circuit-breaker state, and (d) using `drain()` not `close()` for cooperative shutdown so in-flight handlers finish. Skip those four and you ship a client that loses messages on shutdown, can't recover from broker restarts, and silently swallows handler exceptions.

## Activation signals

- Adding any client to `motadata_py_sdk.events` that imports `nats`
- Designing a `Publisher` / `Subscriber` / `Stream` / `Consumer` / `Requester` per TPRD §6 / §7
- Wiring KV or ObjectStore wrappers per TPRD §8
- Reviewer cites "lost messages on close", "no reconnect handling", "blocking handler", "header dropped"
- Wiring OTel propagation through `msg.headers` (use with `python-otel-instrumentation`)

## Connect — Config + factory

```python
import asyncio, ssl
import nats
from nats.aio.client import Client as NatsClient

async def connect(cfg: NatsConfig) -> NatsClient:
    ssl_ctx = None
    if cfg.tls.enabled:
        ssl_ctx = ssl.create_default_context(purpose=ssl.Purpose.SERVER_AUTH)
        if cfg.tls.ca_path:
            ssl_ctx.load_verify_locations(cfg.tls.ca_path)
        if cfg.tls.cert_path and cfg.tls.key_path:
            ssl_ctx.load_cert_chain(certfile=cfg.tls.cert_path, keyfile=cfg.tls.key_path)
    return await nats.connect(
        servers=cfg.servers,
        name=cfg.client_name,
        user_credentials=cfg.creds_path,        # NKey/JWT .creds file
        tls=ssl_ctx,
        tls_hostname=cfg.tls.server_name,
        max_reconnect_attempts=cfg.max_reconnect_attempts,
        reconnect_time_wait=cfg.reconnect_time_wait_s,
        ping_interval=cfg.ping_interval_s,
        max_outstanding_pings=cfg.max_outstanding_pings,
        error_cb=cfg.on_error,
        disconnected_cb=cfg.on_disconnected,
        reconnected_cb=cfg.on_reconnected,
        closed_cb=cfg.on_closed,
    )
```

**Always** pass `name=` — the NATS server logs use it for connection identification, and dashboards group by it.

## Reconnect callbacks → circuit-breaker / metrics integration

`disconnected_cb` and `reconnected_cb` are the canonical hooks for integrating the SDK's `circuit-breaker-policy`. Don't sleep or block in them — they run on the loop thread:

```python
async def on_disconnected() -> None:
    breaker.record_failure()
    metrics_disconnects.add(1)

async def on_reconnected() -> None:
    breaker.reset()
    metrics_reconnects.add(1, {"endpoint": nc.connected_url.netloc})
```

`error_cb(e)` fires for protocol-level errors (slow-consumer warnings, auth failures); log with structured fields, never `print`.

## Publish + headers

```python
await nc.publish(subject, payload, headers={
    "Nats-Msg-Id": idempotency_key,            # JetStream dedup window
    "Content-Type": "application/msgpack",
    "X-Tenant-ID": tenant_id,
})
```

`Msg.headers` is `dict[str, str] | None`. ASCII keys + values, no comma-separated multi-values (use repeated headers if the broker version supports it). The OTel injector from `python-otel-instrumentation` writes into this same dict.

## Subscribe — async callback

```python
async def handler(msg: nats.aio.msg.Msg) -> None:
    try:
        await user_callback(msg)
    except Exception as e:
        log.exception("handler failed", extra={"subject": msg.subject})
        # core NATS has no ack; on JetStream call msg.nak()

sub = await nc.subscribe(subject, queue=queue_group, cb=handler, max_msgs=0)
```

Handlers run **serially per subscription** unless you fan out via `asyncio.create_task` (use the strong-ref pattern from `python-asyncio-patterns`). Slow handlers cause the broker to log "slow consumer" — surface that warning via `error_cb` and `backpressure-flow-control` policy.

## Request / Reply with timeout + NoResponders

```python
from nats.errors import TimeoutError as NatsTimeoutError, NoRespondersError

try:
    resp = await nc.request(subject, payload, timeout=cfg.request_timeout_s, headers=hdrs)
except NatsTimeoutError:
    raise ErrTimeout(...)             # map to SDK sentinel via network-error-classification
except NoRespondersError:
    raise ErrUnavailable(...)         # no listeners on subject; not retriable
```

## JetStream — Stream + pull-Consumer

```python
from nats.js.api import StreamConfig, ConsumerConfig, AckPolicy, RetentionPolicy

js = nc.jetstream()
await js.add_stream(StreamConfig(
    name="EVENTS",
    subjects=["events.>"],
    retention=RetentionPolicy.WORK_QUEUE,
    max_age=24 * 3600,
    max_bytes=10 * 1024 * 1024 * 1024,
    storage="file",
    num_replicas=3,
))

cfg = ConsumerConfig(
    durable_name="worker-1",
    ack_policy=AckPolicy.EXPLICIT,
    ack_wait=30,                 # seconds
    max_deliver=cfg.max_deliver, # then DLQ via deliver-on-fail subject
    filter_subject="events.user.*",
    max_ack_pending=cfg.in_flight,
)
psub = await js.pull_subscribe("events.>", durable="worker-1", config=cfg)

# Pull loop — blocks up to `timeout` for at least one message; heartbeat keeps long fetches alive
while not stopping.is_set():
    try:
        msgs = await psub.fetch(batch=cfg.batch, timeout=cfg.fetch_timeout_s,
                                 heartbeat=cfg.fetch_heartbeat_s)
    except NatsTimeoutError:
        continue                     # idle window; loop again
    async with asyncio.TaskGroup() as tg:
        for m in msgs:
            tg.create_task(_dispatch(m))   # ack/nak/term inside _dispatch
```

`_dispatch` MUST call exactly one of `await msg.ack()`, `await msg.nak(delay=N)`, `await msg.term()`, or `await msg.in_progress()` — silent return = redelivery after `ack_wait`.

`msg.metadata` exposes `.sequence.{stream,consumer}`, `.num_delivered`, `.timestamp`. Use `num_delivered` to drive `idempotent-retry-safety` decisions and the DLQ threshold.

## KV — optimistic CAS

```python
from nats.js.api import KeyValueConfig
from nats.js.errors import KeyWrongLastSequenceError, NotFoundError

kv = await js.create_key_value(KeyValueConfig(
    bucket="config", history=5, ttl=3600, max_bytes=100 << 20))

# read-modify-write with optimistic concurrency
entry = await kv.get("flag.x")        # entry.value, entry.revision
new_value = mutate(entry.value)
try:
    await kv.update("flag.x", new_value, last=entry.revision)
except KeyWrongLastSequenceError:
    raise ErrConflict(...)            # caller retries
```

`kv.watch(prefix)` returns an async-iterator that yields `None` once after the initial sync — treat that sentinel as "caught up" and start serving reads.

## ObjectStore — put_file / get_file

```python
from nats.js.api import ObjectStoreConfig

os_ = await js.create_object_store(config=ObjectStoreConfig(
    bucket="reports", description="...", max_bytes=10 << 30))
info = await os_.put_file("/path/to/local.pdf")        # auto-chunks at 128KB default
await os_.get_file(info.name, "/tmp/local.pdf")
await os_.delete(info.name)
```

For streaming: `put` accepts an `AsyncIterator[bytes]`; `get` returns one. Don't `read()` then `put` for files >100MB — use the streaming form.

## Graceful shutdown — `drain()` not `close()`

```python
async def aclose(self) -> None:
    """Cooperative shutdown: drain subs, then close. Idempotent via _closed flag."""
    if self._closed:
        return
    self._closed = True
    try:
        await asyncio.wait_for(self._nc.drain(), timeout=cfg.drain_timeout_s)
    except (asyncio.TimeoutError, nats.errors.ConnectionClosedError):
        await self._nc.close()
```

`drain()` semantics:
1. Sends UNSUB for every active subscription.
2. Waits for in-flight callback handlers to finish.
3. Flushes pending publishes.
4. Closes the connection.

Hard-`close()` interrupts in-flight handlers with `asyncio.CancelledError`. Reserve for deadline-exceeded paths.

For JetStream pull-consumers: set a `stopping = asyncio.Event()`; the fetch loop checks it before each `psub.fetch()`; `aclose()` sets the event and `await`s the consumer task. See `client-shutdown-lifecycle` for the SDK-wide contract.

## Pitfalls

1. **`close()` mid-handler** — drops un-acked JetStream messages back to the consumer; user sees redelivery. Use `drain()`.
2. **Dropping the subscription handle** — the `Subscription` returned by `nc.subscribe(...)` is the only handle for `unsubscribe()`. Store it.
3. **Blocking I/O inside a handler** — freezes the loop; broker logs "slow consumer". Bridge sync calls via `asyncio.to_thread` (see `python-asyncio-patterns`).
4. **`headers=None` vs `headers={}`** — both publish, but extracting OTel context from `None` requires a `None`-guard in the carrier `Getter` (see `python-otel-instrumentation`).
5. **JetStream `ack_wait` shorter than handler runtime** — silent redelivery storm. Either raise `ack_wait` or call `await msg.in_progress()` periodically inside long handlers.
6. **`max_ack_pending` unset on a high-throughput subject** — defaults to 1000; producers blow past it and the consumer stalls. Tune via `connection-pool-tuning` heuristic for the deployment.
7. **`max_deliver` defaulting to -1 (infinite)** — poison-pill messages loop forever. Always cap (`max_deliver=cfg.max_deliver`, default 5) and DLQ via a `deliver_subject` rule.
8. **Reusing a NATS connection across forks** — async connections are not fork-safe. Open per-process after `os.fork()` / inside the worker entrypoint.

## References

- `nats-py` docs: <https://nats-io.github.io/nats.py/>
- NATS server header semantics: <https://docs.nats.io/reference/reference-protocols/nats-protocol#hpub>
- JetStream consumer model: <https://docs.nats.io/nats-concepts/jetstream/consumers>
- Cross-skill: `python-asyncio-patterns` (handler fan-out), `asyncio-cancellation-patterns` (timeout discipline), `client-shutdown-lifecycle` (aclose contract), `python-otel-instrumentation` (header propagation), `circuit-breaker-policy` (reconnect-callback wiring), `idempotent-retry-safety` (`Nats-Msg-Id` dedup window).
