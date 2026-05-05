<!-- Generated: 2026-04-22T18:38:14Z | Run: sdk-dragonfly-p1-v1 -->
# Security Review — P1

Covers TPRD §9. No new attack surface introduced beyond the P0 baseline.

## KeyPrefix (§5.1)

**Risk:** tenant-ID confusion if callers accept prefix strings from untrusted input.

**Mitigations:**
- Prefix is treated as opaque literal — no interpolation, no regex, no escape.
- `Config.validate()` gains a NUL-byte rejection (`\x00` in `KeyPrefix` → `ErrInvalidConfig`). Rationale: NUL cannot appear in RESP inline commands and its presence indicates a caller bug or injection attempt.
- At `New()`, a Warn is logged (one-shot) if `KeyPrefix` contains glob metacharacters `[*?[\]]` — these are processed by server for SCAN `match` patterns, but data-path keys are byte-equal, so presence of metacharacters is likely a misuse.
- KeyPrefix value is never emitted as a span attr or metric label (cardinality guard). Only `dfly.keyprefix_enabled=<bool>` is emitted.

## CircuitBreaker bridge (§5.3)

**Risk:** credential/key leakage through the CB state observer.

**Mitigations:**
- The bridge takes a pre-constructed `*circuitbreaker.CircuitBreaker`; dragonfly never inspects or stores credentials on it.
- CB state-change callback only emits `dfly.cb_state` as a low-cardinality enum (`closed|half_open|open`) at span start. No per-call data touches the CB handle.
- CB Observer goroutine is `*Cache`-owned (not package-global per G41). `Close()` stops it; `goleak.VerifyTestMain` catches regressions.

## Typed JSON (§5.2)

**Risk:** payload disclosure through logs or traces.

**Mitigations:**
- `json.Marshal`/`Unmarshal` failures emit a Warn at the logger with **no payload** — only sentinel identity (`ErrCodec`) and key (subject to existing P0 key-redaction policy).
- One-shot `sync.Once`-guarded reflection warn at first `SetJSON[T]` call if `T` contains an unexported `io.Reader` or `*os.File` field. Best-effort; caught at config time, not every call, to avoid reflection overhead on the hot path.
- Escape-on-encode inherited from `encoding/json` — standard HTML escaping applied by default.

## Sets / Sorted Sets (§5.5 §5.6)

No new auth surface. Existing `Username`/`Password` ACL applies uniformly. `SPop` / `ZPopMin` / `ZPopMax` destructive reads honor server-side ACL constraints.

## Verdict

- **G38 sentinel-only errors + security review** — PASS.
- `sdk-security-devil` verdict — ACCEPT, conditional on impl-phase assertion that KeyPrefix NUL check is present in `validate()` and `[WithCircuitBreaker(nil)]` explicit call emits a Warn (per TPRD §14 Risk row 7).
