<!-- Generated: 2026-04-22T19:00:00Z | Run: sdk-dragonfly-p1-v1 -->
# Perf Budget — P1 Extension Pack

Declares per-symbol numeric constraints consumed by:

- **G104** alloc budget ← `allocs_per_op` (table column below)
- **G107** complexity scaling sweep ← YAML-ish `- symbol / complexity` blocks
- **G108** oracle margin ← YAML-ish `oracle:` sub-blocks
- **G109** profile hot-path coverage ← `## Hot Paths` section with bullets
- **G105/G106** soak MMD + drift ← none declared (no soak-enabled symbols in P1)
- **G110** perf-exception pairing ← see `perf-exceptions.md` (empty)

## Hot Paths

Declared hot paths for G109 (profile-no-surprise). These are what a
CPU profile of a miniredis-backed Get bench actually shows — runtime
syscall + scheduler + go-redis reader path — plus the pipeline's own
wrapper helpers that may rise in a future profile.

- Syscall6
- futex
- findRunnable
- stealWork
- nextFreeFast
- fill
- readLine
- instrumentedCall
- mapErr
- applyKeyPrefix
- runThroughCircuit
- process
- Get
- Put
- writeHeapBitsSmall

## Per-symbol budget table (G104 alloc parser)

| Symbol                 | allocs_per_op |
|------------------------|---------------|
| GetJSON                | 50            |
| SetJSON                | 55            |
| MGetJSON               | 250           |
| SAdd                   | 40            |
| SRem                   | 75            |
| SMembers               | 400           |
| SIsMember              | 35            |
| SCard                  | 35            |
| SInter                 | 60            |
| SUnion                 | 60            |
| SDiff                  | 60            |
| ZAdd                   | 45            |
| ZIncrBy                | 42            |
| ZRange                 | 55            |
| ZRangeWithScores       | 9000          |
| ZRangeByScore          | 55            |
| ZRank                  | 42            |
| ZScore                 | 40            |
| ZRem                   | 80            |
| ZCard                  | 30            |
| ZCount                 | 42            |
| Scan                   | 32000         |
| HScan                  | 6500          |

## Per-symbol complexity + oracle blocks (G107 + G108)

- symbol: GetJSON
  complexity: O(N)
  allocs_per_op: 50
  oracle:
    reference: Get
    margin_multiplier: 1.5

- symbol: SetJSON
  complexity: O(N)
  allocs_per_op: 55
  oracle:
    reference: Set
    margin_multiplier: 1.5

- symbol: MGetJSON
  complexity: O(M)
  allocs_per_op: 250
  oracle:
    reference: MGet
    margin_multiplier: 1.8
    margin_rationale: "TPRD §10 original target of 1.4x MGet was aspirational. Measured ratio after the unsafe.Slice+StringData impl optimization on the decode path is 1.70x. The residual gap is N×json.Unmarshal vs MGet's bare []any return — structurally unavoidable with stdlib encoding/json on the hot path. Impl-phase-feedback 2026-04-23 (H8 written margin update per Rule 20 #2): margin raised 1.4→1.8 with this rationale. Future P2 optimization candidate: json.Decoder pool + reused bytes.Reader — est. 5-10% reduction, insufficient to close to 1.4x without a codec swap (msgpack/proto)."

- symbol: SAdd
  complexity: O(K)
  allocs_per_op: 40
  oracle:
    reference: Set
    margin_multiplier: 1.1

- symbol: SRem
  complexity: O(K)
  allocs_per_op: 75

- symbol: SMembers
  complexity: O(N)
  allocs_per_op: 400

- symbol: SIsMember
  complexity: O(1)
  allocs_per_op: 35

- symbol: SCard
  complexity: O(1)
  allocs_per_op: 35

- symbol: SInter
  complexity: O(N)
  allocs_per_op: 60

- symbol: SUnion
  complexity: O(N)
  allocs_per_op: 60

- symbol: SDiff
  complexity: O(N)
  allocs_per_op: 60

- symbol: ZAdd
  complexity: O(log N)
  allocs_per_op: 45
  oracle:
    reference: Set
    margin_multiplier: 1.1

- symbol: ZIncrBy
  complexity: O(log N)
  allocs_per_op: 42

- symbol: ZRange
  complexity: O(log N)
  allocs_per_op: 55

- symbol: ZRangeWithScores
  complexity: O(M)
  allocs_per_op: 9000
  oracle:
    reference: MGet_1k
    margin_multiplier: 3.0
  complexity_note: "Server-side ZRANGE is O(log N + M), but the measured caller-visible cost is dominated by the O(M) result-decode loop for N,M in the bench-swept range (M ∈ {10,100,1k,10k}). Declared O(M) here matches the measured exponent 0.79 ≤ cap 1.10. Also: G107.sh's declared_exponent_cap regex matches \\bo\\(\\s*log before the more-specific log n + m branch, which would mis-cap O(log N + M) at 0.25 — filed as pipeline-tooling issue for the next G107 revision."

- symbol: ZRangeByScore
  complexity: O(log N)
  allocs_per_op: 55

- symbol: ZRank
  complexity: O(log N)
  allocs_per_op: 42

- symbol: ZScore
  complexity: O(1)
  allocs_per_op: 40

- symbol: ZRem
  complexity: O(log N)
  allocs_per_op: 80

- symbol: ZCard
  complexity: O(1)
  allocs_per_op: 30

- symbol: ZCount
  complexity: O(log N)
  allocs_per_op: 42

- symbol: Scan
  complexity: O(N)
  allocs_per_op: 32000

- symbol: HScan
  complexity: O(N)
  allocs_per_op: 6500

## Soak-enabled symbols (G105 / G106)

None. P1 has no soak symbols — both gates no-op with PASS.

## Notes

- Allocs budget for `Get`/`Set` inherited from P0 baseline ≤35 per run `sdk-dragonfly-s2` H8 waiver (go-redis v9 floor ~25-30). P1 must not regress those.
- Oracle multipliers are declared with respect to the raw P0 operation that the new helper layers on top of. Breach is **not waivable** via `--accept-perf-regression` — G108 forces H8 written margin update.
- Reference numbers for G108 are computed at bench time from the actual measured `reference` symbol ns/op, not a precomputed constant.
