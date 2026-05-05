"""Negative test for the leak-harness fixture (Wave T1 sensitivity check).

NOT committed to the impl branch. Lives in runs/<id>/testing/sandbox/.
Verifies that the snapshot-based detector logic in
``tests/conftest.py::assert_no_leaked_tasks`` actually catches a
deliberately leaked asyncio task.

Strategy:
- Import the conftest module directly to access the fixture's underlying
  generator implementation.
- Drive it manually: pre-snapshot, body that leaks, post-snapshot, assert
  the assertion fires.
- Also drive it with a clean body, assert no false-positive.

If the leak case PASSES (no AssertionError raised), the fixture is
INSENSITIVE — that is ESCALATION:LEAK-HARNESS-INSENSITIVE.

Run via:
    cd /home/prem-modha/projects/nextgen/motadata-py-sdk
    . .venv/bin/activate
    pytest --rootdir=. \\
      /home/prem-modha/projects/nextgen/motadata-sdk-pipeline/runs/\\
sdk-resourcepool-py-pilot-v1/testing/sandbox/test_leak_harness_negative.py
"""

from __future__ import annotations

import asyncio
import importlib.util
from pathlib import Path

import pytest

# Load the project's conftest fixture as a regular module (we are outside the
# test session that would auto-discover it).
_CONFTEST_PATH = (
    Path("/home/prem-modha/projects/nextgen/motadata-py-sdk/tests/conftest.py")
)
_spec = importlib.util.spec_from_file_location("project_conftest", _CONFTEST_PATH)
assert _spec is not None and _spec.loader is not None
_conftest_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_conftest_mod)


async def _run_fixture_with_leak_body() -> bool:
    """Drive the fixture's underlying async-generator with a leaking body.

    Returns True if the fixture raised (sensitivity confirmed), False if it
    silently completed (insensitivity = BLOCKER).
    """
    # The pytest_asyncio.fixture decorator wraps the function; the wrapped
    # callable returns the async-generator the test would consume.
    raw_fn = _conftest_mod.assert_no_leaked_tasks.__wrapped__  # the bare async def
    agen = raw_fn()  # AsyncGenerator[None, None]
    # Pre-yield: takes the snapshot.
    await agen.__anext__()

    # Test body: deliberately leak a task.
    async def long_lived_sleeper() -> None:
        await asyncio.sleep(60)

    leaked_task = asyncio.create_task(long_lived_sleeper())

    # Post-yield: should detect the leak and raise pytest.fail (Failed).
    try:
        await agen.__anext__()
    except StopAsyncIteration:
        # Fixture completed without raising — it MISSED the leak.
        leaked_task.cancel()
        return False
    except BaseException as exc:  # pytest.fail raises Failed (BaseException subclass)
        # The fixture detected the leak and raised. Clean up the leaked task.
        leaked_task.cancel()
        try:
            await leaked_task
        except (asyncio.CancelledError, BaseException):  # noqa: BLE001
            pass
        # We expected this. Reject only if it's a totally unrelated error type.
        msg = str(exc)
        return "Leaked" in msg


async def _run_fixture_with_clean_body() -> bool:
    """Drive the fixture with a clean body. Returns True if no false-positive."""
    raw_fn = _conftest_mod.assert_no_leaked_tasks.__wrapped__
    agen = raw_fn()
    await agen.__anext__()

    # Clean body — no task creation, no leak.
    await asyncio.sleep(0)

    try:
        await agen.__anext__()
    except StopAsyncIteration:
        return True  # generator exhausted cleanly = no false-positive
    except BaseException:  # noqa: BLE001
        return False


@pytest.mark.asyncio
async def test_fixture_catches_deliberate_leak() -> None:
    """SUCCESS: fixture raises with 'Leaked' in message on a leaking body."""
    sensitive = await _run_fixture_with_leak_body()
    assert sensitive, (
        "ESCALATION:LEAK-HARNESS-INSENSITIVE — "
        "assert_no_leaked_tasks did NOT detect a deliberately leaked task"
    )


@pytest.mark.asyncio
async def test_fixture_does_not_false_positive_on_clean_body() -> None:
    """SUCCESS: fixture stays silent when nothing leaks."""
    clean = await _run_fixture_with_clean_body()
    assert clean, "fixture false-positived on a leak-free body"
