---
name: python-otel-instrumentation
description: >
  Use this when standing up OpenTelemetry in a Python SDK or service —
  TracerProvider + MeterProvider with OTLP exporters; W3C TraceContext + Baggage
  propagation; custom TextMap Getter / Setter for non-HTTP carriers (NATS
  message headers, gRPC metadata, custom binary headers); span lifecycle via
  `start_as_current_span` context manager (never bare `start_span`); lazy meter
  handles; bounded-cardinality attribute conventions; the
  tracer-then-meter-then-logger graceful Shutdown ordering;
  `LoggingInstrumentor` for trace-id correlation in stdlib logs.
  Triggers: TracerProvider, MeterProvider, OTLPSpanExporter, OTLPMetricExporter, BatchSpanProcessor, PeriodicExportingMetricReader, set_tracer_provider, set_meter_provider, propagate.inject, propagate.extract, TextMapGetter, TextMapSetter, W3CBaggagePropagator, TraceContextTextMapPropagator, set_global_textmap, LoggingInstrumentor, Resource.create, span.set_attribute, SpanKind, span.record_exception, tracer_provider.shutdown.
---

# python-otel-instrumentation (v1.0.0)

## Rationale

Wiring OpenTelemetry in Python from the bare SDK API has six independent traps and the SDK pipeline has hit each at least once: (1) using the global tracer with `__name__` (no instrumentation-library version → debugging nightmare); (2) creating metric instruments per call (every increment allocates a fresh `Counter`, GC churn dominates); (3) bare `start_span(...)` without context manager (span never ends — exporter blocks on full queue at shutdown); (4) un-bounded attribute cardinality (one attribute = `user_id` and the metric backend OOMs); (5) writing the propagator yourself instead of using `propagate.inject` / `propagate.extract` (subtle bugs around `tracestate` + baggage); (6) shutting down `MeterProvider` before `TracerProvider` (last spans never flush — they emit metrics on shutdown).

This skill encodes the production-safe pattern. It is the Python sibling of `otel-instrumentation` (Go) and complements `sdk-otel-hook-integration` (Go-specific facade rules).

## Activation signals

- Standing up OTel in `motadata_py_sdk` (or any new client) for the first time
- Adding a new metric or span attribute to existing instrumentation
- Propagating trace context across a non-HTTP carrier (NATS, Kafka, gRPC metadata, custom)
- Reviewer cites "missing parent span", "metric backend OOM", "shutdown lost spans", "bare start_span"
- Any TPRD §10-style requirement that names an OTel attribute, span name, or metric

## Setup — TracerProvider (canonical)

```python
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider, SpanLimits
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

def init_tracing(cfg: OTelConfig) -> None:
    resource = Resource.create({
        "service.name": cfg.service_name,           # required
        "service.version": cfg.service_version,
        "deployment.environment": cfg.environment,
        "service.instance.id": cfg.instance_id,     # pod / container id
    })
    provider = TracerProvider(
        resource=resource,
        sampler=ParentBased(root=TraceIdRatioBased(cfg.sample_ratio)),
        span_limits=SpanLimits(
            max_attributes=64,
            max_events=32,
            max_links=16,
            max_span_attribute_length=512,
        ),
    )
    provider.add_span_processor(BatchSpanProcessor(
        OTLPSpanExporter(
            endpoint=cfg.otlp_endpoint,
            insecure=cfg.otlp_insecure,
            headers=cfg.otlp_headers,               # {"x-honeycomb-team": "..."}
            timeout=cfg.otlp_timeout_s,
        ),
        max_queue_size=2048,
        max_export_batch_size=512,
        schedule_delay_millis=5000,
    ))
    trace.set_tracer_provider(provider)
```

**Always** name the tracer with the package path AND a version, never `__name__` alone:

```python
tracer = trace.get_tracer("motadata.events.jetstream", "0.1.0")
```

## Setup — MeterProvider

```python
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

def init_metrics(cfg: OTelConfig, resource: Resource) -> None:
    reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=cfg.otlp_endpoint, insecure=cfg.otlp_insecure),
        export_interval_millis=cfg.metric_export_interval_ms,   # default 10_000
    )
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[reader]))
```

## Lazy meter handles — `functools.cache`

Each `meter.create_counter(...)` call returns a fresh instrument; calling per request floods exporter state and allocates per call. Cache the handle:

```python
import functools
from opentelemetry import metrics

@functools.cache
def _meter():
    return metrics.get_meter("motadata.events", "0.1.0")

@functools.cache
def _publish_counter():
    return _meter().create_counter(
        "messaging.publish.count",
        unit="{message}",
        description="Count of messages published",
    )

@functools.cache
def _publish_latency():
    return _meter().create_histogram(
        "messaging.publish.duration",
        unit="s",
        description="Publish wall time, seconds",
    )

# hot path: handle is allocated once
_publish_counter().add(1, {"messaging.destination.name": subject})
_publish_latency().record(elapsed_s, {"messaging.destination.name": subject})
```

This is the Python analog of Go's `sync.Once` lazy-init pattern from `sdk-otel-hook-integration`.

## Span lifecycle — context manager only

```python
with tracer.start_as_current_span(
    "events.publish",
    kind=trace.SpanKind.PRODUCER,
    attributes={
        "messaging.system": "nats",
        "messaging.destination.name": subject,
        "messaging.message.body.size": len(payload),
    },
) as span:
    try:
        await nc.publish(subject, payload, headers=hdrs)
        span.set_status(trace.StatusCode.OK)
    except Exception as e:
        span.record_exception(e)
        span.set_status(trace.StatusCode.ERROR, str(e))
        raise
```

NEVER use `tracer.start_span(...)` without `with` / `try/finally span.end()` — un-ended spans are a top-3 cause of exporter back-pressure stalls.

## Propagation — composite W3C + Baggage

```python
from opentelemetry.propagate import set_global_textmap
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.baggage.propagation import W3CBaggagePropagator

set_global_textmap(CompositePropagator([
    TraceContextTextMapPropagator(),
    W3CBaggagePropagator(),
]))
```

Set this ONCE at startup. `inject` / `extract` then use the global propagator.

## Custom carrier — NATS headers (the canonical non-HTTP case)

```python
from opentelemetry.propagate import inject, extract
from opentelemetry.propagators.textmap import Getter, Setter
from opentelemetry import context

class NatsHeaderGetter(Getter[dict[str, str] | None]):
    def get(self, carrier: dict[str, str] | None, key: str) -> list[str] | None:
        if not carrier:
            return None
        v = carrier.get(key)
        return [v] if v is not None else None

    def keys(self, carrier: dict[str, str] | None) -> list[str]:
        return list(carrier.keys()) if carrier else []

class NatsHeaderSetter(Setter[dict[str, str]]):
    def set(self, carrier: dict[str, str], key: str, value: str) -> None:
        carrier[key] = value

_NATS_GETTER = NatsHeaderGetter()
_NATS_SETTER = NatsHeaderSetter()

# Producer:
def inject_into_nats(headers: dict[str, str]) -> None:
    inject(headers, setter=_NATS_SETTER)

# Consumer:
def with_extracted_context(msg_headers: dict[str, str] | None):
    ctx = extract(msg_headers or {}, getter=_NATS_GETTER)
    return context.attach(ctx)        # pair with context.detach(token) in finally
```

Same pattern (`Getter` / `Setter` subclass) for Kafka headers, gRPC metadata, custom binary protocols.

## Baggage — cross-process tags

```python
from opentelemetry import baggage, context

ctx = baggage.set_baggage("tenant_id", tenant_id)
token = context.attach(ctx)
try:
    # downstream code can call baggage.get_baggage("tenant_id")
    await do_work(...)
finally:
    context.detach(token)
```

## Attribute conventions — bounded cardinality

| Use | Don't use |
|---|---|
| `messaging.destination.name = "events.user.>"` (subject pattern) | `messaging.destination.name = "events.user.42"` (per-user) |
| `nats.consumer.name = "worker"` | `nats.consumer.id = "<uuid>"` (unbounded) |
| `error.type = "ErrTimeout"` (sentinel name) | `error.message = "<full str>"` (cardinality bomb) |
| `http.response.status_code = 503` (~600 values) | `http.url = "<full url>"` (per-request) |

If the user MUST tag per-tenant or per-user, do it on **logs** (free-form text indexed by ELK), never on metric attributes — metric backends materialize one time series per attribute combination.

## Logs — trace correlation

```python
from opentelemetry.instrumentation.logging import LoggingInstrumentor
import logging

LoggingInstrumentor().instrument(set_logging_format=True)
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Now records auto-include otelTraceID, otelSpanID, otelServiceName.
log.info("published", extra={"subject": subject, "size": len(payload)})
```

For structured JSON logs (preferred in production), pair with `python-json-logger` or `structlog`.

## Shutdown — strict order

```python
import asyncio
from opentelemetry import trace, metrics

async def shutdown_otel(timeout_s: float = 5.0) -> None:
    """Flush + shutdown providers in dependency order. Idempotent."""
    # 1. Tracer FIRST — span exporters may emit metrics during shutdown
    await asyncio.to_thread(trace.get_tracer_provider().shutdown)
    # 2. Meter
    await asyncio.to_thread(metrics.get_meter_provider().shutdown)
    # 3. Logger provider (if you set one up via opentelemetry-sdk-logs)
```

Wrap each provider's `shutdown()` in `asyncio.to_thread` because the SDK methods are sync and call `force_flush` internally with their own deadline.

## Pitfalls

1. **`get_tracer(__name__)`** — instrumentation library has no version; observability backends can't track schema migrations. Use `"motadata.events.jetstream"`, `"0.1.0"`.
2. **`meter.create_counter` per call** — allocates per call. Always cache via `functools.cache` or module-level `_counter = ...` after `init_metrics()`.
3. **`tracer.start_span(name)` without `try/finally span.end()`** — span leaks → exporter queue fills → publish thread blocks. Use `start_as_current_span` context manager.
4. **High-cardinality span/metric attributes** — every distinct value creates a new time series. Cap to enum-like values; put per-request data on logs.
5. **Forgetting `set_status(ERROR)` on exceptions** — UI shows the trace as green even though the request failed. Always pair `record_exception` with `set_status(StatusCode.ERROR, ...)`.
6. **`MeterProvider.shutdown()` before `TracerProvider.shutdown()`** — span exporters emit `otel.exporter.exported` metrics at shutdown; if MeterProvider is gone, those metrics are lost.
7. **Calling `init_tracing` from inside an async function before the loop is configured** — `BatchSpanProcessor` spawns a background thread that needs the right event loop. Init at module import or in `main()` before `asyncio.run(...)`.
8. **Using `OTLPSpanExporter` with `endpoint="grpc://..."` (with scheme)** — the gRPC exporter takes `host:port`, not a URL. The HTTP exporter takes a URL. Easy to cross-wire.
9. **Forgetting the `service.name` Resource attribute** — every backend treats this as required. Without it, traces show up as `unknown_service:python`.

## References

- OTel Python: <https://opentelemetry-python.readthedocs.io/>
- Semantic conventions (messaging): <https://opentelemetry.io/docs/specs/semconv/messaging/>
- W3C TraceContext: <https://www.w3.org/TR/trace-context/>
- Cross-skill: `nats-python-client-patterns` (header carrier integration), `python-asyncio-patterns` (loop interaction during init), `client-shutdown-lifecycle` (aclose ordering — OTel goes last after the wire client closes), `network-error-classification` (which sentinels to set as `error.type`), `otel-instrumentation` (Go sibling — same conventions, different SDK).
