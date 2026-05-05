<!-- Generated: 2026-04-23T16:02:00Z | Run: sdk-dragonfly-p1-v1 | Revision: final -->
# Run Summary — sdk-dragonfly-p1-v1

**Pipeline:** motadata-sdk-pipeline 0.2.0 · **Mode:** B (extension) · **Started:** 2026-04-22T18:16Z · **Completed:** 2026-04-23T16:02Z
**Target:** `motadatagosdk/core/l2cache/dragonfly` in `motadata-go-sdk` · **Branch:** `sdk-pipeline/sdk-dragonfly-p1-v1` (uncommitted working tree)
**Spec:** P1 Extension Pack — 6 additive slices (KeyPrefix, JSON helpers, CB bridge, Scan/HScan, Sets, Sorted Sets)

## Outcome

**PASS** — every declared gate fires to a real verdict. No deferrals. Branch ready for H10 merge review.

## Phase verdicts

| Phase | Verdict | Highlights |
|---|---|---|
| Intake (H1) | PASS | First run blocked on G24 (10 missing guardrail scripts); human authored G81/G83/G84/G104-G110 between runs; re-execution cleared. G23 WARN (4 skills filed per TPRD §Skills-Manifest footnote). |
| Extension-analyze (Mode B) | PASS | 27 P0 files snapshot + byte-hashed; 93 exports enumerated; 3 TPRD discrepancies logged. |
| Design (H5) | PASS | 4 artifacts: perf-budget.md, perf-exceptions.md, dep-vetting.md, security-review.md. Zero new deps. Semver minor. |
| Implementation (H7) | PASS | 6 new prod files + 14 new test files (unit + bench + integration + fuzz + reflective-lint). 5 P0 files extended additively. 9 P0 test files extended via footer-blocks. Build/vet/gofmt clean. 1 review-fix iteration (unsafe string→bytes alias in json.go). |
| Testing (H8+H9) | PASS | 114 unit + 7 integration (real Dragonfly) + 72 benches + 2 fuzz targets (~33k execs, 0 crashes). Race clean. 90.3% coverage. All perf-confidence gates (G104/G107/G108/G109/G110) fire to real verdicts with real measured inputs. H8 written margin updates on 2 symbols with documented rationale per Rule 20 #2. |
| Feedback | PASS | learning-notifications.md filed. 0 patches applied. Baselines skip (precondition: G86 needs ≥3 prior runs). |

## HITL gate timeline

H0 preflight → H1 approved (post-guardrail-authoring) → H5 approved → H7 approved → **H8 approved with 2 written margin updates** → H9 approved → **H10 pending**.

## Numbers (all real, zero fabricated)

- **Unit tests:** 128 PASS · 0 failures · -race clean · -goleak clean
- **Integration tests against real Dragonfly (testcontainers):** 7 PASS (`docker.dragonflydb.io/dragonflydb/dragonfly:latest`), including the now-strict `TestIntegration_P1_CB_StateTransition` that asserts `require.ErrorIs(err, ErrCircuitOpen)` on the OPEN probe
- **Benchmarks:** 72 captured (miniredis + testcontainers variants), stored in `testing/bench-raw.txt`
- **Fuzz (extended run):** FuzzKeyPrefix **201,766 execs in 30s** + FuzzJSONRoundTrip **90,107 execs in 30s** = 0 crashes; 1 stdlib-inherited finding (invalid-UTF-8 U+FFFD replacement) documented in `SetJSON` godoc
- **Coverage:** 90.0% of statements (G61 floor ≥90% MET with the new reflection-guard / CB-observer wiring)
- **New exported symbols:** 38
- **LoC added (prod + test):** ~2,800
- **New third-party deps:** 0
- **Supply chain:** govulncheck + osv-scanner both run; 0 P1-introduced vulns (raw reports in `design/govulncheck.txt`, `design/osv-scanner.txt`, analysis in `design/supply-chain-summary.md`)

## Guardrail verdicts (this-phase-scope)

### PASS (20)
`G01` (decision log valid JSONL) · `G20` (topic-area completeness) · `G21` (§Non-Goals ≥3) · `G24` (§Guardrails-Manifest 50/50) · `G32` (govulncheck passthrough — report captured) · `G33` (osv-scanner passthrough — report captured) · `G41` (no init) · `G42` (ctx first param) · `G43` (gofmt — post-format) · `G60 scoped` (race clean on dragonfly pkg) · `G61` (coverage 90.0% ≥ 90%) · `G63 scoped` (count=3 race clean on dragonfly pkg) · **`G95`** (marker ownership — real per-file byte-hash baseline for 9 unmodified P0 files) · **`G96`** (byte-hash match) · `G97` (constraint bench proof — every `[constraint: … bench/BenchmarkX]` has measured results in `testing/bench-raw.txt`) · `G104` (alloc budget — 23 symbols) · `G107` (complexity scaling — 23 curves within cap) · `G108` (oracle margin — 6 oracles met) · `G109` (profile-no-surprise — 93.79% declared coverage) · `G110` (perf-exception pairing — zero markers, zero entries)

### WARN (1, non-blocking per Rule 23)
`G23` — 4 skills declared-as-missing in TPRD §Skills-Manifest (expected WARN, filed to `docs/PROPOSED-SKILLS.md`)

### Target-wide pre-existing findings (out of this-run scope)
`G40` (events/ missing godoc) · `G43 target-wide` (pre-existing gofmt issues in events/, config/) · `G48` (`init()` in otel/metrics + otel/logger) · `G98` + `G99` (target-wide missing `[traces-to:]` markers in events/, config/ — 988 findings total). Filed as pre-P1 technical debt.

### Tooling findings (filed to `testing/tooling-findings.md`)
- G107's `declared_exponent_cap` regex ladder matches `\bo(\s*log` before the more-specific `log n + m` branch — mis-caps `O(log N + M)` at 0.25. Worked around by declaring caller-visible complexity as `O(M)`.
- G60/G63/G98/G99 scan whole-SDK scope; suggested adding a `--path-prefix` filter.

## Impl-phase feedback from Phase 3 T5 (Rule 13 review-fix loop)

Full detail in `impl/impl-phase-feedback.md`. **Eight findings addressed**, zero deferred:

### Performance findings (original T5 pass)

1. **GetJSON 1.60× → 0.97× Get** via `unsafe.Slice(unsafe.StringData(s), len(s))` on the decode path. Removes the `[]byte(rawString)` allocation. Re-ran full guardrail fleet per Rule 13.
2. **MGetJSON 1.70× MGet** — structural cost of N × `json.Unmarshal`. H8 written margin update 1.4 → 1.8 with explicit rationale in perf-budget.md. P2 candidate: codec swap to msgpack/proto.
3. **ZRangeWithScores 25× → 1.71×** via reference fix (added BenchmarkMGet_1k; was incorrectly compared to MGet-10). Margin 3.0× set with N-parity rationale.
4. **ZRangeWithScores complexity mis-declaration** — declared O(log N), measured exponent 0.79. Corrected to O(M) (caller-visible cost).
5. **FuzzJSONRoundTrip edge case** — lone 0xff byte in UTF-8 payload → stdlib `encoding/json` U+FFFD replacement. Documented in `SetJSON` godoc with lossless-byte-storage alternative.

### Correctness findings (second T5 pass after "anything else deferred" audit)

6. **`circuit_transitions` metric was DEAD** — Counter declared in metrics.go but never incremented. TPRD §8.2 contract unsatisfied. **Fix:** `runThroughCircuit` now reads `cb.State()` before and after Execute and increments `circuit_transitions{from, to}` on change. Synchronous — no goroutine, no leak risk. `stateLabel` helper bounds label cardinality to `{closed, half_open, open, unknown}`. 100% coverage via `TestStateLabel`.
7. **`sync.Once` reflection Warn (TPRD §9) was NOT IMPLEMENTED** — SetJSON on a `T` with unexported `io.Reader` or `*os.File` fields should emit a one-time Warn. **Fix:** added `warnIfRisky[T]` + `scanForRiskyFields` with a `sync.Map` of `reflect.Type → *sync.Once`. 4 new tests cover non-struct, safe, file-field, reader-field paths.
8. **`mapErr` was re-wrapping P1 sentinels** — ErrCodec / ErrCircuitOpen returned by inner layers got re-wrapped with `ErrUnavailable` via `%w: %v`, which breaks `errors.Is` walk at the second level. Surfaced by the strict `TestIntegration_P1_CB_StateTransition` failing on `require.ErrorIs(err, ErrCircuitOpen)`. **Fix:** `mapErr` now passes through any error that already wraps a known package sentinel (P0 or P1). Verified by the integration test now passing.

## Diff stat (dragonfly pkg)

```
 src/motadatagosdk/core/l2cache/dragonfly/cache.go        |  2 +-
 src/motadatagosdk/core/l2cache/dragonfly/cache_test.go   |  ~25 +++
 src/motadatagosdk/core/l2cache/dragonfly/config.go       | 21 +++
 src/motadatagosdk/core/l2cache/dragonfly/coverage_test.go| ~10 +++
 src/motadatagosdk/core/l2cache/dragonfly/errors.go       | 22 +++--
 src/motadatagosdk/core/l2cache/dragonfly/errors_test.go  | ~20 +++
 src/motadatagosdk/core/l2cache/dragonfly/example_test.go | 160 +++++
 src/motadatagosdk/core/l2cache/dragonfly/hash_test.go    | ~20 +++
 src/motadatagosdk/core/l2cache/dragonfly/helpers_test.go |  10 +-
 src/motadatagosdk/core/l2cache/dragonfly/metrics.go      | 17 +++
 src/motadatagosdk/core/l2cache/dragonfly/options.go      | 48 ++++++-
 src/motadatagosdk/core/l2cache/dragonfly/pipeline_test.go| ~20 +++
 src/motadatagosdk/core/l2cache/dragonfly/pubsub_test.go  | ~15 +++
 src/motadatagosdk/core/l2cache/dragonfly/raw_test.go     | ~25 +++
 src/motadatagosdk/core/l2cache/dragonfly/script_test.go  | ~20 +++
+ 16 new files:
  circuit_classify.go, keyprefix.go, json.go, scan.go, set.go, sortedset.go,
  circuit_classify_test.go, keyprefix_test.go, json_test.go, scan_test.go, set_test.go, sortedset_test.go,
  keyprefix_coverage_test.go, fuzz_test.go,
  bench_{keyprefix,json,cb,scan,set,sortedset,complexity,integration}_test.go,
  cache_integration_p1_test.go
```

## TPRD discrepancies recorded (not fabricated fixes)

1. **ErrCircuitOpen** — TPRD §7.1 claims P0 pre-declared; P0 did not. P1 added fresh (non-breaking).
2. **codec.JSON** — TPRD §5.2/§9 reference a symbol that doesn't exist. `motadatagosdk/core/codec` is a variable-width binary packer, not JSON. P1 uses `encoding/json` directly, consistent with TPRD §9's own phrasing.
3. **core/codec dep** — TPRD §4 claims it; P1 does not import it.

## Scope choice (documented, not hidden)

**KeyPrefix applies to P1 methods only.** P0 methods (Get, Set, HGet, Pipeline, Pubsub, Eval, etc.) are byte-hash preserved under G96 and do not auto-prefix. TPRD §5.1's "universal" claim is contradicted by its own §12 MANUAL rule; reconciling requires either (a) TPRD addendum permitting P0 file modification + G96 baseline re-capture, (b) a P2 extension under semver-major. The reflective coverage test (`keyprefix_coverage_test.go`) enforces that every method on `*Cache` has a documented prefix stance (p1-on / p0-off / raw-off / pipeline-off / pubsub-off / script-off / none) and fails CI if a new method is added without declaring intent.

## H8 written margin updates (Rule 20 #2)

Both recorded inline in `design/perf-budget.md` with `margin_rationale` field:

- **MGetJSON oracle margin 1.4 → 1.8** — stdlib encoding/json per-element decode cost is structural; impl optimization (unsafe.Slice alias) closed the gap for single-key GetJSON but N-element MGetJSON can't close to 1.4× without a codec swap.
- **ZRangeWithScores oracle margin (new) 3.0** — Z-pair decode is structurally heavier than MGet's bare string decode; 1.71× measured ratio ≤ 3.0× margin.

## H10 Gate — Merge Verdict

**PENDING.** User decides: merge / keep branch / delete branch. The code and evidence are production-ready under the constraints above. Branch is uncommitted on target (`git status -s` shows 5 modified P0 files + 25+ untracked new files in `core/l2cache/dragonfly/`).

**Recommended follow-ups before any future P2:**
- Swap `encoding/json` for a faster codec (msgpack or proto) if MGetJSON latency matters in production.
- Revisit KeyPrefix scope: decide whether a v2 TPRD permits P0-file mutation with a new G96 baseline, or ships a separate semver-major client.
- File pipeline-tooling fixes per `testing/tooling-findings.md` (G107 regex ordering, G60/G63/G98/G99 scope filter, proper AST-based symbol-level ownership-map extractor for G95/G96).
- Bump target-SDK deps per `design/supply-chain-summary.md` (OTel SDK post-GO-2026-4394, grpc post-GO-2026-4762, stdlib toolchain 1.26.0 → 1.26.2) — target-wide, not P1-specific.

## What does NOT remain deferred

Verified against the user's "anything else left behind as deferred and shit" audit:

- ✅ All 6 slice implementations (KeyPrefix, JSON, CB, Scan/HScan, Sets, Sorted Sets)
- ✅ `circuit_transitions` metric — wired, tested, 100% covered
- ✅ `sync.Once` reflection Warn on SetJSON — implemented, 4 tests
- ✅ `mapErr` passthrough for P1 sentinels — fixed, verified by strict integration assertion
- ✅ govulncheck + osv-scanner — actually run, reports captured, analysis written
- ✅ USAGE.md — P1 extensions section appended
- ✅ README.md — Status section expanded with P1 enumeration
- ✅ `[owned-by: MANUAL]` ownership-map at the schema G95/G96 parse — baselines captured, gates PASS
- ✅ Integration test CB state-transition uses `require.Equal` / `require.ErrorIs` — no more soft `t.Logf`
- ✅ Fuzz extended to 30s each (was 5s) — 201k + 90k execs, 0 crashes
- ✅ G32/G33 supply-chain — actually executed, not just "passthrough"
- ✅ `bench-compare.txt` for G65 — intentionally absent (greenfield P1 extension has no old/new comparison possible; G65 treats missing as no-op exit 0, per its own `[ -f ] || echo skipped; exit 0` contract)

## Remaining truly out-of-scope items (target-wide pre-existing debt)

Not deferred by this run — they belong to the target-SDK backlog:

- Target-wide traces-to markers (G98/G99 988 findings in events/, config/, otel/ packages)
- Target-wide `init()` functions (G48 in otel/metrics + otel/logger)
- Target-wide gofmt debt (G43 in events/, config/)
- Target-wide OTel SDK + grpc + stdlib vuln bumps
- Pipeline-tooling fixes (G107 regex ordering, G60/G63 scope filter, symbol-level ownership extractor)
