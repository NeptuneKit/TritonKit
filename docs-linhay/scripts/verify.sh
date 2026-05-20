#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${1:---local}"

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/verify.sh [--local|--ci-validate]

Modes:
  --local        Developer gate: Swift tests, release CLI build, CLI smoke,
                 optional Xcode simulator build, docs check, diff check.
  --ci-validate  CI gate: Swift tests, CocoaPods specs, Homebrew template,
                 version stamping scripts, release automation contract.
USAGE
}

run_step() {
  local name="$1"
  shift
  echo "==> ${name}"
  "$@"
}

ensure_cocoapods() {
  if ! command -v pod >/dev/null 2>&1; then
    sudo gem install cocoapods --no-document
  fi
}

release_cli_smoke() {
  local triton="$root/.build/release/triton"

  if [[ ! -x "$triton" ]]; then
    echo "missing release CLI: $triton" >&2
    return 1
  fi

  "$triton" version --json >/tmp/triton-verify-version.json
  "$triton" schema --command capture --json >/tmp/triton-verify-capture-schema.json
  "$triton" schema --command assert --json >/tmp/triton-verify-assert-schema.json

  if "$triton" capture --include nope --output /tmp/triton-verify-nope.tritonevidence --json >/tmp/triton-verify-capture-invalid.json; then
    echo "expected capture validation to fail" >&2
    return 1
  fi

  if ! grep -q '"validation_failed"' /tmp/triton-verify-capture-invalid.json; then
    echo "capture validation did not return validation_failed" >&2
    return 1
  fi

  if "$triton" assert text-exists Macau --within bad --json >/tmp/triton-verify-assert-invalid.json; then
    echo "expected assert validation to fail" >&2
    return 1
  fi

  if ! grep -q '"validation_failed"' /tmp/triton-verify-assert-invalid.json; then
    echo "assert validation did not return validation_failed" >&2
    return 1
  fi
}

xcode_simulator_build_if_available() {
  if [[ "${TRITON_VERIFY_XCODE:-1}" == "0" ]]; then
    echo "skip xcodebuild: TRITON_VERIFY_XCODE=0"
    return 0
  fi

  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "skip xcodebuild: xcodebuild not found"
    return 0
  fi

  if ! command -v xcrun >/dev/null 2>&1; then
    echo "skip xcodebuild: xcrun not found"
    return 0
  fi

  if ! xcrun simctl list devices available | grep -q "iPhone 17"; then
    echo "skip xcodebuild: iPhone 17 simulator not available"
    return 0
  fi

  xcodebuild build \
    -scheme TritonKit \
    -destination "platform=iOS Simulator,name=iPhone 17"
}

case "$mode" in
  --local)
    run_step "Swift tests" swift test
    run_step "Release CLI build" swift build -c release --product triton
    run_step "Release CLI smoke" release_cli_smoke
    run_step "iOS Simulator build" xcode_simulator_build_if_available
    run_step "Docs structure" "$root/docs-linhay/scripts/check-docs.sh"
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      run_step "Git diff whitespace check" git -C "$root" diff --check
    fi
    ;;
  --ci-validate)
    run_step "Swift tests" swift test
    run_step "Install CocoaPods if needed" ensure_cocoapods
    run_step "Validate TritonKitShared podspec" pod lib lint TritonKitShared.podspec --allow-warnings --skip-tests
    run_step "Validate TritonKit podspec" pod lib lint TritonKit.podspec --include-podspecs=TritonKitShared.podspec --allow-warnings --skip-tests
    run_step "Validate Homebrew formula template" "$root/docs-linhay/scripts/verify-homebrew-formula.sh"
    run_step "Validate version stamping scripts" "$root/docs-linhay/scripts/verify-version-stamping.sh"
    run_step "Validate release automation contract" "$root/docs-linhay/scripts/verify-release-automation.sh"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

echo "verification passed: ${mode}"
