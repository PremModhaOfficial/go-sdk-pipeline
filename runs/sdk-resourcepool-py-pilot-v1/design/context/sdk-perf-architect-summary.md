<!-- Generated: 2026-04-27T00:01:40Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: sdk-perf-architect -->

# Perf-architect summary — D1 wave

## Output produced
- `design/perf-budget.md` (235 lines): per-symbol latency / allocs / throughput / oracle / floor / complexity / MMD / drift-signals declarations for every TPRD §10 row + every hot-path §5 method.
- `design/perf-exceptions.md` (47 lines): empty by design; documented entry shape for future use.

## RULE 0 compliance
- Every TPRD §10 row has a declared budget + named bench file (6/6 covered: §1.1, §1.3, §1.4, §1.5, §1.8 plus §1.7 stats which TPRD §10 implies).
- Three additional symbols (acquire_resource §1.2, release §1.6, stats §1.7) declared for completeness.
- Drift signals named with explicit T2-3 rationale (concurrency_units + outstanding_acquires alias).
- MMD = 600s declared.
- G104 / G105 / G106 / G107 / G108 / G109 all gated.
- Zero TBD cells.

## Oracle calibration
- **Source**: Go reference `motadatagosdk/core/pool/resourcepool/`, `pool.go` package docstring "Throughput: 10M+ ops/sec for cached resources" → ~100ns acquire+release cycle, ~50ns acquire alone.
- **Empirical Go bench**: launched at design time (`go test -bench=. -benchmem -benchtime=2s`), did not complete within design wallclock cap. Decision: declare oracle from doc-stated 10M ops/sec figure; impl phase re-measures and updates `baselines/python/performance-baselines.json` on first successful Go bench. If measured Go numbers diverge >2× from declared oracle, perf-architect re-opens budget at H8.
- **Margin**: 10× per TPRD §10 — Python allowed up to 10× Go's number; structural GIL + asyncio overhead.

## Drift signal naming (T2-3 verdict)
- Primary: `concurrency_units` (cross-language neutral name)
- Alias: `outstanding_acquires` (redundant signal for sanity-cross-validation)
- Additional: `heap_bytes` (tracemalloc), `gc_count` (allocation pressure)

## Hot-path declaration (G109)
- `_acquire_with_timeout` inner block ≥ 50% acquire CPU samples
- `release` inner block ≥ 30% release CPU samples
- `_create_resource_via_hook` <5% steady-state, ≥10% cold-start
- Combined coverage ≥ 80% on hot path (G109 fail otherwise)

## Verdict taxonomy mapping (rule 33)
Tabular PASS/FAIL/INCOMPLETE per gate (G104, G105, G106, G107, G108, G109) — see perf-budget.md §4.

## Cross-references
- Hot-path internals → algorithm.md §8
- Drift signal harness wiring → concurrency-model.md (consumer)
- Test bench files → patterns.md §10 (test layout)

## Decision-log entries this agent contributed
1. lifecycle:started
2. decision: oracle-from-doc-stated-throughput (Go bench wallclock cap; recalibration path declared)
3. decision: drift-signal-name-concurrency_units (T2-3 verdict; alias outstanding_acquires)
4. decision: MMD-600s (10 minutes minimum-meaningful-duration)
5. decision: hot-path-coverage-thresholds (G109 falsification axis)
6. decision: empty-perf-exceptions-md (no premature optimization in pilot v1)
7. event: every-tprd-§10-row-budgeted
8. event: every-§5-hot-path-method-budgeted
9. lifecycle:completed
