#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
triton="${TRITON_BIN:-$root/.build/cli/debug/triton}"
host="${TRITON_HOST:-127.0.0.1}"
port="${TRITON_PORT:-19421}"
out_dir="${TRITON_VERIFY_OUT_DIR:-/tmp/triton-cli-bootstrap}"

mkdir -p "$out_dir"

if [[ ! -x "$triton" ]]; then
  echo "missing triton binary: $triton" >&2
  echo "run: swift build --package-path CLI --scratch-path .build/cli --product triton" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "missing jq" >&2
  exit 1
fi

if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "port $port is already listening; stop triton serve before bootstrap verification" >&2
  exit 1
fi

"$triton" version --json > "$out_dir/version.json"
jq -e '.ok == true and .defaultHost == "127.0.0.1" and .defaultPort == 19421 and .language == "en" and .supportedLanguages == ["en","zh"] and (.version | length > 0)' "$out_dir/version.json" >/dev/null

"$triton" version --language zh --json > "$out_dir/version-zh.json"
jq -e '.ok == true and .language == "zh" and .supportedLanguages == ["en","zh"]' "$out_dir/version-zh.json" >/dev/null

"$triton" --language zh -h > "$out_dir/help-zh.txt"
grep -q '概览' "$out_dir/help-zh.txt"
grep -q '子命令' "$out_dir/help-zh.txt"
grep -q '启动本地' "$out_dir/help-zh.txt"

TRITON_LANGUAGE=zh "$triton" -h > "$out_dir/help-env-zh.txt"
grep -q '概览' "$out_dir/help-env-zh.txt"
grep -q '子命令' "$out_dir/help-env-zh.txt"

"$triton" schema --command input --json > "$out_dir/schema-input.json"
jq -e '
  .schemaVersion == 1 and
  (.commands | length) == 1 and
  .commands[0].name == "input" and
  (.commands[0].inputActions | length) >= 4 and
  (.commands[0].options | any(.name == "--json"))
' "$out_dir/schema-input.json" >/dev/null

"$triton" plan --host "$host" --port "$port" --json > "$out_dir/plan.json"
jq -e '.ok == false and .serverReachable == false and .nextStep == "start-server" and .error.nextAction.command == "serve"' "$out_dir/plan.json" >/dev/null

"$triton" doctor --host "$host" --port "$port" --json > "$out_dir/doctor.json"
jq -e '.ok == false and .serverReachable == false and .error.code == "server_unavailable" and .error.nextAction.command == "serve"' "$out_dir/doctor.json" >/dev/null

"$triton" capabilities --host "$host" --port "$port" --json > "$out_dir/capabilities.json"
jq -e '.ok == false and .serverReachable == false and .runtime == "unknown" and (.capabilities | length) > 0' "$out_dir/capabilities.json" >/dev/null

set +e
"$triton" status --host "$host" --port "$port" --json > "$out_dir/status.json"
status_code=$?
set -e
if [[ "$status_code" -eq 0 ]]; then
  echo "status --json should fail when server is unavailable" >&2
  exit 1
fi
jq -e '.ok == false and .error.code == "server_unavailable" and .error.nextAction.command == "serve"' "$out_dir/status.json" >/dev/null

set +e
"$triton" > "$out_dir/default-list.txt" 2>&1
default_code=$?
set -e
if [[ "$default_code" -eq 0 ]]; then
  echo "bare triton should fail when server is unavailable" >&2
  exit 1
fi
if grep -q 'NSURLErrorDomain\|LocalDataTask' "$out_dir/default-list.txt"; then
  echo "bare triton leaked Foundation URLSession error" >&2
  cat "$out_dir/default-list.txt" >&2
  exit 1
fi
grep -q 'server_unavailable' "$out_dir/default-list.txt"
grep -q 'triton serve --host' "$out_dir/default-list.txt"

set +e
"$triton" --language zh > "$out_dir/default-list-zh.txt" 2>&1
default_zh_code=$?
set -e
if [[ "$default_zh_code" -eq 0 ]]; then
  echo "bare triton --language zh should fail when server is unavailable" >&2
  exit 1
fi
grep -q '服务器不可用' "$out_dir/default-list-zh.txt"
grep -q 'triton serve --host' "$out_dir/default-list-zh.txt"

set +e
TRITON_LANGUAGE=zh "$triton" > "$out_dir/default-list-env-zh.txt" 2>&1
default_env_zh_code=$?
set -e
if [[ "$default_env_zh_code" -eq 0 ]]; then
  echo "TRITON_LANGUAGE=zh triton should fail when server is unavailable" >&2
  exit 1
fi
grep -q '服务器不可用' "$out_dir/default-list-env-zh.txt"

cat <<REPORT
cli bootstrap verification passed
version: $out_dir/version.json
version-zh: $out_dir/version-zh.json
help-zh: $out_dir/help-zh.txt
help-env-zh: $out_dir/help-env-zh.txt
schema: $out_dir/schema-input.json
plan: $out_dir/plan.json
doctor: $out_dir/doctor.json
capabilities: $out_dir/capabilities.json
status: $out_dir/status.json
default-list: $out_dir/default-list.txt
default-list-zh: $out_dir/default-list-zh.txt
default-list-env-zh: $out_dir/default-list-env-zh.txt
REPORT
