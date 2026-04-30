# Multi-language pipeline — remaining work

Status as of 2026-04-28.

Steps 1–12 of the structure-finalization plan are **complete** (manifest schema lock, intake §Target-Language requirement, manifest-driven phase-lead dispatch, `run-toolchain.sh` + `run-guardrails.sh` dispatchers wired into G30/G41/G60, schema stamps for forward-compat, validator expansion, AST-hash README per-language rules contract, narrative cleanup, and D6=Split rewrite of 4 debt-bearer agents). `validate-packages.sh` is green.

**Item 1 — DONE 2026-04-28.** Convention applied: agents `-go` suffix, skills `go-` prefix (per `docs/PACKAGE-AUTHORING-GUIDE.md` § Naming convention rule 2 and 3, corrected in this pass — earlier draft of this doc said skills also use suffix, which contradicted the table on line 179 and the existing 25 prefix-shaped go-pack skill names). 16 agents and 17 skills renamed; `goroutine-leak-prevention` kept as-is since `goroutine-` already encodes Go (rule 4). 79 files modified across `.claude/`, `docs/`, `scripts/`, `phases/`, `commands/`, `CLAUDE.md`, `AGENTS.md`, `improvements.md`, `PIPELINE-OVERVIEW.md`, `AGENT-CREATION-GUIDE.md`, `SKILL-CREATION-GUIDE.md`, `LIFECYCLE.md`. 416 substitutions. `validate-packages.sh` green. Historical planning docs (`multi-lang-pipeline-strategy.md`, `multi-lang-plan.md`, this file's pre-update FROM list) intentionally not swept.

**Item 2 (Python authoring) remains** before the pipeline is fully multi-language.

---

## Item 1 — Fork rename for go-pack agents + skills *(DONE 2026-04-28)*

**Why**: per the naming convention locked in Step 11 (`docs/PACKAGE-AUTHORING-GUIDE.md` § "Naming convention for language-specific artifacts"), language-specific artifacts must carry a language tag — `-go` suffix for agents, `go-` prefix for skills. Today's go-pack agents and skills were authored before the convention existed; they need renaming so Phase B Python siblings (`-python` agents, `python-` skills) sit symmetrically.

**Out-of-scope**: agents in `shared-core` (orchestrators stay generic, no suffix). The 4 D6=Split debt-bearer agents (`sdk-design-devil`, `sdk-overengineering-critic`, `sdk-semver-devil`, `sdk-security-devil`) stay in `shared-core` with no suffix.

### 1A — Rename 16 agents in `go.json`

```
.claude/agents/code-reviewer.md                    → code-reviewer-go.md
.claude/agents/documentation-agent.md              → documentation-agent-go.md
.claude/agents/refactoring-agent.md                → refactoring-agent-go.md
.claude/agents/sdk-api-ergonomics-devil.md         → sdk-api-ergonomics-devil-go.md
.claude/agents/sdk-benchmark-devil.md              → sdk-benchmark-devil-go.md
.claude/agents/sdk-breaking-change-devil.md        → sdk-breaking-change-devil-go.md
.claude/agents/sdk-complexity-devil.md             → sdk-complexity-devil-go.md
.claude/agents/sdk-constraint-devil.md             → sdk-constraint-devil-go.md
.claude/agents/sdk-convention-devil.md             → sdk-convention-devil-go.md
.claude/agents/sdk-dep-vet-devil.md                → sdk-dep-vet-devil-go.md
.claude/agents/sdk-existing-api-analyzer.md        → sdk-existing-api-analyzer-go.md
.claude/agents/sdk-integration-flake-hunter.md     → sdk-integration-flake-hunter-go.md
.claude/agents/sdk-leak-hunter.md                  → sdk-leak-hunter-go.md
.claude/agents/sdk-perf-architect.md               → sdk-perf-architect-go.md
.claude/agents/sdk-profile-auditor.md              → sdk-profile-auditor-go.md
.claude/agents/sdk-soak-runner.md                  → sdk-soak-runner-go.md
```

For each rename:
1. `git mv .claude/agents/<old>.md .claude/agents/<old>-go.md`
2. Edit the new file's frontmatter `name:` field to match the new filename
3. Edit the new file's `description:` field if it self-references (some do)

### 1B — Rename skills in `go.json` *(EXECUTED — skills get `<lang>-` PREFIX, not suffix)*

This section originally specified `-go` suffix for skills. Corrected at execution time: skills get a `go-` prefix per `docs/PACKAGE-AUTHORING-GUIDE.md` § Naming convention, table line 179, and the existing 25 prefix-shaped go-pack skill names. Agents still get `-go` suffix.

**Skills already prefixed `go-*` — KEPT, no rename (7 skills):**
```
go-concurrency-patterns        go-example-function-patterns    go-module-paths
go-dependency-vetting          go-hexagonal-architecture       go-struct-interface-design
go-error-handling-patterns
```

**`goroutine-leak-prevention` — KEPT, no rename.** `goroutine-` already encodes Go; no double-tag (per § Naming convention rule 4).

**Skills clearly Go-coupled in body — RENAMED with `go-` prefix (11 skills):**
```
.claude/skills/client-mock-strategy/         → go-client-mock-strategy/
.claude/skills/client-shutdown-lifecycle/    → go-client-shutdown-lifecycle/
.claude/skills/connection-pool-tuning/       → go-connection-pool-tuning/
.claude/skills/context-deadline-patterns/    → go-context-deadline-patterns/
.claude/skills/fuzz-patterns/                → go-fuzz-patterns/
.claude/skills/mock-patterns/                → go-mock-patterns/
.claude/skills/sdk-config-struct-pattern/    → go-sdk-config-struct-pattern/
.claude/skills/sdk-otel-hook-integration/    → go-sdk-otel-hook-integration/
.claude/skills/table-driven-tests/           → go-table-driven-tests/
.claude/skills/testcontainers-setup/         → go-testcontainers-setup/
.claude/skills/testing-patterns/             → go-testing-patterns/
```

**6 skills with neutral concept but Go-coupled body — RENAMED with `go-` prefix (D1=A applied):**
```
.claude/skills/otel-instrumentation/         → go-otel-instrumentation/
.claude/skills/client-tls-configuration/     → go-client-tls-configuration/
.claude/skills/client-rate-limiting/         → go-client-rate-limiting/
.claude/skills/credential-provider-pattern/  → go-credential-provider-pattern/
.claude/skills/backpressure-flow-control/    → go-backpressure-flow-control/
.claude/skills/circuit-breaker-policy/       → go-circuit-breaker-policy/
```

### 1C — Update manifests

After renames, edit `.claude/package-manifests/go.json`:
- `agents` array — replace each old name with new `-go` name
- `waves.<wave-id>` arrays — same
- `tier_critical.<phase>.<tier>` arrays — same
- `skills` array — update the renamed entries

### 1D — Sweep cross-references (~150 files)

For each renamed agent or skill, run:
```bash
grep -rln "\b<old-name>\b" --include='*.md' --include='*.json' --include='*.yaml' --include='*.sh' \
    .claude/ docs/ scripts/ CLAUDE.md AGENTS.md README.md improvements.md 2>/dev/null
```
Then `sed -i 's/\b<old-name>\b/<old-name>-go/g' <files>` on the matches.

**EXCLUDE from sweep** (historical artifacts, must NOT be retroactively rewritten):
- `runs/` — old per-run state references the names that existed at that run's time
- `evolution/` — historical evolution reports
- `baselines/` — historical event logs
- `.git/` — obvious

### 1E — Verify

```bash
bash scripts/validate-packages.sh    # must PASS
git diff --stat                      # spot-check the sweep didn't catch unintended matches
```

Estimated effort: **2–3 hours** for the sweep + a careful review pass.

---

## Item 2 — Python authoring (Task #14)

**Why**: `python.json` ships in v0.5.0 Phase A as scaffolding only — empty `agents`, `skills`, `guardrails` arrays. Phase B authors the content so a real Python TPRD can run end-to-end.

### 2A — Foundations (B-1) — ~6 files, low-risk

These are mechanical / contract work. Can be done before any Python idiom decisions.

```
scripts/ast-hash/python-backend.py             # Use stdlib `ast` module; canonicalize per Step 10's open-questions answers (docstrings? type hints? decorators? async-vs-sync?)
scripts/ast-hash/python-symbols.py             # Symbol-presence scanner (analog of go-symbols.go)
scripts/ast-hash/README.md                     # Add "## Python backend" subsection; answer the 4 canonicalization questions explicitly
.claude/package-manifests/python/conventions.yaml   # Mirror of go/conventions.yaml — per-debt-bearer overlays for sdk-design-devil, sdk-overengineering-critic, sdk-semver-devil, sdk-security-devil. Use Python idiom names (asyncio.Task, dataclass, __repr__, hmac.compare_digest, etc.).
.claude/package-manifests/python/README.md     # Pack overview + how to add Python-specific agents
docs/PACKAGE-AUTHORING-GUIDE.md                # Add "Phase B Python authoring checklist" section
```

### 2B — Python pack agents (B-2)

Authoring rule: **Python pack agents are independent agents, not 1:1 mirrors of the Go pack.** Three categories below.

Earlier drafts of this doc framed Wave B-2 as "16 mirror agents" with a `<go-name>-python` rename per row. That framing is too rigid:

- Some Go-pack agents have Python-idiomatic names that differ from a mechanical `-python` suffix (e.g., `sdk-leak-hunter-go` → `sdk-asyncio-leak-hunter-python` because the noun is "asyncio task leak", not "goroutine leak").
- Some Go-pack agents transfer cleanly with the same role and a generic name.
- Some Python concerns have NO Go counterpart (PEP 517 packaging, type-stub `.pyi` coverage, `py.typed` marker) and warrant Python-only agents.
- Some Go-pack agents may have NO Python counterpart needed at v0.5.0 (revisit during pilot).

#### Category A — Mirror with same name (role + name transfer cleanly)

These have generic, language-neutral roles and names. Author with same name + `-python` suffix; body is fresh Python content (not a translation of the Go body).

| Agent | Wave | Python-flavor notes |
|---|---|---|
| `code-reviewer-python` | M7 | PEP 8 / 257 / 484+ idioms · *(SHIPPED)* |
| `documentation-agent-python` | M6 | PEP 257 docstrings + Google style + doctest *(SHIPPED)* |
| `refactoring-agent-python` | M5 | mypy/ruff/pytest verification chain *(SHIPPED)* |
| `sdk-api-ergonomics-devil-python` | M7 | first-user audit; async-context-manager protocol *(SHIPPED)* |
| `sdk-benchmark-devil-python` | T5 | pytest-benchmark JSON delta vs baseline |
| `sdk-breaking-change-devil-python` | D3 (Mode B/C) | diffs public API via `inspect` / `griffe` |
| `sdk-complexity-devil-python` | T5 | scaling sweep via `@pytest.mark.parametrize(N=[10,100,1k,10k])` |
| `sdk-constraint-devil-python` | D3 + M4 | constraint-bench proofs via pytest-benchmark |
| `sdk-convention-devil-python` | D3 | PEP 8 / 257 / 484+, pyproject.toml conformance |
| `sdk-dep-vet-devil-python` | D3 | pip-audit, safety, license allowlist |
| `sdk-existing-api-analyzer-python` | I3 (Mode B/C) | introspect existing `motadatapysdk` packages |
| `sdk-integration-flake-hunter-python` | T3 | pytest-repeat `--count=3` |
| `sdk-perf-architect-python` | D1 | py-spy + scalene units (seconds, MB) |
| `sdk-profile-auditor-python` | M3.5 | py-spy / scalene profile parsing |
| `sdk-soak-runner-python` | T5.5 | pytest soak with state-file polling |

#### Category B — Mirror with Python-idiomatic rename (role transfers, name does not)

The Go name encodes a Go-only concept; Python's analog uses a different noun.

| Go name | Python rename | Reason |
|---|---|---|
| `sdk-leak-hunter-go` | `sdk-asyncio-leak-hunter-python` | "Goroutine leak" → "asyncio task leak"; the Python primary concern is `asyncio.Task` lifetime, not generic leaks. Secondary: HTTP sessions, file handles, threads. *(SHIPPED)* |

Add to this table when other agents' rename emerge during authoring. Renames are surfaced in the agent's startup-protocol decision-log entry.

#### Category C — Python-only agents (no Go counterpart needed)

Python's packaging, typing, and async stories surface failure modes the Go pack doesn't have. These agents are authored fresh; no Go template exists.

| Agent | Wave | Why no Go counterpart |
|---|---|---|
| `sdk-packaging-devil-python` | D3 (Mode A) + M9 | PEP 517/518/621 pyproject.toml validation; wheel + sdist correctness; namespace package handling (PEP 420); console-script entrypoints; optional-deps `extras_require` semantics. Go has none of this — `go.mod` is the entire packaging story. |
| `sdk-stub-coverage-devil-python` *(optional, Phase B-2.5)* | M7 | If the SDK ships separate `*.pyi` stub files (PEP 561), verify completeness + signature parity. Trigger only when `py.typed` is `partial` or stubs ship in `<pkg>-stubs/`. |

Add to this table whenever Phase B authoring identifies a Python-specific gate worth its own agent.

#### Skip table (Go agents that may not need Python equivalents)

Reserved — populated during Phase B-2 authoring as agents are evaluated. Initial expectation: every Category A entry lands; Category C grows as needs emerge.

#### Authoring discipline

For each new Python pack agent:

1. Read the Go sibling (if any) for **structure reference only** — do not translate the body.
2. Author the body fresh: independent voice, Python-only idioms, citations into `python/conventions.yaml` rules by qualified name.
3. No Go cross-references in the body — agent stands on its own.
4. Add to `.claude/package-manifests/python.json`: `agents`, `waves`, `tier_critical`.
5. Run `bash scripts/validate-packages.sh`.

### 2C — Python-native skills + guardrails + oracles (B-3) — ~50 files

**Skills (~20):**
```
python-asyncio-patterns                    python-pytest-fixtures
python-async-context-managers              python-pytest-parametrize
python-error-handling-patterns             python-mypy-strict-typing
python-example-function-patterns           python-pip-audit-vetting
python-async-generator-patterns            python-otel-hook-integration
python-type-hints-best-practices           python-asyncio-leak-prevention
python-pyproject-tomls                     python-bench-pytest-benchmark
python-secrets-handling                    python-context-managers-vs-decorators
python-asyncio-cancellation                python-stdlib-logging
python-protocol-vs-abc                     python-hexagonal-architecture
```

**Guardrails (~30):** mirrors of Go-pack G30+ scripts:
```
G30-py.sh   — api-stub compiles (python -c 'import ...')
G41-py.sh   — toolchain.build (python -m build)
G42-py.sh   — toolchain.vet (mypy --strict)
G43-py.sh   — toolchain.fmt (ruff format --check)
G48-py.sh   — no top-level side effects
G60-py.sh   — toolchain.test (pytest -x)
G61-py.sh   — coverage gate (pytest --cov)
G63-py.sh   — flake hunt (pytest --count=3 via pytest-repeat)
G65-py.sh   — benchmark delta (pytest-benchmark JSON delta)
G95-py.sh through G103-py.sh   — marker protocol, route through python-backend.py
G104-py.sh through G110-py.sh   — perf-confidence regime, Python-native units
```

Either author Python-native G-scripts OR generalize existing scripts to dispatch via the toolchain. The latter is cleaner long-term but requires more refactoring.

**Oracles + perf-budget format:**
```
.claude/package-manifests/python/oracle-catalog.yaml   # Reference Python implementations + their measured numbers
docs/perf-budget-python-schema.md                       # Document Python-native units (seconds, MB, asyncio-tasks-leaked-per-1k-ops)
```

### 2D — First Python pilot run

After B-1/B-2/B-3 land:
- Author a small Python TPRD (e.g., "add a Redis client to motadatapysdk")
- Run intake → expect Wave I1.5 to accept §Target-Language: python
- Run through full pipeline → expect every wave to dispatch only Python pack content
- Calibrate Python perf oracle numbers from this first real run

Estimated effort: **~3–4 engineering weeks** if done by a human; LLM-authored draft is faster but needs heavy review.

---

## Decisions Pending

### D1 — 6 ambiguous skills (Item 1B) — *RESOLVED 2026-04-28: option (A), with `go-` PREFIX*

For each: `otel-instrumentation`, `client-tls-configuration`, `client-rate-limiting`, `credential-provider-pattern`, `backpressure-flow-control`, `circuit-breaker-policy`

**Resolution applied**: each was renamed with `go-` prefix (`go-otel-instrumentation`, `go-client-tls-configuration`, etc.). Treated as Go-coupled per body content; symmetric with the 11 definite renames. Option (B) (shared-core + skill overlay) deferred to a future skill-Split pass when Python siblings expose which bodies actually generalize.

(The original draft of this doc said "Rename to `-go`" suffix; that was incorrect for skills. Per `docs/PACKAGE-AUTHORING-GUIDE.md` § Naming convention table line 179 and rule 3, language-specific skills use `<lang>-` prefix, not `-<lang>` suffix. Agents do use suffix.)

### D2 — Python toolchain choices (Item 2 prerequisite)

| Concern | Recommendation | Rationale |
|---|---|---|
| Async model | asyncio + asyncio.TaskGroup | Stdlib, widest consumer base |
| Logging | stdlib logging + structured wrapper | Avoids forcing dep on consumers; mirrors Go's slog |
| OTel integration | wrapper package `motadatapysdk/otel/` | Mirrors `motadatagosdk/otel` pattern |
| Dependency mgmt | pip + pyproject.toml + pip-tools for lock | Lowest friction for SDK consumers |
| Package layout | src layout (`src/motadatapysdk/...`) | Modern best practice |
| Project name | `motadatapysdk` | Mirrors `motadatagosdk` |
| Leak detection | Custom asyncio task tracker | No exact goleak equivalent |
| Profile tool | py-spy first, scalene for memory | py-spy is no-install for end users |

These can be locked in `python.json:notes` or a new `python/CONVENTIONS.md`.

---

## Future skill-Split pass (NOT remaining for multi-lang structure; future cleanup)

Three skills in shared-core still have Go-flavored bodies that don't generalize cleanly. Per `shared-core.json:generalization_debt.skills`:

```
tdd-patterns                     # uses Go *_test.go and testing.T examples
idempotent-retry-safety          # Go context + errgroup snippets
network-error-classification     # errors.Is / net.Error examples
```

Resolution: same D6=Split mechanism — extend `<lang>/conventions.yaml` schema with `skills:` map, strip Go examples from skill bodies, add a Startup Protocol that loads the language overlay. Not blocking for the multi-language structure (these skills work today on Go runs as-is); cleanup item.

---

## Verification checklist (when both items are done)

- [ ] `bash scripts/validate-packages.sh` PASS — agent/skill/guardrail file counts match manifests for both go and python packs
- [ ] `bash scripts/run-toolchain.sh build` resolves correctly for both `go` and `python` target_language
- [ ] `bash scripts/run-guardrails.sh testing <run-dir>` correctly filters: Go run fires Go guardrails + skips Python ones; Python run fires Python guardrails + skips Go ones
- [ ] One full Go T1 run end-to-end with no regressions vs. pre-rename behavior
- [ ] One small Python T2 (or T1) run end-to-end as a smoke test
- [ ] CLAUDE.md Project Context block reads accurately for both languages
- [ ] `validate-packages.sh` shows `python.json` no longer has empty `agents/skills/guardrails` arrays

---

## What "done" looks like

- 38 agents on disk → all tagged appropriately (`shared-core` orchestrators no suffix; go-pack `-go` suffix; python-pack `-python` suffix siblings authored)
- 41+ skills on disk → split into shared-core (no tag), go-pack `go-` prefix, python-pack `python-` prefix
- 43+ guardrails on disk → either generalized via toolchain dispatch OR forked into `-py` siblings
- Both go and python packs equally populated in `validate-packages.sh` PASS report
- A Python TPRD runs through the full pipeline producing real code, tests, benchmarks, perf-budget calibration
