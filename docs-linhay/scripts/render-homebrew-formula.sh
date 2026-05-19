#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <tag> <checksums-file> <template> <output>" >&2
  exit 64
fi

tag="$1"
checksums_file="$2"
template="$3"
output="$4"

if [[ ! "${tag}" =~ ^v[0-9]+([.][0-9]+){1,2}([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "invalid version tag: ${tag}" >&2
  exit 65
fi

if [[ ! -f "${checksums_file}" ]]; then
  echo "checksums file not found: ${checksums_file}" >&2
  exit 66
fi

if [[ ! -f "${template}" ]]; then
  echo "template not found: ${template}" >&2
  exit 66
fi

extract_sha() {
  local artifact="$1"
  awk -v artifact="${artifact}" '$2 ~ artifact "$" { print $1; found = 1 } END { if (!found) exit 1 }' "${checksums_file}"
}

sha_arm64="$(extract_sha "triton-macos-arm64[.]tar[.]gz")"
sha_x86_64="$(extract_sha "triton-macos-x86_64[.]tar[.]gz")"

for sha in "${sha_arm64}" "${sha_x86_64}"; do
  if [[ ! "${sha}" =~ ^[0-9a-f]{64}$ ]]; then
    echo "invalid sha256: ${sha}" >&2
    exit 67
  fi
done

version="${tag#v}"
mkdir -p "$(dirname "${output}")"

sed \
  -e "s/__TAG__/${tag}/g" \
  -e "s/__VERSION__/${version}/g" \
  -e "s/__SHA256_ARM64__/${sha_arm64}/g" \
  -e "s/__SHA256_X86_64__/${sha_x86_64}/g" \
  "${template}" > "${output}"
