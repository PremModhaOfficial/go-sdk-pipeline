# Dependencies (D1) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead` (acting as `sdk-dep-vet-devil` consultant).
**Pre-impl status**: vet pending — `pip-audit` + `safety check` will be run by impl-lead at first dependency add. Design-time conclusions are best-effort against PyPI metadata; dep-vet-devil at M1 makes the binding call.

## License allowlist (per `.claude/settings.json`)

`MIT`, `Apache-2.0`, `BSD-3-Clause`, `BSD-2-Clause`, `ISC`, `0BSD`, `MPL-2.0`.

## Required new dependencies (TPRD §6)

| # | Package | Version pin | License | Justification | TPRD §ref | Risk |
|---|---|---|---|---|---|---|
| 1 | `nats-py` | `>=2.7.0,<3.0` | Apache-2.0 | Core NATS client; provides JetStream + KV + ObjectStore. asyncio-native (mandatory; no sync surface). | §6 §7 §8 | LOW (active maintenance; high adoption) |
| 2 | `msgpack` | `>=1.0.7,<2.0` | Apache-2.0 | Default codec per §4.3.2. C-impl; performance baseline. **SEC-2 fix (D3 iter 1)**: every `msgpack.unpackb()` MUST go through the `msgpack_unpack_safe()` wrapper with explicit `max_str_len` / `max_bin_len` / `max_array_len` / `max_map_len` caps to prevent attacker-controlled length-prefix → pre-allocation OOM. See algorithms.md §A16 for caps + rationale; api.py.stub `msgpack_unpack_safe` for the wrapper signature. | §4.3 | LOW |
| 3 | `opentelemetry-api` | `>=1.30.0,<2.0` | Apache-2.0 | OTel API surface. Match Go semconv 1.24.0 (uses deprecated `messaging.destination` key — code carries the deprecation; no enforcement issue). | §10 | LOW |
| 4 | `opentelemetry-sdk` | `>=1.30.0,<2.0` | Apache-2.0 | OTel SDK (TracerProvider, MeterProvider, BatchSpanProcessor). | §10 | LOW |
| 5 | `opentelemetry-exporter-otlp-proto-grpc` | `>=1.30.0,<2.0` | Apache-2.0 | gRPC OTLP exporter. | §10, §11.3 | LOW |
| 6 | `opentelemetry-exporter-otlp-proto-http` | `>=1.30.0,<2.0` | Apache-2.0 | HTTP OTLP exporter (alternative to gRPC). | §10, §11.3 | LOW |
| 7 | `opentelemetry-propagator-b3` | `>=1.30.0,<2.0` | Apache-2.0 | B3 propagator (single + multi). | §10.2 | LOW |
| 8 | `opentelemetry-propagator-jaeger` | `>=1.30.0,<2.0` | Apache-2.0 | Jaeger propagator. | §10.2 | LOW |
| 9 | `opentelemetry-instrumentation-logging` | `>=0.51b0,<0.63` | Apache-2.0 | LoggingInstrumentor for trace_id/span_id auto-extraction. **DD-001 / SEC-3 fix (D3 iter 1)**: 0.x beta line; minor releases break API; M1 must validate exact upper bound against current PyPI. | §10.6 | MEDIUM (instrumentation is `0.x`-versioned; min-pin separately from API/SDK) |
| 10 | `pydantic` | `>=2.7.0,<3.0` | MIT | v2 ONLY — model_validator API is incompatible with v1. | §11 | LOW |
| 11 | `pydantic-settings` | `>=2.3.0,<3.0` | MIT | `BaseSettings` + `SettingsConfigDict` for env+YAML precedence. | §11.4, §11.6 | LOW |
| 12 | `pyyaml` | `>=6.0,<7.0` | MIT | YAML loader for config (§11.4). **SEC-1 fix (D3 iter 1) — Loader policy**: `yaml.safe_load()` ONLY at impl time (sdk-security-devil grep gate enforces). NEVER use `yaml.load`, `yaml.full_load`, `yaml.unsafe_load`, `yaml.Loader`, `yaml.FullLoader`, `yaml.UnsafeLoader` — they construct arbitrary Python objects = RCE on attacker-controlled config. See algorithms.md §A15 for the full prescription. | §11.4 | LOW |

**Test-only dependencies** (extras `[dev]`):

| # | Package | Version pin | License | Justification | Risk |
|---|---|---|---|---|---|
| 13 | `pytest` | `>=9.0.3` | MIT | Already in `pyproject.toml` (resourcepool); reuse. **DD-002 fix (D3 iter 1)**: bumped from `>=8.0` to `>=9.0.3` to clear GHSA-6w46-j5rx-g56g (CVSS 6.8, vulnerable tmpdir handling) which affects all `<9.0.3`. Dev-only; pip-audit gates on this at M1. | LOW |
| 14 | `pytest-asyncio` | `>=0.23,<2.0` | Apache-2.0 | Already present. **DD-003 fix (D3 iter 1)**: added explicit upper bound; `1.x` release line newly out and `asyncio_mode` defaults differ from `0.x`; M1 must validate asyncio_mode behavior before relaxing the upper bound. | LOW |
| 15 | `pytest-benchmark` | `>=4.0` | BSD-2-Clause | Already present; bench harness. | LOW |
| 16 | `pytest-cov` | `>=4.1` | MIT | Already present. | LOW |
| 17 | `testcontainers` | `>=4.0,<5.0` | Apache-2.0 | Spawn nats-server in Docker for integration tests (§13). Requires Docker on test host (G69 + environment-prerequisites-check). | MEDIUM (Docker-dep; CI must provide) |
| 18 | `import-linter` | `>=2.0` | BSD-2-Clause | Enforce module dependency graph in package-layout.md. | LOW |

**No tooling deps to add** beyond existing pyproject (ruff, mypy, pip-audit, safety already present).

## Transitive dependency analysis

`nats-py 2.7.x` brings `aiohttp` (Apache-2.0; transitive ≤10 deps incl. `aiosignal`, `multidict`, `yarl`, `frozenlist`, `aiohappyeyeballs`). All Apache-2.0 / MIT / BSD. No GPL / LGPL / AGPL contamination.

OTel family brings `protobuf` (BSD-3-Clause), `grpcio` (Apache-2.0), `googleapis-common-protos` (Apache-2.0). Heavy by size (~30MB grpcio wheel) but unavoidable for OTLP exports.

Pydantic v2 brings `pydantic-core` (MIT, Rust-built), `typing-extensions` (PSF — equivalent to BSD).

**Total transitive count estimate**: ~45 deps. Resourcepool baseline transitively ~5. Net add: ~40.

## Per-dep rationale + size

| Package | Wheel size | Last commit age (est.) | Why we need it (1-line) |
|---|---|---|---|
| nats-py | 0.4 MB | <30d | Sole NATS Python client with maintained JetStream / KV / Object support |
| msgpack | 0.3 MB | <90d | Wire-format-defining codec |
| opentelemetry-api | 0.1 MB | <30d | Standard observability API |
| opentelemetry-sdk | 0.5 MB | <30d | Provider impls |
| opentelemetry-exporter-otlp-proto-grpc | 0.2 MB | <30d | OTLP/gRPC export |
| opentelemetry-exporter-otlp-proto-http | 0.2 MB | <30d | OTLP/HTTP export (alternative) |
| opentelemetry-propagator-b3 | 0.05 MB | <30d | B3 propagator config |
| opentelemetry-propagator-jaeger | 0.05 MB | <30d | Jaeger propagator config |
| opentelemetry-instrumentation-logging | 0.05 MB | <30d | trace-id auto-extraction in stdlib logging |
| pydantic | 0.4 MB | <14d | Validation + dataclass replacement |
| pydantic-settings | 0.05 MB | <30d | env+YAML precedence |
| pyyaml | 0.7 MB | <365d (stable) | YAML loading |
| testcontainers | 0.2 MB | <90d | Test-only Docker fixture |
| import-linter | 0.1 MB | <90d | Module-graph contract enforcement |

## CVE / vuln status (design-time WARN; impl-time gate)

| Package | Known CVEs (2024-2026)? | Resolution |
|---|---|---|
| nats-py | 0 known | n/a |
| msgpack | 1 historic (CVE-2022-32149 — fixed in 1.0.4); pin >=1.0.7 covers | pin OK |
| opentelemetry-* family | 0 known on 1.30+ | pin OK |
| pydantic | CVE-2024-3772 in pydantic 1.x (DOS via regex). v2 not affected. | v2 enforced |
| pyyaml | CVE-2020-14343 in <5.4 (arbitrary code exec via load); we pin >=6.0 | pin OK |
| testcontainers | 0 known | n/a |
| grpcio (transitive) | CVE-2023-32731 in <1.53; OTel grpc exporter pulls >=1.59 | OK |
| protobuf (transitive) | CVE-2022-1941 in <3.18; OTel pulls >=4.21 | OK |

**Impl-time gate (M1)**: `sdk-dep-vet-devil` runs `pip-audit` + `safety check --full-report` on the resolved environment. Any HIGH/CRITICAL = BLOCKER. License contradicts allowlist = BLOCKER.

## Updated `pyproject.toml::dependencies`

```toml
dependencies = [
  "nats-py>=2.7.0,<3.0",
  "msgpack>=1.0.7,<2.0",
  "opentelemetry-api>=1.30.0,<2.0",
  "opentelemetry-sdk>=1.30.0,<2.0",
  "opentelemetry-exporter-otlp-proto-grpc>=1.30.0,<2.0",
  "opentelemetry-exporter-otlp-proto-http>=1.30.0,<2.0",
  "opentelemetry-propagator-b3>=1.30.0,<2.0",
  "opentelemetry-propagator-jaeger>=1.30.0,<2.0",
  "opentelemetry-instrumentation-logging>=0.51b0,<0.63",  # DD-001/SEC-3: 0.x beta upper bound
  "pydantic>=2.7.0,<3.0",
  "pydantic-settings>=2.3.0,<3.0",
  "pyyaml>=6.0,<7.0",                                     # SEC-1: safe_load ONLY at impl time
]

[project.optional-dependencies]
dev = [
  # existing pytest + pytest-asyncio + pytest-benchmark + pytest-cov + ruff + mypy + pip-audit + safety
  "pytest>=9.0.3",                # DD-002: GHSA-6w46-j5rx-g56g min-pin
  "pytest-asyncio>=0.23,<2.0",    # DD-003: bound 1.x until M1 validates asyncio_mode
  "testcontainers>=4.0,<5.0",
  "import-linter>=2.0",
]
```

## Forbidden alternatives (considered + rejected)

- `aionats` / other NATS clients → unmaintained or sync-only.
- `pickle` for codec fallback → security risk + non-portable.
- `omegaconf` for config → less Pydantic-idiomatic; redundant with pydantic-settings.
- `python-jose` for any token handling → not needed (NATS auth lives in `nats-py` connection options).
- `cryptography` (direct dep) → not needed; OTel TLS uses `ssl` stdlib + `aiohttp`'s ssl context.

## Cross-language version reference (informational; not consumed)

Go-side pins for parity verification at integration test time:

| Concept | Go pin | Python pin |
|---|---|---|
| OTel API/trace/metric | v1.41.0 | >=1.30 |
| OTel SDK | v1.39.0 | >=1.30 |
| OTel log SDK + log exporters | v0.15.0 | (instrumentation-logging >=0.51b0) |
| B3 propagator | v1.39.0 | >=1.30 |
| Jaeger propagator | v1.39.0 | >=1.30 |
| semconv | v1.24.0 | (no Python equivalent; we hardcode the keys per §10.4) |
| msgpack | vmihailenco v5.4.1 | msgpack-python >=1.0.7 |

**Cross-language interop concern**: Go vmihailenco msgpack v5 emits `timestamp ext type -1` for `time.Time`; Python `msgpack` with `datetime=True, timestamp=3` ALSO emits ext -1. Verified via `intake/research/nats-py.md` (msgpack defaults section). Cross-fixture tests (§14.2 checks 25-26) will catch any drift.

## Forced-bump check (learned pattern from PROMPT-PATCH PP-02-design)

Per the "MVS simulation against real target go.mod at D2" pattern in this lead's prompt — Python equivalent is `pip install --dry-run` against the existing `motadata-py-sdk/pyproject.toml`. Resourcepool baseline has `dependencies = []` (zero runtime deps), so there are NO forced upgrades on existing pinned deps. **No DEP-POLICY-CONFLICT possible at design time.**

When impl-lead lands the first `pip install`, validate that nothing in `[dev]` (existing `pytest>=8`, `mypy>=1.10`, `ruff>=0.4`) gets transitively bumped. Expected: clean.

## Verdict at design (advisory; impl-time binding)

**ACCEPT-WITH-CONDITIONS**. Conditions:

1. `sdk-dep-vet-devil` at M1 runs `pip-audit` + `safety check` on resolved env; reports green.
2. `sdk-dep-vet-devil` re-confirms transitive license set against allowlist.
3. If `nats-py` releases a 2.8+ during impl phase that fixes any soft-pinned issue, defer the bump to a follow-up run (do not chase moving targets mid-impl).
4. M1 validates the `<0.63` upper bound on `opentelemetry-instrumentation-logging` against current PyPI (DD-001/SEC-3); tighten if a known-good 0.62.x is the latest stable.
5. M1 validates `pytest-asyncio 1.x` `asyncio_mode` defaults against the test suite's `pytest.ini`/`pyproject.toml` `asyncio_mode = auto` setting before relaxing the `<2.0` upper bound (DD-003).

## D3 fix loop iter 1 — applied changes (2026-05-02)

| ID | Change | Trigger |
|---|---|---|
| DD-001 / SEC-3 | `opentelemetry-instrumentation-logging` upper bound `<0.63` added | dep-vet-devil + security-devil |
| DD-002 | `pytest` floor raised to `>=9.0.3` (GHSA-6w46-j5rx-g56g) | security-devil + dep-vet-devil |
| DD-003 | `pytest-asyncio` upper bound `<2.0` added (1.x just released) | dep-vet-devil |
| SEC-1 | `pyyaml` Loader policy declared: `yaml.safe_load` ONLY (impl-grep gate) | security-devil; rationale in algorithms.md §A15 |
| SEC-2 | `msgpack.unpackb` MUST go through `msgpack_unpack_safe` wrapper with explicit container caps (impl-grep gate) | security-devil; rationale in algorithms.md §A16 |
