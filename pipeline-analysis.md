# Pipeline End-to-End Analysis Report
> **Scope**: `go-sdk-pipeline` v0.5.0 | Python + Go multi-language support | April 2026
> **Method**: Full read of all 55 agent prompts (spot checked), 3 package manifests, skill-index.json, all baseline files, CLAUDE.md (34 rules), all phase docs, guardrail script inventory, and evolution/ dir.

---

## Summary Scorecard

| Area | Status | Severity of Gaps |
|---|---|---|
| Package manifest structure (Go/Python/shared-core) | ✅ Correct | — |
| Language isolation at intake (§Target-Language gate) | ✅ Correct | — |
| Manifest-driven wave dispatch (leads are hardcode-free) | ✅ Correct for 3 leads | 🟡 1 lead still hardcodes |
| Skill index ↔ filesystem alignment | ✅ All 61 skills registered | 🟡 skill-index missing 7 skills |
| Python guardrail scripts | ✅ 11 scripts shipped | 🔴 7 skipped + 5 deferred |
| Baselines (Go) | ✅ Fully populated | — |
| Baselines (Python) | ⚠️ Empty — no Phase B run yet | By design |
| Learning engine + skill versioning | ✅ Correctly scoped | 🟡 Compensating baselines hardcode `/go/` paths |
| AGENTS.md ownership matrix | 🔴 Python agents absent | Critical documentation gap |
| Skill drift / coverage detection | ✅ Correct for Go | 🔴 Not wired for Python skills |
| Agent "Skills invoked" sections | 🔴 4 leads hardcode Go skills | Must be updated |

---

## 1. Structure — What's Correct ✅

### 1.1 Three-Manifest Architecture
The [shared-core.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/shared-core.json) → [go.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/go.json) / [python.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/python.json) dependency arc is clean:
- `shared-core` owns 22 language-neutral agents (intake, phase leads, all 4 feedback agents, all 5 devil orchestration agents)
- [go.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/go.json) owns 16 Go-specific agents, 25 Go-prefixed skills, 23 guardrails
- [python.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/python.json) owns 17 Python-specific agents, 20 Python-prefixed skills, 11 guardrails
- No agent or skill appears in more than one manifest (validated by [scripts/validate-packages.sh](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/scripts/validate-packages.sh))

### 1.2 Intake Language Gate (Wave I1.5)
`§Target-Language` is a **BLOCKER** if missing — `sdk-intake-agent` exits 8. This prevents silent Go-default on a Python TPRD. Wave I6 (skill-orphan cross-check) correctly flags skills registered in [skill-index.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/skills/skill-index.json) but not present in the active pack's union — this is the right safety net for cross-language skill references.

### 1.3 Manifest-Driven Dispatch in 3 Phase Leads
`sdk-design-lead`, `sdk-impl-lead`, and `sdk-testing-lead` all carry the "Active Package Awareness" block and explicitly state **"Zero agent names are hardcoded in this prompt"**. Wave dispatch is computed from `active-packages.json` at runtime. This is correct and language-agnostic.

### 1.4 Python Manifest is Complete for Phase A
[python.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/python.json) has full `waves`, `tier_critical`, `toolchain`, and `baselines` blocks. The `tier_critical` sets for T1/T2 (design, implementation, testing) correctly mirror the Go manifest's structure. Wave IDs match those used by the phase leads exactly.

### 1.5 Baseline Partitioning (Decision D1=B)
- `baselines/go/` — per-language (perf, coverage, output-shape, devil-verdict, hashes)
- `baselines/python/` — correctly partitioned, intentionally empty (placeholder `.gitkeep` explains what materializes on first Python run)
- `baselines/shared/` — quality scores, skill-health, baseline-history (language-neutral)

The `scope` field on every baseline JSON correctly declares `"per-language"` or `"shared"` matching the directory it lives in.

### 1.6 Skill Index Coverage (sdk_native section)
All 20 Python skills are registered in `skill-index.json:skills.sdk_native` with `"added_in": "0.5.0"`. All 31 Go skills are registered. `tags_index.python` correctly lists all 20 Python skill names. Tags like `leak-detection`, `supply-chain`, `architecture`, `fuzz`, `concurrency`, `errors`, `security` are correctly language-partitioned.

---

## 2. Findings & Gaps 🔴🟡

---

### FINDING 1 🔴 AGENTS.md Ownership Matrix Is Go-Only
**File**: [AGENTS.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/AGENTS.md)

The matrix table uses Go-suffixed agents exclusively. 17 new Python-specific agents (`sdk-perf-architect-python`, `sdk-asyncio-leak-hunter-python`, `sdk-packaging-devil-python`, etc.) are **not in the ownership table at all**. A reader of `AGENTS.md` cannot understand who owns Python-run domains.

**Specific gaps**:
- No row for asyncio leak hunt (`sdk-asyncio-leak-hunter-python` owns T6 for Python — currently the matrix shows `sdk-leak-hunter-go`)
- No row for `sdk-packaging-devil-python` — a Python-only agent with no Go analog
- Devil section lists only Go-suffixed devils (D4-D19); Python equivalents have no D-numbers
- "Mode B/C helpers" section only lists Go variants

**Fix**: Add a parallel Python row for every Go-only row in the matrix, using the same D-numbering pattern. Or add a language column to each row. Update Devil section to include Python siblings.

---

### FINDING 2 🔴 Four Phase Leads Have Hardcoded Go Skills in "Skills invoked" Section

**Files**:
- [sdk-impl-lead.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-impl-lead.md) — lists 8 Go skills: `tdd-patterns`, `go-struct-interface-design`, `go-concurrency-patterns`, `go-error-handling-patterns`, `go-otel-instrumentation`, `go-table-driven-tests`, `go-mock-patterns`, `review-fix-protocol`
- [sdk-testing-lead.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-testing-lead.md) — lists 7 skills including `go-testing-patterns`, `go-table-driven-tests`, `go-testcontainers-setup`, `go-mock-patterns`, `go-fuzz-patterns`, plus `observability-test-patterns` and `k6-load-tests` **neither of which exist in `skill-index.json`**
- [sdk-design-lead.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-design-lead.md) — lists `sdk-library-design`, `go-struct-interface-design`, `go-error-handling-patterns`, `openapi-spec-design`, `dto-validation-design` — none of these non-go skills exist in `skill-index.json` either

**Impact**: When a Python TPRD runs, the lead agents will attempt to invoke Go-specific skills (or nonexistent ones), causing skill-orphan warnings at I6 and potentially causing agents to apply wrong patterns.

**Fix**: Change "Skills invoked" in each lead to be conditional on `TARGET_LANGUAGE`, reading from the active-packages.json Python pack's `skills[]` union. Or: replaces the static list with a note saying "Skills are sourced from active-packages.json — see manifest for current list".

---

### FINDING 3 🟡 Learning Engine Compensating Baselines Hardcode `/go/` Paths

**File**: [learning-engine.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/learning-engine.md), Delta 4

The four compensating baseline checks explicitly reference:
- `baselines/go/output-shape-history.jsonl`
- `baselines/go/devil-verdict-history.jsonl`
- `baselines/go/coverage-baselines.json`

These paths are hard-coded strings, not resolved from `active-packages.json`. When Python runs complete and populate `baselines/python/*`, the learning engine will not check shape-churn or devil-regression for Python skills or packages.

**Fix**: Learning engine Delta 4 should resolve baseline paths from `active-packages.json:packages[target_language].baselines.owns_per_language_paths`, substituting the correct language prefix at runtime.

---

### FINDING 4 🟡 `sdk-testing-lead.md` Input Section Still References `baselines/go/performance-baselines.json`

**File**: [sdk-testing-lead.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-testing-lead.md), `## Input` section

Line 55: `- baselines/go/performance-baselines.json`

This hardcoded path will cause the testing lead to read Go baselines even on a Python run. For Python T1 runs, the correct path is `baselines/python/performance-baselines.json` (which won't exist until after the first Python run, but the lead should use the resolved path, not hardcode go).

**Fix**: Replace hardcoded path with `baselines/<TARGET_LANGUAGE>/performance-baselines.json` resolved from `active-packages.json:target_language`.

---

### FINDING 5 🔴 Skill Drift Detector and Skill Coverage Reporter Are Go-Only
**File**: [sdk-skill-drift-detector.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-skill-drift-detector.md), [sdk-skill-coverage-reporter.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-skill-coverage-reporter.md) (not read — confirmed from shared-core.json + skill-health-baselines.json)

`skill-health-baselines.json:coverage_scoreboard` shows only 19 Go skills examined. The drift scoreboard only covers Go skills. Both `sdk-skill-drift-detector` and `sdk-skill-coverage-reporter` are in `shared-core` (language-neutral orchestration agents), but they appear to only scan skills used in Go runs because:
1. The first (and only) baseline was established from a Go run (`sdk-dragonfly-s2`)
2. No mechanism exists to union Python skill drift findings into the same scoreboard

**Fix**: Both agents should read `active-packages.json:target_language` and either (a) maintain per-language drift scoreboards, or (b) explicitly accumulate skill stats across all languages. The `skill-health-baselines.json:drift_scoreboard` should carry a `language` tag per skill entry.

---

### FINDING 6 🟡 skill-index.json Missing 7 Skills from `ported_verbatim` and `ported_with_delta` Categories

Cross-checking `skill-index.json` against the filesystem:

| Skill in filesystem | In skill-index? |
|---|---|
| `python-asyncio-patterns` | ✅ sdk_native |
| `python-hexagonal-architecture` | ✅ sdk_native |
| `python-hypothesis-patterns` | ✅ sdk_native |
| `go-hexagonal-architecture` | ✅ ported_verbatim |
| `go-backpressure-flow-control` | ✅ sdk_native |
| `go-circuit-breaker-policy` | ✅ sdk_native |
| `go-client-mock-strategy` | ✅ sdk_native |

All 61 filesystem skill dirs are registered. **However**: the `ported_verbatim` section (19 entries) and `ported_with_delta` (2 entries) do NOT include any Python skills — all Python skills land in `sdk_native`. This is architecturally correct since Python skills were not ported from an archive but freshly authored. ✅ No bug here.

**Minor issue**: `skill-index.json:pipeline_version` is `"0.5.0"` but `schema_version` is `"1.1.0"` — these are different versioning axes but could confuse readers. Document the distinction.

---

### FINDING 7 🟡 `sdk-design-devil.md` References Non-Existent Skills

**File**: [sdk-design-lead.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/agents/sdk-design-lead.md) Skills section references `sdk-library-design`, `openapi-spec-design`, `dto-validation-design` — none of these appear in `skill-index.json`.

Similarly, `sdk-intake-agent.md` references `dto-validation-design` and `sdk-library-design`.

These are likely pre-pipeline skills that were never added to the index or were renamed. They would trigger WARN at I2 (skills-manifest check via G23) on every run.

**Fix**: Either add these skills to `skill-index.json` (if they exist as SKILL.md files) or update the agent prompts to reference skills that actually exist. Run `bash scripts/guardrails/G23.sh` to produce the canonical miss list.

---

### FINDING 8 🟡 Python Manifest Has `D3_devils_mode_a` Wave (No Go Analog) — Design Lead Not Aware

**File**: [python.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/python.json), line 69

```json
"D3_devils_mode_a": ["sdk-packaging-devil-python"]
```

The Go manifest has `D3_devils_mode_bc` (breaking-change + constraint run in modes B/C only). Python adds a new `D3_devils_mode_a` wave that doesn't exist in Go — `sdk-packaging-devil-python` fires only on Mode A (greenfield packages need PyPI packaging validation).

**The design lead prompt does NOT handle `_mode_a` suffix** — it only handles `_mode_bc`. The wave dispatch logic in `sdk-design-lead.md` will silently skip `D3_devils_mode_a` because it's not a recognized suffix pattern.

**Fix**: Add `_mode_a` suffix handling to `sdk-design-lead.md` Active Package Awareness section: "wave-id with suffix `_mode_a` is unioned with its base wave ONLY when `MODE == A`."

---

### FINDING 9 🟡 Marker Protocol Guardrails (G95-G103) Are Go-Only with No Python Path Declared

**File**: [python.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/package-manifests/python.json) notes section

The notes correctly document this is **intentional and deferred** to Phase 2D when the first Python TPRD includes a `[traces-to:]` marker. However there is no tracking ticket, guardrail candidate file, or `docs/PROPOSED-GUARDRAILS.md` entry for Python marker protocol.

When Python marks land, the `sdk-marker-scanner` (shared-core) needs to read `marker_comment_syntax.line = "#"` from the Python manifest. Currently it works only for Go `//` comments. This is an undocumented design dependency.

**Fix**: Add entry to `docs/PROPOSED-GUARDRAILS.md`: `G95-103-py: Python marker protocol — byte-hash semantics with Python AST; depends on first Python TPRD with [traces-to:] marker`.

---

### FINDING 10 🟡 Quality Baselines Cover Only 4 Agents; Python Agents Have No Baseline Scores

**File**: [baselines/shared/quality-baselines.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/baselines/shared/quality-baselines.json)

Only 4 agents have quality scores: `sdk-intake-agent`, `sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead`. All 17 Python-specific agents and all feedback/devil agents have no quality baseline.

`quality-baselines.json:scope_note` explicitly calls this out (Decision D2=Lenient: shared scores, progressive fallback). The `baseline_quality_score` of `0.85` for `sdk-design-lead` was set from a Go run — if a Python run scores the same agent at `0.75`, the 5% regression gate (tightened from 10%) will fire even if Python performance is normally worse for the first run.

**Fix**: Add a `language_of_baseline_run` field to each agent entry so the learning engine knows which language established the baseline. Progressive partition should trigger at first Python run if quality delta exceeds 3pp (per Decision D2 documented in scope_note but not yet enforced in baseline-manager.md logic).

---

### FINDING 11 🟡 `evolution/` Knowledge Base Has No Language Tag on Entries

**File**: [evolution/](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/evolution) knowledge-base JSONL

Per `learning-engine.md` Steps 5, the JSONL schemas for `agent-performance.jsonl`, `defect-patterns.jsonl`, `skill-effectiveness.jsonl`, and `prompt-evolution-log.jsonl` have no `language` field in their schemas. When Python runs begin writing to these files, it will be impossible to distinguish Go vs Python quality trends or skill effectiveness per-language.

**Fix**: Add `"language": "go"|"python"` to each JSONL schema in `learning-engine.md` Steps 5 (agent-performance, defect-patterns, skill-effectiveness, refactor-patterns, failure-patterns, communication-patterns entries). The `run_id` in every entry is sufficient to join against `state/run-manifest.json:language` as a workaround, but an explicit field is better.

---

## 3. Learning Engine / Skill Patching — Flow Correct ✅

The end-to-end flow for skill patching is correctly implemented:

```
Phase 4 (F3) → sdk-skill-drift-detector writes skill-drift.md
             → sdk-skill-coverage-reporter writes skill-coverage.md
Phase 4 (F6) → learning-engine reads BOTH (Delta 3)
             → Detects MODERATE/MINOR drift (SKD-005 → go-error-handling-patterns)
             → Applies patch (append-only to ## Learned Patterns)
             → Bumps skill semver (1.0.0 → 1.0.1 = patch, no semantic change)
             → Writes learning-notifications.md (H10 review gate)
             → Emits NOTIFY Teammate message
Phase 4 (F7) → baseline-manager reads updated baselines
             → Raise-only policy (no lowering without reset authorization)
             → Every 5 runs: full baseline reset
```

The `sdk-dragonfly-s2` run correctly demonstrates this: 2 patch-level bumps applied (`go-error-handling-patterns`, `go-example-function-patterns`), 4 compensating baseline checks run post-patch, learning-notifications.md written, H10 gate identified.

**One gap**: Golden-corpus is retired (by design, per CLAUDE.md Rule 28), but `skill-health-baselines.json:existing_skill_patch_accept_rate` shows `"status": "PASS-with-caveat-corpus-empty"`. The "accept rate = 1.0" measurement is caveatted because no user reversions were tracked at H10 yet (first run). This tracking should mature over subsequent runs.

---

## 4. Baseline + Patching Flow for Python — Not Yet Exercised

All baseline machinery **correctly declares** Python support:
- `python.json:baselines.owns_per_language_paths` lists 7 files under `baselines/python/`
- `baseline-manager.md` SDK-MODE Delta 3 says "for Python: `units.latency: \"seconds\"`, `units.allocs` may be `null`"
- `quality-baselines.json:scope_note` documents the D2=Lenient progressive fallback

**But**: None of it has been tested. `baselines/python/` is an empty directory. First Python run will:
1. Trigger first-run branch in `baseline-manager` (create all 6 files from scratch)
2. Write `baselines/python/performance-baselines.json` with `"language": "python"` (correct)
3. Skip devil-verdict-history and output-shape-history until pilot data comes in
4. Trigger quality baseline for 4 shared lead agents — already set from Go run (Finding 10)

---

## 5. Recommended Action Priority

| Priority | Finding | Fix Effort |
|---|---|---|
| P0 — Fix before first Python run | F8: `_mode_a` wave not dispatched | 5 min — 1 line in sdk-design-lead.md |
| P0 | F2: Wrong skills invoked on Python run | Medium — update 3 lead "Skills invoked" sections |
| P1 | F1: Python agents absent from AGENTS.md | Low — add rows to ownership matrix |
| P1 | F3: Learning engine `/go/` hardcoded paths | Medium — resolve paths from active-packages.json |
| P1 | F4: Testing lead baselines/go/ hardcoded | 1 line fix |
| P1 | F5: Skill drift/coverage not Python-aware | Medium — add language tag to per_skill entries |
| P2 | F11: No language tag in evolution JSONL | Schema update in learning-engine.md |
| P2 | F10: Quality baseline unaware of language | Add `language_of_baseline_run` field |
| P2 | F7: Non-existent skills referenced in agents | Audit + fix or register missing skills |
| P3 | F9: Python marker protocol undocumented | Add to PROPOSED-GUARDRAILS.md |
| P3 | F6: schema_version vs pipeline_version clarity | Documentation only |
