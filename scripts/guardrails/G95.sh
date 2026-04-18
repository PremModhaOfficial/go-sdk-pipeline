#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Marker ownership — existing tests + benchmarks must continue passing
# post-update (Mode B/C). Pipeline MUST NOT modify [owned-by: MANUAL] symbols.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
OWNERSHIP="$RUN_DIR/impl/ownership-map.json"
[ -f "$OWNERSHIP" ] || { echo "no ownership-map (Mode A — skipped)"; exit 0; }
[ -n "$TARGET" ] || { echo "no target dir"; exit 1; }

python3 - "$OWNERSHIP" "$TARGET" "$RUN_DIR" <<'PY'
import json, sys, pathlib, hashlib
ownership_path, target, run_dir = sys.argv[1:4]
own = json.load(open(ownership_path))

bad = []
for entry in own.get("manual_symbols", []):
    path = pathlib.Path(target) / entry["file"]
    if not path.is_file():
        bad.append(f"MANUAL file removed: {entry['file']}")
        continue
    text = path.read_text(errors="ignore")
    # Match recorded hash of the symbol's byte range
    start, end = entry.get("byte_start", 0), entry.get("byte_end", 0)
    if end <= start:
        continue
    region = text.encode("utf-8", errors="ignore")[start:end]
    h = hashlib.sha256(region).hexdigest()
    if h != entry.get("sha256", ""):
        bad.append(f"MANUAL symbol modified: {entry['file']} — {entry.get('symbol', '?')}")

out = pathlib.Path(run_dir) / "impl" / "marker-ownership-check.md"
out.parent.mkdir(parents=True, exist_ok=True)
if bad:
    out.write_text("# Marker ownership: FAIL\n\n" + "\n".join(f"- {b}" for b in bad) + "\n")
    print(f"FAIL: {len(bad)} MANUAL symbol(s) modified — BLOCKER")
    for b in bad:
        print(f"  {b}")
    sys.exit(1)
out.write_text("# Marker ownership: PASS\n")
sys.exit(0)
PY
