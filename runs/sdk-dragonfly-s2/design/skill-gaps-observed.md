<!-- Generated: 2026-04-18T06:42:00Z | Run: sdk-dragonfly-s2 -->
# Skill Gaps Observed — Phase 1 Design

Per intake verdict, 8 skills from TPRD §Skills-Manifest were WARN-absent. During Phase 1 design, the following gaps materialized as "would-have-helped" moments. Forwarded to Phase 4 feedback / `docs/PROPOSED-SKILLS.md`.

## G-1. `sentinel-error-model-mapping`

**Used by:** `algorithms.md` §A `mapErr` switch; `api.go.stub` errors.go section.

**What a skill would have prescribed:**
- Canonical precedence order for `errors.Is` / `errors.As` / string-prefix matching.
- How to wrap: `fmt.Errorf("%w: %v", sentinel, cause)` vs `fmt.Errorf("%w", cause)` — the former preserves both sentinel for `errors.Is` AND raw message; the latter loses the message.
- Pattern for fuzz-testing: seed corpus of real server error strings.

**Synthesized from:** `network-error-classification` + `go-error-handling-patterns` + TPRD §7 prescription.

## G-2. `redis-pipeline-tx-patterns`

**Used by:** `api.go.stub` §5.4 block (`Pipeline`, `TxPipeline`, `Watch`).

**What a skill would have prescribed:**
- When to instrument pipeline commands vs leave raw.
- How `Watch(ctx, fn, keys...)` interacts with go-redis retry loops.
- Whether to wrap `Pipeliner` (answer here: no — pass through).

**Synthesized from:** TPRD §5.4 + reading go-redis v9 pipeline docs.

## G-3. `hash-field-ttl-hexpire`

**Used by:** `algorithms.md` §C HEXPIRE semantics.

**What a skill would have prescribed:**
- The 4-value return code space `{-2, 0, 1, 2}`.
- Redis 7.4 vs Dragonfly wire compatibility risks.
- Whether to expose a typed enum (answer: §15.Q1 says no).

**Synthesized from:** Redis.io HEXPIRE docs + TPRD §15.Q1.

## G-4. `pubsub-lifecycle`

**Used by:** `concurrency.md` §G2 PubSub leak story.

**What a skill would have prescribed:**
- Explicit caller-owns-Close pattern vs SDK-managed handle tradeoff.
- Goroutine-leak failure modes (one per unclosed subscription).
- Integration-test chaos patterns for subscriber tear-down.

**Synthesized from:** `goroutine-leak-prevention` + `client-shutdown-lifecycle`.

## G-5. `miniredis-testing-patterns`

**Used by:** anticipated Phase 2/3 test files (package-layout.md lists them).

**What a skill would have prescribed:**
- How to structure table-driven tests with a miniredis-per-subtest vs shared miniredis.
- Which commands miniredis does NOT support (affects fallback expectations).
- HEXPIRE: does miniredis support it? (Phase 2 must verify.)

**Synthesized from:** `table-driven-tests` + `testing-patterns`.

## G-6. `testcontainers-dragonfly-recipe`

**Used by:** `dependencies.md` §B3; `package-layout.md` integration test file.

**What a skill would have prescribed:**
- Exact Dragonfly image + tag stability policy.
- Readiness probe (TCP + PING).
- TLS + ACL bootstrap sequence inside container.

**Synthesized from:** `testcontainers-setup` + Dragonfly documentation.

## G-7. `lua-script-safety`

**Used by:** `api.go.stub` §5.6 (Eval / EvalSha / ScriptLoad / ScriptExists).

**What a skill would have prescribed:**
- SHA handling conventions.
- NOSCRIPT → EvalSha → reload pattern (caller-owned per TPRD §3).
- Safe arg escaping (answer: go-redis handles this).

**Synthesized from:** TPRD §5.6 + §3 non-goals (caller owns script registry).

## G-8. `k8s-secret-file-credential-loader`

**Used by:** `api.go.stub` `LoadCredsFromEnv`; `patterns.md` §P5.

**What a skill would have prescribed:**
- `file → env-var-name → read-file` chain pattern.
- Handling `fs.PathError` distinctly from empty-env.
- Whether to trim whitespace (Kubernetes secrets typically don't add newlines, but file-based tooling often does).

**Synthesized from:** `credential-provider-pattern` + TPRD §9.

---

## Priority for human authoring (Phase 4 feedback)

1. **`sentinel-error-model-mapping`** — highest re-use value; any SDK client benefits.
2. **`pubsub-lifecycle`** — caller-owns-Close is subtle and recurring.
3. **`hash-field-ttl-hexpire`** — narrow but exact; saves future HEXPIRE adopters from Redis-7.4-quirk rediscovery.
4. **`testcontainers-dragonfly-recipe`** — narrow; Phase 3 Impl will need it regardless.
5. Remaining four are useful but derive closely from existing patterns.

All 8 filed to `docs/PROPOSED-SKILLS.md` under section "Auto-filed from run `sdk-dragonfly-s2`" (intake seq 5).
