# Package Authoring Guide

**Audience**: contributors authoring a new package manifest (a second-language adapter, a tier-specific bundle, or a domain split out of `shared-core`).

**Pipeline version**: 0.5.0+

---

## What a package is

A **package** is a JSON manifest in `.claude/package-manifests/<name>.json` that lists which on-disk artifacts (agents, skills, guardrails) belong to one logical unit. Two packages exist today:

- `shared-core` — language-agnostic orchestration, meta-skills, governance.
- `go` — Go SDK language adapter for `motadatagosdk`.

Manifests are **descriptive metadata**, not directory structure. Files do NOT move into per-package folders. Agents stay at `.claude/agents/<name>.md`, skills at `.claude/skills/<name>/SKILL.md`, guardrails at `scripts/guardrails/G*.sh`. This is a hard invariant: Claude Code's harness auto-discovers from those canonical paths, and physical packaging would silently break discovery.

---

## When to author a new package

| Scenario | Verdict |
|---|---|
| Adding a second-language adapter (Python, Rust, TypeScript, Java) | YES — author `<lang>.json` |
| Splitting `shared-core` because it grew unwieldy | YES — author `governance.json` etc., move artifacts via manifest entries (no file moves) |
| Adding a single new agent / skill / guardrail | NO — add it to an existing manifest |
| Carving out a tier-specific bundle (e.g. T2-only) | NO — tiers are a runtime filter on the existing union, not their own manifests |
| Per-target-product packaging (e.g. `motadata-go-sdk` vs `motadata-py-sdk`) | NO at v0.4.0 — defer; revisit when third adapter exists |

---

## Manifest schema

```json
{
  "schema_version": "1.0.0",
  "name": "<package-name>",
  "version": "X.Y.Z",
  "type": "core | language-adapter",
  "description": "<one-line>",
  "depends": ["shared-core@>=1.0.0", ...],
  "pipeline_version_compat": ">=0.4.0",

  "agents":     ["<agent-id>", ...],
  "skills":     ["<skill-name>", ...],
  "guardrails": ["G<NN>", ...],

  "toolchain": {           // language-adapter only
    "build":            "<cmd>",
    "test":             "<cmd>",
    "lint":             "<cmd>",
    "vet":              "<cmd>",
    "fmt":              "<cmd>",
    "coverage":         "<cmd>",
    "coverage_min_pct": 90,
    "bench":            "<cmd>",
    "supply_chain":     ["<cmd>", ...],
    "leak_check":       "<cmd>"
  },
  "file_extensions":         [".<ext>"],
  "marker_comment_syntax":   { "line": "<>", "block_open": "<>", "block_close": "<>" },
  "module_file":             "<filename>",

  "generalization_debt": {
    "agents": [{"name": "...", "reason": "..."}],
    "skills": [{"name": "...", "reason": "..."}],
    "resolution_policy": "<text>"
  },

  "notes": { "<key>": "<text>", ... }
}
```

Required fields: `name`, `version`, `agents`, `skills`, `guardrails`. Validator checks for these.

`type=core` packages do NOT carry `toolchain` / `file_extensions` / `marker_comment_syntax` / `module_file`. They're language-neutral.

`type=language-adapter` packages MUST carry all four.

---

## How to add a second-language adapter (worked example: Python)

### Step 1 — author `.claude/package-manifests/python.json`

Use `go.json` as a template. Fill the `toolchain` block:

```json
{
  "schema_version": "1.0.0",
  "name": "python",
  "version": "1.0.0",
  "type": "language-adapter",
  "description": "Python SDK pipeline adapter for motadatapysdk. Target: Python 3.12.",
  "depends": ["shared-core@>=1.0.0"],
  "pipeline_version_compat": ">=0.5.0",

  "agents":     [...],   // python-specific agents (sdk-asyncio-leak-hunter, etc.)
  "skills":     [...],   // python-specific skills (asyncio-patterns, pytest-fixtures, etc.)
  "guardrails": [...],   // python-specific gates

  "toolchain": {
    "build":            "python -m build",
    "test":             "pytest -x --no-header",
    "lint":             "ruff check .",
    "vet":              "mypy --strict .",
    "fmt":              "ruff format --check .",
    "coverage":         "pytest --cov=src --cov-report=json",
    "coverage_min_pct": 90,
    "bench":            "pytest --benchmark-only",
    "supply_chain":     ["pip-audit", "safety check"],
    "leak_check":       "asyncio-leak-test"
  },
  "file_extensions":         [".py"],
  "marker_comment_syntax":   { "line": "#", "block_open": "\"\"\"", "block_close": "\"\"\"" },
  "module_file":             "pyproject.toml"
}
```

### Step 2 — author the agents / skills / guardrails the manifest references

Each must exist on disk before `scripts/validate-packages.sh` will pass. Author them per the existing canonical patterns:

- Agents: `.claude/agents/<name>.md` with frontmatter (`name`, `description`, `model`, `tools`).
- Skills: `.claude/skills/<name>/SKILL.md` with frontmatter (`name`, `description`, `version`).
- Guardrails: `scripts/guardrails/G<NN>.sh` executable, with `# phases:` and `# severity:` headers.

### Step 3 — work through `shared-core.json`'s `generalization_debt` list

Each entry needs one of:
- **Rewrite** the agent / skill body to be language-neutral (no Go idioms in examples).
- **Move** to a language-specific manifest if role turns out to be Go-specific (rare).
- **Split** into shared + per-language parts (e.g. `tdd-patterns` becomes `tdd-patterns-shared` + `go-tdd-snippets` + `python-tdd-snippets`).

### Step 4 — run the validator

```bash
bash scripts/validate-packages.sh
```

Must exit 0. Any orphan / duplicate / dangling reference = FAIL. Fix the manifest until clean.

### Step 5 — author a new TPRD that declares `§Target-Language: python`

Run intake. Wave I5.5 will resolve `python.json` and write `runs/<id>/context/active-packages.json` with the union set. G05 verifies. Phase leads dispatch only Python agents.

---

## Maintenance: adding / removing a single artifact

When you add a NEW agent / skill / guardrail in any PR:

1. Decide which manifest owns it. Default: `shared-core` if role is language-neutral, `<lang>` if role is language-specific.
2. Add the artifact's name/id to the manifest's `agents` / `skills` / `guardrails` array (alphabetical).
3. Run `scripts/validate-packages.sh` — must exit 0.
4. Commit both the artifact AND the manifest update in one PR.

When you DELETE an artifact:

1. Remove from manifest first (otherwise validate-packages.sh will FAIL with "dangling reference").
2. Remove the file.
3. Validator confirms.

When you MOVE an artifact between manifests (e.g. discovered a `shared-core` skill is actually Go-specific):

1. Update both manifests in one diff.
2. If the move surfaces generalization debt, add an entry to the destination manifest's `generalization_debt` array.

---

## The validator

`scripts/validate-packages.sh` enforces:

- Every `.claude/agents/*.md` is referenced in exactly one manifest.
- Every `.claude/skills/*/` directory is referenced in exactly one manifest.
- Every `scripts/guardrails/G*.sh` file is referenced in exactly one manifest.
- No manifest references a non-existent file (dangling).
- No artifact appears in two manifests (duplicate).

Exit codes: 0 = clean, 1 = drift, 2 = infra problem (jq missing, manifest dir missing).

Run on every PR; runs in pre-merge CI eventually (not yet wired).

---

## Baselines — partitioning contract

Every baseline file (under `baselines/`) declares a `scope` field. Every language manifest declares which baselines it owns. This is how the pipeline knows whether a given metric is intrinsically per-language (perf units, AST hashes) or genuinely cross-language (per-agent quality, per-skill stability).

**Three scope values**:

| Scope | Examples | Lives at (v0.4.0+, shipped) |
|---|---|---|
| `per-language` | `performance-baselines.json`, `coverage-baselines.json`, `output-shape-history.jsonl`, `devil-verdict-history.jsonl`, `do-not-regenerate-hashes.json`, `stable-signatures.json`, `regression-report-<run-id>.md` | `baselines/<lang>/<file>` (today: `baselines/go/<file>`) |
| `shared` | `quality-baselines.json`, `skill-health-baselines.json`, `baseline-history.jsonl` | `baselines/shared/<file>` |
| `shared-stub` | `skill-health.json` (legacy pointer at `skill-health-baselines.json`) | `baselines/shared/<file>` (likely deleted in v0.5.0) |

**JSON files** carry the `scope` field at top level (right after `pipeline_version`):

```json
{
  "schema_version": "1.0.0",
  "pipeline_version": "sdk-pipeline@0.5.0",
  "scope": "per-language",
  "language": "go",
  "scope_note": "<reason this is per-language; what units are stored>",
  ...
}
```

**JSONL files** do not carry per-line scope — classification lives only in the manifest's `baselines` block.

**Manifest declaration**:

```json
// go.json (language-adapter)
"baselines": {
  "scope_owned": "per-language",
  "owns_per_language": ["performance-baselines.json", "coverage-baselines.json", ...],
  "contributes_per_language_partition_to": []   // empty in v0.4.0; fills if D2 lands as Strict
}

// shared-core.json (core)
"baselines": {
  "scope_owned": "shared",
  "owns_shared": ["quality-baselines.json", "skill-health-baselines.json", ...]
}
```

**v0.4.0 scope** (shipped): files moved to `baselines/go/` + `baselines/shared/`; consumers (`baseline-manager`, `metrics-collector`, `learning-engine`, G81/G86/G101) updated to read partitioned paths; manifest declares ownership; `scope` field stamped on each JSON baseline.

**v0.5.0 scope** (Python pilot): adds `baselines/python/` partition with per-language baselines. Mechanical because the manifest schema is already in shape and the consumer code already path-joins on `<lang>`.

**Cross-language comparison is explicitly NOT a goal.** Each language adapter compares its perf / coverage / shape baselines against its own language's history. There is no "the Python p99 is X% slower than the Go p99" metric in v0.5.0 — that's deferred to a future research branch (R1 in `docs/LANGUAGE-AGNOSTIC-DECISIONS.md`). Per-language adapters do their own oracle calibration; cross-language oracle equivalence is a separate, harder problem.

**Decisions deferred to v0.5.0+**:
- **D2** — should shared-core agents/skills with `generalization_debt` partition into `languages.<lang>` until rewritten? Defer.
- **D6** — eager rewrite of all 7 debt items vs lazy vs split? Defer; pilot Python with debt-bearers in shared and observe.

See `docs/LANGUAGE-AGNOSTIC-DECISIONS.md` for the full decision board + per-touchpoint handling table.

---

## generalization_debt — convention

When a `shared-core` artifact has a language-neutral *role* but its *body* still cites idioms of a specific language, declare it:

```json
"generalization_debt": {
  "agents": [
    {"name": "sdk-design-devil", "reason": "examples reference Go API shape; review heuristics generalize"}
  ],
  "skills": [
    {"name": "tdd-patterns", "reason": "examples use Go testing.T; TDD cycle itself is language-neutral"}
  ],
  "resolution_policy": "Flagged here so the v0.5.0 second-language pilot knows the backlog. No action required in v0.4.0. When a second language adapter is authored, each item gets either (a) a language-neutral rewrite of the prompt/body, (b) move to the <lang> package if role turns out to also be lang-specific, or (c) a split into shared + per-language parts."
}
```

This is the **single source of truth** for "what's left to do for full agnosticism." Don't track it elsewhere.

---

## Where adapter scripts will live (v0.5.0+ preview)

Today (v0.4.0): the `toolchain` block in a language-adapter manifest carries inline shell-command strings:

```json
"toolchain": { "build": "go build ./...", "test": "go test ./... -race -count=1", ... }
```

This is the right shape while there's only one adapter. Once a second adapter exists and the inline strings start growing per-language flag matrices, v0.5.0 will move them under:

```
.claude/package-manifests/
├── go.json                         # references adapter scripts via path
├── go/
│   ├── adapters/
│   │   ├── build.sh
│   │   ├── test.sh
│   │   ├── leak-check.sh
│   │   └── ...
│   ├── parsers/
│   │   ├── pprof-to-normalized.py  # pprof → neutral profile schema
│   │   └── coverage-to-normalized.py
│   └── oracle-catalog.yaml         # reference-impl throughput per workload
└── python/
    └── ...
```

Adapter scripts must remain **policy-free**: emit normalized output to stdout; no threshold comparisons, no FAIL/BLOCKER strings. Policy stays in agents.

This is a v0.5.0 concern. Don't externalize in v0.4.0; the inline form is fine.

---

## Non-goals (don't do these)

- ❌ **Don't move agent / skill files into per-package directories.** Harness discovery will break.
- ❌ **Don't author runtime-synthesized manifests.** Manifests are human-authored, PR-reviewed, static at runtime (CLAUDE.md rule 23 extended).
- ❌ **Don't put threshold logic in the `toolchain` block.** Strings are commands, not policy.
- ❌ **Don't fork agents per language.** A second language adds a manifest + adapter scripts; not new agents (CLAUDE.md rule 34, future v0.5.0 enforcement).
- ❌ **Don't bypass `validate-packages.sh`.** The validator is the single discipline keeping manifests honest.

---

## See also

- `CLAUDE.md` rule 34 — the canonical Package Layer rule.
- `phases/INTAKE-PHASE.md` Wave I5.5 — per-run package resolution.
- `scripts/guardrails/G05.sh` — `active-packages.json` validator.
- `evolution/evolution-reports/pipeline-v0.4.0.md` — full release notes.
- `.claude/package-manifests/README.md` — manifest directory overview.
- `.claude/package-manifests/shared-core.json` / `go.json` — canonical examples.
