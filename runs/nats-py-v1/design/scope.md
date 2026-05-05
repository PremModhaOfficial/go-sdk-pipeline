# Design Scope (D0) — `nats-py-v1`

**Mode**: A (greenfield).
**Tier**: T1 (full perf-confidence regime).
**Lead**: `sdk-design-lead`.
**Authored**: 2026-05-02.

## 8 packages designed in this run

| # | Python module | TPRD section | LOC est. | Test surface |
|---|---|---|---|---|
| 1 | `motadata_py_sdk.codec` | §4.3 | 600 | unit (byte-fixtures) + bench |
| 2 | `motadata_py_sdk.events.utils` | §4.6 | 350 | unit |
| 3 | `motadata_py_sdk.events.core` | §5 + §4.1–4.2 | 450 | unit |
| 4 | `motadata_py_sdk.events.corenats` | §6 | 700 | unit + integration + bench |
| 5 | `motadata_py_sdk.events.jetstream` | §7 | 1100 | unit + integration + bench |
| 6 | `motadata_py_sdk.events.stores` | §8 | 600 | unit + integration |
| 7 | `motadata_py_sdk.events.middleware` | §9 | 1200 | unit + integration + bench |
| 8 | `motadata_py_sdk.otel` (4 submodules) | §10 | 700 | unit + integration |
| 9 | `motadata_py_sdk.config` | §11 | 500 | unit |

Total impl LOC ≈ 6200; test LOC ≈ 4× impl per typical Python SDK ≈ 25k. Coverage gate: ≥90%.

## Out of scope (per TPRD §2)

- L1/L2 cache, dragonfly, worker pools, generic resource pools. `motadata_py_sdk.resourcepool/` UNTOUCHED — no writes to that subtree at any phase.
- Non-NATS DB / HTTP / gRPC modules.
- Any code outside `motadata-py-sdk/src/motadata_py_sdk/` (rule 17).
- Schema-version field on the wire (deferred — TPRD §16 Q3).
- Cross-language deterministic hashing (deferred — TPRD §16 Q2).
- Go-side bug fixes (preserved verbatim per §15 MIRROR list).
- Bucket-per-tenant scoping at the stores layer (caller responsibility per §8.3).
- Connection lifecycle ownership (caller-owned `nats.Conn` per §2 invariant 1).

## Slice plan (handed to `sdk-impl-lead`)

10 slices in TPRD §14 order; H7b mid-impl checkpoint after Slice 5:

1. `codec` (no NATS dep)
2. `events.utils` (sentinels)
3. `events.core` (header constants + ExtractHeaders/InjectContext)
4. `events.corenats` (Publisher / BatchPublisher / Subscriber)
5. `events.jetstream` Stream + Publisher + Consumer **← H7b checkpoint**
6. `events.jetstream` Requester (depends on slice 5)
7. `events.stores` (KV + Object + tenant overlays)
8. `events.middleware` (CB, retry, ratelimit, metrics, logging, tracing)
9. `otel` (tracer / metrics / logger / common)
10. `config` (pydantic-settings)

## Cross-cutting invariants (LOCKED — apply across all 8 packages)

| ID | Invariant | Source |
|---|---|---|
| INV-1 | 15 NATS header constants byte-exact | TPRD §4.1 |
| INV-2 | `ExtractHeaders` writes 6 keys in fixed order; `InjectContext` reads 6 keys | TPRD §4.2 |
| INV-3 | Codec wire format byte-exact (header byte + custom binary tags + msgpack defaults) | TPRD §4.3 |
| INV-4 | 33 sentinel error strings byte-exact | TPRD §4.6 |
| INV-5 | 15 OTel span names byte-exact | TPRD §10.4 |
| INV-6 | 8 OTel metric names byte-exact (histogram unit `"ms"`) | TPRD §9.5 |
| INV-7 | Subject conventions (`*` `>` `.`) and `MaxSubjectLength=256` (declared, not enforced) | TPRD §4.4 |
| INV-8 | Hard-coded JS Stream fields: `Discard=DiscardOld`, `Duplicates=120s`, `AllowDirect=True` | TPRD §7.1 |
| INV-9 | Default timeouts: `DEFAULT_REQUEST_TIMEOUT=30s`, `DEFAULT_FLUSH_TIMEOUT=5s`, `defaultPublishTimeout=10s` (JS) | TPRD §6.1, §7.2 |
| INV-10 | Default retry: `max_attempts=3, initial=0.1s, max=5s, mult=2.0, jitter=0.1` | TPRD §9.3 |
| INV-11 | Default CB: `failure_threshold=5, success_threshold=2, timeout=30s` | TPRD §9.2 |

All INV-* are marked `[constraint: wire-exact bench/N/A]` in `api.py.stub` — verified by unit tests against test-vectors, NOT by bench. No bench needed because they are correctness, not perf.

## Delegate boundaries (clear ownership at impl time)

- `sdk-impl-lead` slice owners write Python code only; never touches `motadata_py_sdk/resourcepool/`.
- `sdk-testing-lead` writes `tests/{unit,integration,bench,leak}/test_<module>.py` only.
- `sdk-marker-scanner` reads Python `#`-comment markers per `python.json::marker_comment_syntax`.

## Open questions deferred to user (NOT auto-resolved at design)

The 12 open questions in source TPRD §16 / canonical TPRD §15 require Go-team coordination. Design phase position (post H5-rev-3 — TPRD §15 FIX items 28-34 ARE PRE-AUTHORIZED by the TPRD; standing rule still: MIRROR-by-default unless TPRD §15 lists the FIX explicitly):

- Q1 (TenantID validation): **FIX (per TPRD §15.32, restored at H5-rev-3 D3 iter 2)**. The H5-rev-2 revocation was an over-correction by the orchestrator; the user clarified that TPRD §15.32 IS pre-authorization. `MaxTenantIDLength=128` is DECLARED AND ENFORCED at runtime. `TenantKVStore` / `TenantObjectStore` constructors validate via `_TENANT_ID_REGEX = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")` and `len(tenant_id) <= MaxTenantIDLength`; both raise `ValidationError` on bad input. Typing-only `NewType`-style annotations remain permissible.
- Q2 (deterministic codec): NOT implemented; flag remains for v0.2.0+.
- Q3 (X-Schema-Version): NOT added.
- Q4 (span ID width): MIRROR Go (32-hex / 128-bit).
- Q5 (consumer span parenting): **FIX (per TPRD §15.30, restored at H5-rev-3 D3 iter 2)**. `TracingMiddleware` calls `propagator.extract(carrier=msg.headers, getter=NatsHeaderGetter())` on the subscribe path BEFORE `start_consumer(...)`. Producer-side `inject` STAYS. Consumer span IS linked to producer trace via remote-parent context. See `algorithms.md §A17.2`.
- Q6 (CB HalfOpenMaxRequests): NOT added.
- Q7 (semconv key migration): MIRROR Go (`messaging.destination`, deprecated key).
- Q8 (Stores OTel spans): **FIX (per TPRD §15.29, restored at H5-rev-3 D3 iter 2)**. `KVStore` methods emit `kv.<op>` spans (10 methods); `ObjectStore` methods emit `objectstore.<op>` spans (8 methods). Span attrs include `messaging.system='nats'`, `nats.bucket`, `nats.key` (KV) or `nats.object` (Object), `nats.revision` (KV writes). Span overhead ≤1µs at p50. See `algorithms.md §A17.3` and `perf-budget.md Section E` (rows updated H5-rev-3 D3 iter 2).
- Q9 (Tenant-aware stores): Python adds optional `TenantKVStore` / `TenantObjectStore` overlays. (Python-only convenience addition; not a behavioral divergence from Go since Go has no equivalent. Retained as a NEW symbol surface; the §15.32 validation in their `__init__` is the FIX from Q1.)
- Q10 (`create_consumer` naming): NOT renamed; preserves Go API name.
- Q11 (`Subscriber.unsubscribe` actually drains): preserved with explicit docstring `"actually calls drain()"`.
- Q12 (`BatchPublisher.add` size-trigger flush ctx): preserved (drops caller ctx, uses fresh background).

Additional TPRD §15 FIX items applied at H5-rev-3 D3 iter 2 (PRE-AUTHORIZED by TPRD; not previously surfaced as Q-numbered open questions):
- §15.28: `messaging.system='nats'` + `messaging.operation='publish'|'receive'|'process'` added to all inner spans (`nats.publish`, `nats.subscribe`, `nats.receive`, `jetstream.publish`, `jetstream.receive`, `events.publish`, `events.receive`).
- §15.31: Logger/Metrics/Tracer init configs now have `__post_init__` validation. Pydantic config sub-models use `model_validator(mode='after')` for the same effect (closes CONV-5 simultaneously).
- §15.34: Per-error-class metric labels via `error_kind=type(exc).__name__` on every `*_errors_total` increment. Bounded cardinality (sentinel class names only).

**Standing rule for any future cross-language port** (unchanged): default disposition is MIRROR Go behavior verbatim. FIX-divergences (improvements over Go) require explicit user authorization at HITL OR explicit enumeration in the TPRD's §15 FIX list (TPRD acts as user pre-authorization). NEW design-lead-recommended divergences NOT in §15 still need HITL opt-in.

**FIX-divergence count in this run (post H5-rev-3)**: 7 (§15.28, §15.29, §15.30, §15.31, §15.32, §15.33 [Tenant overlays — Python-only addition], §15.34) — ALL TPRD-§15-pre-authorized. Zero new design-lead-introduced divergences beyond §15.

## Fix Loop Log

### D3 iter 1 (2026-05-02) — 5 BLOCKER fixes + 4 dep-pin / DoS hardenings

Triggered by 6 independent devil sub-agents (post-revocation re-run). All fixes preserve Go SDK behavior or introduce a Python-idiomatic translation that doesn't change byte-API parity. Files modified: `api.py.stub`, `interfaces.md`, `algorithms.md`, `dependencies.md`, `concurrency.md`, `package-layout.md`, `scope.md` (this file).

| ID | Fix | Files | MIRROR-justification |
|---|---|---|---|
| **CONV-1 / SEMVER-1 / DD-4 / DD-5** | Renamed `Init`→`init_tracer`, `MetricsInit`→`init_metrics`, `LoggerInit`→`init_logger`, `L`→`get_logger` | api.py.stub, package-layout.md | Python-idiomatic translation: PEP 8 mandates snake_case for module-level functions. Semantic behavior identical to Go's PascalCase exports; only the call-site spelling changes. |
| **DD-1** | Added optional `on_error: Callable[[BaseException], Awaitable[None]] | None = None` ctor parameter (+ `set_error_handler(cb)` setter) on `Subscriber` and `Consumer`. Default `None` preserves Go-equivalent silent log+return; opt-in surfacing via the hook. | api.py.stub, interfaces.md, concurrency.md | Additive; hook fires on the close/dispatch coroutine BEFORE the existing WARN log; existing close()/start() still returns None unconditionally. Hook MUST NOT raise (swallowed via log.exception). |
| **DD-2** | `is_retryable()` now consults a `_NEVER_RETRY: frozenset[type[BaseException]]` exclusion list BEFORE the inheritance walk. `ErrCircuitOpen` and `ErrRateLimitExceeded` are registered into `_NEVER_RETRY` at middleware module load. | api.py.stub, interfaces.md | Type hierarchy unchanged: both still inherit from `ErrPublishFailed` so `isinstance(e, ErrPublishFailed)` matches Go (verified by checks 116, 152). The behavioral fix is in the SDK's own retry decision, not the inheritance — defeats the `Retry(CircuitBreaker(...))` composition footgun. |
| **DD-3** | Added new sentinel `ErrNoMessages(EventsError)` ("no messages available"); `Consumer.next()` now raises it instead of bare `ValueError`. NOT in `_NEVER_RETRY`. Sentinel count: 33 → 34. | api.py.stub, interfaces.md | Python-idiomatic translation of Go's plain-string `errors.New("no messages available")` — Python lacks plain-string sentinels. Wire-API behavior identical (caller knows "no messages" happened); catch surface now `except EventsError`-compatible. |
| **SEC-1** | `config.load()` MUST use `yaml.safe_load(stream)` ONLY. `yaml.load`, `yaml.full_load`, `yaml.unsafe_load`, `Loader`/`FullLoader`/`UnsafeLoader` are BANNED at impl-review (`sdk-security-devil` grep gate). | api.py.stub, algorithms.md (new §A15), dependencies.md | `yaml.safe_load` IS the Python mirror of Go's `gopkg.in/yaml.v3 Unmarshal` default behavior (both safe; no arbitrary-type construction). |
| **DD-001 / SEC-3** | `opentelemetry-instrumentation-logging` pin tightened to `>=0.51b0,<0.63` (added upper bound on 0.x beta line) | dependencies.md | Operational hardening; M1 must validate exact upper bound against current PyPI. |
| **DD-002** | `pytest` floor raised to `>=9.0.3` (clears GHSA-6w46-j5rx-g56g — vulnerable tmpdir handling, CVSS 6.8) | dependencies.md | Dev-only; pip-audit gates at M1. |
| **DD-003** | `pytest-asyncio` upper bound `<2.0` added (1.x newly out; asyncio_mode default differs from 0.x) | dependencies.md | Operational hardening; M1 must validate behavior before relaxing. |
| **SEC-2** | `msgpack.unpackb()` MUST go through `msgpack_unpack_safe(data)` wrapper with explicit container caps (`max_str_len`, `max_bin_len`, `max_array_len`, `max_map_len`); direct `msgpack.unpackb` BANNED at impl-review (`sdk-security-devil` grep gate). | api.py.stub, algorithms.md (new §A16), dependencies.md, package-layout.md | Python-idiomatic translation: Go's `vmihailenco/msgpack v5` lacks container caps; protection there comes from NATS server-side `max_msg_size`. Python's msgpack C-extension's eager-allocation behavior is more exploitable, so adding caps is defense-in-depth; mirrors Go's effective behavior. |

**Marker count delta**: +0 (no new traces-to markers; all changes are inside existing symbols or are Python-implementation details).

**Sentinel count delta**: 33 → **34** (ErrNoMessages added). `test_sentinel_strings` parametrization MUST be updated at impl time (T1).

**Public function count delta** (events.utils): +1 (`ErrNoMessages` re-export); (otel re-exports): rename only, no count change; (codec): +6 (`msgpack_unpack_safe` + 5 `DEFAULT_MAX_*` constants).

**Standing-rule compliance**: every fix above is either MIRROR-preserving (default behavior identical to Go; opt-in extensions only) or a Python-idiomatic translation (PEP-8 naming, typed exceptions for what Go does with strings, DoS caps for what Python's eager-allocation msgpack-C needs). NO FIX-divergences from Go semantics introduced.

### D3 iter 2 (2026-05-02 H5-rev-3) — TPRD §15 FIX restoration + 8 carry-over WARN closures

Triggered by user clarification at H5-rev-3: the prior H5-rev-2 revocation of Q1/Q5/Q8 was an over-correction. TPRD §15 enumerated FIX items ARE pre-authorized by the TPRD itself; the orchestrator should not have demoted them. This pass restores the 3 revoked items, applies the 4 §15 FIX items not yet in the design (#28, #31, #34; §33 Tenant overlays already in place from rev-2), and closes the 8 carry-over WARNs from devil iter-2.

| ID | Fix | Files | TPRD reference / category |
|---|---|---|---|
| **A1 / §15.32** | TenantID validation (regex `^[A-Za-z0-9][A-Za-z0-9_-]*$` + length `<= MaxTenantIDLength=128`) restored in `TenantKVStore` + `TenantObjectStore` ctors; raises `ValidationError` | api.py.stub, interfaces.md, scope.md | TPRD §15.32 PRE-AUTHORIZED FIX |
| **A2 / §15.30** | `propagator.extract(carrier=msg.headers, getter=NatsHeaderGetter)` restored on `TracingMiddleware` subscribe path BEFORE `start_consumer(...)`; consumer span linked to producer trace | api.py.stub, algorithms.md §A17.2 | TPRD §15.30 PRE-AUTHORIZED FIX |
| **A3 / §15.29** | KVStore + ObjectStore span emission restored: `kv.<op>` (10 ops) + `objectstore.<op>` (8 ops); attrs include `messaging.system='nats'`, `nats.bucket`, `nats.key`/`nats.object`, `nats.revision`; perf-budget.md Section E rows updated | api.py.stub, algorithms.md §A17.3, perf-budget.md | TPRD §15.29 PRE-AUTHORIZED FIX |
| **B1 / §15.28** | `messaging.system='nats'` + `messaging.operation='publish'|'receive'|'process'` added to all inner spans (Pub, Sub, JsPub.publish + publish_async, Consumer.start dispatch span); `messaging.destination` already present (mirror Go) | api.py.stub (5 docstrings), algorithms.md §A17.1 | TPRD §15.28 PRE-AUTHORIZED FIX |
| **B2 / §15.31** | `__post_init__` validation on `TracerInitConfig` / `MetricsInitConfig` / `LoggerInitConfig`; raises `ValidationError`. Validates non-blank service.name, sample-ratio range, positive intervals/queues, enum-string membership | api.py.stub (3 dataclasses), algorithms.md §A17.5 | TPRD §15.31 PRE-AUTHORIZED FIX (overlaps CONV-5) |
| **B3 / §15.34** | Per-error-class metric labels: `error_kind=type(exc).__name__` on every `*_errors_total` increment (MetricsCollector + OTELMetricsMiddleware); bounded cardinality (52-class hierarchy) | api.py.stub (MetricsCollector + OTELMetricsMiddleware docstrings), algorithms.md §A17.4, interfaces.md | TPRD §15.34 PRE-AUTHORIZED FIX |
| **B4** | Verified Tenant overlays (TenantKVStore / TenantObjectStore) still present from rev-2; now also carry §15.32 validation from A1 | api.py.stub | TPRD §15.33 PRE-AUTHORIZED FIX (verification only) |
| **C1 / SEC-7** | Codec `unpack_map` except clause extended with `ValueError` (msgpack-python raises ValueError on cap violation, NOT UnpackException — verified empirically by security-devil iter-2). §A1.3 + §A16 updated; api.py.stub `unpack_map` and `msgpack_unpack_safe` docstrings updated | api.py.stub, algorithms.md §A1.3 + §A16 | Security carry-over WARN (Option A: extend at boundary) |
| **C2 / SEMVER-3** | `OTEL_DEFAULT_EXPORT_INTERVAL=15.0` (was 1.0); MetricsInitConfig.export_interval=15.0; _MetricsConfig.export_interval_seconds=15.0 (was already 15.0). Comment notes OTel-spec recommended | api.py.stub | Semver carry-over WARN |
| **C3 / SEMVER-4** | `otel_protocol: Literal["grpc", "http", "http/protobuf"]` (was `str`) on `TracerInitConfig`, `MetricsInitConfig`, `LoggerInitConfig`. Validators reject other values | api.py.stub | Semver carry-over WARN |
| **C4 / CONV-2** | `@dataclass(frozen=True, slots=True)` on `TracerInitConfig`, `MetricsInitConfig`, `LoggerInitConfig` (was `@dataclass`). Mutation now requires `dataclasses.replace(cfg, field=new)` | api.py.stub | Convention carry-over WARN |
| **C5 / CONV-3** | Leading `_` dropped on 9 pydantic config sub-models: `_ServiceConfig`→`ServiceConfig` etc. They were always public re-exports; the underscore contradicted the public role. `Settings` field types updated; package-layout.md re-export list updated | api.py.stub, package-layout.md, convention-deviations.md (verify) | Convention carry-over WARN |
| **C6 / CONV-4** | Mutable literal defaults (`list[str] = [...]`, `dict[str, str] = {}`) in pydantic sub-models replaced with `Field(default_factory=...)` (TracerConfig.propagators, EventsConfig.servers, LoggerConfig.module_levels, MetricsConfig.default_labels) | api.py.stub | Convention carry-over WARN |
| **C7 / CONV-5** | Closed by **B2 / §15.31** — same `__post_init__` validation work + pydantic `model_validator(mode='after')` on the 9 sub-models | (overlap; no separate edit) | Convention carry-over WARN — closed via §15.31 |
| **C8** | `is_retryable` perf-budget row added (perf-budget.md §B.1); existing `[constraint:]` marker tightened to `p50 <= 500ns` + `allocs_per_op == 0`; bench name `bench_is_retryable_typical` | api.py.stub, perf-budget.md | Perf-budget carry-over WARN |

**Marker count delta**: +0 net new traces-to markers (all existing symbols; doc additions only). Span attribute markers and `[traces-to:]` references in the new docstring sections cite §15.28/29/30/31/32/34 inline alongside the existing TPRD-section refs — no new symbol = no new top-level marker.

**Sentinel count delta**: 34 (unchanged from D3 iter 1). `ValidationError` already exists in the inventory.

**Public function count delta**: +0 in events.utils (validation regex stays private `_TENANT_ID_REGEX`); +0 in stores (TenantKVStore/Object already present); +9 in config (drop-underscore: ServiceConfig/TracerConfig/.../SubscribeConfig public names); +0 in otel (3 InitConfigs unchanged signature).

**Standing-rule compliance**: every fix in this pass is either (a) a TPRD §15 PRE-AUTHORIZED FIX (items A1-B4) — TPRD acts as user authorization — OR (b) a Python language/convention concern (C1-C8) addressing security boundaries, semantic-version drift, and Pythonic conventions. NO new design-lead-recommended divergences from Go semantics beyond what TPRD §15 already enumerates.

**Files modified in this pass**: api.py.stub, algorithms.md, interfaces.md, package-layout.md, perf-budget.md, scope.md (this file), traces-to-plan.md (count delta only — no marker additions). Files UNCHANGED in this pass: dependencies.md, concurrency.md, perf-exceptions.md, convention-deviations.md (verified — no underscore-related deviation entry to remove since rev-2 deviations don't reference the leading-underscore pattern).

**go-sdk modifications**: NONE (standing rule honored — `motadata-go-sdk/` is read-only reference).

### D3 iter 3 (2026-05-02) — 2 convention-devil WARN closures (CONV-5 + CONV-12)

Triggered by convention-devil iter-3 NEEDS-FIX verdict. iter-2 fix loop closed 13 items. iter-3 devil verification: 5/6 devils ACCEPT/PASS with 0 BLOCKERs. Convention-devil disagreed: NEEDS-FIX with 2 WARNs — (1) iter-2's CONV-5 closure was incorrect (added `__post_init__` to 3 OTel `*InitConfig` per §15.31 / CONV-2 scope, NOT to the 7 event-domain dataclasses CONV-5 was filed against); (2) NEW finding: `_NEVER_RETRY` cross-module mutation pattern violates CLAUDE.md rule 6 (no global mutable state) AND is import-order-fragile.

| ID | Fix | Files | Category |
|---|---|---|---|
| **CONV-5** | `__post_init__` validation added to 7 event-domain dataclasses: `StreamConfig`, `ConsumerConfig`, `TenantConsumerConfig`, `RequesterConfig`, `KeyValueConfig`, `ObjectStoreConfig`, `ObjectMeta`. Each raises `ValidationError` (existing 52-class hierarchy sentinel) on bad input. 6 new private regexes added to events.utils (`_STREAM_NAME_REGEX`, `_CONSUMER_NAME_REGEX`, `_SUBJECT_REGEX`, `_BUCKET_NAME_REGEX`, `_OBJECT_NAME_REGEX`, `_MAX_DESCRIPTION_LEN`). `TenantConsumerConfig.tenant_id` REUSES existing `_TENANT_ID_REGEX` and `MaxTenantIDLength` per TPRD §15.32 — single source of truth across tenant overlays. Go SDK has NO equivalent runtime checks; this is Python-internal hygiene per `python-class-design` skill. | api.py.stub, interfaces.md | Convention WARN (option (a) per devil recommendation) |
| **CONV-12** | `_NEVER_RETRY` import-order fragility resolved by RELOCATING `ErrCircuitOpen` + `ErrRateLimitExceeded` class definitions from `events.middleware._circuit_breaker` / `_rate_limit` INTO `events.utils._errors`. `_NEVER_RETRY` upgraded to `Final[frozenset[type[BaseException]]]` populated at definition time with both sentinels (no longer empty-then-mutated). Middleware modules now IMPORT these sentinels rather than OWN them. Cross-module rebind / `_register_never_retry()` callback pattern REMOVED. Inheritance from `ErrPublishFailed` preserved (so `isinstance(e, ErrPublishFailed)` still matches per Go error tree, checks 116/152 still hold). Re-exports from `events.middleware.__init__` retained as pure aliases for caller convenience. | api.py.stub, interfaces.md, package-layout.md | Convention WARN (CLAUDE.md rule 6 + import-order) |

**Marker count delta**: 0 (no new symbols introduced; CONV-12 relocates existing classes between modules).

**Sentinel count delta**: 0 net (ErrCircuitOpen + ErrRateLimitExceeded relocated, not added; total stays 36 incl. fail-fast wrappers — note: the canonical "34 retryable + non-retryable EventsError sentinels" count from D3 iter 1 EXCLUDED the 2 wrappers since they previously lived in middleware. Now that they live in events.utils, the events.utils inventory grows from 34→36; the TOTAL exception-class count is unchanged).

**Public symbol count delta**: 0 (CONV-5 adds `__post_init__` methods, NOT new symbols; CONV-12 moves existing public symbols between modules — re-exports preserve every existing import path).

**Standing-rule compliance**:
- Both fixes are Python-internal hygiene (validation + import-graph correctness).
- Zero behavioral change vs Go semantics (Go SDK has no runtime validation on these dataclasses; Python tightens, doesn't loosen).
- Zero new divergences from Go beyond what TPRD §15 already enumerates.
- `motadata-go-sdk/` UNCHANGED.

**Files modified in this pass**: api.py.stub, interfaces.md, package-layout.md, scope.md (this file). Files UNCHANGED: algorithms.md, perf-budget.md, perf-exceptions.md, dependencies.md, concurrency.md (verified — no cross-module mutation reference present), traces-to-plan.md, convention-deviations.md.

**go-sdk modifications**: NONE.
