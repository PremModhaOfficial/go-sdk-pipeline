<!-- Source: retro-design P2 (MVS-forced bumps discovered at impl, not design); anomaly A2 (testcontainers-go MVS cascade caused DEP-BUMP-UNAPPROVED HALT); retro-impl §Surprises -->
<!-- Confidence: HIGH -->
<!-- Run: sdk-dragonfly-s2 | Wave: F6 -->
<!-- Status: DRAFT — learning-engine (F7) decides whether to apply. Append-only to agent's ## Learned Patterns section. -->

## Learned Patterns

### Pattern: MVS simulation against real target go.mod at D2 (not scratch module)

**Rule**: Before rendering any verdict on `dependencies.md`, the design phase MUST simulate Go Minimum Version Selection against a **clone of the live target go.mod** (not a scratch greenfield module). Enumerate every existing direct dependency whose pinned version would be bumped by adding the proposed new deps. Surface this list to H6 BEFORE the gate closes.

**How to run the check (D2 + H6 prep)**:
1. Clone target repo's `go.mod` + `go.sum` into a temp dir `runs/<run-id>/design/mvs-scratch/`.
2. For each proposed new dep in `dependencies.md`, run:
   ```
   go get <dep>@<version>
   go mod tidy -json > mvs-diff-<dep>.json
   ```
3. Diff the resulting `go.mod` against the target's current `go.mod`. Record every existing direct-dep bump in `design/mvs-forced-bumps.md` with: dep, current_pin, forced_pin, reason (transitive require chain).
4. Cross-reference the bumped list against any `dep-untouchable` policy surfaced at H1 (see "dep-policy at H1" pattern in sdk-intake-agent).
5. If any forced bump touches an `untouchable` dep, emit an ESCALATION labeled `DEP-POLICY-CONFLICT-AT-DESIGN` to the run-driver BEFORE H6. Do not wait for impl phase to discover it.

**Evidence from sdk-dragonfly-s2**: `testcontainers-go@v0.42.0` was proposed as a new dep at D2. The scratch-module MVS check at design time did NOT reveal that testcontainers-go transitively required otel `v1.41` while the target was pinned at `v1.39`. The forced bump (otel × 3 packages + klauspost/compress) was only discovered at impl wave M3, triggering `DEP-BUMP-UNAPPROVED` HALT and an unplanned H6 revision loop. Running MVS against a clone of the real target go.mod at D2 would have surfaced all four forced bumps before H6 ever opened.

**Anti-pattern**: Do NOT simulate against a scratch greenfield `go mod init` module. MVS results depend on the full existing require-graph; a scratch module has no pinned versions to clash with.

### Pattern: Cross-SDK convention-deviation recording

**Rule**: When `sdk-convention-devil` emits ACCEPT-WITH-NOTE for a deliberate deviation from an existing sibling-package pattern (e.g., dragonfly uses functional `With*` options while most target packages use `Config struct + New(cfg)`), the design-lead MUST record the deviation in `design/convention-deviations.md` with: sibling-package-comparison, rationale, precedent-setting-decision. This file feeds a future `docs/design-standards.md` synthesis.

**Evidence from sdk-dragonfly-s2**: Dragonfly is the first target package to use functional `With*` options alongside `Config`. Justified by alignment with `motadatagosdk/events`, but no cross-SDK design-standards doc exists to record this as a deliberate precedent. Phase 4 improvement-planner proposed creating `docs/design-standards.md` as a process change.

---

**Apply behavior**: learning-engine should append the above two subsections to the end of `.claude/agents/sdk-design-lead.md` under a `## Learned Patterns` heading. Do NOT modify existing agent content. On apply, log `prompt-evolution-log.jsonl` entry with source-run `sdk-dragonfly-s2`, patch-id `PP-02-design`, and the exact diff applied.
