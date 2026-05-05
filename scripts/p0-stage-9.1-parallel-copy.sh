#!/usr/bin/env bash
# Stage 9.1 of the C-refactor P0 — parallel copy.
#
# Copies every file in the P0 file-move manifest (runs/p0-file-move-manifest.md)
# from the flat layout into the proposed core/ + packs/go/ structure. NO files
# are deleted; originals remain in place for Stage 9.2 wire-up + 9.3 cutover.
#
# Idempotent: re-running rsyncs over existing copies. Reversible:
# `rm -rf core/ packs/` cleans everything this script created.
#
# Verification: after copying, byte-diffs every copied file against its
# original. Reports any mismatch.

set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="$(pwd)"
echo "=== Stage 9.1: parallel copy ==="
echo "Repo root: $ROOT"

# ---- Skeleton ----
mkdir -p \
    core/agents \
    core/skills \
    core/phases \
    core/scripts/guardrails \
    core/scripts/ast-hash \
    core/scripts/perf \
    core/tests/ast-hash \
    core/tests/perf \
    packs/go/agents \
    packs/go/skills \
    packs/go/guardrails \
    packs/go/tests

# ---- Agents → core/agents/ (16) ----
CORE_AGENTS=(
    baseline-manager defect-analyzer guardrail-validator improvement-planner
    learning-engine metrics-collector phase-retrospector root-cause-tracer
    sdk-drift-detector sdk-intake-agent sdk-marker-scanner sdk-perf-architect
    sdk-profile-auditor sdk-skill-coverage-reporter sdk-skill-drift-detector
    sdk-soak-runner
)
for a in "${CORE_AGENTS[@]}"; do
    cp -p ".claude/agents/$a.md" "core/agents/$a.md"
done

# ---- Agents → packs/go/agents/ (22) ----
GO_AGENTS=(
    code-reviewer documentation-agent refactoring-agent
    sdk-api-ergonomics-devil sdk-benchmark-devil sdk-breaking-change-devil
    sdk-complexity-devil sdk-constraint-devil sdk-convention-devil
    sdk-dep-vet-devil sdk-design-devil sdk-design-lead
    sdk-existing-api-analyzer sdk-impl-lead sdk-integration-flake-hunter
    sdk-leak-hunter sdk-marker-hygiene-devil sdk-merge-planner
    sdk-overengineering-critic sdk-security-devil sdk-semver-devil
    sdk-testing-lead
)
for a in "${GO_AGENTS[@]}"; do
    cp -p ".claude/agents/$a.md" "packs/go/agents/$a.md"
done

# ---- Skills → core/skills/ (12 dirs, recursive) ----
CORE_SKILLS=(
    decision-logging review-fix-protocol lifecycle-events
    context-summary-writing conflict-resolution feedback-analysis
    guardrail-validation spec-driven-development environment-prerequisites-check
    api-ergonomics-audit mcp-knowledge-graph sdk-marker-protocol
)
for s in "${CORE_SKILLS[@]}"; do
    cp -rp ".claude/skills/$s" "core/skills/"
done

# ---- Skills → packs/go/skills/ (29 dirs, recursive) ----
GO_SKILLS=(
    backpressure-flow-control circuit-breaker-policy client-mock-strategy
    client-rate-limiting client-shutdown-lifecycle client-tls-configuration
    connection-pool-tuning context-deadline-patterns credential-provider-pattern
    fuzz-patterns go-concurrency-patterns go-dependency-vetting
    go-error-handling-patterns go-example-function-patterns
    go-hexagonal-architecture go-module-paths go-struct-interface-design
    goroutine-leak-prevention idempotent-retry-safety mock-patterns
    network-error-classification otel-instrumentation sdk-config-struct-pattern
    sdk-otel-hook-integration sdk-semver-governance table-driven-tests
    tdd-patterns testcontainers-setup testing-patterns
)
for s in "${GO_SKILLS[@]}"; do
    cp -rp ".claude/skills/$s" "packs/go/skills/"
done

# ---- Phases → core/phases/ (5) ----
for p in DESIGN-PHASE FEEDBACK-PHASE IMPLEMENTATION-PHASE INTAKE-PHASE TESTING-PHASE; do
    cp -p "phases/$p.md" "core/phases/$p.md"
done

# ---- Guardrails → core/scripts/guardrails/ (29) ----
CORE_GUARDRAILS=(
    G01 G02 G03 G04 G06 G07
    G20 G21 G22 G23 G24
    G38 G69
    G80 G81 G83 G84 G85 G86
    G90 G93
    G95 G96 G99 G100 G101 G102 G103
    G104 G105 G106 G107 G108 G109 G110
    G116
)
for g in "${CORE_GUARDRAILS[@]}"; do
    cp -p "scripts/guardrails/$g.sh" "core/scripts/guardrails/$g.sh"
done
cp -p "scripts/guardrails/run-all.sh" "core/scripts/guardrails/run-all.sh"

# ---- Guardrails → packs/go/guardrails/ (Go-tool-specific, currently 13 from listing — keep
#      G97 + G98 here for now; future P1 follow-up moves them to core with pack-supplied
#      file-ext + bench-name pattern) ----
GO_GUARDRAILS=(
    G30 G31 G32 G33 G34
    G40 G41 G42 G43 G48
    G60 G61 G63 G65
    G97 G98
)
for g in "${GO_GUARDRAILS[@]}"; do
    cp -p "scripts/guardrails/$g.sh" "packs/go/guardrails/$g.sh"
done

# ---- Transitional P1/P2 artifacts ----
# Dispatchers stay in core (they are pack-aware)
cp -p scripts/ast-hash/ast-hash.sh   core/scripts/ast-hash/ast-hash.sh
cp -p scripts/ast-hash/symbols.sh    core/scripts/ast-hash/symbols.sh
cp -p scripts/ast-hash/README.md     core/scripts/ast-hash/README.md
cp -p scripts/perf/perf-config.yaml  core/scripts/perf/perf-config.yaml
cp -p scripts/compute-shape-hash.sh  core/scripts/compute-shape-hash.sh

# Go AST backend → packs/go/ (renamed from go-backend → ast-hash-backend per manifest)
cp -p scripts/ast-hash/go-backend.go packs/go/ast-hash-backend.go
cp -p scripts/ast-hash/go-backend    packs/go/ast-hash-backend
cp -p scripts/ast-hash/go-symbols.go packs/go/symbols-backend.go
cp -p scripts/ast-hash/go-symbols    packs/go/symbols-backend

# Tests follow the dispatchers into core
cp -p tests/ast-hash/test.sh         core/tests/ast-hash/test.sh
cp -p tests/ast-hash/test-g95.sh     core/tests/ast-hash/test-g95.sh
cp -p tests/perf/test-g104.sh        core/tests/perf/test-g104.sh

# ---- Split-file placeholders (content split deferred to a separate edit step) ----
# CLAUDE.md is too dense to mechanically split here; we create stubs noting the
# intent. Stage 9.4 documentation phase finalizes the split.
if [ ! -f core/CORE-CLAUDE.md ]; then
    cat > core/CORE-CLAUDE.md <<'STUB'
# core/CORE-CLAUDE.md — Pipeline-Invariant Agent Fleet Rules

> Stub during P0 Stage 9.1. Will be finalized at Stage 9.4 (documentation phase).
>
> When this stub is replaced, it will contain the language-invariant subset
> of the original CLAUDE.md: rules 1-5, 7-13, 17-18, 21-28, 30, 31. The
> language-specific rules (6 quality standards, 14 impl-completeness Go
> specifics, 19 Go dep vetting) move to packs/go/quality-standards.md.
>
> Until then, the original `CLAUDE.md` at the repo root remains the single
> source of truth.
STUB
fi
if [ ! -f packs/go/quality-standards.md ]; then
    cat > packs/go/quality-standards.md <<'STUB'
# packs/go/quality-standards.md — Go-Specific Quality Standards

> Stub during P0 Stage 9.1. Will be finalized at Stage 9.4 (documentation phase).
>
> Will hold the Go-specialized rules extracted from CLAUDE.md: rule 6 (godoc,
> Config+New, no init(), context.Context first param, OTel via motadatagosdk/otel,
> compile-time interface assertions), rule 14 (impl completeness — goleak,
> govulncheck, osv-scanner, Example_*), rule 19 (go-get justification +
> license allowlist).
>
> Until then, the original `CLAUDE.md` rules 6, 14, 19 remain authoritative.
STUB
fi

# ---- skill-index split ----
python3 - <<'PY'
import json, os
src = ".claude/skills/skill-index.json"
d = json.load(open(src))

CORE_SET = {
    "decision-logging","review-fix-protocol","lifecycle-events",
    "context-summary-writing","conflict-resolution","feedback-analysis",
    "guardrail-validation","spec-driven-development","environment-prerequisites-check",
    "api-ergonomics-audit","mcp-knowledge-graph","sdk-marker-protocol",
}

def split_section(entries):
    core_e, pack_e = [], []
    for e in entries:
        (core_e if e["name"] in CORE_SET else pack_e).append(e)
    return core_e, pack_e

core_index = {
    "schema_version": d["schema_version"],
    "pipeline_version": d["pipeline_version"],
    "scope": "core",
    "skills": {},
}
pack_index = {
    "schema_version": d["schema_version"],
    "pipeline_version": d["pipeline_version"],
    "scope": "pack:go",
    "skills": {},
}
for section, entries in d.get("skills", {}).items():
    c, p = split_section(entries)
    if c:
        core_index["skills"].setdefault(section, []).extend(c)
    if p:
        pack_index["skills"].setdefault(section, []).extend(p)

# Tags index — partition similarly
core_tags, pack_tags = {}, {}
for tag, names in d.get("tags_index", {}).items():
    cn = [n for n in names if n in CORE_SET]
    pn = [n for n in names if n not in CORE_SET]
    if cn: core_tags[tag] = cn
    if pn: pack_tags[tag] = pn
core_index["tags_index"] = core_tags
pack_index["tags_index"] = pack_tags

with open("core/skills/skill-index.json", "w") as f:
    json.dump(core_index, f, indent=2)
with open("packs/go/skills/skill-index.json", "w") as f:
    json.dump(pack_index, f, indent=2)
print(f"core/skills/skill-index.json:    {sum(len(v) for v in core_index['skills'].values())} skills")
print(f"packs/go/skills/skill-index.json: {sum(len(v) for v in pack_index['skills'].values())} skills")
PY

# ---- Verification: byte-diff every copied file vs. its original ----
echo
echo "=== Verification (byte-diffs) ==="
FAIL=0; CHECKED=0
verify_pair() {
    if cmp -s "$1" "$2"; then
        CHECKED=$((CHECKED+1))
    else
        echo "DIFF: $1 vs $2"
        FAIL=$((FAIL+1))
    fi
}
for a in "${CORE_AGENTS[@]}"; do verify_pair ".claude/agents/$a.md" "core/agents/$a.md"; done
for a in "${GO_AGENTS[@]}"; do verify_pair ".claude/agents/$a.md" "packs/go/agents/$a.md"; done
for s in "${CORE_SKILLS[@]}"; do
    while IFS= read -r f; do
        rel="${f#.claude/skills/$s/}"
        verify_pair "$f" "core/skills/$s/$rel"
    done < <(find ".claude/skills/$s" -type f)
done
for s in "${GO_SKILLS[@]}"; do
    while IFS= read -r f; do
        rel="${f#.claude/skills/$s/}"
        verify_pair "$f" "packs/go/skills/$s/$rel"
    done < <(find ".claude/skills/$s" -type f)
done
for p in DESIGN-PHASE FEEDBACK-PHASE IMPLEMENTATION-PHASE INTAKE-PHASE TESTING-PHASE; do
    verify_pair "phases/$p.md" "core/phases/$p.md"
done
for g in "${CORE_GUARDRAILS[@]}"; do verify_pair "scripts/guardrails/$g.sh" "core/scripts/guardrails/$g.sh"; done
verify_pair "scripts/guardrails/run-all.sh" "core/scripts/guardrails/run-all.sh"
for g in "${GO_GUARDRAILS[@]}"; do verify_pair "scripts/guardrails/$g.sh" "packs/go/guardrails/$g.sh"; done

# Transitional P1/P2 verification
verify_pair scripts/ast-hash/ast-hash.sh   core/scripts/ast-hash/ast-hash.sh
verify_pair scripts/ast-hash/symbols.sh    core/scripts/ast-hash/symbols.sh
verify_pair scripts/ast-hash/README.md     core/scripts/ast-hash/README.md
verify_pair scripts/perf/perf-config.yaml  core/scripts/perf/perf-config.yaml
verify_pair scripts/compute-shape-hash.sh  core/scripts/compute-shape-hash.sh
verify_pair scripts/ast-hash/go-backend.go packs/go/ast-hash-backend.go
verify_pair scripts/ast-hash/go-backend    packs/go/ast-hash-backend
verify_pair scripts/ast-hash/go-symbols.go packs/go/symbols-backend.go
verify_pair scripts/ast-hash/go-symbols    packs/go/symbols-backend
verify_pair tests/ast-hash/test.sh         core/tests/ast-hash/test.sh
verify_pair tests/ast-hash/test-g95.sh     core/tests/ast-hash/test-g95.sh
verify_pair tests/perf/test-g104.sh        core/tests/perf/test-g104.sh

echo
echo "Files byte-verified: $CHECKED"
echo "Mismatches:          $FAIL"
[ $FAIL -eq 0 ] && echo "Stage 9.1 complete: byte-equivalent parallel copy." || echo "STAGE 9.1 FAILED — investigate mismatches above."
[ $FAIL -eq 0 ]
