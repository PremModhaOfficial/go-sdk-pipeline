<!-- Generated: 2026-04-18T06:40:00Z | Run: sdk-dragonfly-s2 -->
# algorithm-designer — D1 Summary

Output: `design/algorithms.md`.

## Four algorithmic surfaces

1. **`mapErr` switch** (§7): 11-step precedence-ordered match chain (`redis.Nil` → `context.*` → `redis.TxFailedErr` → pool errors → net.Error → TLS errors → server-error prefixes → default `ErrUnavailable`). Wraps via `fmt.Errorf("%w: %v", Sentinel, cause)`. Fuzz-tested (`FuzzMapErr`).
2. **Pool-stats scraper** (§8.2): 10s interval default (§15.Q2), 1s floor. Emits 6 gauges via `motadatagosdk/otel/metrics`. Shutdown-safe via done+stopped channels (details in concurrency.md).
3. **HEXPIRE wire semantics** (§5.3, §15.Q1): raw `[]int64` per-field return codes `{-2, 0, 1, 2}`; documented in godoc; NOT wrapped in enum.
4. **`instrumentedCall` wrapper**: single hot-path helper. `cmd` is a compile-time literal (cardinality guard §8.4). 1 extra alloc from `Labels{}` map; documented as possible lever for §10 ≤3-alloc target.

## `classify(err)` label bounding

6 values: `timeout | unavailable | nil | wrong_type | auth | other`. Cardinality cap: ~276 series max (46 cmds × 6 classes).

## Open risks

- `redis.TxFailedErr` must be caught BEFORE default — added as match-rule 0a.
- `BUSY ` (trailing space) prefix avoids `BUSYGROUP` collision.
- `metrics.Labels{"cmd": cmd}` allocates a map every call — potential optimization lever if bench misses §10 target.
