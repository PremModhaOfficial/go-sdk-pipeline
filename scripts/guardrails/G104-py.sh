#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Python heap-budget gate (CLAUDE.md rule 32 axis 3, Python realization).
#
# For every bench in runs/<id>/testing/bench-current.json (pytest-benchmark JSON
# from wave T4), compares `extra_info.peak_memory_b` against per-symbol
# `heap_bytes_per_call` declared in design/perf-budget.md.
#
# Python signal-to-noise is worse than Go (refcount + generational GC + dict-
# resize + string-interning produce ~3× more variance than Go's b.ReportAllocs()).
# So we apply a widened threshold:
#   hot_path: true   → measured ≤ budget × 1.10  (10% headroom)
#   hot_path: false  → measured ≤ budget × 1.20  (20% headroom)
# Gross regressions (>10x over budget on hot path) still fail clean.
#
# Verdicts (per CLAUDE.md rule 33):
#   PASS         — every bench within widened threshold
#   FAIL         — at least one bench over its widened threshold
#   INCOMPLETE   — bench JSON missing OR a budgeted bench is missing
#                  OR the bench has no `extra_info.peak_memory_b`
#                  (pytest-benchmark not run with --benchmark-autosave + plugin)
#   skipped      — no perf-budget, no symbols with heap_bytes_per_call
#
# Exit codes:
#   0 — PASS or skipped
#   1 — FAIL
#   2 — INCOMPLETE / INFRA missing
#
# Usage: bash scripts/guardrails/G104-py.sh <run-dir> [<target-dir>]
set -uo pipefail
RUN_DIR="${1:?usage: G104-py.sh <run-dir> [<target-dir>]}"
TARGET="${2:-}"
PIPELINE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "INFRA: python3 is required" >&2
  exit 2
fi

PERF_BUDGET="$RUN_DIR/design/perf-budget.md"
BENCH_JSON="$RUN_DIR/testing/bench-current.json"

APJ="$RUN_DIR/context/active-packages.json"
if [ -f "$APJ" ] && command -v jq >/dev/null 2>&1; then
  PACK="$(jq -r '.target_language // "go"' "$APJ")"
else
  PACK="python"
fi
if [ "$PACK" != "python" ]; then
  echo "skipped — G104-py.sh is the Python variant; active language is $PACK (use G104 for Go)"
  exit 0
fi

if [ ! -f "$PERF_BUDGET" ]; then
  echo "no perf-budget.md (skipped)"
  exit 0
fi

if [ ! -f "$BENCH_JSON" ]; then
  echo "INCOMPLETE: $BENCH_JSON missing — pytest-benchmark didn't run at T4"
  exit 2
fi

python3 - "$PERF_BUDGET" "$BENCH_JSON" <<'PY'
import json
import pathlib
import re
import sys

perf_budget_path, bench_json_path = sys.argv[1:3]

HOT_THRESHOLD = 1.10   # 10% headroom for hot-path symbols
COLD_THRESHOLD = 1.20  # 20% headroom for non-hot symbols

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

# (symbol_name, bench_id, heap_budget, hot_path)
budgets: list[tuple[str, str, int, bool]] = []
if parsed and isinstance(parsed, dict):
    for sym in parsed.get("symbols", []) or []:
        if "heap_bytes_per_call" not in sym:
            continue
        bench = sym.get("bench") or ""
        # Strip path prefix if present (perf-budget convention: "bench/bench_get" → "bench_get")
        bench_id = bench.split("/")[-1] if bench else ""
        if not bench_id:
            continue
        try:
            budget = int(sym["heap_bytes_per_call"])
        except (TypeError, ValueError):
            continue
        budgets.append((sym["name"], bench_id, budget, bool(sym.get("hot_path"))))
else:
    sym_pattern = re.compile(
        r"-\s+name:\s*(\S+)\s*\n(.*?)(?=\n  - name:|\Z)",
        re.DOTALL,
    )
    for m in sym_pattern.finditer(yaml_blocks[0]):
        name, body = m.group(1).strip(), m.group(2)
        bench_m = re.search(r"bench:\s*(\S+)", body)
        budget_m = re.search(r"heap_bytes_per_call:\s*(\d+)", body)
        hot_m = re.search(r"hot_path:\s*true", body)
        if bench_m and budget_m:
            bench_id = bench_m.group(1).split("/")[-1]
            budgets.append((name, bench_id, int(budget_m.group(1)), bool(hot_m)))

if not budgets:
    print("no symbols with heap_bytes_per_call declared in perf-budget.md (skipped)")
    sys.exit(0)

try:
    bench_data = json.loads(pathlib.Path(bench_json_path).read_text())
except (OSError, json.JSONDecodeError) as e:
    print(f"INCOMPLETE: {bench_json_path} unreadable — {e}")
    sys.exit(2)

# pytest-benchmark JSON shape:
#   {"benchmarks": [{"name": "bench_get", "extra_info": {"peak_memory_b": 192}, ...}]}
measured: dict[str, int | None] = {}
for bench in bench_data.get("benchmarks", []) or []:
    name = bench.get("name", "")
    extra = bench.get("extra_info") or {}
    peak = extra.get("peak_memory_b")
    if peak is None:
        measured[name] = None
    else:
        try:
            measured[name] = int(peak)
        except (TypeError, ValueError):
            measured[name] = None

fails: list[str] = []
incompletes: list[str] = []
passes: list[str] = []

for symbol, bench_id, budget, hot in budgets:
    if bench_id not in measured:
        incompletes.append(
            f"{symbol}: bench {bench_id} declared but not in bench-current.json — "
            f"add to pytest-benchmark suite or remove from perf-budget.md"
        )
        continue
    actual = measured[bench_id]
    if actual is None:
        incompletes.append(
            f"{symbol}: bench {bench_id} ran but has no extra_info.peak_memory_b — "
            f"pytest-benchmark needs --benchmark-storage / memory plugin enabled"
        )
        continue
    threshold_mult = HOT_THRESHOLD if hot else COLD_THRESHOLD
    threshold = int(budget * threshold_mult)
    marker = "[hot-path]" if hot else "[shared]"
    if actual > threshold:
        delta = actual - budget
        delta_pct = (actual - budget) / max(budget, 1) * 100.0
        fails.append(
            f"{symbol} {marker}: {bench_id} measured {actual} B/call > "
            f"budget {budget} × {threshold_mult:.2f} = {threshold} "
            f"(over by {delta} B / {delta_pct:+.1f}%)"
        )
    else:
        passes.append(
            f"{symbol}: {bench_id} {actual}/{budget} B/call (×{threshold_mult:.2f}={threshold} ceiling) ✓"
        )

if fails:
    print(f"FAIL: {len(fails)} symbol(s) exceed heap_bytes_per_call budget (with widened Python threshold)")
    for line in fails:
        print(f"  {line}")
    if incompletes:
        print(f"  + {len(incompletes)} INCOMPLETE")
        for line in incompletes:
            print(f"  ! {line}")
    sys.exit(1)
if incompletes:
    print(f"INCOMPLETE: {len(incompletes)} symbol(s) — bench output missing or no peak_memory_b")
    for line in incompletes:
        print(f"  {line}")
    sys.exit(2)
print(f"PASS: {len(passes)} symbol(s) within heap_bytes_per_call budget")
for line in passes:
    print(f"  {line}")
sys.exit(0)
PY
