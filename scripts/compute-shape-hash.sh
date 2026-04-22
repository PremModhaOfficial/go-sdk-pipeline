#!/usr/bin/env bash
# compute-shape-hash.sh — emits SHA256 of the sorted exported-symbol signature
# list of a Go package. Used as an output-shape baseline: a silent API drift
# between runs that invoked overlapping skills changes this hash.
#
# Usage: compute-shape-hash.sh <package-dir>
# Output (stdout): <sha256>  <export_count>
# Exit: 0 on success; 1 on missing dir or no Go files
set -uo pipefail
PKG="${1:?package-dir required}"
[ -d "$PKG" ] || { echo "no such dir: $PKG" >&2; exit 1; }

# Extract exported signatures — keep the full line (params + return shape matter)
# Match: func, func (receiver), type, var, const at exported names.
SIGS=$(grep -hE '^(func( \([^)]+\))? [A-Z]|type [A-Z]|var [A-Z]|const [A-Z])' \
  "$PKG"/*.go 2>/dev/null \
  | grep -v '_test\.go' \
  | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+|[[:space:]]+$//g' \
  | sort -u)

if [ -z "$SIGS" ]; then
  echo "no exported symbols found in $PKG" >&2
  exit 1
fi

COUNT=$(printf '%s\n' "$SIGS" | wc -l | tr -d ' ')
HASH=$(printf '%s\n' "$SIGS" | sha256sum | awk '{print $1}')
echo "$HASH  $COUNT"
