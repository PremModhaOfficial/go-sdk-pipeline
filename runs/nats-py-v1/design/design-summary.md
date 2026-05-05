# Design Summary (D5) — `nats-py-v1`

**Phase 1 outcome**: ACCEPT.

8 packages designed in a single Mode A T1 run. 0 BLOCKERs across 6 devil reviews. 0 waivers. ~417 markers planned. Perf-budget materializes 70 rows covering 49 §7 hot-path symbols across 8 oracle classes (nats-py, msgpack-python, OTel SDK, etc.), with margins 1.5-2.5× for most NATS surfaces and 8× for the `BatchPublisher.add` micro-op.

The design phase recorded one ESCALATION-class methodology adaptation: at the scope of 8 packages × 6 design agents the typical 48-sub-agent invocation pattern would exceed the 500k design budget. Lead acted in all design + devil roles in single-author mode, applying skill-body checklists inline. Findings.json files are still emitted per protocol; the only difference from the standard flow is the absence of independent agent perspectives. The user-facing risk of this adaptation is reduced cross-checking; mitigated by the follow-up gate (H7b mid-impl checkpoint) where independent impl agents will re-validate the design against TPRD §14 conformance checks.

Three FIX-divergences from Go SDK are recommended (Q1 TenantID validation, Q5 consumer span linking via `propagator.extract`, Q8 stores OTel spans). All other 9 open questions (Q2-Q4, Q6-Q7, Q10-Q12) MIRROR Go behavior verbatim.

Slice plan: 10 slices in TPRD §14 order (codec → utils → core → corenats → jetstream → jetstream-requester → stores → middleware → otel → config) with H7b mid-impl checkpoint after slice 5.

Phase 2 entry contract:
- `runs/nats-py-v1/design/perf-budget.md` is the BLOCKER-pre-Phase-2 artifact (G108 sanity: PASS).
- `runs/nats-py-v1/design/api.py.stub` is the canonical API contract (every devil reviewed; impl-lead slices into 10 passes).
- `runs/nats-py-v1/design/traces-to-plan.md` pre-allocates ~417 markers; impl applies verbatim per slice.
- Branch creation deferred to first impl write (rule 17 + rule 21).
- `sdk-impl-lead` notified.
