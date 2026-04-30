# Evolution Log — python-dependency-vetting

## 1.0.0 — v0.5.0-phase-b — 2026-04-28
Initial authorship. Per-dep checks V-1 through V-11 (license / pip-audit / safety / size / age / transitives / PyPI adoption / GitHub maintenance / Sigstore PEP 740 / typosquat Levenshtein / native-code provenance / Python version compat); license allowlist + conditional + reject sets; aggregate verdict logic ACCEPT/CONDITIONAL/REJECT/INCOMPLETE; common alternatives table for rejected deps; TPRD §10 template. Drives sdk-dep-vet-devil-python verdicts. Python pack analog of go-dependency-vetting.
