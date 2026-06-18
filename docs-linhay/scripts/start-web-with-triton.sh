#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
configuration="debug"
install_deps="auto"
extra_vite_args=()

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/start-web-with-triton.sh [--debug|--release] [--install|--no-install] [-- <vite-args>...]

Builds the triton CLI, then starts the Web Vite dev server with:
  TRITONKIT_TRITON_BIN=<built-triton>

Defaults:
  --debug       Build CLI debug product for faster local iteration.
  --install    Run npm install only when Web/node_modules is missing.

Examples:
  docs-linhay/scripts/start-web-with-triton.sh
  docs-linhay/scripts/start-web-with-triton.sh --release
  docs-linhay/scripts/start-web-with-triton.sh -- --host 127.0.0.1
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      configuration="debug"
      shift
      ;;
    --release)
      configuration="release"
      shift
      ;;
    --install)
      install_deps="always"
      shift
      ;;
    --no-install)
      install_deps="never"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_vite_args=("$@")
      break
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command() {
  local command="$1"
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "missing required command: $command" >&2
    exit 127
  fi
}

run_step() {
  local name="$1"
  shift
  echo "==> ${name}"
  "$@"
}

require_command swift
require_command npm

scratch_path="$root/.build/web-dev-cli"
build_args=(build --package-path "$root/CLI" --scratch-path "$scratch_path" --product triton)
triton_bin="$scratch_path/debug/triton"

if [[ "$configuration" == "release" ]]; then
  build_args+=(-c release)
  triton_bin="$scratch_path/release/triton"
fi

run_step "Build triton (${configuration})" swift "${build_args[@]}"

if [[ ! -x "$triton_bin" ]]; then
  echo "built triton is not executable: $triton_bin" >&2
  exit 1
fi

if [[ "$install_deps" == "always" || ( "$install_deps" == "auto" && ! -d "$root/Web/node_modules" ) ]]; then
  run_step "Install Web dependencies" npm --prefix "$root/Web" install
fi

echo "==> Start Web dev server"
echo "TRITONKIT_TRITON_BIN=$triton_bin"
echo "URL: http://127.0.0.1:34127/"

if (( ${#extra_vite_args[@]} > 0 )); then
  exec env TRITONKIT_TRITON_BIN="$triton_bin" npm --prefix "$root/Web" run dev -- "${extra_vite_args[@]}"
else
  exec env TRITONKIT_TRITON_BIN="$triton_bin" npm --prefix "$root/Web" run dev --
fi
