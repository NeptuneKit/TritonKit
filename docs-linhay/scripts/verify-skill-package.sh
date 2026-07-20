#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

package="${tmp_dir}/tritonkit-skills.tar.gz"
metadata="${tmp_dir}/package.json"

"${root}/docs-linhay/scripts/package-public-skills.py" \
  --repo-root "${root}" \
  --version "9.8.7-dev+abcdef0" \
  --release-tag "v9.8.7" \
  --output "${package}" \
  --json > "${metadata}"

test -f "${package}"
tar -tzf "${package}" | sort > "${tmp_dir}/contents.txt"
grep -q '^TritonKit[.]skills/BUILD_INFO[.]json$' "${tmp_dir}/contents.txt"
grep -q '^TritonKit[.]skills/README[.]md$' "${tmp_dir}/contents.txt"

for skill_name in tritonkit-dev-feedback tritonkit-emulator-cli-takeover tritonkit-real-project-regression tritonkit-update; do
  grep -q "^TritonKit[.]skills/${skill_name}/SKILL[.]md$" "${tmp_dir}/contents.txt"
  tar -xOf "${package}" "TritonKit.skills/${skill_name}/SKILL.md" > "${tmp_dir}/${skill_name}.skill.md"
  grep -q '^  version: 9.8.7-dev+abcdef0$' "${tmp_dir}/${skill_name}.skill.md"
done

dev_feedback_lines="$(wc -l < "${tmp_dir}/tritonkit-dev-feedback.skill.md")"
if [ "${dev_feedback_lines}" -gt 150 ]; then
  echo "tritonkit-dev-feedback/SKILL.md should stay routed and under 150 lines, got ${dev_feedback_lines}" >&2
  exit 1
fi

for reference in \
  issue-filing \
  evidence-ios-runtime \
  evidence-host-devices \
  schema-contract-feedback \
  app-integration-ios \
  app-integration-harmony
do
  grep -q "^TritonKit[.]skills/tritonkit-dev-feedback/references/${reference}[.]md$" "${tmp_dir}/contents.txt"
  grep -q "references/${reference}.md" "${tmp_dir}/tritonkit-dev-feedback.skill.md"
done

tar -xOf "${package}" TritonKit.skills/tritonkit-dev-feedback/references/issue-filing.md > "${tmp_dir}/issue-filing.md"
grep -q '^## Public issue preflight$' "${tmp_dir}/issue-filing.md"
grep -q 'rg -n' "${tmp_dir}/issue-filing.md"
grep -q '<private-app>' "${tmp_dir}/issue-filing.md"
grep -q '<bundle-id>' "${tmp_dir}/issue-filing.md"
grep -Eq '<simulator-target>|<ios-simulator-runtime-target>' "${tmp_dir}/issue-filing.md"
grep -Eq '<repo-path>|<local-path>' "${tmp_dir}/issue-filing.md"
grep -q '<user>' "${tmp_dir}/issue-filing.md"
grep -q 'Redaction preflight passed:' "${tmp_dir}/issue-filing.md"
python3 - "${tmp_dir}/issue-filing.md" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
preflight = text.index("## Public issue preflight")
create = text.index("gh issue create")
assert preflight < create
PY

if grep -q '[.]DS_Store' "${tmp_dir}/contents.txt"; then
  echo "skill package should not contain .DS_Store" >&2
  exit 1
fi

tar -xOf "${package}" TritonKit.skills/BUILD_INFO.json > "${tmp_dir}/BUILD_INFO.json"
python3 - "${tmp_dir}/BUILD_INFO.json" "${metadata}" <<'PY'
import json
import pathlib
import sys

build_info = json.loads(pathlib.Path(sys.argv[1]).read_text())
payload = json.loads(pathlib.Path(sys.argv[2]).read_text())

expected = [
    "tritonkit-dev-feedback",
    "tritonkit-emulator-cli-takeover",
    "tritonkit-real-project-regression",
    "tritonkit-update",
]

assert build_info["name"] == "tritonkit-skills"
assert build_info["bundlePath"] == "TritonKit.skills/"
assert build_info["version"] == "9.8.7-dev+abcdef0"
assert build_info["releaseTag"] == "v9.8.7"
assert [skill["name"] for skill in build_info["skills"]] == expected
assert all(skill["version"] == "9.8.7-dev+abcdef0" for skill in build_info["skills"])
assert build_info == payload["buildInfo"]
PY

install_dir="${tmp_dir}/agent-skills"
mkdir -p "${install_dir}/tritonkit-dev-feedback" \
  "${install_dir}/tritonkit-emulator-cli-takeover" \
  "${install_dir}/tritonkit-real-project-regression" \
  "${install_dir}/tritonkit-update"
"${root}/docs-linhay/scripts/install-public-skills.sh" "${install_dir}" --from-tar "${package}" >/tmp/tritonkit-install-skills.log
test -d "${install_dir}/TritonKit.skills"
test -f "${install_dir}/TritonKit.skills/tritonkit-dev-feedback/SKILL.md"
test ! -e "${install_dir}/tritonkit-dev-feedback"
test ! -e "${install_dir}/tritonkit-emulator-cli-takeover"
test ! -e "${install_dir}/tritonkit-real-project-regression"
test ! -e "${install_dir}/tritonkit-update"

source_install_dir="${tmp_dir}/agent-skills-source"
mkdir -p "${source_install_dir}/tritonkit-dev-feedback"
"${root}/docs-linhay/scripts/install-public-skills.sh" "${source_install_dir}" >/tmp/tritonkit-install-source-skills.log
test -d "${source_install_dir}/TritonKit.skills"
test -f "${source_install_dir}/TritonKit.skills/tritonkit-real-project-regression/SKILL.md"
test -f "${source_install_dir}/TritonKit.skills/tritonkit-update/SKILL.md"
test ! -e "${source_install_dir}/tritonkit-dev-feedback"

legacy_skill_root="${tmp_dir}/legacy-skills"
cp -R "${root}/TritonKit.skills" "${legacy_skill_root}"
printf '\n```sh\ntriton find "More" --json\ntriton ax --json --with-hierarchy\n```\n' \
  >> "${legacy_skill_root}/tritonkit-dev-feedback/SKILL.md"
if "${root}/docs-linhay/scripts/package-public-skills.py" \
  --repo-root "${root}" \
  --skill-root "${legacy_skill_root}" \
  --version "9.8.7-dev+abcdef0" \
  --output "${tmp_dir}/legacy-skills.tar.gz" \
  2> "${tmp_dir}/legacy-skills.stderr"
then
  echo "skill package should reject retired top-level Triton commands" >&2
  exit 1
fi
grep -q 'unknown Triton command root `find`' "${tmp_dir}/legacy-skills.stderr"
grep -q 'use `triton act find`' "${tmp_dir}/legacy-skills.stderr"
grep -q 'unknown Triton command root `ax`' "${tmp_dir}/legacy-skills.stderr"
grep -q 'use `triton debug ax`' "${tmp_dir}/legacy-skills.stderr"
test ! -e "${tmp_dir}/legacy-skills.tar.gz"

echo "skill package verification passed"
