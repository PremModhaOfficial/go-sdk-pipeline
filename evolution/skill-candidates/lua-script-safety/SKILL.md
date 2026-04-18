---
name: lua-script-safety
version: 0.1.0-draft
status: candidate
priority: MUST
tags: [redis, dragonfly, lua, scripting, eval, evalsha]
target_consumers: [sdk-impl-lead, sdk-design-lead]
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §5.6, §7)
---

# lua-script-safety

## When to apply
Any SDK method exposing EVAL / EVALSHA / SCRIPTLOAD / SCRIPTEXISTS.

## Core prescriptions

### 1. EVALSHA-first with NOSCRIPT fallback is CALLER's responsibility
TPRD §3 explicitly declines to maintain an SDK-side SCRIPTLOAD cache. The SDK exposes:

```go
func (c *Cache) Eval(ctx, script string, keys []string, args ...any) (any, error)
func (c *Cache) EvalSha(ctx, sha string, keys []string, args ...any) (any, error)
func (c *Cache) ScriptLoad(ctx, script string) (string, error)
func (c *Cache) ScriptExists(ctx, shas ...string) ([]bool, error)
```

SDK does not auto-retry EVALSHA with EVAL on NOSCRIPT. Document the recommended pattern in USAGE.md:

```go
res, err := c.EvalSha(ctx, sha, keys, args...)
if errors.Is(err, dragonfly.ErrScriptNotFound) {
    if _, lerr := c.ScriptLoad(ctx, script); lerr != nil { return nil, lerr }
    res, err = c.EvalSha(ctx, sha, keys, args...)
}
```

### 2. Error mapping
- Server `NOSCRIPT` prefix → `ErrScriptNotFound`.
- Server `BUSY` prefix (script timeout) → `ErrBusyScript`.
- Other script errors (compile failure) → default `ErrUnavailable` wrap.

### 3. Metrics cardinality
Label `script_id` is permitted ONLY if it's a caller-declared constant at compile time. Do NOT derive label from SHA (cardinality blows with every caller SCRIPTLOAD). Safer default: no script label on script metrics; just `cmd="eval"` / `cmd="evalsha"`.

### 4. Concurrency
go-redis EVAL/EVALSHA are pool-checkout + round-trip — no special contract. Same pool-exhaustion rules as any other command.

### 5. Size / atomicity notes (documented, not enforced)
- Redis/Dragonfly scripts are atomic — no other commands interleave on the server.
- BUSY risk: long-running scripts block the shard. Callers should use `SCRIPT KILL` externally if needed; SDK does not expose.
- Dragonfly executes Lua on a per-shard thread — semantics match single-shard Redis.

### 6. Test requirements (S6)
- miniredis supports basic Lua — test happy-path EVAL, return types (string, int64, []any, nil).
- ScriptExists → `[]bool` pass-through.
- NOSCRIPT mapping: use testcontainers in S7 (miniredis may not distinguish reliably).
- FuzzMapErr includes `NOSCRIPT` and `BUSY` strings.

## Anti-patterns
- SDK-owned SHA cache — TPRD non-goal.
- Auto-retry on NOSCRIPT inside SDK.
- SHA-keyed metric labels.
- Swallowing `ErrBusyScript` as generic unavailable — it signals script-specific action.

## References
TPRD §3 (non-goals), §5.6, §7 (script sentinels), §8.2 (cardinality).
