<!-- Generated: 2026-04-18T06:15:00Z | Run: sdk-dragonfly-s2 | Agent: interface-designer -->
# Interface Design — `dragonfly`

Scope: concrete types only. No exported interfaces on receiver — TPRD §15.Q3 explicitly resolves: "no `redis.Cmdable` exposure; tests use miniredis". This document defines:

1. The concrete type surface users program against.
2. Internal seams where compile-time interface assertions are used (G43).
3. Rationale for NOT extracting a `CacheAPI` interface.

## 1. Exported type surface

| Type | Kind | Rationale |
|---|---|---|
| `Cache` | `struct` (receiver) | Primary user handle. Methods live on `*Cache`. All data-path methods are methods on `*Cache`. |
| `Config` | `struct` | Populated via `With*` options. See §6 of TPRD. |
| `TLSConfig` | `struct` | Nested in `Config.TLS`. Mirror shape of `motadatagosdk/events.TLSConfig` for convention parity. |
| `Option` | `func(*Config)` | Functional option applied to internal config. |

**No exported interfaces.** Reasoning:

- TPRD §15.Q3 answered: "no, return concrete `*Cache`". Tests use miniredis (which speaks the wire protocol), so a mock-oriented interface is unnecessary.
- Adding a `CacheAPI` interface with ~40 methods creates a maintenance burden (adding a new command requires editing interface + impl + mocks) and invites stale-interface drift.
- Go ecosystem convention (go-redis itself, stdlib `sql`) returns concrete `*Client` / `*DB`. Users can wrap in their own interface if they need DI.

## 2. Receiver method grouping

All methods listed in TPRD §5.x; binding to `*Cache` receiver:

- §5.1 Lifecycle (3): `Ping`, `Close` + `New` (package function).
- §5.2 Strings (19)
- §5.3 Hash (13)
- §5.4 Pipeline (3)
- §5.5 PubSub (3)
- §5.6 Scripting (4)
- §5.7 Raw (2)

**Total receiver methods on `*Cache`:** 47 (19+13+3+3+4+2+3) — wait, 2 lifecycle receiver methods. 19+13+3+3+4+2+2 = 46 receiver methods.

All data-path methods share the same first-arg shape: `ctx context.Context, <domain args...>` (G42 complies at design time). Returns mirror go-redis (string / int64 / []any / map[string]string / []int64 / time.Duration / bool / error).

## 3. Internal compile-time assertions (G43)

Even without exported interfaces, we assert internal shape consistency:

```go
// cache.go — ensure Cache satisfies io.Closer for generic caller patterns
var _ io.Closer = (*Cache)(nil)

// poolstats.go — internal scraper satisfies a simple stopper contract
type stopper interface{ stop() }
var _ stopper = (*poolStatsScraper)(nil)
```

These are zero-cost at runtime and catch signature drift at compile.

## 4. Rejected alternatives

| Alternative | Reason rejected |
|---|---|
| Export `type Cacher interface { Get, Set, ... }` | TPRD §15.Q3 says no. Maintenance cost not worth the marginal mockability. |
| Generic `Cache[K comparable, V any]` | go-redis returns `string`, not typed values. Type-safety gains are illusory when values transit as bytes. |
| `type Option interface { apply(*Config) }` (interface-based options) | Functional-func option is idiomatic + matches existing SDK pattern (see `events.ConnectionConfig` which uses `Config struct` directly, and `pool/resourcepool` which uses `Config struct` directly). `Option func(*Config)` is the chosen reconciliation of TPRD §6 "Config + With* options". |
| Separate `type Reader interface{Get...}` and `type Writer interface{Set...}` | Premature segregation. Users do not compose reader/writer shapes for a cache client; they want the full surface or none. |

## 5. Option pattern reconciliation (TPRD §6)

TPRD §6 says both:
- "All fields in `Config`"
- "All setters in `options.go`"

Plus intake §Non-negotiable #1: "Config struct + `With*` options — match existing SDK convention".

**Resolution:** `Config` is an exported struct (populated for advanced callers / serialization). `Option` is `func(*Config)`. `New(opts ...Option)` zeros a `Config`, applies each option, then `applyDefaults()` fills missing values, then `validate()`. Callers may choose either path:

```go
// Preferred: With* options
cache, err := dragonfly.New(
    dragonfly.WithAddr("dfly:6379"),
    dragonfly.WithPoolSize(32),
)

// Power users: raw Config via a single option
cfg := dragonfly.Config{Addr: "dfly:6379", PoolSize: 32}
cache, err := dragonfly.New(func(c *dragonfly.Config) { *c = cfg })
```

We do NOT export a `NewWithConfig(cfg Config)` constructor — keeps the entry point single (`New`). This matches how `events.Connect(ctx, cfg)` and `resourcepool.New` present a single constructor.

## 6. Method-signature invariants

Verified at design time; Phase 2 impl must not drift:

- Every data-path method: first param `ctx context.Context`. (G42)
- Every data-path method returns `(..., error)` with the last return being `error`. (standard Go convention)
- Variadic args only where TPRD specifies: `MGet(keys...)`, `MSet(kv...)`, `HSet(values...)`, `HMGet(fields...)`, `HDel(fields...)`, `HExpire(ttl, fields...)`, `Watch(fn, keys...)`, `Eval(script, keys, args...)`, `ScriptExists(shas...)`, `Do(args...)`.
- Return types are not remapped (intake non-negotiable #8): `[]any`, `map[string]string`, `[]int64`, `time.Duration`, `[]bool` all match go-redis v9.

## 7. Thread safety

- `*Cache` MUST be safe for concurrent use (go-redis `*Client` is; `Cache` adds only read-only fields + a scraper with its own synchronization).
- `Close` MUST be idempotent and safe to call concurrently with any other method (typical pattern: atomic flag + RWMutex held read by ops, write by close).
- `*Cache` zero-value is not usable; `New` is the only constructor.
