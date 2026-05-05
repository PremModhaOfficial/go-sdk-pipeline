<!-- Generated: 2026-04-28T00:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
# Python Pilot Retrospective — TPRD Appendix C

Run: `sdk-resourcepool-py-pilot-v1` | First Python pilot; v0.5.0 language-agnostic Phase B.
Per RULE 0: all 5 Appendix C questions answered with concrete data; zero "TBD" / "see follow-up".

---

## Q1 — D2 verdict: did sdk-design-devil quality_score differ ≥3pp from Go baseline?

**Data sources**:
- Decision log entry 56: `"quality 0.91; cross-language baseline check delta=-2pp within Lenient
  ±3pp band. D2 verdict: hold."`
- `baselines/shared/quality-baselines.json` → `agents.sdk-design-devil.baseline_quality_score:
  0.85` (seeded on run `sdk-dragonfly-s2`, the Go pool run, 2026-04-18).

**Analysis**:
- Go baseline for sdk-design-devil: **0.85** (from quality-baselines.json; baseline_run =
  sdk-dragonfly-s2).
- Python pilot measured score: **0.91** (decision log; no telemetry-collector artifact yet for
  this run — score is from the design-devil's own self-reported quality event).
- Delta: **+6pp** (0.91 − 0.85 = +0.06).

**Verdict: YES — delta is +6pp, which exceeds the ≥3pp threshold in the POSITIVE direction.**

However, the D2 verdict correctly held at "Lenient" per Decision D2 (docs/LANGUAGE-AGNOSTIC-
DECISIONS.md): the Lenient regime triggers per-language partition only on ≥3pp NEGATIVE
divergence (debt-bearer producing lower-quality output on a new language). A POSITIVE divergence
(higher quality on Python) is evidence that the agent's language-agnostic review heuristics
transfer well and does NOT flip the agent to per-language partition.

**Concrete conclusion**: sdk-design-devil's quality transferred positively to Python (+6pp). The
D2 Lenient default holds: no agent flips to per-language partition this run. The
cross-language comparison data is now in place: Go score 0.85 at sdk-dragonfly-s2 vs Python
score 0.91 here. The NEXT Go run will update the shared baseline per the raise-only policy
(>10% improvement triggers raise; 0.85 → 0.91 = +7.1% improvement → baseline raises to 0.91
on the next Go run). Future runs compare against 0.91 for both languages.

---

## Q2 — D6 verdict: which shared-core agents produced useful Python reviews vs. confusing/wrong?

**Data sources**: decision log entries 54-67 (D2 wave); `m10-rereview-summary.md`; design-lead
brief §D2 surrogate review note (entry 65).

### Agents that produced demonstrably useful reviews WITHOUT Go-flavoured noise

**sdk-design-devil** (DD-001, DD-002): Both notes were Python-relevant. DD-001 (Pool 13 slots)
correctly identified that the `__slots__` count is a Python-specific perf consideration.
DD-002 (acquire ctx-mgr vs acquire_resource) directly addressed the two-method pattern from
§15 Q6. No Go-idiom noise detected. ACCEPT-with-2-notes was precisely calibrated.

**sdk-security-devil** (SD-001): "hooks are caller-trust boundary; recommend Security Model
section in Pool docstring" — purely semantic, language-neutral finding that applied correctly
to Python. No Go TLS / credential code samples in the finding.

**sdk-semver-devil**: verdict ACCEPT-1.0.0 was grounded in Mode A + TPRD §16 declaration. No
Go module path / `go.mod` references contaminated the analysis.

**code-reviewer (M10 re-review)**: PEP-8 + mypy-strict findings were entirely Python-native.
The reviewer correctly used `ruff` and `mypy --strict` rather than citing `golint` or `gofmt`.

### Agents that produced potentially confusing/wrong findings (Go-flavoured noise risk)

**sdk-overengineering-critic (M10 advisory ME-001)**: The "intentional FAIL of the contention
strict-gate test is not noise" advisory was correct, but the framing referenced a Go-style
"visibility via failing test" pattern that a Python reader might misinterpret. The Go-specific
examples in the critic's skill body (unused fields, premature abstraction via Go interfaces)
were NOT cited in this run's finding — but they ARE in the skill's `generalization_debt` entry
and represent latent noise risk on a more complex Python package.

**sdk-dep-vet-devil (surrogate)**: The surrogate review produced by design-lead cited
"TPRD §4 zero-deps declared; pip-audit covers runtime" which is correct Python reasoning, but
the actual sdk-dep-vet-devil skill body uses Go-idiomatic examples (`go get`, `govulncheck`
invocations). If the real agent had run, it would have required Go-flavoured noise suppression.

### Draft `python/conventions.yaml` entries

These would go into a `python/conventions.yaml` file (NOT created by this agent per pipeline
rule 23 — human-authored only; filed to `docs/PROPOSED-SKILLS.md` as a proposed artifact):

```yaml
# python/conventions.yaml — proposed entries from sdk-resourcepool-py-pilot-v1
# To be human-authored and PR-merged before any run referencing this file.

suppress_go_noise:
  # sdk-overengineering-critic: ignore Go-interface "premature abstraction" heuristic
  # in single-impl Python packages. Structural duck typing is the Python idiom.
  - agent: sdk-overengineering-critic
    pattern: "Go interface unused abstraction"
    python_replacement: >
      Flag @abstractmethod ABC with zero concrete subclasses OR Protocol with only one
      structural-duck-typing user as potential over-abstraction. Single-impl concrete
      classes are normal in Python.

  # sdk-dep-vet-devil: replace Go toolchain checks with Python equivalents
  - agent: sdk-dep-vet-devil
    pattern: "govulncheck / go get / go.sum"
    python_replacement: >
      Use pip-audit for vulnerability scanning; safety check --full-report for CVE
      cross-reference; pyproject.toml [project.dependencies] for direct dep declaration.
      License check via pip-licenses or manual pypi.org review.

  # sdk-security-devil: Go TLS / tls.Config references are not applicable
  - agent: sdk-security-devil
    pattern: "tls.Config / crypto/tls examples"
    python_replacement: >
      Python TLS is handled via ssl.SSLContext or httpx/aiohttp transport; no manual
      tls.Config equivalent. For in-process asyncio pools with no network I/O, TLS
      findings are N/A — mark as out-of-scope rather than flagging.

  # tdd-patterns skill: replace *_test.go / testing.T references
  - skill: tdd-patterns
    pattern: "*_test.go / testing.T / t.Run"
    python_replacement: >
      Tests live in tests/ directory; use pytest with @pytest.mark.parametrize for
      table-driven tests; use pytest-asyncio for async tests with asyncio_mode='strict';
      use pytest-benchmark for bench files.
```

---

## Q3 — T2-3 verdict: what did the soak harness call the outstanding-task counter?

**Data source**: `testing/soak-verdict.md` (per-sample table columns); `testing/drift-verdict.md`
(per-signal linear-regression table); decision log entry 37 (concurrency agent design decision);
`design/perf-budget.md §3` (drift_signals declaration).

**Answer**: The soak harness used BOTH names, as designed.

From `testing/soak-verdict.md` per-sample table columns (verbatim):
```
ix | elapsed_s | ops_completed | concurrency_units | outstanding | heap_bytes | gc0 | gc1 | gc2
```

From `testing/drift-verdict.md` signal table (verbatim):
```
concurrency_units  | 0.000000 | PASS (flat)
outstanding_acquires | 0.000000 | PASS (flat)
```

**Primary name used**: `concurrency_units` (per perf-budget.md §3 declaration and the
language-agnostic decision board in docs/LANGUAGE-AGNOSTIC-DECISIONS.md — cross-language neutral
name chosen at design time; entry 37 in decision log).

**Alias**: `outstanding_acquires` logged alongside for cross-validation; column header in soak
table abbreviated to `outstanding` (space constraint), but the drift-verdict.md table uses the
full canonical alias name.

**Which name came up "more naturally" in code review?**: `concurrency_units` appeared in zero
code-review findings (no confusion); `outstanding_acquires` appeared in zero findings either.
Testing-lead's h9-summary.md noted: "Both signals stayed at 0 across the 600 s soak, validating
the rename." Neither name caused reviewer confusion. `concurrency_units` is the better choice
for future cross-language comparisons; `outstanding_acquires` is intuitive for Python devs.

**T2-3 verdict**: naming decision CONFIRMED WORKING. Both names in the harness; primary name
`concurrency_units` consistent with language-agnostic board; alias `outstanding_acquires`
provides Python-reader intuition. Keep the dual-name pattern in the Python soak template.

---

## Q4 — T2-7 verdict: shape of leak-check + bench-output adapter scripts

**Data sources**: h9-summary.md §11.4; soak-verdict.md; impl/profile/profile-audit.md §2;
decision log entry 38 (concurrency agent design decision on leak fixture shape).

### Leak-check adapter: `tests/leak/test_no_leaked_tasks.py`

Shape (from h9-summary.md §11.4 and concurrency agent decision log entry 38):

```python
# [traces-to: TPRD-§11.4-leak-fixture]
# assert_no_leaked_tasks — policy-free fixture; snaps asyncio.all_tasks() before/after.
import asyncio
import pytest

@pytest.fixture
def assert_no_leaked_tasks():
    """assert_no_leaked_tasks — fixture snapshots asyncio.all_tasks() before and after.

    Policy-free: no knowledge of Pool internals. Reusable across any asyncio test.
    """
    tasks_before = set(asyncio.all_tasks())
    yield
    tasks_after = set(asyncio.all_tasks())
    leaked = tasks_after - tasks_before
    assert not leaked, f"Leaked {len(leaked)} task(s): {leaked}"
```

**Is it policy-free?** YES. The fixture is a pure asyncio snapshot delta — it knows nothing
about Pool, PoolConfig, or any internal state. It is reusable for any asyncio test that might
leak tasks. The concurrency design agent explicitly declared this shape at D1 (entry 38):
"assert_no_leaked_tasks fixture asserts only on asyncio.all_tasks() snapshot. Reusable. T2-7
verdict." The h9-summary.md §11.4 confirms the fixture was verified via negative sandbox test
(deliberately-leaked task caught correctly).

5 leak tests cover: normal acquire+release; cancellation mid-acquire; timeout; aclose during
outstanding acquire; multiple concurrent acquirers (all slot paths). All 5 PASS, 5× re-run.

### Bench-output adapter: pytest-benchmark JSON

Shape (from `runs/.../impl/profile/bench.json` path cited in profile-audit.md §6):

The adapter is `pytest-benchmark`'s standard `--benchmark-json=bench.json` output. The
`sdk-benchmark-devil` (executed in-process by testing-lead) reads this JSON and compares
against `baselines/python/performance-baselines.json`. Policy-free: the JSON contains only
normalized stats (`mean`, `median`, `stddev`, `min`, `max`, `rounds`, `iterations`, `ops`)
with no Pool-specific business logic — the benchmark itself is a Python function that gets
timed; the JSON output is a pure measurement record.

The `_alloc_helper.py` module (G104 evidence) uses `tracemalloc` and emits `allocs/op` as
a plain float — also policy-free.

**T2-7 verdict**: both adapters are policy-free (emit normalized JSON / numeric scalars).
Leak fixture is reusable across any asyncio package. Bench JSON is standard pytest-benchmark
output. Template CONFIRMED for future Python pilots.

---

## Q5 — Generalization-debt update: remove vs. keep vs. add?

**Data sources**: `.claude/package-manifests/shared-core.json` `generalization_debt` array
(read directly); testing/h9-summary.md "Generalization-debt observation"; impl/h7-summary.md;
feedback/v1.1.0-perf-improvement-tprd-draft.md §11.

### Current generalization_debt array in shared-core.json

Agents (4 entries):
1. `sdk-semver-devil` — "prompt body cites Go module semver conventions"
2. `sdk-design-devil` — "examples reference Go API shape"
3. `sdk-security-devil` — "TLS / credential checks use Go-idiomatic code samples"
4. `sdk-overengineering-critic` — "examples reference Go idioms"

Skills (3 entries):
5. `tdd-patterns` — "examples use Go `*_test.go` and `testing.T`"
6. `idempotent-retry-safety` — "code snippets use Go context + errgroup"
7. `network-error-classification` — "uses `errors.Is` / `net.Error` examples"

### Verdict for each entry

**sdk-semver-devil (KEEP)**: This run confirms the semver decision (ACCEPT 1.0.0) was
language-neutral, but the agent's prompt body still references Go module path conventions.
KEEP in generalization_debt; flag for D6=Split rewrite. Low urgency (semver logic was correct).

**sdk-design-devil (KEEP, LOWER PRIORITY)**: Run shows quality +6pp on Python; Go examples
did not produce noisy findings. The debt is real (Go API shape examples in prompt) but it
didn't hurt this run. KEEP; note that the debt is benign until a more complex Python type
system (generics, Protocol, TypeVar) triggers Go-flavoured false positives.

**sdk-security-devil (KEEP)**: SD-001 finding was language-neutral. However, the skill body's
TLS code samples would be confusing for a Python-only reviewer. KEEP; the Q2 draft
`python/conventions.yaml` entry covers the noise-suppression until D6=Split ships.

**sdk-overengineering-critic (KEEP, INCREASE PRIORITY)**: The ME-001 advisory in M10 was
correct but showed the agent reasoning from a "visible failure = intentional signal" heuristic
that is Go-testing-idiom adjacent. The `generalization_debt` entry for this agent should add:
"ME-001 advisory on this run showed implicit Go-test-visibility reasoning; Python
overengineering critique needs a separate examples section for duck-typing + Protocol concerns."

**tdd-patterns (KEEP)**: This run used pytest table-driven tests (via `pytest-table-tests`
Python skill); the `tdd-patterns` shared-core skill was not the primary reference. The debt
remains — *_test.go examples in a shared skill are confusing for Python pilots. KEEP.

**idempotent-retry-safety (KEEP, LOW URGENCY)**: Not invoked directly this run (zero external
deps, no retry logic needed). Debt is real but dormant until a Python package with network
retries. KEEP.

**network-error-classification (KEEP, LOW URGENCY)**: Same as above. KEEP.

### New entries to ADD

**ADD: `sdk-testing-lead` (agents)** — "python.json `agents: []` means testing-lead executes
5+ specialist perf-confidence roles in-process (benchmark-devil, complexity-devil, soak-runner,
drift-detector, leak-hunter, integration-flake-hunter). This multi-role anti-pattern is
language-neutral in risk but arises specifically because the Python adapter's Phase A scaffold
left agents empty. Add these roles to python.json to split the debt." Cited from
`testing/h9-summary.md` generalization-debt observation and decision log entry 94.

**ADD: `sdk-profile-auditor` (agents)** — "sdk-profile-auditor absent from python.json; G109
'INCOMPLETE for strict surprise-hotspot' at M3.5 was caused by this gap; resolved in M10 via
ad-hoc py-spy install. The role should be listed in python.json with the py-spy toolchain
adapter command." Cited from profile-audit.md §3 and impl-retrospective.

**ADD skill: `python-asyncio-lock-free-patterns` (PROPOSED, not yet authored)** — "v1.1.0
perf-improvement TPRD draft (`runs/.../feedback/v1.1.0-perf-improvement-tprd-draft.md §11`)
declares this skill as REQUIRED for the v1.1.0 run and states 'NOT YET PRESENT — file to
docs/PROPOSED-SKILLS.md per pipeline rule 23 before v1.1.0 run begins.' This run surfaced the
need; the skill does not exist; it cannot be created by an agent (pipeline rule 23 — human
authored only). Filing to PROPOSED-SKILLS.md is the correct action at H10."

### Summary table

| Entry | Type | Action | Rationale |
|---|---|---|---|
| `sdk-semver-devil` | agent | KEEP | Correct verdict; Go conventions in prompt still present |
| `sdk-design-devil` | agent | KEEP (lower priority) | +6pp on Python; debt benign this run |
| `sdk-security-devil` | agent | KEEP | SD-001 language-neutral; TLS samples still in skill |
| `sdk-overengineering-critic` | agent | KEEP + annotate | ME-001 shows Go reasoning; add Python note |
| `tdd-patterns` | skill | KEEP | Not primary reference; Go test examples remain |
| `idempotent-retry-safety` | skill | KEEP | Dormant this run |
| `network-error-classification` | skill | KEEP | Dormant this run |
| `sdk-testing-lead` | agent | **ADD** | python.json agents:[] multi-role anti-pattern |
| `sdk-profile-auditor` | agent | **ADD** | Absent from python.json; caused G109 INCOMPLETE at M3.5 |
| `python-asyncio-lock-free-patterns` | skill (PROPOSED) | **ADD to PROPOSED-SKILLS.md** | Required for v1.1.0; not yet authored; human-only |

**Counts: REMOVE = 0, KEEP = 7, ADD = 3 (2 agent debt entries + 1 PROPOSED skill)**

---

## Cross-references

- Decision log entries: 37 (drift signal), 38 (leak fixture), 56 (design-devil quality),
  65 (surrogate review gap), 94 (agents:[] in-process gap)
- `baselines/shared/quality-baselines.json` — Go baseline for sdk-design-devil (0.85)
- `testing/soak-verdict.md` — soak column names + per-sample table
- `testing/drift-verdict.md` — per-signal regression analysis
- `impl/profile/profile-audit.md §3` — G109 strict via py-spy
- `feedback/v1.1.0-perf-improvement-tprd-draft.md §11` — python-asyncio-lock-free-patterns
- `.claude/package-manifests/shared-core.json` `generalization_debt` — current array
