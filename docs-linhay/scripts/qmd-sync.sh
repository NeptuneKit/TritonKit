#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

cat <<'NOTE'
qmd maintenance note:
  The current qmd CLI supports collection filters for query/search, but not for
  update/embed maintenance. This script keeps TritonKit's sync entrypoint stable,
  while the underlying qmd commands still update all configured collections.
NOTE

qmd update
qmd embed
