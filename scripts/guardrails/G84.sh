#!/usr/bin/env bash
# phases: feedback
# severity: BLOCKER
# Per-run safety caps — counts of
#   prompt_patches, existing_skill_patches, new_skills,
#   new_guardrails, new_agents
# applied in this run must not exceed settings.json § safety_caps.
# Catches a runaway learning-engine before F-phase exit.
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_ID="$(basename "$RUN_DIR")"
SETTINGS="$REPO/.claude/settings.json"
EVO_LOG="$REPO/evolution/knowledge-base/prompt-evolution-log.jsonl"
REPORT="$RUN_DIR/feedback/safety-caps-check.md"
mkdir -p "$(dirname "$REPORT")"

[ -f "$SETTINGS" ] || { echo "FAIL G84: settings.json missing at $SETTINGS"; exit 1; }

python3 - "$SETTINGS" "$EVO_LOG" "$RUN_ID" "$REPORT" "$REPO" <<'PY'
import json, pathlib, sys
settings_p, evo_log, run_id, report, repo = sys.argv[1:6]

caps = json.loads(open(settings_p).read()).get("safety_caps", {})
# Map type → cap key
CAP_KEYS = {
    "prompt_patch":         "prompt_patches_per_run",
    "prompt_patches":       "prompt_patches_per_run",
    "existing_skill_patch": "existing_skill_patches_per_run",
    "skill_patch":          "existing_skill_patches_per_run",
    "new_skill":            "new_skills_per_run",
    "new_guardrail":        "new_guardrails_per_run",
    "new_agent":            "new_agents_per_run",
}

counts = {k: 0 for k in set(CAP_KEYS.values())}

if pathlib.Path(evo_log).is_file():
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
        key = CAP_KEYS.get(t)
        if key:
            counts[key] += 1

# Cross-check: any new skills/guardrails/agents that landed on filesystem this run
# (best-effort — we still trust the evolution log as the authority).

breaches = []
summary = []
for cap_key, used in sorted(counts.items()):
    cap_val = caps.get(cap_key)
    if cap_val is None:
        summary.append(f"- {cap_key}: used {used} (no cap declared)")
        continue
    summary.append(f"- {cap_key}: used {used} / cap {cap_val}")
    if used > cap_val:
        breaches.append(f"{cap_key}: {used} > cap {cap_val}")

lines = ["# Safety-caps check (G84)", ""]
status = "PASS" if not breaches else "FAIL"
lines.append(f"Status: {status}")
lines.append("")
lines.append("## Declared caps (settings.json § safety_caps)")
for k, v in sorted(caps.items()):
    if k == "_note":
        continue
    lines.append(f"- `{k}`: {v}")
lines.append("")
lines.append("## Counts for this run")
lines.extend(summary)
lines.append("")
if breaches:
    lines.append("## Breaches")
    for b in breaches:
        lines.append(f"- {b}")
    lines.append("")

pathlib.Path(report).write_text("\n".join(lines))

if breaches:
    print(f"FAIL G84: {len(breaches)} cap breach(es)")
    for b in breaches:
        print(f"  - {b}")
    sys.exit(1)
print("PASS G84: all safety caps respected")
sys.exit(0)
PY
