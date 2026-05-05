# Waivers (D5) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead`.
**Purpose**: per CLAUDE.md `review-fix-protocol`, BLOCKER-severity findings unaddressed in the fix loop must be either RESOLVED or formally WAIVED here with rationale before H5 sign-off.

## Status

**No waivers.** All 6 devil reviews returned ACCEPT or ACCEPT-WITH-NOTES (no BLOCKER findings). All NOTE-severity findings are documented inline (api.py.stub, scope.md, dependencies.md). All WARN findings have explicit resolutions in the corresponding `reviews/<devil>.findings.json`.

## Future-fix backlog (NOT waivers — non-blocking issues for v0.2+)

Issues identified during D2 self-review that are explicit MIRROR-of-Go behavior (per scope.md §Open Questions). These are NOT waivers since they pre-existed the design; logged for future runs:

1. `Subscriber.unsubscribe` actually drains (Q11) — preserved for byte-API parity.
2. `Requester.close` does NOT delete ephemeral consumer (Q12) — relies on server inactive_threshold.
3. `BatchPublisher.add` size-trigger drops caller ctx (Q12 sub).
4. `JsPublisher.publish_async` no pre-validation, unbounded concurrency (Q11 sub).
5. `Stream.duplicates=120s` hard-coded (INV-8).
6. Span ID 32-hex (Q4) — non-W3C-standard.
7. `messaging.destination` deprecated semconv key (Q7).

These will be revisited at v0.2.0 planning, possibly with cross-language coordination at the Go side.
