# TPRD — NATS Subsystem Port to motadata-py-sdk (run `nats-py-v1`)

> **Canonicalized by**: `sdk-intake-agent` Wave I1 on 2026-05-02 from
> `motadata-py-sdk/PYTHON_SDK_TPRD.md` (2128 lines, 5 modules + consolidated OTel).
>
> **Source-of-truth body** (wire contracts, behavioral specs, conformance lists,
> known issues) is preserved as-authored in §7 (API Surface) by reference to the
> input TPRD sections. Only the canonical 14-section meta-frame is added /
> derived here. The DERIVED tag marks any section not present in the source
> TPRD and back-filled by intake from documented defaults.
>
> **Pipeline version**: `0.5.0` (per `.claude/settings.json`).
> **Target language**: `python` (DERIVED — source TPRD lacked `§Target-Language`).
> **Target tier**: `T1` (DERIVED — full perf-confidence regime per CLAUDE.md rule 32).
> **Mode**: `A` (new package; target tree contains only `src/motadata_py_sdk/resourcepool/`).
> **Run scope decision**: deferred to H1 — source TPRD covers 5 modules + OTel
> which is 5–10× the typical "add a client" TPRD. Intake recommends
> scope-decomposition; see §16.

---

## §Target-Language (DERIVED)

`python`

Default applied per CLAUDE.md rule 34 / `sdk-intake-agent` Wave I5.5 spec
(source TPRD did not declare `§Target-Language`). A
`.claude/package-manifests/python.json` exists (v0.5.0 Phase A scaffold).

## §Target-Tier (DERIVED)

`T1` — full perf-confidence regime (rule 32).

Rationale: NATS messaging is a hot-path subsystem with byte-exact wire
contracts (§4 of source TPRD); regression on publish / subscribe / req-reply
latency or allocation rates would propagate to every downstream consumer of
the SDK. Tier downgrade to T2 would skip the perf-confidence axes and is not
appropriate for a port whose explicit goal is wire-compat with a Go reference
implementation.

## §Required-Packages (DERIVED)

```
shared-core@>=1.0.0
python@>=1.0.0
```

Default applied per the manifest dispatch contract. No optional packages
declared.

---

## 1. Request Type / Purpose

**Mode A — new package addition** to `motadata-py-sdk`.

Add the `motadata_py_sdk.events` subsystem (5 modules: `core`, `corenats`,
`jetstream`, `stores`, `middleware`), the `motadata_py_sdk.codec` package
(custom binary + msgpack), and OTel instrumentation
(`motadata_py_sdk.otel.{tracer,metrics,logger,common}`) plus
`motadata_py_sdk.config` (NATS-relevant subset). Goal: Python SDK that is
**wire-compatible** with the Go SDK at `motadata-go-sdk/src/motadatagosdk/` —
publishers in one language and consumers in the other can share a NATS server.

The target tree currently contains only `src/motadata_py_sdk/resourcepool/`
(prior pilot). All paths added by this run are net-new — no existing-API
preservation concerns (Mode A baseline; no `[owned-by: MANUAL]` markers in the
target).

## 2. Scope / Goals

**In scope** (mirrored from source TPRD §1):

- `events/core` — interfaces, header constants (15 byte-exact), context propagation
- `events/corenats` — Publisher / BatchPublisher / Subscriber over plain NATS
- `events/jetstream` — Stream mgmt, sync + async Publisher, pull Consumer, sync-over-async Requester
- `events/stores` — KV + Object Store wrappers (with optional tenant-aware overlay)
- `events/middleware` — chain framework + 6 middlewares (CB, retry, ratelimit, metrics, logging, tracing)
- `events/utils` — sentinels, MultiError, retryability classifiers, constants
- `codec` — custom binary codec + MsgPack codec (wire-format-defining)
- `otel/{tracer,metrics,logger,common}` — instrumentation surface
- `config` — NATS-relevant subset (connection, JetStream, OTel exporters, service identity)

### Non-Goals

- L1/L2 cache, dragonfly integration, worker pools, generic resource pools (out of scope per source TPRD §1; resourcepool already exists as a separate package and is untouched by this run).
- Non-NATS DB / HTTP / gRPC modules — explicitly out of scope.
- Any code outside `src/motadata_py_sdk/` (target-dir discipline per CLAUDE.md rule 17).
- Schema-version field on the wire — codec evolves additively via headers (source TPRD §2 invariant 3); adding `X-Schema-Version` is an open question for the Go team (source TPRD §16 Q3) and out of scope for this port.
- Cross-language deterministic hashing of codec output — neither Go nor Python codec is deterministic today (source TPRD §4.3.2). An opt-in `deterministic=True` flag is recommended in source TPRD §15.42 but requires Go-side coordination; deferred.
- Go-side bug fixes — defects flagged in source TPRD §15 MIRROR list are preserved verbatim (e.g., `traceparent` not parsed on subscribe-side; `Subscriber.unsubscribe` actually drains; `Requester.close` does not delete ephemeral consumer; CB has no `HalfOpenMaxRequests`). Python-side improvements in source TPRD §15 FIX list (28-43) are advisory and may or may not be in scope depending on H1 scope-decomposition decision.
- Multi-tenant storage isolation at the bucket layer — Go SDK has no tenant-awareness in `events/stores`; Python adds optional `TenantKVStore` / `TenantObjectStore` wrappers (source TPRD §8.3) but bucket-per-tenant scoping is left to caller.
- Connection lifecycle — `nats.Conn` is **caller-owned** (source TPRD §2 invariant 1); Publisher/Subscriber wrappers do not open or close the connection. Out of scope: connection pooling, reconnect orchestration beyond `nats-py` defaults.

## 3. Motivation / Rationale

**Why now**: cross-language deployments (Python services consuming events
published by Go services and vice versa) currently require either (a)
ad-hoc Python re-implementations that drift on header naming or codec layout,
or (b) Go FFI bridges with operational cost. Shipping a first-party Python
port aligned to the Go SDK's wire contracts removes both categories.

**Why a port (not a clean-slate Python design)**: Go is the reference
implementation already in production — the wire contracts are de facto frozen
by deployed consumers. A clean-slate Python design would either drift (bad
for cross-language interop) or have to recreate the same byte-exact
constraints anyway. Porting front-loads the wire-contract enforcement.

**Why all 5 modules together** (NOT per-module separate runs): the modules
are tightly coupled — `corenats.Publisher` calls into `core.ExtractHeaders`;
middleware wraps both `corenats` and `jetstream`; `Requester` composes
`jetstream.Publisher` + an internal pull consumer. A scope decomposition is
possible (see §16 / H1) but would create artificial seams.

## 4. Functional Requirements / API Surface

The functional surface is specified verbatim in the source TPRD
(`runs/nats-py-v1/input.md`). Intake DOES NOT re-author it; downstream phase
leads (design, impl, testing) read both this canonical file and the source
TPRD. Sections with the source-of-truth body:

- **§4 Wire contracts (LOCKED, byte-exact)** — header constants, ExtractHeaders/InjectContext semantics, codec wire format, subject conventions, tenant model, sentinel error inventory. Source TPRD lines 104–344.
- **§5 events/core** — TraceContext, Metadata, context helpers, Publisher / Subscriber / Subscription / MessageHandler protocols. Source TPRD lines 347–435.
- **§6 events/corenats** — Publisher, BatchPublisher, Subscriber concrete impls with semantic specs. Source TPRD lines 438–615.
- **§7 events/jetstream** — Stream mgmt, sync + async Publisher, pull Consumer, Requester. Source TPRD lines 618–985.
- **§8 events/stores** — KVStore, ObjectStore wrappers + optional TenantKVStore / TenantObjectStore overlays. Source TPRD lines 987–1138.
- **§9 events/middleware** — Stack/Chain framework + 6 middlewares with composition rules. Source TPRD lines 1141–1419.
- **§10 OTel instrumentation (consolidated)** — resource attrs, propagators, sampler, span inventory, metrics inventory, log fields, error sentinels, batch settings. Source TPRD lines 1422–1525.
- **§11 Configuration** — events config, publish/subscribe defaults, OTel exporter config, loading precedence, validation rules, suggested pydantic-settings impl. Source TPRD lines 1527–1707.
- **§12 Suggested Python project layout** — directory tree. Source TPRD lines 1711–1775.
- **§14 Master conformance checklist** — 170 numbered checks. Source TPRD lines 1806–1986. **Each numbered check is a testable acceptance criterion.**

**Pipeline-formal canonicalization note**: source TPRD §12 is titled
"Suggested Python project layout" — pipeline schema expects §12 to carry
semver / breaking-change / versioning declarations. Naming mismatch is
flagged here; semver concerns are addressed in §12 below (this canonical
file). Mode A means semver baseline = `0.x` so the mismatch is low-risk.

## 5. Non-Functional Requirements / NFR / Perf Targets

The source TPRD does NOT contain explicit `[constraint: <metric> <op> <value> | bench/<BenchmarkName>]` markers — but it DOES specify:

1. **Byte-exact wire contracts** (source §4) — these are correctness requirements, not perf targets, but they are NFR-class because deviation breaks cross-language interop. Treated as binary PASS/FAIL conformance gates by `sdk-testing-lead`. No latency/allocs/throughput thresholds attached.
2. **Default timeouts and retry parameters** (source §6.2, §7.2, §9.3, §11.2) — these are behavioral defaults, not perf budgets. They MUST match Go-side numbers byte-for-byte (e.g., `DEFAULT_REQUEST_TIMEOUT=30.0s`, `DEFAULT_FLUSH_TIMEOUT=5.0s`, retry initial=100ms / mult=2 / max=5s / jitter=0.1).
3. **Codec known-issue caps** (source §4.3.4 quirk 1) — array length cap at `2^16` (65535), enforced as `ErrDataTooLarge`. Hard limit, not perf budget.
4. **JetStream dedup window** (source §7.1) — 120.0s hard-coded `Stream.duplicates`. Behavioral, not perf.

**Perf budget authoring (Wave D1 of design phase)**: `sdk-perf-architect` MUST
materialize `runs/nats-py-v1/design/perf-budget.md` declaring:

- Per-symbol p50 / p95 / p99 latency targets for the hot paths: `Publisher.publish`, `Publisher.request`, `JsPublisher.publish`, `JsPublisher.publish_async`, `Subscriber.subscribe` callback, `Consumer.start` dispatch loop, `Requester.request`, codec `pack_map` / `unpack_map` over a representative payload.
- Allocation budgets (`allocs_per_op`) for the same set, calibrated against the existing `motadata_py_sdk.resourcepool` baseline (`baselines/python/performance-baselines.json` — recorded `0.04 allocs_per_op` on cycle hot path, `4 allocs_per_op` design budget).
- Reference-impl oracle margins (per CLAUDE.md rule 20 / G108) — likely "≤ 2× Go SDK measured p50 on equivalent benchmark" given Python interpreter overhead and `nats-py` async layer (see §Constraint-feasibility note below).
- Big-O complexity declarations + scaling-sweep targets for `BatchPublisher.flush` (linear in batch size), `MultiCircuitBreaker.get` (constant amortized), `SlidingWindowLimiter.allow` (linear in window-bound queue, bounded).
- MMD seconds for any soak-class symbols (e.g., `Subscriber` long-running with reconnect cycles).

**Intake-time constraint feasibility (CALIBRATION-WARN check, learned pattern from evolution log)**: The source TPRD has NO declared `[constraint: <metric> <op> <value>]` markers, so no I3 cross-check fires as a WARN. However, intake notes the following advisory points for `sdk-perf-architect` to consult at D1:

| Concern | Reference baseline | Note |
|---|---|---|
| Python `nats-py` publish latency floor | nats-py docs cite ~50–200µs over loopback at 1KB payloads (no commit-grade benchmark; not authoritative) | Aspirational p50 < 50µs is mechanically infeasible without C-extension fast-path; budget should target ≥ 200µs. |
| Codec `pack_map` allocs/op | resourcepool baseline measured `0.04 allocs/op` on amortized cycle, suggesting Python is capable of low-alloc paths when designed for it | Codec is more allocation-heavy (per-field tag dispatch); budget should target ≤ 30 allocs/op for a 10-field map, NOT mirror the Go reference's likely <10. |
| Subscriber callback dispatch | nats-py invokes callbacks via `asyncio.create_task` — there is structural per-msg task-creation overhead (~10–30µs) unavoidable | Budget the `Subscriber.subscribe` dispatch p50 with this floor; do not aspire to < 10µs. |

These are advisory; perf-architect is the authority. They are recorded here so
that perf-budget.md does not propagate aspirational Go-derived numbers that
fail at H8.

## 6. Dependencies / Compat Matrix

Verbatim from source TPRD §13:

| Concern | Python lib | Min version | Notes |
|---|---|---|---|
| NATS client | `nats-py` | latest (≥2.x) | asyncio-native; provides JetStream + KV + Object Store |
| MsgPack codec | `msgpack` | ≥1.0 | `use_bin_type=True, raw=False, datetime=True, timestamp=3, strict_map_key=False` |
| OTel API | `opentelemetry-api` | ≥1.30 | Match Go SDK semconv 1.24.0 (uses deprecated `messaging.destination` key) |
| OTel SDK | `opentelemetry-sdk` | ≥1.30 | |
| OTel OTLP exporter (gRPC) | `opentelemetry-exporter-otlp-proto-grpc` | ≥1.30 | |
| OTel OTLP exporter (HTTP) | `opentelemetry-exporter-otlp-proto-http` | ≥1.30 | |
| B3 propagator | `opentelemetry-propagator-b3` | ≥1.30 | |
| Jaeger propagator | `opentelemetry-propagator-jaeger` | ≥1.30 | |
| Config | `pydantic` + `pydantic-settings` | v2 | |
| Tests | `pytest` + `pytest-asyncio` + `testcontainers[nats]` | latest | |

**Go-side reference pins** (do not consume; for cross-language coordination):
OTel API/trace/metric `v1.41.0`, OTel SDK `v1.39.0`, OTel log SDK + log
exporters `v0.15.0`, otelzap bridge `v0.14.0`, B3 propagator `v1.39.0`,
Jaeger propagator `v1.39.0`, semconv `v1.24.0`, vmihailenco/msgpack `v5.4.1`.

Dependency vetting at design phase Wave D-DEP: `pip-audit` + `safety check`
(per `python.json` toolchain) MUST be green pre-merge. License allowlist per
`.claude/settings.json` (MIT / Apache-2.0 / BSD-3-Clause / BSD-2-Clause / ISC
/ 0BSD / MPL-2.0). `sdk-dep-vet-devil` verdict required for each new dep.

## 7. API Surface

See §4 above. Source-of-truth bodies live in `input.md` §4–§11 and §14 (master
conformance checklist of 170 numbered items). Symbol-level marker provenance
(`[traces-to: TPRD-<section>-<id>]`) MUST be attached per CLAUDE.md rule 29
during impl phase; Slice-1 partition is the design lead's responsibility at
D2 / D3.

## 8. Configuration

Verbatim from source TPRD §11. Two parallel config systems coexist in Go
(`config.Config` + `config.EventsConfig`); source TPRD §11.6 recommends
unifying into a single `pydantic-settings` v2 tree. Env-var precedence:
defaults → YAML → env (env wins). Both Go-style flat env vars
(`LOG_LEVEL`, `METRICS_OTEL_ENDPOINT`) AND OTel-standard env vars
(`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`) MUST be accepted
(source TPRD §11.3 note + §15.40 FIX-list item).

## 9. Observability / OTel / Tracing / Metrics

Source TPRD §10 (consolidated), §9.5 (middleware metrics inventory), §9.7
(tracing middleware), §10.4 (span inventory across all NATS code paths), §10.6
(log fields).

**Span inventory** (15 span names, byte-exact — source §10.4): `nats.connect`,
`events.publish`, `events.receive`, `nats.publish`, `nats.subscribe`,
`nats.queue_subscribe`, `nats.receive`, `nats.subscriber.close`,
`jetstream.publish`, `requester.request`, `requester.init`, `stream.create`,
`stream.create_or_update`, `stream.delete`, `stream.purge`.

**Metric inventory** (8 OTel metrics, byte-exact — source §9.5):
`events_publish_total`, `events_publish_errors_total`,
`events_publish_duration_ms` (unit `"ms"`, NOT `"s"`),
`events_receive_total`, `events_receive_errors_total`,
`events_receive_duration_ms`, `events_bytes_sent_total`,
`events_bytes_received_total`. Resulting on-wire names prefix with
`<service_name>_` from registry namespace.

**OTel via `motadata_py_sdk.otel`** (NOT raw OTel API at call sites) — per
CLAUDE.md quality standard 6. Wrapper in `otel/{tracer,metrics,logger,common}`.

**Known OTel gaps from Go SDK** (mirror unless §15 FIX-list item applies):
inner spans (`nats.publish`, `nats.receive`, `jetstream.publish`) miss
`messaging.system="nats"` and `messaging.operation` attrs; consumer span is
NOT linked to producer trace (Go SDK does not call `propagator.extract`); KV /
Object Store emit no spans at all. Python port is RECOMMENDED to fix the
producer-consumer linking via `propagator.extract` (source TPRD §15 item 30)
and add KV / ObjectStore spans (item 29) — pending H1 scope decision.

## 10. Resilience / Error Model / Reliability

Source TPRD §4.6 (sentinel error inventory — 33 sentinels with byte-exact
strings, retryable / temporary classification), §9.2 (circuit breaker), §9.3
(retry middleware with backoff formula), §9.4 (rate limiting — token bucket +
sliding window + per-subject), §9.8 (composition rules — tracing outermost,
retry inside CB, rate-limit positioning).

**Critical resilience invariants** (from source §15 MIRROR list):

- `ErrCircuitOpen` and `ErrRateLimitExceeded` BOTH wrap `ErrPublishFailed` (which is in the retryable set) — naive composition `Retry(CB(...))` will retry on circuit-open. Composition guidance (source §9.8) MUST be enforced via documentation + an example test in conformance checks 152, 153.
- Retry backoff formula is byte-exact and deterministic given the same RNG seed (source §9.3): `backoff = initial * (multiplier ** attempt)`, capped, jittered uniformly in `[-range, +range)`, floored at `initial` only when jitter > 0. Conformance check 119 verifies the schedule.
- `MultiError(n>1).str()` format is byte-exact: `"<n> errors occurred: <slice>"` (source §4.6, conformance 30). `MultiError.unwrap()` returns the FIRST collected error — `is_instance(multi, sentinel)` matches the most significant failure.
- 8 non-retryable sentinels MUST be distinguished from the 25 retryable: `ErrConnectionClosed`, `ErrDuplicateMsg`, `ErrInvalidSubject`, `ErrPermissionDenied`, `ErrInvalidConfig`, `ErrMissingConfig`, `ErrSerializationFailed`, `ErrShutdownInProgress`, plus typed `SerializationError` / `ConfigError` wrappers. `is_retryable(e)` helper enforces.

## 11. Security

Source TPRD §11.1 TLS subset (`tls.enabled`, `cert_file`, `key_file`,
`ca_file`, `skip_verify`); source §4.1 header set (no auth headers — auth is
NATS-server-side via `nats-py` connection options). Sentinel inventory
(§4.6) covers auth failure modes: `ErrAuthFailed`, `ErrAuthExpired`,
`ErrInvalidCredentials`, `ErrPermissionDenied`.

**Credential hygiene** (CLAUDE.md rule 27): integration tests MUST read NATS
auth creds from `.env.example` (committed, fake) + `.env` (gitignored). G69
guardrail enforces no creds in spec/design/test source.

**TLS validation** (source TPRD §11.5): cert+key paired (both empty or both
set); files exist if any of cert/key/ca is set. Pydantic-settings model MUST
enforce this in a `@model_validator(mode="after")`.

**Multi-tenant security** (source §4.5): TenantID is a bare string in Go with
NO validation; declared `MaxTenantIDLength = 128` is unused. Python port
RECOMMENDED to add `__post_init__` validation: non-empty, ≤128 chars, regex
`^[A-Za-z0-9][A-Za-z0-9_-]*$` (subject-token-safe). Stricter than Go — flag
back as gap (source §16 Q1).

## 12. Semver / Backwards-Compat / Versioning (Breaking-Change policy)

Mode A baseline: this is a NEW package. Initial release version: `0.1.0`
(pre-1.0 — explicitly NOT yet stable; semver guarantees do not apply per
SemVer §4). No `[stable-since: vX]` markers attached to any symbol on first
release; the conformance test suite (170 checks from source §14) IS the
contract for v0.1.0 → v1.0.0 progression.

**Semver bump rules** (per CLAUDE.md rule and `sdk-semver-governance` skill,
applicable from v1.0.0 onward):

- Breaking change to any of the 15 byte-exact header constants → MAJOR (cross-language interop break).
- Breaking change to codec wire format → MAJOR (header byte semantics, type tags, length encoding).
- Adding a new sentinel exception → MINOR.
- Changing a sentinel exception's `.Error()` string → MAJOR (it is part of the wire-observable contract via log fields and error responses).
- Changing a default timeout / retry parameter → MINOR if behavior preserved at extremes; otherwise MAJOR.
- Adding a new metric or span name → MINOR.
- Changing a metric or span name (or its unit / kind) → MAJOR.
- Changing the marker comment syntax of `[traces-to:]` etc. (currently `#`-line per python.json `marker_comment_syntax`) → MAJOR.

**Source TPRD §12 naming note**: the source TPRD's §12 is "Suggested Python
project layout" — that content is preserved as informational guidance for
the design phase (target tree for `motadata_py_sdk.events`). The pipeline's
canonical §12 (this section) overlays on top.

## 13. Testing / Test Strategy

Source TPRD §14 (master conformance checklist — 170 numbered checks). Each
check is a testable acceptance criterion mapped to one of:

- **Unit conformance** (default): pytest table-driven test per check; covers wire-byte-exact, sentinel string equality, default value verification.
- **Integration** (~40 checks involving live NATS): testcontainers `nats-server` + JetStream. Coverage: stream mgmt, JS publish dedup, consumer redelivery, KV / Object Store CAS / watch, requester req/reply round-trip.
- **Cross-language fixture conformance** (~10 checks under §14.2 Codec): byte-fixtures emitted by the Go SDK on a one-time CI job, committed under `tests/fixtures/`, decoded by Python — verifies cross-language interop on real bytes.
- **Bench** (Wave T5): hot paths from §5 perf budget; allocation gates per CLAUDE.md rule 20 (G104).
- **Leak** (Wave T6): asyncio task-leak detector per `python.json` toolchain (`pytest tests/leak --asyncio-mode=auto`).
- **Soak** (Wave T5.5, conditional on perf-budget MMD declaration): subscriber long-run + reconnect cycles, drift detection via G106.

**Coverage minimum**: 90% on new package (`python.json` toolchain `coverage_min_pct: 90`; CLAUDE.md rule 14).

**Skills referenced**: `pytest-table-tests` (v1.0.0), `tdd-patterns` (v1.0.0
language-neutral), `asyncio-cancellation-patterns` (v1.0.0) for cancel-aware
test fixtures.

## 14. Rollout / Milestones / Deployment

1. **D1–D5 (design phase)**: API design + ownership-map + perf-budget + dependency-vet. HITL **H5** sign-off.
2. **M1–M10 (impl phase)**: TDD red/green/refactor/docs per module slice. Slice order proposed:
   - Slice 1: `codec` (no NATS dep; foundation for serialization)
   - Slice 2: `events/utils` (sentinels)
   - Slice 3: `events/core` (header constants, context helpers, ExtractHeaders/InjectContext)
   - Slice 4: `events/corenats` (Publisher / BatchPublisher / Subscriber)
   - Slice 5: `events/jetstream` (Stream / Publisher / Consumer)
   - Slice 6: `events/jetstream` Requester (depends on Slice 5)
   - Slice 7: `events/stores` (KV / Object + tenant overlays)
   - Slice 8: `events/middleware` (CB, retry, ratelimit, metrics, logging, tracing)
   - Slice 9: `otel/{tracer,metrics,logger,common}`
   - Slice 10: `config` (pydantic-settings)
   - Inter-slice HITL **H7b** mid-impl checkpoint after Slice 5.
   - Final HITL **H7** impl sign-off.
3. **T1–T10 (testing phase)**: unit + integration + bench + leak + (soak if MMD-declared). HITL **H8** bench sign-off, **H9** testing sign-off.
4. **F1–F5 (feedback phase)**: metrics + drift + coverage + learning-engine (existing-skill patches only, per-patch H10 notification). HITL **H10** merge verdict.

**Deployment**: pipeline writes only to `motadata-py-sdk/` (target dir) and
`runs/nats-py-v1/`. No direct main commit; pipeline branch `sdk-pipeline/nats-py-v1`
created by impl phase. Final diff shown to user at H10 (CLAUDE.md rule 21).

## 15. Clarifications / Open Questions / Risks

**Source TPRD §16 Open Questions** (unresolved Go-team coordination required
before locking byte-exact contracts in Python — DO NOT default these without
H1 explicit acceptance):

1. TenantID validation rules (regex, length).
2. Deterministic codec mode (Go-side coordination needed for cross-language hash compat).
3. Schema versioning (add `X-Schema-Version` header? — currently no).
4. Span ID width (move to W3C 64-bit, or keep 128-bit for compat with deployed traces).
5. Consumer span parenting (fix missing `propagator.extract` in Go, or document as intentional).
6. CB half-open cap (add `HalfOpenMaxRequests`, or remove from doc).
7. `messaging.destination` vs `messaging.destination.name` semconv (move both sides).
8. Stores OTel (add spans/metrics in Go, or accept Python-only divergence).
9. Tenant-aware KV/Object stores (Python-only or backport to Go).
10. `create_consumer` naming (vs `create_or_update_consumer`).
11. `Subscriber.unsubscribe` actually drains (rename or document).
12. `BatchPublisher.add` deprecated ctx behavior (use fresh background ctx for size-trigger flush).

**Intake-derived risks**:

- **R1 — Run scope**: TPRD covers 5 modules + OTel + config. Single-pass run will likely consume multi-million tokens across phases. Intake STRONGLY recommends scope-decomposition; see H1 question 1. Default if H1 says "go full scope": run proceeds with documented budget overrun risk.
- **R2 — Marker protocol on Python**: G95–G103 (marker byte-hash protocol) currently live in the `go` package per a future manifest (not yet authored — `python.json` notes them as Go-only with byte-hash semantics tied to Go source-byte offsets). On a Mode A run with no preserved symbols this is low-risk for THIS run, but H1 should flag the gap so design + impl phases do not assume marker preservation. Resolution path per `python.json::notes.marker_protocol_note`: Python comment syntax (`#`) is already declared; G95–G103 may need to migrate to shared-core OR get python-specific siblings — decide in Phase B based on observed implementation cost.
- **R3 — `nats-py` version pin**: source TPRD says "latest" without a specific version. `sdk-dep-vet-devil` MUST pin a specific minor at design phase Wave D-DEP; use `pip-audit` + `safety check` to confirm CVE-clean.
- **R4 — Python perf-baseline seed quality**: existing `baselines/python/performance-baselines.json` was seeded from `sdk-resourcepool-py-pilot-v1` on a "loaded testing host" (host_load_class, see file). Future regressions for the NATS package will baseline against THIS run; first-seed methodology must follow the same caveat-aware process.
- **R5 — Skills-Manifest absence**: source TPRD has no `§Skills-Manifest`; intake derives it (see §Skills-Manifest below) from the 4 Python-specific skills + relevant shared-core skills. WARN-level per G23; H1 should confirm the derived list.
- **R6 — Guardrails-Manifest absence**: source TPRD has no `§Guardrails-Manifest`; G24 is BLOCKER-level. H1 must explicitly accept a default guardrail set OR cancel. Default proposed below in §Guardrails-Manifest.

---

## §Skills-Manifest (DERIVED at intake; H1 confirmation required)

Per CLAUDE.md rule 23 and `python.json` notes: the source TPRD did not author
this section. Intake derives it from the 4 Python-specific skills shipped in
v0.5.0 Phase A + relevant shared-core skills mapped to TPRD topics. WARN
status from G23 is expected; missing references are auto-filed to
`docs/PROPOSED-SKILLS.md`.

| Skill | Min version | Mapped TPRD topic |
|---|---|---|
| `python-asyncio-patterns` | ≥1.0.0 | source §6 (Subscriber callback dispatch), §7.2 (publish_async), §9 (middleware async chains) |
| `asyncio-cancellation-patterns` | ≥1.0.0 | source §6.4 (Subscriber.close cancel-then-drain), §7.3 (Consumer.start ctx-cancellation), §7.4 (Requester.request ctx.deadline) |
| `python-class-design` | ≥1.0.0 | source §11.6 (pydantic-settings models), §4.6 (sentinel exception subclasses), §5.1 (TraceContext / Metadata dataclasses) |
| `pytest-table-tests` | ≥1.0.0 | source §14 (170-check master conformance); each check is a parametrized test row |
| `tdd-patterns` | ≥1.0.0 | impl phase Slices 1–10 red/green/refactor cycle |
| `network-error-classification` | ≥1.0.0 | source §4.6 (33 sentinels + retryable / temporary classification), `is_retryable` / `is_temporary` helpers |
| `idempotent-retry-safety` | ≥1.0.0 | source §9.3 (retry middleware + backoff formula), §7.2 (JetStream `Nats-Msg-Id` dedup) |
| `circuit-breaker-policy` | ≥1.0.0 | source §9.2 (circuit breaker state machine + composition with retry) |
| `client-rate-limiting` | ≥1.0.0 | source §9.4 (token bucket + sliding window + per-subject) |
| `backpressure-flow-control` | ≥1.0.0 | source §6.3 (BatchPublisher buffering), §9.4 (rate-limit Wait mode) |
| `client-shutdown-lifecycle` | ≥1.0.0 | source §6.4 Subscriber.close, §7.2 Publisher.close, §7.4 Requester.close (drain semantics, idempotency) |
| `client-tls-configuration` | ≥1.0.0 | source §11.1 TLS subset (cert/key/ca + pairing validation) |
| `credential-provider-pattern` | ≥1.0.0 | source §11.1 NATS auth (env + .env per CLAUDE.md rule 27) |
| `client-mock-strategy` | ≥1.0.0 | source §14 (~110 unit conformance checks; mock `nats-py` client interface) |
| `connection-pool-tuning` | ≥1.0.0 | source §11.1 reconnect config (max_attempts, initial/max interval, multiplier, jitter) |
| `otel-instrumentation` | ≥1.0.0 | source §10 consolidated OTel, §9.5 metrics middleware, §9.7 tracing middleware |
| `sdk-otel-hook-integration` | ≥1.0.0 | source §10.4 span inventory, §10.6 log fields auto-extraction from ctx |
| `sdk-config-struct-pattern` | ≥1.0.0 | source §11.6 pydantic-settings (Python analog of Config struct + factory) |
| `sdk-semver-governance` | ≥1.0.0 | §12 above (semver bump rules) |
| `sdk-marker-protocol` | ≥1.0.0 | impl phase `[traces-to: TPRD-<section>-<id>]` markers (CLAUDE.md rule 29) — see R2 risk re: Python marker hash semantics |
| `api-ergonomics-audit` | ≥1.0.0 | design phase devil review |
| `spec-driven-development` | ≥1.0.0 | this intake phase |
| `decision-logging` | ≥1.1.0 | every agent in this run |
| `lifecycle-events` | ≥1.0.0 | every agent lifecycle entry |
| `context-summary-writing` | ≥1.0.0 | every agent context handoff |
| `review-fix-protocol` | ≥1.0.0 | review-fix loops in design / impl / testing |
| `guardrail-validation` | ≥1.1.0 | guardrail-validator agent |
| `conflict-resolution` | ≥1.0.0 | per ownership matrix |
| `feedback-analysis` | ≥1.0.0 | feedback phase |
| `environment-prerequisites-check` | ≥1.0.0 | testcontainers + nats-server local availability |
| `mcp-knowledge-graph` | ≥1.0.0 | optional MCP-aware augmentation per CLAUDE.md rule 31 |

**Notable absences** (intake notes; no auto-filing):

- No Python-specific OTel skill — `otel-instrumentation` is the language-neutral skill (currently has Go examples per shared-core `generalization_debt`); body applies to Python with idiomatic translation.
- No `pytest-asyncio-patterns` skill — tests rely on `pytest-asyncio` documentation directly via context7 + the `python-asyncio-patterns` and `pytest-table-tests` skills jointly.
- No `nats-py-client-patterns` skill — does not exist; covered by `client-mock-strategy` + library docs (context7 lookup at design phase).
- No `pydantic-settings-patterns` skill — covered by `sdk-config-struct-pattern` (Python analog) + library docs.

H1 may amend this list. Approval at H1 is the contract for `sdk-design-lead`
to invoke skills strictly from this set.

## §Guardrails-Manifest (DERIVED at intake; H1 EXPLICIT acceptance required)

**G24 will FAIL on this section in source TPRD** (BLOCKER per agent prompt).
Intake proposes the following default set, derived from the union of:

- `shared-core.json::guardrails` (22 guardrails: G01–G07, G20–G24, G69, G80–G81, G83–G86, G90, G93, G116) — apply to every run.
- `python.json::guardrails` (currently empty per Phase A scaffold; Python-specific guardrails authored lazily as Phase B exposes gaps — see `python.json::notes.phase_a_scope`).
- Tier T1 perf-confidence regime (CLAUDE.md rule 32, axes 1–7): G104 (alloc), G105 (MMD), G106 (drift), G107 (complexity), G108 (oracle), G109 (profile shape), G110 (perf-exception pairing).
- Quality gates referenced by phase contracts (build/vet/lint/fmt, test pass, coverage, supply-chain): G02, G03, G07, G30–G34, G38, G40–G43, G48, G60–G61, G63, G65, G69, G80, G93, G98, G102.

**Marker-protocol guardrails** (G95–G103) — `python.json::notes.marker_protocol_note`
flags these as currently Go-only with byte-hash semantics tied to Go source-byte
offsets. For this Mode A run with NO preserved symbols, hash-comparison
guardrails are low-risk. Intake proposes:

- Include G99 (pipeline-authored symbols MUST have `[traces-to:]` marker) — this works on Python `#` comment syntax already declared in `python.json::marker_comment_syntax`.
- Defer G95 (MANUAL preservation byte-hash), G96 (MANUAL never modified), G100 (`[do-not-regenerate]` lock), G101 (`[stable-since:]` semver gate), G103 (no forged `[traces-to: MANUAL-*]`) — none triggers on a fresh-port Mode A run; if a future iteration introduces preserved symbols, lift these guardrails per the resolution path in `python.json::notes.marker_protocol_note`.
- Include G97 (constraint-bench pairing) ONLY if perf-architect at D1 declares any `[constraint:]` markers; as of intake, the TPRD has none.
- Include G110 (perf-exception pairing) ONLY if any `[perf-exception:]` markers are introduced; same condition.

**Proposed default set for `nats-py-v1`** (sorted; expressed as ranges where contiguous):

```
G01, G02, G03, G04, G05, G06, G07,
G20, G21, G22, G23, G24,
G30, G31, G32, G33, G34,
G38, G40, G41, G42, G43, G48,
G60, G61, G63, G65, G69,
G80, G81, G83, G84, G85, G86,
G90, G93,
G98, G99,
G102,
G104, G105, G106, G107, G108, G109, G110,
G116
```

**Total**: 49 guardrails.

**Excluded** (with rationale):

- **G95, G96, G100, G101, G103** — marker preservation suite; not applicable to Mode A fresh port (no MANUAL symbols, no `[stable-since:]` markers on first release). Lift to active set on first Mode B/C extension run for this package.
- **G97** — `[constraint:]` bench pairing; only triggers if perf-architect declares such markers at D1. Activate if so.

**G24 itself**: included to validate THIS section reflexively on any future
iteration of the TPRD.

H1 must accept this set OR substitute. Intake DOES NOT silently invent the
manifest — explicit acceptance is the gate.

---

## §16 (canonical) — Mode + Scope decomposition recommendation

**Mode**: A. Target `motadata_py_sdk.events` (and adjacencies: `codec`, `otel`,
`config`) does not exist in the target tree. Existing
`motadata_py_sdk.resourcepool` is untouched.

**Scope decomposition** (recommendation; user decides at H1):

| Option | Run scope | Rough size | Risk |
|---|---|---|---|
| **A. Full scope** | All 5 events modules + codec + OTel + config in `nats-py-v1` | 8–12M tokens estimate; 5–10× typical | High budget overrun; multiple H7b mid-impl checkpoints required; reviewer-fleet cycles costly |
| **B. v1+v2 split** (RECOMMENDED) | `nats-py-v1`: `codec` + `events/utils` + `events/core` + `events/corenats`. `nats-py-v2`: `events/jetstream` + `events/stores`. `nats-py-v3`: `events/middleware` + consolidated `otel`. `nats-py-v4`: `config`. | ~2–3M each | Cleanly slice-bounded; each TPRD inherits a stable wire-contract baseline from the prior; lower risk per run |
| **C. Minimal v1** | `nats-py-v1`: `codec` + `events/utils` + `events/core` only (no over-the-wire I/O). All other modules deferred. | ~1M | Fastest to v1; defers all integration testing; produces a wire-contract codec library, not a usable client |

**Intake STRONG recommendation**: Option B. Slice 1 (codec + utils + core +
corenats) is the natural minimum-shippable client; the wire contracts in
source §4 are fully exercised; subsequent runs build on a stable foundation.

If the user chooses Option A at H1, intake records the budget overrun risk
in the decision log and proceeds.

---

**END canonical TPRD.**
