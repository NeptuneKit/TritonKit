#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
triton="${TRITON_BIN:-$repo_root/.build/cli/debug/triton}"
out_dir="${TRITON_VERIFY_OUT_DIR:-$repo_root/.build/ios-demo-e2e-smoke}"
host="${TRITON_HOST:-127.0.0.1}"
port="${TRITON_PORT:-19421}"
bundle_id="${TRITON_IOS_DEMO_BUNDLE_ID:-com.neptunekit.tritonkit.demo}"
project="${TRITON_IOS_DEMO_PROJECT:-Examples/TritonKitDemo/TritonKitDemo.xcodeproj}"
scheme="${TRITON_IOS_DEMO_SCHEME:-TritonKitDemo}"
configuration="${TRITON_IOS_DEMO_CONFIGURATION:-Debug}"
derived_data="${TRITON_IOS_DEMO_DERIVED_DATA:-.triton/DerivedData/ios-demo-e2e-smoke}"
runs_dir="$out_dir/workspace-runs"
run_id="${TRITON_IOS_DEMO_RUN_ID:-ios-demo-e2e}"

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

server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

capture_triton() {
  local output="$1"
  shift
  set +e
  "$triton" "$@" > "$output"
  local code=$?
  set -e
  printf '%s\n' "$code" > "${output%.json}.exit"
  return "$code"
}

capture_triton "$out_dir/status-before-serve.json" status --host "$host" --port "$port" --json || true
capture_triton "$out_dir/doctor-before-serve.json" doctor --host "$host" --port "$port" --json || true
"$triton" capabilities --host "$host" --port "$port" --json > "$out_dir/capabilities-before-serve.json"
"$triton" schema --command workspace --json > "$out_dir/schema-workspace.json"
"$triton" schema --command app --json > "$out_dir/schema-app.json"
"$triton" plan ios-smoke --platform ios --device booted --bundle-id "$bundle_id" --text "TritonKit Demo" --evidence "$out_dir/demo.tritonevidence" --json > "$out_dir/plan-ios-smoke.json"

if ! jq -e '.ok == true and .serverReachable == true' "$out_dir/status-before-serve.json" >/dev/null 2>&1; then
  "$triton" serve --host "$host" --port "$port" > "$out_dir/serve.log" 2>&1 &
  server_pid=$!
  for _ in {1..80}; do
    if "$triton" status --host "$host" --port "$port" --json > "$out_dir/status-wait-serve.json" 2>/dev/null &&
      jq -e '.ok == true and .serverReachable == true' "$out_dir/status-wait-serve.json" >/dev/null; then
      break
    fi
    sleep 0.25
  done
fi

capture_triton "$out_dir/status-after-serve.json" status --host "$host" --port "$port" --json
capture_triton "$out_dir/doctor-after-serve.json" doctor --host "$host" --port "$port" --json
"$triton" capabilities --host "$host" --port "$port" --json > "$out_dir/capabilities-after-serve.json"
jq -e '.ok == true and .serverReachable == true' "$out_dir/status-after-serve.json" >/dev/null

simulator="${TRITON_IOS_DEMO_SIMULATOR:-}"
if [[ -n "$simulator" ]]; then
  simulator="${simulator#sim:}"
  "$triton" target resolve "sim:$simulator" --platform ios --scope simulator --json > "$out_dir/target-resolve-selected.json"
else
  set +e
  "$triton" target resolve booted --platform ios --scope simulator --json > "$out_dir/target-resolve-booted.json"
  resolve_code=$?
  set -e
  if [[ "$resolve_code" -ne 0 ]]; then
    if jq -e '.error.code == "ambiguous_target"' "$out_dir/target-resolve-booted.json" >/dev/null 2>&1; then
      echo "multiple booted iOS simulators; set TRITON_IOS_DEMO_SIMULATOR=<udid>" >&2
      jq -r '.candidates[]? | "\(.target) \(.name) \(.runtime)"' "$out_dir/target-resolve-booted.json" >&2
      exit 2
    fi
    cat "$out_dir/target-resolve-booted.json" >&2
    exit "$resolve_code"
  fi
  simulator="$(jq -r '.selection.target.target' "$out_dir/target-resolve-booted.json")"
  cp "$out_dir/target-resolve-booted.json" "$out_dir/target-resolve-selected.json"
fi

target_id="triton:ios-simulator:${simulator}/app:${bundle_id}"

set +e
"$triton" app terminate --platform ios --scope simulator --device "sim:$simulator" --bundle-id "$bundle_id" --json > "$out_dir/app-terminate-before-run.json"
printf '%s\n' "$?" > "$out_dir/app-terminate-before-run.exit"
set -e

"$triton" xcode run \
  --project "$project" \
  --scheme "$scheme" \
  --configuration "$configuration" \
  --sdk iphonesimulator \
  --simulator "$simulator" \
  --derived-data-path "$derived_data" \
  --env "TRITON_HOST=$host" \
  --env "TRITON_PORT=$port" \
  --timeout 600 \
  --jsonl > "$out_dir/xcode-run-demo.jsonl"

for _ in {1..80}; do
  "$triton" list --host "$host" --port "$port" --json > "$out_dir/targets-after-demo-launch.json"
  if jq -e --arg target "$target_id" '.targets[]? | select(.id == $target and .connected == true)' "$out_dir/targets-after-demo-launch.json" >/dev/null; then
    break
  fi
  sleep 0.25
done
jq -e --arg target "$target_id" '.targets[]? | select(.id == $target and .connected == true)' "$out_dir/targets-after-demo-launch.json" >/dev/null

"$triton" observe current --host "$host" --port "$port" --target "$target_id" --json > "$out_dir/observe-current-initial.json"
jq -e --arg target "$target_id" '.ok == true and .target == $target and ([.nodes[]? | select(.text == "Complex harness: 0")] | length) >= 1' "$out_dir/observe-current-initial.json" >/dev/null

"$triton" screenshot --host "$host" --port "$port" --target "$target_id" --output "$out_dir/screenshot-before-action.png" --json > "$out_dir/screenshot-before-action.json"
test -s "$out_dir/screenshot-before-action.png"

"$triton" act find Primary --host "$host" --port "$port" --target "$target_id" --json > "$out_dir/find-primary-before-action.json"
jq -e '.query == "Primary" and .request.type == "tap"' "$out_dir/find-primary-before-action.json" >/dev/null

"$triton" act tap Primary --host "$host" --port "$port" --target "$target_id" --json > "$out_dir/tap-primary.json"
jq -e '.ok == true and .targetClassName == "UIButton"' "$out_dir/tap-primary.json" >/dev/null

"$triton" wait --text "Complex harness: 1" --host "$host" --port "$port" --target "$target_id" --timeout 5 --interval 0.25 --json > "$out_dir/wait-complex-harness-1.json"
jq -e '.ok == true and .matched == true' "$out_dir/wait-complex-harness-1.json" >/dev/null

"$triton" observe current --host "$host" --port "$port" --target "$target_id" --json > "$out_dir/observe-current-after-action.json"
jq -e '([.nodes[]? | select(.text == "Complex harness: 1")] | length) >= 1' "$out_dir/observe-current-after-action.json" >/dev/null

"$triton" screenshot --host "$host" --port "$port" --target "$target_id" --output "$out_dir/screenshot-after-action.png" --json > "$out_dir/screenshot-after-action.json"
test -s "$out_dir/screenshot-after-action.png"

"$triton" evidence capture \
  --case ios-demo-e2e-smoke \
  --output "$out_dir/demo.tritonevidence" \
  --target "$target_id" \
  --host "$host" \
  --port "$port" \
  --include status,list,version,hierarchy,ax,screenshot,geometry,archive \
  --note "iOS Demo end-to-end smoke after Primary action reached Complex harness: 1" \
  --json > "$out_dir/evidence-capture-demo.json"
jq -e '.ok == true and (.artifacts | length) >= 8' "$out_dir/evidence-capture-demo.json" >/dev/null

"$triton" evidence summary "$out_dir/demo.tritonevidence" --json > "$out_dir/evidence-summary-demo.json"

"$triton" workspace run \
  --target "sim:$simulator" \
  --platform ios \
  --scope simulator \
  --resolve-target \
  --app "$bundle_id" \
  --goal "Verify iOS Demo runtime and Atlas map" \
  --runs-dir "$runs_dir" \
  --run-id "$run_id" \
  --app-mode launch \
  --bundle-id "$bundle_id" \
  --observe-live \
  --observe-kind current \
  --business-ready-text Primary \
  --business-ready-assert \
  --llm-provider mock \
  --vlm-provider mock \
  --json > "$out_dir/workspace-run-ios-demo.json"
jq -e '.status == "passed" and .target.resolved == true' "$out_dir/workspace-run-ios-demo.json" >/dev/null
test -s "$runs_dir/$run_id/atlas/app-map/app-map.json"

"$triton" workspace inspect "$run_id" --runs-dir "$runs_dir" --json > "$out_dir/workspace-inspect-ios-demo.json"

cat <<REPORT
ios demo e2e smoke passed
out-dir: $out_dir
target: $target_id
evidence: $out_dir/demo.tritonevidence
workspace-run: $runs_dir/$run_id
REPORT
