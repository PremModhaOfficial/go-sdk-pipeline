<!-- Source: retro-impl P4 (OTel conformance test authored by testing-lead at T9, not by impl-lead at M6); retro-testing §Systemic Patterns -->
<!-- Confidence: HIGH -->
<!-- Run: sdk-dragonfly-s2 | Wave: F6 -->
<!-- Status: DRAFT — learning-engine (F7) decides whether to apply. Append-only to agent's ## Learned Patterns section. -->

## Learned Patterns

### Pattern: Static OTel conformance test in M6 Docs wave (shift-left)

**Rule**: During the M6 Docs wave, impl-lead MUST author a static (AST-based, no live exporter) OTel conformance test alongside godoc. The test MUST assert:

1. Every call site of the instrumentation helper (e.g., `instrumentedCall`, `runCmd`) passes a string-literal command name — never a runtime variable, struct field, or Config-derived string. This keeps span-name cardinality bounded at compile time.
2. Span attributes MUST NOT be drawn from a configured secret, credential, payload value, or user-supplied key. Maintain an explicit forbidden-attr allowlist in the test (e.g., `{"password","secret","token","key","value","payload"}`) and scan attribute literals.
3. Span names use a stable prefix tied to the client package (e.g., `dfly.<cmd>`, `s3.<op>`, `kafka.<op>`). Reject attribute names not in the OTel semantic-conventions subset the design phase declared.
4. Error recording routes through the package's otel wrapper (`motadatagosdk/otel`), not raw `go.opentelemetry.io/otel` calls. Grep-based check is sufficient; AST-based is preferred.

The test lives in `<pkg>/observability_test.go` and runs under `go test` with no build tag.

**How to author (M6)**:
1. Read the design's `observability.md` for declared invariants.
2. Use `go/ast` or `go/parser` to load the production .go files.
3. For each invariant, write a `TestObservability_<invariant>` function that scans AST nodes and asserts the rule.
4. Include negative seeds: a commented-out "// would violate" example to document intent.

**Evidence from sdk-dragonfly-s2**: impl-lead completed M6 without authoring a static OTel conformance test. `sdk-testing-lead` filled the gap in Phase 3 T9 with `observability_test.go` (270 LOC, 4 AST-based tests). Testing-lead self-resolved the gap rather than escalating as a BLOCKER (pragmatic for this run), but this is a skill-drift signal: conformance invariants are knowable from design artifacts and therefore belong in impl's owned test surface, not testing's.

### Pattern: M1 pre-flight MVS dry-run against target go.mod

**Rule**: At the very start of M1 (before any test-red file is written), run MVS simulation against a clone of the target's live `go.mod` for every new dep declared in `design/dependencies.md`. Compare resulting go.sum against the `dep-untouchable` list surfaced at H1/H6. If any forced bump violates the untouchable list, HALT and emit `DEP-BUMP-UNAPPROVED` BEFORE any test code is written.

**Evidence from sdk-dragonfly-s2**: The `DEP-BUMP-UNAPPROVED` escalation (testcontainers-go forcing otel × 3 + klauspost/compress) surfaced mid-wave M3 after red-phase tests were already committed. Pre-flight at M1 would have caught the same bumps before writing a single test line, preventing the mid-wave HALT.

**Note**: This pattern complements `sdk-design-lead`'s D2 MVS simulation pattern. Impl runs its own check because between D2 and M1 the user may have modified the `dep-untouchable` list (as happened in sdk-dragonfly-s2 where the "do not update untouched deps" directive landed at H6).

---

**Apply behavior**: learning-engine should append the above two subsections to the end of `.claude/agents/sdk-impl-lead.md` under a `## Learned Patterns` heading. Do NOT modify existing agent content. On apply, log `prompt-evolution-log.jsonl` entry with source-run `sdk-dragonfly-s2`, patch-id `PP-03-impl`, and the exact diff applied.
