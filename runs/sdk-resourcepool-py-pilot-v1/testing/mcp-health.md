<!-- Generated: 2026-04-28T00:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead -->

# MCP health (Phase 3 entry)

`scripts/guardrails/G04.sh` invoked at testing-phase start (Wave T0).

| Field | Value |
|---|---|
| Exit code | 0 |
| Severity declared by G04 | WARN (per script header) |
| Verdict | OK (neo4j-memory probe succeeded — `claude-neo4j` docker container Up, bolt port 7687 reachable) |
| Report file | `runs/sdk-resourcepool-py-pilot-v1/intake/mcp-health.md` (G04 wrote there because intake/ exists; testing/ also gets a copy via this file) |

Per CLAUDE.md rule 31: MCP availability is enhancement-only. Pipeline NEVER halts on MCP miss. This run has MCPs reachable, so the optional cross-run learning paths are available; testing-phase agents that would consult MCPs (e.g. cross-run pattern lookup) may proceed with normal-confidence outputs.

Verdict: PASS (gate is WARN-severity and is GREEN).
