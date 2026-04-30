Before laying out the plan — one design call that shapes everything: do we use physical directory packaging (move files into .claude/packages/<pkg>/) or manifest-only packaging      
  (files stay where they are; packages are JSON files that list which artifacts they own)?                                                                                              
                                                                                                                                                                                        
  I strongly recommend manifest-only for two reasons:                                                                                                                                   
  1. Claude Code's harness auto-discovers agents at .claude/agents/*.md and skills at .claude/skills/*/SKILL.md. Moving them into .claude/packages/<pkg>/agents/ breaks discovery — the 
  agents become uninvokable.                                                                                                                                                            
  2. Zero file moves = zero risk of breaking the existing Go pipeline mid-refactor. The strategy doc itself flagged the atomic-move issue as a WARNING.
                                                                                                                                                                                        
  The plan below assumes manifest-only. If you want physical directories, we'd need a build step (symlinks or sync script) and the risk profile triples.                                
                                                                                                                                                                                        
  ---                                                                                                                                                                                   
  Implementation Plan — Package Layer (Manifest-Only)                                                                                                                                   
                                                                                                                                                                                        
  Goal: Add a package abstraction that bundles agents + skills + guardrails per language, with TPRD selecting which packages are active. Everything stays Go-only initially; we just
  prove the package boundary works without breaking determinism.                                                                                                                        
                  
  Estimated effort: ~5 working days                                                                                                                                                     
  Pipeline version bump: 0.2.0 → 0.3.0
  Branch: pkg-layer-v0.3 (off current mcp-enhanced-graph)                                                                                                                               
                                                                                                                                                                                        
  ---                                                                                                                                                                                   
  Phase 0 — Pre-flight & Baseline Capture (Day 0, ~2 hours)                                                                                                                             
                                                                                                                                                                                        
  Goal: Establish a known-good baseline so we can verify determinism after the refactor.
                                                                                                                                                                                        
  ┌──────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────┐
  │ Step │                                                   Action                                                   │                Exit criteria                 │                  
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 0.1  │ Create branch pkg-layer-v0.3                                                                               │ branch exists                                │
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 0.2  │ Snapshot current state: git rev-parse HEAD saved to runs/_baseline/source-sha.txt                          │ sha recorded                                 │                  
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤                  
  │ 0.3  │ Run an existing Go SDK-addition TPRD end-to-end (pick smallest one in golden-corpus/ or use a trivial one) │ run completes, runs/<baseline-id>/ populated │                  
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤                  
  │ 0.4  │ Snapshot runs/<baseline-id>/ to runs/_baseline/golden/ (decision-log, generated code, metrics)             │ golden tree saved                            │
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤                  
  │ 0.5  │ Compute hash of generated code + decision-log structure → runs/_baseline/baseline-hash.txt                 │ hash file exists                             │
  └──────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────┘                  
                  
  Halt point: if step 0.3 fails (existing Go TPRD broken on current main), we fix that before doing any package work. No point refactoring a broken pipeline.                           
                  
  ---                                                                                                                                                                                   
  Phase 1 — Package Manifests (Day 1, ~4 hours)
                                                                                                                                                                                        
  Goal: Author the two package manifest files. No file moves, no agent prompt changes.
                                                                                                                                                                                        
  1.1 — Create .claude/packages/ directory                                                                                                                                              
                                                                                                                                                                                        
  .claude/packages/                                                                                                                                                                     
  ├── shared-core.json
  ├── go.json
  └── README.md   # 1-pager explaining the layer
                                                                                                                                                                                        
  1.2 — Author shared-core.json
                                                                                                                                                                                        
  {               
    "name": "shared-core",
    "version": "1.0.0",
    "type": "core",
    "description": "Language-agnostic orchestration, meta-skills, governance",                                                                                                          
    "depends": [],                                                                                                                                                                      
    "agents": [                                                                                                                                                                         
      "baseline-manager", "defect-analyzer", "improvement-planner",                                                                                                                     
      "learning-engine", "metrics-collector", "phase-retrospector",                                                                                                                     
      "root-cause-tracer", "guardrail-validator", "sdk-intake-agent",                                                                                                                   
      "sdk-design-lead", "sdk-impl-lead", "sdk-testing-lead",                                                                                                                           
      "sdk-merge-planner", "sdk-marker-scanner", "sdk-marker-hygiene-devil",                                                                                                            
      "sdk-skill-coverage-reporter", "sdk-skill-drift-detector",                                                                                                                        
      "sdk-drift-detector", "sdk-semver-devil", "sdk-design-devil",                                                                                                                     
      "sdk-security-devil", "sdk-overengineering-critic"                                                                                                                                
    ],                                                                                                                                                                                  
    "skills": [                                                                                                                                                                         
      "decision-logging", "lifecycle-events", "review-fix-protocol",                                                                                                                    
      "conflict-resolution", "context-summary-writing", "feedback-analysis",                                                                                                            
      "guardrail-validation", "mcp-knowledge-graph", "spec-driven-development",                                                                                                         
      "environment-prerequisites-check", "sdk-marker-protocol",                                                                                                                         
      "sdk-semver-governance", "api-ergonomics-audit", "tdd-patterns",                                                                                                                  
      "idempotent-retry-safety", "network-error-classification"                                                                                                                         
    ],                                                                                                                                                                                  
    "guardrails": [                                                                                                                                                                     
      "G01", "G02", "G03", "G04", "G07",                                                                                                                                                
      "G20", "G21", "G22", "G23", "G24",
      "G69", "G80", "G85", "G86", "G90", "G93"                                                                                                                                          
    ]                                                                                                                                                                                   
  }                                                                                                                                                                                     
                                                                                                                                                                                        
  1.3 — Author go.json

  {
    "name": "go",
    "version": "1.0.0",
    "type": "language-adapter",
    "description": "Go SDK pipeline adapter for motadatagosdk",                                                                                                                         
    "depends": ["shared-core@>=1.0.0"],                                                                                                                                                 
    "tier": "T1",                                                                                                                                                                       
    "agents": [                                                                                                                                                                         
      "sdk-existing-api-analyzer", "sdk-leak-hunter", "sdk-profile-auditor",                                                                                                            
      "sdk-soak-runner", "sdk-benchmark-devil", "sdk-complexity-devil",                                                                                                                 
      "sdk-perf-architect", "sdk-integration-flake-hunter",                                                                                                                             
      "sdk-dep-vet-devil", "sdk-convention-devil", "sdk-constraint-devil",                                                                                                              
      "documentation-agent",                                                                                                                                                            
      "code-reviewer", "refactoring-agent",                                                                                                                                             
      "sdk-api-ergonomics-devil", "sdk-breaking-change-devil"                                                                                                                           
    ],                                                                                                                                                                                  
    "skills": [                                                                                                                                                                         
      "go-concurrency-patterns", "go-error-handling-patterns",                                                                                                                          
      "go-struct-interface-design", "go-hexagonal-architecture",
      "go-module-paths", "go-dependency-vetting", "go-example-function-patterns",                                                                                                       
      "goroutine-leak-prevention", "fuzz-patterns", "mock-patterns",                                                                                                                    
      "table-driven-tests", "testcontainers-setup", "client-mock-strategy",                                                                                                             
      "connection-pool-tuning", "context-deadline-patterns",                                                                                                                            
      "sdk-config-struct-pattern", "sdk-otel-hook-integration",                                                                                                                         
      "client-rate-limiting",                                                                                                                                                           
      "circuit-breaker-policy", "backpressure-flow-control",                                                                                                                            
      "client-shutdown-lifecycle", "client-tls-configuration",                                                                                                                          
      "credential-provider-pattern", "otel-instrumentation", "testing-patterns"                                                                                                         
    ],                                                                                                                                                                                  
    "guardrails": [                                                                                                                                                                     
      "G30", "G31", "G32", "G33", "G34", "G38",                                                                                                                                         
      "G40", "G41", "G42", "G43", "G48",                                                                                                                                                
      "G60", "G61", "G63", "G65",
      "G95", "G96", "G97", "G98", "G99",                                                                                                                                                
      "G100", "G101", "G102", "G103"
    ],                                                                                                                                                                                  
    "toolchain": {                                                                                                                                                                      
      "build": "go build ./...",
      "test": "go test ./... -race -count=1",                                                                                                                                           
      "lint": "golangci-lint run",
      "vet": "go vet ./...",
      "fmt": "gofmt -l .",                                                                                                                                                              
      "coverage": "go test ./... -coverprofile=coverage.out",
      "coverage_min_pct": 90,                                                                                                                                                           
      "bench": "go test -bench=. -benchmem -count=10",                                                                                                                                  
      "supply_chain": ["govulncheck ./...", "osv-scanner --recursive ."],                                                                                                               
      "leak_check": "goleak.VerifyTestMain"                                                                                                                                             
    },                                                                                                                                                                                  
    "file_extensions": [".go"],                                                                                                                                                         
    "marker_comment_syntax": {
      "line": "//",                                                                                                                                                                     
      "block_open": "/*",
      "block_close": "*/"                                                                                                                                                               
    },
    "module_file": "go.mod"                                                                                                                                                             
  }               

  1.4 — Write scripts/validate-packages.sh                                                                                                                                              
   
  A small bash script that:                                                                                                                                                             
  - Confirms every agent file in .claude/agents/ is listed in exactly one package
  - Confirms every skill dir in .claude/skills/ is listed in exactly one package                                                                                                        
  - Confirms every guardrail script in scripts/guardrails/ is listed in exactly one package
  - Reports orphans + duplicates                                                                                                                                                        
  - Exit non-zero if any violation
                                                                                                                                                                                        
  This becomes a permanent CI check.
                                                                                                                                                                                        
  Exit criteria for Phase 1:                                                                                                                                                            
  - Both manifests committed                                                                                                                                                            
  - validate-packages.sh exits 0 (no orphans, no dupes)                                                                                                                                 
  - Total agents in manifests = 38 (confirms accounting)
  - Total skills = 41 (we missed 1 in earlier count — sdk-marker-protocol may already be in skills; verify)                                                                             
  - Total guardrails = 40                                                                                                                                                               
                                                                                                                                                                                        
  Halt point: if validate-packages.sh finds orphans, fix the manifests (or accept them as "unused, deprecate later") before proceeding.                                                 
                                                                                                                                                                                        
  ---             
  Phase 2 — TPRD Schema Update (Day 1, ~2 hours, parallel with Phase 1)                                                                                                                 
                                                                                                                                                                                        
  Goal: TPRD declares which packages it needs. Backwards-compatible defaulting.
                                                                                                                                                                                        
  2.1 — Update TPRD schema doc
                                                                                                                                                                                        
  Add to phases/INTAKE-PHASE.md (or wherever TPRD spec lives):                                                                                                                          
   
  ## §Target-Language (NEW, optional)                                                                                                                                                   
  Default: `go`. The primary language adapter package required for this run.                                                                                                            
  Validated against `.claude/packages/<lang>.json` existing.                                                                                                                            
                                                                                                                                                                                        
  ## §Target-Tier (NEW, optional)                                                                                                                                                       
  Default: `T1`. Pipeline tier — T1=full perf gates, T2=skeleton+governance, T3=out-of-scope.                                                                                           
                                                                                                                                                                                        
  ## §Required-Packages (NEW, optional, advanced)                                                                                                                                       
  Override list. Default: `["shared-core@>=1.0.0", "<§Target-Language>@>=1.0.0"]`.                                                                                                      
                                                                                                                                                                                        
  2.2 — Update example TPRD template + golden-corpus TPRDs                                                                                                                              
                                                                                                                                                                                        
  Add §Target-Language: go to all existing TPRDs in golden-corpus/. Defaulting handles existing in-flight TPRDs but explicit is better for golden-corpus determinism.                   
                  
  Exit criteria: schema doc updated; golden-corpus TPRDs all carry the new field.                                                                                                       
                  
  ---                                                                                                                                                                                   
  Phase 3 — Intake → active-packages.json (Day 2, ~4 hours)
                                                                                                                                                                                        
  Goal: sdk-intake-agent resolves the package set per run and writes a manifest the rest of the pipeline reads.
                                                                                                                                                                                        
  3.1 — Update .claude/agents/sdk-intake-agent.md                                                                                                                                       
                                                                                                                                                                                        
  Add to the prompt a new step after manifest validation:                                                                                                                               
                  
  ## Step N — Package Resolution                                                                                                                                                        
  1. Read §Target-Language (default: "go")
  2. Read §Target-Tier (default: "T1")                                                                                                                                                  
  3. Read §Required-Packages (default: ["shared-core@>=1.0.0", "<lang>@>=1.0.0"])
  4. For each declared package:                                                                                                                                                         
     a. Verify .claude/packages/<name>.json exists
     b. Verify version satisfies declared range                                                                                                                                         
     c. Recursively resolve `depends`
  5. Write runs/<run-id>/context/active-packages.json:                                                                                                                                  
     {            
       "run_id": "<id>",                                                                                                                                                                
       "resolved_at": "<iso8601>",                                                                                                                                                      
       "target_language": "go",
       "target_tier": "T1",                                                                                                                                                             
       "packages": [                                                                                                                                                                    
         {"name": "shared-core", "version": "1.0.0",
          "agents": [...], "skills": [...], "guardrails": [...]},                                                                                                                       
         {"name": "go", "version": "1.0.0",                                                                                                                                             
          "agents": [...], "skills": [...], "guardrails": [...],
          "toolchain": {...}, "file_extensions": [...]}                                                                                                                                 
       ]          
     }                                                                                                                                                                                  
  6. If any resolution fails: BLOCKER, halt at H1.
                                                                                                                                                                                        
  3.2 — Author new shared guardrail G05.sh                                                                                                                                              
                                                                                                                                                                                        
  # phases: intake                                                                                                                                                                      
  # severity: BLOCKER
  # active-packages.json valid + resolves                                                                                                                                               
   
  Verifies the file exists, references valid packages, no circular deps.                                                                                                                
                  
  Add G05 to shared-core.json guardrails list.                                                                                                                                          
                  
  Exit criteria:                                                                                                                                                                        
  - Run a TPRD through intake; active-packages.json produced
  - File contains exactly 38 agents + 41 skills + 40 guardrails (full Go set)                                                                                                           
  - G05.sh exits 0                                                           
                                                                                                                                                                                        
  Halt point: if active-packages.json is missing any artifact that the existing pipeline uses, the package manifests are incomplete. Fix before continuing.
                                                                                                                                                                                        
  ---             
  Phase 4 — Guardrail Validator Dispatch (Day 2, ~3 hours)                                                                                                                              
                                                                                                                                                                                        
  Goal: guardrail-validator only runs scripts listed in active packages — proving the package boundary actually filters something.
                                                                                                                                                                                        
  4.1 — Update .claude/agents/guardrail-validator.md                                                                                                                                    
                                                                                                                                                                                        
  Replace any "run all G*.sh in scripts/guardrails/" logic with:                                                                                                                        
                  
  ## Dispatch                                                                                                                                                                           
  1. Read runs/<run-id>/context/active-packages.json
  2. Collect union of `guardrails` arrays across all active packages → ACTIVE_GATES                                                                                                     
  3. For phase=<current>: filter ACTIVE_GATES to those whose `# phases:` header matches                                                                                                 
  4. Run only the filtered set                                                                                                                                                          
  5. Report: gates_active, gates_run, gates_skipped (with package attribution)                                                                                                          
                                                                                                                                                                                        
  4.2 — Determinism check                                                                                                                                                               
                                                                                                                                                                                        
  For a Go run, ACTIVE_GATES should be all 40 guardrails (since shared-core+go covers the full set). The validator must produce identical pass/fail results to baseline.                
   
  Exit criteria:                                                                                                                                                                        
  - Run intake → guardrail-validator at intake phase
  - Same gates fire as baseline run (G01, G07, G20-G24, G69, G05 newly)                                                                                                                 
  - No gate fires that wasn't in active packages                       
                                                                                                                                                                                        
  ---                                                                                                                                                                                   
  Phase 5 — Phase-Lead Agent Dispatch (Day 3, ~6 hours)                                                                                                                                 
                                                                                                                                                                                        
  Goal: phase-leads only invoke agents in active packages. The most prompt-editing-heavy phase.
                                                                                                                                                                                        
  5.1 — Audit current phase-lead prompts
                                                                                                                                                                                        
  For each of sdk-design-lead, sdk-impl-lead, sdk-testing-lead, find every agent invocation pattern:                                                                                    
   
  grep -E "Agent.*sdk-|invoke.*sdk-" .claude/agents/sdk-*-lead.md                                                                                                                       
                                                                                                                                                                                        
  Each invocation needs to gain a "if active-packages includes this agent, invoke; else log skip-with-reason."                                                                          
                                                                                                                                                                                        
  5.2 — Update phase-lead prompts                                                                                                                                                       
                  
  Add a header block to each:                                                                                                                                                           
                  
  ## Active Package Awareness
  Before invoking any specialist agent, verify it's in the active-packages.json                                                                                                         
  agent set:                                                                                                                                                                            
                                                                                                                                                                                        
    ACTIVE_AGENTS = read runs/<run-id>/context/active-packages.json | union(.packages[].agents)                                                                                         
                  
  If a specialist is NOT in ACTIVE_AGENTS:                                                                                                                                              
    - Log decision-log entry: type="event", reason="agent-not-in-active-packages"
    - Skip the invocation                                                                                                                                                               
    - Do NOT halt unless the missing agent is critical for the active tier (T1 requires                                                                                                 
      sdk-leak-hunter, sdk-profile-auditor, sdk-benchmark-devil; T2 doesn't)                                                                                                            
                                                                                                                                                                                        
  Critical-for-tier checks:                                                                                                                                                             
    T1: requires {sdk-leak-hunter, sdk-profile-auditor, sdk-benchmark-devil,                                                                                                            
                  sdk-soak-runner, sdk-complexity-devil}                                                                                                                                
    T2: requires {build, test, lint, supply-chain agents only}                                                                                                                          
                                                                                                                                                                                        
  5.3 — Determinism check                                                                                                                                                               
                                                                                                                                                                                        
  For Go T1 run, all current agents fire (active-packages contains them all). Output should match baseline byte-for-byte.                                                               
   
  Exit criteria:                                                                                                                                                                        
  - Run end-to-end Go TPRD
  - Decision-log shows same agent invocations as baseline (modulo new "active-package-resolved" event)                                                                                  
  - Generated code byte-identical to baseline                                                         
                                                                                                                                                                                        
  Halt point: if any expected agent doesn't fire, the prompt edit broke dispatch. Diff prompts and fix.                                                                                 
                                                                                                                                                                                        
  ---                                                                                                                                                                                   
  Phase 6 — Toolchain.md Generation (Day 3, ~2 hours)                                                                                                                                   
                                                                                                                                                                                        
  Goal: sdk-intake-agent writes the toolchain.md file (data-only — no agent reads it yet, that's R2 work).
                                                                                                                                                                                        
  6.1 — Update sdk-intake-agent prompt
                                                                                                                                                                                        
  After writing active-packages.json, also write runs/<run-id>/context/toolchain.md:                                                                                                    
   
  <!-- Generated: <iso8601> | Run: <run_id> | Pipeline: 0.3.0 -->                                                                                                                       
  # Toolchain (resolved from package: go@1.0.0)                                                                                                                                         
                                                                                                                                                                                        
  ## Build                                                                                                                                                                              
  go build ./...                                                                                                                                                                        
                                                                                                                                                                                        
  ## Test         
  go test ./... -race -count=1

  ## Lint
  golangci-lint run

  ## Coverage minimum
  90%

  ## File extensions                                                                                                                                                                    
  .go
                                                                                                                                                                                        
  ## Marker comment syntax
  line: //
  block: /* */

  This is informational for now — proves the data flow works. Future agents will read it.                                                                                               
   
  Exit criteria: toolchain.md present in run dir; content matches go.json toolchain block.                                                                                              
                  
  ---                                                                                                                                                                                   
  Phase 7 — End-to-End Validation (Day 4, ~4 hours)
                                                                                                                                                                                        
  Goal: Prove rule 25 determinism holds.
                                                                                                                                                                                        
  7.1 — Run the same TPRD as Phase 0 baseline
                                                                                                                                                                                        
  commands/run-sdk-addition.md with the baseline TPRD. New run-id.                                                                                                                      
   
  7.2 — Diff against baseline                                                                                                                                                           
                  
  diff -r runs/_baseline/golden/ runs/<new-id>/   # ignoring timestamps
                                                                                                                                                                                        
  Areas to check:
  - Decision-log entry types + counts (modulo new package-resolution events)                                                                                                            
  - Generated code (byte-identical expected)                                                                                                                                            
  - Guardrail pass/fail set                 
  - Final metrics                                                                                                                                                                       
  - Baseline updates
                                                                                                                                                                                        
  7.3 — Run metrics-collector on both, compare                                                                                                                                          
                                                                                                                                                                                        
  Quality scores, defect counts, coverage % must all match.                                                                                                                             
                                                                                                                                                                                        
  7.4 — Run phase-retrospector on the new run                                                                                                                                           
                  
  Final verdict: PASS = ship it. FAIL = diagnose.                                                                                                                                       
   
  Exit criteria:                                                                                                                                                                        
  - Generated SDK code: byte-identical (modulo formatting whitespace)
  - Decision-log: structurally equivalent (same entry types, same agents fired)                                                                                                         
  - Metrics: identical scores                                                  
  - All guardrails: same pass/fail outcomes                                                                                                                                             
                                                                                                                                                                                        
  Halt point — CRITICAL: if determinism breaks here, do NOT proceed. Diagnose which dispatch decision changed. Most likely cause: a phase-lead skipped an agent that should have fired  
  (Phase 5 prompt edit too aggressive).                                                                                                                                                 
                  
  ---                                                                                                                                                                                   
  Phase 8 — Documentation Updates (Day 4-5, ~6 hours)
                                                                                                                                                                                        
  Goal: Make the new layer discoverable + maintainable.
                                                                                                                                                                                        
  ┌─────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │              File               │                                                                     Change                                                                     │  
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ CLAUDE.md                       │ Add new rule 32 "Package Layer" — what it is, how packages get selected. Update Project Context to reference active-packages instead of        │
  │                                 │ hardcoding Go. Update rule 23 to mention package-scoped skills.                                                                                │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ AGENTS.md                       │ Add a "Package" column to ownership matrix                                                                                                     │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ SKILL-CREATION-GUIDE.md         │ Add "Package Assignment" section: every new skill must be added to exactly one package manifest                                                │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ AGENT-CREATION-GUIDE.md         │ Same: package assignment required                                                                                                              │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ README.md                       │ Mention package layer in architecture overview                                                                                                 │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ phases/INTAKE-PHASE.md          │ Document §Target-Language, §Target-Tier, §Required-Packages                                                                                    │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ phases/*-PHASE.md               │ Note that specialists are package-gated                                                                                                        │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ docs/PACKAGE-AUTHORING-GUIDE.md │ NEW — how to add a new language package (~2 pages)                                                                                             │
  ├─────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤  
  │ pipeline-map.html               │ Defer unless trivial; mark as TODO                                                                                                             │
  └─────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘  
                  
  Exit criteria: doc files updated; new authoring guide exists.                                                                                                                         
                  
  ---                                                                                                                                                                                   
  Phase 9 — Pipeline Version Bump + Evolution Report (Day 5, ~1 hour)
                                                                                                                                                                                        
  ┌──────┬────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Step │                                             Action                                             │                                                                             
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 9.1  │ Bump pipeline_version: "0.2.0" → "0.3.0" in .claude/settings.json                              │                                                                             
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ 9.2  │ Author evolution/evolution-reports/0.3.0-package-layer.md: what changed, why, how to roll back │                                                                             
  ├──────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                                             
  │ 9.3  │ Update commands/run-sdk-addition.md if it references pipeline_version                          │                                                                             
  └──────┴────────────────────────────────────────────────────────────────────────────────────────────────┘                                                                             
                  
  ---                                                                                                                                                                                   
  Phase 10 — PR + Code Review (Day 5)
                                                                                                                                                                                        
  ┌──────┬───────────────────────────────────────────────────┐
  │ Step │                      Action                       │                                                                                                                          
  ├──────┼───────────────────────────────────────────────────┤
  │ 10.1 │ Open PR from pkg-layer-v0.3 → mcp-enhanced-graph  │
  ├──────┼───────────────────────────────────────────────────┤
  │ 10.2 │ Run code-reviewer agent on the PR                 │                                                                                                                          
  ├──────┼───────────────────────────────────────────────────┤                                                                                                                          
  │ 10.3 │ Address review findings using review-fix-protocol │                                                                                                                          
  ├──────┼───────────────────────────────────────────────────┤                                                                                                                          
  │ 10.4 │ Merge after determinism re-validation in CI       │
  └──────┴───────────────────────────────────────────────────┘                                                                                                                          
   
  ---                                                                                                                                                                                   
  Critical Path Summary

  Day 0:  [Pre-flight, baseline capture]
  Day 1:  [Manifests] || [TPRD schema]                                                                                                                                                  
  Day 2:  [Intake → active-packages] → [Guardrail dispatch]                                                                                                                             
  Day 3:  [Phase-lead dispatch] → [toolchain.md]                                                                                                                                        
  Day 4:  [E2E validation] → [Docs]                                                                                                                                                     
  Day 5:  [Version bump] → [PR + review]                                                                                                                                                
                                                                                                                                                                                        
  Total: ~5 working days, single-engineer.                                                                                                                                              
                                                                                                                                                                                        
  Rollback Plan                                                                                                                                                                         
                  
  If anything breaks:
  1. The package manifests are inert until intake/validator read them. Reverting just intake + validator agent prompts disables the layer.
  2. git revert <commit-range> returns to flat layout.                                                                                                                                  
  3. No file moves means no recovery work — everything is where it always was.
  4. pipeline_version stays at 0.2.0 if rollback happens before Phase 9.                                                                                                                
                                                                                                                                                                                        
  Explicit Non-Goals (don't get sidetracked)                                                                                                                                            
                                                                                                                                                                                        
  - ❌ Moving any agent/skill/guardrail files into subdirectories                                                                                                                       
  - ❌ Authoring any non-Go skills (Python/Rust/Java come later)
  - ❌ Splitting any "disputed" skills (defer until 2nd lang need)                                                                                                                      
  - ❌ Building bench-output normalizer                                                                                                                                                 
  - ❌ Touching learning-engine cross-language safety                                                                                                                                   
  - ❌ Updating pipeline-map.html deeply (small note only)                                                                                                                              
  - ❌ Real package distribution (npm-style with install hooks)                                                                                                                         
                                                                                                                                                                                        
  Risk Register                                                                                                                                                                         
                                                                                                                                                                                        
  ┌───────────────────────────────────────────────────────┬────────────┬────────┬────────────────────────────────────────────────────────┐                                              
  │                         Risk                          │ Likelihood │ Impact │                       Mitigation                       │
  ├───────────────────────────────────────────────────────┼────────────┼────────┼────────────────────────────────────────────────────────┤
  │ Determinism breaks at Phase 7                         │ Medium     │ High   │ Strong baseline at Phase 0; fast revert path           │
  ├───────────────────────────────────────────────────────┼────────────┼────────┼────────────────────────────────────────────────────────┤
  │ Phase-lead prompts have subtle dispatch changes       │ Medium     │ High   │ Side-by-side decision-log diff                         │                                              
  ├───────────────────────────────────────────────────────┼────────────┼────────┼────────────────────────────────────────────────────────┤                                              
  │ validate-packages.sh finds orphans we forgot          │ Low        │ Low    │ Fix in manifests; iterate                              │                                              
  ├───────────────────────────────────────────────────────┼────────────┼────────┼────────────────────────────────────────────────────────┤                                              
  │ TPRD default-language breaks existing in-flight TPRDs │ Low        │ Low    │ Default to go everywhere                               │
  ├───────────────────────────────────────────────────────┼────────────┼────────┼────────────────────────────────────────────────────────┤                                              
  │ Claude Code harness doesn't see new guardrail G05     │ Low        │ Low    │ G05 is a script, not an agent — no harness involvement │
  ├───────────────────────────────────────────────────────┼────────────┼────────┼────────────────────────────────────────────────────────┤                                              
  │ Doc updates missed → future contributor confusion     │ Medium     │ Medium │ Phase 8 is mandatory before merge                      │
  └───────────────────────────────────────────────────────┴────────────┴────────┴────────────────────────────────────────────────────────┘                                              
                  
  ---                                                                                                                                                                                   
  Decisions I need from you before starting
                                                                                                                                                                                        
  1. Manifest-only confirmed? (vs physical packaging — strongly recommend manifest-only)
  2. Pipeline version: 0.2.0 → 0.3.0 ok, or do you want 0.3.0-rc.1 first?                                                                                                               
  3. Branch base: off mcp-enhanced-graph (current) or off main?                                                                                                                         
  4. TPRD for baseline run (Phase 0): pick the smallest existing TPRD in golden-corpus/, or use a trivial test TPRD I draft?                                                            
  5. Disputed skills/agents (4 agents + 6 skills): keep in pkg-go for now (my recommendation) or attempt to split now?                                                                  
                                                                                                                                                                                        
  Once you confirm those five, I can start Phase 0 immediately.