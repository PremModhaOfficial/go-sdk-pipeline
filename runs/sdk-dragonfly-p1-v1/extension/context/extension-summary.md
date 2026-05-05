<!-- Generated: 2026-04-22T18:38:05Z | Run: sdk-dragonfly-p1-v1 -->
# Phase 0.5 Extension-analyze — Summary

**Mode:** B · **Source run:** `sdk-dragonfly-s2` · **Target:** `core/l2cache/dragonfly`

## P0 surface snapshot

- **27 .go files** in P0 package (prod + test)
- **93 exported symbols** across 11 prod files (Cache methods + Option funcs + Err* sentinels + Config/TLSConfig types)
- **Single data-path wrapper** (`instrumentedCall` in `cache.go`) — every prod method routes through it except `raw.Do` and `raw.Client`
- **Generic dispatcher** `runCmd[T]` in `cache.go:239` wraps `instrumentedCall` for single-return-value methods

## Byte-hash baseline

All 27 files SHA256-hashed. See `ownership-map.json`. G96 will re-hash at impl-phase exit and reject any diff on MANUAL-marked files.

## Key-prefix coverage matrix (from TPRD §5.1)

**37 key-ingress methods** across 6 files. Per TPRD:
- **33 must auto-prefix** (all String/Hash/Pipeline-batched/Pubsub/Script/Pool/TTL commands)
- **2 must bypass prefix** (`raw.Do`, `raw.Client`) — intentional escape hatch
- **2 are structural** (`Pipeline`, `TxPipeline`) — return a Pipeliner; the callback inside must respect KeyPrefix. This requires either wrapping the Pipeliner at `Pipeline()` call site (new file `keyprefix.go`) or documenting the caller contract

TPRD §14 Risk row 1 requires a `reflect`-based lint test in `keyprefix_test.go` that enumerates every method on `*Cache` and asserts coverage.

## TPRD discrepancies discovered

Three inaccuracies logged to `ownership-map.json § tprd_discrepancies_noted`:

1. **ErrCircuitOpen** — TPRD claims P0 pre-declared it; P0 did not. P1 introduces fresh as new sentinel. No semver impact (both paths are additive).
2. **codec.JSON** — TPRD §5.2 references `motadatagosdk/core/codec` JSON encoder; no such encoder exists — the package is a variable-width binary packer. P1 will use `encoding/json` directly, consistent with TPRD §9's description "uses encoding/json under the hood".
3. **Dependency graph** — TPRD §4 claims both `core/codec` and `core/circuitbreaker`; only the latter will actually be imported.

None of these block P1 implementation. All three are noted for the `sdk-dep-vet-devil` handoff in Phase 1 design.

## Hand-off to design

Design lead (`sdk-design-lead`) should:

1. Emit `api-design.md` with all 6 slices using the P0 `instrumentedCall` / `runCmd[T]` pattern.
2. Emit `perf-budget.md` declaring hot paths + big-O + `allocs_per_op` + oracle margins (feeds G104/G107/G108/G109).
3. Emit `dep-vetting.md` noting TPRD §4 internal-dep adjustment (codec drop).
4. Emit `perf-exceptions.md` — empty (TPRD §16 expects zero `[perf-exception:]` markers in P1).
5. Emit `security-review.md` — §9 KeyPrefix sanitization warning, CB integration audit, typed-JSON reflection guard (sync.Once warn on `T` containing `io.Reader`/`*os.File`).
