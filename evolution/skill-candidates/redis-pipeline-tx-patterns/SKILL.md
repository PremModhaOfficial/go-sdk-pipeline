---
name: redis-pipeline-tx-patterns
version: 0.1.0-draft
status: candidate
priority: MUST
tags: [redis, dragonfly, pipeline, transaction, watch, resilience]
target_consumers: [sdk-design-lead, sdk-impl-lead, sdk-testing-lead]
scope: go
scope_rationale: Pipelining + WATCH/MULTI/EXEC contract is itself language-neutral, but body shows go-redis pipeline.Exec / TxPipelined signatures. Promote to shared-core only after a Python sibling rewrite proves the rule body is language-neutral.
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §5.4, §7, §11)
---

# redis-pipeline-tx-patterns

## When to apply
Any SDK client that wraps `github.com/redis/go-redis/v9` and exposes `Pipeline()`, `TxPipeline()`, or `Watch()`.

## Core prescriptions

### 1. Expose, don't wrap
Return `redis.Pipeliner` directly. Do NOT introduce a parallel interface. Callers get full command surface without SDK churn when Dragonfly adds commands.

```go
func (c *Cache) Pipeline() redis.Pipeliner   { return c.rdb.Pipeline() }
func (c *Cache) TxPipeline() redis.Pipeliner { return c.rdb.TxPipeline() }
```

Do NOT span-wrap individual pipelined commands — the pipeline Exec is the unit of work. One span `dfly.pipeline.exec` with attribute `cmd_count` is sufficient. Individual-cmd spans blow OTel cardinality under batching.

### 2. Watch contract (optimistic lock)
`Watch(ctx, fn, keys...)` runs `fn` in a retry loop owned by the caller. Pipeline MUST NOT internally retry — TPRD §3 fixes `MaxRetries=0`.

Mapping:
- `redis.TxFailedErr` → `ErrTxnAborted` (a WATCHed key changed mid-txn).
- Do not swallow `ErrTxnAborted`; caller decides retry policy (likely upstream CB+retry).
- Inside `fn`, only read-then-queue writes via `*redis.Tx`. Issuing a non-queued write inside `fn` bypasses atomicity.

### 3. Error mapping in pipeline Exec
`pipe.Exec(ctx)` returns `[]redis.Cmder, error`. Two error surfaces:
- The top-level error (map via `mapErr`).
- Per-command `cmd.Err()` — caller iterates; `redis.Nil` is per-op miss, not a pipeline failure.

Rule: pipeline-level metrics count once (`l2cache.pipeline.requests`, `.errors{class}`, `.duration_ms`, `.cmd_count`). Per-cmd error classification is the CALLER's responsibility.

### 4. Sizing and allocation
No cap by design (TPRD §14 risk accepted). Document `USAGE.md` guidance: keep batches ≤1000 commands or ≤1 MiB payload; larger is legal but OOM risk is caller's.

Bench contract for S4: `BenchmarkPipeline_100` must report ≤3 allocs per cmd in batch (amortized).

### 5. Goroutine safety
`redis.Pipeliner` is NOT safe for concurrent use by multiple goroutines. Doc this explicitly. Callers needing fan-in must use `sync.Mutex` or one pipeline per goroutine + `Cache.Pipeline()` is cheap (no I/O).

### 6. Test matrix (S4 required)
- happy path: Set+Get batched, verify order preserved.
- mixed error: one cmd miss (`redis.Nil`) alongside success — verify per-cmd surface.
- WATCH fires: concurrent mutator changes key between WATCH and EXEC → `ErrTxnAborted`.
- ctx cancel mid-batch: first-batch succeeds, post-cancel returns `context.Canceled`.
- miniredis limitation: WATCH support is partial — integration test in S7 confirms under real Dragonfly.

## Anti-patterns
- Wrapping `Pipeliner` behind a custom interface "for testability" — test the caller with a `*miniredis.Miniredis` instead.
- Internal retry on `TxFailedErr` — violates MaxRetries=0 invariant.
- Per-cmd OTel spans — cardinality explosion.
- Returning bare `error` from Watch-fn without sentinel wrapping on EXEC-nil.

## References
- TPRD §5.4, §7 (ErrTxnAborted), §11 (test strategy), §14 (risks).
- go-redis v9 docs: `Pipeliner`, `Tx`, `TxFailedErr`.
