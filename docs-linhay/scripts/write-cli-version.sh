#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <swift-source-file>" >&2
  exit 64
fi

version="$1"
swift_file="$2"

if [[ ! "${version}" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]]; then
  echo "invalid version: ${version}" >&2
  exit 65
fi

if [[ ! -f "${swift_file}" ]]; then
  echo "swift source file not found: ${swift_file}" >&2
  exit 66
fi

tmp_file="$(mktemp)"
if [[ "$(uname -s)" == "Darwin" ]]; then
  file_mode="$(stat -f "%Lp" "${swift_file}")"
else
  file_mode="$(stat -c "%a" "${swift_file}")"
fi

awk -v version="${version}" '
  $0 ~ /^[[:space:]]*static let cliVersion = "/ {
    indent = $0
    sub(/static let cliVersion.*/, "", indent)
    print indent "static let cliVersion = \"" version "\""
    found = 1
    next
  }
  { print }
  END {
    if (!found) {
      exit 1
    }
  }
' "${swift_file}" > "${tmp_file}"

chmod "${file_mode}" "${tmp_file}"
mv "${tmp_file}" "${swift_file}"
