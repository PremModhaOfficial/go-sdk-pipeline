#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# [stable-since: vX.Y.Z] signature-change guard — any change to a stable
# signature requires TPRD §12 Breaking-Change Risk section to declare MAJOR.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || { echo "no target dir"; exit 0; }

BASELINE_DIR="$(dirname "$0")/../../baselines"
BASELINE="$BASELINE_DIR/stable-signatures.json"
TPRD="$RUN_DIR/tprd.md"

python3 - "$TARGET" "$RUN_DIR" "$BASELINE" "$TPRD" <<'PY'
import json, pathlib, re, sys
target, run_dir, baseline_path, tprd_path = sys.argv[1:5]
target_p = pathlib.Path(target)
baseline_p = pathlib.Path(baseline_path)

stable_re = re.compile(r'\[stable-since:\s*v\d+\.\d+\.\d+\]')
sig_re = re.compile(r'^(func\s+(?:\([^)]+\)\s+)?[A-Z]\w+[^{]*|type\s+[A-Z]\w+[^{]*)')
ws_re = re.compile(r'\s+')

current = {}
for p in target_p.rglob("*.go"):
    if p.name.endswith("_test.go"):
        continue
    lines = p.read_text(errors="ignore").splitlines()
    for i, line in enumerate(lines):
        m = sig_re.match(line)
        if not m:
            continue
        # look back for godoc with [stable-since]
        j = i - 1
        godoc = []
        while j >= 0 and lines[j].lstrip().startswith("//"):
            godoc.append(lines[j]); j -= 1
        if not any(stable_re.search(g) for g in godoc):
            continue
        sig_line = ws_re.sub(" ", m.group(1).rstrip("{").strip())
        # key by signature declarator core (first identifier after func/type)
        key = f"{p.relative_to(target_p)}::{sig_line}"
        # store normalized signature under filename + symbol name
        # simpler: key on file+symbol_ident
        nm = re.search(r'(?:func\s+(?:\([^)]+\)\s+)?|type\s+)([A-Z]\w+)', m.group(1))
        if nm:
            current[f"{p.relative_to(target_p)}::{nm.group(1)}"] = sig_line

if not baseline_p.is_file():
    baseline_p.parent.mkdir(parents=True, exist_ok=True)
    baseline_p.write_text(json.dumps(current, indent=2, sort_keys=True) + "\n")
    print(f"baseline created ({len(current)} stable signatures) — first run, skipped")
    sys.exit(0)

baseline = json.loads(baseline_p.read_text())
changed = [k for k, v in current.items() if k in baseline and baseline[k] != v]

if not changed:
    # persist new stable symbols
    for k, v in current.items():
        baseline.setdefault(k, v)
    baseline_p.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n")
    sys.exit(0)

# Signature changed — check TPRD §12 declares MAJOR / breaking
tprd_text = ""
if pathlib.Path(tprd_path).is_file():
    tprd_text = open(tprd_path).read()
sec12 = re.search(r'(?i)#+\s*(?:\d+\.\s*)?(?:§\s*)?12[^\n]*\n(.*?)(?=\n#+\s|\Z)',
                  tprd_text, re.DOTALL)
sec12_text = sec12.group(1) if sec12 else ""
has_major = bool(re.search(r'\b(MAJOR|breaking)\b', sec12_text, re.IGNORECASE))

if not has_major:
    print(f"FAIL: {len(changed)} stable signature(s) changed without TPRD §12 MAJOR declaration")
    for k in changed:
        print(f"  {k}")
        print(f"    was:  {baseline[k]}")
        print(f"    now:  {current[k]}")
    sys.exit(1)
print(f"OK: {len(changed)} stable signature change(s) covered by TPRD §12 MAJOR declaration")
sys.exit(0)
PY
