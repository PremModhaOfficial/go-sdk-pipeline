# pytest-table-tests — evolution log

- 1.0.0 (2026-04-27): initial — authored as part of v0.5.0 Phase A Python adapter pilot. Reference style: matched go-concurrency-patterns / context-deadline-patterns.
- v1.0.1 (run sdk-resourcepool-py-pilot-v1, 2026-04-28): PATCH bump — appended "Pilot lessons — bare-list parametrize" subsection citing test_construction.py:97 regression risk; reaffirmed `pytest.param(..., id=...)` is mandatory for ≥2-tuple params; added single-value bare-list carve-out + reviewer cue. Description tightened to mention bare-list regression risk. Source: improvement-plan A2; skill-drift §SKD-001 MODERATE. Applied by: learning-engine.
