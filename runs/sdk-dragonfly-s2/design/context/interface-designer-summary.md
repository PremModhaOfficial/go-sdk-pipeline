<!-- Generated: 2026-04-18T06:40:00Z | Run: sdk-dragonfly-s2 -->
# interface-designer — D1 Summary

Output: `design/interfaces.md`.

## Headlines

- **No exported interfaces.** TPRD §15.Q3 resolved: "no `redis.Cmdable` exposure; tests use miniredis". Concrete `*Cache` only.
- **Internal compile-time assertions (G43):** `var _ io.Closer = (*Cache)(nil)` and an internal `stopper` contract for the scraper.
- **46 receiver methods** on `*Cache`, all with `ctx context.Context` first (G42 compliant at design time).
- **Signature parity with go-redis:** return types (`string`, `int64`, `[]any`, `map[string]string`, `[]int64`, `time.Duration`, `[]bool`) are not remapped.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| `type Cacher interface { Get... }` | §15.Q3 + mock maintenance cost |
| `Cache[K,V]` generics | go-redis returns `string`, typed wrapping creates false safety |
| `Option` as interface | functional-func option idiomatic; matches events SDK's Config-struct convention at a higher abstraction (options apply to Config) |
| Split Reader/Writer interfaces | premature segregation; no caller needs it |

## Thread safety invariants

- `*Cache` safe for concurrent use.
- `Close` idempotent (atomic flag).
- Zero-value `Cache` not usable; `New` is sole constructor.
