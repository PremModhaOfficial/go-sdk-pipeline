#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# No forged MANUAL markers — every [traces-to: MANUAL-*] or [owned-by: MANUAL]
# must be on a symbol listed in ownership-map manual_symbols.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || { echo "no target dir"; exit 0; }
OWNERSHIP="$RUN_DIR/impl/ownership-map.json"
[ -f "$OWNERSHIP" ] || { echo "no ownership-map (Mode A — skipped)"; exit 0; }

python3 - "$TARGET" "$OWNERSHIP" "$RUN_DIR" <<'PY'
import json, pathlib, re, sys
target, ownership_path, run_dir = sys.argv[1:4]
target_p = pathlib.Path(target)

own = json.load(open(ownership_path))
allowed = set()  # set of (file, symbol)
for e in own.get("manual_symbols", []):
    allowed.add((e.get("file", ""), e.get("symbol", "")))
manual_files = set(own.get("manual_files", []))
for e in own.get("manual_symbols", []):
    manual_files.add(e.get("file", ""))

manual_marker_re = re.compile(
    r'\[(?:traces-to:\s*MANUAL-[^\]]+|owned-by:\s*MANUAL)\]')
sym_re = re.compile(r'^(?:func\s+(?:\([^)]+\)\s+)?([A-Z]\w+)|type\s+([A-Z]\w+))')

forged = []
for p in target_p.rglob("*.go"):
    if p.name.endswith("_test.go"):
        continue
    rel = str(p.relative_to(target_p))
    lines = p.read_text(errors="ignore").splitlines()
    for i, line in enumerate(lines):
        if not manual_marker_re.search(line):
            continue
        # find the nearest following symbol declaration
        sym = None
        for j in range(i + 1, min(i + 30, len(lines))):
            m = sym_re.match(lines[j])
            if m:
                sym = m.group(1) or m.group(2); break
            if lines[j].strip() and not lines[j].lstrip().startswith("//"):
                break
        if sym is None:
            # marker not attached to a symbol — allow (file-level)
            if rel not in manual_files:
                forged.append(f"{rel}:{i+1} MANUAL marker on non-manual file")
            continue
        if (rel, sym) not in allowed:
            forged.append(f"{rel}:{i+1} MANUAL marker on pipeline symbol '{sym}'")

out = pathlib.Path(run_dir) / "impl" / "forged-manual-check.md"
out.parent.mkdir(parents=True, exist_ok=True)
if forged:
    out.write_text("# Forged MANUAL markers: FAIL\n\n" +
                   "\n".join(f"- {f}" for f in forged) + "\n")
    print(f"FAIL: {len(forged)} forged MANUAL marker(s)")
    for f in forged[:20]:
        print(f"  {f}")
    sys.exit(1)
out.write_text("# Forged MANUAL markers: PASS\n")
sys.exit(0)
PY
