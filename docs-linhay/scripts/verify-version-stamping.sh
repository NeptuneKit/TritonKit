#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

tag_version="$(
  GITHUB_REF_TYPE=tag \
  GITHUB_REF_NAME=v1.2.3 \
  GITHUB_SHA=0123456789abcdef \
  "${root}/docs-linhay/scripts/resolve-ci-version.sh"
)"
if [[ "${tag_version}" != "1.2.3" ]]; then
  echo "unexpected tag version: ${tag_version}" >&2
  exit 1
fi

dev_version="$(
  GITHUB_REF_TYPE=branch \
  GITHUB_REF_NAME=main \
  GITHUB_SHA=0123456789abcdef \
  "${root}/docs-linhay/scripts/resolve-ci-version.sh"
)"
if [[ "${dev_version}" != "0.1.0-dev+0123456" ]]; then
  echo "unexpected dev version: ${dev_version}" >&2
  exit 1
fi

swift_file="${tmp_dir}/main.swift"
cat > "${swift_file}" <<'SWIFT'
enum TritonKitBuildInfo {
    static let cliVersion = "0.1.0-dev"
}
SWIFT

"${root}/docs-linhay/scripts/write-cli-version.sh" "${tag_version}" "${swift_file}"
grep -q 'static let cliVersion = "1.2.3"' "${swift_file}"

skill_file="${tmp_dir}/SKILL.md"
cat > "${skill_file}" <<'SKILL'
---
name: sample
description: Sample skill.
---

# Sample
SKILL

"${root}/docs-linhay/scripts/stamp-skill-version.sh" "${tag_version}" "${skill_file}"
grep -q '^metadata:$' "${skill_file}"
grep -q '^  version: 1.2.3$' "${skill_file}"

"${root}/docs-linhay/scripts/stamp-skill-version.sh" "1.2.4-dev+abcdef0" "${skill_file}"
grep -q '^  version: 1.2.4-dev+abcdef0$' "${skill_file}"
if [[ "$(grep -c '^  version:' "${skill_file}")" -ne 1 ]]; then
  echo "skill version field duplicated" >&2
  exit 1
fi

echo "version stamping verification passed"
