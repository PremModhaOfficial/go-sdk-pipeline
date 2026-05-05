<!-- Generated: 2026-04-27T00:02:01Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Reviewer: sdk-security-devil (READ-ONLY) -->

# Security-Devil Findings — `motadata_py_sdk.resourcepool`

Paranoid security review of the design. Look for: secret/credential paths, deserialization of untrusted input, PII paths, supply-chain risk, attack surface from caller-provided code (hooks).

## Verdict: ACCEPT WITH ATTACK-SURFACE NOTE

---

## SD-001 — ACCEPT WITH NOTE: hook execution is caller-trusted code

**Where**: `api-design.md` §3.1 Pool — accepts `on_create`, `on_reset`, `on_destroy` callables from the caller.

**Observation**: Hooks run in the pool's event loop, holding the GIL (well, holding the event-loop time-slice). A malicious or buggy hook can:
1. Block the event loop (sync hook with long CPU work or sync blocking I/O).
2. Raise arbitrary exceptions (handled per the documented policy: ResourceCreationError wrap, destroy-then-skip, log-and-swallow).
3. Mutate process-global state (since they run in-process).
4. Access any object the caller has reachable (no sandboxing).

**Mitigation already present**:
- TPRD §3 Non-Goal explicit: "no sync-callable hook coercion via asyncio.to_thread() magic" — caller is in control.
- TPRD §9 Security: "No secrets/credentials are pool-handled — caller's responsibility per on_create."
- The pool does NOT log resource bodies (logs only the pool name + error type).
- The pool does NOT serialize or pickle resources.

**Risk classification**: ACCEPT. Hooks are caller-supplied code; the pool cannot defend against caller-malicious code without sandboxing (out of scope for any Python library). Document the boundary explicitly in Pool's docstring under a "Security Model" section (recommendation, not a fix).

**Recommendation for impl phase**: add a "Security Model" section to Pool's docstring noting hooks run in caller-trust boundary.

---

## SD-002 — Checked: deserialization of untrusted input

The pool accepts `T` (caller-typed resource) and stores it in a deque. No serialization, no JSON parsing, no pickle, no msgpack, no XML. ✓

If the caller's `on_create` returns a deserialized object from untrusted input, that's the caller's responsibility (and out of scope per TPRD §9).

PASS.

---

## SD-003 — Checked: PII paths

Pool data flows:
- `config.name: str` — caller-supplied; logged in error messages. NOT a credential vector.
- `T` resource body — never logged, never serialized.
- Counters (`_created`, `_in_use`, `_waiting`) — integers; no PII.
- `_closed: bool` — no PII.

No PII paths. PASS.

---

## SD-004 — Checked: supply chain (pip-audit / safety)

TPRD §4: "External deps for the package: zero — stdlib only." Verified by patterns.md §11 (pyproject.toml `dependencies = []`). Dev deps under `[project.optional-dependencies] dev = [...]` are not shipped at install.

Action item for impl phase + testing phase:
- `pip-audit` MUST run clean against `pyproject.toml` (no direct deps → trivially clean).
- `safety check --full-report` MUST run clean (same).

PASS.

---

## SD-005 — Checked: credential hygiene (G69)

Searched the design files for `password`, `secret`, `token`, `api_key`, `key=`, `credential`, `auth=`. Zero matches. The TPRD's `Appendix A` example uses `make_client` and `https://example.com` — no creds.

The `safety check` and `pip-audit` references in §4 are tooling commands, not credentials. ✓

PASS.

---

## SD-006 — Checked: race-condition + TOCTOU

- Pool's lock-protected critical sections: identified in concurrency-model.md §2 + algorithm.md §3.
- No TOCTOU between `_idle.pop()` and counter mutations — both inside same lock acquisition.
- The `_closed` flag is set inside the lock at aclose start; subsequent `if self._closed:` reads under or outside the lock both observe the latest write (single-event-loop + GIL byte-write atomicity).
- `try_acquire` reads `_closed` and `_idle` without the lock — relies on single-event-loop invariant. Documented + tested.

No security-relevant races found. PASS.

---

## SD-007 — Checked: denial-of-service surface

Could a caller crash the pool by:
1. Raising in every `on_create`? → ResourceCreationError per acquire; `_created` not incremented. Pool stays usable indefinitely.
2. Spawning 1M acquirers? → Bounded by event loop; each parks in Condition.wait(); memory grows linearly with `_waiting`. Caller-side responsibility.
3. Calling `pool.aclose()` while many acquirers are parked? → All wake via `notify_all`; receive PoolClosedError; clean shutdown.
4. Calling `pool.aclose()` recursively from inside on_destroy? → Idempotent; second aclose returns immediately.

No DoS vector intrinsic to the pool. PASS.

---

## Final verdict: ACCEPT

One ACCEPT-WITH-NOTE: hooks run in caller trust boundary; recommend impl phase add a "Security Model" section to Pool's docstring. No blockers; no fixes required at design phase.
