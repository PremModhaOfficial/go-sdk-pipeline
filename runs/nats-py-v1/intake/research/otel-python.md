# opentelemetry-python canonical patterns (context7 digest, 2026-05-02)

Source: `/open-telemetry/opentelemetry-python` (210 snippets, High reputation, score 72.43).

## TracerProvider setup (full form)

```python
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider, SpanLimits
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

resource = Resource.create({
    "service.name": "motadata-py-sdk",
    "service.version": "0.1.0",
    "deployment.environment": "production",
})

provider = TracerProvider(
    resource=resource,
    sampler=ParentBased(root=TraceIdRatioBased(0.1)),
    span_limits=SpanLimits(max_attributes=64, max_events=32, max_links=16,
                           max_span_attribute_length=512),
)
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(
    endpoint="http://otel-collector:4317", insecure=True, timeout=10,
)))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("motadata.events", "0.1.0")
```

## MeterProvider setup

```python
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint="http://otel-collector:4317", insecure=True),
    export_interval_millis=10_000,
)
mp = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(mp)
meter = metrics.get_meter("motadata.events", "0.1.0")
counter = meter.create_counter("messages_published_total")
hist = meter.create_histogram("publish_latency_seconds", unit="s")
```

## Span lifecycle (context manager only — never bare start_span without end)

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
        await publish(...)
        span.set_status(trace.StatusCode.OK)
    except Exception as e:
        span.record_exception(e)
        span.set_status(trace.StatusCode.ERROR, str(e))
        raise
```

## Propagation: W3C TraceContext + Baggage

```python
from opentelemetry.propagate import inject, extract, set_global_textmap
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.baggage.propagation import W3CBaggagePropagator

set_global_textmap(CompositePropagator([
    TraceContextTextMapPropagator(),
    W3CBaggagePropagator(),
]))
```

## Custom carrier for NATS headers (TextMapGetter / TextMapSetter)

```python
from opentelemetry.propagators.textmap import Getter, Setter

class NatsHeaderGetter(Getter[dict[str, str] | None]):
    def get(self, carrier, key):
        if not carrier: return None
        v = carrier.get(key)
        return [v] if v is not None else None
    def keys(self, carrier):
        return list(carrier.keys()) if carrier else []

class NatsHeaderSetter(Setter[dict[str, str]]):
    def set(self, carrier, key, value):
        carrier[key] = value

# At publish:
headers: dict[str, str] = {}
inject(headers, setter=NatsHeaderSetter())
await nc.publish(subject, payload, headers=headers)

# At receive:
ctx = extract(msg.headers or {}, getter=NatsHeaderGetter())
token = context.attach(ctx)
try:
    with tracer.start_as_current_span("events.receive", kind=SpanKind.CONSUMER):
        await user_handler(msg)
finally:
    context.detach(token)
```

## Baggage

```python
from opentelemetry import context, baggage
ctx = baggage.set_baggage("tenant_id", tenant_id)
token = context.attach(ctx)
try:
    ...
finally:
    context.detach(token)
```

## Graceful shutdown ordering (CRITICAL — matches Go SDK rule)

```python
async def shutdown_otel():
    # 1. Stop creating new spans (close clients)
    # 2. Flush + shutdown tracer FIRST (it may emit metrics on shutdown)
    trace.get_tracer_provider().shutdown()
    # 3. Then meter provider
    metrics.get_meter_provider().shutdown()
    # 4. Then logger provider (if used)
```

## slog-equivalent: structured stdlib logging + LoggingInstrumentor

```python
from opentelemetry.instrumentation.logging import LoggingInstrumentor
LoggingInstrumentor().instrument(set_logging_format=True)
# Now logging records auto-include otelTraceID, otelSpanID
```

## Notes for our SDK port

- All public-API methods that issue NATS calls MUST open a span via the
  package's `tracer = trace.get_tracer("motadata.events.<sub>")` — never the global tracer
  with `__name__`, mirrors Go SDK rule 6.
- All metric handles created lazily under a `functools.cache` (Python equivalent of
  Go `sync.Once`) to avoid re-creating instruments per call.
- `LoggingInstrumentor` is the closest stdlib equivalent to the Go SDK's
  `slog`-with-trace-correlation handler. Confirm in TPRD §10.6.
- Carrier classes (NatsHeaderGetter / NatsHeaderSetter) belong in
  `motadata_py_sdk.events.otel_propagation`.
- Attribute conventions: use `messaging.system`, `messaging.destination.name`,
  `messaging.message.body.size`, `messaging.nats.consumer.delivery_count`.
  Bounded cardinality — NEVER put raw payload, user IDs, tenant IDs in span attrs
  unless TPRD explicitly approves (matches `sdk-otel-hook-integration` skill).
