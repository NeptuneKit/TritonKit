#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
triton="${TRITON_BIN:-$root/.build/debug/triton}"
host="${TRITON_HOST:-127.0.0.1}"
port="${TRITON_PORT:-19431}"
out_dir="${TRITON_VERIFY_OUT_DIR:-/tmp/triton-intent-cli-smoke}"

mkdir -p "$out_dir"

if [[ ! -x "$triton" ]]; then
  echo "missing triton binary: $triton" >&2
  echo "run: swift build --product triton" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "missing jq" >&2
  exit 1
fi

if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "port $port is already listening; choose another TRITON_PORT" >&2
  exit 1
fi

python3 - "$host" "$port" "$out_dir/mock-requests.ndjson" <<'PY' &
import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

host = sys.argv[1]
port = int(sys.argv[2])
log_path = sys.argv[3]

ax_nodes = [
    {
        "role": "button",
        "label": "HTTP",
        "value": None,
        "identifier": "protocol.http",
        "title": None,
        "frame": {"x": 20, "y": 40, "width": 120, "height": 36},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 42,
        "viewOID": 42,
        "className": "UISegmentedControl",
        "children": [],
    },
    {
        "role": "textField",
        "label": "名称",
        "value": "",
        "identifier": None,
        "title": None,
        "frame": {"x": 116, "y": 203, "width": 254, "height": 34},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 77,
        "viewOID": 77,
        "className": "UITextField",
        "children": [],
    },
    {
        "role": "textField",
        "label": "协议",
        "value": "HTTPS",
        "identifier": None,
        "title": None,
        "frame": {"x": 116, "y": 483, "width": 254, "height": 34},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 88,
        "viewOID": 88,
        "className": "UITextField",
        "children": [],
    }
]

hierarchy = {
    "displayItems": [
        {
            "viewObject": {"oid": 201, "classChainList": ["HiddenCell"]},
            "layerObject": {"oid": 202, "classChainList": ["CALayer"]},
            "frame": {"x": 116, "y": 483, "width": 254, "height": 37},
            "isHidden": True,
            "alpha": 0,
            "subitems": [
                {
                    "viewObject": {"oid": 203, "classChainList": ["UISegmentLabel"]},
                    "layerObject": {"oid": 204, "classChainList": ["CALayer"]},
                    "frame": {"x": 281, "y": 492, "width": 51, "height": 19},
                    "isHidden": False,
                    "alpha": 1,
                    "subitems": [],
                }
            ],
        },
        {
            "viewObject": {"oid": 301, "classChainList": ["VisibleCell"]},
            "layerObject": {"oid": 302, "classChainList": ["CALayer"]},
            "frame": {"x": 116, "y": 321, "width": 254, "height": 37},
            "isHidden": False,
            "alpha": 1,
            "subitems": [
                {
                    "viewObject": {"oid": 303, "classChainList": ["UISegmentLabel"]},
                    "layerObject": {"oid": 304, "classChainList": ["CALayer"]},
                    "frame": {"x": 281, "y": 330, "width": 51, "height": 19},
                    "isHidden": False,
                    "alpha": 1,
                    "subitems": [],
                }
            ],
        },
    ]
}
attribute_groups_by_layer = {
    204: [{"identifier": "view", "userCustomTitle": None, "attrSections": [{"identifier": "main", "attributes": [{"identifier": "text", "displayTitle": "Text", "attrType": 0, "value": "HTTPS", "extraValue": None, "customSetterID": None}]}]}],
    304: [{"identifier": "view", "userCustomTitle": None, "attrSections": [{"identifier": "main", "attributes": [{"identifier": "text", "displayTitle": "Text", "attrType": 0, "value": "HTTPS", "extraValue": None, "customSetterID": None}]}]}],
}
input_result = {
    "ok": True,
    "action": "tap",
    "message": "mock tap dispatched",
    "targetOID": 42,
    "targetClassName": "UISegmentedControl",
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def send_json(self, status, payload):
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/targets":
            self.send_json(200, {
                "targets": [{
                    "id": "triton:demo:single",
                    "transport": "local-websocket",
                    "connected": True,
                    "latestHierarchyAvailable": True,
                    "appName": "Intent Smoke",
                    "bundleIdentifier": "dev.triton.intent-smoke",
                    "deviceDescription": "Mock iPhone",
                    "osDescription": "iOS 26",
                }]
            })
            return
        self.send_json(404, {"ok": False, "error": {"code": "not_found", "message": self.path}})

    def do_POST(self):
        if self.path != "/request":
            self.send_json(404, {"ok": False, "error": {"code": "not_found", "message": self.path}})
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        request = json.loads(body.decode())
        with open(log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps(request, separators=(",", ":")) + "\n")

        request_type = request.get("type")
        if request_type == "accessibility":
            self.send_json(200, ax_nodes)
        elif request_type == "geometry":
            self.send_json(408, {
                "ok": False,
                "error": {
                    "code": "runtime_ui_interrupted",
                    "message": "Timed out waiting for runtime UI response; a system alert may be blocking the app",
                    "endpoint": "/request",
                    "hint": "Dismiss the iOS system alert, then retry.",
                },
            })
        elif request_type == "hierarchy":
            self.send_json(200, hierarchy)
        elif request_type == "allAttrGroups":
            payload = base64.b64decode(request.get("payload", ""))
            layer_oid = json.loads(payload.decode())
            self.send_json(200, attribute_groups_by_layer.get(layer_oid, []))
        elif request_type == "input":
            payload = base64.b64decode(request.get("payload", ""))
            action = json.loads(payload.decode())
            if action.get("type") == "tap" and action.get("targetOID") == 42:
                self.send_json(200, input_result)
            elif action.get("type") == "tap" and action.get("x") == 243 and action.get("y") == 220:
                self.send_json(200, {
                    "ok": True,
                    "action": "tap",
                    "message": "mock text field focused",
                    "targetOID": 77,
                    "targetClassName": "UITextField",
                })
            elif action.get("type") == "tap" and action.get("x") == 306.5 and abs(action.get("y", 0) - 339.5) < 1:
                self.send_json(200, {
                    "ok": True,
                    "action": "tap",
                    "message": "mock segment selected",
                    "targetOID": 99,
                    "targetClassName": "UISegmentedControl",
                })
            else:
                self.send_json(422, {"ok": False, "action": "tap", "message": "unexpected input"})
        else:
            self.send_json(400, {"ok": False, "error": {"code": "unsupported", "message": str(request_type)}})


ThreadingHTTPServer((host, port), Handler).serve_forever()
PY
server_pid=$!
trap 'kill "$server_pid" >/dev/null 2>&1 || true' EXIT

for _ in {1..50}; do
  if "$triton" list --host "$host" --port "$port" --json > "$out_dir/list.json" 2>"$out_dir/list.err"; then
    break
  fi
  sleep 0.1
done

jq -e '(.targets | length) == 1 and .targets[0].id == "triton:demo:single"' "$out_dir/list.json" >/dev/null

"$triton" tap "HTTP" --host "$host" --port "$port" --json > "$out_dir/tap-http-omitted-target.json"
jq -e '.ok == true and .targetOID == 42 and .targetClassName == "UISegmentedControl"' "$out_dir/tap-http-omitted-target.json" >/dev/null

"$triton" find "名称" --host "$host" --port "$port" --json > "$out_dir/find-name-text-field.json"
jq -e '.role == "textField" and .strategy == "coordinate" and .request.x == 243 and .request.y == 220' "$out_dir/find-name-text-field.json" >/dev/null
"$triton" tap "名称" --host "$host" --port "$port" --json > "$out_dir/tap-name-text-field.json"
jq -e '.ok == true and .targetClassName == "UITextField"' "$out_dir/tap-name-text-field.json" >/dev/null

"$triton" find "HTTPS" --host "$host" --port "$port" --json > "$out_dir/find-https-visible-hierarchy.json"
jq -e '.source == "hierarchy-text" and .strategy == "coordinate" and .frame.y == 330 and .request.y < 350' "$out_dir/find-https-visible-hierarchy.json" >/dev/null
"$triton" tap "HTTPS" --host "$host" --port "$port" --json > "$out_dir/tap-https-visible-hierarchy.json"
jq -e '.ok == true and .targetClassName == "UISegmentedControl"' "$out_dir/tap-https-visible-hierarchy.json" >/dev/null

set +e
"$triton" tap "Missing Label" --host "$host" --port "$port" --json > "$out_dir/tap-missing-label.json" 2>&1
missing_code=$?
set -e
if [[ "$missing_code" -eq 0 ]]; then
  echo 'tap "Missing Label" should fail' >&2
  exit 1
fi
grep -q 'No tappable UI target matched query: Missing Label' "$out_dir/tap-missing-label.json"
jq -e '.ok == false and .error.code == "request_failed"' "$out_dir/tap-missing-label.json" >/dev/null

set +e
"$triton" geometry --host "$host" --port "$port" --json > "$out_dir/geometry-interrupted.json" 2>&1
geometry_code=$?
set -e
if [[ "$geometry_code" -eq 0 ]]; then
  echo "geometry should fail with runtime_ui_interrupted" >&2
  exit 1
fi
jq -e '.ok == false and .error.code == "runtime_ui_interrupted"' "$out_dir/geometry-interrupted.json" >/dev/null

jq -s -e '
  any(.[]; .type == "input"
    and ((.payload | @base64d | fromjson).type == "tap")
    and ((.payload | @base64d | fromjson).targetOID == 42)
  )
' "$out_dir/mock-requests.ndjson" >/dev/null

cat <<REPORT
intent-first CLI smoke passed
list: $out_dir/list.json
tap-http-omitted-target: $out_dir/tap-http-omitted-target.json
find-name-text-field: $out_dir/find-name-text-field.json
find-https-visible-hierarchy: $out_dir/find-https-visible-hierarchy.json
tap-missing-label: $out_dir/tap-missing-label.json
geometry-interrupted: $out_dir/geometry-interrupted.json
requests: $out_dir/mock-requests.ndjson
REPORT
