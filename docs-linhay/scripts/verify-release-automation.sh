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
grep -Fq -- '--json headBranch,url' "${release_script}" || fail "release script must resolve run ids from run URLs, not numeric databaseId templates"
grep -Fq 'run_id="${run_url##*/}"' "${release_script}" || fail "release script must parse the run id from the run URL string"
if grep -Fq -- '--json databaseId,headBranch' "${release_script}"; then
  fail "release script must not render databaseId through gh templates because large ids can become scientific notation"
fi
grep -Fq 'gh-run-summary.sh --repo "${repo}" --watch "${run_id}"' "${release_script}" || fail "release script must pass the selected repo to gh-run-summary"
grep -q 'brew fetch --formula' "${release_script}" || fail "release script must verify Homebrew fetch"

if grep -q 'render-homebrew-formula.sh .*v0[.]1[.]0' "${ci_workflow}"; then
  fail "ci workflow must not hard-code v0.1.0 when validating formula rendering"
fi

grep -q 'formula_tag=' "${ci_workflow}" || fail "ci workflow must derive formula_tag dynamically"
grep -q 'tritonkit-emulator-cli-takeover' "${ci_workflow}" || fail "ci workflow must package the emulator CLI takeover skill"
grep -q 'tritonkit-skills[.]tar[.]gz' "${ci_workflow}" || fail "ci workflow must publish a combined tritonkit-skills.tar.gz"
grep -q 'sha256sum [*][.]tar[.]gz' "${ci_workflow}" || fail "ci workflow checksums should cover tar.gz release assets"
if grep -q 'ditto .*zip' "${ci_workflow}" || grep -q 'zip -qr' "${ci_workflow}"; then
  fail "ci workflow must not generate zip release assets"
fi
if grep -q 'path:.*[.]zip' "${ci_workflow}" || grep -q 'sha256sum .*[*][.]zip' "${ci_workflow}"; then
  fail "ci workflow must not upload or checksum zip release assets"
fi
if grep -q 'tar -czf .*tritonkit-dev-feedback[.]tar[.]gz' "${ci_workflow}" \
  || grep -q 'tar -czf .*tritonkit-real-project-regression[.]tar[.]gz' "${ci_workflow}" \
  || grep -q 'tar -czf .*tritonkit-emulator-cli-takeover[.]tar[.]gz' "${ci_workflow}"; then
  fail "ci workflow must not publish individual skill tarballs"
fi
grep -q 'workflow_dispatch:' "${tap_workflow}" || fail "tap workflow must support manual reruns"
grep -q 'TAP_GITHUB_TOKEN is required' "${tap_workflow}" || fail "tap workflow must fail clearly when the secret is missing"

echo "release automation verification passed"
