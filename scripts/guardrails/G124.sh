#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Python credential-scan — Python sibling of G69; scans *.py + .env.example for leaked secrets
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
# Patterns: AWS access keys, GitHub PATs, PEM private keys, password=/api_key= literals.
# Scope: src/ tests/ and any .env.example (but NOT .env which is .gitignored anyway).
PATS='(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(password|api_key|secret|token|passwd)\s*=\s*["'"'"'][^"'"'"']{4,}["'"'"'])'
BAD=$(grep -rniE "$PATS" "$TARGET" \
        --include="*.py" --include=".env.example" --include="*.toml" --include="*.yaml" --include="*.yml" \
        --exclude-dir=__pycache__ --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.tox \
        --exclude-dir=.mypy_cache --exclude-dir=.ruff_cache --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
        2>/dev/null || true)
# Allow SecretStr placeholders + obvious test sentinels
BAD=$(echo "$BAD" | grep -viE 'SecretStr|<masked>|<redacted>|REPLACE_ME|example\.com|localhost|test_password|hunter2|dummy|fake|<your-' || true)
[ -z "$BAD" ] || { echo "G124 FAIL: hardcoded credentials detected"; echo "$BAD"; exit 1; }
