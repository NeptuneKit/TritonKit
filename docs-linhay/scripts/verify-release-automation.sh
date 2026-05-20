#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
release_script="${root}/docs-linhay/scripts/release.sh"
ci_workflow="${root}/.github/workflows/ci.yml"
tap_workflow="${root}/.github/workflows/update-homebrew-tap.yml"

fail() {
  echo "release automation verification failed: $*" >&2
  exit 1
}

test -x "${release_script}" || fail "missing executable docs-linhay/scripts/release.sh"

grep -q 'TAP_GITHUB_TOKEN' "${release_script}" || fail "release script must check TAP_GITHUB_TOKEN"
grep -q 'NeptuneKit/homebrew-tap' "${release_script}" || fail "release script must check the default tap repo"
grep -q 'git tag -a' "${release_script}" || fail "release script must create annotated version tags"
grep -q 'gh run' "${release_script}" || fail "release script must observe GitHub Actions runs"
grep -q 'brew fetch --formula' "${release_script}" || fail "release script must verify Homebrew fetch"

if grep -q 'render-homebrew-formula.sh .*v0[.]1[.]0' "${ci_workflow}"; then
  fail "ci workflow must not hard-code v0.1.0 when validating formula rendering"
fi

grep -q 'formula_tag=' "${ci_workflow}" || fail "ci workflow must derive formula_tag dynamically"
grep -q 'workflow_dispatch:' "${tap_workflow}" || fail "tap workflow must support manual reruns"
grep -q 'TAP_GITHUB_TOKEN is required' "${tap_workflow}" || fail "tap workflow must fail clearly when the secret is missing"

echo "release automation verification passed"
