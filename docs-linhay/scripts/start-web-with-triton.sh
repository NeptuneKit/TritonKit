#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
configuration="debug"
install_deps="auto"
restart="false"
host="127.0.0.1"
port="34127"
extra_vite_args=()

usage() {
  cat <<'USAGE'
Usage:
  docs-linhay/scripts/start-web-with-triton.sh [--debug|--release] [--install|--no-install] [--restart] [--host <host>] [--port <port>] [-- <vite-args>...]

Builds the triton CLI, then starts the Web Vite dev server with:
  TRITONKIT_TRITON_BIN=<built-triton>

Defaults:
  --debug       Build CLI debug product for faster local iteration.
  --install    Run npm install only when Web/node_modules is missing.
  --restart     Stop the existing listener on the selected Web port before starting.
  --host        Vite bind host. Default: 127.0.0.1.
  --port        Vite/Web port. Default: 34127.

Examples:
  docs-linhay/scripts/start-web-with-triton.sh
  docs-linhay/scripts/start-web-with-triton.sh --restart
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
    --restart)
      restart="true"
      shift
      ;;
    --host)
      host="${2:-}"
      if [[ -z "$host" ]]; then
        echo "--host requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    --port)
      port="${2:-}"
      if [[ -z "$port" ]]; then
        echo "--port requires a value" >&2
        exit 2
      fi
      shift 2
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

stop_existing_listener() {
  local pids
  pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "$pids" ]]; then
    return
  fi

  echo "==> Stop existing Web listener on ${host}:${port}: ${pids}"
  local current_pgid
  current_pgid="$(ps -o pgid= -p "$$" | tr -d ' ')"
  local pgids=()
  local pid
  for pid in $pids; do
    local pgid
    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    if [[ -n "$pgid" && "$pgid" != "$current_pgid" ]]; then
      pgids+=("$pgid")
    fi
  done

  if (( ${#pgids[@]} > 0 )); then
    local seen_pgids=" "
    local pgid
    for pgid in "${pgids[@]}"; do
      if [[ "$seen_pgids" == *" $pgid "* ]]; then
        continue
      fi
      seen_pgids+="$pgid "
      kill -- "-$pgid" 2>/dev/null || true
    done
  else
    kill $pids
  fi

  for _ in {1..20}; do
    sleep 0.25
    if ! lsof -tiTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      return
    fi
  done

  echo "port ${port} is still occupied after SIGTERM; stop it manually or choose --port <free-port>" >&2
  exit 1
}

require_command swift
require_command npm
if [[ "$restart" == "true" ]]; then
  require_command lsof
fi

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

if [[ "$restart" == "true" ]]; then
  stop_existing_listener
fi

echo "==> Start Web dev server"
echo "TRITONKIT_TRITON_BIN=$triton_bin"
echo "URL: http://${host}:${port}/"
echo "React Inspector: click the bottom-right button or press Ctrl+Shift+Command+C in the browser"

if (( ${#extra_vite_args[@]} > 0 )); then
  exec env TRITONKIT_TRITON_BIN="$triton_bin" npm --prefix "$root/Web" run dev -- --host "$host" --port "$port" "${extra_vite_args[@]}"
else
  exec env TRITONKIT_TRITON_BIN="$triton_bin" npm --prefix "$root/Web" run dev -- --host "$host" --port "$port"
fi
