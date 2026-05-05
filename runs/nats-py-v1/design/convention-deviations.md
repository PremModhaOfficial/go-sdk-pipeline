# Convention Deviations (D2) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead`.
**Per learned pattern**: lead's prompt PROMPT-PATCH PP-02-design ("Cross-SDK convention-deviation recording").

This file records deliberate deviations from existing sibling-package patterns in `motadata-py-sdk/`. Future cross-SDK design-standards synthesis (proposed in Phase 4 improvement-planner) consumes this list.

## Deviation 1: Async-first API (NO sync surface)

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool.Pool` exposes `acquire(timeout=...)` as `async def`. Same pattern.

**Deviation in this run**: every public-API I/O method is `async def` (Publisher.publish, Subscriber.subscribe, Stream.create, KVStore.get, etc.). NO sync wrappers.

**Rationale**: NATS Python ecosystem (`nats-py`) is asyncio-native. A sync surface would require thread-pool bridging (slow + leak-prone). `client-shutdown-lifecycle` skill aligns.

**Precedent-setting**: this becomes the convention for all future Python SDKs in this org that wrap async-native libraries. Documented as such.

## Deviation 2: Pydantic v2 BaseSettings for env-driven config (NEW)

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool.PoolConfig` is a frozen+slots dataclass. NO env loading; caller passes pre-built config.

**Deviation in this run**: `motadata_py_sdk.config.Settings` is a `pydantic_settings.BaseSettings` class. Loads from defaults → YAML → env (env wins).

**Rationale**: TPRD §11 explicitly specifies pydantic-settings + YAML + env precedence. Required for cross-language env-var compat with Go SDK (`SERVICE_NAME`, `LOG_LEVEL`, etc.) AND OTel-standard env vars. Frozen+slots dataclass cannot do this.

**Precedent-setting**: introduces `pydantic` + `pydantic-settings` as runtime deps in this org's Python SDK package. First time. Future SDKs needing env config inherit; future SDKs without env config keep using dataclass+slots (resourcepool pattern).

## Deviation 3: Protocol-based interfaces (NEW)

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool` does not define any Protocol; it has only concrete classes.

**Deviation in this run**: `motadata_py_sdk.events.core` defines 5 `typing.Protocol` interfaces (`Publisher`, `Subscriber`, `Subscription`, `MessageHandler` type alias, `NatsMsg`/`JsMsg` Protocols). Concrete impls live in sibling submodules.

**Rationale**: TPRD §5 explicitly specifies an interface package (mirrors Go's `events/core` interface-only design). Mixing two concrete Publisher impls (corenats + jetstream) requires a structural-typing layer for caller flexibility + testing.

**Precedent-setting**: introduces Protocol pattern. Future SDKs with multiple sibling implementations of a contract follow this. Future SDKs with a single concrete impl can skip the Protocol indirection.

## Deviation 4: 33 sentinel exceptions in a single class hierarchy (NEW)

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool` has 5 sentinel exceptions: `PoolError`, `PoolClosedError`, `PoolEmptyError`, `ResourceCreationError`, `ConfigError`. Single-level hierarchy.

**Deviation in this run**: 33 sentinels + 6 wrapper classes + 7 stores-specific sentinels + 5 codec sentinels = 51 exception classes. All under `EventsError` (events) or `CodecError` (codec) bases.

**Rationale**: TPRD §4.6 declares 33 byte-exact wire-observable error strings (cross-language interop requires byte-exactness). Cannot collapse into fewer types without breaking the wire contract. `network-error-classification` skill prescribes a sentinel-per-condition approach.

**Precedent-setting**: large sentinel hierarchies are valid when the sentinels carry wire-observable semantics. Future SDKs should ONLY introduce sentinels with comparable wire-observable claims (logs, error responses).

## Deviation 5: `[traces-to:]` marker via Python `#` line-comment OR docstring (NEW)

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool/__init__.py` uses `[traces-to: TPRD-§5-API-Surface]` and `[stable-since: v1.0.0]` markers in the module docstring (NOT line comments). Pattern was authored manually.

**Deviation in this run**: marker syntax declared in `python.json::marker_comment_syntax`:
- Line: `# [traces-to: ...]`
- Block (docstring): `[traces-to: ...]` on a line inside `"""..."""`.

Pipeline-authored Python symbols use the BLOCK form by default (inside the docstring), with the LINE form available for inline annotations.

**Rationale**: Python convention is to put metadata in docstrings (rendered by tooling). Comments are reserved for transient notes.

**Precedent-setting**: confirms the lazy decision in `python.json::notes.marker_protocol_note` — Python uses docstring-marker form by default. `sdk-marker-scanner` learns BOTH forms.

## Deviation 6: 6 functional options on BatchPublisher (KW-only) — partial functional-options usage

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool.PoolConfig` is a single dataclass; no functional options.

**Deviation in this run**: `BatchPublisher.__init__` takes `publisher: Publisher` positional + 5 KW-only optional knobs (`max_batch_size`, `flush_interval`, `concurrent_flush`, `max_flush_workers`, `on_flush_error`).

**Rationale**: Mirrors Go's variadic functional options for BatchPublisher. Pure config-struct would force callers to create a `BatchPublisherConfig` for what is fundamentally constructor-time tuning. KW-only avoids order-fragility.

**Precedent-setting**: classes with ≤6 optional construction-time knobs may use KW-only optionals over a separate Config struct. Beyond 6 → use Config struct.

## Deviation 7: Hard-coded JS Stream fields (mirror Go limitation)

**Sibling-pkg comparison**: `motadata_py_sdk.resourcepool` exposes every PoolConfig field directly.

**Deviation in this run**: 3 JS Stream fields are hard-coded and NOT exposed in `StreamConfig`: `discard=DiscardOld`, `duplicate_window=120.0s`, `allow_direct=True`.

**Rationale**: TPRD §7.1 declares these as wire-contract invariants. Allowing override would let callers create streams that the Go SDK / consumer expectations cannot match.

**Precedent-setting**: wire-contract invariants may be hard-coded with a [constraint: wire-exact] marker; documenting the limitation in the dataclass docstring is mandatory.

## H5-rev-3 D3 iter 2 (2026-05-02) — verification pass

Reviewed all 7 deviations against the post-iter-2 design state. None of the deviations
reference the leading-underscore-on-public-pydantic-models pattern that CONV-3 closed,
so no deviation entry is removed in this pass.

Verified the deviations remain valid:
- **Deviation 1** (async-first) — unchanged.
- **Deviation 2** (pydantic v2 BaseSettings) — strengthened: now also relies on
  `model_validator(mode='after')` for TPRD §15.31 validation across all 9 sub-models.
- **Deviation 3** (Protocol-based interfaces) — unchanged.
- **Deviation 4** (33→34 sentinels) — count unchanged from D3 iter 1; ValidationError
  is the sentinel raised by §15.32 TenantID validation but already counted.
- **Deviation 5** (marker syntax) — unchanged; H5-rev-3 added inline `§15.<NN>`
  cross-references which travel with existing primary markers.
- **Deviation 6** (KW-only BatchPublisher) — unchanged.
- **Deviation 7** (hard-coded JS Stream fields) — unchanged.

Implicit new convention introduced at H5-rev-3 D3 iter 2 (NOT promoted to a numbered
deviation since it strictly re-aligns with target SDK convention rather than
deviating): `frozen=True, slots=True` on the 3 OTel `*InitConfig` dataclasses.
`motadata_py_sdk.resourcepool.PoolConfig` already uses `frozen=True, slots=True`, so
this matches sibling convention rather than departing from it.

## Cross-cutting note

Once a `docs/design-standards.md` is synthesized in a future run (per improvement-planner proposal), this file should be promoted into the standards doc as the seven Python-specific conventions established by `nats-py-v1`.
