<!-- Generated: 2026-04-18T07:00:00Z | Run: sdk-dragonfly-s2 -->
# sdk-convention-devil — D3 Review

Evaluate conformance to existing target-SDK conventions. Input: `patterns.md`, `package-layout.md`, `api.go.stub`.

## Conventions checked

### C-1. Constructor style: `Config struct + NewFromConfig` vs functional options
**Existing target SDK**: uniformly Config-struct-direct (events/, resourcepool/, otel/).
**Dragonfly proposal**: functional `With*` options (15), `Config` still exported.
**Deviation?** YES — first package in target SDK with functional options.
**Justification in design**: `patterns.md` §P1 — TPRD §6 explicitly prescribes both; Appendix B shows the `With*` usage.
**Verdict:** ACCEPT-WITH-NOTE. The deviation is TPRD-directed; convention devils should not block TPRD-sanctioned divergence. But: flag as a **cross-SDK convention drift risk** — if this pattern spreads, the SDK ends up with two constructor styles indefinitely. Recommend promoting the pattern choice to a cross-SDK design-standards doc in a follow-up feedback cycle.

### C-2. Package godoc location
**Existing**: package godoc at top of a primary file (e.g., `events/events.go`, `otel/tracer/tracer.go`). No `doc.go`.
**Dragonfly proposal**: same — top of `cache.go`.
**Verdict:** ACCEPT.

### C-3. Error sentinel shape
**Existing**: `var ErrXxx = errors.New("package: xxx")` at package level.
**Dragonfly proposal**: same; 26 sentinels.
**Verdict:** ACCEPT.

### C-4. OTel access
**Existing**: through `motadatagosdk/otel/{tracer,metrics,logger}` (never raw `go.opentelemetry.io/otel`).
**Dragonfly proposal**: same. `instrumentedCall` uses `tracer.Start`, `metrics.Counter.Inc`, etc.
**Verdict:** ACCEPT.

### C-5. Test layout
**Existing**: `*_test.go` per domain, `*benchmark_test.go` for benches, `//go:build integration` for integration.
**Dragonfly proposal**: same.
**Verdict:** ACCEPT.

### C-6. Godoc style
**Existing**: "FuncName does X. ..." first sentence starts with symbol name.
**Dragonfly proposal**: same.
**Verdict:** ACCEPT (Phase 2 must enforce via G40 review).

### C-7. Ctx-first rule (G42)
All 46 data-path methods take `ctx context.Context` first. Verified in stub.
**Verdict:** ACCEPT.

### C-8. Compile-time assertions (G43)
Stub includes `var _ = (*Cache)(nil)` — weak. Design says `var _ io.Closer = (*Cache)(nil)` + internal stopper. Phase 2 must implement both.
**Verdict:** ACCEPT (design documents the intent; Phase 2 enforces).

### C-9. No `init()`, no global mutable state (G41)
Design says no `init()`; `sync.Once` for metrics. Metrics registry is external (shared across packages). No package-level mutable state introduced by dragonfly.
**Verdict:** ACCEPT.

### C-10. No unnecessary `*redis.Client` re-export
**Existing**: `events` re-exports select NATS types via local aliases.
**Dragonfly proposal**: `Cache.Client()` returns `*redis.Client` directly (not aliased). This is a light leak of the upstream type.
**Alternative**: `type Client = redis.Client` alias at package level, then `(*Cache).Client() *Client`.
**Assessment**: TPRD §5.7 explicitly says "direct handle; for features not yet wrapped". An alias buys nothing and introduces confusion. Reject the alias.
**Verdict:** ACCEPT.

### C-11. Package path under `core/l2cache/dragonfly`
Matches target tree convention (`core/l1cache`, `core/pool`, `core/circuitbreaker`).
**Verdict:** ACCEPT.

## Aggregate

- 10 ACCEPT
- 1 ACCEPT-WITH-NOTE (C-1, intentional TPRD-sanctioned deviation)
- 0 REJECT
- 0 NEEDS-FIX

## Verdict

**ACCEPT** overall. One documented deviation (functional options) is TPRD-directed; all other patterns align.

Recommend for follow-up (Phase 4 feedback): promote a cross-SDK design-standards doc clarifying when each constructor style (Config-direct vs functional options) applies.
