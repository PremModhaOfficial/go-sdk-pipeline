# Agent Roster

This file is the single source of truth for every agent in this pipeline. Canonical per-agent prompt files live in `.claude/agents/<name>.md`.

## Ownership Matrix

| Domain | Owner agent | Consulted |
|---|---|---|
| TPRD canonicalization + manifest validation | `sdk-intake-agent` | — |
| New skill authorship | **human only** (PR merge) | — |
| Existing skill body patches | `learning-engine` (Phase 4) | `sdk-golden-regression-runner`, `baseline-manager` |
| Extension pre-design snapshot | `sdk-existing-api-analyzer` | — |
| Target-SDK marker ownership map | `sdk-marker-scanner` | — |
| API design | `sdk-design-lead` | `pattern-advisor`, `sdk-designer` |
| Interface signatures | `interface-designer` | `sdk-designer` |
| Retry/backoff/CB algorithms | `algorithm-designer` | `sdk-designer` |
| Concurrency patterns | `concurrency-designer` | — |
| Dependency vetting | `sdk-dep-vet-devil` | — |
| Semver verdict | `sdk-semver-devil` | `sdk-breaking-change-devil` (Mode B/C) |
| Target SDK convention conformance | `sdk-convention-devil` | — |
| Security review | `sdk-security-devil` | — |
| Code generation in target | `sdk-impl-lead` | `sdk-implementor`, `code-generator` |
| Merge planning (marker-aware) | `sdk-merge-planner` | `sdk-marker-scanner` |
| Marker hygiene | `sdk-marker-hygiene-devil` | — |
| Constraint proof execution | `sdk-constraint-devil` | — |
| Leak hunt | `sdk-leak-hunter` | — |
| API ergonomics (consumer POV) | `sdk-api-ergonomics-devil` | — |
| Refactoring | `refactoring-agent` | — |
| Documentation | `documentation-agent` | — |
| Testing lead | `sdk-testing-lead` | `unit-test-agent`, `integration-test-agent`, `performance-test-agent` |
| Benchmark regression verdict | `sdk-benchmark-devil` | `baseline-manager` |
| Integration flake hunt | `sdk-integration-flake-hunter` | — |
| Metrics collection | `metrics-collector` | — |
| Phase retrospective | `phase-retrospector` | — |
| Root-cause trace | `root-cause-tracer` | — |
| Improvement planning | `improvement-planner` | — |
| Learning + patch application | `learning-engine` | `baseline-manager` |
| Skill drift detection | `sdk-skill-drift-detector` | — |
| Skill coverage reporting | `sdk-skill-coverage-reporter` | — |
| Golden-corpus regression | `sdk-golden-regression-runner` | — |
| Mechanical guardrail checks | `guardrail-validator` | — |

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
