#!/usr/bin/env bash
# phases: meta
# severity: BLOCKER
# skill-index.json consistent with filesystem
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
ROOT="$(dirname "$0")/../../.claude/skills"
python3 - <<PY
import json, pathlib, sys
root = pathlib.Path("$ROOT")
idx = json.loads((root / "skill-index.json").read_text())
declared = set()
for section in ("ported_verbatim","ported_with_delta","to_synthesize_on_first_use"):
    for e in idx.get("skills",{}).get(section,[]):
        declared.add(e["name"])
fs = {p.name for p in root.iterdir() if p.is_dir()}
missing_on_fs = declared - fs
missing_in_idx = fs - declared
if missing_on_fs:
    print("in index, missing on fs:", missing_on_fs); sys.exit(1)
# allow extras in fs (e.g., newly-synthesized); just warn
PY
