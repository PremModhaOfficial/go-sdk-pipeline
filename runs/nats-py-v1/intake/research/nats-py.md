# nats-py canonical patterns (context7 digest, 2026-05-02)

Source: `/nats-io/nats.py` (164 snippets, High reputation, score 79.27).

## Connect

```python
import nats
nc = await nats.connect(
    servers=["nats://localhost:4222", "nats://localhost:4223"],
    error_cb=error_cb,
    disconnected_cb=disconnected_cb,
    reconnected_cb=reconnected_cb,
    max_reconnect_attempts=60,
    reconnect_time_wait=2,
    name="my-client",
    user_credentials="/path/to/secret.creds",   # NKeys/JWT
    tls=ssl_ctx,
    tls_hostname="localhost",
)
async with await nats.connect("nats://...") as nc: ...    # context manager closes
```

## Publish / Subscribe / Request

```python
await nc.publish("subject", b"payload", headers={"k": "v"})
sub = await nc.subscribe("subject", cb=async_handler)
resp = await nc.request("api.echo", b"hello", timeout=2.0,
                        headers={"Content-Type": "application/json"})
# Errors: nats.errors.{TimeoutError,NoRespondersError,ConnectionClosedError,NoServersError}
```

## JetStream — Stream + Pull Subscribe

```python
js = nc.jetstream()
await js.add_stream(name="TASKS", subjects=["tasks.*"])
await js.publish("tasks.work", b"...")

from nats.js.api import ConsumerConfig, AckPolicy
cfg = ConsumerConfig(ack_policy=AckPolicy.EXPLICIT, max_deliver=3, ack_wait=30)
psub = await js.pull_subscribe("tasks.>", durable="worker-2", config=cfg)
msgs = await psub.fetch(batch=5, timeout=30.0, heartbeat=5.0)
for m in msgs:
    meta = m.metadata     # .sequence.{stream,consumer}, .num_delivered, .timestamp
    await m.ack()         # or m.nak() / m.term() / m.in_progress()
info = await psub.consumer_info()  # .num_pending, .delivered.consumer_seq
```

## JetStream — KV bucket

```python
from nats.js.api import KeyValueConfig
kv = await js.create_key_value(KeyValueConfig(
    bucket="CONFIG", history=5, ttl=3600, max_bytes=100*1024*1024))
rev = await kv.put("k", b"v")
entry = await kv.get("k", revision=None)        # entry.{key,value,revision,delta,operation}
await kv.create("new", b"v")                    # raises KeyWrongLastSequenceError on collision
await kv.update("k", b"v2", last=entry.revision)# optimistic CAS
await kv.delete("k")                            # tombstone
await kv.purge("k")                             # full erase
keys = await kv.keys()
async for entry in await kv.watch("config.*"):
    if entry is None: continue   # initial-sync sentinel
    ...
status = await kv.status()
```

## ObjectStore (sketch — confirm in §8 of TPRD)

```python
os_ = await js.create_object_store(config=ObjectStoreConfig(bucket="ASSETS", max_bytes=...))
info = await os_.put_file("reports/a.pdf")          # streams from disk
await os_.get_file("reports/a.pdf", "/tmp/a.pdf")
await os_.delete("reports/a.pdf")
async for info in await os_.watch():
    ...
```

## Graceful shutdown

```python
await nc.drain()    # waits for pending subs to drain handlers; closes
await nc.close()    # immediate close; in-flight cb's cancelled
```
**TPRD-relevant**: rule 6 (Close()/aclose() lifecycle) maps to `drain()` for cooperative shutdown
or `close()` for hard stop. JetStream Consumer's `unsubscribe()` precedes connection drain.

## Headers

`Msg.headers` is `dict[str, str] | None`. NATS protocol carries headers as ASCII key:value pairs
(NATS/1.0 prefix). Special keys: `Nats-Last-Sequence`, `Nats-Expected-Stream`,
`Nats-Expected-Last-Subject-Sequence`, `Nats-Msg-Id` (dedup), `Nats-Rollup`.
**Wire-byte exactness** for the TPRD §4.1 header constants is preserved — we just put the same
ASCII strings into `Msg.headers`.

## Async context-cancellation contract

`asyncio.CancelledError` raised inside a `cb` aborts the handler; `psub.fetch` honors the
caller's `asyncio.timeout()`. Both align with our `asyncio-cancellation-patterns` skill.

## Notes for our SDK port

- `Publisher` / `Subscriber` / `Stream` / `Consumer` / `Requester` in TPRD §5–§7 should be
  thin wrappers around `nc` + `js` that bake in:
  - the OTel instrumented-call pattern (open span → publish → set_attribute → end)
  - the chain-middleware around the user handler
  - the codec layer (msgpack / custom binary per §4.3)
  - the tenant subject prefix per §4.4 / §4.5
- Reconnection callbacks are the right hook for our circuit-breaker-state notification.
- `m.metadata.num_delivered` is the redelivery counter — feeds `[constraint:]` checks in §10.
