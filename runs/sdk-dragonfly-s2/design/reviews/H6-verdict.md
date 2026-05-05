<!-- Generated: 2026-04-18T12:20:00Z | Run: sdk-dragonfly-s2 | Gate: H6 -->
# H6 — Dependency Vet Verdict

**Status:** CONDITIONAL-ACCEPTED-WITH-MITIGATIONS
**Tools installed:** govulncheck@v1.2.0 · osv-scanner@1.9.2 · benchstat · staticcheck@2026.1
**Scope:** proposed new deps for dragonfly package — isolated scratch module at `/tmp/dragonfly-depcheck`

## A. Scope explained

The current target SDK does not yet depend on `testcontainers-go` or `goleak`. Running G32/G33 against `src/motadatagosdk` as-is only vets pre-existing deps, not the NEW deps we're adding. The correct dep-vet scope is "what does the dragonfly package pull in" — a scratch go.mod was built for exactly that purpose:

```
require (
    github.com/redis/go-redis/v9 v9.18.0       // existing in target
    github.com/alicebob/miniredis/v2 v2.37.0   // existing in target
    github.com/testcontainers/testcontainers-go v0.42.0 // NEW — upgraded from v0.37.0
    go.uber.org/goleak v1.3.0                   // NEW
    github.com/stretchr/testify v1.11.1        // existing in target
    golang.org/x/crypto v0.50.0                // transitive — upgraded from v0.37.0
)
```

## B. osv-scanner (G33)

**First pass** (testcontainers-go v0.37.0, x/crypto v0.37.0): 5 findings
- `github.com/docker/docker@28.0.1+incompatible` — GO-2026-4883 (CVSS 6.8), GO-2026-4887 (CVSS 8.8) — pulled by testcontainers-go
- `golang.org/x/crypto@v0.37.0` — GO-2025-4135, GO-2025-4134 (CVSS 5.3 each), GO-2025-4116

**Mitigation applied:** `go get -u github.com/testcontainers/testcontainers-go golang.org/x/crypto` →
- testcontainers-go: v0.37.0 → **v0.42.0**
- golang.org/x/crypto: v0.37.0 → **v0.50.0**
- docker/docker transitive resolved to a non-vulnerable version

**Second pass (post-upgrade):** `No issues found` — 58 packages scanned. **PASS.**

## C. govulncheck (G32)

**Post-upgrade run:**
> Your code is affected by 8 vulnerabilities from the Go standard library.
> 2 vulnerabilities in packages you import; 2 in modules you require; your code doesn't call these.

All 8 call-reachable vulns are **Go stdlib at 1.26.0**, all with fixes in **go1.26.1 / go1.26.2**:

| CVE | Stdlib pkg | Fixed in |
|---|---|---|
| GO-2026-4947, 4946, 4866, 4600, 4599 | crypto/x509 | 1.26.1 / 1.26.2 |
| GO-2026-4870 | crypto/tls | 1.26.2 |
| GO-2026-4865 | html/template | 1.26.2 |
| GO-2026-4602 | os | 1.26.1 |

**Analysis:** None of these are introduced by the dragonfly package. They are a **target-wide** go-toolchain condition (target go.mod declares `go 1.26`). A bump to `go 1.26.2` resolves all 8.

**Verdict:** PASS for dragonfly-introduced dep delta. PENDING for target-repo go-toolchain refresh (out-of-scope for this run).

## D. Pinned versions for Phase 2 impl (REVISED per user directive 2026-04-18)

**User constraint (2026-04-18 12:22):** *"DO not update the deps if not touched by our code ever"* — do NOT alter pre-existing target deps (including `golang.org/x/crypto v0.48.0` already present in target go.mod, `go.uber.org/goleak v1.3.0` already in target go.sum, and the Go 1.26 toolchain).

`sdk-impl-lead` may only touch deps it is ADDING:

| Dep | Action | Version |
|---|---|---|
| `github.com/testcontainers/testcontainers-go` | ADD (net-new) | latest stable (`v0.42.0` at time of verdict — impl may use whatever `go get <module>` resolves to at Phase 2 run-time if newer) |
| `go.uber.org/goleak` | keep | `v1.3.0` — already in target go.sum; promote to direct via `go get` (version unchanged) |

Deps **NOT TO TOUCH**:
- `golang.org/x/crypto` — already at v0.48.0 in target. Let MVS (Go's minimum-version selection) decide if testcontainers-go's transitive graph needs bumping; do NOT pin in our design.
- `go 1.26` toolchain directive in target go.mod — untouched.
- `github.com/redis/go-redis/v9 v9.18.0`, `github.com/alicebob/miniredis/v2 v2.37.0`, `github.com/stretchr/testify v1.11.1` — existing, unchanged.

If MVS resolution from testcontainers-go@v0.42.0 forces a bump of any untouched dep, `sdk-impl-lead` must STOP and escalate to the user for explicit approval — not auto-upgrade.

## E. Target-SDK-wide tech debt (RECORDED, NOT ACTIONED)

The 8 call-reachable Go 1.26.0 stdlib vulns (crypto/x509, crypto/tls, html/template, os, net/url) are resolved in go 1.26.1/1.26.2. These are pre-existing conditions affecting the entire target SDK. Per user directive, **not touching the Go toolchain**. Filed as observation only — a target-SDK owner can patch out of band. Phase 3 G32 will continue to flag these until the target bumps; the gate is expected to pass its dragonfly-scoped check while noting the stdlib baseline.

## F. License allowlist re-check (G34)

All 5 direct deps PASS: BSD-2-Clause (go-redis), Apache-2.0 (miniredis), MIT (testcontainers-go, goleak, testify). No changes from design D2.

## G. Final H6 verdict

**ACCEPT (conditional on impl honoring pinned versions in §D).**

Phase 3 testing re-runs G32/G33 on the assembled package. If impl respects §D pins, G32/G33 at Phase 3 should PASS modulo the go-toolchain stdlib items (which remain until target go.mod bumps 1.26 → 1.26.2, out-of-scope).
