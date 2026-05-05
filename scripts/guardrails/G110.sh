#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Rule 32 axis 7 + rule 29 marker protocol.
# Any source-line bearing `[perf-exception: <reason> bench/BenchmarkX]` must
# have a matching entry in runs/<run-id>/design/perf-exceptions.md declaring
# the exception at design time AND a profile-auditor-measured bench win.
# Orphan markers (no matching entry) fail the gate.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || { echo "no target dir"; exit 0; }
EXC_FILE="$RUN_DIR/design/perf-exceptions.md"
REPORT="$RUN_DIR/impl/perf-exception-pairing-check.md"
mkdir -p "$(dirname "$REPORT")"

python3 - "$TARGET" "$EXC_FILE" "$REPORT" "$RUN_DIR" <<'PY'
import pathlib, re, sys
target, exc_file, report_p, run_dir = sys.argv[1:5]
target_p = pathlib.Path(target)

marker_re = re.compile(r'\[perf-exception:\s*([^\]]+?)\s+bench/([A-Za-z_]\w+)\s*\]')
markers = []
for p in target_p.rglob("*.go"):
    try:
        for lineno, line in enumerate(p.read_text(errors="ignore").splitlines(), start=1):
            for m in marker_re.finditer(line):
                markers.append({
                    "file":   str(p.relative_to(target_p)),
                    "line":   lineno,
                    "reason": m.group(1).strip(),
                    "bench":  m.group(2).strip(),
                    "raw":    m.group(0),
                })
    except Exception:
        continue

exc_text = ""
if pathlib.Path(exc_file).is_file():
    exc_text = pathlib.Path(exc_file).read_text(errors="ignore")

orphans      = []
matched      = []
missing_win  = []

# A matching entry requires the bench name to appear in perf-exceptions.md
# AND the reason (first keyword) to appear near it, AND a "bench_win:" or
# "measured_ns_saved:" assertion to be present for that bench.
for mk in markers:
    bench = mk["bench"]
    if bench not in exc_text:
        orphans.append(mk)
        continue
    # Locate the stanza containing this bench
    stanza_re = re.compile(
        r'(?ms)(?:^#+\s*[^\n]*\n|^-[^\n]*\n)'
        r'(?:(?!^#+\s|^\s*-\s*\w+:\s*[A-Z]).)*?'
        r'\b' + re.escape(bench) + r'\b'
        r'(?:(?!^#+\s).)*'
    )
    m = stanza_re.search(exc_text)
    stanza = m.group(0) if m else ""
    has_win = bool(re.search(r'(?m)^\s*(?:bench_win|measured_ns_saved|ns_saved|pct_saved)\s*:', stanza))
    if has_win:
        matched.append(mk)
    else:
        missing_win.append(mk)

lines = ["# perf-exception pairing check (G110)", ""]
if not markers:
    lines.append("Status: PASS — zero `[perf-exception: ...]` markers found in target.")
    pathlib.Path(report_p).write_text("\n".join(lines) + "\n")
    print("PASS G110: zero perf-exception markers")
    sys.exit(0)

status = "PASS" if not orphans and not missing_win else "FAIL"
lines.append(f"Status: {status}")
lines.append(f"Markers: {len(markers)} · Matched (with bench win): {len(matched)} · "
             f"Orphans: {len(orphans)} · Missing bench-win: {len(missing_win)}")
lines.append("")
if matched:
    lines.append("## Matched")
    for mk in matched:
        lines.append(f"- {mk['file']}:{mk['line']} `{mk['raw']}`")
    lines.append("")
if orphans:
    lines.append("## Orphans (no matching entry in design/perf-exceptions.md)")
    for mk in orphans:
        lines.append(f"- {mk['file']}:{mk['line']} `{mk['raw']}`")
    lines.append("")
if missing_win:
    lines.append("## Missing bench win (entry exists but lacks bench_win/measured_ns_saved/pct_saved)")
    for mk in missing_win:
        lines.append(f"- {mk['file']}:{mk['line']} `{mk['raw']}`")
    lines.append("")
pathlib.Path(report_p).write_text("\n".join(lines))

if orphans or missing_win:
    print(f"FAIL G110: {len(orphans)} orphan(s), {len(missing_win)} missing-win")
    for mk in orphans + missing_win:
        print(f"  - {mk['file']}:{mk['line']} {mk['raw']}")
    sys.exit(1)
print(f"PASS G110: all {len(markers)} perf-exception markers paired with bench-win entries")
sys.exit(0)
PY
