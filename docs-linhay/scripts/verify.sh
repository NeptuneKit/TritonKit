#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${1:---local}"

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/verify.sh [--local|--ci-validate|--ci-docs]

Modes:
  --local        Developer gate: Swift tests, release CLI build, CLI smoke,
                 optional Xcode simulator build, docs check, diff check.
  --ci-validate  CI gate: Swift tests, CocoaPods specs, Homebrew template,
                 version stamping scripts, release automation contract.
  --ci-docs      Fast CI gate for docs/skill-only changes: docs structure,
                 diff check, skill/release contract, and CI scope classifier.
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
  local triton="$root/.build/cli/release/triton"

  if [[ ! -x "$triton" ]]; then
    echo "missing release CLI: $triton" >&2
    return 1
  fi

  "$triton" version --json >/tmp/triton-verify-version.json
  "$triton" schema --command capture --json >/tmp/triton-verify-capture-schema.json
  "$triton" schema --command assert --json >/tmp/triton-verify-assert-schema.json
  "$triton" schema --command app --json >/tmp/triton-verify-app-schema.json
  "$triton" schema --command ax --json >/tmp/triton-verify-ax-schema.json
  "$triton" schema --command wait --json >/tmp/triton-verify-wait-schema.json
  "$triton" schema --command tap --json >/tmp/triton-verify-tap-schema.json
  "$triton" schema --command screenshot --json >/tmp/triton-verify-screenshot-schema.json
  "$triton" schema --command observe --json >/tmp/triton-verify-observe-schema.json
  "$triton" schema --command node --json >/tmp/triton-verify-node-schema.json

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

  local fake_bin fake_calls
  fake_bin="$(mktemp -d)"
  fake_calls="$fake_bin/xcodebuild-calls.log"
  cat >"$fake_bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${TRITON_FAKE_XCODEBUILD_CALLS:?}"
echo "** BUILD SUCCEEDED **"
EOF
  chmod +x "$fake_bin/xcodebuild"

  TRITON_FAKE_XCODEBUILD_CALLS="$fake_calls" \
    PATH="$fake_bin:$PATH" \
    "$triton" xcode build \
      --workspace App.xcworkspace \
      --scheme App \
      --configuration Debug \
      --sdk iphonesimulator \
      --destination "platform=iOS Simulator,id=SIM-1" \
      --derived-data-path .triton/DerivedData \
      --jsonl \
      --timeout 1 \
      >/tmp/triton-verify-xcode-build-jsonl.log

  if ! grep -q '"event":"xcode.build.summary"' /tmp/triton-verify-xcode-build-jsonl.log; then
    echo "xcode build smoke did not emit build summary" >&2
    return 1
  fi

  if grep -q -- "-showBuildSettings" "$fake_calls"; then
    echo "xcode build smoke unexpectedly invoked -showBuildSettings after build" >&2
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
    run_step "SwiftPM dependency boundary" "$root/docs-linhay/scripts/verify-spm-dependency-boundary.sh"
    run_step "iOS DEBUG isolation" "$root/docs-linhay/scripts/verify-ios-debug-isolation.sh"
    run_step "Swift tests" swift test
    run_step "Release CLI build" swift build --package-path "$root/CLI" --scratch-path "$root/.build/cli" -c release --product triton
    run_step "Release CLI smoke" release_cli_smoke
    run_step "Harmony host smoke" env TRITON_BIN="$root/.build/cli/release/triton" "$root/docs-linhay/scripts/verify-harmony-host-smoke.sh"
    run_step "iOS runtime observe smoke" env TRITON_BIN="$root/.build/cli/release/triton" "$root/docs-linhay/scripts/verify-ios-runtime-observe-smoke.sh"
    run_step "iOS Simulator build" xcode_simulator_build_if_available
    run_step "Docs structure" "$root/docs-linhay/scripts/check-docs.sh"
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      run_step "Git diff whitespace check" git -C "$root" diff --check
    fi
    ;;
  --ci-validate)
    run_step "Validate CI scope classifier" "$root/docs-linhay/scripts/verify-ci-validate-mode.sh"
    run_step "SwiftPM dependency boundary" "$root/docs-linhay/scripts/verify-spm-dependency-boundary.sh"
    run_step "iOS DEBUG isolation" "$root/docs-linhay/scripts/verify-ios-debug-isolation.sh"
    run_step "Swift tests" swift test
    run_step "Release CLI build" swift build --package-path "$root/CLI" --scratch-path "$root/.build/cli" -c release --product triton
    run_step "Install CocoaPods if needed" ensure_cocoapods
    run_step "Validate TritonKitShared podspec" pod lib lint TritonKitShared.podspec --allow-warnings --skip-tests
    run_step "Validate TritonKit podspec" pod lib lint TritonKit.podspec --include-podspecs=TritonKitShared.podspec --allow-warnings --skip-tests
    run_step "Validate Homebrew formula template" "$root/docs-linhay/scripts/verify-homebrew-formula.sh"
    run_step "Validate version stamping scripts" "$root/docs-linhay/scripts/verify-version-stamping.sh"
    run_step "Validate release automation contract" "$root/docs-linhay/scripts/verify-release-automation.sh"
    ;;
  --ci-docs)
    run_step "Validate CI scope classifier" "$root/docs-linhay/scripts/verify-ci-validate-mode.sh"
    run_step "Docs structure" "$root/docs-linhay/scripts/check-docs.sh"
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      run_step "Git diff whitespace check" git -C "$root" diff --check
    fi
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
