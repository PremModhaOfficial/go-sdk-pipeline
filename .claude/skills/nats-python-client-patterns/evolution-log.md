# nats-python-client-patterns — evolution log

- 1.0.0 (2026-05-02): initial — authored during run `nats-py-v1` intake on user instruction "construct the missing things". Sourced from context7 `/nats-io/nats.py` digest at `runs/nats-py-v1/intake/research/nats-py.md`. Covers connect+TLS+creds, pub/sub/request, JetStream stream/pull-consumer/KV/ObjectStore, headers, drain vs close, reconnect-callback hooks for circuit-breaker integration. Companion to `python-otel-instrumentation` (header-carrier propagation) and `python-asyncio-patterns` (handler fan-out).
