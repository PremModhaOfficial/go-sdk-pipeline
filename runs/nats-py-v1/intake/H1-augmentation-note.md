# H1 augmentation note (run `nats-py-v1`)

**Trigger**: user instruction during intake — *"construct the missing things like skills and guardrails"*. Authored as human-direction (CLAUDE.md rule 23 path 1).

## What changed

### Skills added (3) — `.claude/skills/<name>/SKILL.md` + `evolution-log.md`

| Skill | v | Purpose |
|---|---|---|
| `nats-python-client-patterns` | 1.0.0 | Wraps `nats-py` v2.x: connect+TLS+creds, pub/sub/request, JetStream stream + pull-consumer + KV + ObjectStore, headers, drain vs close, reconnect-callback hooks |
| `python-otel-instrumentation` | 1.0.0 | Python sibling of `otel-instrumentation`: TracerProvider/MeterProvider with OTLP, lazy meter handles via `functools.cache`, span context manager, custom carrier (NATS headers) `Getter`/`Setter`, W3C+Baggage propagator, shutdown ordering |
| `pydantic-settings-patterns` | 1.0.0 | Python sibling of `sdk-config-struct-pattern` + `credential-provider-pattern`: `BaseSettings` + `env_prefix`, layered precedence, `SecretStr`, nested config via `env_nested_delimiter`, `.env.example` plumbing per CLAUDE.md rule 27 |

### Guardrails added (5) — `scripts/guardrails/G*.sh`

| ID | Severity | Phases | Purpose |
|---|---|---|---|
| `G120` | BLOCKER | impl, testing | `python -m build` produces wheel + sdist |
| `G121` | BLOCKER | testing | `pytest -x` exits 0 (no failed/errored tests) |
| `G122` | BLOCKER | impl, testing | `ruff check .` + `ruff format --check .` + `mypy --strict src` |
| `G123` | BLOCKER | testing | `pip-audit --strict` (PyPI advisories) + `safety check` (best-effort, may auth-gate) |
| `G124` | BLOCKER | testing | Python sibling of G69 — credential scan including `*.py` + `.env.example`; AWS keys, GitHub PATs, PEM private keys, password=/api_key= literals |

### Manifest registrations

- `.claude/package-manifests/python.json` — version `1.0.0` → `1.1.0`; `skills` 4→7; `guardrails` 0→5
- `.claude/skills/skill-index.json` — 3 entries added under `skills.python_specific`; `tags_index.python` 4→7; new `tags_index.config` and `tags_index.messaging` tags
- `scripts/validate-packages.sh` — PASS (38 agents / 48 skills / 58 guardrails on disk; manifests consistent)

### Why this was needed (per intake's own analysis)

The intake agent's `H1-summary.md` §2 explicitly named three "notable absences":

1. *"No Python-specific OTel skill — `otel-instrumentation` is language-neutral with Go examples in shared-core's generalization_debt."*
2. *"No `nats-py-client-patterns` — covered by `client-mock-strategy` + library docs (context7 lookup at design phase)."*
3. *"No `pydantic-settings-patterns` — covered by `sdk-config-struct-pattern` (Python analog) + library docs."*

Per "be strict" user direction, deferring authorship to design phase (option chosen by intake) was rejected — the gaps are now closed in-repo before design starts.

The 5 guardrails close a quieter gap: `python.json` declared `guardrails: []`, so the Python pilot inherited only `shared-core`'s 22 guardrails (process / meta / drift-prevention) — and the Go-coupled guardrails (`G63 = go test -race -count=3`, `G69 = grep --include="*.go"`) would silently SKIP or FAIL on a Python target. G120–G124 are the strict Python-aware coverage.

## What did NOT change

- The TPRD source (`/home/prem-modha/projects/nextgen/motadata-py-sdk/PYTHON_SDK_TPRD.md`) — read-only
- The canonical TPRD (`runs/nats-py-v1/tprd.md`) — sections 1-14 retained verbatim from intake
- `mode.json` — Mode A unchanged
- `active-packages.json` — STALE; needs regeneration to pick up new python.json entries (G05 should be re-run)
- `intake/skills-manifest-check.md` and `intake/guardrails-manifest-check.md` — STALE if anything in TPRD §Skills-Manifest/§Guardrails-Manifest references the new entries (current TPRD does not, since intake derived them earlier)
- HITL H1 — STILL pending user decision on Q1 (run scope)

## Open H1 questions (unchanged from intake)

| # | Question | Auto-mode default |
|---|---|---|
| Q1 | Run scope: **A** (full 5 modules + OTel + config in one run, est 8–12M tokens) / **B** (decompose to `nats-py-v1` = codec + events/utils + events/core + events/corenats only, est 2–3M) / **C** (minimal v1 = codec + events/utils + events/core only, est ~1M) | **B** |
| Q2 | Skills-Manifest accept (now 31 + 3 = 34 entries) | accept |
| Q3 | Guardrails-Manifest accept (now 53 + 5 = 58 entries; same 5 informational exclusions for Mode A) | accept |
| Q4 | Constraint advisories noted | noted |
| Q5 | Marker-protocol Phase B plan acknowledged | acknowledge |

Q2/Q3 verdicts upgrade automatically (the augmented set is a strict superset; nothing lost). Q1 remains the user-blocking decision.
