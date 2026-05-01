#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Python profile-no-surprise hot-path coverage gate
# (CLAUDE.md rule 32 axis 2, Python realization).
#
# Reads runs/<id>/impl/profile-cpu.txt produced by sdk-profile-auditor-python
# at M3.5 via `py-spy record --format speedscope` then `py-spy top` text dump,
# OR via `scalene` text output. Extracts top-10 CPU samples by self-percentage,
# intersects with hot_path: true symbols in design/perf-budget.md, asserts
# coverage >= 0.80 over user-code samples.
#
# Python-specific filtering challenges this gate handles:
#   1. asyncio runtime symbols dominate when workload is I/O-bound or wall-time
#      heavy (e.g. _asyncio.Task.__step, selectors.EpollSelector.select). These
#      are runtime overhead, not user logic. Excluded from coverage denominator.
#   2. C-extension symbols show up via their .so / module names (e.g. _socket.send,
#      _pickle.loads, _hashlib.openssl_sha256). Excluded as runtime — caller-attributed
#      analysis would need cum% which py-spy top doesn't always emit reliably.
#   3. Builtin Python module symbols (collections.OrderedDict.__init__,
#      dict.__contains__, etc.) — borderline; excluded as runtime to keep the
#      gate focused on user SDK code.
#
# Verdicts (per CLAUDE.md rule 33):
#   PASS         — coverage >= 0.80 over user-code top-10
#   FAIL         — coverage < 0.80 (declared hot paths don't dominate user code)
#   INCOMPLETE   — profile missing OR < 5 user-code samples
#                  (workload too small / too I/O-bound)
#   skipped      — no perf-budget OR no hot_path: true symbols
#
# py-spy top format expected (one of):
#   %Own  %Total  OwnTime  TotalTime  Function
#    35.0  40.0   0.350s   0.400s    Cache.get (motadatapysdk/cache/__init__.py:42)
#   ...
# OR scalene output (also tabular, with similar % column).
#
# Exit codes:
#   0 — PASS or skipped
#   1 — FAIL
#   2 — INCOMPLETE / INFRA missing
#
# Usage: bash scripts/guardrails/G109-py.sh <run-dir> [<target-dir>]
set -uo pipefail
RUN_DIR="${1:?usage: G109-py.sh <run-dir> [<target-dir>]}"
TARGET="${2:-}"
PIPELINE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "INFRA: python3 is required" >&2
  exit 2
fi

PERF_BUDGET="$RUN_DIR/design/perf-budget.md"
PROFILE="$RUN_DIR/impl/profile-cpu.txt"

APJ="$RUN_DIR/context/active-packages.json"
if [ -f "$APJ" ] && command -v jq >/dev/null 2>&1; then
  PACK="$(jq -r '.target_language // "go"' "$APJ")"
else
  PACK="python"
fi
if [ "$PACK" != "python" ]; then
  echo "skipped — G109-py.sh is the Python variant; active language is $PACK"
  exit 0
fi

if [ ! -f "$PERF_BUDGET" ]; then
  echo "no perf-budget.md (skipped)"
  exit 0
fi

if [ ! -f "$PROFILE" ]; then
  echo "INCOMPLETE: $PROFILE missing — sdk-profile-auditor-python (M3.5) didn't capture CPU profile"
  exit 2
fi

python3 - "$PERF_BUDGET" "$PROFILE" <<'PY'
import pathlib
import re
import sys

perf_budget_path, profile_path = sys.argv[1:3]

COVERAGE_MIN = 0.80
TOP_N = 10
MIN_USER_SAMPLES = 5

text = pathlib.Path(perf_budget_path).read_text()
yaml_blocks = re.findall(r"```yaml\n(.*?)```", text, re.DOTALL)
if not yaml_blocks:
    print("INCOMPLETE: perf-budget.md has no YAML code block")
    sys.exit(2)

try:
    import yaml  # type: ignore
    parsed = yaml.safe_load(yaml_blocks[0])
except ImportError:
    parsed = None

# Collect declared-hot symbols. Match against py-spy's qualified-name format
# (`module.Class.method`). Build matcher tokens from the leaf-2 components.
hot_tokens: list[str] = []
if parsed and isinstance(parsed, dict):
    for sym in parsed.get("symbols", []) or []:
        if not sym.get("hot_path"):
            continue
        name = sym.get("name") or ""
        parts = name.split(".")
        if len(parts) >= 2:
            hot_tokens.append(".".join(parts[-2:]))
        if parts:
            hot_tokens.append(parts[-1])
else:
    sym_pattern = re.compile(
        r"-\s+name:\s*(\S+)\s*\n(.*?)(?=\n  - name:|\Z)",
        re.DOTALL,
    )
    for m in sym_pattern.finditer(yaml_blocks[0]):
        name, body = m.group(1).strip(), m.group(2)
        if not re.search(r"hot_path:\s*true", body):
            continue
        parts = name.split(".")
        if len(parts) >= 2:
            hot_tokens.append(".".join(parts[-2:]))
        if parts:
            hot_tokens.append(parts[-1])

if not hot_tokens:
    print("no hot_path symbols in perf-budget.md (skipped)")
    sys.exit(0)

profile_text = pathlib.Path(profile_path).read_text()

# py-spy top format:
#   %Own  %Total  OwnTime  TotalTime  Function
#    35.0  40.0   0.350s   0.400s     Cache.get (motadatapysdk/cache/__init__.py:42)
# Also accepts scalene "% CPU" column variants.
sample_re = re.compile(
    r"^\s*([\d.]+)\s+[\d.]+\s+[\d.]+s?\s+[\d.]+s?\s+(\S.*?)(?:\s+\([^)]+\))?\s*$",
    re.MULTILINE,
)

# Fallback: simpler "<own%> <function>" format (single column).
fallback_re = re.compile(
    r"^\s*([\d.]+)\s+(\S.*?)(?:\s+\([^)]+\))?\s*$",
    re.MULTILINE,
)


def is_runtime(fn: str) -> bool:
    """Python runtime / asyncio / C-extension / stdlib symbols.

    Excluded from coverage denominator — they're expected overhead.
    """
    runtime_prefixes = (
        # asyncio runtime / event loop
        "_asyncio.", "asyncio.", "selectors.", "concurrent.futures.",
        # C-extension / native
        "<built-in>", "<frozen", "<native>",
        "_socket.", "_ssl.", "_pickle.", "_hashlib.", "_struct.",
        "_io.", "_json.", "_thread.", "_collections.",
        "_decimal.", "_sqlite3.", "_curses.", "_tracemalloc.",
        # Python interpreter / GC
        "gc.", "sys.", "builtins.",
        # Stdlib that's "not user logic"
        "threading.", "queue.", "weakref.",
        # File / network primitives
        "socket.recv", "socket.send", "socket._real_close",
    )
    return any(fn.startswith(p) for p in runtime_prefixes)


# Try py-spy 5-col format first; fall back to 2-col if no matches.
samples: list[tuple[float, str]] = []
for m in sample_re.finditer(profile_text):
    try:
        own_pct = float(m.group(1))
    except ValueError:
        continue
    fn = m.group(2).strip()
    samples.append((own_pct, fn))

if not samples:
    for m in fallback_re.finditer(profile_text):
        try:
            own_pct = float(m.group(1))
        except ValueError:
            continue
        fn = m.group(2).strip()
        # Skip header-like rows
        if "function" in fn.lower() or "%total" in fn.lower():
            continue
        samples.append((own_pct, fn))

if not samples:
    print(f"INCOMPLETE: {profile_path} has no parseable %own samples — re-run sdk-profile-auditor-python")
    sys.exit(2)

samples.sort(reverse=True)
top = samples[:TOP_N]

user_samples = [(p, fn) for p, fn in top if not is_runtime(fn)]
runtime_samples = [(p, fn) for p, fn in top if is_runtime(fn)]

if len(user_samples) < MIN_USER_SAMPLES:
    print(
        f"INCOMPLETE: only {len(user_samples)} user-code samples in top-{TOP_N} "
        f"(need >={MIN_USER_SAMPLES}). Profile may be I/O-bound, asyncio-dominated, or workload-too-small."
    )
    if runtime_samples:
        print(f"  Runtime samples seen: {[fn for _, fn in runtime_samples]}")
    sys.exit(2)


def matches_any_hot(fn: str) -> bool:
    return any(token and token in fn for token in hot_tokens)


user_total = sum(p for p, _ in user_samples)
hot_pct = sum(p for p, fn in user_samples if matches_any_hot(fn))
surprise_pct = user_total - hot_pct

coverage = hot_pct / user_total if user_total > 0 else 0.0

print(f"  Top-{TOP_N} CPU samples (own %):")
for p, fn in top:
    if is_runtime(fn):
        tag = " [runtime]"
    elif matches_any_hot(fn):
        tag = " [declared-hot]"
    else:
        tag = " [SURPRISE]"
    print(f"    {p:5.2f}%  {fn}{tag}")
print(f"  Declared-hot coverage of user-code top-{TOP_N}: {hot_pct:.1f}% / {user_total:.1f}% = {coverage:.3f}")
print(f"  Surprise hotspots (user code not declared hot): {surprise_pct:.1f}%")

if coverage < COVERAGE_MIN:
    print(
        f"FAIL: coverage {coverage:.3f} < {COVERAGE_MIN:.2f} — declared hot paths don't dominate the "
        f"user-code profile. Either (a) declare the surprise functions as hot_path: true in "
        f"perf-budget.md, or (b) refactor so the declared hot paths actually dominate."
    )
    sys.exit(1)

print(f"PASS: coverage {coverage:.3f} >= {COVERAGE_MIN:.2f}")
sys.exit(0)
PY
