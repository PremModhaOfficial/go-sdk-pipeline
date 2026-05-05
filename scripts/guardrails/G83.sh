#!/usr/bin/env bash
# phases: feedback
# severity: BLOCKER
# Rule 23 — every body-patch the learning-engine applied to an existing skill
# in this run must have a matching entry in that skill's adjacent evolution-log.md.
# Runs in O(patches) by iterating `evolution/knowledge-base/prompt-evolution-log.jsonl`
# filtered to this run_id.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_ID="$(basename "$RUN_DIR")"
EVO_LOG="$REPO/evolution/knowledge-base/prompt-evolution-log.jsonl"
SKILLS_ROOT="$REPO/.claude/skills"
REPORT="$RUN_DIR/feedback/skill-evolution-log-check.md"
mkdir -p "$(dirname "$REPORT")"

# No evolution log yet → nothing to verify.
[ -f "$EVO_LOG" ] || {
  mkdir -p "$(dirname "$REPORT")"
  echo "# Skill evolution-log check (G83)" >  "$REPORT"
  echo "" >> "$REPORT"
  echo "Status: PASS — no prompt-evolution-log.jsonl present; no patches to verify." >> "$REPORT"
  exit 0
}

python3 - "$EVO_LOG" "$SKILLS_ROOT" "$RUN_ID" "$REPORT" <<'PY'
import json, pathlib, re, sys
evo_log, skills_root, run_id, report = sys.argv[1:5]

patches = []
for line in open(evo_log, errors="ignore").read().splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
    except Exception:
        continue
    if rec.get("run_id") != run_id:
        continue
    t = rec.get("type") or rec.get("patch_type") or ""
    # existing-skill patch shapes we recognize
    if t in ("existing_skill_patch", "skill_patch") or rec.get("target_kind") == "skill":
        name = rec.get("skill") or rec.get("target") or rec.get("skill_name")
        if name:
            patches.append({
                "skill": name,
                "version": rec.get("new_version") or rec.get("version_after") or "",
            })

missing = []
ok      = []

for p in patches:
    skill_dir = pathlib.Path(skills_root) / p["skill"]
    evo_md    = skill_dir / "evolution-log.md"
    if not evo_md.is_file():
        missing.append(f"{p['skill']} (no evolution-log.md)")
        continue
    text = evo_md.read_text(errors="ignore")
    # Accept either an explicit run_id reference or a matching version header.
    hits = []
    if run_id in text:
        hits.append("run_id")
    if p["version"] and re.search(r'(?m)^\s*#+.*\b' + re.escape(p["version"]) + r'\b', text):
        hits.append("version-header")
    if hits:
        ok.append(f"{p['skill']} → {','.join(hits)}")
    else:
        missing.append(f"{p['skill']} (no entry referencing run_id={run_id} or version={p['version'] or '?'})")

lines = ["# Skill evolution-log check (G83)", ""]
status = "PASS" if not missing else "FAIL"
lines.append(f"Status: {status}")
lines.append(f"Patches in this run: {len(patches)} · logged: {len(ok)} · missing: {len(missing)}")
lines.append("")
if ok:
    lines.append("## Logged")
    for o in ok:
        lines.append(f"- {o}")
    lines.append("")
if missing:
    lines.append("## Missing")
    for m in missing:
        lines.append(f"- {m}")
    lines.append("")

pathlib.Path(report).write_text("\n".join(lines))
if missing:
    print(f"FAIL G83: {len(missing)} patch(es) missing from evolution-log.md")
    for m in missing:
        print(f"  - {m}")
    sys.exit(1)
print(f"PASS G83: {len(patches)} patch(es) logged (or none applied)")
sys.exit(0)
PY
