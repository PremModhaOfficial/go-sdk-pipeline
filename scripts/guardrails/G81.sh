#!/usr/bin/env bash
# phases: feedback
# severity: BLOCKER
# Rule 28 compensating baselines — at least one of
#   baselines/go/output-shape-history.jsonl
#   baselines/go/devil-verdict-history.jsonl
#   baselines/go/coverage-baselines.json
# must advance during this run, OR the feedback report must carry a skip
# rationale tagged "baseline-skip-rationale:".
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_ID="$(basename "$RUN_DIR")"
REPORT="$RUN_DIR/feedback/baseline-advance-check.md"
mkdir -p "$(dirname "$REPORT")"

python3 - "$REPO" "$RUN_DIR" "$RUN_ID" "$REPORT" <<'PY'
import json, pathlib, re, sys
repo, run_dir, run_id, report = sys.argv[1:5]
repo_p = pathlib.Path(repo)
run_p  = pathlib.Path(run_dir)

advanced = {}

# v0.4.0 partition: baselines may live at root (legacy), baselines/<lang>/ (per-language),
# or baselines/shared/ (cross-language). Check all candidate locations for each file.
def _candidate_paths(filename):
    candidates = [repo_p / "baselines" / filename]
    bdir = repo_p / "baselines"
    if bdir.is_dir():
        for sub in sorted(p for p in bdir.iterdir() if p.is_dir() and not p.name.startswith(".")):
            candidates.append(sub / filename)
    return candidates

def _jsonl_has_run(filename):
    for p in _candidate_paths(filename):
        if not p.is_file():
            continue
        try:
            for line in p.read_text().splitlines():
                if not line.strip():
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                if rec.get("run_id") == run_id:
                    return True
        except Exception:
            continue
    return False

# output-shape-history.jsonl
advanced["output-shape-history.jsonl"] = _jsonl_has_run("output-shape-history.jsonl")

# devil-verdict-history.jsonl
advanced["devil-verdict-history.jsonl"] = _jsonl_has_run("devil-verdict-history.jsonl")

# coverage-baselines.json — accept either a per-run entry or mtime bump recorded
advanced["coverage-baselines.json"] = False
for cov in _candidate_paths("coverage-baselines.json"):
    if not cov.is_file():
        continue
    try:
        data = json.loads(cov.read_text())
        runs = data.get("runs") or data.get("history") or {}
        if isinstance(runs, dict) and run_id in runs:
            advanced["coverage-baselines.json"] = True
            break
        elif isinstance(runs, list) and any(r.get("run_id") == run_id for r in runs if isinstance(r, dict)):
            advanced["coverage-baselines.json"] = True
            break
        elif data.get("last_run_id") == run_id or data.get("first_seeded_by_run") == run_id:
            advanced["coverage-baselines.json"] = True
            break
        # v0.4.0 per-package shape: packages.<pkg>.first_seeded_by_run == run_id
        pkgs = data.get("packages") or {}
        if isinstance(pkgs, dict):
            for pkg_data in pkgs.values():
                if isinstance(pkg_data, dict) and pkg_data.get("first_seeded_by_run") == run_id:
                    advanced["coverage-baselines.json"] = True
                    break
            if advanced["coverage-baselines.json"]:
                break
    except Exception:
        continue

any_advanced = any(advanced.values())

# Rationale: scan feedback/*.md for an explicit "baseline-skip-rationale:" line.
rationale = None
fb_dir = run_p / "feedback"
if fb_dir.is_dir():
    for p in sorted(fb_dir.glob("*.md")):
        try:
            text = p.read_text(errors="ignore")
        except Exception:
            continue
        m = re.search(r'(?im)^.*baseline-skip-rationale:\s*(.+)$', text)
        if m:
            rationale = {"file": str(p.relative_to(run_p)), "line": m.group(1).strip()}
            break

lines = ["# Baseline advance check (G81)", "",
         f"Status: {'PASS' if any_advanced or rationale else 'FAIL'}", ""]
lines.append("## Advance map")
for name, ok in advanced.items():
    lines.append(f"- `{name}` {'advanced ✓' if ok else 'unchanged'}")
lines.append("")
if rationale:
    lines.append("## Skip rationale")
    lines.append(f"- `{rationale['file']}`: {rationale['line']}")
    lines.append("")

pathlib.Path(report).write_text("\n".join(lines))

if any_advanced:
    print(f"PASS G81: {sum(advanced.values())} baseline(s) advanced for run {run_id}")
    sys.exit(0)
if rationale:
    print(f"PASS G81: no baselines advanced, rationale accepted — {rationale['file']}")
    sys.exit(0)

print("FAIL G81: no compensating baseline advanced for this run and no rationale filed.")
print("  expected one of:")
for name in advanced:
    print(f"    - baselines/{name}  (append entry with run_id={run_id})")
print("  OR feedback/*.md line:  baseline-skip-rationale: <reason>")
sys.exit(1)
PY
