<!-- Generated: 2026-04-18T07:00:00Z | Run: sdk-dragonfly-s2 -->
# sdk-security-devil — D3 Review

Scope: TLS, credentials, logging, metrics/traces attrs, transport.

## Checked

### S-1. TLS config
**Design**: `TLSConfig{CertFile, KeyFile, CAFile, ServerName, SkipVerify, MinVersion}`. Default MinVersion = TLS 1.2; prefer 1.3. ServerName required unless SkipVerify (§9).
**Check**: `Config.validate()` design-stated rule: "reject SkipVerify=false && ServerName=='' when TLS is enabled".
**Gap**: stub `validate()` is a placeholder returning `nil`. Phase 2 must implement the check; flag as `[traces-to: TPRD-§9-TLS]` on `validate()`.
**Verdict:** ACCEPT (Phase 2 contract-to-enforce clearly stated).

### S-2. SkipVerify warning in prod
**Design**: §9 "validator warns" when TLS disabled or SkipVerify=true in prod.
**Check**: how does the SDK know "prod"? No env var defined. Design should say: log a `Warn` unconditionally (regardless of environment) and let operators filter. Adding env-sensitive logic introduces false sense of safety.
**Verdict:** ACCEPT-WITH-NOTE. Phase 2 impl: `logger.Warn(ctx, "dragonfly: TLS SkipVerify enabled — disable in production")` on `New()` return path when applicable. Likewise for `TLS == nil` (cleartext).

### S-3. Credential loader — path handling
**Design**: `LoadCredsFromEnv(userEnv, passPathEnv)` reads username direct + password from file.
**Risk A**: env-var injection — `passPathEnv` could point to `/etc/passwd`. Not our concern: caller controls env.
**Risk B**: file permissions — a world-readable password file indicates misconfig. Should `LoadCredsFromEnv` `stat()` the file and warn if mode & 0077 != 0? Possibly. Not required by TPRD but a good security-hardening lever.
**Verdict:** ACCEPT-WITH-NOTE. Recommend Phase 2 add a `logger.Warn` if `stat.Mode().Perm() & 0077 != 0` on the password file. File as feedback candidate.

### S-4. Trailing newline on password file
**Design**: §9 implies raw file contents. K8s secret files often have no trailing newline but file-based tooling may add one.
**Recommendation**: `LoadCredsFromEnv` SHOULD NOT trim whitespace by default — that would break passwords containing intentional trailing spaces. Document in godoc: "Password is file contents as-is; no trimming." Phase 2 must follow.
**Verdict:** ACCEPT-WITH-NOTE.

### S-5. No credentials in logs / spans / metrics
**Design**: §8.3 redaction rule ("never log Password, Username, key values, payloads"). §8.4 cardinality guard ("no label derived from user input").
**Check**: stub `instrumentedCall` uses only `cmd` (compile-time literal) and `error_class` (bounded set of 6). No user-input labels. Good.
**Check**: `span.SetAttributes` includes `server.address = c.cfg.Addr` — address is caller-provided, technically "user input" but bounded to a single value per `*Cache`. Low cardinality; acceptable.
**Gap**: `logger.Warn` on SkipVerify risk should NOT include the password path (could leak file paths mapping to K8s secret mounts → infra enumeration).
**Verdict:** ACCEPT-WITH-NOTE. Phase 2 impl reviewer must spot-check that no `Password` / `Username` / key arg / value arg reaches any `logger.*` / `span.SetAttributes` / `metrics.Labels`. This is a G-level concern — recommend a grep-based guardrail addition.

### S-6. `Cache.Client()` escape hatch
**Risk**: caller bypasses all instrumentation AND may subscribe/auth with the underlying client.
**Design**: `Cache.Client()` returns `*redis.Client` with the caller's credentials already applied (set in `New`). Caller cannot re-auth to a different user via `Client()` alone — they would need access to `rdb.Options()`. That's exposed by go-redis. Low-risk escape hatch: operator-instrumentation blind spot only, not a security boundary.
**Verdict:** ACCEPT.

### S-7. TLS private key material in memory
**Design**: `TLSConfig` holds file paths, not decoded `*x509.Certificate` or `crypto.PrivateKey`. Phase 2 loads them inside `New()` into a `tls.Config`, which holds them in process memory for the lifetime of the client.
**Standard practice**: acceptable. No pinning, no HSM integration — out of scope per §3.
**Verdict:** ACCEPT.

### S-8. Transport without TLS in non-prod
**Design**: §9 "Transport: plain TCP allowed in non-prod; validator emits warning log when TLS disabled."
**Check**: Phase 2 `New()` must emit `logger.Warn(ctx, "dragonfly: TLS disabled — use only in non-production")` when `cfg.TLS == nil`.
**Verdict:** ACCEPT (Phase 2 contract).

### S-9. ConnMaxLifetime rotation
**Design**: 10m default forces re-dial → fresh file-read. Good.
**Gap**: go-redis re-dials by calling the configured `Dialer` — which in v9 is called with the original address. If the password file changes, the re-dial must re-read it. Phase 2 impl: supply a `Dialer` closure that calls `LoadCredsFromEnv` afresh — OR accept that the password is latched at `New()` time.
**TPRD stance**: §9 "Re-dial reads file fresh."
**Implication**: Phase 2 MUST implement a re-reading Dialer OR design must document that rotation requires `New()` call (not just a TCP re-dial). This is a **real gap**.
**Verdict:** **NEEDS-FIX**. Amend `patterns.md` §P5 or `algorithms.md` with explicit Dialer re-read pattern, OR amend `dependencies.md` / `api.go.stub` godoc to note that `LoadCredsFromEnv` is called only at `New()`.

### S-10. RESP3 + AUTH order
**Design**: Protocol = 3 default. ACL username + password sent via `AUTH` after `HELLO 3`.
**Check**: go-redis handles this internally. No design-level action.
**Verdict:** ACCEPT.

## Summary

- **1 NEEDS-FIX** (S-9 — credential rotation semantic).
- 6 ACCEPT-WITH-NOTE (S-2, S-3, S-4, S-5, and by implication S-6, S-8 — contracts for Phase 2 impl reviewer to spot-check).
- 3 pure ACCEPT.

**Overall verdict:** NEEDS-FIX — one design artifact amendment.
