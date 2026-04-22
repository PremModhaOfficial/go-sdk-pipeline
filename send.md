# TPRD — NATS Client SDK (Cleaned)

> **Run ID**: `nats-v1`
> **Mode**: A (New Package)
> **Pipeline Version**: 0.1.0
> **Date**: 2026-04-17
> **Status**: AWAITING H1 APPROVAL
> **Target Package**: `$TARGET_PKG` (resolve via `SDK_TARGET_DIR`)
> **Go Version**: 1.26
> **Semver Bump**: minor (v0.x.0 → v0.(x+1).0 — new package, no breakage)

---

## §1. Request Type

**New Package** — Mode A.

Add a production-grade NATS / NATS JetStream client package to `$TARGET_PKG`. The package exposes:

- Core NATS publish / subscribe (core NATS)
- JetStream publish / subscribe / pull-consumer APIs
- Key-Value store operations (via JetStream KV)
- Object Store operations (via JetStream Object Store)
- Connection lifecycle (connect, reconnect, drain, close)
- Full OTel instrumentation via `$SDK_ROOT/otel`
- Circuit-breaker wrapping via `$SDK_ROOT/core/circuitbreaker`
- Connection pooling via `$SDK_ROOT/core/pool`

---

## §2. Scope

### In-Scope

| Area | Detail |
|---|---|
| Core NATS | `Publish`, `PublishMsg`, `Subscribe`, `QueueSubscribe`, `Request`, `RequestMsg` |
| JetStream | `JetStreamPublish`, `JetStreamPublishMsg`, `CreateOrUpdateStream`, `CreateOrUpdateConsumer`, `PullMessages`, `FetchMessages` |
| KV | `KeyValueBind`, `KVGet`, `KVPut`, `KVDelete`, `KVPurge`, `KVWatch` |
| Object Store | `ObjectStoreBind`, `OSPut`, `OSGet`, `OSDelete`, `OSWatch` |
| Connection | TLS, user+password, token, NKey, JWT creds, auto-reconnect, drain |
| Resilience | Per-publish circuit breaker, retry with exponential backoff, context cancellation |
| Observability | OTel traces (span per publish/subscribe/fetch), OTel metrics (counters, histograms), structured logging |
| Security | TLS 1.2 min, mutual TLS, credential zero-out on close |
| Testing | Table-driven unit tests, testcontainers (nats:latest + nats:alpine JetStream), benchmarks, fuzz |

### Non-Goals

- NATS clustering orchestration (create / manage servers) — out of scope; SDK is a _client_ only
- NATS account management (operator JWT creation) — server-side concern
- NATS Leaf-node routing configuration beyond standard client connect options
- WebSocket transport (NATS over WS) — not required for current backend targets
- NATS micro / services framework (`nats.Micro`) — future TPRD
- Hot reload of credentials without connection restart
- Plugin architecture for custom serializers at the SDK level
- Multi-tenancy enforcement — caller supplies `tenant_id` in subject prefixes; SDK does not enforce

---

## §3. Motivation

`motadatagosdk` currently has no first-class NATS client. Background services and event pipelines hand-roll `nats.go` connections, resulting in:

1. **Inconsistent retry/reconnect logic** — each service re-implements its own policy.
2. **No circuit-breaker protection** — a lagging NATS server causes goroutine pile-ups.
3. **Zero observability** — no spans or metrics on publish latency, consumer lag, or ack failures.
4. **Security drift** — TLS settings configured ad-hoc; some services skip client-cert verification.
5. **Test sprawl** — each service invents its own testcontainer setup.

A shared SDK client solves all five problems with a single, audited implementation.

---

## §4. Functional Requirements

### Connection Management

| ID | Requirement |
|---|---|
| FR-CON-01 | `New(cfg Config) (*Client, error)` MUST open a NATS connection using the resolved server list. On failure it MUST return a wrapped `ErrConnect`. |
| FR-CON-02 | Client MUST support nkey authentication, user+password authentication, token authentication, and credentials-file (JWT+nkey pair) authentication — selected by which fields in `Config` are non-zero. |
| FR-CON-03 | Client MUST auto-reconnect on transient disconnects. Max reconnect attempts and interval are configurable (FR-CON-07). Reconnect attempts MUST emit an OTel event `nats.reconnect_attempt`. |
| FR-CON-04 | `Client.Drain(ctx)` MUST flush in-flight messages, drain all active subscriptions, and then close the connection. It MUST respect context deadline. |
| FR-CON-05 | `Client.Close()` MUST close the connection synchronously; it MUST NOT leak goroutines (`goleak.VerifyTestMain` clean). |
| FR-CON-06 | `Client.IsConnected() bool` MUST return `true` only when the underlying NATS connection is in `CONNECTED` state. |
| FR-CON-07 | Config fields governing connection: `Servers []string`, `MaxReconnects int`, `ReconnectWait time.Duration`, `ReconnectJitter time.Duration`, `PingInterval time.Duration`, `MaxPingsOutstanding int`, `ConnectTimeout time.Duration`, `DrainTimeout time.Duration`, `Name string` (connection name), `InboxPrefix string`. |

### Core NATS — Publish

| ID | Requirement |
|---|---|
| FR-PUB-01 | `Publish(ctx, subject, data []byte) error` MUST publish to the server, propagating OTel trace context via NATS message headers. |
| FR-PUB-02 | `PublishMsg(ctx, *nats.Msg) error` MUST publish a pre-built `nats.Msg`; span MUST inherit caller's trace context. |
| FR-PUB-03 | Subject MUST be validated: non-empty, no leading/trailing dot, no embedded `\0`, max 255 bytes. Violation returns `ErrInvalidSubject`. |
| FR-PUB-04 | Payload MUST be within `Config.MaxPayloadBytes`; violation returns `ErrPayloadTooLarge`. |
| FR-PUB-05 | Publish MUST be wrapped by the circuit breaker; open-circuit returns `ErrCircuitOpen`. |

### Core NATS — Subscribe

| ID | Requirement |
|---|---|
| FR-SUB-01 | `Subscribe(ctx, subject string, handler MsgHandler) (*Subscription, error)` MUST create an async subscription. |
| FR-SUB-02 | `QueueSubscribe(ctx, subject, queue string, handler MsgHandler) (*Subscription, error)` MUST create a queue-group subscription. |
| FR-SUB-03 | `Request(ctx, subject string, data []byte) (*nats.Msg, error)` MUST publish a request and wait for a reply, respecting context deadline. **[AMBIGUITY]** Does circuit breaker wrap the publish side of Request? Clarify intent. |
| FR-SUB-04 | `Subscription.Unsubscribe() error` MUST drain and remove the subscription. |
| FR-SUB-05 | Each received message MUST extract OTel trace context from headers and create a child span covering the handler duration. |
| FR-SUB-06 | `MsgHandler` signature: `func(ctx context.Context, msg *nats.Msg) error`. Handler errors MUST be logged and counted (`nats.handler_error_total`). **[AMBIGUITY]** Counter incremented for core-NATS handlers, JetStream pull handlers, or both? |
| FR-SUB-07 | Slow-consumer configuration: `Config.SubPendingMsgLimit int`, `Config.SubPendingBytesLimit int` (default `65536` msgs / `67108864` bytes). |

### JetStream — Stream Management

| ID | Requirement |
|---|---|
| FR-JS-01 | `JetStream() (JetStreamClient, error)` MUST return a JetStream context bound to the current connection. |
| FR-JS-02 | `CreateOrUpdateStream(ctx, cfg jetstream.StreamConfig) (jetstream.Stream, error)` MUST be idempotent (create if absent, update if config differs, no-op if identical). |
| FR-JS-03 | `DeleteStream(ctx, name string) error` MUST delete the named stream; returns `ErrStreamNotFound` if absent. |
| FR-JS-04 | `StreamInfo(ctx, name string) (*jetstream.StreamInfo, error)` MUST return current stream metadata. |

### JetStream — Publish

| ID | Requirement |
|---|---|
| FR-JSP-01 | `JetStreamPublish(ctx, subject string, data []byte, opts ...jetstream.PublishOpt) (*jetstream.PubAck, error)` MUST publish and wait for server ack. |
| FR-JSP-02 | Ack wait is configurable via `Config.JetStreamPublishAckWait time.Duration` (default 5 s). |
| FR-JSP-03 | De-duplication window: `Config.JetStreamPublishDedupWindow time.Duration` (default 2 min). Publish MUST set `Nats-Msg-Id` header when `Config.EnableMsgID bool` is true. |
| FR-JSP-04 | JetStream publish MUST be circuit-breaker and retry protected (FR-RES-01). |

### JetStream — Pull Consumer

| ID | Requirement |
|---|---|
| FR-JSC-01 | `CreateOrUpdateConsumer(ctx, stream string, cfg jetstream.ConsumerConfig) (jetstream.Consumer, error)` MUST be idempotent create/update. |
| FR-JSC-02 | `PullMessages(ctx, consumer jetstream.Consumer, batchSize int, handler MsgHandler) error` MUST fetch a batch, invoke handler per message, and ack or nak based on handler error. |
| FR-JSC-03 | `FetchMessages(ctx, consumer jetstream.Consumer, opts FetchOptions) (jetstream.MessageBatch, error)` MUST return a raw batch for caller-managed ack. **[AMBIGUITY]** Why two APIs? When use `PullMessages` vs `FetchMessages`? Document trade-off. |
| FR-JSC-04 | `FetchOptions` fields: `Batch int`, `MaxWait time.Duration`, `MaxBytes int`. |
| FR-JSC-05 | Consumer config validation: `Durable string` must be non-empty for durable consumers; `FilterSubject` / `FilterSubjects []string` must be valid subject(s); `AckWait` defaults to 30 s. |
| FR-JSC-06 | On handler error `PullMessages` MUST nak with delay `Config.NakDelay time.Duration` (default 5 s). |
| FR-JSC-07 | `ConsumerInfo(ctx, stream, consumer string) (*jetstream.ConsumerInfo, error)` MUST return current consumer metadata. |

### Key-Value Store

| ID | Requirement |
|---|---|
| FR-KV-01 | `KeyValueBind(ctx, bucket string) (jetstream.KeyValue, error)` MUST succeed if the bucket exists or create it using `Config.KVBucketDefaults`. **[AMBIGUITY] OQ-04** Does this use idempotent create-or-update or fail-fast if bucket absent? Answer required before design. |
| FR-KV-02 | `KVGet(ctx, kv jetstream.KeyValue, key string) (jetstream.KeyValueEntry, error)` MUST return `ErrKeyNotFound` sentinel on miss. |
| FR-KV-03 | `KVPut(ctx, kv jetstream.KeyValue, key string, value []byte) (revision uint64, err error)` MUST write and return the revision. |
| FR-KV-04 | `KVDelete(ctx, kv jetstream.KeyValue, key string) error` MUST delete the key. |
| FR-KV-05 | `KVPurge(ctx, kv jetstream.KeyValue, key string) error` MUST purge all revisions of a key. |
| FR-KV-06 | `KVWatch(ctx, kv jetstream.KeyValue, key string) (jetstream.KeyWatcher, error)` MUST return a watcher; watcher MUST be closed on context cancellation. |
| FR-KV-07 | KV key validation: non-empty, no leading/trailing `.`, alphanumeric + `-._/`, max 512 bytes. Returns `ErrInvalidKey`. |

### Object Store

| ID | Requirement |
|---|---|
| FR-OS-01 | `ObjectStoreBind(ctx, bucket string) (jetstream.ObjectStore, error)` creates or binds to an object store bucket. |
| FR-OS-02 | `OSPut(ctx, os jetstream.ObjectStore, name string, r io.Reader) (*jetstream.ObjectInfo, error)` MUST stream data to the bucket. |
| FR-OS-03 | `OSGet(ctx, os jetstream.ObjectStore, name string) (io.ReadCloser, error)` MUST return a streaming reader; caller MUST close it. |
| FR-OS-04 | `OSDelete(ctx, os jetstream.ObjectStore, name string) error` MUST delete the object. |
| FR-OS-05 | `OSWatch(ctx, os jetstream.ObjectStore) (jetstream.ObjectStoreWatcher, error)` returns a watcher; closed on context cancellation. |

---

## §5. Non-Functional Requirements

### Performance Benchmarks (Targets)

All benchmarks run on **bare metal**: 8-core 3 GHz, 32 GB RAM, NATS server co-located over loopback.
Bench suite: `go test -bench=. -benchmem -count=10 ./events/nats/...`

| Benchmark Name | Metric | Target | Regression Gate |
|---|---|---|---|
| `BenchmarkPublish_1KB` | Publish latency p50 | ≤ 120 µs | +5% from baseline |
| `BenchmarkPublish_1KB` | Throughput | ≥ 80 000 msg/s | −5% from baseline |
| `BenchmarkPublish_64KB` | Publish latency p50 | ≤ 800 µs | +5% |
| `BenchmarkPublish_64KB` | Throughput | ≥ 8 000 msg/s | −5% |
| `BenchmarkJetStreamPublish_1KB` | Publish+Ack latency p99 | ≤ 5 ms | +10% |
| `BenchmarkJetStreamPublish_1KB` | Throughput | ≥ 20 000 msg/s | −10% |
| `BenchmarkPullFetch_Batch64` | Fetch latency (all 64 msgs) | ≤ 8 ms | +10% |
| `BenchmarkPullFetch_Batch64` | Msgs processed/s | ≥ 200 000 msg/s | −10% |
| `BenchmarkKVPut_256B` | KV Put latency p50 | ≤ 200 µs | +5% |
| `BenchmarkKVGet_256B` | KV Get latency p50 | ≤ 150 µs | +5% |
| `BenchmarkSubscribe_Throughput` | End-to-end receive throughput | ≥ 150 000 msg/s | −10% |
| `BenchmarkConnect` | Cold connect time (TLS off) | ≤ 5 ms | +20% |
| `BenchmarkConnect_TLS` | Cold connect time (TLS on) | ≤ 30 ms | +20% |
| `BenchmarkPublish_Parallel_8` | Throughput (8 goroutines, 1 KB) | ≥ 400 000 msg/s | −10% |

Latency measurement: `benchstat` over 10 runs; p50/p99 extracted from `testing.B` timer.
Regression verdict: **BLOCKER** on any miss; `sdk-benchmark-devil` owns verdict.

### Memory Allocation Targets

| Benchmark | Max allocs/op | Max bytes/op |
|---|---|---|
| `BenchmarkPublish_1KB` | ≤ 3 | ≤ 512 B |
| `BenchmarkJetStreamPublish_1KB` | ≤ 6 | ≤ 1 024 B |
| `BenchmarkPullFetch_Batch64` | ≤ 4 per msg | ≤ 768 B per msg |
| `BenchmarkKVPut_256B` | ≤ 4 | ≤ 640 B |
| `BenchmarkKVGet_256B` | ≤ 3 | ≤ 512 B |

### Latency SLOs (Integration Tests vs. testcontainers)

| Operation | p50 | p95 | p99 |
|---|---|---|---|
| Core NATS Publish (1 KB) | ≤ 200 µs | ≤ 500 µs | ≤ 1 ms |
| JetStream Publish+Ack (1 KB) | ≤ 2 ms | ≤ 8 ms | ≤ 20 ms |
| JetStream Pull Fetch (batch 64) | ≤ 10 ms | ≤ 30 ms | ≤ 60 ms |
| KV Put (256 B) | ≤ 500 µs | ≤ 2 ms | ≤ 5 ms |
| KV Get (256 B) | ≤ 300 µs | ≤ 1 ms | ≤ 3 ms |
| Request-Reply (1 KB) | ≤ 1 ms | ≤ 5 ms | ≤ 15 ms |

### Concurrency

| ID | Requirement |
|---|---|
| NFR-CON-01 | All exported methods MUST be goroutine-safe. Internal state protected by sync primitives or lock-free techniques; no global mutable state. |
| NFR-CON-02 | Subscription handlers MUST be called in dedicated goroutines, not in the NATS library's internal dispatch goroutine. |
| NFR-CON-03 | `PullMessages` goroutine MUST exit cleanly when context is cancelled; no goroutine leak. |
| NFR-CON-04 | Connection-level circuit breaker MUST use atomic state transitions; no mutex on hot publish path. |

### Reliability

| ID | Requirement |
|---|---|
| NFR-REL-01 | Zero goroutine leaks: `goleak.VerifyTestMain` in `TestMain` of every `_test.go` file. |
| NFR-REL-02 | `go test -race -count=5` MUST pass clean on all test files. |
| NFR-REL-03 | Auto-reconnect MUST recover within `Config.MaxReconnects × Config.ReconnectWait` seconds; default ≤ 30 s. |
| NFR-REL-04 | Drain timeout (default 30 s) MUST be enforced; `Drain` MUST not block forever. |

### Scalability

| NFR-SCA-01 | Client MUST handle ≥ 1 000 active subscriptions without measurable latency increase on publish. |
|---|---|
| NFR-SCA-02 | JetStream pull loop MUST support configurable batch sizes up to `Config.MaxFetchBatch int` (default 256, max 4096). **[AMBIGUITY]** Can `FetchOptions.Batch` exceed `Config.MaxFetchBatch`? Add validation rule. |
| NFR-SCA-03 | Object Store streaming MUST handle objects up to `Config.MaxObjectSize int64` bytes (default: 1 GiB) without full in-memory buffering. |

### Code Quality

| NFR-CQ-01 | Branch coverage ≥ 90% for all files in `$TARGET_PKG`. |
|---|---|
| NFR-CQ-02 | `golangci-lint` (staticcheck + errcheck + gosec) MUST report zero findings. |
| NFR-CQ-03 | Every exported symbol MUST have Godoc (first word = symbol name). |
| NFR-CQ-04 | Zero `TODO` / `ErrNotImplemented` in committed code. |
| NFR-CQ-05 | Every exported API function MUST have an `Example_*` function. |

---

## §6. Dependencies

| Dependency | Version | License | Justification | Vetting |
|---|---|---|---|---|
| `github.com/nats-io/nats.go` | v1.39.x (latest stable) | Apache-2.0 | Official NATS Go client | `govulncheck` + `osv-scanner` MUST pass |
| `github.com/nats-io/nkeys` | v0.4.x | Apache-2.0 | NKey auth; transitive of nats.go | Bundled with nats.go |
| `github.com/nats-io/nuid` | v1.0.x | Apache-2.0 | Unique ID generation; transitive | Bundled with nats.go |
| `go.opentelemetry.io/otel` | (already in SDK) | Apache-2.0 | Trace + metrics; re-use existing | No new dep |
| `github.com/testcontainers/testcontainers-go` | (already in SDK test toolchain) | MIT | Integration test containers | Re-use existing |

**No net-new transitive deps beyond nats.go** are acceptable without a new `dependencies.md` entry and `sdk-dep-vet-devil` ACCEPT.

### Config Param Validation Table

All `Config` fields MUST be validated in `New(cfg)`. Invalid fields return `ErrInvalidConfig` wrapping the field name and violation.

| Field | Type | Default | Min | Max | Validation Rule |
|---|---|---|---|---|---|
| `Servers` | `[]string` | `["nats://127.0.0.1:4222"]` | 1 | 64 | Each URL parsed by `nats.ParseURL`; scheme must be `nats://`, `tls://`, or `ws://`. |
| `ConnectTimeout` | `time.Duration` | `5s` | `100ms` | `60s` | Must be > 0. |
| `MaxReconnects` | `int` | `60` | `-1` (infinite) | `10000` | -1 = infinite. |
| `ReconnectWait` | `time.Duration` | `2s` | `100ms` | `60s` | Must be > 0. |
| `ReconnectJitter` | `time.Duration` | `500ms` | `0` | `10s` | Must be ≥ 0. |
| `PingInterval` | `time.Duration` | `2m` | `5s` | `30m` | Must be ≥ ReconnectWait. |
| `MaxPingsOutstanding` | `int` | `2` | `1` | `20` | Must be ≥ 1. |
| `DrainTimeout` | `time.Duration` | `30s` | `1s` | `5m` | Must be > 0. |
| `Name` | `string` | `""` | — | 255 bytes | UTF-8; no null bytes. Optional. |
| `InboxPrefix` | `string` | `"_INBOX"` | 2 chars | 64 bytes | Must match `[A-Za-z0-9_-]+`. |
| `MaxPayloadBytes` | `int` | `1048576` (1 MiB) | `1` | `67108864` (64 MiB) | Checked against server advertised max at connect. |
| `SubPendingMsgLimit` | `int` | `65536` | `1` | `4194304` | Must be ≥ 1. |
| `SubPendingBytesLimit` | `int` | `67108864` | `1024` | `1073741824` | Must be ≥ 1 KiB. |
| `TLS.Enable` | `bool` | `false` | — | — | If true, `TLS.CertFile` and `TLS.KeyFile` must exist if set. |
| `TLS.MinVersion` | `uint16` | `tls.VersionTLS12` | `tls.VersionTLS12` | `tls.VersionTLS13` | Reject < TLS 1.2. |
| `TLS.CertFile` | `string` | `""` | — | 4096 bytes | If non-empty, must be readable PEM. |
| `TLS.KeyFile` | `string` | `""` | — | 4096 bytes | If non-empty, must be readable PEM. |
| `TLS.CAFile` | `string` | `""` | — | 4096 bytes | If non-empty, must be readable PEM. |
| `TLS.InsecureSkipVerify` | `bool` | `false` | — | — | Allowed only in test builds (`//go:build integration`). Production use = compile-time BLOCKER. |
| `Auth.Username` | `string` | `""` | — | 255 bytes | Mutually exclusive with Token, NKey, CredentialsFile. |
| `Auth.Password` | `string` | `""` | — | 1024 bytes | Required when Username is set. Zeroed on `Close()`. |
| `Auth.Token` | `string` | `""` | — | 1024 bytes | Mutually exclusive with Username/NKey/Creds. Zeroed on `Close()`. |
| `Auth.NKeyPath` | `string` | `""` | — | 4096 bytes | Path to .nk file; file must be readable. |
| `Auth.CredentialsFile` | `string` | `""` | — | 4096 bytes | Path to .creds file; file must be readable. |
| `JetStreamPublishAckWait` | `time.Duration` | `5s` | `100ms` | `60s` | Must be > 0. |
| `JetStreamPublishDedupWindow` | `time.Duration` | `2m` | `0` | `1h` | 0 = dedup disabled. |
| `EnableMsgID` | `bool` | `true` | — | — | Generates `Nats-Msg-Id` UUID on each JetStream publish. |
| `NakDelay` | `time.Duration` | `5s` | `0` | `5m` | Delay before redelivery on handler error. 0 = immediate nak. |
| `MaxFetchBatch` | `int` | `256` | `1` | `4096` | Must be ≥ 1. |
| `MaxObjectSize` | `int64` | `1073741824` | `1` | `17179869184` (16 GiB) | OS streaming; no full-buffer. |
| `KVBucketDefaults` | `jetstream.KeyValueConfig` | — | — | — | If bucket created by SDK: `History` ≥ 1, `TTL` ≥ 0. |
| `CircuitBreaker` | `circuitbreaker.Config` | SDK defaults | — | — | Delegated to `$SDK_ROOT/core/circuitbreaker` validation. |
| `OTel` | `otel.Config` | SDK defaults | — | — | Delegated to `$SDK_ROOT/otel` validation. |
| **[MISSING]** `PublishRetryAttempts` | `int` | `3` | `0` | `10` | Add to Config. Mentioned in §9 but absent from struct. |
| **[MISSING]** `PublishRetryBaseDelay` | `time.Duration` | `100ms` | `10ms` | `5s` | Add to Config. Mentioned in §9. |
| **[MISSING]** `PublishRetryMaxDelay` | `time.Duration` | `2s` | `100ms` | `60s` | Add to Config. Mentioned in §9. |
| **[MISSING]** `PublishRetryMultiplier` | `float64` | `2.0` | `1.0` | `10.0` | Add to Config. Mentioned in §9. |
| **[MISSING]** `SlowConsumerWarnThreshold` | `time.Duration` | `1s` | — | — | Add to Config. Mentioned in §9 metrics but absent. |
| **[MISSING]** `OnReconnect` | `func()` | `nil` | — | — | Add to Config. Mentioned in §9 behavior. |
| **[MISSING]** `OnPermanentDisconnect` | `func(error)` | `nil` | — | — | Add to Config. Mentioned in §9 behavior. |

---

## §7. Config + API

```go
// Package nats provides a production-grade NATS/JetStream client for motadatagosdk.
// [traces-to: TPRD-1-FR-CON-01]
package nats

import (
    "context"
    "crypto/tls"
    "io"
    "time"

    "github.com/nats-io/nats.go"
    "github.com/nats-io/nats.go/jetstream"
    "$SDK_ROOT/core/circuitbreaker"
    "$SDK_ROOT/otel"
)

// TLSConfig holds transport-layer security settings.
// [traces-to: TPRD-6-validation]
type TLSConfig struct {
    Enable             bool
    MinVersion         uint16 // tls.VersionTLS12 or tls.VersionTLS13
    CertFile           string
    KeyFile            string
    CAFile             string
    InsecureSkipVerify bool // disallowed outside integration build tag
}

// AuthConfig holds NATS authentication credentials.
// Exactly one method may be non-zero. Multiple non-zero fields = ErrInvalidConfig.
// [traces-to: TPRD-6-validation]
type AuthConfig struct {
    Username        string
    Password        string // zeroed on Close
    Token           string // zeroed on Close
    NKeyPath        string
    CredentialsFile string
}

// Config is the single constructor input for the NATS client.
// All fields are validated in New; see §6 for per-field rules.
// [traces-to: TPRD-6-validation]
type Config struct {
    Servers             []string
    ConnectTimeout      time.Duration
    MaxReconnects       int
    ReconnectWait       time.Duration
    ReconnectJitter     time.Duration
    PingInterval        time.Duration
    MaxPingsOutstanding int
    DrainTimeout        time.Duration
    Name                string
    InboxPrefix         string
    MaxPayloadBytes     int
    SubPendingMsgLimit  int
    SubPendingBytesLimit int

    // TLS transport configuration.
    TLS TLSConfig

    // Auth credentials; mutually exclusive fields.
    Auth AuthConfig

    // JetStream settings.
    JetStreamPublishAckWait   time.Duration
    JetStreamPublishDedupWindow time.Duration
    EnableMsgID               bool
    NakDelay                  time.Duration
    MaxFetchBatch             int
    MaxObjectSize             int64
    KVBucketDefaults          jetstream.KeyValueConfig

    // Resilience — publish retry policy.
    PublishRetryAttempts  int
    PublishRetryBaseDelay time.Duration
    PublishRetryMaxDelay  time.Duration
    PublishRetryMultiplier float64

    // Slow consumer threshold.
    SlowConsumerWarnThreshold time.Duration

    // Reconnect callbacks.
    OnReconnect           func()
    OnPermanentDisconnect func(error)

    // Resilience.
    CircuitBreaker circuitbreaker.Config

    // Observability.
    OTel otel.Config
}

// FetchOptions controls a raw JetStream pull-fetch call.
// [traces-to: TPRD-4-FR-JSC-03]
type FetchOptions struct {
    Batch   int
    MaxWait time.Duration
    MaxBytes int
}

// MsgHandler is invoked per received message.
// A non-nil error causes a nak (JetStream) or an error counter increment (core NATS).
// [traces-to: TPRD-4-FR-SUB-06]
type MsgHandler func(ctx context.Context, msg *nats.Msg) error

// Subscription wraps a NATS subscription with lifecycle control.
// [traces-to: TPRD-4-FR-SUB-04]
type Subscription interface {
    Unsubscribe() error
    Subject() string
}

// JetStreamClient exposes JetStream operations.
// [traces-to: TPRD-4-FR-JS-01]
type JetStreamClient interface {
    CreateOrUpdateStream(ctx context.Context, cfg jetstream.StreamConfig) (jetstream.Stream, error)
    DeleteStream(ctx context.Context, name string) error
    StreamInfo(ctx context.Context, name string) (*jetstream.StreamInfo, error)

    Publish(ctx context.Context, subject string, data []byte, opts ...jetstream.PublishOpt) (*jetstream.PubAck, error)
    PublishMsg(ctx context.Context, msg *jetstream.Msg, opts ...jetstream.PublishOpt) (*jetstream.PubAck, error)

    CreateOrUpdateConsumer(ctx context.Context, stream string, cfg jetstream.ConsumerConfig) (jetstream.Consumer, error)
    PullMessages(ctx context.Context, consumer jetstream.Consumer, batchSize int, handler MsgHandler) error
    FetchMessages(ctx context.Context, consumer jetstream.Consumer, opts FetchOptions) (jetstream.MessageBatch, error)
    ConsumerInfo(ctx context.Context, stream, consumer string) (*jetstream.ConsumerInfo, error)

    KeyValueBind(ctx context.Context, bucket string) (jetstream.KeyValue, error)
    KVGet(ctx context.Context, kv jetstream.KeyValue, key string) (jetstream.KeyValueEntry, error)
    KVPut(ctx context.Context, kv jetstream.KeyValue, key string, value []byte) (uint64, error)
    KVDelete(ctx context.Context, kv jetstream.KeyValue, key string) error
    KVPurge(ctx context.Context, kv jetstream.KeyValue, key string) error
    KVWatch(ctx context.Context, kv jetstream.KeyValue, key string) (jetstream.KeyWatcher, error)

    ObjectStoreBind(ctx context.Context, bucket string) (jetstream.ObjectStore, error)
    OSPut(ctx context.Context, os jetstream.ObjectStore, name string, r io.Reader) (*jetstream.ObjectInfo, error)
    OSGet(ctx context.Context, os jetstream.ObjectStore, name string) (io.ReadCloser, error)
    OSDelete(ctx context.Context, os jetstream.ObjectStore, name string) error
    OSWatch(ctx context.Context, os jetstream.ObjectStore) (jetstream.ObjectStoreWatcher, error)
}

// Client is the primary NATS client handle.
// [traces-to: TPRD-4-FR-CON-01]
type Client interface {
    // Core NATS publish.
    Publish(ctx context.Context, subject string, data []byte) error
    PublishMsg(ctx context.Context, msg *nats.Msg) error

    // Core NATS subscribe.
    Subscribe(ctx context.Context, subject string, handler MsgHandler) (Subscription, error)
    QueueSubscribe(ctx context.Context, subject, queue string, handler MsgHandler) (Subscription, error)
    Request(ctx context.Context, subject string, data []byte) (*nats.Msg, error)

    // JetStream access.
    JetStream() (JetStreamClient, error)

    // Lifecycle.
    IsConnected() bool
    Drain(ctx context.Context) error
    Close() error
}

// New constructs and returns a ready-to-use Client.
// Returns ErrInvalidConfig if any Config field fails validation (§6).
// Returns ErrConnect if the initial NATS connection cannot be established.
// [traces-to: TPRD-4-FR-CON-01]
func New(cfg Config) (Client, error)

// Compile-time interface assertions — implementation file must contain:
//   var _ Client          = (*client)(nil)
//   var _ JetStreamClient = (*jetStreamClient)(nil)
//   var _ Subscription    = (*subscription)(nil)

// --- Sentinel errors

var (
    // ErrInvalidConfig is returned when Config validation fails.
    ErrInvalidConfig  = errors.New("nats: invalid config")
    // ErrConnect is returned when the initial connection cannot be established.
    ErrConnect        = errors.New("nats: connect failed")
    // ErrInvalidSubject is returned when a subject fails validation.
    ErrInvalidSubject = errors.New("nats: invalid subject")
    // ErrInvalidKey is returned when a KV key fails validation.
    ErrInvalidKey     = errors.New("nats: invalid kv key")
    // ErrPayloadTooLarge is returned when data exceeds MaxPayloadBytes.
    ErrPayloadTooLarge = errors.New("nats: payload too large")
    // ErrCircuitOpen is returned when the circuit breaker is open.
    ErrCircuitOpen    = errors.New("nats: circuit breaker open")
    // ErrStreamNotFound is returned when a JetStream stream does not exist.
    ErrStreamNotFound = errors.New("nats: stream not found")
    // ErrKeyNotFound is returned on a KV miss.
    ErrKeyNotFound    = errors.New("nats: key not found")
    // ErrDrainTimeout is returned when Drain exceeds DrainTimeout.
    ErrDrainTimeout   = errors.New("nats: drain timeout")
)
```

---

## §8. Observability

### OTel Spans

| Span Name | Kind | Created By | Required Attributes |
|---|---|---|---|
| `nats.publish` | CLIENT | `Publish` / `PublishMsg` | `nats.subject`, `nats.payload_size`, `messaging.system=nats` |
| `nats.jetstream.publish` | CLIENT | `JetStreamPublish` | `nats.subject`, `nats.stream`, `nats.payload_size`, `nats.msg_id` (if EnableMsgID) |
| `nats.subscribe.receive` | CONSUMER | wrapped `MsgHandler` | `nats.subject`, `nats.queue_group` (if any), `messaging.system=nats` |
| `nats.pull.fetch` | CLIENT | `PullMessages` / `FetchMessages` | `nats.stream`, `nats.consumer`, `nats.batch_size` |
| `nats.kv.put` | CLIENT | `KVPut` | `nats.bucket`, `nats.key` |
| `nats.kv.get` | CLIENT | `KVGet` | `nats.bucket`, `nats.key`, `nats.kv.revision` |
| `nats.connect` | INTERNAL | `New` | `nats.server_url` (first), `nats.name` (if set) |
| `nats.reconnect` | INTERNAL | reconnect callback | `nats.reconnect_attempt_num` |

Trace context propagated via `Nats-Trace-Context` message header using W3C TraceContext format.

### OTel Metrics

| Metric Name | Type | Unit | Labels |
|---|---|---|---|
| `nats.publish.duration` | Histogram | ms | `nats.subject`, `status` (ok/error) |
| `nats.publish.messages_total` | Counter | 1 | `nats.subject`, `status` |
| `nats.publish.bytes_total` | Counter | bytes | `nats.subject` |
| `nats.subscribe.messages_received_total` | Counter | 1 | `nats.subject`, `nats.queue_group` |
| `nats.handler.errors_total` | Counter | 1 | `nats.subject`, `error_type` |
| `nats.jetstream.publish.duration` | Histogram | ms | `nats.stream`, `status` |
| `nats.jetstream.publish.ack_total` | Counter | 1 | `nats.stream` |
| `nats.jetstream.fetch.duration` | Histogram | ms | `nats.stream`, `nats.consumer` |
| `nats.jetstream.fetch.messages_total` | Counter | 1 | `nats.stream`, `nats.consumer` |
| `nats.jetstream.nak_total` | Counter | 1 | `nats.stream`, `nats.consumer` |
| `nats.kv.operation.duration` | Histogram | ms | `nats.bucket`, `operation` (get/put/delete/purge) |
| `nats.connection.state` | Gauge | 1 | `nats.name`, `state` (connected/reconnecting/closed) |
| `nats.circuit_breaker.state` | Gauge | 1 | `state` (closed/open/half_open) |
| `nats.circuit_breaker.trips_total` | Counter | 1 | — |

### Structured Logging (zerolog / slog compatible)

All log lines MUST include: `run_id`, `trace_id`, `span_id`, `component=nats`, `level`.

Log events:
- `DEBUG`: each message publish (includes subject, payload size)
- `INFO`: connect, reconnect, drain start, drain complete, close
- `WARN`: slow-consumer detected, circuit open
- `ERROR`: handler error (includes subject, error string stripped of PII)

---

## §9. Resilience

### Circuit Breaker

| Param | Source | Default | Description |
|---|---|---|---|
| `CircuitBreaker.MaxRequests` | `Config.CircuitBreaker` | `1` | Requests allowed in half-open state. |
| `CircuitBreaker.Interval` | `Config.CircuitBreaker` | `0` (reset on open→closed) | Counting window in closed state. |
| `CircuitBreaker.Timeout` | `Config.CircuitBreaker` | `60s` | Time to stay in open before half-open. |
| `CircuitBreaker.Threshold` | `Config.CircuitBreaker` | `5` consecutive failures | Open trigger. |

Circuit breaker wraps: `Publish`, `PublishMsg`, `JetStreamPublish`, `JetStreamPublishMsg`.
Circuit breaker does **NOT** wrap subscribe (it is receive-side) or lifecycle methods.

### Retry Policy (JetStream Publish)

Exponential backoff: `delay = base * (multiplier ^ attempt) ± 20% jitter`, clamped to `[BaseDelay, MaxDelay]`.

Retries MUST be skipped when `ErrCircuitOpen` is returned by the circuit breaker.

**[AMBIGUITY] OQ-05** — If `Config.PublishRetryAttempts = 0`, does CB still apply? Answer required before design.

### Auto-Reconnect Behaviour

| Event | Action |
|---|---|
| Connection drop | Attempt reconnect up to `MaxReconnects`; emit `nats.reconnect_attempt` OTel event. |
| All reconnect attempts exhausted | Call `Config.OnPermanentDisconnect(err)` callback if set; log ERROR. |
| Reconnect succeeded | Call `Config.OnReconnect()` callback if set; log INFO; reset circuit breaker to closed. |

### Backpressure

- `Config.SubPendingMsgLimit` and `Config.SubPendingBytesLimit` limit per-subscription buffers.
- Slow consumer: handler takes > `Config.SlowConsumerWarnThreshold` (default 1 s) → WARN log + `nats.slow_consumer_total` metric increment.

---

## §10. Security

| ID | Requirement |
|---|---|
| SEC-01 | TLS minimum version MUST be TLS 1.2. TLS 1.0 / 1.1 MUST be rejected at compile time (`crypto/tls.VersionTLS12`). |
| SEC-02 | `TLSConfig.InsecureSkipVerify` MUST compile only under `//go:build integration`. Any production binary including the unguarded flag MUST be rejected by `sdk-security-devil` REJECT verdict. |
| SEC-03 | `Auth.Password` and `Auth.Token` fields MUST be zeroed (overwritten with `\0`) in `Close()` before GC. |
| SEC-04 | Credentials files (NKey, .creds) MUST NOT be logged, traced, or included in error messages. |
| SEC-05 | Subject names MUST be sanitized before logging (strip potential PII: avoid logging full subjects with tenant IDs unless truncated). |
| SEC-06 | Message headers used for trace-context propagation MUST NOT leak sensitive span attributes to downstream NATS consumers outside the service trust boundary. |
| SEC-07 | `govulncheck` and `osv-scanner` MUST report zero HIGH/CRITICAL CVEs on all direct and transitive dependencies. |
| SEC-08 | No credentials or keys in test fixtures (`//go:build integration` test files use `.env` + testcontainers-provisioned creds). |
| SEC-09 | Client-certificate verification MUST be enabled by default when `TLS.Enable = true` (i.e., `tls.Config.ClientAuth = tls.RequireAndVerifyClientCert` for mutual TLS scenarios). |
| SEC-10 | Payload size MUST be validated against `Config.MaxPayloadBytes` BEFORE the publish reaches the network layer (defence-in-depth). |

---

## §11. Testing

### Unit Tests

| Area | Table-Driven Cases Required |
|---|---|
| Config validation (`New`) | Valid config; each invalid field (25+ cases matching §6 table); auth mutually-exclusive check; multiple servers; min/max boundary values. |
| Subject validation | Valid subjects; empty subject; leading dot; trailing dot; null byte; 255-byte subject (pass); 256-byte subject (fail). |
| KV key validation | Valid key; empty key; leading dot; trailing dot; invalid chars; 512-byte key (pass); 513-byte key (fail). |
| Payload size check | 1-byte payload; exactly max bytes (pass); max+1 bytes (fail). |
| Circuit breaker integration | Open circuit returns `ErrCircuitOpen`; half-open allows one request; closed allows all. |
| Retry logic | 0 retries; 3 retries with backoff; context cancelled mid-retry. |
| Reconnect callback | `OnReconnect` invoked; `OnPermanentDisconnect` invoked after max attempts. |
| Drain | Drain with running subscriptions; Drain after context timeout returns `ErrDrainTimeout`. |
| Credential zero-out | Password and Token byte-zero verified post-`Close`. |

### Integration Tests (testcontainers)

Image: `nats:latest` with `--js` flag for JetStream.
Build tag: `//go:build integration`

| Test | Scenario |
|---|---|
| `TestConnect_PlainAuth` | Connect with user+password; publish; subscribe; receive. |
| `TestConnect_TokenAuth` | Connect with token. |
| `TestConnect_TLS` | Connect with mTLS (testcontainers with generated cert). |
| `TestPublishSubscribe_RoundTrip` | Publish 1 000 messages; assert all received in order. |
| `TestRequestReply` | Request-reply over core NATS; assert correct payload. |
| `TestJetStream_PublishAndAck` | Publish to JS stream; assert ack sequence. |
| `TestJetStream_PullConsumer` | Create durable pull consumer; fetch 64 msgs; ack all. |
| `TestJetStream_PullConsumer_NakOnError` | Handler returns error; assert redelivery after NakDelay. |
| `TestKV_CRUD` | Put / Get / Delete / Purge lifecycle. |
| `TestKV_Watch` | Watch; put 3 keys; assert 3 watch events; cancel context; assert watcher closed. |
| `TestObjectStore_PutGet` | OSPut 512 KB object; OSGet; byte-compare. |
| `TestDrain_Graceful` | Start subscriber; call Drain; assert all in-flight messages processed. |
| `TestCircuitBreaker_OpenOnFailures` | Disconnect server; publish 6 times; assert CB opens. |
| `TestGoroutineLeak_SubscribeUnsubscribe` | Subscribe 100 subs; unsubscribe all; goleak clean. |
| `TestGoroutineLeak_PullLoop` | Start PullMessages; cancel context; goleak clean. |
| `TestFlakiness` | Run integration suite with `-count=3`; zero failures expected. |

### Benchmarks

File: `$TARGET_PKG/bench_test.go`
All benchmarks use a testcontainers-managed NATS server (loopback).

```go
func BenchmarkPublish_1KB(b *testing.B)         // [traces-to: TPRD-5-NFR-bench]
func BenchmarkPublish_64KB(b *testing.B)        // [traces-to: TPRD-5-NFR-bench]
func BenchmarkPublish_Parallel_8(b *testing.B)  // [traces-to: TPRD-5-NFR-bench]
func BenchmarkJetStreamPublish_1KB(b *testing.B)
func BenchmarkPullFetch_Batch64(b *testing.B)
func BenchmarkKVPut_256B(b *testing.B)
func BenchmarkKVGet_256B(b *testing.B)
func BenchmarkSubscribe_Throughput(b *testing.B)
func BenchmarkConnect(b *testing.B)
func BenchmarkConnect_TLS(b *testing.B)
```

Run command: `go test -bench=. -benchmem -count=10 $TARGET_PKG/... | tee runs/nats-v1/testing/bench-raw.txt`

### Fuzz Targets

| Target | Seeds |
|---|---|
| `FuzzSubjectValidation(f *testing.F)` | Valid subjects, empty string, null byte, 300-char string. |
| `FuzzKVKeyValidation(f *testing.F)` | Valid keys, empty, dots, slashes, unicode, null byte. |
| `FuzzPayloadSizeCheck(f *testing.F)` | 0-byte, 1-byte, max-byte, max+1-byte payloads. |

Run: `go test -fuzz=FuzzSubjectValidation -fuzztime=60s $TARGET_PKG/...`

### Coverage Target

`go test -cover $TARGET_PKG/... | grep -E "^ok"` MUST show ≥ 90% on all packages.

---

## §12. Breaking-Change Risk

**Mode A — New Package.** No existing code in `$TARGET_PKG`.

| Risk | Assessment |
|---|---|
| Semver bump | **Minor** — new package added under existing module; no existing exports modified. |
| Downstream breakage | None — new package; callers opt-in by importing `$TARGET_PKG`. |
| Shared package impact | `$SDK_ROOT/core/circuitbreaker` and `$SDK_ROOT/core/pool` are read-write-reused; MUST NOT modify their exported signatures. |
| Dependency graph | `nats.go` v1.39.x adds ~12 direct transitive deps; `sdk-dep-vet-devil` MUST review all. |
| OTel package impact | New metrics/spans registered; MUST NOT collide with existing `nats.*` instrument names. Verify with `otel.GetMeterProvider()` name collision test. |

`sdk-breaking-change-devil` verdict required: **ACCEPT** (Mode A, no breakage expected by design).

---

## §13. Rollout

### Phase Gate Sequence

```
Phase 0   Intake       — This TPRD + §Skills-Manifest + §Guardrails-Manifest validation; H1 approval → proceed
Phase 1   Design       — api.go.stub, interfaces.md, algorithms.md, concurrency.md; H5 approval
Phase 2   Impl         — TDD red/green/refactor/docs on branch sdk-pipeline/nats-v1; H7 approval
Phase 3   Testing      — Integration + benchmarks + fuzz + leak hunt; H9 approval
Phase 4   Feedback     — skill drift check; learning-engine patches to existing skills with per-patch notifications in learning-notifications.md; H10 merge verdict (user reviews and may revert patches)
```

### §Skills-Manifest (REQUIRED for a detailed TPRD)

| Skill | Min version | Why required |
|---|---|---|
| `sdk-config-struct-pattern` | 1.0.0 | FR-CON-07 Config design |
| `connection-pool-tuning` | 1.0.0 | FR-CON-01 pool sizing |
| `goroutine-leak-prevention` | 1.0.0 | NFR-REL-01 goleak clean |
| `client-shutdown-lifecycle` | 1.0.0 | FR-CON-04/05 Drain + Close |
| `sdk-otel-hook-integration` | 1.0.0 | §8 Observability |
| `otel-instrumentation` | 1.0.0 | §8 OTel spans + metrics |
| `network-error-classification` | 1.0.0 | §9 retry taxonomy |
| `idempotent-retry-safety` | 1.0.0 | FR-JSP-04 retry policy |
| `client-tls-configuration` | 1.0.0 | SEC-01/02/09 TLS |
| `credential-provider-pattern` | 1.0.0 | SEC-03/04 credential hygiene |
| `backpressure-flow-control` | 1.0.0 | FR-SUB-07 slow-consumer |
| `circuit-breaker-policy` | 1.0.0 | §9 circuit breaker |
| `context-deadline-patterns` | 1.0.0 | FR-CON-04 Drain deadline |
| `testcontainers-setup` | 1.0.0 | §11 integration tests |
| `sdk-marker-protocol` | 1.0.0 | §7 `[traces-to:]` markers |

### §Guardrails-Manifest (REQUIRED for a detailed TPRD)

| Guardrail | Applies to | Enforcement |
|---|---|---|
| G01 | all phases | BLOCKER (decision-log valid JSONL) |
| G07 | impl | BLOCKER (target-dir discipline) |
| G20 | intake | BLOCKER (TPRD completeness) |
| G21 | intake | BLOCKER (§Non-Goals populated) |
| G23 | intake | WARN (§Skills-Manifest validation; non-blocking) |
| G24 | intake | BLOCKER (§Guardrails-Manifest validation) |
| G65 | testing | BLOCKER (bench regression >5% new / >10% shared) |
| G69 | testing | BLOCKER (credential hygiene) |
| G90 | meta | BLOCKER (skill-index consistency) |
| G95–G103 | impl | BLOCKER (marker protocol) |

### Deployment Checklist (SDK consumer side)

- [ ] Import `$TARGET_PKG` after go.sum updated
- [ ] Supply `Config.Servers` (at least one URL)
- [ ] Configure `Auth` (choose exactly one method)
- [ ] Set `TLS.Enable = true` in production; provide cert/key/CA paths
- [ ] Set `Config.Name` to service identifier for server-side monitoring
- [ ] Wire `Config.OTel` to service's OTel provider
- [ ] Call `Client.Drain(ctx)` in signal handler (SIGTERM/SIGINT) before `Close()`
- [ ] Confirm NATS server version ≥ 2.10 for JetStream v2 API (PullConsumer)
- [ ] Confirm JetStream enabled on server (`--js` flag or server config `jetstream: enabled`)

### Environment Prerequisites

| Requirement | Version | Check |
|---|---|---|
| NATS Server | ≥ 2.10.x | `nats-server --version` |
| Go | 1.26 | `go version` |
| testcontainers (CI) | ≥ 0.31.x | `go list -m github.com/testcontainers/testcontainers-go` |
| Docker (CI) | ≥ 24.x | `docker --version` |
| govulncheck | latest | `govulncheck ./...` |
| osv-scanner | latest | `osv-scanner ./go.mod` |
| benchstat | latest | `benchstat -version` |
| goleak | ≥ 1.3.x | `go list -m go.uber.org/goleak` |

---

## §14. Pre-Phase-1 Clarifications Required

| ID | Question | Owner | Status | Blocker? |
|---|---|---|---|---|
| OQ-02 | Should `PullMessages` support push-based consumers for backward compat? NATS 2.10 recommends pull-only. | Design lead | **ANSWER REQUIRED** | YES — design phase depends on API shape |
| OQ-03 | JetStream domain isolation: should `Config.JetStreamDomain string` be exposed? Required for multi-account JetStream. | Design lead | **ANSWER REQUIRED** | YES — config completeness |
| OQ-04 | Should KV bucket creation (in `KeyValueBind`) use `CreateOrUpdateKeyValue` (idempotent) or fail-fast if absent? | SDK lead | **ANSWER REQUIRED** | YES — FR-KV-01 behavior unclear |
| OQ-05 | `Config.PublishRetryAttempts = 0` means no retry — should that be enforced even when CB is closed? | Algorithm designer | **ANSWER REQUIRED** | YES — retry/CB interaction undefined |
| OQ-01 | Should the SDK expose a `Micro` / service-framework surface (`nats.Micro`)? Tentative answer: **No** — separate TPRD. | SDK lead | DEFERRED | NO |
| OQ-06 | Should `OSPut` support multipart / chunked uploads for objects > 64 MiB with progress callbacks? | Design lead | DEFERRED | NO |
| OQ-07 | TLS: should `InsecureSkipVerify` be a compile-time error (build constraint) or a runtime panic? Pipeline preference: compile-time. | Security devil | PENDING REVIEW | NO |
| OQ-08 | Credential file hot-reload: excluded from this TPRD — confirm no objection from platform team. | SDK lead | DEFERRED | NO |

---

## Cleanup Summary

**Hardcoded paths replaced:**
- `motadatagosdk/events/nats/` → `$TARGET_PKG`
- `motadatagosdk/core/circuitbreaker` → `$SDK_ROOT/core/circuitbreaker`
- `motadatagosdk/core/pool` → `$SDK_ROOT/core/pool`
- `motadatagosdk/otel` → `$SDK_ROOT/otel`

**Ambiguities marked with `[AMBIGUITY]` or `[MISSING]`:**
- Config struct now includes missing retry params, slow-consumer threshold, reconnect callbacks
- FR-SUB-03 Request circuit-breaker scope clarified (ambiguity noted)
- FR-JSC-02/03 fetch API trade-off noted
- OQ-02/03/04/05 elevated to blockers; must answer before Phase 1

**Document ready for H1 intake review.**

*Cleaned: 2026-04-17 | Paths variabilized | Ambiguities annotated*
