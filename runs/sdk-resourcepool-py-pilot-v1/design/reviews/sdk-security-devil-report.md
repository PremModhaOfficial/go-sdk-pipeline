<!-- Generated: 2026-04-29T13:40:30Z | Agent: sdk-security-devil | Wave: D3 -->

# Security Devil Review — `motadata_py_sdk.resourcepool`

Reviewer: `sdk-security-devil` (shared-core)
Verdict: **ACCEPT**

## Threat model

A bounded async resource pool is a low-attack-surface primitive. It does
not:
- Accept network input (caller-supplied resources are typed `T`).
- Deserialize untrusted data.
- Hold credentials or secrets.
- Touch the filesystem.
- Spawn subprocesses.

The threat model reduces to:
1. **DoS via resource exhaustion** — bounded by `max_size`. ✓
2. **Cancellation-induced state corruption** — explicitly defended in
   `concurrency-model.md`. ✓
3. **Hook-callable abuse** — `on_create` / `on_reset` / `on_destroy` are
   caller-supplied; the pool catches and contains exceptions per
   `error-taxonomy.md`. ✓
4. **Information disclosure via `PoolStats`** — the snapshot exposes
   counts only, no resource contents. ✓
5. **Dependency supply-chain** — 0 runtime deps. ✓

## Specific checks

| Check | Verdict |
|---|---|
| No hardcoded credentials | PASS — no creds anywhere in design. |
| No `pickle` / `marshal` / `eval` / `exec` | PASS — none referenced. |
| No `subprocess` / `os.system` | PASS — none. |
| No raw SQL, no string-interpolated commands | PASS — no DB/shell touched. |
| No untrusted-input deserialization | PASS — `T` is caller-typed. |
| Dependency CVE scan | PASS — see `sdk-dep-vet-devil-python-report.md`. |
| Resource exhaustion bounded | PASS — `max_size` enforced. |
| Memory leak risk (long-running soak) | PASS — `aclose` drains; soak test in T5.5 verifies no rss/tracemalloc growth. |
| Information leak via error messages | PASS — error taxonomy uses sentinel strings, not user data. |
| TLS / crypto exposure | N/A — pool does not touch network. |

## OTel deferred

TPRD §3 defers OTel wiring. When that follow-up TPRD lands, security devil
must re-review for:
- Trace context propagation (no PII in span attrs).
- Metric label cardinality (don't emit per-resource labels).

These are out-of-scope for this pilot.

## Verdict

**ACCEPT** — minimal-surface primitive with appropriate defensive design.
No SSRF / SQLi / RCE / XXE / path-traversal / TOCTOU vectors.
