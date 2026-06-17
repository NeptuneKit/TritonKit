#!/usr/bin/env bash
set -euo pipefail

mode="docs"

is_docs_only_path() {
  local path="$1"

  case "$path" in
    README.md|AGENTS.md|MEMORY.md)
      return 0
      ;;
    TritonKit.skills/*|.agents/skills/*)
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

is_swift_only_path() {
  local path="$1"

  case "$path" in
    Package.swift|Package.resolved|CLI/Package.swift|CLI/Package.resolved)
      return 0
      ;;
    Sources/TritonKitCLI/*)
      return 0
      ;;
    CLI/Sources/TritonKitCLI)
      return 0
      ;;
    Tests/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_contract_only_path() {
  local path="$1"

  case "$path" in
    .github/workflows/*)
      return 0
      ;;
    docs-linhay/scripts/ci-validate-mode.sh|\
docs-linhay/scripts/verify-ci-validate-mode.sh|\
docs-linhay/scripts/verify-release-automation.sh|\
docs-linhay/scripts/verify-homebrew-formula.sh|\
docs-linhay/scripts/verify-version-stamping.sh|\
docs-linhay/scripts/package-public-skills.py|\
docs-linhay/scripts/install-public-skills.sh|\
docs-linhay/scripts/verify-skill-package.sh|\
docs-linhay/scripts/render-homebrew-formula.sh|\
docs-linhay/scripts/resolve-ci-version.sh|\
docs-linhay/scripts/write-cli-version.sh|\
docs-linhay/scripts/stamp-skill-version.sh|\
docs-linhay/scripts/gh-run-summary.sh|\
docs-linhay/scripts/release.sh)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_podkit_path() {
  local path="$1"

  case "$path" in
    TritonKit.podspec)
      return 0
      ;;
    Sources/TritonKit/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

raise_mode() {
  local next="$1"

  case "$mode:$next" in
    full:*)
      ;;
    *:full)
      mode="full"
      ;;
    podkit:*)
      ;;
    *:podkit)
      mode="podkit"
      ;;
    swift:contracts|contracts:swift)
      mode="swift"
      ;;
    docs:*)
      mode="$next"
      ;;
    *:docs)
      ;;
    *)
      mode="$next"
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
    if is_docs_only_path "$path"; then
      continue
    fi

    if is_contract_only_path "$path"; then
      raise_mode "contracts"
      continue
    fi

    if is_swift_only_path "$path"; then
      raise_mode "swift"
      continue
    fi

    if is_podkit_path "$path"; then
      raise_mode "podkit"
      continue
    fi

    mode="full"
    break
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

changed_files=()
while IFS= read -r changed_file; do
  changed_files+=("${changed_file}")
done < <(changed_files_from_git) || {
  echo "full"
  exit 0
}

classify_paths "${changed_files[@]}"
