---
name: go-otel-instrumentation
description: OpenTelemetry TracerProvider, MeterProvider, OTLP exporters, slog correlation, span enrichment, context propagation, graceful shutdown.
version: 1.0.0
created-in-run: bootstrap-seed
status: stable
tags: [otel, observability, tracing, metrics, logging]
---



# OTel Instrumentation Patterns

OpenTelemetry SDK instrumentation patterns for every Go microservice in the
platform. Every service MUST emit traces, metrics, and structured logs with
tenant context and trace correlation.

## When to Activate
- When designing the observability SDK (`pkg/observability/`)
- When implementing TracerProvider, MeterProvider, or log setup in any service
- When adding custom metrics or spans to business logic
- When propagating trace context through NATS JetStream messages
- When reviewing code for observability completeness
- Used by: sdk-designer, sdk-implementor, code-generator, infrastructure-architect, component-designer, observability-test-agent

## Provider Initialization

### TracerProvider Setup

```go
// pkg/observability/tracer.go
func NewTracerProvider(ctx context.Context, cfg OTelConfig, res *resource.Resource) (*sdktrace.TracerProvider, error) {
    if cfg.Exporter == "none" {
        return sdktrace.NewTracerProvider(sdktrace.WithResource(res)), nil
    }

    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint),
        otlptracegrpc.WithInsecure(), // TLS handled by mesh/sidecar
    )
    if err != nil {
        return nil, fmt.Errorf("creating trace exporter: %w", err)
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter,
            sdktrace.WithMaxExportBatchSize(512),
            sdktrace.WithBatchTimeout(5*time.Second),
        ),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.ParentBased(
            sdktrace.TraceIDRatioBased(cfg.SampleRate),
        )),
    )
    return tp, nil
}
```

### MeterProvider Setup

```go
// pkg/observability/meter.go
func NewMeterProvider(ctx context.Context, cfg OTelConfig, res *resource.Resource) (*sdkmetric.MeterProvider, error) {
    if cfg.Exporter == "none" {
        return sdkmetric.NewMeterProvider(sdkmetric.WithResource(res)), nil
    }

    exporter, err := otlpmetricgrpc.New(ctx,
        otlpmetricgrpc.WithEndpoint(cfg.OTLPEndpoint),
        otlpmetricgrpc.WithInsecure(),
    )
    if err != nil {
        return nil, fmt.Errorf("creating metric exporter: %w", err)
    }

    mp := sdkmetric.NewMeterProvider(
        sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter,
            sdkmetric.WithInterval(15*time.Second),
        )),
        sdkmetric.WithResource(res),
    )
    return mp, nil
}
```

### Resource Construction

```go
func NewResource(ctx context.Context, serviceName, serviceVersion string) (*resource.Resource, error) {
    return resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceNameKey.String(serviceName),
            semconv.ServiceVersionKey.String(serviceVersion),
            semconv.DeploymentEnvironmentKey.String(os.Getenv("ENVIRONMENT")),
        ),
        resource.WithHost(),
        resource.WithProcess(),
    )
}
```

**IMPORTANT**: Do NOT use `resource.Merge(resource.Default(), ...)` — it causes
schema URL conflicts with transitive OTel SDK dependencies. Always use
`resource.New(ctx, ...)`.

### Structured Logging with Trace Correlation

```go
// pkg/observability/logger.go
func NewLogger(cfg OTelConfig) *slog.Logger {
    opts := &slog.HandlerOptions{Level: parseLevel(cfg.LogLevel)}
    var handler slog.Handler
    handler = slog.NewJSONHandler(os.Stdout, opts)
    // Wrap with trace-correlation handler
    handler = &traceCorrelationHandler{inner: handler}
    return slog.New(handler)
}

type traceCorrelationHandler struct {
    inner slog.Handler
}

func (h *traceCorrelationHandler) Handle(ctx context.Context, r slog.Record) error {
    sc := trace.SpanContextFromContext(ctx)
    if sc.IsValid() {
        r.AddAttrs(
            slog.String("trace_id", sc.TraceID().String()),
            slog.String("span_id", sc.SpanID().String()),
        )
    }
    // Always add tenant_id from context
    if tid := tenant.FromContext(ctx); tid != uuid.Nil {
        r.AddAttrs(slog.String("tenant_id", tid.String()))
    }
    return h.inner.Handle(ctx, r)
}
```

## Service Bootstrap

```go
func initTelemetry(ctx context.Context, cfg config.Config) (shutdown func(context.Context) error, err error) {
    res, err := observability.NewResource(ctx, cfg.ServiceName, cfg.Version)
    if err != nil {
        return nil, fmt.Errorf("creating otel resource: %w", err)
    }

    tp, err := observability.NewTracerProvider(ctx, cfg.OTel, res)
    if err != nil {
        return nil, fmt.Errorf("creating tracer provider: %w", err)
    }
    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))

    mp, err := observability.NewMeterProvider(ctx, cfg.OTel, res)
    if err != nil {
        return nil, fmt.Errorf("creating meter provider: %w", err)
    }
    otel.SetMeterProvider(mp)

    logger := observability.NewLogger(cfg.OTel)
    slog.SetDefault(logger)

    shutdown = func(ctx context.Context) error {
        return errors.Join(tp.Shutdown(ctx), mp.Shutdown(ctx))
    }
    return shutdown, nil
}
```

## NATS Trace Propagation

```go
// Inject trace context into NATS message headers
func InjectTraceContext(ctx context.Context, msg *nats.Msg) {
    carrier := NATSHeaderCarrier(msg.Header)
    otel.GetTextMapPropagator().Inject(ctx, carrier)
}

// Extract trace context from NATS message headers
func ExtractTraceContext(ctx context.Context, msg *nats.Msg) context.Context {
    carrier := NATSHeaderCarrier(msg.Header)
    return otel.GetTextMapPropagator().Extract(ctx, carrier)
}

// NATSHeaderCarrier adapts nats.Header to propagation.TextMapCarrier
type NATSHeaderCarrier nats.Header

func (c NATSHeaderCarrier) Get(key string) string    { return nats.Header(c).Get(key) }
func (c NATSHeaderCarrier) Set(key, val string)       { nats.Header(c).Set(key, val) }
func (c NATSHeaderCarrier) Keys() []string {
    keys := make([]string, 0, len(c))
    for k := range c {
        keys = append(keys, k)
    }
    return keys
}
```

## Standard Metrics Per Service

Every service MUST register these instruments at startup:

| Metric | Type | Attributes | Purpose |
|---|---|---|---|
| `{service}.request.duration` | Histogram | `method`, `status`, `tenant_id` | Request latency |
| `{service}.request.total` | Counter | `method`, `status`, `tenant_id` | Request count |
| `{service}.error.total` | Counter | `error_type`, `tenant_id` | Error count by type |
| `{service}.inflight.requests` | UpDownCounter | `tenant_id` | Concurrent requests |
| `{service}.nats.publish.duration` | Histogram | `subject`, `tenant_id` | NATS publish latency |
| `{service}.nats.consume.duration` | Histogram | `subject`, `tenant_id` | NATS consume processing time |
| `{service}.db.query.duration` | Histogram | `operation`, `table`, `tenant_id` | DB query latency |

### Custom Metric Registration

```go
meter := otel.Meter("identity-service")

requestDuration, _ := meter.Float64Histogram(
    "identity.request.duration",
    metric.WithUnit("ms"),
    metric.WithDescription("Request processing duration"),
)

requestTotal, _ := meter.Int64Counter(
    "identity.request.total",
    metric.WithDescription("Total requests processed"),
)
```

## Span Conventions

- Span names: `{Service}.{Method}` (e.g., `IdentityService.CreateUser`)
- Always set `tenant_id` as a span attribute
- Set `otel.status_code` on errors
- Use `span.RecordError(err)` for error spans

```go
ctx, span := otel.Tracer("identity-service").Start(ctx, "IdentityService.CreateUser",
    trace.WithAttributes(
        attribute.String("tenant_id", tenantID.String()),
        attribute.String("user.email", req.Email),
    ),
)
defer span.End()

if err != nil {
    span.RecordError(err)
    span.SetStatus(codes.Error, err.Error())
}
```

## Examples

### GOOD
```go
// Trace context propagated through NATS, tenant_id on every span
ctx = observability.ExtractTraceContext(ctx, msg)
ctx, span := tracer.Start(ctx, "NotificationService.SendEmail",
    trace.WithAttributes(attribute.String("tenant_id", tid.String())),
)
defer span.End()
```

### BAD
```go
// Missing trace propagation from NATS — creates orphan spans
span := tracer.Start(context.Background(), "SendEmail")
defer span.End()

// Missing tenant_id — cannot filter by tenant in Grafana
ctx, span := tracer.Start(ctx, "SendEmail")
```

## Common Mistakes
1. **Using `resource.Merge` with `resource.Default()`** — Causes schema URL conflicts. Use `resource.New` with explicit attributes.
2. **Forgetting NATS trace propagation** — Every NATS publish/consume MUST inject/extract trace context, otherwise traces are broken across service boundaries.
3. **Missing tenant_id on metrics/spans** — Every metric and span MUST include `tenant_id` attribute for per-tenant dashboards and alerting.
4. **Not calling provider Shutdown** — Telemetry providers MUST be shut down in graceful shutdown to flush pending data.
5. **Using stdout exporter in production** — `OTEL_EXPORTER` must be `otlp` in prod, `stdout` for local debug only, `none` for dev without collectors.
