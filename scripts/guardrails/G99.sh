#!/usr/bin/env bash
# phases: impl
# severity: BLOCKER
# Pipeline-authored exported symbols (func/type) must carry a [traces-to:] marker
# in their preceding godoc comment block.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || { echo "no target dir"; exit 0; }

MANIFEST="$RUN_DIR/impl/manifest.json"
OWNERSHIP="$RUN_DIR/impl/ownership-map.json"

python3 - "$TARGET" "$RUN_DIR" "$MANIFEST" "$OWNERSHIP" <<'PY'
import json, pathlib, re, sys
target, run_dir, manifest_path, ownership_path = sys.argv[1:5]
target_p = pathlib.Path(target)

authored = None
if pathlib.Path(manifest_path).is_file():
    try:
        m = json.load(open(manifest_path))
        if isinstance(m.get("pipeline_authored_files"), list):
            authored = set(m["pipeline_authored_files"])
    except Exception:
        authored = None

manual_files = set()
if pathlib.Path(ownership_path).is_file():
    try:
        own = json.load(open(ownership_path))
        for f in own.get("manual_files", []):
            manual_files.add(f)
    except Exception:
        pass

files = []
if authored is not None:
    for f in authored:
        p = target_p / f
        if p.suffix == ".go" and not p.name.endswith("_test.go") and p.is_file():
            files.append(p)
else:
    for p in target_p.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        rel = str(p.relative_to(target_p))
        if rel in manual_files:
            continue
        files.append(p)

sym_re = re.compile(r'^(func\s+(?:\([^)]+\)\s+)?([A-Z]\w+)|type\s+([A-Z]\w+))')
marker_re = re.compile(r'\[traces-to:\s*[^\]]+\]')

missing = []
for p in files:
    lines = p.read_text(errors="ignore").splitlines()
    for i, line in enumerate(lines):
        m = sym_re.match(line)
        if not m:
            continue
        sym = m.group(2) or m.group(3)
        # walk back over consecutive godoc // comment lines
        j = i - 1
        godoc = []
        while j >= 0 and lines[j].lstrip().startswith("//"):
            godoc.append(lines[j])
            j -= 1
        if not any(marker_re.search(g) for g in godoc):
            missing.append(f"{p.relative_to(target_p)}:{i+1} {sym}")

out = pathlib.Path(run_dir) / "impl" / "symbol-markers-check.md"
out.parent.mkdir(parents=True, exist_ok=True)
if missing:
    out.write_text("# Symbol markers: FAIL\n\n" +
                   "\n".join(f"- {m}" for m in missing) + "\n")
    print(f"FAIL: {len(missing)} exported symbol(s) missing [traces-to:] marker")
    for m in missing[:20]:
        print(f"  {m}")
    sys.exit(1)
out.write_text("# Symbol markers: PASS\n")
sys.exit(0)
PY
