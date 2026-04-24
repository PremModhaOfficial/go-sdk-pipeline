---
name: api-ergonomics-audit
description: Consumer-side ergonomics checklist — constructor shape, godoc discoverability, Example_* presence, error-value discoverability, idiomatic-Go surface checks. Feeds sdk-api-ergonomics-devil.
version: 1.0.0
authored-in: v0.3.0-straighten
created-in-run: bootstrap-seed
last-evolved-in-run: v0.3.0-straighten
source-pattern: core/l2cache/dragonfly/, general-go-sdk-idioms
status: stable
priority: SHOULD
tags: [api-design, ergonomics, godoc, examples, consumer-pov, meta]
trigger-keywords: [quickstart, godoc, Example_, boilerplate, "consumer experience", ergonomics, "ctx first param", "errors.Is"]
---

# api-ergonomics-audit (v1.0.0)

## Rationale

An SDK succeeds or fails on the first ten minutes of a new integrator's experience. Every extra line in "hello world", every missing `Example_*` in godoc, every sentinel error that does not surface via `errors.Is`, and every parameter named `timeout` that takes seconds-as-int instead of `time.Duration` costs hundreds of future-user hours. The Go standard library's ergonomics — `http.Client{}` works zero-config, `errors.Is` is the canonical matching verb, `Example_*` renders on pkg.go.dev — is the bar motadatagosdk should meet. This skill is a checklist the design-phase `sdk-api-ergonomics-devil` evaluates against; because it is SHOULD-priority (not MUST), findings are NEEDS-FIX rather than BLOCKER unless combined with a MUST-violation.

## Activation signals

- Phase 1 design exit — any new exported package gets the audit
- Phase 2 review wave — `sdk-api-ergonomics-devil` scheduled
- TPRD §11 "Usage examples" section is empty or thin
- No `Example_*` functions in `*_test.go` of a new package
- Quickstart in README exceeds ~10 lines
- Design proposes a method that returns three or more distinct error types via `(T, error1, error2)`

## The 8-point audit checklist

1. **Quickstart ≤5 lines (excluding imports + error handling).** "Hello world" is construct → use → close. If it takes more, either Config has too many required fields (consider defaults) or `New` signature is wrong shape.
2. **Constructor shape matches sibling package** (see `sdk-config-struct-pattern`). Config struct for low-field clients; functional options for wide configs.
3. **`context.Context` is the FIRST parameter on every I/O method.** Never 2nd, never last. CLAUDE.md rule 6.
4. **Every exported function+method pair has a godoc starting with the symbol name.** `Get fetches ...`, `New constructs ...`. gofmt/staticcheck enforces this; missing first-word-is-name is a NEEDS-FIX.
5. **At least one `Example_*` per exported symbol where applicable.** Package-level `Example()` for quickstart; `ExampleType_Method()` for each significant method. These render in godoc. Missing Example is HIGH.
6. **Sentinel errors are exported `ErrX` and discoverable via `errors.Is`.** No `return errors.New("some string")` — every failure mode is a package-level var.
7. **No forced boilerplate on the caller.** If every call needs `if err != nil && !errors.Is(err, io.EOF) { ... }`, the API should fold that into the return contract. Two-error returns `(T, error, error)` are always wrong.
8. **Consistency with sibling packages.** `Close(ctx)` not `Shutdown(ctx)` if siblings use Close. `Duration` in field names means `time.Duration` not `int`-seconds. Return `*T` when siblings do.

## GOOD examples

5-line quickstart — `dragonfly` opens, uses, closes. `errors.Is` surfaces a miss as a discriminated sentinel rather than a string match:

```go
cache, err := dragonfly.New(dragonfly.WithAddr("localhost:6379"))
if err != nil { return err }
defer cache.Close()
if err := cache.Set(ctx, "k", "v", 0); err != nil { return err }
v, err := cache.Get(ctx, "k")
```
(Source pattern: `core/l2cache/dragonfly/example_test.go` `Example()` function. Package-level `Example()` renders as the intro on pkg.go.dev.)

Godoc-runnable Example with `// Output:` block — tests the example AND renders in docs, satisfying checklist item 5:

```go
// Example demonstrates constructing a Cache, performing a Set/Get
// round-trip, and classifying a miss via errors.Is.
func Example() {
    mr, _ := miniredis.Run()
    defer mr.Close()
    cache, _ := dragonfly.New(dragonfly.WithAddr(mr.Addr()), dragonfly.WithProtocol(2))
    defer cache.Close()

    ctx := context.Background()
    _ = cache.Set(ctx, "greeting", "hello", 0)
    v, _ := cache.Get(ctx, "greeting")
    fmt.Println(v)

    _, err := cache.Get(ctx, "absent")
    if errors.Is(err, dragonfly.ErrNil) {
        fmt.Println("absent: miss")
    }
    // Output:
    // hello
    // absent: miss
}
```
(Source: `core/l2cache/dragonfly/example_test.go` lines 20-57.)

Sentinel-error discoverability — every failure mode is a package var with godoc:

```go
// ErrNil is the sentinel for "key not found" (mirrors redis.Nil).
// [traces-to: TPRD-§7-ErrNil]
var ErrNil = errors.New("dragonfly: key not found")

// ErrTimeout wraps context.DeadlineExceeded and net timeout errors.
var ErrTimeout = errors.New("dragonfly: timeout")

// ErrCircuitOpen is returned by any data-path call when the
// configured circuit breaker is OPEN.
var ErrCircuitOpen = errors.New("dragonfly: circuit open")
```
(Source: `core/l2cache/dragonfly/errors.go` lines 22-103. 19 sentinels; each has godoc + `[traces-to:]`; `errors.Is(err, dragonfly.ErrTimeout)` is the canonical match.)

## BAD examples (anti-patterns)

String-match error discrimination — caller must know the literal message, which breaks on any rewording:

```go
// BAD API
func (c *Cache) Get(ctx context.Context, k string) (string, error) {
    if !found {
        return "", fmt.Errorf("key %q not found", k)  // <-- no sentinel
    }
    // ...
}

// BAD caller
v, err := cache.Get(ctx, "k")
if err != nil && strings.Contains(err.Error(), "not found") {  // <-- fragile
    // handle miss
}
```
Why it breaks: any godoc tweak that changes `"not found"` to `"missing"` breaks every caller silently. Export `ErrNotFound`; consumers write `errors.Is(err, cache.ErrNotFound)`. Go stdlib pattern: `io.EOF`, `os.ErrNotExist`, `sql.ErrNoRows`.

Context-as-last-param — violates Go-stdlib + motadatagosdk convention (CLAUDE.md rule 6):

```go
// BAD
func (c *Cache) Get(key string, ctx context.Context) (string, error) { ... }
```
Why it breaks: staticcheck/`golint` + every Go reviewer flags this. It also defeats code-generated wrappers that assume ctx-first. `sdk-api-ergonomics-devil` marks it BLOCKER because fixing after v1.0.0 requires a major bump.

Missing `Example_*` — godoc page renders without runnable code:

```go
// BAD
package dragonfly
// No *_example_test.go file. godoc shows type docs only.
type Cache struct { ... }
func New(opts ...Option) (*Cache, error) { ... }
```
Why it breaks: pkg.go.dev displays "Examples" section with nothing in it. First-time users hit godoc, find type+method listings, and have to reverse-engineer construction from tests. HIGH finding; ergonomics-devil adds it to every audit.

Surprising default — `Config{}` zero-value that silently succeeds but is insecure / misconfigured:

```go
// BAD: zero-value is accepted, TLS disabled, credentials empty, localhost:6379 assumed
cache, _ := dragonfly.New()   // returns a Cache that will panic on first use
```
Why it breaks: misleading. Either reject zero-value config (dragonfly does — `Addr == ""` returns `ErrInvalidConfig`) OR provide a `Default()` that is demonstrably safe for dev. Never split the difference.

## Decision criteria

Severity ladder for findings:
- **BLOCKER** — ctx not first, two-error returns, panic on documented valid input, forged zero-value
- **HIGH** — missing `Example_*`, missing sentinel for a documented failure mode, constructor >5-line quickstart
- **MEDIUM** — inconsistency with siblings (Shutdown vs Close, int-seconds vs Duration), missing `Default()`, field naming drift
- **LOW** — godoc phrasing, ordering of options functions, package-doc thinness

Audit output format (see `.claude/agents/sdk-api-ergonomics-devil.md`): re-write the quickstart by hand from the README; if the result is >5 lines OR needs unfamiliar primitives, mark NEEDS-FIX with a finding id like `IM-401`. Every finding carries a suggested fix.

Greenfield vs retrofit: in Mode A (new package) fix every HIGH+ finding before Phase 2 exit — the cost of shipping a bad API is lifetime-of-the-SDK. In Mode B/C fix HIGH+ where the change is source-compatible; if it requires a semver-major bump, defer to the next major release and record in `docs/PROPOSED-API-CHANGES.md`.

## Cross-references

- `sdk-config-struct-pattern` — constructor shape drives quickstart length; this audit is a downstream check
- `sdk-otel-hook-integration` — ergonomics audit includes "is the instrumentation invisible to the consumer?" — it should be (dragonfly achieves this — consumer never touches `otel.*`)
- `go-example-function-patterns` — example-function structure, `// Output:` discipline, runnability
- `go-error-handling-patterns` — sentinel-error taxonomy, `errors.Is`/`errors.As` discipline
- `sdk-semver-governance` — an ergonomics-driven API rewrite that changes signatures triggers a major bump
- `spec-driven-development` — TPRD §11 "Usage" section is where the quickstart lands first; ergonomics review flows back into §11 edits

## Guardrail hooks

No single `Gxx.sh` enforces ergonomics directly — this is a judgment-call skill expressed through `sdk-api-ergonomics-devil`'s `NEEDS-FIX` findings. Related guardrails that partially enforce:

- **G63** (if present — verify) / `go vet` + staticcheck — first-word-is-name godoc.
- **G16** — every exported function has `Example_*` where applicable. HIGH (SHOULD, not BLOCKER).
- **G68** — package-level `doc.go` with package godoc. BLOCKER.
- **G99** — every exported symbol carries `[traces-to:]`. BLOCKER (enforces godoc block exists, which the audit builds on).

Verdict storage: `runs/<id>/impl/reviews/api-ergonomics-devil.md`. Review-fix loop per `review-fix-protocol`: HIGH findings loop until fixed or explicitly waived at H7/H9 HITL. LOW findings log as advisory and ship.
