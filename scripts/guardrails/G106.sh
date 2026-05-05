#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Rule 32 axis 6 — soak drift detector.
# sdk-drift-detector curve-fits declared soak signals (e.g. RSS, goroutine count,
# pool-checkout latency p99) over the soak window and fails on a statistically
# significant positive trend.
# Consumes testing/soak-drift-report.json written by sdk-drift-detector.
# No-ops cleanly when no soak symbol is declared.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
BUDGET="$RUN_DIR/design/perf-budget.md"
REPORT_IN="$RUN_DIR/testing/soak-drift-report.json"
REPORT="$RUN_DIR/testing/soak-drift-check.md"
mkdir -p "$(dirname "$REPORT")"

# No perf-budget → nothing declared → no-op.
if [ ! -f "$BUDGET" ]; then
  echo "# Soak drift check (G106)"                                            >  "$REPORT"
  echo ""                                                                     >> "$REPORT"
  echo "Status: PASS (no-op) — design/perf-budget.md absent (no soak decl)."  >> "$REPORT"
  echo "PASS G106: no perf-budget.md"
  exit 0
fi

python3 - "$BUDGET" "$REPORT_IN" "$REPORT" <<'PY'
import json, pathlib, re, sys
budget_p, in_p, report_p = sys.argv[1:4]

text = open(budget_p).read()
soak_symbols = set(re.findall(
    r'(?ms)^\s*-\s*symbol:\s*([A-Za-z_][\w\./:-]*)\s*\n(?:(?!^\s*-\s*symbol:).)*?\s*soak:\s*true',
    text))

if not soak_symbols:
    pathlib.Path(report_p).write_text(
        "# Soak drift check (G106)\n\nStatus: PASS (no-op) — no soak-enabled symbols declared.\n"
    )
    print("PASS G106: no soak-enabled symbols declared (no-op)")
    sys.exit(0)

if not pathlib.Path(in_p).is_file():
    pathlib.Path(report_p).write_text(
        f"# Soak drift check (G106)\n\nStatus: FAIL — {len(soak_symbols)} soak symbol(s) declared but "
        f"{in_p} missing.\n\nExpected JSON shape: "
        f"`{{\"<symbol>\": {{\"signal\": \"rss|goroutines|p99\", \"slope\": <float>, \"p_value\": <float>, \"verdict\": \"PASS|FAIL\"}} }}`.\n"
    )
    print(f"FAIL G106: {in_p} missing; {len(soak_symbols)} symbol(s) un-verified")
    sys.exit(1)

data = json.loads(open(in_p).read())
# Accept dict-by-symbol or list.
if isinstance(data, list):
    data = {r.get("symbol"): r for r in data if isinstance(r, dict) and r.get("symbol")}

bad, ok, miss = [], [], []
for sym in sorted(soak_symbols):
    rec = data.get(sym)
    if not rec:
        miss.append(sym)
        continue
    verdict = rec.get("verdict", "").upper()
    if verdict == "PASS":
        ok.append(f"{sym}: slope={rec.get('slope','?')} p={rec.get('p_value','?')}")
    else:
        bad.append(f"{sym}: verdict={verdict or '<none>'} slope={rec.get('slope','?')} p={rec.get('p_value','?')}")

lines = ["# Soak drift check (G106)", "",
         f"Status: {'PASS' if not bad and not miss else 'FAIL'}",
         f"Symbols: {len(soak_symbols)} · PASS: {len(ok)} · FAIL: {len(bad)} · missing: {len(miss)}", ""]
if ok:   lines.append("## Drift PASS"); [lines.append(f"- {x}") for x in ok];   lines.append("")
if bad:  lines.append("## Drift FAIL"); [lines.append(f"- {x}") for x in bad];  lines.append("")
if miss: lines.append("## No report");  [lines.append(f"- {x}") for x in miss]; lines.append("")
pathlib.Path(report_p).write_text("\n".join(lines))

if bad or miss:
    print(f"FAIL G106: {len(bad)} drift failure(s), {len(miss)} missing")
    for x in bad + [f"MISSING: {m}" for m in miss]:
        print(f"  - {x}")
    sys.exit(1)
print(f"PASS G106: {len(ok)} soak drift check(s) PASS")
sys.exit(0)
PY
