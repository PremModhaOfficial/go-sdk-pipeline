#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Rule 32 axis 6 + rule 33 verdict taxonomy — soak MMD enforcement.
# Any soak verdict marked PASS must satisfy
#   actual_duration_s >= mmd_seconds  (from design/perf-budget.md).
# Shorter runs are INCOMPLETE, not PASS. Prevents silent timeout-to-PASS promotion.
# No-ops cleanly when no soak-enabled symbol is declared.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
BUDGET="$RUN_DIR/design/perf-budget.md"
RESULTS="$RUN_DIR/testing/soak-results.json"
REPORT="$RUN_DIR/testing/soak-mmd-check.md"
mkdir -p "$(dirname "$REPORT")"

if [ ! -f "$BUDGET" ]; then
  echo "# Soak MMD check (G105)"                                      >  "$REPORT"
  echo ""                                                             >> "$REPORT"
  echo "Status: PASS (no-op) — design/perf-budget.md absent."         >> "$REPORT"
  echo "PASS G105: no perf-budget.md (no soak symbols declared)"
  exit 0
fi

python3 - "$BUDGET" "$RESULTS" "$REPORT" <<'PY'
import json, pathlib, re, sys
budget_p, results_p, report_p = sys.argv[1:4]

# Parse soak-enabled symbols: look for a block of
#   - symbol: X
#     soak: true
#     mmd_seconds: N
# or a markdown table | Symbol | soak | mmd_seconds | ...
soak_mmd = {}
text = open(budget_p).read()
block_re = re.compile(
    r'(?ms)^\s*-\s*symbol:\s*(?P<sym>[A-Za-z_][\w\./:-]*)\s*\n'
    r'(?:(?!^\s*-\s*symbol:).)*?'          # body up to next symbol/start
    r'\s*soak:\s*true\s*\n'
    r'(?:(?!^\s*-\s*symbol:).)*?'
    r'\s*mmd_seconds:\s*(?P<mmd>\d+)'
)
for m in block_re.finditer(text):
    soak_mmd[m.group("sym")] = int(m.group("mmd"))

# Markdown table fallback (requires columns named Symbol, soak, mmd_seconds).
for line in text.splitlines():
    if not line.startswith("|"):
        continue
    parts = [c.strip() for c in line.strip("|").split("|")]
    if len(parts) >= 3 and parts[1].lower() in ("true", "yes"):
        sym = parts[0]
        try:
            soak_mmd.setdefault(sym, int(parts[2]))
        except ValueError:
            pass

if not soak_mmd:
    pathlib.Path(report_p).write_text(
        "# Soak MMD check (G105)\n\nStatus: PASS (no-op) — no soak-enabled symbols declared.\n"
    )
    print("PASS G105: no soak-enabled symbols declared (no-op)")
    sys.exit(0)

if not pathlib.Path(results_p).is_file():
    pathlib.Path(report_p).write_text(
        f"# Soak MMD check (G105)\n\nStatus: FAIL — {len(soak_mmd)} soak symbol(s) declared but {results_p} missing.\n"
    )
    print(f"FAIL G105: {results_p} missing; {len(soak_mmd)} soak symbol(s) un-verified")
    sys.exit(1)

results = json.loads(open(results_p).read())
# Accept either a dict keyed by symbol or a list of records.
records = {}
if isinstance(results, dict):
    records = {k: v for k, v in results.items() if isinstance(v, dict)}
elif isinstance(results, list):
    for r in results:
        if isinstance(r, dict) and "symbol" in r:
            records[r["symbol"]] = r

bad = []
ok  = []
for sym, mmd in soak_mmd.items():
    rec = records.get(sym)
    if not rec:
        bad.append(f"{sym}: no result record")
        continue
    verdict = rec.get("verdict", "").upper()
    actual  = rec.get("actual_duration_s") or rec.get("duration_s") or 0
    if verdict == "PASS" and actual < mmd:
        bad.append(f"{sym}: PASS claim with actual_duration_s={actual}s < mmd_seconds={mmd}s (should be INCOMPLETE)")
    elif verdict == "PASS":
        ok.append(f"{sym}: PASS ({actual}s ≥ {mmd}s)")
    elif verdict == "INCOMPLETE":
        ok.append(f"{sym}: INCOMPLETE ({actual}s < {mmd}s) — properly classified")
    else:
        ok.append(f"{sym}: {verdict or '<no-verdict>'} (not PASS, not gated here)")

lines = ["# Soak MMD check (G105)", "",
         f"Status: {'PASS' if not bad else 'FAIL'}",
         f"Soak symbols: {len(soak_mmd)} · OK: {len(ok)} · Violations: {len(bad)}", ""]
if ok:  lines.append("## OK");        [lines.append(f"- {x}") for x in ok];  lines.append("")
if bad: lines.append("## Violations"); [lines.append(f"- {x}") for x in bad]; lines.append("")
pathlib.Path(report_p).write_text("\n".join(lines))

if bad:
    print(f"FAIL G105: {len(bad)} soak MMD violation(s)")
    for b in bad:
        print(f"  - {b}")
    sys.exit(1)
print(f"PASS G105: {len(ok)} soak record(s) within MMD")
sys.exit(0)
PY
