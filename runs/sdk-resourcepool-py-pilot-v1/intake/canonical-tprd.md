# Canonical TPRD (Wave I5)

Run-id: `sdk-resourcepool-py-pilot-v1`
Source: `/home/meet-dadhania/Documents/motadata-ai-pipeline/motadata-sdk/TPRD.md`
Run-local copy: `runs/sdk-resourcepool-py-pilot-v1/tprd.md` (566 lines, 33977 bytes)

## Canonicalization summary

**No rewrites required.** The TPRD was authored with intake's full schema in mind and passed every preflight (16 sections + 5 v0.5.0 §-fields + §Skills-Manifest 22/22 + §Guardrails-Manifest 19/19 + §Non-Goals 13 bullets) on first parse. Zero clarification questions were generated. The canonical TPRD for downstream phases is **byte-identical** to the run-local copy at `runs/sdk-resourcepool-py-pilot-v1/tprd.md`.

## Cross-references resolved

- §1 Request Mode → `mode.json:mode = "A"` ✓
- §Target-Language → `active-packages.json:target_language = "python"` ✓
- §Target-Tier → `active-packages.json:target_tier = "T1"` ✓
- §Required-Packages → `active-packages.json:resolution_order = [shared-core, python]` ✓
- §Skills-Manifest 22 entries → all present in active-packages.json:skills (union: 36) ✓ — see skill-orphan-check.md
- §Guardrails-Manifest 19 entries → all present + executable in `scripts/guardrails/` ✓
- §10 oracle-margin (10× Go reference) → `sdk-perf-architect-python` will materialize numbers in Phase 1 D1 perf-budget.md
- §11.4 leak-check → `python-asyncio-leak-prevention` skill present; `sdk-asyncio-leak-hunter-python` agent in active set
- §16 semver Mode A 1.0.0 → `sdk-semver-devil` will confirm at H5

## Open questions (TPRD §15)

All seven open questions are pre-resolved by the author (Q1–Q6 marked **Decided**, Q7 explicitly flagged as **PILOT-DRIVEN — surfaces T2-3** and is intended to be answered by the pipeline run itself, not by intake). No clarification requests needed.

## Pilot-test markers (informational)

The TPRD has dual goals: (a) ship the Python resource pool, and (b) test pipeline decisions D2 + D6 + T2-3 + T2-7. Phase 4's `python-pilot-retrospective.md` (per Appendix C) will answer all four — intake notes this explicitly so phase leads do not treat the secondary pipeline-meta hooks as scope creep.

## Verdict

CANONICAL == SOURCE. Proceed to H1.
