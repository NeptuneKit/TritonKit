#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
triton="${TRITON_BIN:-$repo_root/.build/cli/debug/triton}"
out_dir="$repo_root/.build/harmony-runtime-emulator-smoke"
target="${TRITON_HARMONY_TARGET:-}"
local_port="${TRITON_HARMONY_RUNTIME_LOCAL_PORT:-28767}"
remote_port="${TRITON_HARMONY_RUNTIME_REMOTE_PORT:-28767}"
hdc="${HDC_BIN:-hdc}"
hap=""
harmony_repo="${HARMONY_TRITONKIT_REPO:-/Users/linhey/Desktop/linhay-open-sources/harmony-tritonkit}"
no_forward=false

usage() {
  cat <<'USAGE'
Usage: verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> [options]

Options:
  --target <target>       HDC target, for example 127.0.0.1:10100.
  --triton <path>         Triton CLI path. Defaults to TRITON_BIN or .build/cli/debug/triton.
  --out <dir>             Output directory. Defaults to .build/harmony-runtime-emulator-smoke.
  --hdc <path>            HDC executable. Defaults to HDC_BIN or hdc.
  --local-port <port>     Host local runtime port. Defaults to 28767.
  --remote-port <port>    Device embedded runtime host-access port. Defaults to 28767.
  --hap <path>            Optional demo HAP to install/start through harmony-tritonkit script.
  --harmony-repo <path>   harmony-tritonkit repo path. Used with --hap.
  --no-forward            Skip HDC fport setup and only probe the current local base URL.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      target="${2:-}"
      shift 2
      ;;
    --triton)
      triton="${2:-}"
      shift 2
      ;;
    --out)
      out_dir="${2:-}"
      shift 2
      ;;
    --hdc)
      hdc="${2:-}"
      shift 2
      ;;
    --local-port)
      local_port="${2:-}"
      shift 2
      ;;
    --remote-port)
      remote_port="${2:-}"
      shift 2
      ;;
    --hap)
      hap="${2:-}"
      shift 2
      ;;
    --harmony-repo)
      harmony_repo="${2:-}"
      shift 2
      ;;
    --no-forward)
      no_forward=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "{\"ok\":false,\"error\":{\"code\":\"unknown_argument\",\"message\":\"$1\"}}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$target" ]]; then
  echo '{"ok":false,"error":{"code":"missing_target","message":"Pass --target or TRITON_HARMONY_TARGET."}}' >&2
  exit 2
fi

mkdir -p "$out_dir"

"$triton" device wait-ready --platform harmony --target "$target" --hdc "$hdc" --timeout 60 --json > "$out_dir/wait-ready.json"
jq -e '.ok == true and .ready == true' "$out_dir/wait-ready.json" >/dev/null

if [[ -n "$hap" ]]; then
  start_script="$harmony_repo/scripts/start-demo-via-hdc.sh"
  if [[ ! -x "$start_script" ]]; then
    echo "{\"ok\":false,\"error\":{\"code\":\"missing_start_script\",\"message\":\"$start_script\"}}" >&2
    exit 2
  fi
  "$start_script" --target "$target" --hap "$hap" --no-build --no-unlock > "$out_dir/start-demo.log" 2>&1
fi

runtime_args=(
  device runtime-url
  --platform harmony
  --target "$target"
  --hdc "$hdc"
  --local-port "$local_port"
  --remote-port "$remote_port"
  --probe-manifest
  --json
)

if [[ "$no_forward" == true ]]; then
  runtime_args+=(--no-forward)
fi

"$triton" "${runtime_args[@]}" > "$out_dir/runtime-url.json"
base_url="$(jq -r '.baseURL' "$out_dir/runtime-url.json")"
jq -e '.ok == true and .manifest.platform == "harmony" and .manifest.runtime == "arkts-har"' "$out_dir/runtime-url.json" >/dev/null

"$triton" runtime manifest --runtime-base-url "$base_url" --json > "$out_dir/runtime-manifest.json"
jq -e '.ok == true and .platform == "harmony" and .runtime == "arkts-har"' "$out_dir/runtime-manifest.json" >/dev/null

"$triton" state app --runtime-base-url "$base_url" --json > "$out_dir/state-app.json"
jq -e '.ok == true and .platform == "harmony"' "$out_dir/state-app.json" >/dev/null

"$triton" state route --runtime-base-url "$base_url" --json > "$out_dir/state-route.json"
jq -e '(.ok == true) or (.ok == false and .errorCode == "unsupported_runtime_scope")' "$out_dir/state-route.json" >/dev/null

"$triton" snapshot --runtime-base-url "$base_url" --include app,route --json > "$out_dir/snapshot.json"
jq -e '.ok == true and .runtime == "arkts-har"' "$out_dir/snapshot.json" >/dev/null

"$triton" ledger --runtime-base-url "$base_url" --limit 5 --jsonl > "$out_dir/ledger.jsonl"
jq -s -e 'length >= 1 and all(.[]; has("requestType"))' "$out_dir/ledger.jsonl" >/dev/null

echo "{\"ok\":true,\"target\":\"$target\",\"baseURL\":\"$base_url\",\"outDir\":\"$out_dir\"}"
