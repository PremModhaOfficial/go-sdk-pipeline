---
name: pydantic-settings-patterns
description: >
  Use this when designing the Config layer of a Python SDK or service —
  `pydantic-settings` v2 `BaseSettings`, env-var loading with `env_prefix`, layered
  precedence (CLI > env > .env > defaults), validators (`field_validator`,
  `model_validator`), `SecretStr` for credentials, frozen models, nested config
  composition, and `.env` / `.env.example` plumbing per CLAUDE.md rule 27.
  Triggers: BaseSettings, SettingsConfigDict, env_prefix, env_file, model_config, field_validator, model_validator, SecretStr, frozen, ValidationError, .env, MOTADATA_, pydantic-settings.
---

# pydantic-settings-patterns (v1.0.0)

## Rationale

`pydantic-settings` v2 separates config schema (the `BaseSettings` subclass) from config sources (env vars, `.env` file, CLI, secrets dir). It gives you (a) free env-var → field mapping with type coercion, (b) source precedence as a deterministic list (no surprise overrides), (c) `ValidationError` at construction time with the exact field-and-value that failed, (d) `SecretStr` that won't accidentally render in logs / repr. Skip it and you reinvent: per-field `os.getenv` boilerplate, hand-rolled type coercion, scattered `default_value` constants, secrets that leak via `print(cfg)`. This skill is the Python sibling of Go's `sdk-config-struct-pattern` plus `credential-provider-pattern`.

## Activation signals

- Standing up the `Config` layer for a new client per TPRD §11
- Adding a new env-var-driven knob to existing config
- Reviewer cites "secret leaked in repr", "missing validator", "unclear precedence", "default scattered"
- Test setup uses `monkeypatch.setenv(...)` against a `BaseSettings` class
- Designing nested config (e.g. `EventsConfig` containing `NatsConfig` + `JetStreamConfig` + `OTelConfig`)

## Canonical pattern — flat config with prefix + .env

```python
# motadata_py_sdk/events/config.py
from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class NatsConfig(BaseSettings):
    """NATS-connection config. Env vars: MOTADATA_NATS_*."""

    model_config = SettingsConfigDict(
        env_prefix="MOTADATA_NATS_",
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="forbid",                # any unknown env var = ValidationError
        frozen=True,                   # config is immutable post-construction
    )

    servers: tuple[str, ...] = Field(
        default=("nats://localhost:4222",),
        description="NATS server URLs",
    )
    client_name: str = Field(default="motadata-py-sdk", min_length=1, max_length=64)
    creds_path: str | None = Field(default=None, description="Path to .creds file (NKey/JWT)")
    password: SecretStr | None = Field(default=None, description="Plain password (test only)")

    request_timeout_s: float = Field(default=2.0, gt=0, le=60.0)
    max_reconnect_attempts: int = Field(default=60, ge=0, le=10_000)
    reconnect_time_wait_s: float = Field(default=2.0, ge=0, le=300)

    @field_validator("servers")
    @classmethod
    def _servers_not_empty(cls, v: tuple[str, ...]) -> tuple[str, ...]:
        if not v:
            raise ValueError("servers must contain at least one URL")
        for url in v:
            if not (url.startswith("nats://") or url.startswith("tls://")):
                raise ValueError(f"server URL must start with nats:// or tls://: {url}")
        return v
```

Construction:

```python
cfg = NatsConfig()                              # reads env + .env
cfg = NatsConfig(servers=("nats://prod:4222",)) # explicit override wins over env
```

`extra="forbid"` is critical — without it, a typo like `MOTADATA_NATS_TIMOUT_S=5` is silently dropped and the default applies. With `forbid`, the typo raises `ValidationError` at startup.

## Precedence — explicit ordering

Pydantic-settings sources are tried in order; first hit wins. The default order is:

1. Constructor kwargs (test overrides)
2. Env vars
3. Init `.env` file (path from `env_file`)
4. File secrets (path from `secrets_dir`)
5. Field defaults

To customize (e.g. CLI args first, AWS Secrets Manager last):

```python
from pydantic_settings import (
    BaseSettings, SettingsConfigDict, PydanticBaseSettingsSource,
    EnvSettingsSource, DotEnvSettingsSource,
)

class Config(BaseSettings):
    @classmethod
    def settings_customise_sources(
        cls, settings_cls, init_settings, env_settings, dotenv_settings, file_secret_settings,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        return (init_settings, env_settings, dotenv_settings, AwsSecretsManagerSource(settings_cls))
```

Document the order in a docstring — every reader of the Config class needs to know "where does this value come from".

## Secrets — `SecretStr`, never `str`

```python
from pydantic import SecretStr

class TLSConfig(BaseSettings):
    password: SecretStr | None = None

cfg = TLSConfig(password="hunter2")
print(cfg)                           # password=SecretStr('**********')   ← masked
str(cfg.password)                    # 'SecretStr(\'**********\')'       ← masked
cfg.password.get_secret_value()      # 'hunter2'                         ← explicit unmask
```

`SecretStr` masks in `__repr__`, `__str__`, and JSON serialization. Pass it to wire calls via `.get_secret_value()` ONLY at the call site, never store the unwrapped value as a field. `SecretBytes` is the sibling for binary secrets (TLS keys).

## Nested config — composition

```python
class JetStreamConfig(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="MOTADATA_JETSTREAM_", env_nested_delimiter="__")
    stream_name: str = "EVENTS"
    max_age_s: int = 86_400

class TLSConfig(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="MOTADATA_NATS_TLS_")
    enabled: bool = False
    ca_path: str | None = None
    cert_path: str | None = None
    key_path: str | None = None
    server_name: str | None = None

class NatsConfig(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="MOTADATA_NATS_", env_nested_delimiter="__")
    servers: tuple[str, ...] = ("nats://localhost:4222",)
    tls: TLSConfig = Field(default_factory=TLSConfig)
    jetstream: JetStreamConfig = Field(default_factory=JetStreamConfig)

# Env: MOTADATA_NATS_SERVERS='["nats://prod:4222"]'
#      MOTADATA_NATS_TLS__ENABLED=true
#      MOTADATA_NATS_TLS__CA_PATH=/etc/ca.pem
```

`env_nested_delimiter="__"` lets nested fields take their own envs without prefix collision.

## Cross-field validation — `model_validator`

```python
from pydantic import model_validator

class TLSConfig(BaseSettings):
    enabled: bool = False
    cert_path: str | None = None
    key_path: str | None = None

    @model_validator(mode="after")
    def _mtls_paths_paired(self) -> "TLSConfig":
        if self.enabled and bool(self.cert_path) ^ bool(self.key_path):
            raise ValueError("when TLS is enabled, cert_path and key_path must be set together")
        return self
```

Run cross-field rules in `model_validator(mode="after")` so each field has already passed its own `field_validator`.

## `.env.example` — committed template per CLAUDE.md rule 27

Always commit a `.env.example` with EVERY supported env var, sample value, and one-line comment:

```dotenv
# motadata-py-sdk/.env.example
# Real values go in .env (gitignored). Do not commit secrets here.

# NATS connection
MOTADATA_NATS_SERVERS=["nats://localhost:4222"]
MOTADATA_NATS_CLIENT_NAME=motadata-py-sdk
MOTADATA_NATS_CREDS_PATH=                           # NKey/JWT .creds path
MOTADATA_NATS_REQUEST_TIMEOUT_S=2.0

# TLS (mutually-exclusive with PASSWORD)
MOTADATA_NATS_TLS__ENABLED=false
MOTADATA_NATS_TLS__CA_PATH=
MOTADATA_NATS_TLS__CERT_PATH=
MOTADATA_NATS_TLS__KEY_PATH=
MOTADATA_NATS_TLS__SERVER_NAME=

# OTel
MOTADATA_OTEL_SERVICE_NAME=motadata-py-sdk
MOTADATA_OTEL_OTLP_ENDPOINT=http://localhost:4317
MOTADATA_OTEL_OTLP_INSECURE=true
MOTADATA_OTEL_SAMPLE_RATIO=0.1
```

Add `.env` to `.gitignore`. Guardrail G124 (Python credential scan) catches secrets accidentally committed to `.env.example`.

## Validation timing — fail fast at startup

Construct `Config` AT THE TOP OF `main()`, never lazily inside the request path. `ValidationError` should crash the process before it accepts the first request.

```python
from pydantic import ValidationError

def main() -> None:
    try:
        cfg = NatsConfig()
    except ValidationError as e:
        log.critical("config invalid; refusing to start", extra={"errors": e.errors()})
        sys.exit(1)
    asyncio.run(run(cfg))
```

`e.errors()` returns a list of `{loc, msg, type, input}` dicts — log them as structured fields.

## Test plumbing — `monkeypatch.setenv` + clean BaseSettings instance

```python
def test_config_loads_from_env(monkeypatch):
    monkeypatch.setenv("MOTADATA_NATS_REQUEST_TIMEOUT_S", "5.0")
    monkeypatch.setenv("MOTADATA_NATS_SERVERS", '["nats://test:4222"]')
    cfg = NatsConfig()
    assert cfg.request_timeout_s == 5.0
    assert cfg.servers == ("nats://test:4222",)
```

For test isolation, instantiate `Config()` per test (don't share); pydantic-settings re-reads sources on each construction.

## Pitfalls

1. **`extra="ignore"` (default in v1) on a public-API Config class** — typoed env vars silently drop to defaults. Always set `extra="forbid"` on the top-level Config; allow `extra="allow"` only for internal extension points.
2. **Storing unwrapped secrets as `str` fields** — `Config(password="hunter2")` then `print(cfg)` leaks via `__repr__`. Use `SecretStr` and unwrap only at the call site.
3. **`Field(default=[])` on `list[str]`** — Pydantic v2 rejects mutable defaults; use `Field(default_factory=list)` or `default=()` (tuple).
4. **`env_file=".env"` in production code** — production should rely on env vars, not a file in the cwd. Only enable `.env` loading in dev / test contexts.
5. **`field_validator` without `@classmethod`** — Pydantic v2 requires the decorator-then-classmethod ordering; missing it raises a confusing TypeError at class-definition time.
6. **Nested config without `env_nested_delimiter`** — child env vars collide with parent prefix. Always set `env_nested_delimiter="__"`.
7. **Lazy config construction inside request handlers** — first invalid env var crashes a request, not the process. Construct in `main()`.
8. **Mixing `pydantic` and `pydantic-settings` v1 imports** — v1 used `BaseSettings` from `pydantic`; v2 moved it to `pydantic_settings`. Pin `pydantic-settings>=2.0` in `pyproject.toml` and import from there.

## References

- pydantic-settings v2: <https://docs.pydantic.dev/latest/concepts/pydantic_settings/>
- Pydantic v2 validators: <https://docs.pydantic.dev/latest/concepts/validators/>
- Cross-skill: `python-class-design` (frozen+slots dataclass alternative for non-env-driven config), `credential-provider-pattern` (for rotating creds where Config is read once at startup), `sdk-config-struct-pattern` (Go sibling — same intent, different mechanism), CLAUDE.md rule 27 (`.env.example` plumbing).
