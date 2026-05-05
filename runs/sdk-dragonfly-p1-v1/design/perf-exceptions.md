<!-- Generated: 2026-04-22T18:38:12Z | Run: sdk-dragonfly-p1-v1 -->
# Perf Exceptions — P1

None. P1 is fully additive and uses the P0 `instrumentedCall` + `runCmd[T]` shape. No hand-optimized hot paths, no [perf-exception:] markers expected in pipeline-authored code. G110 passes with zero-pairs.
