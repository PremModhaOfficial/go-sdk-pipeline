# Agent Roster

This file is the single source of truth for every agent in this pipeline. Canonical per-agent prompt files live in `.claude/agents/<name>.md`.

## Ownership Matrix

| Domain | Owner agent | Consulted | MCPs used |
|---|---|---|---|
| TPRD canonicalization + manifest validation | `sdk-intake-agent` | — | `context7` |
| New skill authorship | **human only** (PR merge) | — | — |
| Existing skill body patches | `learning-engine` (Phase 4) | `sdk-golden-regression-runner`, `baseline-manager` | `neo4j-memory` |
| Extension pre-design snapshot | `sdk-existing-api-analyzer` | — | `serena`, `code-graph` |
| Target-SDK marker ownership map | `sdk-marker-scanner` | — | `serena`, `ast-grep` |
| API design | `sdk-design-lead` | `pattern-advisor`, `sdk-designer` | `context7` |
| Interface signatures | `interface-designer` | `sdk-designer` | — |
| Retry/backoff/CB algorithms | `algorithm-designer` | `sdk-designer` | — |
| Concurrency patterns | `concurrency-designer` | — | — |
| Dependency vetting | `sdk-dep-vet-devil` | — | — |
| Semver verdict | `sdk-semver-devil` | `sdk-breaking-change-devil` (Mode B/C) | — |
| Target SDK convention conformance | `sdk-convention-devil` | — | — |
| Security review | `sdk-security-devil` | — | — |
| Code generation in target | `sdk-impl-lead` | `sdk-implementor`, `code-generator` | `serena`, `tree-sitter` |
| Merge planning (marker-aware) | `sdk-merge-planner` | `sdk-marker-scanner` | `serena` |
| Marker hygiene | `sdk-marker-hygiene-devil` | — | `ast-grep` |
| Constraint proof execution | `sdk-constraint-devil` | — | — |
| Leak hunt | `sdk-leak-hunter` | — | — |
| API ergonomics (consumer POV) | `sdk-api-ergonomics-devil` | — | — |
| Refactoring | `refactoring-agent` | — | — |
| Documentation | `documentation-agent` | — | — |
| Testing lead | `sdk-testing-lead` | `unit-test-agent`, `integration-test-agent`, `performance-test-agent` | — |
| Benchmark regression verdict | `sdk-benchmark-devil` | `baseline-manager` | — |
| Integration flake hunt | `sdk-integration-flake-hunter` | — | — |
| Metrics collection | `metrics-collector` | — | `neo4j-memory` |
| Phase retrospective | `phase-retrospector` | — | — |
| Root-cause trace | `root-cause-tracer` | — | `neo4j-memory` |
| Improvement planning | `improvement-planner` | — | `neo4j-memory` |
| Learning + patch application | `learning-engine` | `baseline-manager` | `neo4j-memory` |
| Skill drift detection | `sdk-skill-drift-detector` | — | `serena`, `ast-grep`, `neo4j-memory` |
| Skill coverage reporting | `sdk-skill-coverage-reporter` | — | `neo4j-memory` |
| Golden-corpus regression | `sdk-golden-regression-runner` | — | — |
| Mechanical guardrail checks | `guardrail-validator` | — | — |
| Baseline management | `baseline-manager` | — | `neo4j-memory` |

## Agent Groups

### Leads (orchestrators)
- `sdk-intake-agent` — Phase 0 (also acts as its own lead)
- `sdk-existing-api-analyzer` — Phase 0.5 (Mode B/C only)
- `sdk-design-lead` — Phase 1
- `sdk-impl-lead` — Phase 2
- `sdk-testing-lead` — Phase 3
- `learning-engine` — Phase 4 (skill-patch scope narrowed)

### Design agents (SDK-specific)
- `sdk-designer`, `interface-designer`, `algorithm-designer`, `concurrency-designer`, `pattern-advisor`

### Implementation agents
- `sdk-implementor`, `code-generator` (adapted scope), `test-spec-generator` (adapted), `refactoring-agent`, `documentation-agent`

### Testing agents
- `unit-test-agent`, `integration-test-agent`, `performance-test-agent`, `mutation-test-agent`, `observability-test-agent`, `fuzz-agent` (new minimal)

### Feedback agents (feedback-track)
- `metrics-collector`, `phase-retrospector`, `root-cause-tracer`, `defect-analyzer`, `improvement-planner`, `baseline-manager`, `learning-engine`

### Devil / adversarial agents (SDK-specific)
- `sdk-design-devil` (D3)
- `sdk-dep-vet-devil` (D4)
- `sdk-semver-devil` (D5)
- `sdk-convention-devil` (D6)
- `sdk-security-devil` (D7)
- `sdk-overengineering-critic` (D8)
- `sdk-leak-hunter` (D9)
- `sdk-api-ergonomics-devil` (D10)
- `sdk-integration-flake-hunter` (D11)
- `sdk-benchmark-devil` (D12)
- `sdk-skill-drift-detector` (D13)
- `sdk-skill-coverage-reporter` (D14)
- `sdk-golden-regression-runner` (D15)
- `guardrail-validator` (D16, ported)
- `sdk-constraint-devil` (D17)
- `sdk-marker-hygiene-devil` (D18)

D1 (`sdk-skill-devil`) and D2 (`sdk-agent-devil`) REMOVED with Phase -1.

### Mode B/C helpers (new)
- `sdk-existing-api-analyzer`
- `sdk-breaking-change-devil`
- `sdk-marker-scanner`
- `sdk-merge-planner`

## Review-only guarantee

Every agent whose name contains `devil`, `critic`, `reviewer`, or `validator` is READ-ONLY on source code. They write only to `runs/<run-id>/<phase>/reviews/`.

## MCP Integration

MCPs listed in the **MCPs used** column are enhancements, not correctness dependencies. All agents fall back to JSONL / Grep / text-based paths on MCP unavailability (WARN-only; pipeline never halts). See `CLAUDE.md` rule 31 for the policy, `docs/MCP-INTEGRATION-PROPOSAL.md` for scope + rollout, and `.claude/skills/mcp-knowledge-graph/SKILL.md` for the canonical read/write + fallback pattern.
