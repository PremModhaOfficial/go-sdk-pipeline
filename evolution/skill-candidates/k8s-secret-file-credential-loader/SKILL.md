---
name: k8s-secret-file-credential-loader
version: 0.1.0-draft
status: candidate
priority: SHOULD
tags: [sdk, credentials, k8s, secrets, security]
target_consumers: [sdk-design-lead, sdk-impl-lead]
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §6, §9)
specializes: credential-provider-pattern
---

# k8s-secret-file-credential-loader

## When to apply
Any SDK client whose credentials (password, API key, TLS material) are delivered via K8s-mounted Secret files rather than env or Secrets Manager. Specializes `credential-provider-pattern`.

## Loader contract

```go
// LoadCredsFromEnv resolves (username, password) by reading file paths from
// environment variables. Username may be inline (ACL default user).
//
//   userEnvVar:       optional; if set, value is the username literal
//   passwdPathEnvVar: required; value is a FILE PATH whose contents = password
//
// Returns ErrInvalidConfig if passwdPathEnvVar unset or file unreadable.
// Trims ONE trailing newline (kubectl create secret appends LF).
func LoadCredsFromEnv(userEnvVar, passwdPathEnvVar string) (user, pass string, err error)
```

Rules:
1. Never log the password. Error messages: file path only.
2. Trim one trailing `\n` — K8s Secret files routinely have it.
3. Do NOT cache file contents inside loader. Re-read is cheap; cache defeats rotation.
4. No watcher goroutine. Rotation picks up via `ConnMaxLifetime` expiry triggering re-dial which calls loader again.

## TLS material loader

```go
// LoadTLSFromDir reads ca.crt, tls.crt, tls.key from a directory (K8s Secret
// mount). Returns *config.TLSConfig with all three paths populated; file
// existence verified once here (fail-fast). Actual TLS assembly is inside
// buildTLS at dial time.
func LoadTLSFromDir(dir string) (*config.TLSConfig, error)
```

Pattern: files at paths; SDK's `buildTLS` re-reads them at dial time (consistent with password flow).

## Rotation model

TPRD §9: `ConnMaxLifetime=10m` forces pool-level reconnect. On re-dial, go-redis re-invokes the `Dialer` (or, in this SDK's simpler model, the pool just re-establishes TCP+AUTH). Because AUTH credentials in `redis.Options` are captured by VALUE at `NewClient` time, naive rotation does NOT pick up new password.

Two acceptable designs:
- **A (TPRD P0)**: accept staleness up to `ConnMaxLifetime` + require process restart for credential change. Document the limitation in USAGE.md. Simple; no goroutines.
- **B (future)**: `redis.Options.CredentialsProvider` func — called on each dial. Better rotation. Not in P0 scope; flag as candidate for P1.

S2-S7 scope = A. If B becomes desired, TPRD revision needed — do NOT silently introduce the callback in this run.

## Security invariants
- Password file permissions: 0400 expected. Warn (log) if world-readable; never fail-closed (K8s tmpfs perms vary by node).
- Refuse to proceed if password file is empty (`ErrInvalidConfig`: `password file empty`).
- Never mix env-literal password with file-literal. Pick one. Env-literal allowed only in non-prod via explicit `WithPassword("...")`.

## Test matrix

- happy path: temp file with password; loader returns value minus trailing \n.
- unset env var → `ErrInvalidConfig`.
- missing file → `ErrInvalidConfig` with path in message.
- empty file → `ErrInvalidConfig`.
- file with no trailing newline → returned verbatim (no over-trim).
- file with 2 trailing newlines → trims one only.

## Anti-patterns
- Caching loader output in a package-global.
- fsnotify watcher introducing a goroutine in the loader.
- Logging the password value on any path.
- Returning the file descriptor to the caller.
- Auto-fallback to env-literal password when file path unset — silent insecure path.

## References
TPRD §6 (Config Surface), §9 (Security), existing `credential-provider-pattern` + `client-tls-configuration` skills.
