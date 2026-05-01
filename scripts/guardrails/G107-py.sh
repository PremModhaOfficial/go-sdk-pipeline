#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Python complexity-mismatch gate (CLAUDE.md rule 32 axis 4, Python realization).
#
# For every symbol with declared `complexity.time` in design/perf-budget.md,
# parses pytest-benchmark JSON in runs/<id>/testing/bench-scaling.json
# (produced by sdk-complexity-devil-python with @pytest.mark.parametrize over
# N ∈ {10, 100, 1k, 10k}). Log-log curve-fits measured `stats.mean` vs N;
# compares to declared big-O. BLOCKER on mismatch.
#
# Tolerance windows (same math as G107.sh — pure log-log slope; language-agnostic):
#   O(1), O(log n)   → slope ≈ 0   (~[-0.3, 0.5/0.6])
#   O(n)             → slope ≈ 1   ([0.6, 1.4])
#   O(n log n)       → slope ≈ 1   ([0.7, 1.5])
#   O(n²)            → slope ≈ 2   ([1.5, 2.5])
#   O(n³)            → slope ≈ 3   ([2.5, 3.5])
#
# Verdicts (per CLAUDE.md rule 33):
#   PASS         — every symbol's measured slope within tolerance
#   FAIL         — declared O(n) but measured O(n²) (or worse)
#   INCOMPLETE   — fewer than 3 N-points OR scaling JSON missing
#   skipped      — no perf-budget, no symbols with complexity.time
#
# pytest-benchmark JSON shape:
#   {"benchmarks": [
#       {"name": "bench_scan", "params": {"n": 10}, "stats": {"mean": 0.000245, ...}},
#       {"name": "bench_scan", "params": {"n": 100}, "stats": {"mean": 0.000820, ...}},
#       ...
#   ]}
#
# Exit codes:
#   0 — PASS or skipped
#   1 — FAIL
#   2 — INCOMPLETE / INFRA missing
#
# Usage: bash scripts/guardrails/G107-py.sh <run-dir> [<target-dir>]
set -uo pipefail
RUN_DIR="${1:?usage: G107-py.sh <run-dir> [<target-dir>]}"
TARGET="${2:-}"
PIPELINE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "INFRA: python3 is required" >&2
  exit 2
fi

PERF_BUDGET="$RUN_DIR/design/perf-budget.md"
SCALING="$RUN_DIR/testing/bench-scaling.json"

APJ="$RUN_DIR/context/active-packages.json"
if [ -f "$APJ" ] && command -v jq >/dev/null 2>&1; then
  PACK="$(jq -r '.target_language // "go"' "$APJ")"
else
  PACK="python"
fi
if [ "$PACK" != "python" ]; then
  echo "skipped — G107-py.sh is the Python variant; active language is $PACK"
  exit 0
fi

if [ ! -f "$PERF_BUDGET" ]; then
  echo "no perf-budget.md (skipped)"
  exit 0
fi

if [ ! -f "$SCALING" ]; then
  echo "INCOMPLETE: $SCALING missing — sdk-complexity-devil-python didn't produce parametrized scaling sweep"
  exit 2
fi

python3 - "$PERF_BUDGET" "$SCALING" <<'PY'
import json
import math
import pathlib
import re
import sys

perf_budget_path, scaling_path = sys.argv[1:3]

BIG_O_TOLERANCE: dict[str, tuple[float, float]] = {
    "O(1)":         (-0.3, 0.5),
    "O(log n)":     (-0.3, 0.6),
    "O(n)":         (0.6, 1.4),
    "O(n log n)":   (0.7, 1.5),
    "O(n^2)":       (1.5, 2.5),
    "O(n²)":        (1.5, 2.5),
    "O(n^3)":       (2.5, 3.5),
    "O(n³)":        (2.5, 3.5),
}


def declared_to_window(declared: str) -> tuple[float, float] | None:
    norm = declared.strip().replace(" ", "").lower()
    norm = norm.replace("n^2", "n²").replace("n^3", "n³").replace("nlogn", "nlog(n)")
    aliases = {
        "o(1)": "O(1)",
        "o(logn)": "O(log n)",
        "o(log(n))": "O(log n)",
        "o(n)": "O(n)",
        "o(nlog(n))": "O(n log n)",
        "o(nlogn)": "O(n log n)",
        "o(n²)": "O(n²)",
        "o(n³)": "O(n³)",
    }
    canonical = aliases.get(norm)
    if canonical is None:
        canonical = aliases.get(norm.replace(" ", ""))
    if canonical is None:
        return None
    return BIG_O_TOLERANCE.get(canonical)


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

specs: list[tuple[str, str, str]] = []  # (symbol, bench_id, declared)
if parsed and isinstance(parsed, dict):
    for sym in parsed.get("symbols", []) or []:
        complexity = sym.get("complexity") or {}
        big_o = complexity.get("time") or ""
        bench = (sym.get("bench") or "").split("/")[-1]
        if big_o and bench:
            specs.append((sym["name"], bench, big_o))
else:
    sym_pattern = re.compile(
        r"-\s+name:\s*(\S+)\s*\n(.*?)(?=\n  - name:|\Z)",
        re.DOTALL,
    )
    for m in sym_pattern.finditer(yaml_blocks[0]):
        name, body = m.group(1).strip(), m.group(2)
        bench_m = re.search(r"bench:\s*(\S+)", body)
        big_o_m = re.search(r"complexity:\s*\n\s*time:\s*\"?([^\"\n]+)\"?", body)
        if bench_m and big_o_m:
            specs.append((name, bench_m.group(1).split("/")[-1], big_o_m.group(1).strip()))

if not specs:
    print("no symbols with complexity.time declared in perf-budget.md (skipped)")
    sys.exit(0)

try:
    bench_data = json.loads(pathlib.Path(scaling_path).read_text())
except (OSError, json.JSONDecodeError) as e:
    print(f"INCOMPLETE: {scaling_path} unreadable — {e}")
    sys.exit(2)

# Build map: bench_id → list of (n, mean_seconds)
points: dict[str, list[tuple[int, float]]] = {}
for bench in bench_data.get("benchmarks", []) or []:
    name = bench.get("name", "")
    params = bench.get("params") or {}
    n = params.get("n")
    stats = bench.get("stats") or {}
    mean = stats.get("mean")
    if n is None or mean is None:
        continue
    try:
        n_int = int(n)
        mean_f = float(mean)
    except (TypeError, ValueError):
        continue
    points.setdefault(name, []).append((n_int, mean_f))


def log_log_slope(pts: list[tuple[int, float]]) -> float | None:
    if len(pts) < 3:
        return None
    xs = [math.log(n) for n, _ in pts]
    ys = [math.log(t) for _, t in pts if t > 0]
    if len(ys) != len(xs):
        return None
    mean_x = sum(xs) / len(xs)
    mean_y = sum(ys) / len(ys)
    sum_xy = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    sum_xx = sum((x - mean_x) ** 2 for x in xs)
    if sum_xx == 0:
        return None
    return sum_xy / sum_xx


fails: list[str] = []
incompletes: list[str] = []
passes: list[str] = []

for symbol, bench, declared in specs:
    window = declared_to_window(declared)
    if window is None:
        incompletes.append(
            f"{symbol}: declared complexity '{declared}' not recognized "
            f"(supported: O(1), O(log n), O(n), O(n log n), O(n²), O(n³))"
        )
        continue
    pts = sorted(points.get(bench, []))
    if len(pts) < 3:
        incompletes.append(
            f"{symbol}: bench {bench} has {len(pts)} N-points in scaling JSON "
            f"(need >=3). Add @pytest.mark.parametrize values."
        )
        continue
    slope = log_log_slope(pts)
    if slope is None:
        incompletes.append(f"{symbol}: bench {bench} log-log fit failed (degenerate data)")
        continue
    lo, hi = window
    sample_str = ", ".join(f"N={n}:{t*1e6:.0f}µs" for n, t in pts)
    if slope > hi:
        fails.append(
            f"{symbol}: declared {declared} but measured slope {slope:+.2f} > expected upper {hi:.2f} "
            f"(samples: {sample_str})"
        )
    elif slope < lo:
        passes.append(
            f"{symbol}: declared {declared}, measured slope {slope:+.2f} ≤ expected lower {lo:.2f} "
            f"(faster than declared — consider tightening)"
        )
    else:
        passes.append(
            f"{symbol}: declared {declared} ✓ measured slope {slope:+.2f} ∈ [{lo:.2f}, {hi:.2f}]"
        )

if fails:
    print(f"FAIL: {len(fails)} symbol(s) exceed declared big-O")
    for line in fails:
        print(f"  {line}")
    if incompletes:
        print(f"  + {len(incompletes)} INCOMPLETE")
        for line in incompletes:
            print(f"  ! {line}")
    sys.exit(1)
if incompletes:
    print(f"INCOMPLETE: {len(incompletes)} symbol(s)")
    for line in incompletes:
        print(f"  {line}")
    sys.exit(2)
print(f"PASS: {len(passes)} symbol(s) within declared big-O")
for line in passes:
    print(f"  {line}")
sys.exit(0)
PY
