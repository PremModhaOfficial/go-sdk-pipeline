# pydantic-settings-patterns — evolution log

- 1.0.0 (2026-05-02): initial — authored during run `nats-py-v1` intake on user instruction "construct the missing things". Python sibling of `sdk-config-struct-pattern` (Go) plus `credential-provider-pattern`. Covers `BaseSettings` with `env_prefix`, source precedence, `SecretStr` for credentials, nested config via `env_nested_delimiter="__"`, `field_validator`/`model_validator`, `.env.example` plumbing per CLAUDE.md rule 27, fail-fast validation timing, and the standard `monkeypatch.setenv` test pattern.
