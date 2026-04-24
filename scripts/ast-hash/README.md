# AST-Hash Protocol — Phase P1 deliverable

> Part of the C-refactor (shared core + language packs). Replaces the byte-range SHA256 in the marker protocol (G95/G96) and the regex-based Go symbol scanners (G99–G103) with a language-pluggable AST hasher.

## Why

The current marker protocol (CLAUDE.md §29) byte-hashes source regions to lock `[owned-by: MANUAL]` symbols against pipeline modification. This is **fragile**:

- `gofmt` on an adjacent symbol shifts byte offsets → false-positive BLOCKER
- comment edits flip the hash even without semantic change
- every check is Go-specific (Go comment syntax, Go symbol regex)

AST-hashing fixes all three: the hash is computed over a **canonical form** of the symbol's AST subtree, stripped of comments and formatting.

## Interface

```
ast-hash.sh <pack> <file> <symbol>   →   <sha256-hex>
```

- `<pack>`: `go` (P1), `python` (P4)
- `<file>`: absolute or relative path to the source file
- `<symbol>`: name of the symbol:
  - `Foo` — top-level func/type/var/const named Foo
  - `T.Foo` — method Foo on type T (handles pointer + generic receivers)
  - `T` — type T (bare)

Success: prints the hash + exits 0.
Failure exits:
- 2: usage error
- 3: file missing
- 4: backend missing for the pack
- 5: pack not implemented yet
- 6: unknown pack

The Go backend additionally uses:
- 3: Go parse error
- 4: symbol not found

## Canonicalization rules

The Go backend (`go-backend.go`):

1. Parses the file with `go/parser.ParseFile(fset, path, nil, 0)` — **no `ParseComments` flag**, so comments are discarded at parse time.
2. Walks `file.Decls` to locate the named symbol (FuncDecl, TypeSpec, ValueSpec).
3. Prints the node with `go/printer.Config{Mode: TabIndent|UseSpaces, Tabwidth: 8}` — deterministic output for any AST.
4. Trims trailing whitespace, appends a single newline.
5. SHA256 of the canonical bytes.

This gives **the invariances we want**:
- Whitespace change in the symbol → same hash.
- Comment added/edited/removed → same hash.
- Import reordering (outside the symbol) → same hash.
- Formatter change (gofmt version bump) → same hash (printer is version-stable).

And the **sensitivity we want**:
- Any identifier renamed, statement added/removed, expression changed → different hash.

## Worked examples (Go)

```bash
# Hash the Client.Get method of an SDK client
./ast-hash.sh go core/l2cache/dragonfly/cache.go 'Client.Get'
# → 3f5a...b091

# Hash a top-level type
./ast-hash.sh go core/l2cache/dragonfly/config.go 'Config'
# → 8e2c...a4df

# Hash a constant (top-level ValueSpec)
./ast-hash.sh go core/l2cache/dragonfly/const.go 'DefaultPoolSize'
# → 7b1d...9e00
```

## Integration with `ownership-map.json`

The marker protocol's ownership map gains two new fields:

```json
{
  "symbol": "Client.Get",
  "file": "core/l2cache/dragonfly/cache.go",
  "language": "go",              // NEW — drives pack dispatch
  "ast_hash": "3f5a...b091",     // NEW — preferred

  "byte_start": 1234,            // DEPRECATED (kept one release)
  "byte_end": 1580,              // DEPRECATED
  "sha256": "..."                // DEPRECATED (byte-range hash)
}
```

`G95.sh` / `G96.sh` check `ast_hash` first; fall back to `sha256`+`byte_start`/`byte_end` for older ownership maps. After one pipeline-version release (0.3.0 → 0.4.0) the byte fields are removed.

## Testing

`tests/ast-hash/` (P1 week 2) will contain:

1. **gofmt invariance**: same symbol, pre-gofmt vs. post-gofmt source → identical hashes.
2. **comment invariance**: same symbol, comment added → identical hash.
3. **semantic sensitivity**: single identifier renamed inside the symbol → different hash.
4. **receiver resolution**: `T.X`, `*T.X`, `T[K].X`, `T[K,V].X` all resolve correctly.
5. **unknown symbol**: exits 4.
6. **parse error** (malformed Go): exits 3.

## What's next (P3 migration)

When Phase P3 creates `packs/go/`:

1. `scripts/ast-hash/go-backend.go` → `packs/go/ast-hash-backend.go`
2. `packs/go/pack-manifest.yaml` declares `ast_hash_backend: ast-hash-backend.go`
3. The dispatcher's `go` branch prefers `$ROOT/packs/go/ast-hash-backend.go` (it already does — P1 dispatcher was written pack-aware).
4. Add `packs/python/ast-hash-backend.py` (uses Python's `ast` stdlib module) when P4 kicks off.
