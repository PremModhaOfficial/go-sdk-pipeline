---
name: spec-driven-development
description: Story-to-impl mapping, story-level TDD, feature-level validation, dependency graph. Re-scoped for SDK as TPRD-to-symbol mapping — every TPRD §7 API symbol gets (impl, test, godoc, bench, Example_*, [traces-to] marker). Ported with SDK delta.
version: 1.0.0
created-in-run: bootstrap-seed
status: stable
tags: [meta, spec, tprd, traceability, symbol-coverage]
---

# spec-driven-development (SDK-mode)


## SDK-pipeline re-scope

- **"Story" -> TPRD functional requirement (FR-n)**
- **"Acceptance criteria" -> TPRD §4 FR body + §11 testing notes**
- **Symbol-traceability (CLAUDE.md Rule 16)**: every symbol in TPRD §7 (Config+API sketch) MUST gain, by end of Phase 2:
  - impl with godoc starting with symbol name
  - at least one table-driven test in same package `_test.go`
  - `Example_*` function if symbol is part of public API surface
  - benchmark if symbol is on a hot path (flagged in TPRD §5 non-functional requirements)
  - `// [traces-to: TPRD-<section>-<fr-id>]` marker directly above declaration
- **Feature-level validation** replaces "story" granularity: a feature = one TPRD; run is green only when every FR has complete symbol coverage AND Phase 4's `sdk-skill-coverage-reporter` reports `skill_coverage_pct >= 0.9`.
- **Dependency graph**: SDK pipeline is single-package per run, so cross-service story contracts collapse to intra-package symbol ordering (constructors before methods, types before embeddings). Downstream consumers of the new SDK package are NOT in scope.

## When to Activate
- `sdk-intake-agent` during Phase 0 — extract FRs from NL input
- `sdk-design-lead` during Phase 1 — map FRs to symbols in `api.go.stub`
- `sdk-impl-lead` during Phase 2 — verify every symbol has TDD red-green-refactor evidence
- `metrics-collector` during Phase 4 — compute symbol-coverage metric

---

## Archive canonical body (ported verbatim from motadata-ai-pipeline-ARCHIVE @ b2453098)


# Spec-Driven Development Patterns

## Philosophy

Spec-driven development treats each **user story as the unit of implementation**. Instead of implementing an entire service at once, you implement one story at a time, building the service incrementally. Each story's acceptance criteria and test scenarios ARE the specification that drives the TDD cycle.

## The Story-Level TDD Cycle

```
For each story (ordered by dependency):
  1. SPEC    → story-spec-extractor reads the story, outputs implementation spec
  2. RED     → test-spec-generator writes failing tests from story AC + test scenarios
  3. GREEN   → code-generator implements minimum code to pass story tests
  4. VERIFY  → implementation-lead runs go test
  5. GUARD   → feature-guardian checks feature-level behavior when all stories in a feature complete
```

### Contrast with Service-Level TDD

| Aspect | Service-Level (old) | Story-Level (new) |
|--------|-------------------|------------------|
| Unit of work | Entire service (~20 stories) | Single user story |
| Task size | 30+ files, all entities | 2-5 files, one behavior |
| Test scope | All tests at once | Tests for one story's AC |
| Traceability | None to requirements | Story ID in every file |
| Verification | "Does the service work?" | "Does this story pass its AC?" |
| Risk | All-or-nothing | Incremental, story-by-story |

## Story Spec Extraction

The `story-spec-extractor` reads a user story file and produces a structured implementation spec:

### Input: User Story (example: US-FND-01.1.01)
- Acceptance criteria (functional + non-functional)
- Test scenarios (TS-01 through TS-13)
- Field definitions (Email, Password)
- Validation rules (V-01, V-02, V-03)
- State transitions (Unauthenticated → Authenticated)
- Audit events (Sign-in succeeded)
- Edge cases (double-click, browser back, default branding)

### Output: Story Implementation Spec

```json
{
  "story_id": "US-FND-01.1.01",
  "story_title": "Sign in with email and password",
  "target_services": ["identity-service", "api-gateway"],
  "domain_operations": [
    {
      "service": "identity-service",
      "operation": "AuthenticateUser",
      "type": "command",
      "inputs": ["email", "password", "tenant_id"],
      "outputs": ["session_token", "user"],
      "errors": ["ErrInvalidCredentials", "ErrUserDeactivated", "ErrSystemError"],
      "publishes_events": ["identity.auth.signin_succeeded"],
      "validation_rules": [
        {"field": "email", "rules": ["required", "email_format", "max:254", "trim", "lowercase"]},
        {"field": "password", "rules": ["required", "no_trim"]}
      ]
    }
  ],
  "api_endpoints": [
    {
      "service": "api-gateway",
      "method": "POST",
      "path": "/v1/auth/signin",
      "request_fields": ["email", "password"],
      "success_response": {"status": 200, "body": "session + user"},
      "error_responses": [
        {"status": 400, "condition": "empty/invalid fields"},
        {"status": 401, "condition": "invalid credentials"},
        {"status": 403, "condition": "deactivated account"},
        {"status": 500, "condition": "system error"}
      ]
    }
  ],
  "state_transitions": [
    {"from": "unauthenticated", "to": "authenticated", "trigger": "valid credentials + active account"}
  ],
  "audit_events": [
    {"action": "signin_succeeded", "trigger": "session issued", "data": ["actor", "timestamp"]}
  ],
  "test_scenarios": ["TS-01", "TS-02", "TS-03", "TS-04", "TS-05", "TS-06", "TS-07", "TS-08", "TS-09", "TS-10", "TS-11", "TS-12", "TS-13"],
  "dependencies": {
    "requires_stories": [],
    "requires_entities": ["User"],
    "requires_services": ["identity-service"]
  },
  "cross_service_contracts": [
    {
      "from": "api-gateway",
      "to": "identity-service",
      "subject": "tenant.{tenant_id}.identity.auth.request.signin",
      "request_schema": {"email": "string", "password": "string"},
      "response_schema": {"session_token": "string", "user": "User"},
      "reply_subject": "gateway._reply.{correlation_id}"
    }
  ]
}
```

## Story Dependency Graph

The `implementation-planner` computes story ordering by analyzing:

1. **Explicit dependencies** from story files (`Dependencies` section)
2. **Entity dependencies** — a story that reads `User` depends on the story that creates `User`
3. **Feature ordering** from `breakdown.md` (Recommended Build Order)
4. **Cross-service contracts** — if story A in service X sends a message that story B in service Y handles, B depends on A

### Dependency Rules

| Rule | Example |
|------|---------|
| Create before Read | US-FND-02.1.01 (create user) before US-FND-02.1.03 (view user) |
| Seed before Custom | US-FND-03.0.01 (seed roles) before US-FND-03.1.01 (create custom role) |
| Entity before Assignment | US-FND-03.1.01 (create role) before US-FND-02.2.01 (assign role to user) |
| Publisher before Subscriber | US-FND-01.2.01 (request reset) before US-FND-01.2.04 (send email) |

### Output Format

```json
{
  "story_order": [
    {
      "batch": 1,
      "stories": ["US-FND-03.0.01", "US-FND-07.1.01", "US-FND-05.1.01", "US-FND-05.2.01"],
      "rationale": "Bootstrap — no dependencies, different services, parallel"
    },
    {
      "batch": 2,
      "stories": ["US-FND-03.0.02", "US-FND-03.1.01"],
      "rationale": "Depends on seed roles from batch 1"
    }
  ]
}
```

## Cross-Service Story Handling

When a story touches multiple services (e.g., US-FND-01.2.04 "Send password reset email" involves identity-service AND notification-service):

1. **Define contracts FIRST** — before implementation, define the NATS message contract between services
2. **Implement as single task** — one agent processes the story across all affected services
3. **Test the contract** — test that publisher sends correct message AND subscriber handles it correctly
4. **Verify end-to-end** — feature-guardian validates the cross-service flow when the feature completes

### Contract-First Pattern

```markdown
## Cross-Service Contract: US-FND-01.2.04

### Publisher (identity-service)
- Subject: `tenant.{tenant_id}.identity.password.reset_requested`
- Payload: `{ user_id, email, reset_token, tenant_id }`
- Trigger: Password reset token generated

### Subscriber (notification-service)
- Queue Group: `notification-password-reset`
- Handler: `HandlePasswordResetRequested`
- Action: Resolve email template, bind data, send via SMTP
```

## Feature-Level Validation

The `feature-guardian` runs when ALL stories in a feature complete. It validates:

1. **All stories implemented** — every story ID in the feature has passing tests
2. **Feature-level behavior** — the stories work together as a cohesive feature
3. **Business logic completeness** — no gaps between individual story implementations
4. **Cross-story state consistency** — entities modified by multiple stories maintain invariants

### Feature Guardian Checks

```
Feature: FE-FND-01.1 (Sign-In & Session Management)
Stories: US-FND-01.1.01 through US-FND-01.1.07

Checks:
  ✓ Sign-in creates session (01.1.01) AND session is maintained across requests (01.1.04)
  ✓ Invalid credentials rejected (01.1.02) AND deactivated user rejected (01.1.03)
  ✓ Session expires after timeout (01.1.05) AND sign-out invalidates (01.1.06)
  ✓ Force logout terminates sessions (01.1.07) AND session maintenance reflects this
  ✓ All audit events fire in the correct order
  ✓ All domain events published with correct payloads
```

## Story Traceability

Every generated file MUST include a traceability comment:

```go
// Package auth implements authentication handlers.
// [traces-to: US-FND-01.1.01, US-FND-01.1.02, US-FND-01.1.03]
```

Every test file MUST link to the story's test scenarios:

```go
// TestSignIn_ValidCredentials tests TS-01 from US-FND-01.1.01.
// [traces-to: US-FND-01.1.01/TS-01]
func TestSignIn_ValidCredentials(t *testing.T) { ... }
```

## Incremental Service Building

Services grow story-by-story. The service scaffold provides the skeleton, then each story adds:

| Story | Adds to Service |
|-------|----------------|
| US-FND-02.1.01 (Create user) | `CreateUser` command, `User` domain model, `UserRepository.Create`, NATS handler |
| US-FND-02.1.02 (Unique email) | `UserRepository.GetByEmail`, duplicate check in `CreateUser` |
| US-FND-02.1.03 (View user) | `GetUser` query, `UserRepository.GetByID` |
| US-FND-02.1.04 (Edit user) | `UpdateUser` command, `UserRepository.Update` |
| US-FND-02.1.05 (Deactivate) | `DeactivateUser` command, status field, `UserRepository.Update` |

Each story builds on the previous. The scaffold ensures everything compiles, and each story adds real behavior incrementally.

## Story Completeness Check

After ALL stories for a service are implemented, run an explicit completeness check:

```
For service X:
  1. List all stories mapped to this service
  2. For each story:
     a. Verify test file exists with story traceability comment
     b. Verify all acceptance criteria have corresponding test assertions
     c. Verify all test scenarios (TS-XX) have test functions
     d. Run tests: go test ./services/X/... -run "StoryID"
  3. Verify all domain events declared in stories are published
  4. Verify all audit events declared in stories are emitted
  5. Verify all validation rules from stories are enforced
```
