#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
triton="${TRITON_BIN:-$repo_root/.build/cli/debug/triton}"
out_dir="${1:-$repo_root/.build/ios-runtime-observe-smoke}"
port="${TRITON_IOS_RUNTIME_SMOKE_PORT:-28768}"
base_url="http://127.0.0.1:${port}"

mkdir -p "$out_dir"

python3 - "$port" <<'PY' &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

port = int(sys.argv[1])

snapshot = {
    "ok": True,
    "capturedAt": "2026-05-22T00:00:00Z",
    "runtime": "embedded",
    "targetConnectionState": "connected",
    "include": ["app", "scene", "route", "ax", "geometry"],
    "app": None,
    "scene": None,
    "route": None,
    "responder": None,
    "geometry": {
        "bounds": {"x": 0, "y": 0, "width": 390, "height": 844},
        "safeArea": {"top": 0, "left": 0, "bottom": 0, "right": 0},
        "scale": 3,
        "orientation": "portrait"
    },
    "ax": [
        {
            "role": "window",
            "label": None,
            "value": None,
            "identifier": None,
            "title": None,
            "frame": {"x": 0, "y": 0, "width": 390, "height": 844},
            "enabled": True,
            "focused": False,
            "hidden": False,
            "targetOID": 1,
            "viewOID": 1,
            "layerOID": None,
            "className": "UIWindow",
            "children": [
                {
                    "role": "button",
                    "label": "Submit",
                    "value": None,
                    "identifier": "submitButton",
                    "title": None,
                    "frame": {"x": 40, "y": 120, "width": 120, "height": 48},
                    "enabled": True,
                    "focused": False,
                    "hidden": False,
                    "targetOID": 2,
                    "viewOID": 2,
                    "layerOID": None,
                    "className": "UIButton",
                    "children": []
                },
                {
                    "role": "webArea",
                    "label": "Hybrid",
                    "value": None,
                    "identifier": "web",
                    "title": None,
                    "frame": {"x": 0, "y": 220, "width": 390, "height": 520},
                    "enabled": True,
                    "focused": False,
                    "hidden": False,
                    "targetOID": 3,
                    "viewOID": 3,
                    "layerOID": None,
                    "className": "WKWebView",
                    "children": []
                }
            ]
        }
    ],
    "screenshot": None,
    "artifacts": [],
    "skipped": [],
    "truncation": {"truncated": False, "reason": None, "originalCount": None, "returnedCount": None}
}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path != "/v2/runtime/snapshot":
            self.send_response(404)
            self.end_headers()
            return
        body = json.dumps(snapshot).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return

HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
server_pid=$!
trap 'kill "$server_pid" >/dev/null 2>&1 || true' EXIT

for _ in {1..50}; do
  if curl -fsS "$base_url/v2/runtime/snapshot" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

curl -fsS "$base_url/v2/runtime/snapshot" >/dev/null

"$triton" schema --command observe --json > "$out_dir/schema-observe.json"
jq -e '.commands[0].providedCapabilities | index("observe-ios")' "$out_dir/schema-observe.json" >/dev/null

"$triton" schema --command node --json > "$out_dir/schema-node.json"
jq -e '.commands[0].providedCapabilities | index("node-resolve")' "$out_dir/schema-node.json" >/dev/null

"$triton" observe current --platform ios --runtime-base-url "$base_url" --json > "$out_dir/observe-current.json"
jq -e '.ok == true and .platform == "ios" and .partial == true and (.sources[] | select(.name == "runtime-tree" and .available == true))' "$out_dir/observe-current.json" >/dev/null
jq -e '.nodes[] | select(.text == "Submit" and .identifier == "submitButton" and (.capabilities | index("tap")))' "$out_dir/observe-current.json" >/dev/null
jq -e '.nodes[] | select(.role == "webArea" and .candidateOnly == true and (.missingCapabilities | index("webview.dom")))' "$out_dir/observe-current.json" >/dev/null

"$triton" observe tree --platform ios --runtime-base-url "$base_url" --max-nodes 2 --json > "$out_dir/observe-tree.json"
jq -e '.ok == true and .platform == "ios" and (.nodes | length == 2)' "$out_dir/observe-tree.json" >/dev/null

"$triton" node resolve --platform ios --runtime-base-url "$base_url" --text Submit --all --json > "$out_dir/node-resolve.json"
jq -e '.ok == true and .platform == "ios" and .query == "Submit" and .matchCount == 1 and .node.text == "Submit" and .node.identifier == "submitButton" and (.candidates | length == 1)' "$out_dir/node-resolve.json" >/dev/null

echo "ios runtime observe smoke ok: $out_dir"
