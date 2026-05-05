<!-- Generated: 2026-04-27T00:00:15Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# HITL H1 — TPRD Acceptance Gate

**Verdict**: **BLOCKED — user resolution required on G90 before Phase 1 Design may start.**

## Why H1 is not auto-passed

Eight intake-phase guardrails passed cleanly: G05, G06, G20, G21, G22, G23, G24, G93, G116.

One drift-prevention guardrail failed: **G90 (skill-index ↔ filesystem strict equality)**. Per CLAUDE.md rule 23 + the v0.3.0-straighten note ("the pipeline refuses to operate on a drifted repo"), G90 is a meta-BLOCKER at intake. Auto-mode is not a license to bypass safety rails.

## Root cause of the G90 BLOCKER

`scripts/guardrails/G90.sh` (v0.3.0-straighten era) reads `skill-index.json` only from sections `ported_verbatim`, `ported_with_delta`, and `sdk_native`:

```bash
for section in ("ported_verbatim","ported_with_delta","sdk_native"):
    for e in idx.get("skills",{}).get(section,[]):
        declared.add(e["name"])
```

The v0.5.0 Phase A Python adapter PR (commit `3bff99c`) added a new section `python_specific` with the four skills `asyncio-cancellation-patterns`, `pytest-table-tests`, `python-asyncio-patterns`, `python-class-design`, and bumped the index `schema_version` to `1.1.0`. **The G90.sh script was not updated in the same PR**. Result: G90 sees the four skill directories on disk but does not see them in its truncated read of the index, and reports them as "Present on fs but not indexed."

This is genuine pipeline-infrastructure drift, not a TPRD issue. The four skills ARE correctly indexed; G90 just doesn't read the section they live in.

## Why intake cannot self-heal this

Per the user's READ-ONLY constraint on this run, sdk-intake-agent is permitted to write only inside `runs/sdk-resourcepool-py-pilot-v1/`, `docs/PROPOSED-SKILLS.md`, `docs/PROPOSED-GUARDRAILS.md`, and `decision-log.jsonl`. `scripts/guardrails/G90.sh` is outside that scope. The sandbox correctly enforced the boundary.

## Resolution options for the user

Pick one of the following before re-running intake:

**Option 1 (recommended, 1-line fix)** — extend G90's section list:

```diff
-for section in ("ported_verbatim","ported_with_delta","sdk_native"):
+for section in ("ported_verbatim","ported_with_delta","sdk_native","python_specific"):
     for e in idx.get("skills",{}).get(section,[]):
         declared.add(e["name"])
```

**Option 2** — generalize G90 to read all sections under `skills.*`:

```python
for section, entries in idx.get("skills", {}).items():
    for e in entries:
        declared.add(e["name"])
```

This future-proofs against the next language-adapter PR (e.g. `rust_specific` in v0.6.0) without requiring a G90 patch.

**Option 3** — re-organize `skill-index.json` to fold the four `python_specific` entries into `sdk_native`. This works but loses the per-language tagging that the index `tags_index.python` already exploits.

After applying any of the above, re-run:

```bash
bash scripts/check-doc-drift.sh runs/sdk-resourcepool-py-pilot-v1
bash scripts/guardrails/G05.sh   runs/sdk-resourcepool-py-pilot-v1
bash scripts/guardrails/G20.sh   runs/sdk-resourcepool-py-pilot-v1
bash scripts/guardrails/G23.sh   runs/sdk-resourcepool-py-pilot-v1
bash scripts/guardrails/G24.sh   runs/sdk-resourcepool-py-pilot-v1
```

All five must exit 0. Then H1 is approvable and Phase 1 Design may start.

## What is already locked in (carries forward once H1 approves)

- **TPRD canonicalized** at `runs/sdk-resourcepool-py-pilot-v1/tprd.md` (16 sections + 2 manifests + 3 appendices, 565 lines, Mode A).
  Two cosmetic edits vs. source TPRD to satisfy G20/G24 keyword anchoring; semantics fully preserved (see intake-summary.md §G24 + §G20 notes).
- **Mode**: A (new package); `intake/mode.json` written.
- **Active packages**: `shared-core@1.0.0` + `python@1.0.0` resolved cleanly; `context/active-packages.json` + `context/toolchain.md` written; G05 PASS.
- **20/20 declared skills** present at ≥ declared min version; nothing filed to `docs/PROPOSED-SKILLS.md`.
- **22/22 declared guardrails** present + executable.
- **User hard constraint** (zero TPRD tech debt) propagated verbatim into `intake/intake-summary.md` for downstream lead inheritance.
- **Decision log** seeded with 16 entries (≤15 cap policy applies per agent; intake's last entry is `lifecycle: completed-with-blocker`).

## Cancel / revise / approve options at H1

- **approve** — only valid after G90 is fixed and re-run shows green.
- **revise** — pick one of options 1/2/3 above; intake re-runs the failed gates; no impact on the rest of intake's outputs.
- **cancel** — halt the pipeline; preserve intake artifacts for forensics.

---

## H1 — Resolution

**Verdict**: **APPROVED**
**Resolved at**: 2026-04-27T00:00:14Z
**Authorization**: user, via AskUserQuestion answer "Generalize (recommended)" earlier in this conversation thread.
**Patched by**: orchestrator (out-of-band; sdk-intake-agent is READ-ONLY outside `runs/`).

### Diff applied to `scripts/guardrails/G90.sh`

```diff
-for section in ("ported_verbatim","ported_with_delta","sdk_native"):
-    for e in idx.get("skills",{}).get(section,[]):
-        declared.add(e["name"])
+for section, entries in idx.get("skills", {}).items():
+    for e in entries:
+        declared.add(e["name"])
```

This is Option 2 from the resolution menu above — generalizes G90 to read every section under `skills.*`, so the next language-adapter PR (e.g. `rust_specific` in v0.6.0) does not require another G90 patch.

### Verification

```
$ bash scripts/guardrails/G90.sh runs/sdk-resourcepool-py-pilot-v1
PASS: skill-index.json matches filesystem (45 skills)
$ echo $?
0

$ bash scripts/check-doc-drift.sh runs/sdk-resourcepool-py-pilot-v1
=== Drift guardrails ===
PASS G06
PASS G90
PASS G116
=== drift check PASSED ===
$ echo $?
0
```

### Final intake-phase gate matrix

| Gate | Verdict |
|---|---|
| G05 active-packages.json | PASS |
| G06 pipeline_version drift | PASS |
| G20 TPRD topic-area completeness | PASS |
| G21 §Non-Goals populated | PASS |
| G22 clarifications cap | PASS (0) |
| G23 §Skills-Manifest | PASS (20/20) |
| G24 §Guardrails-Manifest | PASS (22/22) |
| G90 skill-index ↔ filesystem | PASS (45 skills) |
| G93 settings.json schema | PASS |
| G116 retired-term scanner | PASS |

Phase 1 Design (`sdk-design-lead`) is unblocked. Run-manifest `phases.intake.status` set to `completed`; `hitl_gates.H1_tprd` set to `approved`.
