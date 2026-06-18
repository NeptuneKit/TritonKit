#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
repo="${TRITON_RELEASE_REPO:-NeptuneKit/TritonKit}"
tap_repository="${TRITON_TAP_REPOSITORY:-NeptuneKit/homebrew-tap}"
workflow_name="${TRITON_RELEASE_WORKFLOW:-Release}"
run_local_verify=1
assume_yes=0
dry_run=0

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/release.sh <version|vversion> [options]

Options:
  --yes                Do not prompt before creating and pushing the tag.
  --dry-run            Run preflight checks only; do not create or push a tag.
  --skip-local-verify  Skip docs-linhay/scripts/verify.sh --local.
  --repo OWNER/NAME    GitHub repository to release. Default: NeptuneKit/TritonKit.
  --tap OWNER/NAME     Homebrew tap repository. Default: NeptuneKit/homebrew-tap.
  -h, --help           Show this help.

Environment:
  TRITON_RELEASE_REPO       Overrides the default release repository.
  TRITON_TAP_REPOSITORY     Overrides the default Homebrew tap repository.
  TRITON_RELEASE_WORKFLOW   Overrides the workflow name used for run lookup.
USAGE
}

fail() {
  echo "release failed: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

normalize_tag() {
  local raw="$1"
  if [[ "${raw}" == v* ]]; then
    printf '%s\n' "${raw}"
  else
    printf 'v%s\n' "${raw}"
  fi
}

tap_name() {
  local owner="${tap_repository%%/*}"
  local name="${tap_repository#*/}"
  if [[ "${name}" == homebrew-* ]]; then
    name="${name#homebrew-}"
  fi
  printf '%s/%s\n' "${owner}" "${name}"
}

version_arg=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      assume_yes=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --skip-local-verify)
      run_local_verify=0
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || fail "--repo requires OWNER/NAME"
      repo="$2"
      shift 2
      ;;
    --tap)
      [[ $# -ge 2 ]] || fail "--tap requires OWNER/NAME"
      tap_repository="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "${version_arg}" ]] || fail "version was provided more than once"
      version_arg="$1"
      shift
      ;;
  esac
done

[[ -n "${version_arg}" ]] || {
  usage >&2
  exit 2
}

tag="$(normalize_tag "${version_arg}")"
version="${tag#v}"

[[ "${tag}" =~ ^v[0-9]+([.][0-9]+){1,2}([-+][0-9A-Za-z.-]+)?$ ]] || fail "invalid release tag: ${tag}"

cd "${root}"

require_command git
require_command gh
require_command ruby
require_command brew

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git worktree"
[[ -z "$(git status --porcelain)" ]] || fail "working tree is not clean"

gh auth status >/dev/null
gh repo view "${repo}" >/dev/null
gh repo view "${tap_repository}" >/dev/null

if ! gh secret list --repo "${repo}" | awk '{ print $1 }' | grep -Fxq "TAP_GITHUB_TOKEN"; then
  fail "TAP_GITHUB_TOKEN is not configured in ${repo}; set a token that can push ${tap_repository}"
fi

docs-linhay/scripts/verify-release-package-versions.sh "${version}"

git fetch origin main --tags
current_branch="$(git symbolic-ref --quiet --short HEAD || true)"
[[ "${current_branch}" == "main" ]] || fail "release must run from main; current branch is ${current_branch:-detached}"
git rev-parse --verify main >/dev/null 2>&1 || fail "local main branch not found"
git rev-parse --verify origin/main >/dev/null 2>&1 || fail "origin/main not found"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse main)" ]] || fail "HEAD is not local main"
[[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail "main is not synced with origin/main"

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  fail "local tag already exists: ${tag}"
fi

if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
  fail "remote tag already exists: ${tag}"
fi

if [[ "${run_local_verify}" == "1" ]]; then
  docs-linhay/scripts/verify.sh --local
fi

echo "Release preflight passed:"
echo "  repo: ${repo}"
echo "  tag: ${tag}"
echo "  version: ${version}"
echo "  tap: ${tap_repository}"

if [[ "${dry_run}" == "1" ]]; then
  echo "dry run complete; no tag was created"
  exit 0
fi

if [[ "${assume_yes}" != "1" ]]; then
  read -r -p "Create and push ${tag}? [y/N] " answer
  [[ "${answer}" == "y" || "${answer}" == "Y" ]] || fail "release cancelled"
fi

git tag -a "${tag}" -m "TritonKit ${tag}"
git push origin "${tag}"

echo "Waiting for GitHub Actions run for ${tag}..."
run_id=""
run_url=""
for _ in {1..60}; do
  run_url="$(
    gh run list \
      --repo "${repo}" \
      --workflow "${workflow_name}" \
      --event push \
      --branch "${tag}" \
      --limit 5 \
      --json headBranch,url \
      --jq '.[] | select(.headBranch == "'"${tag}"'") | .url' \
      | head -n 1
  )"
  if [[ -n "${run_url}" ]]; then
    run_id="${run_url##*/}"
  fi

  if [[ -n "${run_id}" ]]; then
    break
  fi
  sleep 5
done

[[ -n "${run_id}" ]] || fail "could not find GitHub Actions run for ${tag}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

brew_tap="$(tap_name)"

echo "Waiting for arm64 release assets and Homebrew tap for ${tag}..."
release_ready=0
for _ in {1..120}; do
  rm -f "${tmp_dir}/tritonkit_checksums.txt" "${tmp_dir}/triton.rb"

  if gh release view "${tag}" --repo "${repo}" >/dev/null 2>&1 \
    && gh release download "${tag}" \
      --repo "${repo}" \
      --pattern tritonkit_checksums.txt \
      --dir "${tmp_dir}" \
      --clobber >/dev/null 2>&1 \
    && grep -q 'triton-macos-arm64[.]tar[.]gz$' "${tmp_dir}/tritonkit_checksums.txt" \
    && grep -q 'tritonkit-skills[.]tar[.]gz$' "${tmp_dir}/tritonkit_checksums.txt"; then
    docs-linhay/scripts/render-homebrew-formula.sh \
      "${tag}" \
      "${tmp_dir}/tritonkit_checksums.txt" \
      ".github/homebrew/triton.rb.template" \
      "${tmp_dir}/triton.rb"
    ruby -c "${tmp_dir}/triton.rb" >/dev/null

    if brew tap "${brew_tap}" >/dev/null 2>&1 \
      && brew update >/dev/null 2>&1 \
      && brew fetch --formula "${brew_tap}/triton" >/dev/null 2>&1; then
      release_ready=1
      break
    fi
  fi

  run_status="$(gh run view "${run_id}" --repo "${repo}" --json status,conclusion --jq '.status + ":" + (.conclusion // "")' 2>/dev/null || true)"
	if [[ "${run_status}" == completed:* && "${run_status}" != "completed:success" ]]; then
	  fail "GitHub Actions run failed before arm64 release was ready: ${run_status}"
	fi
	if [[ "${run_status}" == "completed:success" ]]; then
	  fail "GitHub Actions run completed successfully before arm64 release assets were created; check release job conditions"
	fi

	sleep 10
done

[[ "${release_ready}" == "1" ]] || fail "arm64 release or Homebrew tap was not ready in time for ${tag}"

echo "release complete: ${tag}"
echo "GitHub Release: https://github.com/${repo}/releases/tag/${tag}"
echo "Homebrew: brew install ${brew_tap}/triton"
echo "x86_64 assets are published by the backfill job when the Intel runner finishes."
