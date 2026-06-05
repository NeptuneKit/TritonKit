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
grep -q '^BUILD_INFO[.]json$' "${tmp_dir}/contents.txt"

for skill_name in tritonkit-dev-feedback tritonkit-emulator-cli-takeover tritonkit-real-project-regression; do
  grep -q "^${skill_name}/SKILL[.]md$" "${tmp_dir}/contents.txt"
  tar -xOf "${package}" "${skill_name}/SKILL.md" > "${tmp_dir}/${skill_name}.skill.md"
  grep -q '^  version: 9.8.7-dev+abcdef0$' "${tmp_dir}/${skill_name}.skill.md"
done

if grep -q '[.]DS_Store' "${tmp_dir}/contents.txt"; then
  echo "skill package should not contain .DS_Store" >&2
  exit 1
fi

tar -xOf "${package}" BUILD_INFO.json > "${tmp_dir}/BUILD_INFO.json"
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
]

assert build_info["name"] == "tritonkit-skills"
assert build_info["version"] == "9.8.7-dev+abcdef0"
assert build_info["releaseTag"] == "v9.8.7"
assert [skill["name"] for skill in build_info["skills"]] == expected
assert all(skill["version"] == "9.8.7-dev+abcdef0" for skill in build_info["skills"])
assert build_info == payload["buildInfo"]
PY

echo "skill package verification passed"
