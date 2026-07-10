#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docs="$root/docs-linhay"

required_dirs=(
  "$docs/dev"
  "$docs/memory"
  "$docs/spaces"
  "$docs/scripts"
)
spaces_index="$docs/spaces/README.md"

for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "missing directory: ${dir#$root/}" >&2
    exit 1
  fi
done

if [[ ! -f "$spaces_index" ]]; then
  echo "missing spaces index: ${spaces_index#$root/}" >&2
  exit 1
fi

if find "$docs" -name '* *' -print -quit | grep -q .; then
  echo "docs-linhay contains paths with spaces" >&2
  exit 1
fi

if find "$docs" -iname '*latest*' -o -iname '*final*' | grep -q .; then
  echo "docs-linhay contains non-traceable latest/final names" >&2
  exit 1
fi

while IFS= read -r space; do
  if [[ ! -f "$space/README.md" ]]; then
    echo "missing space README: ${space#$root/}" >&2
    exit 1
  fi

  space_key="$(basename "$space")"
  index_entry="[$space_key](./$space_key/README.md)"
  entry_count="$(awk -v needle="$index_entry" 'index($0, needle) { count++ } END { print count + 0 }' "$spaces_index")"
  if [[ "$entry_count" -ne 1 ]]; then
    echo "space index must contain exactly one link for $space_key" >&2
    exit 1
  fi
done < <(find "$docs/spaces" -mindepth 1 -maxdepth 1 -type d | sort)

echo "docs-linhay structure ok"
