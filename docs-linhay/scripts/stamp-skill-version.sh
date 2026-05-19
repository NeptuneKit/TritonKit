#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <SKILL.md>" >&2
  exit 64
fi

version="$1"
skill_file="$2"

if [[ ! "${version}" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]]; then
  echo "invalid version: ${version}" >&2
  exit 65
fi

if [[ ! -f "${skill_file}" ]]; then
  echo "skill file not found: ${skill_file}" >&2
  exit 66
fi

first_line="$(sed -n '1p' "${skill_file}")"
if [[ "${first_line}" != "---" ]]; then
  echo "skill file missing front matter: ${skill_file}" >&2
  exit 67
fi

tmp_file="$(mktemp)"
if [[ "$(uname -s)" == "Darwin" ]]; then
  file_mode="$(stat -f "%Lp" "${skill_file}")"
else
  file_mode="$(stat -c "%a" "${skill_file}")"
fi

awk -v version="${version}" '
  NR == 1 && $0 == "---" {
    print
    in_front_matter = 1
    next
  }
  in_front_matter && $0 ~ /^version:/ {
    next
  }
  in_front_matter && $0 ~ /^metadata:[[:space:]]*$/ {
    print
    in_metadata = 1
    saw_metadata = 1
    next
  }
  in_front_matter && in_metadata && $0 ~ /^  version:/ {
    if (!inserted) {
      print "  version: " version
      inserted = 1
    }
    next
  }
  in_front_matter && in_metadata && $0 ~ /^[^[:space:]][^:]*:/ {
    if (!inserted) {
      print "  version: " version
      inserted = 1
    }
    in_metadata = 0
    print
    next
  }
  in_front_matter && $0 ~ /^version:/ {
    next
  }
  in_front_matter && $0 == "---" {
    if (!inserted) {
      if (!saw_metadata) {
        print "metadata:"
      }
      print "  version: " version
      inserted = 1
    }
    print
    in_front_matter = 0
    next
  }
  { print }
  END {
    if (!inserted) {
      exit 1
    }
  }
' "${skill_file}" > "${tmp_file}"

chmod "${file_mode}" "${tmp_file}"
mv "${tmp_file}" "${skill_file}"
