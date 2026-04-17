# verify-provenance (spec)

One-time maintenance script — NOT a runtime dependency. The pipeline is fully independent and does not read the archive at runtime. This script is only relevant when someone wants to re-check that inlined content still matches its archive origin (e.g., before cutting a new `pipeline_version`).

## Intent

Given an optional path to the archived source (passed as argument), for every "Ported verbatim" entry in `PROVENANCE.md`:
- Run `diff` between the inlined pipeline file and the archive file
- FAIL if drift exists without a `// [SDK-MODE deviation]` marker in the pipeline file

For every "Ported with delta" entry:
- Verify the pipeline file contains at least one `// [SDK-MODE deviation]:` marker
- Verify the delta description in PROVENANCE matches a deviation comment

## Exit

- 0: all provenance verified
- 1: drift without marker
- 2: delta entry missing deviation marker
- 3: archive path argument not provided or not reachable

## Usage

```bash
# archive path is a script argument; pipeline has no runtime archive dependency
scripts/verify-provenance.sh /path/to/motadata-ai-pipeline-ARCHIVE
```

## When to run

- After applying a prompt patch via `learning-engine` (verify it only adjusted deltas, not core ports)
- Before releasing a new `pipeline_version`
- Never during a normal pipeline run — provenance is frozen at port time; this is a maintainer tool

## Script body (to implement)

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_ROOT="${1:-}"
if [ -z "$ARCHIVE_ROOT" ] || [ ! -d "$ARCHIVE_ROOT" ]; then
  echo "Usage: $0 <path-to-archive-root>"
  exit 3
fi

ERRORS=0

# Extract "Ported verbatim" entries from PROVENANCE.md
grep -E "Ported verbatim" PROVENANCE.md | while read -r line; do
  new_path=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' `')
  archive_rel=$(echo "$line" | awk -F'|' '{print $4}' | tr -d ' `')
  if ! diff -q "$new_path" "$ARCHIVE_ROOT/$archive_rel" >/dev/null; then
    echo "DRIFT: $new_path diverged from archive $archive_rel"
    ERRORS=$((ERRORS+1))
  fi
done

# Extract "Ported with delta" entries; verify [SDK-MODE deviation] markers
grep -E "Ported with delta" PROVENANCE.md | while read -r line; do
  new_path=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' `')
  if ! grep -q "SDK-MODE deviation" "$new_path" 2>/dev/null; then
    echo "MISSING DEVIATION MARKER: $new_path"
    ERRORS=$((ERRORS+1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo "Provenance verification: $ERRORS issue(s)"
  exit 1
fi
echo "Provenance verification: OK"
```
