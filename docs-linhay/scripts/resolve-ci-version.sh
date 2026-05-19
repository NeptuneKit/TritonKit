#!/usr/bin/env bash
set -euo pipefail

ref_type="${GITHUB_REF_TYPE:-}"
ref_name="${GITHUB_REF_NAME:-}"
sha="${GITHUB_SHA:-}"
base_version="${TRITON_BASE_VERSION:-0.1.0}"

if [[ "${ref_type}" == "tag" && "${ref_name}" =~ ^v[0-9]+([.][0-9]+){1,2}([-+][0-9A-Za-z.-]+)?$ ]]; then
  version="${ref_name#v}"
elif [[ -n "${sha}" ]]; then
  short_sha="${sha:0:7}"
  version="${base_version}-dev+${short_sha}"
else
  version="${base_version}-dev"
fi

if [[ ! "${version}" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]]; then
  echo "invalid resolved version: ${version}" >&2
  exit 65
fi

printf '%s\n' "${version}"
