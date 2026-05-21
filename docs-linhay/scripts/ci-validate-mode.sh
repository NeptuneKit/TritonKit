#!/usr/bin/env bash
set -euo pipefail

mode="docs"

is_docs_only_path() {
  local path="$1"

  case "$path" in
    README.md|AGENTS.md|MEMORY.md)
      return 0
      ;;
    .agents/tritonkit-skills/*|.agents/skills/*)
      return 0
      ;;
    docs-linhay/scripts/*)
      return 1
      ;;
    docs-linhay/*|docs-dev/*|memory/*|references/*|screenshots/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

classify_paths() {
  local path

  if [[ "$#" -eq 0 ]]; then
    echo "full"
    return
  fi

  for path in "$@"; do
    if ! is_docs_only_path "$path"; then
      mode="full"
      break
    fi
  done

  echo "$mode"
}

changed_files_from_git() {
  if [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" ]]; then
    return 1
  fi

  if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]] || [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
    return 1
  fi

  if [[ "${GITHUB_EVENT_NAME:-}" == pull_request* ]] && [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD"
    return
  fi

  if [[ -n "${TRITON_CI_BASE_SHA:-}" ]] && [[ "${TRITON_CI_BASE_SHA}" != "0000000000000000000000000000000000000000" ]]; then
    git diff --name-only "${TRITON_CI_BASE_SHA}..HEAD"
    return
  fi

  if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    git diff --name-only HEAD~1..HEAD
    return
  fi

  return 1
}

if [[ "$#" -gt 0 ]]; then
  classify_paths "$@"
  exit 0
fi

if ! mapfile -t changed_files < <(changed_files_from_git); then
  echo "full"
  exit 0
fi

classify_paths "${changed_files[@]}"
