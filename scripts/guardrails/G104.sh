#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Rule 32 axis 3 — per-pack alloc-metric budget check.
#
# Reads the active pack's `alloc_metric.name` from scripts/perf/perf-config.yaml
# (Go default: `allocs_per_op`; Python: `heap_bytes_per_call`; Rust:
# `instructions_per_call`). For each symbol with a declared budget under that
# metric in design/perf-budget.md, compare against measured values in
# impl/bench-allocs.json. Pre-0.3.0 always assumed `allocs_per_op`; 0.3.0+
# parameterizes via the active pack (PACK env var, default `go`).
#
# Runs BEFORE T5 so alloc overruns never reach testing phase.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
BUDGET="$RUN_DIR/design/perf-budget.md"
MEASURED="$RUN_DIR/impl/bench-allocs.json"
REPORT="$RUN_DIR/impl/alloc-budget-check.md"
mkdir -p "$(dirname "$REPORT")"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PERF_CONFIG="$REPO_ROOT/scripts/perf/perf-config.yaml"
PACK="${PACK:-go}"

# Resolve metric name from perf-config (no PyYAML required — minimal nested-key parser)
METRIC_NAME=$(python3 - "$PERF_CONFIG" "$PACK" <<'PY' || echo allocs_per_op
import sys, re
cfg_path, pack = sys.argv[1:3]
try:
    txt = open(cfg_path).read()
except Exception:
    print("allocs_per_op"); sys.exit(0)
# Locate the pack block
m = re.search(rf'^{re.escape(pack)}:\s*\n((?:[ \t].+\n?)+)', txt, re.MULTILINE)
if not m:
    print("allocs_per_op"); sys.exit(0)
block = m.group(1)
m2 = re.search(r'^\s+alloc_metric:\s*\n((?:\s{4,}.+\n?)+)', block, re.MULTILINE)
if not m2:
    print("allocs_per_op"); sys.exit(0)
sub = m2.group(1)
m3 = re.search(r'^\s*name:\s*([^\s#]+)', sub, re.MULTILINE)
print(m3.group(1) if m3 else "allocs_per_op")
PY
)

if [ ! -f "$BUDGET" ]; then
  echo "# Alloc budget check (G104, pack=$PACK, metric=$METRIC_NAME)" >  "$REPORT"
  echo ""                                                              >> "$REPORT"
  echo "Status: PASS — design/perf-budget.md absent (no budgets declared)." >> "$REPORT"
  echo "PASS G104: no perf-budget.md declared (pack=$PACK)"
  exit 0
fi

python3 - "$BUDGET" "$MEASURED" "$REPORT" "$METRIC_NAME" "$PACK" <<'PY'
import json, pathlib, re, sys
budget_p, measured_p, report_p, metric_name, pack = sys.argv[1:6]

budget = {}
text = open(budget_p).read()

# Table form: any 2-column row where col2 is an integer (works for any metric name).
table_re = re.compile(r'^\|\s*([A-Za-z_][\w\./:-]*)\s*\|\s*(\d+)\s*\|', re.MULTILINE)
for m in table_re.finditer(text):
    sym, val = m.group(1), int(m.group(2))
    if sym.lower() in ("symbol", "sym", "name"):
        continue
    budget[sym] = val

# YAML-ish block form, parameterized by the configured metric name:
inline_re = re.compile(
    rf'(?m)^\s*-\s*symbol:\s*([A-Za-z_][\w\./:-]*)\s*\n(?:.*\n)*?\s*{re.escape(metric_name)}:\s*(\d+)'
)
for m in inline_re.finditer(text):
    budget[m.group(1)] = int(m.group(2))

# Key-value form on same line, parameterized:
kv_re = re.compile(rf'(?m)^\s*([A-Za-z_][\w\./:-]*)\s*:\s*{re.escape(metric_name)}\s*=\s*(\d+)')
for m in kv_re.finditer(text):
    budget[m.group(1)] = int(m.group(2))

if not budget:
    pathlib.Path(report_p).write_text(
        f"# Alloc budget check (G104, pack={pack}, metric={metric_name})\n\n"
        f"Status: PASS — perf-budget.md present but no `{metric_name}` entries parsed.\n"
        f"(Recognized formats: markdown table with `{metric_name}` column, or YAML-ish "
        f"`- symbol:` / `{metric_name}:` blocks.)\n"
    )
    print(f"PASS G104: no {metric_name} budgets parseable from perf-budget.md")
    sys.exit(0)

if not pathlib.Path(measured_p).is_file():
    pathlib.Path(report_p).write_text(
        f"# Alloc budget check (G104, pack={pack}, metric={metric_name})\n\n"
        f"Status: FAIL — {len(budget)} symbol(s) have declared budgets but {measured_p} is missing.\n\n"
        f"Expected JSON: `{{\"<symbol>\": <{metric_name}_measured>, ...}}` "
        f"or `[{{\"symbol\": ..., \"{metric_name}\": ...}}, ...]`.\n"
    )
    print(f"FAIL G104: {measured_p} missing; {len(budget)} declared symbol(s) cannot be verified")
    sys.exit(1)

measured = {}
try:
    data = json.loads(open(measured_p).read())
    if isinstance(data, dict):
        measured = {k: int(v) for k, v in data.items() if isinstance(v, (int, float))}
    elif isinstance(data, list):
        for e in data:
            if isinstance(e, dict) and "symbol" in e:
                # accept either the configured metric name or "allocs_per_op" for backward compat
                if metric_name in e:
                    measured[e["symbol"]] = int(e[metric_name])
                elif "allocs_per_op" in e:
                    measured[e["symbol"]] = int(e["allocs_per_op"])
except Exception as exc:
    pathlib.Path(report_p).write_text(
        f"# Alloc budget check (G104, pack={pack}, metric={metric_name})\n\n"
        f"Status: FAIL — could not parse {measured_p}: {exc}\n"
    )
    print(f"FAIL G104: cannot parse {measured_p}: {exc}")
    sys.exit(1)

overruns, ok, miss = [], [], []
for sym, cap in budget.items():
    if sym not in measured:
        miss.append(sym); continue
    if measured[sym] > cap:
        overruns.append(f"{sym}: measured {measured[sym]} > budget {cap}")
    else:
        ok.append(f"{sym}: {measured[sym]} / {cap}")

lines = [f"# Alloc budget check (G104, pack={pack}, metric={metric_name})", ""]
status = "PASS" if not overruns and not miss else "FAIL"
lines.append(f"Status: {status}")
lines.append(f"Declared budgets: {len(budget)} · OK: {len(ok)} · Overrun: {len(overruns)} · Missing measurement: {len(miss)}")
lines.append("")
if ok:        lines.append("## OK");                  [lines.append(f"- {x}") for x in ok];        lines.append("")
if overruns:  lines.append("## Overruns");            [lines.append(f"- {x}") for x in overruns];  lines.append("")
if miss:      lines.append("## Missing measurements"); [lines.append(f"- {x}") for x in miss];     lines.append("")
pathlib.Path(report_p).write_text("\n".join(lines))

if overruns or miss:
    print(f"FAIL G104: {len(overruns)} overrun(s), {len(miss)} missing measurement(s) (pack={pack}, metric={metric_name})")
    for x in overruns + [f"MISSING: {m}" for m in miss]:
        print(f"  - {x}")
    sys.exit(1)
print(f"PASS G104: {len(ok)} symbol(s) within {metric_name} budget (pack={pack})")
sys.exit(0)
PY
