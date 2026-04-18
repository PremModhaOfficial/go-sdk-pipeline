---
name: testcontainers-dragonfly-recipe
version: 0.1.0-draft
status: candidate
priority: MUST
tags: [testing, integration, dragonfly, testcontainers]
target_consumers: [sdk-testing-lead, sdk-integration-flake-hunter]
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §11.2, §14)
---

# testcontainers-dragonfly-recipe

## When to apply
S7 integration suite; any future SDK work that targets real Dragonfly behavior (HEXPIRE wire parity, TLS, ACL, chaos).

## Recipe skeleton

```go
//go:build integration

package dragonfly_test

import (
    "context"
    "testing"
    "time"

    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"
)

const (
    dragonflyImage = "docker.dragonflydb.io/dragonflydb/dragonfly:v1.21.2" // pin
    dragonflyPort  = "6379/tcp"
)

func startDragonfly(t *testing.T, env map[string]string, mounts []testcontainers.ContainerMount) (string, func()) {
    t.Helper()
    ctx := context.Background()

    req := testcontainers.ContainerRequest{
        Image:        dragonflyImage,
        ExposedPorts: []string{dragonflyPort},
        Env:          env,
        Mounts:       mounts,
        WaitingFor: wait.ForAll(
            wait.ForListeningPort(dragonflyPort),
            wait.ForLog("Listening on port").WithStartupTimeout(30*time.Second),
        ),
    }
    c, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: req,
        Started:          true,
    })
    if err != nil { t.Fatalf("start dragonfly: %v", err) }

    host, _ := c.Host(ctx)
    port, _ := c.MappedPort(ctx, dragonflyPort)
    addr := host + ":" + port.Port()

    cleanup := func() { _ = c.Terminate(context.Background()) }
    t.Cleanup(cleanup)
    return addr, cleanup
}
```

## Required matrices (S7)

### Matrix A — TLS off / ACL off (default dev mode)
Smoke: Ping, Set+Get, HExpire real return codes, EVALSHA roundtrip.

### Matrix B — TLS enabled (server cert + CA, mTLS optional)
Mount CA+cert+key into container at `/etc/dragonfly/tls/`, pass `--tls` flags via env or command. SDK side: `WithTLS(&config.TLSConfig{Enabled: true, CAFile: ...})` + `WithTLSServerName("localhost")`.

Test: non-TLS client is rejected; TLS client succeeds.

### Matrix C — ACL enabled
`DFLY_requirepass=secret` or ACL file mount. Test: wrong password → `ErrAuth`; no creds → `ErrAuth`; correct → success.

### Matrix D — Chaos
- `c.Stop` mid-flight → in-flight command returns `ErrUnavailable`.
- `docker kill -s KILL` equivalent (via `Terminate`) — pool surfaces `ErrUnavailable` within `DialTimeout`.
- Restart + reconnect via `ConnMaxLifetime` expiry → fresh credentials read.

## Flake prevention

1. **Pin the image tag** — NEVER `latest`. Version bumps go via explicit PR with bench diff.
2. **wait.ForLog + wait.ForListeningPort** BOTH — port binding happens before RESP listener is ready on some Dragonfly versions.
3. **Unique container name or auto** — never fix names; parallel tests collide.
4. **No host networking** — always port-mapped.
5. **Reuse=false** — `testcontainers.ContainerRequest.Reuse` false for isolation (reuse introduces state leaks between runs).
6. **Docker socket check** — call `sdk-integration-flake-hunter` guard: skip tier with `t.Skip` if `/var/run/docker.sock` unreachable; never fail CI on missing Docker in dev laptop.
7. **Per-test container** for chaos tests (they mutate state); shared container OK for read-only smokes (via TestMain + package-level `os.Exit`).

## Resource discipline
- Terminate in `t.Cleanup` — not `defer` inside test function (parallel subtests lose containers otherwise).
- Soft CPU/mem limits per Docker Desktop: `HostConfigModifier` with 512 MiB is enough for smoke; bench tier needs 2 GiB.
- Per-test timeout: 60s ctx on `GenericContainer`.

## Healthcheck timing

Dragonfly (unlike Redis) binds port fast but may delay command-parsing. 500ms PING retry loop with 30s cap is the expected pattern. Document in USAGE.md "Expect first PING after container start to take up to 2s."

## CI integration

- Tag: `//go:build integration` (TPRD §11.2).
- Command: `go test -tags=integration -count=1 -timeout=120s ./core/l2cache/dragonfly/...`.
- Main CI runs with container; PR CI may use the unit-only tier (miniredis) to keep wall time low.

## Anti-patterns
- `image: latest` — silent breakage on upstream push.
- Reusing one container across all integration tests (chaos tests contaminate).
- `time.Sleep` waits instead of `wait.ForLog` — flaky on slow CI nodes.
- Terminate omitted — leaks Docker resources across runs.
- TLS cert generation inside test (use committed fixtures under `testdata/tls/`).

## References
TPRD §11.2, §9 (security), §14 (Dragonfly divergence), existing `testcontainers-setup` skill.
testcontainers-go docs; Dragonfly Docker image page.
