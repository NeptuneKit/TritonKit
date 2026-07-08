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
llm_port="${TRITON_IOS_DEMO_LLM_PORT:-19429}"

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

if ! command -v python3 >/dev/null 2>&1; then
  echo "missing python3" >&2
  exit 1
fi

server_pid=""
llm_pid=""
cleanup() {
  if [[ -n "$llm_pid" ]]; then
    kill "$llm_pid" >/dev/null 2>&1 || true
  fi
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

target_id=""

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
  if jq -e --arg simulator "$simulator" --arg bundle "$bundle_id" '.targets[]? | select(.simulatorUDID == $simulator and .bundleIdentifier == $bundle and .connected == true)' "$out_dir/targets-after-demo-launch.json" >/dev/null; then
    break
  fi
  sleep 0.25
done
target_id="$(jq -r --arg simulator "$simulator" --arg bundle "$bundle_id" '.targets[]? | select(.simulatorUDID == $simulator and .bundleIdentifier == $bundle and .connected == true) | .id' "$out_dir/targets-after-demo-launch.json" | head -n 1)"
test -n "$target_id"
test "$target_id" != "null"

"$triton" observe current --host "$host" --port "$port" --target "$target_id" --json > "$out_dir/observe-current-initial.json"
jq -e --arg target "$target_id" '.ok == true and .target == $target and ([.nodes[]? | select(.text == "Complex harness: 0")] | length) >= 1' "$out_dir/observe-current-initial.json" >/dev/null

"$triton" screenshot --host "$host" --port "$port" --target "$target_id" --output "$out_dir/screenshot-before-action.png" --json > "$out_dir/screenshot-before-action.json"
test -s "$out_dir/screenshot-before-action.png"

initial_screenshot_sha="$(shasum -a 256 "$out_dir/screenshot-before-action.png" | awk '{print $1}')"
initial_observe_sha="$(shasum -a 256 "$out_dir/observe-current-initial.json" | awk '{print $1}')"
jq \
  --arg screenshot "$out_dir/screenshot-before-action.png" \
  --arg hierarchy "$out_dir/observe-current-initial.json" \
  --arg screenshotSha "$initial_screenshot_sha" \
  --arg observeSha "$initial_observe_sha" \
  '{
    schemaVersion: 1,
    kind: "triton.workspace.observation-fixture",
    artifacts: {
      screenshot: $screenshot,
      hierarchy: $hierarchy,
      ax: $hierarchy
    },
    screenCandidate: {
      screenshotSha256: $screenshotSha,
      axTextHash: $observeSha,
      hierarchySha256: $observeSha,
      visibleTexts: (reduce [.nodes[]?.text | select(type == "string" and length > 0)][] as $text ([]; if index($text) then . else . + [$text] end))
    },
    sourceCommands: ["triton observe current --json", "triton screenshot --json"],
    changed: true
  }' "$out_dir/observe-current-initial.json" > "$out_dir/workspace-initial-observation-fixture.json"
jq -e '(.screenCandidate.visibleTexts | index("Primary")) != null and (.artifacts.screenshot | length) > 0' "$out_dir/workspace-initial-observation-fixture.json" >/dev/null

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

set +e
"$triton" app terminate --platform ios --scope simulator --device "sim:$simulator" --bundle-id "$bundle_id" --json > "$out_dir/app-terminate-before-workspace.json"
printf '%s\n' "$?" > "$out_dir/app-terminate-before-workspace.exit"
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
  --jsonl > "$out_dir/xcode-run-demo-before-workspace.jsonl"

for _ in {1..80}; do
  "$triton" list --host "$host" --port "$port" --json > "$out_dir/targets-before-workspace-run.json"
  if jq -e --arg simulator "$simulator" --arg bundle "$bundle_id" '.targets[]? | select(.simulatorUDID == $simulator and .bundleIdentifier == $bundle and .connected == true)' "$out_dir/targets-before-workspace-run.json" >/dev/null; then
    break
  fi
  sleep 0.25
done
target_id="$(jq -r --arg simulator "$simulator" --arg bundle "$bundle_id" '.targets[]? | select(.simulatorUDID == $simulator and .bundleIdentifier == $bundle and .connected == true) | .id' "$out_dir/targets-before-workspace-run.json" | head -n 1)"
test -n "$target_id"
test "$target_id" != "null"
"$triton" observe current --host "$host" --port "$port" --target "$target_id" --json > "$out_dir/observe-current-before-workspace.json"
jq -e '([.nodes[]? | select(.text == "Complex harness: 0")] | length) >= 1' "$out_dir/observe-current-before-workspace.json" >/dev/null

llm_mock="$out_dir/openai-compatible-workspace-llm.py"
cat > "$llm_mock" <<'PY'
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
log_path = sys.argv[2]

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length)
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except Exception:
            payload = {"raw": body.decode("utf-8", errors="replace")}
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps({"path": self.path, "body": payload}, sort_keys=True) + "\n")
        if self.path != "/v1/chat/completions":
            self.send_response(404)
            self.end_headers()
            return
        content = json.dumps({
            "action": "tap",
            "query": "Primary",
            "confidence": 0.94,
            "summary": "Primary is the visible counter action.",
            "expected": "Primary increments Complex harness."
        }, separators=(",", ":"))
        response = {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": content
                    }
                }
            ]
        }
        data = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        return

HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
python3 "$llm_mock" "$llm_port" "$out_dir/llm-requests.jsonl" > "$out_dir/llm-mock.log" 2>&1 &
llm_pid=$!
for _ in {1..40}; do
  if curl -fsS \
    -H 'Content-Type: application/json' \
    -d '{"model":"probe","messages":[{"role":"user","content":"probe"}]}' \
    "http://127.0.0.1:$llm_port/v1/chat/completions" > "$out_dir/llm-probe.json" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
jq -e '.choices[0].message.content | contains("\"Primary\"")' "$out_dir/llm-probe.json" >/dev/null

"$triton" workspace run \
  --target "sim:$simulator" \
  --platform ios \
  --scope simulator \
  --resolve-target \
  --app "$bundle_id" \
  --goal "Verify iOS Demo runtime and Atlas map" \
  --runs-dir "$runs_dir" \
  --run-id "$run_id" \
  --app-mode attach \
  --bundle-id "$bundle_id" \
  --observation-fixture "$out_dir/workspace-initial-observation-fixture.json" \
  --observe-live \
  --observe-kind current \
  --business-ready-text "Complex harness: 1" \
  --business-ready-assert \
  --execute-actions \
  --llm-provider openai-compatible \
  --llm-base-url "http://127.0.0.1:$llm_port/v1" \
  --llm-model ios-demo-primary-action \
  --vlm-provider mock \
  --json > "$out_dir/workspace-run-ios-demo.json"
jq -e '.status == "passed" and .target.resolved == true and .business.phase == "post_action_assertion_passed"' "$out_dir/workspace-run-ios-demo.json" >/dev/null
test -s "$runs_dir/$run_id/atlas/app-map/app-map.json"
jq -e '.screenCount >= 2 and .transitionCount >= 1 and .pathCount >= 1' "$runs_dir/$run_id/atlas/app-map/app-map.json" >/dev/null
jq -e '.usedVLMGrounding == true and .proofSource == "vlm.grounding+runtime.input" and .vlmGrounding.target == "Primary"' "$runs_dir/$run_id/evidence/actions/action-000.json" >/dev/null
jq -s '([.[] | select(.type == "observation.captured")] | length) >= 2 and ([.[] | select(.type == "observation.captured")][-1].phase == "post_action")' "$runs_dir/$run_id/events.jsonl" >/dev/null

"$triton" workspace inspect "$run_id" --runs-dir "$runs_dir" --json > "$out_dir/workspace-inspect-ios-demo.json"
jq -e '.appMap.pathCount >= 1 and (.appMap.pathIds | length) >= 1' "$out_dir/workspace-inspect-ios-demo.json" >/dev/null

map_dir="$out_dir/ios-demo.tritonmap"
"$triton" workspace merge-map "$run_id" --runs-dir "$runs_dir" --map-dir "$map_dir" --confirm --json > "$out_dir/workspace-merge-map-ios-demo.json"
jq -e '.pathCount >= 1 and .transitionCount >= 1 and (.pathIds | length) >= 1' "$out_dir/workspace-merge-map-ios-demo.json" >/dev/null

"$triton" map inspect "$map_dir" --json > "$out_dir/map-inspect-ios-demo.json"
jq -e '.pathCount >= 1 and .transitionCount >= 1 and .health.passCount >= 1' "$out_dir/map-inspect-ios-demo.json" >/dev/null

"$triton" map paths "$map_dir" --json > "$out_dir/map-paths-ios-demo.json"
path_id="$(jq -r '.paths[0].pathId' "$out_dir/map-paths-ios-demo.json")"
test -n "$path_id"
test "$path_id" != "null"
jq -e '.paths[0].requiresVLM == true and any(.paths[0].suggestedCommands[]; contains("--allow-vlm"))' "$out_dir/map-paths-ios-demo.json" >/dev/null

"$triton" map path show "$map_dir" --path "$path_id" --json > "$out_dir/map-path-show-ios-demo.json"
jq -e '.path.requiresVLM == true and any(.path.suggestedCommands[]; contains("triton map export-flow")) and any(.path.suggestedCommands[]; contains("--allow-vlm"))' "$out_dir/map-path-show-ios-demo.json" >/dev/null

flow="$out_dir/ios-demo-map-flow.tritontest.yaml"
"$triton" map export-flow "$map_dir" --path "$path_id" --out "$flow" --json > "$out_dir/map-export-flow-ios-demo.json"
jq -e '.ok == true and .requiresVLM == true and any(.suggestedCommands[]; contains("triton test validate")) and any(.suggestedCommands[]; contains("--allow-vlm"))' "$out_dir/map-export-flow-ios-demo.json" >/dev/null

"$triton" test validate "$flow" --json > "$out_dir/test-validate-ios-demo-map-flow.json"
jq -e '.ok == true' "$out_dir/test-validate-ios-demo-map-flow.json" >/dev/null

cat <<REPORT
ios demo e2e smoke passed
out-dir: $out_dir
target: $target_id
evidence: $out_dir/demo.tritonevidence
workspace-run: $runs_dir/$run_id
map: $map_dir
flow: $flow
REPORT
