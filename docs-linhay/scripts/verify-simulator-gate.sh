#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
mode="${1:-quick}"

echo "[sim-gate] mode=$mode"

run() {
  echo "[sim-gate] $*"
  "$@"
}

# Quick gate: deterministic and CI-friendly checks that do not require a booted simulator.
run swift test --package-path "$repo_root/CLI" --filter SimulatorAdvancedControlsTests
run swift test --package-path "$repo_root/CLI" --filter DeviceCrossPlatformTests
run swift test --package-path "$repo_root/CLI" --filter SchemaFactSourceTests/capabilityNextActionTargetSelectorPlaceholdersStayCanonical
run swift test --package-path "$repo_root/CLI" --filter SchemaFactSourceTests/capabilityNextActionPlatformFlagsStayCanonicalAndFamilyAligned
run swift test --package-path "$repo_root/CLI" --filter SchemaFactSourceTests/capabilityNextActionTextPlaceholdersStayCanonical
run "$repo_root/docs-linhay/scripts/verify-ios-runtime-observe-smoke.sh"

if [[ "$mode" == "full" ]]; then
  # Full gate: requires local simulator runtime context.
  run "$repo_root/docs-linhay/scripts/verify-ios-webview-harness.sh"
fi

echo "[sim-gate] ok"
