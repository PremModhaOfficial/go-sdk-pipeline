# Perf Exceptions (D1) — `nats-py-v1`

**Authored by**: `sdk-perf-architect` (sdk-design-lead acting in this role).
**Status**: EMPTY at design time.

No symbol in this design requires a `[perf-exception:]` marker (per CLAUDE.md rule 29). All hot-path symbols are within `oracle.margin_multiplier` declared in `perf-budget.md`. If impl phase discovers a symbol that needs hand-optimization beyond the declared budget:

1. Impl agent files an entry below with: symbol-name, declared-budget, achieved-perf, complexity-justification, named-bench.
2. `sdk-overengineering-critic` exempts only if (a) entry exists here, (b) bench measurably justifies, (c) `sdk-profile-auditor` confirms profile evidence (G110).
3. Orphan `[perf-exception:]` markers (no entry here) = BLOCKER per G110.

## Entries

(none)

---

**END perf-exceptions.md**
