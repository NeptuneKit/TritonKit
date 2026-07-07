#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
triton="${TRITON_BIN:-$root/.build/cli/debug/triton}"
host="${TRITON_HOST:-127.0.0.1}"
port="${TRITON_PORT:-19421}"
target="${TRITON_TARGET:-triton:local}"
out_dir="${TRITON_VERIFY_OUT_DIR:-/tmp/triton-overloaded-smoke}"
name_text="${TRITON_OVERLOADED_NAME:-Triton Smoke}"
include_system_prompt="${TRITON_OVERLOADED_INCLUDE_SYSTEM_PROMPT:-0}"
require_system_prompt="${TRITON_OVERLOADED_REQUIRE_SYSTEM_PROMPT:-0}"
expected_bundle_regex="${TRITON_OVERLOADED_EXPECTED_BUNDLE_REGEX:-^overloaded\.cn(\.debug)?$}"

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

triton_find() {
  "$triton" act find "$1" --host "$host" --port "$port" --target "$target" --json
}

triton_tap() {
  "$triton" act tap "$1" --host "$host" --port "$port" --target "$target" --json
}

triton_type() {
  "$triton" act type --host "$host" --port "$port" --target "$target" --text "$1" --json
}

triton_observe_current() {
  "$triton" observe current --host "$host" --port "$port" --target "$target" --json
}

triton_debug_ax() {
  "$triton" debug ax --host "$host" --port "$port" --target "$target" --json
}

"$triton" status --host "$host" --port "$port" --json > "$out_dir/status-before.json"
jq -e '.ok == true and .connected == true and .targetCount >= 1' "$out_dir/status-before.json" >/dev/null

if [[ -n "$expected_bundle_regex" ]]; then
  triton_observe_current > "$out_dir/observe-target.json"
  if ! jq -e --arg re "$expected_bundle_regex" '(.target // "") | capture("/app:(?<bundle>[^/]+)$").bundle | test($re)' "$out_dir/observe-target.json" >/dev/null; then
    current_target="$(jq -r '.target // "unknown"' "$out_dir/observe-target.json")"
    echo "expected Overloaded runtime target matching $expected_bundle_regex, got: $current_target" >&2
    echo "set TRITON_OVERLOADED_EXPECTED_BUNDLE_REGEX= to skip this app identity preflight" >&2
    exit 2
  fi
fi

if triton_find "稍后再说" > "$out_dir/find-skip-permission.json" 2>/dev/null; then
  triton_tap "稍后再说" > "$out_dir/tap-skip-permission.json"
  jq -e '.ok == true' "$out_dir/tap-skip-permission.json" >/dev/null
  sleep 1
fi

if triton_find "添加" > "$out_dir/find-add.json" 2>/dev/null; then
  triton_tap "添加" > "$out_dir/tap-add.json"
  jq -e '.ok == true' "$out_dir/tap-add.json" >/dev/null
fi

triton_find "HTTP" > "$out_dir/find-http.json"
jq -e '.query == "HTTP" and (.request.type == "tap")' "$out_dir/find-http.json" >/dev/null

set +e
triton_tap "添加连接" > "$out_dir/tap-nav-title.json" 2>&1
nav_title_code=$?
set -e
if [[ "$nav_title_code" -eq 0 ]]; then
  echo "navigation title tap should fail" >&2
  exit 1
fi
grep -Eq 'Target UIControl has no primary or touchUpInside action|Hit view does not expose a public UIControl tap action' "$out_dir/tap-nav-title.json"

triton_tap "HTTP" > "$out_dir/tap-http.json"
jq -e '.ok == true and .targetClassName == "UISegmentedControl"' "$out_dir/tap-http.json" >/dev/null
triton_find "端口" > "$out_dir/find-port-http.json"
jq -e '.role == "textField" and .value == "80"' "$out_dir/find-port-http.json" >/dev/null

triton_tap "HTTPS" > "$out_dir/tap-https.json"
jq -e '.ok == true and .targetClassName == "UISegmentedControl"' "$out_dir/tap-https.json" >/dev/null
triton_find "端口" > "$out_dir/find-port-https.json"
jq -e '.role == "textField" and .value == "443"' "$out_dir/find-port-https.json" >/dev/null

triton_tap "名称" > "$out_dir/tap-name.json"
jq -e '.ok == true and .targetClassName == "UITextField"' "$out_dir/tap-name.json" >/dev/null
triton_type "$name_text" > "$out_dir/type-name.json"
jq -e '.ok == true and .targetClassName == "UITextField"' "$out_dir/type-name.json" >/dev/null
triton_find "名称" > "$out_dir/find-name-after.json"
jq -e --arg text "$name_text" '.role == "textField" and (.value | contains($text))' "$out_dir/find-name-after.json" >/dev/null

set +e
triton_tap "验证连接" > "$out_dir/tap-disabled-primary.json" 2>&1
disabled_code=$?
set -e
if [[ "$disabled_code" -eq 0 ]]; then
  echo "disabled primary action should fail" >&2
  exit 1
fi
grep -q 'Target UIControl is disabled' "$out_dir/tap-disabled-primary.json"

set +e
triton_tap "连接信息" > "$out_dir/tap-static-title.json" 2>&1
static_code=$?
set -e
if [[ "$static_code" -eq 0 ]]; then
  echo "static title tap should fail" >&2
  exit 1
fi
grep -q 'Hit view does not expose a public UIControl tap action' "$out_dir/tap-static-title.json"

triton_find "导入连接" > "$out_dir/find-import.json"
jq -e '.role == "control" and .identifier == "document.editor.action.import"' "$out_dir/find-import.json" >/dev/null

if [[ "$include_system_prompt" == "1" ]]; then
  triton_tap "导入连接" > "$out_dir/tap-import.json"
  jq -e '.ok == true and .message == "Dispatched UIControl.touchUpInside"' "$out_dir/tap-import.json" >/dev/null

  set +e
  triton_debug_ax > "$out_dir/ax-after-import.json" 2>&1
  ax_code=$?
  set -e
  if [[ "$ax_code" -eq 0 ]]; then
    if [[ "$require_system_prompt" == "1" ]]; then
      echo "ax should be interrupted while system pasteboard alert is visible" >&2
      exit 1
    fi
    cat > "$out_dir/system-prompt-skipped.txt" <<SKIP
system pasteboard alert was not observed; ax succeeded after tapping import
set TRITON_OVERLOADED_REQUIRE_SYSTEM_PROMPT=1 to make this a hard failure
SKIP
  else
    jq -e '.ok == false and .error.code == "runtime_ui_interrupted"' "$out_dir/ax-after-import.json" >/dev/null
  fi
fi

"$triton" status --host "$host" --port "$port" --json > "$out_dir/status-after.json"
jq -e '.ok == true and .connected == true and .targetCount >= 1' "$out_dir/status-after.json" >/dev/null

cat <<REPORT
overloaded triton smoke passed
status-before: $out_dir/status-before.json
find-skip-permission: $out_dir/find-skip-permission.json
find-http: $out_dir/find-http.json
tap-http: $out_dir/tap-http.json
tap-nav-title: $out_dir/tap-nav-title.json
tap-https: $out_dir/tap-https.json
type-name: $out_dir/type-name.json
tap-disabled-primary: $out_dir/tap-disabled-primary.json
tap-static-title: $out_dir/tap-static-title.json
find-import: $out_dir/find-import.json
system-prompt-skipped: $out_dir/system-prompt-skipped.txt
status-after: $out_dir/status-after.json
REPORT
