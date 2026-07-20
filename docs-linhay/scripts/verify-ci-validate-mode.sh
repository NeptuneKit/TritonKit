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
  TritonKit.skills/tritonkit-dev-feedback/SKILL.md \
  .agents/skills/tritonkit-ops-governance/SKILL.md

expect_mode swift Sources/TritonKitCLI/TritonKitCLI.swift
expect_mode swift Tests/TritonKitSharedTests/TKCLITransportModelsTests.swift
expect_mode swift Package.swift
expect_mode swift CLI/Package.swift
expect_mode swift CLI/Package.resolved README.md
expect_mode swift Package.resolved README.md
expect_mode swift Sources/TritonKitCLI/TritonKitCLI.swift .github/workflows/ci.yml

expect_mode contracts .github/workflows/ci.yml
expect_mode contracts docs-linhay/scripts/ci-validate-mode.sh
expect_mode contracts docs-linhay/scripts/verify-release-automation.sh README.md
expect_mode contracts docs-linhay/scripts/package-public-skills.py
expect_mode contracts docs-linhay/scripts/public-skill-command-schema.json
expect_mode contracts docs-linhay/scripts/verify-public-skill-commands.py
expect_mode contracts docs-linhay/scripts/install-public-skills.sh
expect_mode contracts docs-linhay/scripts/verify-skill-package.sh

tag_mode="$(
  GITHUB_REF_TYPE=tag GITHUB_REF=refs/tags/v9.8.7 GITHUB_EVENT_NAME=push "${classifier}"
)"
if [[ "${tag_mode}" != "contracts" ]]; then
  echo "expected contracts, got ${tag_mode} for release tag validation" >&2
  exit 1
fi

expect_mode podkit Sources/TritonKit/TritonKit.swift
expect_mode podkit TritonKit.podspec
expect_mode podkit Sources/TritonKit/TritonKit.swift Sources/TritonKitCLI/TritonKitCLI.swift

expect_mode podkit Sources/TritonKitShared/TKCLITransportModels.swift
expect_mode full docs-linhay/scripts/verify.sh
expect_mode full fixtures/harmony-collector-smoke/oh-package.json5

echo "ci validate mode verification passed"
