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
run swift test --package-path "$repo_root/CLI" --filter SchemaFactSourceTests/capabilityNextActionURLPlaceholdersStayCanonical
smoke_port="${TRITON_IOS_RUNTIME_SMOKE_PORT:-$((28000 + (RANDOM % 1200)))}"
echo "[sim-gate] TRITON_IOS_RUNTIME_SMOKE_PORT=$smoke_port"
run env TRITON_IOS_RUNTIME_SMOKE_PORT="$smoke_port" "$repo_root/docs-linhay/scripts/verify-ios-runtime-observe-smoke.sh"

if [[ "$mode" == "full" ]]; then
  # Full gate: requires local simulator runtime context.
  run "$repo_root/docs-linhay/scripts/verify-ios-webview-harness.sh"
fi

echo "[sim-gate] ok"
