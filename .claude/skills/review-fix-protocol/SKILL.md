---
name: review-fix-protocol
description: Standardized review-fix resolution loop — per-issue retry cap 5, stuck detection 2, dedup, findings schema, guardrail re-run, convergence criteria.
version: 1.0.0
created-in-run: bootstrap-seed
status: stable
tags: [meta, review, findings, retry, convergence]
---



# Review-Fix Resolution Protocol

## Overview

Every pipeline phase follows the same review-fix resolution loop after review agents produce findings. The loop tracks each issue individually (max 5 retries per issue), routes fixes to the correct agent, deduplicates across reviewers, and detects when the loop is stuck.

## Structured Findings JSON Schema

Every review agent MUST produce a `.findings.json` file alongside their markdown report. This is the machine-readable input for the resolution loop.

### Findings File Schema

```json
{
  "reviewer": "<agent-name>",
  "phase": "<phase-name>",
  "run_id": "<uuid>",
  "iteration": 1,
  "timestamp": "<ISO-8601>",
  "findings": [
    {
      "id": "<PHASE-PREFIX>-<NNN>",
      "severity": "blocker|high|medium|low",
      "category": "<category>",
      "title": "<short description>",
      "description": "<detailed explanation>",
      "file": "<file-path>",
      "line": "<line-number or null>",
      "fix_agent": "<agent-name that should fix this>",
      "fix_action": "<specific action to take>",
      "story_id": "<US-XXX if traceable, else null>"
    }
  ],
  "summary": {
    "total": 0,
    "blocker": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  }
}
```

### Finding ID Prefixes by Phase

| Phase | Prefix | Example |
|-------|--------|---------|
| Architecture | `AR` | `AR-001` |
| Detailed Design | `DD` | `DD-001` |
| Implementation | `IM` | `IM-001` |
| Testing | `TS` | `TS-001` |
| Frontend | `FE` | `FE-001` |

### Severity Definitions

| Severity | Definition | Resolution Requirement |
|----------|-----------|----------------------|
| `blocker` | Prevents the phase from being signed off | MUST fix — blocks report approval |
| `high` | Significant quality issue | SHOULD fix — degrades quality if left |
| `medium` | Improvement opportunity | FIX if possible within iteration budget |
| `low` | Minor suggestion | FIX only if trivial, else log as accepted |

## Resolution Loop Algorithm

```
FUNCTION ResolutionLoop(phase, review_findings_dir, fix_agents_map):

  // Step 1: Initialize issue tracker
  issue_tracker = {}  // keyed by finding ID
  iteration = 0
  global_max_iterations = 10  // safety cap for the loop itself
  per_issue_max_retries = 5
  stuck_threshold = 2  // consecutive non-improving iterations

  // Step 2: Parse initial findings
  all_findings = ParseAllFindingsJSON(review_findings_dir)
  all_findings = Deduplicate(all_findings)

  FOR each finding IN all_findings:
    issue_tracker[finding.id] = {
      finding: finding,
      retry_count: 0,
      status: "open",  // open | fixed | ignored
      history: []
    }

  // Step 3: Main loop
  previous_open_count = len(all_findings)
  consecutive_no_progress = 0

  WHILE iteration < global_max_iterations:
    iteration++

    // 3a: Check exit — all resolved?
    open_issues = [i FOR i IN issue_tracker.values() IF i.status == "open"]
    IF len(open_issues) == 0:
      RETURN "ALL_CLEAR"

    // 3b: Filter issues that have NOT exhausted retries
    fixable_issues = []
    FOR each issue IN open_issues:
      IF issue.retry_count >= per_issue_max_retries:
        issue.status = "ignored"
        issue.history.append({
          iteration: iteration,
          action: "ignored_after_max_retries",
          reason: "Same issue persisted after 5 fix attempts"
        })
        LOG decision: "Ignoring {issue.id} after {per_issue_max_retries} retries"
      ELSE:
        fixable_issues.append(issue)

    // 3c: Re-check exit after ignoring exhausted issues
    IF len(fixable_issues) == 0:
      RETURN "CONVERGED_WITH_IGNORED"

    // 3d: Stuck detection
    current_open_count = len(fixable_issues)
    IF current_open_count >= previous_open_count:
      consecutive_no_progress++
    ELSE:
      consecutive_no_progress = 0

    IF consecutive_no_progress >= stuck_threshold:
      LOG decision: "Stuck detection: findings not decreasing for {stuck_threshold} iterations"
      FOR each issue IN fixable_issues:
        issue.status = "ignored"
        issue.history.append({action: "stuck_detected"})
      RETURN "STUCK"

    previous_open_count = current_open_count

    // 3e: Route to fix agents
    fix_groups = GroupByFixAgent(fixable_issues)
    FOR each (agent, issues) IN fix_groups:
      SpawnFixAgent(agent, issues, iteration)
      FOR each issue IN issues:
        issue.retry_count++
        issue.history.append({
          iteration: iteration,
          action: "fix_assigned",
          agent: agent
        })

    // 3f: Wait for fixes, re-run guardrails
    WaitForAllFixAgents()
    RunGuardrails()

    // 3g: Re-run review agents
    new_findings = ReRunReviewAgents()
    new_findings = Deduplicate(new_findings)

    // 3h: Reconcile — match new findings to existing issues
    FOR each old_issue IN issue_tracker.values():
      IF old_issue.status == "open":
        matching_new = FindMatch(old_issue.finding, new_findings)
        IF matching_new IS NULL:
          old_issue.status = "fixed"
          old_issue.history.append({iteration: iteration, action: "resolved"})
        ELSE:
          old_issue.finding = matching_new  // update with latest details
          old_issue.history.append({iteration: iteration, action: "still_open"})
          REMOVE matching_new FROM new_findings

    // 3i: Add genuinely new findings
    FOR each new_finding IN remaining new_findings:
      issue_tracker[new_finding.id] = {
        finding: new_finding,
        retry_count: 0,
        status: "open",
        history: [{iteration: iteration, action: "new_finding"}]
      }

  RETURN "MAX_ITERATIONS_REACHED"
```

## Deduplication Logic

Multiple reviewers may flag the same issue. Before routing to fix agents:

1. **Group findings by `file` + approximate `title` match** (case-insensitive, ignoring articles)
2. **If two findings target the same file and describe the same issue**:
   - Keep the one with **HIGHER severity**
   - Discard the duplicate
   - Log: `"Deduplicated: {id-kept} supersedes {id-discarded}"`
3. **Cross-reviewer deduplication**: If `frontend-code-reviewer` flags "Missing error boundary" and `simulated-frontend-lead` flags "Add Error Boundary" for the same file, keep the higher severity one

## Fix Agent Routing

Each finding's `fix_agent` field determines who fixes it. The phase lead spawns fix agents with this exact format:

```
RESOLUTION FIX — Iteration {N}

You are being called to fix specific review findings. Do NOT run your normal generation flow.

FINDINGS TO FIX:
1. {id} ({severity}): {title}
   File: {file}:{line}
   Description: {description}
   Action: {fix_action}
   Retry: {retry_count}/{per_issue_max_retries}

RULES:
- Read ONLY the files listed above
- Fix ONLY the issues described
- Do NOT regenerate files from scratch
- Do NOT modify unrelated code
- Verify fix compiles/passes
- Log a "type":"refactor" entry per finding to the decision log
```

## Fix Agent Mapping by Phase

### Architecture Phase
| Category | Fix Agent |
|----------|----------|
| Service boundary issues | system-decomposer |
| API contract issues | api-designer |
| Database schema issues | database-architect |
| Infrastructure issues | infrastructure-architect |
| Design pattern issues | pattern-advisor |

### Detailed Design Phase
| Category | Fix Agent |
|----------|----------|
| Component/interface design | component-designer |
| DTO/validation issues | interface-designer |
| Data model issues | data-model-designer |
| Algorithm issues | algorithm-designer |
| Concurrency issues | concurrency-designer |
| SDK design issues | sdk-designer |
| Coding guidelines | coding-guidelines-generator |

### Implementation Phase
| Category | Fix Agent |
|----------|----------|
| Service code issues | code-generator |
| SDK package issues | sdk-implementor |
| Migration issues | migration-generator |
| Build/config issues | build-config-generator |
| Deployment issues | deployment-generator |
| Documentation issues | documentation-agent |

### Testing Phase
| Category | Fix Agent |
|----------|----------|
| Unit test issues | unit-test-agent |
| Integration test issues | integration-test-agent |
| Contract test issues | contract-test-agent |
| E2E test issues | e2e-test-agent |
| Performance test issues | performance-test-agent |
| Security test issues | security-test-agent |
| Test data issues | test-data-agent |

### Frontend Phase
| Category | Fix Agent |
|----------|----------|
| Component issues | component-generator |
| Page issues | page-generator |
| Form issues | form-generator |
| i18n issues | i18n-generator |
| State/DuckDB issues | state-architect |
| API hook issues | api-hook-generator |
| Config/build issues | frontend-build-config |
| WebSocket issues | websocket-handler |

## Manifest Tracking Schema

Every phase lead tracks the resolution loop in the run manifest:

```json
{
  "resolution_loop": {
    "status": "pending|in-progress|completed|stuck|converged_with_ignored",
    "current_iteration": 0,
    "max_global_iterations": 10,
    "per_issue_max_retries": 5,
    "stuck_threshold": 2,
    "issue_tracker": {
      "<finding-id>": {
        "severity": "blocker",
        "title": "...",
        "fix_agent": "...",
        "retry_count": 0,
        "status": "open|fixed|ignored",
        "ignored_reason": null
      }
    },
    "history": [
      {
        "iteration": 1,
        "open": 15,
        "fixed": 0,
        "ignored": 0,
        "new": 0
      }
    ],
    "final_summary": {
      "total_found": 0,
      "resolved": 0,
      "ignored_after_max_retries": 0,
      "ignored_stuck": 0,
      "open": 0
    }
  }
}
```

## Convergence Criteria

The loop terminates when ANY of these conditions is met:

| Condition | Status | Report Impact |
|-----------|--------|--------------|
| All findings resolved | `completed` | APPROVE |
| All remaining are `ignored` (max retries) | `converged_with_ignored` | APPROVE_WITH_CAVEATS (list ignored) |
| Stuck for 2 consecutive iterations | `stuck` | NOT_READY (if blockers remain) |
| Global iteration cap (10) reached | `max_iterations_reached` | NOT_READY |

## Report Integration

Every phase's final report MUST include a **Resolution Loop Summary** section:

```markdown
## Resolution Loop Summary

| Metric | Value |
|--------|-------|
| Total findings | 23 |
| Resolved | 20 |
| Ignored (max retries) | 2 |
| Ignored (stuck) | 1 |
| Iterations | 4 |
| Status | CONVERGED_WITH_IGNORED |

### Ignored Issues (accepted risk)
1. AR-007 (medium): "Missing retry logic in NATS publisher" — 5 fix attempts, pattern-advisor unable to resolve
2. AR-015 (low): "Cost estimate missing for Redis cluster" — stuck after 3 iterations

### Resolution History
| Iteration | Open | Fixed | Ignored | New |
|-----------|------|-------|---------|-----|
| 1 | 23 | 0 | 0 | 0 |
| 2 | 15 | 8 | 0 | 0 |
| 3 | 9 | 6 | 0 | 0 |
| 4 | 3 | 5 | 2 | 1 |
```

## Review Agent Requirements

For this protocol to work, ALL review agents across ALL phases MUST:

1. Produce a `.findings.json` alongside their markdown report
2. Include `fix_agent` field on every finding
3. Include `severity` field on every finding
4. Use the standard finding ID prefix for their phase
5. On re-run iterations, compare with previous findings to identify resolved vs. new
