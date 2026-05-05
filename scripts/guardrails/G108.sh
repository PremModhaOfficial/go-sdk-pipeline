#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Rule 32 axis 5 — oracle margin vs reference impl.
# Measured p50 must stay within oracle.margin_multiplier × reference_impl_ns_per_op
# declared in design/perf-budget.md. NOT waivable via --accept-perf-regression;
# oracle-waiver requires an H8 decision + written margin update.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
BUDGET="$RUN_DIR/design/perf-budget.md"
RESULTS="$RUN_DIR/testing/oracle-results.json"
REPORT="$RUN_DIR/testing/oracle-margin-check.md"
mkdir -p "$(dirname "$REPORT")"

if [ ! -f "$BUDGET" ]; then
  echo "# Oracle margin check (G108)"                                   >  "$REPORT"
  echo ""                                                               >> "$REPORT"
  echo "Status: PASS — design/perf-budget.md absent (no oracle decl)."  >> "$REPORT"
  echo "PASS G108: no perf-budget.md"
  exit 0
fi

python3 - "$BUDGET" "$RESULTS" "$REPORT" <<'PY'
import json, pathlib, re, sys
budget_p, results_p, report_p = sys.argv[1:4]

text = open(budget_p).read()
# Shape expected per symbol:
#   - symbol: GetJSON
#     oracle:
#       reference: Get
#       margin_multiplier: 1.5
oracles = {}
block_re = re.compile(
    r'(?ms)^\s*-\s*symbol:\s*(?P<sym>[A-Za-z_][\w\./:-]*)\s*\n'
    r'(?:(?!^\s*-\s*symbol:).)*?'
    r'\s*oracle:\s*\n'
    r'(?:(?!^\s*-\s*symbol:).)*?\s*reference:\s*(?P<ref>[A-Za-z_][\w\./:-]*)\s*\n'
    r'(?:(?!^\s*-\s*symbol:).)*?\s*margin_multiplier:\s*(?P<mm>[\d.]+)')
for m in block_re.finditer(text):
    oracles[m.group("sym")] = {"reference": m.group("ref"), "margin": float(m.group("mm"))}

# Also accept an inline-table note: "GetJSON <= 1.5x Get"
inline_re = re.compile(r'\b([A-Za-z_][\w\./:-]*)\s*(?:<=|≤)\s*([\d.]+)\s*(?:x|×)\s*([A-Za-z_][\w\./:-]*)')
for m in inline_re.finditer(text):
    sym, mm, ref = m.group(1), float(m.group(2)), m.group(3)
    oracles.setdefault(sym, {"reference": ref, "margin": mm})

if not oracles:
    pathlib.Path(report_p).write_text(
        "# Oracle margin check (G108)\n\nStatus: PASS — no oracle entries declared in perf-budget.md.\n"
    )
    print("PASS G108: no oracle entries declared")
    sys.exit(0)

if not pathlib.Path(results_p).is_file():
    pathlib.Path(report_p).write_text(
        f"# Oracle margin check (G108)\n\nStatus: FAIL — {len(oracles)} oracle(s) declared but "
        f"{results_p} missing.\n\nExpected JSON: per symbol `{{\"measured_ns\": <float>, \"reference_ns\": <float>}}` "
        f"keyed by symbol OR list with `symbol`, `measured_ns`, `reference_ns`.\n"
    )
    print(f"FAIL G108: {results_p} missing")
    sys.exit(1)

data = json.loads(open(results_p).read())
if isinstance(data, list):
    data = {r.get("symbol"): r for r in data if isinstance(r, dict) and r.get("symbol")}

bad, ok, miss = [], [], []
for sym, o in oracles.items():
    rec = data.get(sym)
    if not rec:
        miss.append(sym); continue
    m_ns, r_ns, mm = rec.get("measured_ns"), rec.get("reference_ns"), o["margin"]
    if m_ns is None or r_ns is None or r_ns <= 0:
        bad.append(f"{sym}: missing measured_ns / reference_ns in record"); continue
    ratio = m_ns / r_ns
    if ratio > mm:
        bad.append(f"{sym}: measured/reference = {ratio:.2f}× > margin {mm}× (ref `{o['reference']}`)")
    else:
        ok.append(f"{sym}: {ratio:.2f}× ≤ {mm}× (ref `{o['reference']}`)")

lines = ["# Oracle margin check (G108)", "",
         f"Status: {'PASS' if not bad and not miss else 'FAIL'}",
         f"Oracles: {len(oracles)} · OK: {len(ok)} · Violations: {len(bad)} · Missing: {len(miss)}", ""]
if ok:   lines.append("## OK");          [lines.append(f"- {x}") for x in ok];   lines.append("")
if bad:  lines.append("## Violations");  [lines.append(f"- {x}") for x in bad];  lines.append("")
if miss: lines.append("## Missing results"); [lines.append(f"- {x}") for x in miss]; lines.append("")
pathlib.Path(report_p).write_text("\n".join(lines))

if bad or miss:
    print(f"FAIL G108: {len(bad)} violation(s), {len(miss)} missing")
    for x in bad + [f"MISSING: {m}" for m in miss]:
        print(f"  - {x}")
    sys.exit(1)
print(f"PASS G108: {len(ok)} oracle margin(s) met")
sys.exit(0)
PY
