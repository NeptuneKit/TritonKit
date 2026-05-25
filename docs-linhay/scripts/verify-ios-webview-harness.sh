#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
triton="${TRITON_BIN:-$root/.build/cli/debug/triton}"
host="${TRITON_HOST:-127.0.0.1}"
port="${TRITON_PORT:-19421}"
target="${TRITON_TARGET:-triton:local}"
simulator="${TRITON_SIMULATOR:-}"
out_dir="${TRITON_VERIFY_OUT_DIR:-/tmp/triton-ios-webview-harness}"
project="${TRITON_DEMO_PROJECT:-$root/Examples/TritonKitDemo/TritonKitDemo.xcodeproj}"
scheme="${TRITON_DEMO_SCHEME:-TritonKitDemo}"
configuration="${TRITON_DEMO_CONFIGURATION:-Debug}"
server_pid=""

mkdir -p "$out_dir"

if [[ ! -x "$triton" ]]; then
  echo "missing triton binary: $triton" >&2
  echo "run: swift build --package-path CLI --scratch-path .build/cli --product triton" >&2
  exit 1
fi

if [[ -z "$simulator" ]]; then
  echo "missing TRITON_SIMULATOR" >&2
  echo "set TRITON_SIMULATOR to a booted iOS Simulator UDID" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "missing jq" >&2
  exit 1
fi

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

tap_label_center() {
  local label="$1"
  local name="$2"
  local find_json="$out_dir/find-${name}.json"
  local tap_json="$out_dir/tap-${name}.json"
  local x y

  "$triton" find "$label" --host "$host" --port "$port" --target "$target" --all --json >"$find_json"
  x="$(jq -er '.frame.x + (.frame.width / 2)' "$find_json")"
  y="$(jq -er '.frame.y + (.frame.height / 2)' "$find_json")"
  "$triton" tap --host "$host" --port "$port" --target "$target" --x "$x" --y "$y" --json >"$tap_json"
  jq -e '.ok == true' "$tap_json" >/dev/null
}

if ! "$triton" status --host "$host" --port "$port" --json >"$out_dir/status-before.json" 2>/dev/null; then
  "$triton" serve --host "$host" --port "$port" >"$out_dir/server.log" 2>&1 &
  server_pid="$!"
  sleep 1
fi

"$triton" xcode run \
  --project "$project" \
  --scheme "$scheme" \
  --configuration "$configuration" \
  --simulator "$simulator" \
  --jsonl \
  --timeout 180 \
  >"$out_dir/xcode-run.jsonl"

for attempt in {1..20}; do
  "$triton" status --host "$host" --port "$port" --json >"$out_dir/status-after-launch.json"
  if jq -e '.ok == true and .connected == true and .runtime == "embedded"' "$out_dir/status-after-launch.json" >/dev/null; then
    break
  fi
  if [[ "$attempt" == "20" ]]; then
    echo "runtime did not reconnect after launch" >&2
    exit 1
  fi
  sleep 0.5
done
jq -e '.ok == true and .connected == true and .runtime == "embedded"' "$out_dir/status-after-launch.json" >/dev/null

for attempt in {1..20}; do
  "$triton" webview snapshot \
    --host "$host" \
    --port "$port" \
    --target "$target" \
    --platform ios \
    --include metadata,dom,text,forms,links \
    --max-dom-nodes 20 \
    --max-text-bytes 2048 \
    --json \
    >"$out_dir/overview-snapshot.json"

  if jq -e '
    .ok == true and
    .webView.title == "Triton WebView Smoke" and
    (.forms | length) == 1 and
    .forms[0].valueRedaction == "length-only"
  ' "$out_dir/overview-snapshot.json" >/dev/null; then
    break
  fi
  if [[ "$attempt" == "20" ]]; then
    echo "overview WebView did not finish loading" >&2
    exit 1
  fi
  sleep 0.5
done

tap_label_center "Web Edge" "web-edge"
sleep 1

for attempt in {1..20}; do
  "$triton" webview snapshot \
    --host "$host" \
    --port "$port" \
    --target "$target" \
    --platform ios \
    --include metadata,dom,text,forms,links \
    --max-dom-nodes 6 \
    --max-text-bytes 80 \
    --json \
    >"$out_dir/edge-snapshot.json"

  if jq -e '
    .ok == true and
    .webView.title == "Triton WebView Edge" and
    (.forms | length) <= 6 and
    (.links | length) <= 6 and
    ([.forms[] | select(.inputType == "password" and .valueRedaction == "length-only")] | length) == 1 and
    .truncation.truncated == true
  ' "$out_dir/edge-snapshot.json" >/dev/null; then
    break
  fi
  if [[ "$attempt" == "20" ]]; then
    echo "edge WebView did not reach expected snapshot state" >&2
    exit 1
  fi
  sleep 0.5
done

"$triton" webview call getRouteState --host "$host" --port "$port" --target "$target" --platform ios --json >"$out_dir/edge-route.json"
jq -e '.ok == true and .result.route == "/edge"' "$out_dir/edge-route.json" >/dev/null

"$triton" webview call emitEdgeEvent --host "$host" --port "$port" --target "$target" --platform ios --json >"$out_dir/edge-event-call.json"
"$triton" webview events --host "$host" --port "$port" --target "$target" --platform ios --limit 10 --json >"$out_dir/edge-events.json"
jq -e '.ok == true and ([.events[] | select(.name == "edge.ready")] | length) >= 1' "$out_dir/edge-events.json" >/dev/null

tap_label_center "Web Nav" "web-nav"
sleep 1

for attempt in {1..20}; do
  "$triton" webview current --host "$host" --port "$port" --target "$target" --platform ios --json >"$out_dir/nav-current-before.json"
  if jq -e '.ok == true and .webView.title == "Triton WebView Navigation A"' "$out_dir/nav-current-before.json" >/dev/null; then
    break
  fi
  if [[ "$attempt" == "20" ]]; then
    echo "navigation WebView did not reach initial page" >&2
    exit 1
  fi
  sleep 0.5
done

page_session_id="$(jq -r '.webView.pageSessionID' "$out_dir/nav-current-before.json")"
"$triton" webview call getRouteState --host "$host" --port "$port" --target "$target" --platform ios --json >"$out_dir/nav-route-before.json"
jq -e '.ok == true and .result.route == "/navigation"' "$out_dir/nav-route-before.json" >/dev/null

"$triton" webview call navigateDetails --host "$host" --port "$port" --target "$target" --platform ios --json >"$out_dir/nav-call.json"
jq -e '.ok == true and .result.route == "/navigation/b"' "$out_dir/nav-call.json" >/dev/null

if "$triton" webview snapshot \
  --host "$host" \
  --port "$port" \
  --target "$target" \
  --platform ios \
  --page-session-id "$page_session_id" \
  --json \
  >"$out_dir/nav-stale-snapshot.json"; then
  echo "expected stale page session snapshot to fail" >&2
  exit 1
fi

jq -e '.ok == false and .error.code == "webview_navigation_changed"' "$out_dir/nav-stale-snapshot.json" >/dev/null

"$triton" webview current --host "$host" --port "$port" --target "$target" --platform ios --json >"$out_dir/nav-current-after.json"
jq -e '.ok == true and .webView.title == "Triton WebView Navigation B"' "$out_dir/nav-current-after.json" >/dev/null

"$triton" webview events --host "$host" --port "$port" --target "$target" --platform ios --limit 10 --json >"$out_dir/nav-events.json"
jq -e '.ok == true and ([.events[] | select(.name == "navigation.changed")] | length) >= 1' "$out_dir/nav-events.json" >/dev/null

cat <<REPORT
iOS WebView harness verification passed
output: $out_dir
simulator: $simulator
REPORT
