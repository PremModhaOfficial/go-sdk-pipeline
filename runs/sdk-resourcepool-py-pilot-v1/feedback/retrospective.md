<!-- Generated: 2026-04-29T18:05:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
# Phase Retrospective — Python Adapter Pilot (sdk-resourcepool-py-pilot-v1)
<!-- Covers all 4 phases: Intake, Design, Impl, Testing + cross-cutting toolchain incident -->

## What Went Well
- **Intake was a clean first run.** 0 clarifications, 0 manifest misses, 22/22 skills, 19/19 guardrails. Package resolution (shared-core@1.0.0 + python@1.0.0) cleanly isolated 24 Go-pack guardrails from the active set. No Go leak into the Python run.
- **Design converged in 1 iteration.** 6/6 devils ACCEPT on first pass; 4 LOW findings all closed in M5 without re-invoking the devil fleet. Review-fix-protocol deterministic-first gate never triggered.
- **CV-001 was a real correctness bug — caught by toolchain rerun.** The `typing` module import omission would have silently broken `cast()` calls at runtime. Static analysis (M5) mis-filed it LOW; only dynamic mypy-strict (M5b) confirmed correctness impact. The toolchain-provisioning loop earned its overhead.
- **Soak, drift, leak, complexity all green.** G105 (MMD 600s exact match), G106 (all 6 drift signals static/negative), G107 (O(1) confirmed slope −0.06), T6 (15/15, 0 leaks). The Python pack's T1-tier regime executed with no gaps on these axes.
- **Per-language baseline partition seeded cleanly.** 4 python-scoped files populated without touching shared/ partition. D1=B (per-language subdirectory) worked as designed; no cross-contamination.

## What Went Poorly
- **No Python toolchain at H7-option-1 selection meant 3 impl sub-runs.** Run-1 timed out after 75 tool uses. Run-2 proceeded statically and declared INCOMPLETE across all dynamic gates. Run-3 (toolchain provisioned) was necessary and correct but required user re-engagement after H7. A pre-flight toolchain probe at H0 would have surfaced this as a blocking preflight question before any pipeline work started.
- **Stream-idle timeout broke impl mid-flight at M3.** The agent stream killed after 75 tool uses on a long-running green-phase commit cycle. This is an infrastructure ceiling, not a pipeline logic error, but the resume protocol consumed user attention and required a second `sdk-impl-lead` agent instantiation. No mechanism exists to checkpoint mid-wave.
- **perf-budget.md oracle values were miscalibrated for floor-bound Python symbols.** Two symbols (`PoolConfig.__init__`, `AcquiredResource.__aenter__`) hit the Python language floor, making the Go×10 margin mechanically unreachable. The perf-architect wrote the budget without a "floor-bound" idiom; the gap was only discovered at H8 (testing). This cost a calibration round-trip and PA-013.
- **Bench harnesses for two shapes produced INCOMPLETE (PA-001, PA-002).** `try_acquire` (sync fast-path in asyncio context) and `aclose` (bulk-teardown) do not fit pytest-benchmark's per-call timing model. The python pack has no pre-built skill for these harness shapes; the impl agent wrote bespoke stubs that the profiler could not instrument.
- **G43-py (ruff + PEP 639) was a tooling-version-vs-config-format mismatch, not a real finding.** The dev-extras pin `ruff>=0.4,<0.5` predated PEP 639 support. The guardrail fired on config-file parsing, not code. A minimum-version policy for linters in the python manifest toolchain block would have caught this at design phase.

## Surprises
- **M3.5 caught CV-001 — a correctness bug the design-phase devils classified LOW.** The convention-devil flagged the import style as a PEP 585 suggestion; mypy-strict's runtime type-narrowing check discovered it was a missing import breaking `cast()`. The surprise: devil classification at design time can under-rate findings that only manifest at compile/run time. Design-phase devils need a "runtime-impact unknown — defer to dynamic verification" severity bucket.
- **The soak sampler defect (run-1 archived) mirrored a known Go-pack sampler pattern.** The asyncio cooperative-yield starvation under hot worker loops (PA-012) is structurally identical to the goroutine-scheduler-starving-soak-sampler pattern the Go pack already documents. Same root cause, different runtime. This suggests the soak-runner skill abstraction should carry a language-neutral "sampler-starvation" warning in its cross-language notes.

## Agent Coordination Issues
- **No mid-wave inter-agent communication logged.** All agents operated serially with no cross-agent messages beyond HITL gates. For this pilot (single-language, single-agent-per-wave) this was acceptable. For multi-agent Python waves (Phase B+), explicit communication protocol needs to exist.
- **G200-py + G32-py phase-header mismatch.** Two guardrails fired prematurely at design phase for Mode A greenfield. Lead issued a waiver; root cause is guardrail phase-header not accounting for Mode A lifecycle (pyproject.toml doesn't exist until M3). Phase-header fix is mechanical (PA filed) but cost a decision log entry and a waiver at D2.

## Communication Health
| Metric | Value |
|--------|-------|
| Total communications logged | 4 |
| Assumptions raised | 0 |
| Assumptions resolved | 0 (n/a) |
| Escalations sent | 0 |
| Escalations resolved | 0 |
| HITL gate communications | 4 (H1, H5, H7, H9) |

## Failure & Recovery Summary
| Metric | Value |
|--------|-------|
| Total failures logged | 3 |
| Recovered (retry / re-run) | 3 (all toolchain-absence → provisioned) |
| Recovered (fallback/skip) | 0 |
| Unrecovered (blocked downstream) | 0 |
| Top failure type | toolchain-absent (all 3) |

## Refactor Summary
| Metric | Value |
|--------|-------|
| Total refactors | 2 (M5 + M5b) |
| Trigger: review-finding | 1 (M5 — 4 design-LOW findings) |
| Trigger: toolchain-driven mechanical | 1 (M5b — 36 ruff/mypy fixes) |
| Trigger: test-failure | 0 |
| Trigger: guardrail-failure | 1 (G200-py in M5) |
| High regression risk refactors | 0 |
| Refactor ratio (2 waves / 9 output files) | ~22% |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|-------|-----------|----------------|----------------|
| sdk-perf-architect-python | Add "floor-bound" idiom: if symbol wraps runtime/dataclass machinery, declare `floor_type: language-floor` and set oracle margin relative to measured floor, not Go baseline | Prevents H8 calibration round-trips for frozen dataclass / small-context-switch symbols | G108 CALIBRATION-WARN on PoolConfig.__init__ and AcquiredResource.__aenter__ |
| sdk-convention-devil-python | Add severity bucket: `runtime-impact-unknown` for import/type-annotation findings; flag for dynamic verification rather than LOW deferral | Would have elevated CV-001 to MEDIUM at design phase, catching correctness risk earlier | CV-001 misclassified LOW at D3; correctness confirmed only at M5b mypy-strict |
| sdk-impl-lead (python pack) | Add explicit bench-harness selection step at M3.5 pre-flight: classify each hot-path symbol as `per-call`, `sync-fast-path-in-async`, or `bulk-teardown`; select matching harness template per classification before writing bench stubs | Prevents INCOMPLETE-by-harness on try_acquire (sync-fast-path) and aclose (bulk-teardown) | PA-001, PA-002 |

### Skill Gaps
| Proposed Skill | Domain | Rationale |
|---------------|--------|-----------|
| `python-bench-harness-shapes` | Python testing | Formalizes 3 harness shapes (per-call, sync-fast-path-in-async, bulk-teardown) with pytest-benchmark patterns for each. Prevents PA-001/PA-002 class of INCOMPLETE. |
| `python-floor-bound-perf-budget` | Python performance | Establishes idiom for declaring language-floor symbols in perf-budget.md with a `floor_type` field; guides perf-architect to avoid mechanically-unreachable oracle margins. |
| `soak-sampler-cooperative-yield` | Cross-language testing | Language-neutral guidance on sampler-starvation under hot event-loop / goroutine workers; currently documented in Go soak skill but not elevated to cross-language. Prevents PA-012 class in all packs. |

### Process Changes
| Change | Current State | Proposed State | Justification |
|--------|--------------|----------------|---------------|
| H0 toolchain probe | H0 is a git-repo check only; toolchain presence not verified | H0 must also verify active-language toolchain: `python --version`, `pip`, `venv` reachable; BLOCKER if missing | Eliminated 3-sub-run impl cycle and two HITL re-engagements |
| Guardrail phase-header Mode-A scoping | G200-py + G32-py fire at design phase (Mode A has no pyproject.toml yet) | Add `mode_skip: [A]` or `min_phase: impl` to guardrail headers for any gate that requires impl artifacts | Prevents false-BLOCKER at D2 for all future Python Mode A runs |
| linter min-version policy in python manifest | `toolchain.lint.min_version` is informational | Promote to enforced: if installed linter version < `toolchain.lint.min_version`, guardrail G43-py treats as INCOMPLETE-by-tooling from intake (not a surprise at M9) | Prevents G43-py class of late-surfaced tooling mismatch |
| Mid-wave checkpointing for long impl runs | No checkpoint between M3 sub-waves; agent timeout = full re-run from last checkpoint | Agent writes a `wave-checkpoint.json` after each M-wave commit; resume protocol reads this and skips completed sub-waves | Eliminates need for full impl re-run on stream-idle timeout |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|-----------|------------|-------|-----------|
| G-py-toolchain-probe | At H0 (intake): verify `python3 --version >= §Target-Language-Version`, `pip`, `venv` present; BLOCKER if absent | intake | Surfaces absent toolchain before design phase; prevents 3-sub-run impl cycle |
| G-py-linter-version | At impl-entry: compare `ruff --version` vs python manifest `toolchain.lint.min_version`; INCOMPLETE-by-tooling if below | impl | Catches ruff/pyproject.toml format mismatch before M9 surprises it |

## Pilot Verdict — D2 and D6

**D2 (Lenient cross-language baseline)**: Validated with one caveat. `sdk-design-devil` quality_score 87 compared meaningfully against Go-run shared-baseline history (Go baseline ~85 ±3pp; within-noise). The shared partition recorded the Python run without blocking on cross-language drift. However, the "is a shared-core agent systematically lower quality in Python runs?" cross-language analysis is not yet meaningful from a single data point — D2=Lenient is the correct posture for v0.5.0 with the expectation that the comparison becomes meaningful at ≥3 Python runs.

**D6 (Split shape — rule shared, examples per-lang)**: Empirically confirmed. Shared-core devils (sdk-design-devil, sdk-semver-devil, sdk-security-devil) applied universal rules with no Go-flavored noise. Python sibling agents (sdk-convention-devil-python, sdk-dep-vet-devil-python, sdk-packaging-devil-python) produced sharper findings on pack-native concerns (PEP 639, src-layout, py.typed, asyncio timeouts). No cross-language contamination observed in any review output. D6=Split is delivering as designed.

## Systemic Patterns (appeared in 2+ phases)
- **Toolchain-absence cascade**: surfaced in impl run-2 (M3.5, M5-verify, M7, M9 all INCOMPLETE) and testing (G32-py INCOMPLETE-by-tooling). Root cause is the same single gap: H0 does not probe the language toolchain. Cross-cutting; highest-priority improvement.
- **Floor-bound perf declaration gap**: surfaced at design (oracle set without floor-type idiom) and testing (G108 calibration-warn). Requires both a perf-architect skill update and a testing calibration classification. Two-phase pattern.
- **CLAUDE.md prose naming Go agents in language-neutral rules** (PA-006): rules 20, 24, 28, 32 name `sdk-perf-architect-go` etc. This is generalization debt carried through all 4 phases; every Python agent that reads these rules encountered Go-specific terminology. Systemic but low-severity; human PR required.
