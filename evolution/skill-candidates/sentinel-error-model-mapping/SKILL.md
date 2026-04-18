---
name: sentinel-error-model-mapping
version: 0.1.0-draft
status: candidate
priority: SHOULD
tags: [errors, redis, dragonfly, sentinels, fuzz]
target_consumers: [sdk-impl-lead, sdk-design-lead]
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §7)
specializes: network-error-classification, go-error-handling-patterns
---

# sentinel-error-model-mapping

## When to apply
Any SDK that adopts a **sentinel-only** error model with a single `mapErr(err) error` switch converting driver/server errors into package sentinels. Specializes `network-error-classification`.

## Design invariants (TPRD §7)

1. **All exported errors are sentinels.** No custom types with fields. Callers use `errors.Is`, never type-assertion.
2. **Wrap shape is fixed:** `fmt.Errorf("%w: %v", Sentinel, cause)`. Sentinel is %w (unwrappable); cause is %v (context only). Never double-%w.
3. **Single switch.** One `mapErr` per package. No per-method error wrapping.
4. **Pass-through for caller-origin errors.** `context.Canceled` passes through as-is (no wrap). `context.DeadlineExceeded` is wrapped as `ErrTimeout`.

## Mapping table (Dragonfly)

| Input | Output sentinel |
|---|---|
| nil | nil |
| `redis.ErrClosed` | `ErrNotConnected` (no wrap — bare sentinel) |
| `context.Canceled` | passthrough (bare) |
| `context.DeadlineExceeded` | `ErrTimeout` (wrapped) |
| `net.Error` with `Timeout()==true` | `ErrTimeout` (wrapped) |
| `redis.Nil` | `ErrNil` (wrapped — allows errors.Is + retains cause) |
| `redis.TxFailedErr` | `ErrTxnAborted` (wrapped) |
| server string prefix `MOVED ` | `ErrMoved` |
| server string prefix `ASK ` | `ErrAsk` |
| server string `CLUSTERDOWN` | `ErrClusterDown` |
| server string `LOADING` | `ErrLoading` |
| server string `READONLY` | `ErrReadOnly` |
| server string `MASTERDOWN` | `ErrMasterDown` |
| server string `WRONGPASS` or `NOAUTH` | `ErrAuth` |
| server string `NOPERM` | `ErrNoPerm` |
| server string `WRONGTYPE` | `ErrWrongType` |
| server string contains ` out of range` | `ErrOutOfRange` |
| server string starts `ERR syntax` | `ErrSyntax` |
| server string `NOSCRIPT` | `ErrScriptNotFound` |
| server string `BUSY` (script) | `ErrBusyScript` |
| pool: `redis: connection pool timeout` | `ErrPoolExhausted` |
| pool: closed | `ErrPoolClosed` |
| everything else | `ErrUnavailable` (wrapped — catch-all) |

## Prefix-matching helpers

```go
func hasPrefix(err error, p string) bool { return err != nil && strings.HasPrefix(err.Error(), p) }
func contains(err error, s string) bool  { return err != nil && strings.Contains(err.Error(), s) }
```

Prefix match order matters: check NOAUTH **before** generic ERR; WRONGPASS before WRONGTYPE (lexical prefix collisions possible on misread — order defensively).

## Error-class metric label

`error_class ∈ {timeout, unavailable, nil, wrong_type, auth, other}` — bounded set. Map sentinel → class:

| Sentinel | class |
|---|---|
| `ErrTimeout` | `timeout` |
| `ErrNotConnected`, `ErrUnavailable`, `ErrPoolExhausted`, `ErrPoolClosed`, `ErrClusterDown`, `ErrLoading`, `ErrMasterDown` | `unavailable` |
| `ErrNil` | `nil` |
| `ErrWrongType` | `wrong_type` |
| `ErrAuth`, `ErrNoPerm`, `ErrTLS` | `auth` |
| everything else (`ErrMoved`, `ErrAsk`, `ErrReadOnly`, `ErrTxnAborted`, `ErrScriptNotFound`, `ErrBusyScript`, `ErrSyntax`, `ErrOutOfRange`, `ErrRESP3Required`, `ErrSubscriberClosed`, `ErrCircuitOpen`) | `other` |

Cardinality: 6. Safe.

## Fuzz contract (TPRD §11.4)

```go
func FuzzMapErr(f *testing.F) {
    seeds := []string{"", "MOVED 1234 1.2.3.4:6379", "WRONGTYPE Operation...",
        "NOAUTH Authentication required", "NOSCRIPT No matching script",
        "BUSY Redis is busy", "ERR syntax error", "LOADING Redis is loading",
        "READONLY You can't write", "NOPERM this user has no ...",
        "redis: connection pool timeout", "CLUSTERDOWN ..."}
    for _, s := range seeds { f.Add(s) }
    f.Fuzz(func(t *testing.T, s string) {
        mapped := mapErr(errors.New(s))
        if mapped == nil && s != "" {
            t.Errorf("non-empty input produced nil output: %q", s)
        }
        // All mapped outputs must Is() one of the 20 sentinels or be the input.
    })
}
```

Property: no input (except empty) yields nil; every non-nil mapping unwraps to a known sentinel via `errors.Is`.

## Anti-patterns

- Custom error types with unexported fields — forces type-assertion, breaks sentinel contract.
- `fmt.Errorf("prefix: %w", Sentinel)` without %v cause — loses context.
- Multi-sentinel wrap: `fmt.Errorf("%w %w", A, B)` — go 1.20 allows, but violates "one sentinel per error" invariant.
- Returning raw server strings to caller without mapping — caller-visible coupling to Redis wire format.
- Re-classifying `context.Canceled` as `ErrCanceled` sentinel (TPRD §7 lists it but `mapErr` should passthrough; sentinel exists for forward compat but is unreachable from mapErr path today — flag in code comment).

## References
TPRD §7 (full sentinel catalog), §8.2 (error_class bounded dims), §11.4 (fuzz).
Existing skills: `network-error-classification`, `go-error-handling-patterns`.
