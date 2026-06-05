#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/install-public-skills.sh <agent-skills-dir> [--from-tar <tritonkit-skills.tar.gz>]

Installs the public TritonKit skill bundle as:
  <agent-skills-dir>/TritonKit.skills/

The installer removes the older top-level per-skill layout first:
  tritonkit-dev-feedback
  tritonkit-emulator-cli-takeover
  tritonkit-real-project-regression
USAGE
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 64
fi

agent_skills_dir="$1"
shift
tarball=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-tar)
      if [[ $# -lt 2 ]]; then
        echo "--from-tar requires a path" >&2
        exit 64
      fi
      tarball="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

mkdir -p "${agent_skills_dir}"

for legacy_skill in \
  tritonkit-dev-feedback \
  tritonkit-emulator-cli-takeover \
  tritonkit-real-project-regression; do
  rm -rf "${agent_skills_dir:?}/${legacy_skill}"
done
rm -rf "${agent_skills_dir:?}/TritonKit.skills"

if [[ -n "${tarball}" ]]; then
  if [[ ! -f "${tarball}" ]]; then
    echo "skill tarball not found: ${tarball}" >&2
    exit 66
  fi
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT
  tar -xzf "${tarball}" -C "${tmp_dir}"
  if [[ ! -d "${tmp_dir}/TritonKit.skills" ]]; then
    echo "skill tarball must contain TritonKit.skills/" >&2
    exit 67
  fi
  cp -R "${tmp_dir}/TritonKit.skills" "${agent_skills_dir}/TritonKit.skills"
else
  cp -R "${root}/TritonKit.skills" "${agent_skills_dir}/TritonKit.skills"
fi

echo "Installed TritonKit.skills to ${agent_skills_dir}/TritonKit.skills"
