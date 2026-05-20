#!/usr/bin/env bash
set -euo pipefail

repo="${GH_REPO:-NeptuneKit/TritonKit}"
watch="0"
interval="${GH_RUN_WATCH_INTERVAL:-15}"
run_id=""

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/gh-run-summary.sh [--watch] [--repo owner/name] <run-id>

Prints a compact GitHub Actions run summary. In --watch mode it refreshes at a
coarse interval and exits with the run conclusion.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch)
      watch="1"
      shift
      ;;
    --repo)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      repo="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$run_id" ]]; then
        usage >&2
        exit 2
      fi
      run_id="$1"
      shift
      ;;
  esac
done

if [[ -z "$run_id" ]]; then
  usage >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "missing jq" >&2
  exit 1
fi

print_run() {
  local json="$1"
  jq -r '
    "run: \(.workflowName) #\(.url | split("/")[-1])",
    "sha: \(.headSha[0:7]) status=\(.status) conclusion=\(.conclusion // "-")",
    (
      .jobs[]
      | "- \(.name): \(.status) / \(.conclusion // "-") \(.url)"
    )
  ' <<<"$json"
}

while true; do
  json="$(gh run view "$run_id" --repo "$repo" --json status,conclusion,url,headSha,workflowName,jobs)"
  print_run "$json"
  status="$(jq -r '.status' <<<"$json")"
  conclusion="$(jq -r '.conclusion // ""' <<<"$json")"

  if [[ "$status" == "completed" ]]; then
    [[ "$conclusion" == "success" ]]
    exit $?
  fi

  if [[ "$watch" != "1" ]]; then
    exit 0
  fi

  sleep "$interval"
done
