#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Rule 32 axis 4 — complexity scaling sweep.
# sdk-complexity-devil runs each declared hot-path symbol at N∈{10,100,1k,10k}
# and records a curve-fit exponent. Compares to the declared big-O from
# design/perf-budget.md. Catches accidental quadratic paths that pass wall-clock
# gates at microbench sizes.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
BUDGET="$RUN_DIR/design/perf-budget.md"
RESULTS="$RUN_DIR/testing/complexity-scan.json"
REPORT="$RUN_DIR/testing/complexity-scan-check.md"
mkdir -p "$(dirname "$REPORT")"

if [ ! -f "$BUDGET" ]; then
  echo "# Complexity scan check (G107)"                                   >  "$REPORT"
  echo ""                                                                 >> "$REPORT"
  echo "Status: PASS — design/perf-budget.md absent (no complexity decl)." >> "$REPORT"
  echo "PASS G107: no perf-budget.md"
  exit 0
fi

python3 - "$BUDGET" "$RESULTS" "$REPORT" <<'PY'
import json, pathlib, re, sys, math
budget_p, results_p, report_p = sys.argv[1:4]

# Parse declared complexity per symbol. Accept YAML-ish blocks or table columns.
decl = {}
text = open(budget_p).read()
block_re = re.compile(
    r'(?ms)^\s*-\s*symbol:\s*(?P<sym>[A-Za-z_][\w\./:-]*)\s*\n'
    r'(?:(?!^\s*-\s*symbol:).)*?'
    r'\s*(?:complexity|big_o|bigO):\s*(?P<bigo>[^\n]+)')
for m in block_re.finditer(text):
    decl[m.group("sym")] = m.group("bigo").strip().strip('"`\'')

if not decl:
    pathlib.Path(report_p).write_text(
        "# Complexity scan check (G107)\n\nStatus: PASS — perf-budget.md has no declared complexity entries.\n"
    )
    print("PASS G107: no declared complexity entries")
    sys.exit(0)

# Classify an exponent hint from the declared big-O. We only need a ceiling.
def declared_exponent_cap(bigo: str) -> float:
    b = bigo.lower()
    if re.search(r'\bo\(\s*1\s*\)', b):                       return 0.10
    if re.search(r'\bo\(\s*log', b):                          return 0.25
    if re.search(r'\bo\(\s*n\s*log\s*n\s*\)', b):             return 1.25
    if re.search(r'\bo\(\s*(n|m)\s*\)', b):                   return 1.10
    if re.search(r'\bo\(\s*log\s*n\s*\+\s*m\s*\)', b):        return 1.25
    if re.search(r'\bo\(\s*n\^?\s*2\s*\)', b):                return 2.10
    return 1.25  # conservative default

caps = {s: declared_exponent_cap(b) for s, b in decl.items()}

if not pathlib.Path(results_p).is_file():
    pathlib.Path(report_p).write_text(
        f"# Complexity scan check (G107)\n\nStatus: FAIL — {len(decl)} symbol(s) declared but "
        f"{results_p} missing.\n\nExpected JSON shape per symbol: `{{\"exponent\": <float>, \"r2\": <float>, "
        f"\"samples\": [{{\"n\":..., \"ns\":...}}, ...]}}`.\n"
    )
    print(f"FAIL G107: {results_p} missing")
    sys.exit(1)

data = json.loads(open(results_p).read())
if isinstance(data, list):
    data = {r.get("symbol"): r for r in data if isinstance(r, dict) and r.get("symbol")}

bad, ok, miss = [], [], []
for sym, bigo in decl.items():
    cap = caps[sym]
    rec = data.get(sym)
    if not rec:
        miss.append(sym); continue
    exp = rec.get("exponent")
    if exp is None and "samples" in rec and len(rec["samples"]) >= 2:
        # derive exponent via log-log least squares
        xs = [math.log(s["n"])  for s in rec["samples"] if s.get("n", 0) > 0]
        ys = [math.log(s["ns"]) for s in rec["samples"] if s.get("ns", 0) > 0]
        n  = min(len(xs), len(ys))
        if n >= 2:
            xs, ys = xs[:n], ys[:n]
            mx, my = sum(xs)/n, sum(ys)/n
            num = sum((x-mx)*(y-my) for x, y in zip(xs, ys))
            den = sum((x-mx)**2 for x in xs)
            exp = num/den if den else None
    if exp is None:
        bad.append(f"{sym}: no exponent parseable (declared {bigo})")
        continue
    if exp > cap:
        bad.append(f"{sym}: exponent {exp:.2f} > cap {cap:.2f} for {bigo}")
    else:
        ok.append(f"{sym}: exponent {exp:.2f} ≤ cap {cap:.2f} ({bigo})")

lines = ["# Complexity scan check (G107)", "",
         f"Status: {'PASS' if not bad and not miss else 'FAIL'}",
         f"Declared: {len(decl)} · OK: {len(ok)} · Violations: {len(bad)} · Missing: {len(miss)}", ""]
if ok:   lines.append("## OK");          [lines.append(f"- {x}") for x in ok];   lines.append("")
if bad:  lines.append("## Violations");  [lines.append(f"- {x}") for x in bad];  lines.append("")
if miss: lines.append("## No measurement"); [lines.append(f"- {x}") for x in miss]; lines.append("")
pathlib.Path(report_p).write_text("\n".join(lines))

if bad or miss:
    print(f"FAIL G107: {len(bad)} violation(s), {len(miss)} missing measurement(s)")
    for x in bad + [f"MISSING: {m}" for m in miss]:
        print(f"  - {x}")
    sys.exit(1)
print(f"PASS G107: {len(ok)} complexity curve(s) within cap")
sys.exit(0)
PY
