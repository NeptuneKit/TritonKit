#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
release_script="${root}/docs-linhay/scripts/release.sh"
ci_workflow="${root}/.github/workflows/ci.yml"
release_workflow="${root}/.github/workflows/release.yml"
tap_workflow="${root}/.github/workflows/update-homebrew-tap.yml"
package_skill_script="${root}/docs-linhay/scripts/package-public-skills.py"
verify_skill_package_script="${root}/docs-linhay/scripts/verify-skill-package.sh"
verify_public_skill_commands_script="${root}/docs-linhay/scripts/verify-public-skill-commands.py"
public_skill_command_schema="${root}/docs-linhay/scripts/public-skill-command-schema.json"
install_skill_script="${root}/docs-linhay/scripts/install-public-skills.sh"
verify_release_package_versions_script="${root}/docs-linhay/scripts/verify-release-package-versions.sh"
public_skill_root="${root}/TritonKit.skills"
internal_skill_root="${root}/.agents/skills"

fail() {
  echo "release automation verification failed: $*" >&2
  exit 1
}

test -x "${release_script}" || fail "missing executable docs-linhay/scripts/release.sh"
test -x "${package_skill_script}" || fail "missing executable docs-linhay/scripts/package-public-skills.py"
test -x "${verify_skill_package_script}" || fail "missing executable docs-linhay/scripts/verify-skill-package.sh"
test -x "${verify_public_skill_commands_script}" || fail "missing executable docs-linhay/scripts/verify-public-skill-commands.py"
test -f "${public_skill_command_schema}" || fail "missing public skill command schema snapshot"
test -x "${install_skill_script}" || fail "missing executable docs-linhay/scripts/install-public-skills.sh"
test -x "${verify_release_package_versions_script}" || fail "missing executable docs-linhay/scripts/verify-release-package-versions.sh"

grep -q 'TAP_GITHUB_TOKEN' "${release_script}" || fail "release script must check TAP_GITHUB_TOKEN"
grep -q 'NeptuneKit/homebrew-tap' "${release_script}" || fail "release script must check the default tap repo"
grep -q 'git tag -a' "${release_script}" || fail "release script must create annotated version tags"
grep -q 'verify-release-package-versions[.]sh' "${release_script}" || fail "release script must verify all public package versions before tagging"
grep -q 'gh run' "${release_script}" || fail "release script must observe GitHub Actions runs"
grep -q 'TRITON_RELEASE_WORKFLOW:-Release' "${release_script}" || fail "release script must observe the Release workflow by default"
grep -Fq -- '--json headBranch,url' "${release_script}" || fail "release script must resolve run ids from run URLs, not numeric databaseId templates"
grep -Fq 'run_id="${run_url##*/}"' "${release_script}" || fail "release script must parse the run id from the run URL string"
if grep -Fq -- '--json databaseId,headBranch' "${release_script}"; then
  fail "release script must not render databaseId through gh templates because large ids can become scientific notation"
fi
grep -Fq 'Waiting for arm64 release assets and Homebrew tap' "${release_script}" \
  || fail "release script must return after arm64 release assets and Homebrew tap are ready"
grep -q 'brew fetch --formula' "${release_script}" || fail "release script must verify Homebrew fetch"

if grep -q 'render-homebrew-formula.sh .*v0[.]1[.]0' "${ci_workflow}"; then
  fail "ci workflow must not hard-code v0.1.0 when validating formula rendering"
fi

grep -q 'formula_tag=' "${ci_workflow}" || fail "ci workflow must derive formula_tag dynamically"
if grep -Fq 'formula_tag="v${{ steps.version.outputs.version }}"' "${ci_workflow}"; then
  fail "ci workflow must not render Homebrew formula from non-tag dev versions"
fi
grep -q 'classify-validate:' "${ci_workflow}" || fail "ci workflow must classify validate scope before running gates"
grep -q 'Validate docs and skills' "${ci_workflow}" || fail "ci workflow must keep an in-classifier docs/skill-only validate path"
grep -q 'Validate short-path contracts' "${ci_workflow}" || fail "ci workflow must keep an in-classifier contract-only validate path"
grep -q 'validate-swift:' "${ci_workflow}" || fail "ci workflow must split Swift tests into an independent validate job"
grep -q 'validate-podspec-kit:' "${ci_workflow}" || fail "ci workflow must split TritonKit podspec lint into an independent validate job"
grep -q 'validate-contracts:' "${ci_workflow}" || fail "ci workflow must split release/homebrew contract checks into an independent validate job"
grep -q 'name: Validate' "${ci_workflow}" || fail "ci workflow must keep a stable Validate aggregator job"
grep -q "mode == 'swift'" "${ci_workflow}" || fail "ci workflow must support a swift-only validate mode"
grep -q "mode == 'contracts'" "${ci_workflow}" || fail "ci workflow must support a contract-only validate mode"
grep -q "mode == 'podkit'" "${ci_workflow}" || fail "ci workflow must support a TritonKit-only podspec validate mode"
if grep -q 'TritonKitShared[.]podspec' "${ci_workflow}"; then
  fail "ci workflow must not validate or require a public TritonKitShared podspec"
fi
grep -q 'actions/cache@v5' "${ci_workflow}" || fail "ci workflow must cache SwiftPM dependencies/build products with the Node 24 cache action"
if grep -Eq 'actions/(cache|upload-artifact|download-artifact)@v4' "${ci_workflow}" "${release_workflow}"; then
  fail "release workflows must not use Node 20 cache/artifact actions"
fi
grep -q 'verify-spm-dependency-boundary[.]sh' "${ci_workflow}" || fail "ci workflow must validate the SwiftPM iOS/CLI dependency boundary"
grep -q 'swift build --package-path CLI --scratch-path [.]build/cli -c release --product triton' "${ci_workflow}" \
  || fail "ci workflow must build the CLI from CLI/Package.swift"
web_build_count="$(grep -Fc 'npm --prefix Web run build' "${ci_workflow}" || true)"
if (( web_build_count < 2 )); then
  fail "ci workflow must build Web/dist before both arm64 and x86_64 CLI artifacts"
fi
node_setup_count="$(grep -Fc 'actions/setup-node@v6' "${ci_workflow}" || true)"
if (( node_setup_count < 2 )); then
  fail "ci workflow must pin Node before building bundled Web assets on both CLI release jobs"
fi
grep -Fq 'cache-dependency-path: Web/package-lock.json' "${ci_workflow}" \
  || fail "ci workflow must cache npm dependencies using Web/package-lock.json"
web_copy_count="$(grep -Fc 'cp -R "Web/dist/." "${package_dir}/web/"' "${ci_workflow}" || true)"
if (( web_copy_count < 2 )); then
  fail "ci workflow must copy Web/dist into both CLI artifact web directories"
fi
grep -Fq 'triton web starts the bundled Web Device Hub from ./web.' "${ci_workflow}" \
  || fail "CLI package README must explain bundled Web startup through triton web"
if grep -Fq "| grep -Fq 'triton web starts the bundled Web Device Hub from ./web.'" "${ci_workflow}"; then
  fail "release README validation must not pipe tar output into grep -q because grep can close the pipe before tar finishes"
fi
if grep -Eq 'tar -tf .*\| grep -E?q' "${ci_workflow}"; then
  fail "release tar content validation must write tar -tf output to a file before grep under pipefail"
fi
grep -Fq 'triton-macos-arm64/web/index[.]html' "${ci_workflow}" \
  || fail "ci workflow must validate the arm64 CLI tarball contains bundled Web assets"
grep -Fq 'triton-macos-x86_64/web/index[.]html' "${ci_workflow}" \
  || fail "ci workflow must validate the x86_64 CLI tarball contains bundled Web assets"
grep -Fq 'pkgshare.install web_dir => "web"' "${root}/.github/homebrew/triton.rb.template" \
  || fail "Homebrew formula must install bundled Web assets into pkgshare/web"
grep -Fq 'triton web --print-command --json' "${root}/.github/homebrew/triton.rb.template" \
  || fail "Homebrew formula test must verify triton web resolves packaged mode"
grep -Fq 'assert_equal "packaged", web_plan["mode"]' "${root}/.github/homebrew/triton.rb.template" \
  || fail "Homebrew formula test must assert packaged triton web mode"
grep -q 'skip Homebrew formula rendering for non-tag release asset validation' "${ci_workflow}" \
  || fail "ci workflow must skip Homebrew formula rendering for non-tag release asset validation"
if grep -q '| rg '\''\^  version: '\''' "${ci_workflow}"; then
  fail "ci workflow must not require rg when validating skill versions in release jobs"
fi
grep -q 'tritonkit-emulator-cli-takeover' "${ci_workflow}" || fail "ci workflow must package the emulator CLI takeover skill"
grep -q 'tritonkit-update' "${ci_workflow}" || fail "ci workflow must validate the public update skill in release assets"
grep -q 'tritonkit-update' "${package_skill_script}" || fail "package script must package the public update skill"
grep -q 'verify-public-skill-commands[.]py' "${package_skill_script}" || fail "package script must validate public skill commands"
grep -q 'public-skill-command-schema[.]json' "${package_skill_script}" || fail "package script must use the CLI command schema snapshot"
grep -q 'unknown Triton command root' "${verify_skill_package_script}" || fail "skill package verification must cover retired command roots"
grep -q 'package-public-skills[.]py' "${ci_workflow}" || fail "ci workflow must package skills through package-public-skills.py"
grep -q 'TritonKit[.]skills/BUILD_INFO[.]json' "${ci_workflow}" || fail "ci workflow must validate packaged skill bundle BUILD_INFO.json"
grep -q 'TritonKit[.]skills' "${package_skill_script}" || fail "package script must package public skills from TritonKit.skills"
if grep -q '[.]agents/skills/[$][{]skill_name[}]' "${ci_workflow}" \
  || grep -q '[.]agents/tritonkit-skills' "${ci_workflow}"; then
  fail "ci workflow must not package release skills from internal skills or retired roots"
fi
for public_skill in tritonkit-dev-feedback tritonkit-emulator-cli-takeover tritonkit-real-project-regression tritonkit-update; do
  test -f "${public_skill_root}/${public_skill}/SKILL.md" || fail "missing public skill source: ${public_skill}"
  test ! -e "${root}/.agents/skills/${public_skill}" || fail "public skill must not live in .agents/skills: ${public_skill}"
done
for internal_skill in tritonkit-autonomous-cruise tritonkit-host-simulator-takeover tritonkit-ops-governance tritonkit-subagent-supervision tritonkit-xcode-workflow-takeover; do
  test -f "${internal_skill_root}/${internal_skill}/SKILL.md" || fail "missing internal skill source: ${internal_skill}"
  test -d "${root}/.agents/skills/${internal_skill}" || fail "internal skill must live in .agents/skills: ${internal_skill}"
  test ! -L "${root}/.agents/skills/${internal_skill}" || fail "internal skill must not be a symlink: ${internal_skill}"
  if grep -q "${internal_skill}" "${ci_workflow}"; then
    fail "ci workflow must not package internal skill: ${internal_skill}"
  fi
done
grep -q 'tritonkit-skills[.]tar[.]gz' "${ci_workflow}" || fail "ci workflow must publish a combined tritonkit-skills.tar.gz"
grep -q 'TritonKit[.]skills/[$][{]skill_name[}]/SKILL[.]md' "${ci_workflow}" || fail "ci workflow must validate skills under the TritonKit.skills bundle directory"
grep -q 'build-cli-arm64:' "${ci_workflow}" || fail "ci workflow must build arm64 CLI as an independent release gate"
grep -q 'needs: build-cli-arm64' "${ci_workflow}" || fail "release asset packaging must depend on arm64 only"
grep -q 'publish-x86-release-asset:' "${ci_workflow}" || fail "ci workflow must backfill the x86_64 release asset"
grep -q 'Update Homebrew tap [(]x86_64 backfill[)]' "${ci_workflow}" || fail "ci workflow must update the tap again after x86_64 backfill"
grep -q 'sha256sum [*][.]tar[.]gz' "${ci_workflow}" || fail "ci workflow checksums should cover tar.gz release assets"
if grep -q 'ditto .*zip' "${ci_workflow}" || grep -q 'zip -qr' "${ci_workflow}"; then
  fail "ci workflow must not generate zip release assets"
fi
if grep -q 'path:.*[.]zip' "${ci_workflow}" || grep -q 'sha256sum .*[*][.]zip' "${ci_workflow}"; then
  fail "ci workflow must not upload or checksum zip release assets"
fi
if grep -q 'tar -czf .*tritonkit-dev-feedback[.]tar[.]gz' "${ci_workflow}" \
  || grep -q 'tar -czf .*tritonkit-real-project-regression[.]tar[.]gz' "${ci_workflow}" \
  || grep -q 'tar -czf .*tritonkit-emulator-cli-takeover[.]tar[.]gz' "${ci_workflow}" \
  || grep -q 'tar -czf .*tritonkit-update[.]tar[.]gz' "${ci_workflow}"; then
  fail "ci workflow must not publish individual skill tarballs"
fi
grep -q 'workflow_dispatch:' "${tap_workflow}" || fail "tap workflow must support manual reruns"
grep -q 'TAP_GITHUB_TOKEN is required' "${tap_workflow}" || fail "tap workflow must fail clearly when the secret is missing"
grep -q '^name: Release$' "${release_workflow}" || fail "release workflow must exist"
grep -q 'tags:' "${release_workflow}" || fail "release workflow must run on version tags"
grep -q 'Build CLI [(]arm64[)]' "${release_workflow}" || fail "release workflow must build arm64 CLI"
grep -q 'Build CLI [(]x86_64[)]' "${release_workflow}" || fail "release workflow must build x86_64 CLI"
if grep -q 'macos-15-intel' "${release_workflow}"; then
  fail "release workflow must not wait for the slow Intel runner; cross-compile x86_64 on the arm64 runner"
fi
grep -Fq -- '--triple x86_64-apple-macosx14.0' "${release_workflow}" \
  || fail "release workflow must cross-compile x86_64 through SwiftPM --triple"
grep -Fq 'actions/cache@v5' "${release_workflow}" \
  || fail "release workflow must cache SwiftPM dependencies and build outputs with the Node 24 cache action"
grep -Fq 'release-cli-arm64' "${release_workflow}" \
  || fail "release workflow must keep a dedicated arm64 CLI cache key"
grep -Fq 'release-cli-x86_64' "${release_workflow}" \
  || fail "release workflow must keep a dedicated x86_64 CLI cache key"
grep -Fq '.build/cli-x86/x86_64-apple-macosx/release/triton' "${release_workflow}" \
  || fail "release workflow must package the x86_64 cross-compiled binary"
grep -Fq 'Mach-O 64-bit executable x86_64' "${release_workflow}" \
  || fail "release workflow must verify the x86_64 binary architecture before upload"
grep -A12 'publish-x86-release-asset:' "${release_workflow}" | grep -Fq 'actions/checkout@v5' \
  || fail "release workflow must checkout before gh release download in the x86_64 publish job"
grep -Fq 'is_release_tag: ${{ steps.validate-scope.outputs.is_release_tag }}' "${ci_workflow}" \
  || fail "ci workflow must expose release tag detection from classify-validate"
grep -Fq "needs.classify-validate.outputs.is_release_tag == 'true'" "${ci_workflow}" \
  || fail "ci workflow release jobs must depend on classify-validate release output"
grep -Fq 'if: ${{ needs.classify-validate.outputs.is_release_tag == '\''true'\'' }}' "${ci_workflow}" \
  || fail "ci workflow release job conditions must use explicit GitHub expressions for needs outputs"
grep -Fq 'completed successfully before arm64 release assets were created' "${release_script}" \
  || fail "release script must fail if a tag run succeeds without creating release assets"

echo "release automation verification passed"
