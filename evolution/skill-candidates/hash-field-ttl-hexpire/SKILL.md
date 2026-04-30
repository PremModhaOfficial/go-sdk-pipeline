---
name: hash-field-ttl-hexpire
version: 0.1.0-draft
status: candidate
priority: MUST
tags: [redis, dragonfly, hash, hexpire, ttl]
target_consumers: [sdk-design-lead, sdk-impl-lead, sdk-testing-lead]
scope: go
scope_rationale: Synthesized from Go pilot (sdk-dragonfly-s2); body cites motadatagosdk signatures + goleak. Promote to shared-core only after a Python sibling rewrite proves the rule body is language-neutral.
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §5.3, §14)
---

# hash-field-ttl-hexpire

## When to apply
Any SDK method mapping HEXPIRE / HPEXPIRE / HEXPIREAT / HTTL / HPERSIST (Redis 7.4+ / Dragonfly hash-field TTL family).

## Signatures (from TPRD §5.3)

```go
HExpire(ctx, key, ttl time.Duration, fields ...string) ([]int64, error)
HPExpire(ctx, key, ttl time.Duration, fields ...string) ([]int64, error)
HExpireAt(ctx, key, at time.Time, fields ...string) ([]int64, error)
HTTL(ctx, key, fields ...string) ([]time.Duration, error)
HPersist(ctx, key, fields ...string) ([]int64, error)
```

## Return-code contract — keep raw `[]int64`

TPRD §15 locks this: expose raw go-redis return codes, do not remap to enums. v2 may add a helper.

Per-field code semantics (Redis 7.4 reference):
- `-2` — no such key (applies to the whole call; list will be length 1 often).
- `-1` — no such field within existing key.
- `0`  — call ignored because of NX/XX/GT/LT condition (P0 does not expose these flags).
- `1`  — TTL set / field existed for TTL-query.
- `2`  — HEXPIRE with ttl=0 deleted the field atomically.

Position in `[]int64` corresponds to position in `fields...` at call time. Callers parallel-iterate.

`HTTL` returns `[]time.Duration`:
- `-2s` = no key (go-redis marshals `-2` seconds).
- `-1s` = field has no TTL.
- positive = remaining TTL.

Document all four return-value tables in godoc on the method comment.

## Input validation

- `len(fields) == 0` → return `ErrInvalidConfig` wrapped with `"fields: must supply at least one"` BEFORE the round trip.
- `ttl <= 0` on HExpire/HPExpire → reject with `ErrInvalidConfig` (HEXPIRE semantics differ between 0 and negative at server; cleaner to forbid).
- `at.Before(time.Now())` on HExpireAt — allowed; server will delete field (code 2). Document.

## Wire compatibility — Dragonfly vs Redis 7.4

TPRD §14 risk: Dragonfly HEXPIRE return-code parity is not 100% guaranteed. Mitigation:
- Integration test `hash_integration_test.go` (S7) exercises all five codes on BOTH miniredis (where supported) AND real Dragonfly.
- If a divergence is found: document in USAGE.md "Known Dragonfly gaps" table; do NOT patch codes inside `mapErr`.

## Metrics

Use `cmd=hexpire`, `cmd=hpexpire`, etc. Do NOT label by field count or field names.

## Test matrix (S3)

Table rows:
- no-key → all `-2`s.
- mixed fields (some exist, some don't) → per-position codes.
- HTTL after HExpire → positive duration < TTL (monotonic check).
- HPersist on no-TTL field → `-1`.
- HExpire with 2 fields + 2s TTL → [1, 1]; wait 2.1s; HGet both → ErrNil.

miniredis v2 HEXPIRE: verify feature support at test-startup; fall back to integration tier if unsupported.

## Anti-patterns
- Remapping `-2`/`-1`/`0`/`1`/`2` to a Go enum — violates TPRD zero-surprise parity.
- Using `[]int` instead of `[]int64` — signature mismatch with go-redis.
- Swallowing partial failures — every field gets a code, not a single error.

## References
TPRD §5.3, §14 (wire-compat risk), §15 (API shape decision).
