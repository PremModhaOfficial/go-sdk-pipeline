# Evolution Log — review-fix-protocol

## 1.0.0 — bootstrap-seed — 2026-04-17
Initial wrapper; protocol reused verbatim.

## 1.1.0 — deterministic-first-gate — 2026-04-20
Added the deterministic-first gate between fix-agent batch completion and reviewer-fleet re-run.

**Change**: Step 3f now branches on guardrail result. BLOCKER-level script-driven checks (go build/vet/fmt/staticcheck, -race, goleak, govulncheck/osv-scanner, marker byte-hash, constraint bench proofs, license allowlist) gate the expensive reviewer fleet.

**Behavior**:
- Guardrails fail BLOCKER → synthesize as findings (prefix `GR-<Gxx>-<iter>`), route to fix agents, skip reviewer fleet this iteration.
- Guardrails green → reviewer fleet re-runs (unchanged from 1.0.0).
- WARNING-only failures do not gate.

**Invariant preserved**: Rule 13 (Post-Iteration Review Re-Run) still holds — every iteration whose output a reviewer would meaningfully evaluate gets reviewed. Iterations skipped by the gate have known mechanical defects that would dominate reviewer findings and get superseded on the next iteration anyway.

**Why this is a free win**: reviewer-fleet spawn costs are multiplicative (N reviewers × full-artifact input × per-agent logging). Gating on deterministic PASS avoids paying for reviews of code that doesn't compile. Savings track with the fraction of iterations that introduce a mechanical regression (~30–40% in typical runs).

**Rollback**: set `deterministic_gate_enabled: false` in run manifest to restore 1.0.0 behavior. Phase lead may override per-run for determinism-sensitive experiments.
