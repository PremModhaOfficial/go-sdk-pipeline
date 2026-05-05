<!-- Generated: 2026-04-22T18:38:13Z | Run: sdk-dragonfly-p1-v1 -->
# Dependency Vetting — P1

## Third-party deps

**Zero new third-party deps introduced.** TPRD §4 confirms this. Existing `go-redis/v9 v9.18.0` and `miniredis/v2 v2.37.0` carry forward. `govulncheck`/`osv-scanner` re-scan at G32/G33 is a pass-through of P0 results.

## Internal dep graph

| Consumer  | Dep                                              | Use                                      |
|-----------|--------------------------------------------------|------------------------------------------|
| dragonfly | `motadatagosdk/core/circuitbreaker`              | `WithCircuitBreaker` bridge §5.3         |
| dragonfly | `motadatagosdk/otel/tracer`                      | spans (existing P0 usage)                |
| dragonfly | `motadatagosdk/otel/metrics`                     | counters/histograms (existing P0 usage)  |
| dragonfly | `motadatagosdk/otel/logger`                      | warn logs (existing P0 usage)            |
| dragonfly | `motadatagosdk/utils`                            | `ErrCircuitOpen` re-export bridge        |

**TPRD §4 discrepancy:** TPRD claims `motadatagosdk/core/codec` as an internal dep. P1 does NOT import `core/codec` — the TPRD's §5.2 references a `codec.JSON` symbol that does not exist in the package (which is a variable-width binary packer, not a JSON encoder). P1 uses `encoding/json` directly, consistent with TPRD §9's own description "codec.JSON uses encoding/json under the hood". Net effect: one fewer internal dep than TPRD claims. See `extension/ownership-map.json § tprd_discrepancies_noted` for the full record.

## Verdict

- **G32 govulncheck** — passthrough; no new deps to scan in P1.
- **G33 osv-scanner** — passthrough; no new deps.
- **G34 license allowlist** — passthrough; existing deps already MIT / Apache-2.0 / BSD.
- **`sdk-dep-vet-devil` verdict** — ACCEPT.
