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
spaces_registry="$docs/spaces/INDEX.md"

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

if [[ ! -f "$spaces_registry" ]]; then
  echo "missing space registry: ${spaces_registry#$root/}" >&2
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

  registry_entry='[`'"$space_key"'`](./'"$space_key"'/README.md)'
  registry_count="$(awk -v needle="$registry_entry" 'index($0, needle) { count++ } END { print count + 0 }' "$spaces_registry")"
  if [[ "$registry_count" -ne 1 ]]; then
    echo "space registry must contain exactly one link for $space_key" >&2
    exit 1
  fi
done < <(find "$docs/spaces" -mindepth 1 -maxdepth 1 -type d | sort)

space_ids="$(sed -nE 's/^\| `(SP-[0-9]{3}-[a-z0-9-]+)` \|.*$/\1/p' "$spaces_registry")"
space_count="$(find "$docs/spaces" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

registry_id_count="$(printf '%s\n' "$space_ids" | wc -l | tr -d ' ')"
if [[ "$registry_id_count" -ne "$space_count" ]]; then
  echo "space registry ID count does not match space directory count" >&2
  exit 1
fi

unique_id_count="$(printf '%s\n' "$space_ids" | sort -u | wc -l | tr -d ' ')"
if [[ "$unique_id_count" -ne "$space_count" ]]; then
  echo "space registry contains duplicate IDs" >&2
  exit 1
fi

expected_number=1
while IFS= read -r space_id; do
  expected_prefix="$(printf 'SP-%03d-' "$expected_number")"
  if [[ "$space_id" != "$expected_prefix"* ]]; then
    echo "space registry IDs must be contiguous from SP-001: $space_id" >&2
    exit 1
  fi
  expected_number="$((expected_number + 1))"
done <<< "$space_ids"

echo "docs-linhay structure ok ($space_count spaces registered)"
