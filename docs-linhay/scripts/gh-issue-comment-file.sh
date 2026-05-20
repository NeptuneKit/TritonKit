#!/usr/bin/env bash
set -euo pipefail

repo="${GH_REPO:-NeptuneKit/TritonKit}"

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/gh-issue-comment-file.sh <issue-number-or-url> <markdown-file>

Environment:
  GH_REPO  GitHub repository, defaults to NeptuneKit/TritonKit.

The comment body is always passed through gh --body-file, so Markdown backticks
and shell snippets are not evaluated by the local shell.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 2
fi

issue="$1"
body_file="$2"

if [[ ! -f "$body_file" ]]; then
  echo "missing markdown file: $body_file" >&2
  exit 1
fi

gh issue comment "$issue" --repo "$repo" --body-file "$body_file"
