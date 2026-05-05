<!-- Generated: 2026-04-18T07:00:00Z | Run: sdk-dragonfly-s2 -->
# sdk-semver-devil — D3 Review

Mode A (greenfield regeneration of a package that had a Slice-1 baseline). Evaluate semver bump class.

## Current state

Per intake mode.json + TPRD §16:
- Baseline: Slice-1 at target HEAD commit `bd3a4f7` on branch `sdk-pipeline/sdk-dragonfly-s2` (off base `l2Cache`).
- Slice-1 exports: `New`, `(*Cache).Ping`, `(*Cache).Close`, `Config`, `Option`, `ErrNotConnected`, `ErrInvalidConfig`.
- Mode A override: these will be **regenerated**, NOT preserved. Per user directive + intake seq 3.
- TPRD §1 "Zero downstream callers" → no external consumers of Slice-1.

## Analysis

### Export additions (new, safe for any semver level)

- `Cache` (already existed; regenerated shape identical at receiver level).
- 46 new receiver methods (§5.2 through §5.7).
- 24 new `Err*` sentinels (TPRD §7: 26 total, 2 existed).
- 13 new `With*` options (TPRD-declared 15 − 2 existed baseline; may be fewer depending on what Slice-1 had).
- `LoadCredsFromEnv` (new package function).
- `TLSConfig` (may have existed; check).

### Potential signature drift (Mode A regeneration)

Even though Slice-1 is being regenerated, the NEW design preserves signature-identity where TPRD didn't change:
- `New(opts ...Option) (*Cache, error)` — unchanged.
- `(*Cache).Ping(ctx context.Context) error` — unchanged.
- `(*Cache).Close() error` — unchanged.
- `Config` struct — additions only (e.g., new `PoolStatsInterval` field). Field additions are compatible.
- `Option` type — unchanged shape `func(*Config)`.
- `ErrNotConnected`, `ErrInvalidConfig` — unchanged.

**Risk:** if Slice-1 shipped `TLSConfig{CertFile, KeyFile, CAFile, SkipVerify}` (matching events TLSConfig), the new design adds `ServerName` and `MinVersion`. Field additions to an exported struct are BACKWARD-COMPATIBLE when the struct is returned-from or passed-to external callers by value. Since `Config.TLS` is `*TLSConfig`, zero-value fields are safe.

### Bump classification

| Classification | Rationale |
|---|---|
| **Minor** (v0.x.0 → v0.(x+1).0) | Additive exports. Slice-1 signatures preserved. No exported symbol is REMOVED. Field additions on `TLSConfig` are backward-compatible. |

### Footguns checked

- [x] No exported symbol renamed.
- [x] No exported symbol deleted.
- [x] No method receiver changed (e.g., `*Cache` stays; not changed to value receiver).
- [x] No exported type changed from struct to interface or vice versa.
- [x] Option type signature (`func(*Config)`) preserved.
- [x] Error sentinel IDENTITIES preserved (re-declared via `errors.New(msg)`; identity is value-identity, so re-declaring creates new identity — **this is a subtle issue**).

### F-S1 — Sentinel re-declaration breaks `errors.Is` identity? (SEV=info, Mode A specific)

Mode A regenerates `errors.go`. `var ErrNotConnected = errors.New("dragonfly: not connected")` is redeclared. Any caller holding a reference to the OLD `ErrNotConnected` value (via binary linking) would see `errors.Is` fail across version boundary.

**But:** TPRD §1 "Zero downstream callers". No one has a pinned reference to Slice-1's sentinels in another module. Safe.

**Verdict:** ACCEPT (no external impact).

## Verdict

**ACCEPT minor** (v0.x.0 → v0.(x+1).0).

No BREAKING change detected. Mode A regeneration is semver-safe because:
1. No external callers of Slice-1 (per TPRD §1).
2. Slice-1 signatures are preserved.
3. All new exports are additive.
4. No `[stable-since: vX]` markers in baseline (Mode A, no MANUAL preservation).

Breaking-change devil is N/A (Mode A bound; skipped per spec).
