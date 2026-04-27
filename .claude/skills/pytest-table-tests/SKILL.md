---
name: pytest-table-tests
description: Pytest table-driven tests — parametrize with ids, fixtures, indirect, raises with match, tmp_path / monkeypatch / caplog standard fixtures.
version: 1.0.0
status: stable
authored-in: v0.5.0-python-pilot
priority: MUST
tags: [python, testing, pytest, parametrize, fixtures]
trigger-keywords: [pytest, parametrize, fixture, indirect, raises, tmp_path, monkeypatch, caplog, table-driven]
---

# pytest-table-tests (v1.0.0)

## Rationale

Pytest's `@pytest.mark.parametrize` is the Python analog of Go's `t.Run(name, func)` subtests. One test function, N cases, individual pass/fail per case in the report. The pipeline standardizes on this structure for unit tests because: (1) every case is independently named and individually addressable (`pytest -k case-name`), (2) shared fixtures stay in `@pytest.fixture` and are not duplicated per case, (3) negative paths use `pytest.raises(..., match=)` which forces both the exception type AND the message contract into the test. Tests written without `id=` produce unreadable names like `test_x[0-1-True]` and break CI failure triage.

## Activation signals

- Writing unit tests for any pure function or method with multiple input scenarios
- Adding a negative-path case for an SDK API method
- Reviewer cites "unreadable parametrize ids", "fixture recomputed per case", or "raises without match"
- Setting up a fixture that opens a resource (tmp dir, monkeypatched env, captured logs)
- Migrating a stack of similar `def test_x_case_a():` functions to one parametrized test

## `@pytest.mark.parametrize` with named cases

Always wrap each case in `pytest.param(..., id="human-readable")`. Test report shows `test_publish[empty-subject-rejected]` instead of `test_publish[--True]`.

```python
# tests/test_publish.py
from __future__ import annotations
import pytest

from sdk.client import Client, ValidationError, new_client
from sdk.config import Config


@pytest.fixture
def client() -> Client:
    return new_client(Config(endpoint="https://x", api_key="k"))


@pytest.mark.parametrize(
    ("subject", "payload", "want_error_match"),
    [
        pytest.param("orders.created", b"{}", None, id="happy-path-json"),
        pytest.param("", b"{}", r"subject.*empty", id="empty-subject-rejected"),
        pytest.param("orders.created", b"", r"payload.*empty", id="empty-payload-rejected"),
        pytest.param("a" * 256, b"{}", r"subject.*too long", id="oversize-subject-rejected"),
    ],
)
def test_publish_validation(
    client: Client,
    subject: str,
    payload: bytes,
    want_error_match: str | None,
) -> None:
    if want_error_match is None:
        client.publish(subject, payload)
        return
    with pytest.raises(ValidationError, match=want_error_match):
        client.publish(subject, payload)
```

## Stacking parametrize — outer × inner = matrix

Stacking decorators produces the cartesian product. Use it for "this behavior must hold across both axis A AND axis B".

```python
@pytest.mark.parametrize("compression", ["none", "gzip", "zstd"], ids=lambda c: f"compress-{c}")
@pytest.mark.parametrize("payload_kb", [1, 64, 1024], ids=lambda n: f"size-{n}kb")
def test_publish_roundtrip(client: Client, compression: str, payload_kb: int) -> None:
    payload = b"x" * (payload_kb * 1024)
    ack = client.publish("t", payload, compression=compression)
    assert ack.size == len(payload)
    # Generates 9 cases: size-1kb x compress-none, size-1kb x compress-gzip, ...
```

## Fixtures — shared setup; choose the right scope

`@pytest.fixture` returns the system-under-test or a resource. Default scope is `function` (recomputed per case). For expensive setup (DB container, embedded NATS), set `scope="module"` or `scope="session"` to share across tests.

```python
import pytest
from collections.abc import Iterator
import httpx
import respx


@pytest.fixture(scope="session")
def httpx_mock() -> Iterator[respx.Router]:
    """Module-wide HTTP stub. One MockRouter shared across all tests."""
    with respx.mock(base_url="https://api.example.com") as router:
        yield router


@pytest.fixture
def client(httpx_mock: respx.Router) -> Client:
    """Per-test Client wired to the shared mock."""
    return new_client(Config(endpoint="https://api.example.com", api_key="test"))
```

Rule: a fixture that does NOT mutate state across tests should be `scope="module"` or wider; mutable per-case state stays at default `function` scope.

## `indirect=True` — turn parameter values into fixture inputs

When the parametrize value is a "fixture key" (config preset name, role, etc.), declare the fixture's parameter via `request.param` and pass `indirect=True`. Pytest invokes the fixture with each value before injecting.

```python
@pytest.fixture
def config(request: pytest.FixtureRequest) -> Config:
    return {"minimal": Config(...), "with-retries": Config(...)}[request.param]

@pytest.mark.parametrize("config", ["minimal", "with-retries"], indirect=True,
                         ids=["preset-minimal", "preset-with-retries"])
def test_client_lifecycle(config: Config) -> None:
    assert new_client(config) is not None
```

## `pytest.raises(ExceptionType, match=r"regex")` — negative cases

The `match=` argument applies a regex to the exception's `str()`. Without it, `pytest.raises(ValueError)` passes for ANY ValueError — including ones unrelated to the bug under test. **Always include `match=`** in negative cases.

```python
def test_config_rejects_negative_timeout() -> None:
    with pytest.raises(ConfigError, match=r"timeout_s must be > 0"):
        Config(endpoint="https://x", api_key="k", timeout_s=-1.0)
```

To assert on the exception object itself (custom error code, attribute), capture via `as excinfo` and read `excinfo.value.<attr>`.

## Standard fixtures: `tmp_path`, `monkeypatch`, `caplog`

Use these built-ins instead of writing your own. Each is per-test, auto-cleaned.

| Fixture | Purpose | Example |
|---|---|---|
| `tmp_path` | A `pathlib.Path` to a per-test temp directory; auto-removed | `(tmp_path / "config.toml").write_text(...)` |
| `monkeypatch` | Patch env vars, attributes, dict items; auto-restored | `monkeypatch.setenv("API_KEY", "test")` |
| `caplog` | Capture log records; assert on level / message | `assert "retrying" in caplog.text` |
| `capsys` | Capture stdout/stderr (`out, err = capsys.readouterr()`) | — |

```python
def test_client_logs_on_retry(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    monkeypatch.setenv("SDK_RETRY_MAX", "2")
    caplog.set_level("WARNING", logger="sdk.client")
    # ... exercise client ...
    assert any("retry attempt" in r.message for r in caplog.records)
```

## Async tests — `pytest-asyncio`

For async client tests, mark with `@pytest.mark.asyncio` (requires `pytest-asyncio` plugin). Combine with `parametrize` exactly the same way.

```python
@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("timeout_s", "want_outcome"),
    [
        pytest.param(0.001, "timeout", id="too-short"),
        pytest.param(5.0, "ok", id="comfortable"),
    ],
)
async def test_async_get(client: Client, timeout_s: float, want_outcome: str) -> None:
    if want_outcome == "timeout":
        with pytest.raises(TimeoutError):
            await client.get("k", timeout_s=timeout_s)
    else:
        assert await client.get("k", timeout_s=timeout_s) is not None
```

## Pitfalls

1. **Parametrize without `id=`** — test names become `test_publish[--True]` from raw repr; CI failure triage degrades. Always wrap in `pytest.param(..., id="name")` or pass `ids=[...]`.
2. **Heavy fixture at default `function` scope** — DB container started 50× for 50 cases is hours of CI time. Set `scope="module"` or `"session"` for setup that's read-only across tests.
3. **`pytest.raises(Exc)` without `match=`** — passes for any matching exception type, including bugs that throw the same type for the wrong reason. Always provide `match=r"..."`.
4. **Nested `parametrize` when caller wanted a matrix** — stacking decorators IS the matrix; use `pytest.param` inside one decorator only when cases need individual marks.
5. **Mutating fixture state across cases** — fixture mutation in case 1 leaks into case 2. Make fixture state per-test (default scope) OR explicitly reset in fixture teardown.
6. **`monkeypatch` outside a test** — monkeypatch state is restored at test exit; using it in a fixture without `yield` means restoration happens before the test runs. Use `yield` correctly: setup, `yield`, teardown.
7. **Using `assert exc.message == "..."`** instead of `match=` — `BaseException.message` doesn't exist; use `str(exc)` or `excinfo.value.args`.
8. **Forgetting `pytest-asyncio` `asyncio_mode = "strict"`** — without explicit marks, async tests may run but get silently skipped. Declare in `pyproject.toml` or `pytest.ini`.

## References

- pytest docs — `parametrize`, `fixture`, `raises`, built-in fixtures
- pytest-asyncio plugin — async test support
- pytest-mock plugin — `mocker` fixture wraps `unittest.mock`
- Cross-skill: `python-asyncio-patterns` — async patterns under test; `python-class-design` — Config under construction-validation tests
