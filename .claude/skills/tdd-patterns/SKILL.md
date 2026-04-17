---
name: tdd-patterns
description: Go TDD skeleton→failing-test→impl→verify cycle, interface-driven test design, mock-based TDD, RED/GREEN/REFACTOR. Ported verbatim.
version: 1.0.0
created-in-run: bootstrap-seed
status: stable
source-pattern: ported-from-archive@b2453098:.claude/skills/tdd-patterns/SKILL.md
tags: [go, testing, tdd, red-green-refactor]
---

<!-- ported-from: motadata-ai-pipeline-ARCHIVE/.claude/skills/tdd-patterns/SKILL.md @ b2453098 -->


# Go TDD Patterns for Multi-Agent Implementation

## The TDD Cycle in the Agent System

### Overview
The agent system implements TDD through a three-agent cycle per service:
1. **code-generator (SKELETON)** → writes compilable stubs
2. **test-spec-generator (RED)** → writes failing tests against stubs
3. **code-generator (GREEN)** → fills real implementations to pass tests

### Phase 1: Skeleton Generation (code-generator)

The skeleton provides compilable but non-functional code that tests can import.

#### Interface Skeleton
```go
// internal/ports/repository.go
package ports

import (
    "context"
    "github.com/motadata/platform/services/identity-service/internal/domain"
)

// UserRepository defines persistence operations for User entities.
type UserRepository interface {
    Create(ctx context.Context, user *domain.User) (*domain.User, error)
    GetByID(ctx context.Context, id string) (*domain.User, error)
    GetByEmail(ctx context.Context, email string) (*domain.User, error)
    Update(ctx context.Context, user *domain.User) (*domain.User, error)
    Delete(ctx context.Context, id string) error
    List(ctx context.Context, opts ListOptions) ([]*domain.User, string, error)
}
```

#### Stub Implementation
```go
// internal/application/service.go
package application

import (
    "context"
    "errors"
    "github.com/motadata/platform/services/identity-service/internal/domain"
)

var errNotImplemented = errors.New("not implemented")

// UserService handles user business logic.
type UserService struct {
    repo      ports.UserRepository
    publisher ports.EventPublisher
}

// NewUserService creates a new UserService with injected dependencies.
func NewUserService(repo ports.UserRepository, pub ports.EventPublisher) *UserService {
    return &UserService{repo: repo, publisher: pub}
}

// CreateUser creates a new user. STUB — returns not-implemented error.
func (s *UserService) CreateUser(ctx context.Context, cmd CreateUserCommand) (*domain.User, error) {
    return nil, errNotImplemented
}

// GetUser retrieves a user by ID. STUB — returns not-implemented error.
func (s *UserService) GetUser(ctx context.Context, id string) (*domain.User, error) {
    return nil, errNotImplemented
}
```

Key skeleton rules:
- All interfaces fully defined (every method signature)
- All structs have correct fields and tags
- Constructors return real instances
- Method stubs return `nil, errNotImplemented` or zero values
- Package structure matches the detailed design exactly

### Phase 2: Failing Test Specification (test-spec-generator)

Tests define WHAT the implementation must do. They are the specification.

#### Assertion-First Pattern
Write the assertion first, then work backwards to the setup:

```go
func TestCreateUser_ValidInput_ReturnsUserWithGeneratedID(t *testing.T) {
    // START with what you want to assert:
    // - No error
    // - User is not nil
    // - User has a generated UUID
    // - User has the input email
    // - User has a CreatedAt timestamp
    // - Event was published

    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockRepo := mocks.NewMockUserRepository(ctrl)
    mockRepo.EXPECT().
        Create(gomock.Any(), gomock.Any()).
        DoAndReturn(func(ctx context.Context, u *domain.User) (*domain.User, error) {
            // Verify the user passed to repo has expected shape
            assert.NotEmpty(t, u.ID, "user should have generated ID before persistence")
            assert.Equal(t, "test@example.com", u.Email)
            return u, nil
        })

    mockPub := mocks.NewMockEventPublisher(ctrl)
    mockPub.EXPECT().
        Publish(gomock.Any(), gomock.Any()).
        DoAndReturn(func(ctx context.Context, event interface{}) error {
            e, ok := event.(*domain.UserCreatedEvent)
            require.True(t, ok, "event should be UserCreatedEvent")
            assert.NotEmpty(t, e.UserID)
            return nil
        })

    svc := application.NewUserService(mockRepo, mockPub)

    user, err := svc.CreateUser(context.Background(), application.CreateUserCommand{
        Email:    "test@example.com",
        TenantID: "tenant-1",
    })

    require.NoError(t, err)
    require.NotNil(t, user)
    assert.NotEmpty(t, user.ID)
    assert.Equal(t, "test@example.com", user.Email)
    assert.Equal(t, "tenant-1", user.TenantID)
    assert.False(t, user.CreatedAt.IsZero())
}
```

#### Table-Driven TDD
For functions with multiple behaviors, define all expected behaviors as test cases:

```go
func TestCreateUser_Validation(t *testing.T) {
    tests := []struct {
        name    string
        cmd     application.CreateUserCommand
        wantErr bool
        errType error // sentinel error to check with errors.Is
    }{
        {
            name:    "empty email returns validation error",
            cmd:     application.CreateUserCommand{Email: "", TenantID: "t1"},
            wantErr: true,
            errType: domain.ErrInvalidEmail,
        },
        {
            name:    "empty tenant returns validation error",
            cmd:     application.CreateUserCommand{Email: "a@b.com", TenantID: ""},
            wantErr: true,
            errType: domain.ErrMissingTenantID,
        },
        {
            name:    "malformed email returns validation error",
            cmd:     application.CreateUserCommand{Email: "not-an-email", TenantID: "t1"},
            wantErr: true,
            errType: domain.ErrInvalidEmail,
        },
        {
            name:    "valid input succeeds",
            cmd:     application.CreateUserCommand{Email: "valid@example.com", TenantID: "t1"},
            wantErr: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()

            mockRepo := mocks.NewMockUserRepository(ctrl)
            if !tt.wantErr {
                mockRepo.EXPECT().Create(gomock.Any(), gomock.Any()).
                    Return(&domain.User{ID: "u1", Email: tt.cmd.Email}, nil)
            }

            mockPub := mocks.NewMockEventPublisher(ctrl)
            if !tt.wantErr {
                mockPub.EXPECT().Publish(gomock.Any(), gomock.Any()).Return(nil)
            }

            svc := application.NewUserService(mockRepo, mockPub)
            _, err := svc.CreateUser(context.Background(), tt.cmd)

            if tt.wantErr {
                require.Error(t, err)
                if tt.errType != nil {
                    assert.True(t, errors.Is(err, tt.errType),
                        "expected %v, got %v", tt.errType, err)
                }
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

#### Domain Constructor TDD
```go
func TestNewUser_SetsDefaults(t *testing.T) {
    user, err := domain.NewUser("test@example.com", "tenant-1")

    require.NoError(t, err)
    assert.NotEmpty(t, user.ID, "should generate UUID")
    assert.Equal(t, "test@example.com", user.Email)
    assert.Equal(t, "tenant-1", user.TenantID)
    assert.Equal(t, domain.UserStatusActive, user.Status)
    assert.False(t, user.CreatedAt.IsZero(), "should set creation time")
}
```

#### Repository Integration TDD (testcontainers)
```go
func TestUserRepository_Create_PersistsAndReturns(t *testing.T) {
    // Arrange: real PostgreSQL via testcontainers
    db := setupTestDB(t) // t.Cleanup handles teardown
    repo := postgres.NewUserRepository(db)

    user := &domain.User{
        ID:       "user-1",
        Email:    "test@example.com",
        TenantID: "tenant-1",
    }

    // Act
    result, err := repo.Create(context.Background(), user)

    // Assert
    require.NoError(t, err)
    assert.Equal(t, "user-1", result.ID)

    // Verify persistence
    found, err := repo.GetByID(context.Background(), "user-1")
    require.NoError(t, err)
    assert.Equal(t, "test@example.com", found.Email)
}

func TestUserRepository_TenantIsolation(t *testing.T) {
    db := setupTestDB(t)
    repo := postgres.NewUserRepository(db)

    // Create user in tenant-1
    _, err := repo.Create(contextWithTenant("tenant-1"), &domain.User{
        ID: "user-1", Email: "a@b.com", TenantID: "tenant-1",
    })
    require.NoError(t, err)

    // Query from tenant-2 context should NOT find it
    _, err = repo.GetByID(contextWithTenant("tenant-2"), "user-1")
    require.Error(t, err)
    assert.True(t, errors.Is(err, domain.ErrNotFound))
}
```

#### NATS Handler TDD
```go
func TestUserCreatedHandler_PublishesEvent(t *testing.T) {
    // Arrange: embedded NATS server
    ns := startEmbeddedNATS(t)
    nc, err := nats.Connect(ns.ClientURL())
    require.NoError(t, err)
    defer nc.Close()

    publisher := natsadapter.NewEventPublisher(nc)

    // Subscribe to expected subject
    received := make(chan *nats.Msg, 1)
    _, err = nc.Subscribe("tenant.t1.identity.user.created", func(msg *nats.Msg) {
        received <- msg
    })
    require.NoError(t, err)

    // Act: publish event
    err = publisher.PublishUserCreated(context.Background(), &domain.UserCreatedEvent{
        UserID:   "user-1",
        TenantID: "t1",
        Email:    "test@example.com",
    })
    require.NoError(t, err)

    // Assert: verify message received with correct envelope
    select {
    case msg := <-received:
        var envelope cloudevents.Event
        err := msgpack.Unmarshal(msg.Data, &envelope)
        require.NoError(t, err)
        assert.Equal(t, "identity.user.created", envelope.Type())
        assert.Equal(t, "t1", envelope.Extensions()["tenantid"])
    case <-time.After(2 * time.Second):
        t.Fatal("timeout waiting for NATS message")
    }
}
```

### Phase 3: Implementation (code-generator GREEN phase)

code-generator reads the failing tests and writes implementation code to make them pass.

Key rules for GREEN phase:
- Read ALL test files first — understand what behavior is expected
- Write the MINIMUM code to make tests pass
- Do not add behavior that isn't tested
- If a test expects a specific error type, use that exact error type
- If a test checks event publishing, ensure the event is published
- Run `go test` after each significant change

### Phase 4: Verification (implementation-lead)

implementation-lead runs:
```bash
cd src && go test ./services/<service-name>/... -v -count=1 -race
```

Expected outcomes:
- **ALL PASS** → GREEN state achieved, proceed to next service
- **SOME FAIL** → code-generator gets failure output, fixes, re-verify (max 2 retries)
- **COMPILATION ERROR** → code-generator fixes compilation, re-verify

### Fix Loop Pattern
When tests fail in verification:

```
Attempt 1:
  input:  test failure output from `go test`
  action: code-generator analyzes failures, fixes implementation
  verify: re-run `go test`

Attempt 2 (if still failing):
  input:  updated test failure output
  action: code-generator makes targeted fixes
  verify: re-run `go test`

After 2 failures:
  action: flag service as BLOCKED in manifest
  note:   record which tests still fail
  continue: move to next service in parallel group
```

## Anti-Patterns to Avoid

### 1. Weak Assertions (Tests Pass Too Early)
```go
// BAD — passes even with stub implementation
func TestCreateUser(t *testing.T) {
    svc := application.NewUserService(nil, nil)
    _, _ = svc.CreateUser(ctx, cmd)
    // no assertions!
}

// GOOD — fails until real implementation exists
func TestCreateUser_ReturnsNonNilUser(t *testing.T) {
    svc := setupService(t)
    user, err := svc.CreateUser(ctx, validCmd)
    require.NoError(t, err)           // fails: stub returns error
    require.NotNil(t, user)            // fails: stub returns nil
    assert.NotEmpty(t, user.ID)        // fails: no ID generated
}
```

### 2. Testing Implementation Details
```go
// BAD — tests HOW, not WHAT
func TestCreateUser_CallsRepoCreate(t *testing.T) {
    mockRepo.EXPECT().Create(gomock.Any(), gomock.Eq(specificUser))
    // testing exact argument match — brittle
}

// GOOD — tests behavior/outcome
func TestCreateUser_PersistsUserWithEmail(t *testing.T) {
    mockRepo.EXPECT().Create(gomock.Any(), gomock.Any()).
        DoAndReturn(func(ctx context.Context, u *domain.User) (*domain.User, error) {
            assert.Equal(t, "test@example.com", u.Email) // verify behavior
            return u, nil
        })
}
```

### 3. Skipping Error Path Tests
```go
// MUST test error paths — they define error handling behavior
func TestCreateUser_RepoFailure_ReturnsInternalError(t *testing.T) {
    mockRepo.EXPECT().Create(gomock.Any(), gomock.Any()).
        Return(nil, errors.New("connection refused"))

    _, err := svc.CreateUser(ctx, validCmd)

    require.Error(t, err)
    var appErr *apperrors.AppError
    require.True(t, errors.As(err, &appErr))
    assert.Equal(t, apperrors.Internal, appErr.Code)
}
```

## Coverage Strategy for TDD

### What MUST Be Tested in RED Phase
- Every public method on application services (happy path + error paths)
- Every domain constructor and validation method
- Every domain event creation
- Tenant isolation in repository operations
- NATS message publishing on state changes
- HTTP request validation (API Gateway only)

### What Can Be Deferred to Later Testing Agents
- Edge cases with complex setup (deferred to unit-test-agent)
- Cross-service integration flows (deferred to integration-test-agent)
- Performance characteristics (deferred to performance-test-agent)
- Security-specific scenarios (deferred to security-test-agent)

### Target: 60-70% Coverage in RED Phase
TDD tests should cover the primary behavior specification. The remaining 15-25% to reach 85% target is filled by unit-test-agent in the cross-cutting testing phase.
