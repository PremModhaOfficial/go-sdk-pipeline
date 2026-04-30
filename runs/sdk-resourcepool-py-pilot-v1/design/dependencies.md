<!-- Generated: 2026-04-29T13:33:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->

# Dependencies — `motadata_py_sdk.resourcepool`

Per CLAUDE.md rule 19, every new dep needs a row here, vetted by
`sdk-dep-vet-devil-python`. License allowlist:
**MIT / Apache-2.0 / BSD / ISC / 0BSD / MPL-2.0**.

TPRD §4 declares **zero direct runtime dependencies** for this package
(`stdlib only`). Only stdlib modules are imported by impl code.

## Runtime dependencies (PEP 621 `[project] dependencies`)

| Package | Version | License | govulncheck | osv / pip-audit | last-commit-age | transitive count | Justification |
|---|---|---|---|---|---|---|---|
| **(none)** | — | — | — | — | — | — | TPRD §4 explicitly: "zero direct runtime deps". Pool uses only stdlib (`asyncio`, `collections`, `dataclasses`, `typing`, `gc`, `tracemalloc`). |

## Stdlib-only modules used by impl

| Module | Used for | Notes |
|---|---|---|
| `asyncio` | Lock, Condition, Event, Future, TaskGroup (3.11+), timeout (3.11+), CancelledError | Hot-path primitive; canonical async runtime. |
| `collections` | `deque` for idle-slot LIFO storage | LIFO over FIFO chosen for warm-cache locality on the hot path. |
| `dataclasses` | `@dataclass(frozen=True, slots=True)` for PoolConfig and PoolStats | Per `python-sdk-config-pattern` skill. |
| `typing` | `Generic[T]`, `TypeVar`, `Awaitable`, `Callable` | Required for mypy --strict. |
| `inspect` | `iscoroutinefunction` — distinguishes sync vs async hooks | Used once at `Pool.__init__`; never on hot path. |
| `weakref` | (Possible) `WeakSet[asyncio.Task]` for cancel-safe outstanding-task tracker | Confirmed at impl time; if used, no escape hatch. |
| `logging` | `logging.getLogger("motadata_py_sdk.resourcepool")` for WARN on `on_destroy` failure | Per `python-otel-instrumentation` skill (deferred OTel wiring uses `LoggingHandler`). |

## Dev dependencies (PEP 621 `[project.optional-dependencies] dev`)

These are CI-only; never shipped to runtime users.

| Package | Version (pinned) | License | pip-audit | safety | last-commit-age | Justification |
|---|---|---|---|---|---|---|
| `pytest` | `>=8.0,<9.0` | MIT | clean (per pip-audit DB at 2026-04-29) | clean | active | TPRD §4 mandates `pytest 8.x`; canonical Python test runner. |
| `pytest-asyncio` | `>=0.23,<0.24` | Apache-2.0 | clean | clean | active | TPRD §11.4 requires asyncio test support; strict-mode default. |
| `pytest-benchmark` | `>=4.0,<5.0` | BSD-2-Clause | clean | clean | active | TPRD §11.3; `pytest-benchmark` JSON output is the bench artifact. |
| `pytest-cov` | `>=5.0,<6.0` | MIT | clean | clean | active | Coverage gate (TPRD §11.1: ≥90%). |
| `pytest-repeat` | `>=0.9,<1.0` | MPL-2.0 | clean | clean | active | TPRD §11.5 `--count=10` flake-detection on contention/cancellation tests. |
| `mypy` | `>=1.10,<2.0` | MIT | clean | clean | active | TPRD §2: `mypy --strict` must pass. |
| `ruff` | `>=0.4,<0.5` | MIT | clean | clean | active | TPRD §4 + python toolchain block: `ruff check` + `ruff format --check`. |
| `pip-audit` | `>=2.7,<3.0` | Apache-2.0 | self | clean | active | Supply-chain gate (active-packages toolchain.supply_chain[0]). |
| `safety` | `>=3.0,<4.0` | MIT | clean | self | active | Supply-chain gate (toolchain.supply_chain[1]); cross-check against pip-audit. |
| `psutil` | `>=5.9,<6.0` | BSD-3-Clause | clean | clean | active | Drift signals: `rss_bytes`, `open_fds`, `num_fds()`. Soak-runner only. |
| `py-spy` | `>=0.3,<0.4` | MIT | clean | clean | active | M3.5 profile-auditor — speedscope JSON output. |
| `tracemalloc` | (stdlib) | PSF | — | — | — | Heap accounting — no install. |

All licenses on the allowlist (MIT, Apache-2.0, BSD-3-Clause, BSD-2-Clause,
MPL-2.0). PSF (stdlib) is not on the allowlist but is also not "vendored" — it
ships with CPython itself.

## Transitive surface

`pytest 8.x` brings `pluggy`, `iniconfig`, `packaging` (all MIT/Apache-2.0).
`pytest-benchmark` brings `py-cpuinfo` (MIT). `psutil` is pure-Python wheels
on Linux/macOS/Windows. `py-spy` is a Rust binary distributed via wheels;
no Python transitive deps.

Total transitive count for dev extras: **~12 packages** — all on allowlist.

## Verdict requested from `sdk-dep-vet-devil-python`

- **Runtime**: `ACCEPT` — zero deps; impossible to fail vetting.
- **Dev (per dep)**: `ACCEPT` requested for all 11 entries above. Rationale
  individually documented per row. Aggregate verdict: see
  `runs/.../design/reviews/dep-vet-devil-python-report.md`.

## Forbidden packages (negative declarations)

| Package | Why excluded |
|---|---|
| `anyio` | TPRD §4 declares stdlib `asyncio` only for v1; reconsider in a follow-up if a multi-runtime adapter is requested. |
| `trio` | Same reason as anyio. |
| `aiomisc`, `aiotools` | Add unnecessary surface area; pool primitives are stdlib-sufficient. |
| `pydantic` | Frozen dataclass is enough for PoolConfig — `pydantic.BaseModel` would inflate runtime cost on the hot path. |

## Notes

- Pinning style: `>=X,<Y` (compatible-release, not `~=X.Y` exact-pin) per
  `python-dependency-vetting` skill. Lock-file (`uv.lock` or `requirements.txt`)
  is generated at impl time, not at design.
- `pyproject.toml` PEP 621 `[project] dependencies = []` is intentional and
  visible from PyPI metadata once published — communicates "zero runtime deps"
  to consumers.
