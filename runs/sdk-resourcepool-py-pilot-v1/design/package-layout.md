<!-- Generated: 2026-04-29T13:35:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->

# Package Layout — `motadata_py_sdk.resourcepool`

Per Python pack convention C-2 (src/ layout), C-3 (`__init__.py` + `__all__`
+ `py.typed`), C-1 (`pyproject.toml` PEP 517/518/621/639).

```
motadata-py-sdk/                              # repo root (target SDK)
├── pyproject.toml                            # PEP 621 metadata; build-backend hatchling
├── README.md
├── LICENSE                                   # Apache-2.0 (matches Go SDK)
├── .gitignore
├── src/
│   └── motadata_py_sdk/
│       ├── __init__.py                       # top-level package; namespace for sub-clients
│       ├── py.typed                          # PEP 561 marker (empty file)
│       └── resourcepool/
│           ├── __init__.py                   # public exports + __all__
│           ├── _config.py                    # PoolConfig
│           ├── _stats.py                     # PoolStats
│           ├── _errors.py                    # PoolError + descendants
│           ├── _acquired.py                  # AcquiredResource context manager
│           └── _pool.py                      # Pool main class
├── tests/
│   ├── __init__.py
│   ├── conftest.py                           # shared fixtures (assert_no_leaked_tasks, etc.)
│   ├── unit/
│   │   ├── test_construction.py
│   │   ├── test_acquire_release.py
│   │   ├── test_cancellation.py
│   │   ├── test_timeout.py
│   │   ├── test_aclose.py
│   │   └── test_hook_panic.py
│   ├── integration/
│   │   ├── test_contention.py
│   │   └── test_chaos.py
│   ├── bench/
│   │   ├── bench_acquire.py                  # bench_acquire_idle, bench_acquire_resource_idle, bench_try_acquire_idle
│   │   ├── bench_acquire_contention.py
│   │   ├── bench_aclose.py
│   │   ├── bench_release.py
│   │   ├── bench_stats.py
│   │   ├── bench_config_construct.py
│   │   ├── bench_acquired_aenter.py
│   │   └── bench_scaling.py
│   └── leak/
│       └── test_no_leaked_tasks.py
└── docs/
    ├── USAGE.md
    └── DESIGN.md
```

## `src/motadata_py_sdk/resourcepool/__init__.py`

```python
"""Bounded async resource pool for motadata_py_sdk.

See docs/USAGE.md for examples.
"""

from motadata_py_sdk.resourcepool._acquired import AcquiredResource
from motadata_py_sdk.resourcepool._config import PoolConfig
from motadata_py_sdk.resourcepool._errors import (
    ConfigError,
    PoolClosedError,
    PoolEmptyError,
    PoolError,
    ResourceCreationError,
)
from motadata_py_sdk.resourcepool._pool import Pool
from motadata_py_sdk.resourcepool._stats import PoolStats

__all__ = [
    "Pool",
    "PoolConfig",
    "PoolStats",
    "AcquiredResource",
    "PoolError",
    "PoolClosedError",
    "PoolEmptyError",
    "ConfigError",
    "ResourceCreationError",
]
```

## `pyproject.toml` skeleton

```toml
[build-system]
requires = ["hatchling>=1.21"]
build-backend = "hatchling.build"

[project]
name = "motadata-py-sdk"
version = "1.0.0"                       # TPRD §16 Mode A initial version
description = "Async Python SDK for the Motadata platform — resource pool primitive."
requires-python = ">=3.11"              # TPRD §4
readme = "README.md"
license = { file = "LICENSE" }
authors = [
    { name = "Platform SDK", email = "platform-sdk@example.com" }
]
classifiers = [
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
    "Framework :: AsyncIO",
    "License :: OSI Approved :: Apache Software License",
    "Topic :: Software Development :: Libraries :: Python Modules",
    "Typing :: Typed",
]
dependencies = []                       # TPRD §4 — zero runtime deps

[project.optional-dependencies]
dev = [
    "pytest>=8.0,<9.0",
    "pytest-asyncio>=0.23,<0.24",
    "pytest-benchmark>=4.0,<5.0",
    "pytest-cov>=5.0,<6.0",
    "pytest-repeat>=0.9,<1.0",
    "mypy>=1.10,<2.0",
    "ruff>=0.4,<0.5",
    "pip-audit>=2.7,<3.0",
    "safety>=3.0,<4.0",
    "psutil>=5.9,<6.0",
    "py-spy>=0.3,<0.4",
]

[project.urls]
Homepage     = "https://github.com/example/motadata-py-sdk"
Repository   = "https://github.com/example/motadata-py-sdk"
Issues       = "https://github.com/example/motadata-py-sdk/issues"

[tool.hatch.build.targets.wheel]
packages = ["src/motadata_py_sdk"]

[tool.hatch.build.targets.sdist]
include = [
    "/src",
    "/tests",
    "/docs",
    "/pyproject.toml",
    "/README.md",
    "/LICENSE",
]

[tool.pytest.ini_options]
asyncio_mode = "strict"
testpaths = ["tests"]

[tool.coverage.run]
source = ["src/motadata_py_sdk"]
branch = true

[tool.coverage.report]
fail_under = 90
show_missing = true

[tool.mypy]
python_version = "3.11"
strict = true
warn_unreachable = true

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "B", "UP", "ASYNC", "S", "RUF"]
```

## `py.typed` marker

```
src/motadata_py_sdk/py.typed
```
Empty file. Required by PEP 561 so consumers' `mypy --strict` picks up our
type hints.

## Marker comment convention (per `python.json` `marker_comment_syntax`)

Line marker (most common): `# [traces-to: TPRD-§N-id]`
Block marker (long rationale): triple-double-quote docstring with marker
on its own line.

Every public symbol's docstring MUST end with a `[traces-to: TPRD-...]`
marker on its own paragraph (per the api.py.stub).

## Cross-platform notes

- All paths use POSIX separators in source. Tests run on both Linux and
  macOS (TPRD §4); Windows is best-effort but un-CIed.
- `psutil.Process().num_fds()` is Linux/macOS only; on Windows, drift
  signal `open_fds` falls back to `psutil.Process().num_handles()`.
- `tracemalloc` is stdlib on every CPython we target (3.11+).
