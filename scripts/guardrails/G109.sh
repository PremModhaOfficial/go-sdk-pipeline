#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Rule 32 axis 2 — profile-no-surprise hotspot check.
# sdk-profile-auditor reads CPU/heap/block/mutex pprof output. Top-10 CPU samples
# must cover ≥0.8 of the declared hot paths in design/perf-budget.md. Any hot
# function not in the declared set is a surprise hotspot and a BLOCKER.
# Catches design-reality drift before testing phase.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
BUDGET="$RUN_DIR/design/perf-budget.md"
PROFILE="$RUN_DIR/impl/profile-top-cpu.json"
REPORT="$RUN_DIR/impl/profile-no-surprise-check.md"
mkdir -p "$(dirname "$REPORT")"

if [ ! -f "$BUDGET" ]; then
  echo "# Profile-no-surprise check (G109)"                                 >  "$REPORT"
  echo ""                                                                   >> "$REPORT"
  echo "Status: PASS — design/perf-budget.md absent (no hot-path decl)."    >> "$REPORT"
  echo "PASS G109: no perf-budget.md"
  exit 0
fi

python3 - "$BUDGET" "$PROFILE" "$REPORT" <<'PY'
import json, pathlib, re, sys
budget_p, profile_p, report_p = sys.argv[1:4]

text = open(budget_p).read()

# Hot paths: look for an explicit list
#   hot_paths:
#     - fnA
#     - fnB
# or a `## Hot Paths` markdown section with bullet lines.
declared = set()
m = re.search(r'(?ms)hot_paths:\s*\n((?:\s*-\s*[^\n]+\n)+)', text)
if m:
    for line in m.group(1).splitlines():
        item = line.strip().lstrip("-").strip().strip('`"')
        if item:
            declared.add(item)
m = re.search(r'(?ms)^#+\s*Hot\s*Paths?\s*$(.*?)(?=^#+\s|\Z)', text)
if m:
    for line in m.group(1).splitlines():
        item = line.strip().lstrip("-").strip().strip('`"')
        if item and not item.startswith("#"):
            declared.add(item)

if not declared:
    pathlib.Path(report_p).write_text(
        "# Profile-no-surprise check (G109)\n\nStatus: PASS — no hot paths declared in perf-budget.md.\n"
    )
    print("PASS G109: no declared hot paths")
    sys.exit(0)

if not pathlib.Path(profile_p).is_file():
    pathlib.Path(report_p).write_text(
        f"# Profile-no-surprise check (G109)\n\nStatus: FAIL — hot paths declared "
        f"({len(declared)}) but {profile_p} missing.\n\nExpected JSON: "
        f"`[{{\"fn\": \"pkg.Func\", \"flat_pct\": <float>}}, ...]` — top 10 CPU samples.\n"
    )
    print(f"FAIL G109: {profile_p} missing")
    sys.exit(1)

profile = json.loads(open(profile_p).read())
if isinstance(profile, dict) and "top" in profile:
    profile = profile["top"]
if not isinstance(profile, list) or not profile:
    pathlib.Path(report_p).write_text(
        "# Profile-no-surprise check (G109)\n\nStatus: FAIL — profile-top-cpu.json parseable but empty.\n"
    )
    print("FAIL G109: empty profile")
    sys.exit(1)

top10 = profile[:10]

def matches_declared(fn: str) -> bool:
    leaf = fn.rsplit(".", 1)[-1]
    for d in declared:
        if d == fn or d == leaf or fn.endswith("." + d) or leaf == d.split(".")[-1]:
            return True
    return False

declared_coverage = sum(float(e.get("flat_pct", 0)) for e in top10 if matches_declared(e.get("fn", "")))
total_pct         = sum(float(e.get("flat_pct", 0)) for e in top10) or 1.0
coverage_ratio    = declared_coverage / total_pct

surprises = [e for e in top10 if not matches_declared(e.get("fn", ""))]

# Surprise cutoff: any function in top-3 that is not declared is a surprise regardless.
hard_surprises = [e for e in top10[:3] if not matches_declared(e.get("fn", ""))]

lines = ["# Profile-no-surprise check (G109)", "",
         f"Declared hot paths: {sorted(declared)}",
         f"Top-10 total flat% = {total_pct:.2f}",
         f"Declared coverage = {declared_coverage:.2f} ({coverage_ratio:.2%} of top-10)",
         ""]

fail = False
if coverage_ratio < 0.80:
    lines.append(f"Status: FAIL — declared coverage {coverage_ratio:.2%} below 0.80 threshold")
    fail = True
elif hard_surprises:
    lines.append(f"Status: FAIL — top-3 contains non-declared hot function(s)")
    fail = True
else:
    lines.append("Status: PASS")
lines.append("")
lines.append("## Top 10 (leaf fn · flat%)")
for e in top10:
    mark = "✓" if matches_declared(e.get("fn", "")) else "!"
    lines.append(f"- [{mark}] {e.get('fn')}  {e.get('flat_pct')}%")
pathlib.Path(report_p).write_text("\n".join(lines))

if fail:
    print(f"FAIL G109: declared coverage {coverage_ratio:.2%} or top-3 surprise")
    for e in hard_surprises:
        print(f"  SURPRISE top-3: {e.get('fn')} ({e.get('flat_pct')}%)")
    sys.exit(1)
print(f"PASS G109: declared coverage {coverage_ratio:.2%} ≥ 0.80, no top-3 surprise")
sys.exit(0)
PY
