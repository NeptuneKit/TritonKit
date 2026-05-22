#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
triton="${TRITON_BIN:-$repo_root/.build/cli/debug/triton}"
out_dir="${1:-$repo_root/.build/harmony-host-smoke}"
target="127.0.0.1:10100"

mkdir -p "$out_dir"

fake_hdc="$out_dir/fake-hdc.sh"
fake_calls="$out_dir/hdc-calls.log"
cat > "$fake_hdc" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${TRITON_FAKE_HDC_CALLS:?}"

target="127.0.0.1:10100"

if [[ "$*" == "-v" ]]; then
  echo "hdc 6.0.0"
  exit 0
fi

if [[ "$*" == "list targets -v" ]]; then
  echo "$target TCP Connected localhost"
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "install" && "${4:-}" == "-r" ]]; then
  echo "Install successfully"
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "shell" && "${4:-}" == "bm" && "${5:-}" == "dump" && "${6:-}" == "-n" ]]; then
  echo "bundleName: ${7:-com.example.demo}"
  echo "appIndex: 0"
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "shell" && "${4:-}" == "aa" && "${5:-}" == "start" ]]; then
  echo "start ability successfully."
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "shell" && "${4:-}" == "aa" && "${5:-}" == "force-stop" ]]; then
  echo "force-stop successfully."
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "shell" && "${4:-}" == "uitest" && "${5:-}" == "dumpLayout" ]]; then
  echo "DumpLayout saved to:/data/local/tmp/triton-layout.json"
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "file" && "${4:-}" == "recv" ]]; then
  remote_path="${5:-}"
  local_path="${6:-}"
  mkdir -p "$(dirname "$local_path")"
  if [[ "$remote_path" == *"layout"* ]]; then
    cat > "$local_path" <<'JSON'
{
  "attributes": { "text": "root", "bounds": "[0,0][390,844]" },
  "children": [
    {
      "attributes": {
        "text": "登录",
        "type": "Button",
        "bounds": "[100,100][300,180]"
      }
    },
    {
      "attributes": {
        "text": "欢迎",
        "type": "Text",
        "bounds": "[20,220][160,260]"
      }
    },
    {
      "attributes": {
        "text": "resource:/RAWFILE/index.html",
        "type": "Web",
        "bounds": "[0,300][390,844]",
        "visible": "true"
      }
    }
  ]
}
JSON
  else
    printf 'fake-jpeg' > "$local_path"
  fi
  echo "FileTransfer finish"
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "shell" && "${4:-}" == "uitest" && "${5:-}" == "uiInput" && "${6:-}" == "click" ]]; then
  echo "click successfully."
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "$target" && "${3:-}" == "shell" && "${4:-}" == "snapshot_display" && "${5:-}" == "-f" ]]; then
  echo "snapshot successfully."
  exit 0
fi

echo "unsupported fake hdc invocation: $*" >&2
exit 2
SH
chmod +x "$fake_hdc"
: > "$fake_calls"

export TRITON_FAKE_HDC_CALLS="$fake_calls"

"$triton" schema --command app --json > "$out_dir/schema-app.json"
jq -e '.commands[0].providedCapabilities | index("harmony-app-install") and index("harmony-app-open-url")' "$out_dir/schema-app.json" >/dev/null

"$triton" schema --command ax --json > "$out_dir/schema-ax.json"
jq -e '.commands[0].providedCapabilities | index("harmony-ax")' "$out_dir/schema-ax.json" >/dev/null

"$triton" schema --command wait --json > "$out_dir/schema-wait.json"
jq -e '.commands[0].providedCapabilities | index("harmony-wait-text")' "$out_dir/schema-wait.json" >/dev/null

"$triton" schema --command tap --json > "$out_dir/schema-tap.json"
jq -e '.commands[0].providedCapabilities | index("harmony-tap-text")' "$out_dir/schema-tap.json" >/dev/null

"$triton" schema --command screenshot --json > "$out_dir/schema-screenshot.json"
jq -e '.commands[0].providedCapabilities | index("harmony-screenshot")' "$out_dir/schema-screenshot.json" >/dev/null

"$triton" schema --command observe --json > "$out_dir/schema-observe.json"
jq -e '.commands[0].providedCapabilities | index("observe-harmony") and index("observe-ios")' "$out_dir/schema-observe.json" >/dev/null

"$triton" schema --command node --json > "$out_dir/schema-node.json"
jq -e '.commands[0].providedCapabilities | index("node-resolve")' "$out_dir/schema-node.json" >/dev/null

"$triton" app inspect --platform harmony --bundle com.example.demo --target "$target" --hdc "$fake_hdc" --json > "$out_dir/app-inspect.json"
jq -e '.ok == true and .runtimeScope == "host-harmony" and .target == "harmony:127.0.0.1:10100/app:com.example.demo"' "$out_dir/app-inspect.json" >/dev/null

"$triton" app install --platform harmony --hap /tmp/Demo.hap --target "$target" --hdc "$fake_hdc" --json > "$out_dir/app-install.json"
jq -e '.ok == true and .action == "app.install" and .runtimeScope == "host-harmony"' "$out_dir/app-install.json" >/dev/null

"$triton" app launch --platform harmony --bundle com.example.demo --ability EntryAbility --target "$target" --hdc "$fake_hdc" --json > "$out_dir/app-launch.json"
jq -e '.ok == true and .action == "app.launch" and .runtimeScope == "host-harmony"' "$out_dir/app-launch.json" >/dev/null

"$triton" app open-url --platform harmony --bundle com.example.demo --ability EntryAbility --target "$target" --hdc "$fake_hdc" "demo://nativejump/index" --json > "$out_dir/app-open-url.json"
jq -e '.ok == true and .action == "app.open-url" and .runtimeScope == "host-harmony"' "$out_dir/app-open-url.json" >/dev/null

"$triton" app terminate --platform harmony --bundle com.example.demo --target "$target" --hdc "$fake_hdc" --json > "$out_dir/app-terminate.json"
jq -e '.ok == true and .action == "app.terminate" and .runtimeScope == "host-harmony"' "$out_dir/app-terminate.json" >/dev/null

"$triton" ax --platform harmony --target "$target" --hdc "$fake_hdc" --output "$out_dir/layout.json" --json > "$out_dir/ax.json"
jq -e --arg artifact "$out_dir/layout.json" '.ok == true and .action == "ax" and .platform == "harmony" and .artifact == $artifact and (.sourceCommands | length == 2)' "$out_dir/ax.json" >/dev/null
jq -e '.children[0].attributes.text == "登录"' "$out_dir/layout.json" >/dev/null

"$triton" observe tree --platform harmony --target "$target" --hdc "$fake_hdc" --output "$out_dir/observe-layout.json" --json > "$out_dir/observe-tree.json"
jq -e '.ok == true and .action == "observe.tree" and .platform == "harmony" and .partial == true and (.sources[] | select(.name == "host-layout" and .available == true)) and (.sources[] | select(.name == "webview-provider" and .available == false))' "$out_dir/observe-tree.json" >/dev/null
jq -e '.nodes[] | select(.text == "登录" and .source == "host-layout" and (.capabilities | index("tap")))' "$out_dir/observe-tree.json" >/dev/null
jq -e '.nodes[] | select(.role == "Web" and .candidateOnly == true and (.missingCapabilities | index("webview.dom")))' "$out_dir/observe-tree.json" >/dev/null

"$triton" node resolve --platform harmony --target "$target" --hdc "$fake_hdc" --text "登录" --all --json > "$out_dir/node-resolve.json"
jq -e '.ok == true and .platform == "harmony" and .query == "登录" and .matchCount == 1 and .node.text == "登录" and .node.source == "host-layout" and (.candidates | length == 1)' "$out_dir/node-resolve.json" >/dev/null

"$triton" wait --platform harmony --target "$target" --hdc "$fake_hdc" --text "登录" --timeout 1 --interval 0.1 --json > "$out_dir/wait-text.json"
jq -e '.ok == true and .matched == true and .match.text == "登录" and .match.bounds.x == 100' "$out_dir/wait-text.json" >/dev/null

"$triton" wait --platform harmony --target "$target" --hdc "$fake_hdc" --gone "不存在" --timeout 1 --interval 0.1 --json > "$out_dir/wait-gone.json"
jq -e '.ok == true and .matched == true and .condition == "gone"' "$out_dir/wait-gone.json" >/dev/null

"$triton" tap "登录" --platform harmony --target "$target" --hdc "$fake_hdc" --json > "$out_dir/tap-text.json"
jq -e '.ok == true and .x == 200 and .y == 140 and .match.text == "登录"' "$out_dir/tap-text.json" >/dev/null

"$triton" tap --platform harmony --target "$target" --hdc "$fake_hdc" --at 10,20 --json > "$out_dir/tap-at.json"
jq -e '.ok == true and .x == 10 and .y == 20 and .match == null' "$out_dir/tap-at.json" >/dev/null

"$triton" screenshot --platform harmony --target "$target" --hdc "$fake_hdc" --output "$out_dir/screenshot.jpeg" --json > "$out_dir/screenshot.json"
jq -e --arg artifact "$out_dir/screenshot.jpeg" '.ok == true and .action == "screenshot" and .platform == "harmony" and .artifact == $artifact' "$out_dir/screenshot.json" >/dev/null
test -s "$out_dir/screenshot.jpeg"

if "$triton" tap --platform harmony --target "$target" --hdc "$fake_hdc" --within 0,0,10,10 "登录" --json > "$out_dir/tap-unsupported.json"; then
  echo "expected unsupported Harmony tap selector to fail" >&2
  exit 1
fi
jq -e '.ok == false and .error.code == "unsupported_capability"' "$out_dir/tap-unsupported.json" >/dev/null

if "$triton" app install --platform harmony --target "$target" --hdc "$fake_hdc" --json > "$out_dir/app-install-invalid.json"; then
  echo "expected Harmony install without --hap to fail" >&2
  exit 1
fi
jq -e '.ok == false and .error.code == "validation_failed"' "$out_dir/app-install-invalid.json" >/dev/null

grep -q -- "-t $target shell uitest uiInput click 200 140" "$fake_calls"
grep -q -- "-t $target shell snapshot_display -f" "$fake_calls"

echo "harmony host smoke ok: $out_dir"
