#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
classifier="${root}/docs-linhay/scripts/ci-validate-mode.sh"

expect_mode() {
  local expected="$1"
  shift

  local actual
  actual="$("${classifier}" "$@")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "expected ${expected}, got ${actual} for paths: $*" >&2
    exit 1
  fi
}

expect_mode docs \
  README.md \
  AGENTS.md \
  docs-linhay/memory/2026-05-21.md \
  docs-linhay/dev/ai-cli-readable-control.md \
  .agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md \
  .agents/skills/tritonkit-dev-feedback

expect_mode full Sources/TritonKit/TritonKit.swift
expect_mode full Tests/TritonKitTests/TKPlatformFallbackTests.swift
expect_mode full Package.swift
expect_mode full TritonKit.podspec
expect_mode full .github/workflows/ci.yml
expect_mode full docs-linhay/scripts/verify.sh
expect_mode full fixtures/harmony-collector-smoke/oh-package.json5

echo "ci validate mode verification passed"
