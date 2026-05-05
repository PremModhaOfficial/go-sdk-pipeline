<!-- Generated: 2026-04-18T14:35:00Z | Run: sdk-dragonfly-s2 -->
# Testing Summary — sdk-dragonfly-s2 Phase 3

**One-liner:** All hard gates green; one soft gate (allocs-per-GET constraint vs `go-redis/v9.18` client floor) requires H8 disposition before H9 close.

## Numbers

| Metric | Value |
|---|---|
| Unit tests PASS | 71 |
| Unit tests SKIP | 1 |
| Unit tests FAIL | 0 |
| Integration tests PASS (T2) | 2 |
| Integration tests SKIP (T2) | 1 |
| Integration tests FAIL (T2) | 0 |
| Flake-hunt iterations | 3 |
| Flake-hunt PASS count | 217 |
| Flake-hunt FAIL count | 0 |
| Coverage | 90.4% |
| Observability conformance tests | 4 (all PASS) |
| Fuzz execs | 839,670 (2 fuzzers × 60s) |
| Fuzz crashes | 0 |
| goleak detections | 0 |
| Data races | 0 |
| govulncheck new CVEs in dragonfly scope | 0 |
| osv-scanner new CVSS≥7 in dragonfly deps | 0 |
| Test files in package (post-Phase-3) | 14 (+1 vs Phase 2) |
| Pipeline commits on branch | 7 (+1 vs Phase 2) |
| Benchmarks recorded | 5 (Get/Set/HExpire/EvalSha/Pipeline_100) |
| Bench iterations | 10 per bench |

## Bench constraint table (TPRD §10)

| Constraint | Target | Measured | Verdict |
|---|---|---|---|
| P50 GET ≤ 200µs | 200µs | 26.6µs (miniredis) | PROVISIONAL-PASS |
| P99 GET ≤ 1ms | 1,000µs | ~28µs | PROVISIONAL-PASS |
| ≤3 allocs per GET | 3 | 32 | **FAIL** → H8 |
| SDK overhead vs raw go-redis ≤ 5% | 5% | — | UNMEASURED |
| 10k ops/sec sustained | 10,000 | ~37,594 theoretical | UNMEASURED |

## H8 status

**Required.** Allocs-per-GET constraint FAIL. Dispositions in `H9-summary.md §6`. Recommended: (a) accept-with-waiver at 35 allocs OR (c) re-scope to wrapper-only allocs.

## H9 recommendation

**APPROVE** pending H8 disposition. Test rigor is satisfactory: 90.4% coverage, 0 leak / 0 race / 0 flake / 0 fuzz-crash / 0 new-CVE. One benchmark constraint reveals a TPRD target mismatched against the chosen client's baseline cost — a calibration decision, not a test failure.

## Artifacts

- `runs/sdk-dragonfly-s2/testing/coverage.txt`
- `runs/sdk-dragonfly-s2/testing/integration.txt`
- `runs/sdk-dragonfly-s2/testing/flake-hunt.txt`
- `runs/sdk-dragonfly-s2/testing/bench-raw.txt`
- `runs/sdk-dragonfly-s2/testing/bench-compare.md`
- `runs/sdk-dragonfly-s2/testing/leak-hunt.txt`
- `runs/sdk-dragonfly-s2/testing/fuzz.txt`
- `runs/sdk-dragonfly-s2/testing/govulncheck.txt`
- `runs/sdk-dragonfly-s2/testing/osv-scan.txt`
- `runs/sdk-dragonfly-s2/testing/observability.txt`
- `runs/sdk-dragonfly-s2/testing/H9-summary.md`
- `baselines/performance-baselines.json` (key `core/l2cache/dragonfly` — first-run baseline)
- Commit `a4d5d7f` on `sdk-pipeline/sdk-dragonfly-s2` (T9 observability conformance)
