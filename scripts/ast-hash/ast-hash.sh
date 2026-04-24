#!/usr/bin/env bash
# ast-hash.sh — language-neutral dispatcher for the marker-protocol AST hasher.
#
# Resolves a pack → invokes the pack's AST-hash backend → emits the canonical
# SHA256 of the named symbol's AST subtree to stdout.
#
# Usage: ast-hash.sh <pack> <file> <symbol>
#   ast-hash.sh go /path/to/cache.go 'Client.Get'
#
# Exit 0 on success, non-zero on error (unknown pack, missing file, symbol
# not found, parse error).
#
# Transitional note: during P1 (pre-pack-layout), the Go backend lives at
#   scripts/ast-hash/go-backend.go. It will move to packs/go/ast-hash-backend.go
#   in Phase P3. The dispatcher prefers the new location if present.

set -euo pipefail

if [ $# -ne 3 ]; then
    echo "usage: $0 <pack> <file> <symbol>" >&2
    exit 2
fi

PACK="$1"
FILE="$2"
SYMBOL="$3"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$FILE" ]; then
    echo "file not found: $FILE" >&2
    exit 3
fi

case "$PACK" in
    go)
        # Prefer compiled binaries; fall back to `go run` only if no binary exists.
        # Binaries propagate exit codes faithfully; `go run` collapses any non-zero
        # program exit into a generic 1, which loses the protocol's exit-code contract.
        if [ -x "$ROOT/packs/go/ast-hash-backend" ]; then
            exec "$ROOT/packs/go/ast-hash-backend" -file "$FILE" -symbol "$SYMBOL"
        elif [ -x "$ROOT/scripts/ast-hash/go-backend" ]; then
            exec "$ROOT/scripts/ast-hash/go-backend" -file "$FILE" -symbol "$SYMBOL"
        elif [ -f "$ROOT/scripts/ast-hash/go-backend.go" ]; then
            # Auto-build on first use, then exec.
            if go build -o "$ROOT/scripts/ast-hash/go-backend" "$ROOT/scripts/ast-hash/go-backend.go"; then
                exec "$ROOT/scripts/ast-hash/go-backend" -file "$FILE" -symbol "$SYMBOL"
            fi
            # Build failed — last-ditch via go run (exit codes will be lossy).
            go run "$ROOT/scripts/ast-hash/go-backend.go" -file "$FILE" -symbol "$SYMBOL"
        else
            echo "go AST-hash backend missing" >&2
            exit 4
        fi
        ;;
    python)
        SRC="$ROOT/packs/python/ast-hash-backend.py"
        if [ ! -f "$SRC" ]; then
            echo "python AST-hash backend not yet implemented (P4 deliverable)" >&2
            exit 5
        fi
        python3 "$SRC" "$FILE" "$SYMBOL"
        ;;
    *)
        echo "unknown pack: $PACK (expected: go | python)" >&2
        exit 6
        ;;
esac
