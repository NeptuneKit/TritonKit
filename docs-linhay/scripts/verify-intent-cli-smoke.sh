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
        "role": "secureTextField",
        "label": "密码",
        "value": "",
        "identifier": None,
        "title": None,
        "frame": {"x": 116, "y": 249, "width": 254, "height": 34},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 78,
        "viewOID": 78,
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
    },
    {
        "role": "switch",
        "label": "记住我",
        "value": "0",
        "identifier": "remember.switch",
        "title": None,
        "frame": {"x": 298, "y": 522, "width": 52, "height": 32},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 89,
        "viewOID": 89,
        "className": "UISwitch",
        "children": [],
    },
    {
        "role": "button",
        "label": "hello",
        "value": None,
        "identifier": "hello.left",
        "title": None,
        "frame": {"x": 24, "y": 560, "width": 120, "height": 44},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 501,
        "viewOID": 501,
        "className": "UIButton",
        "children": [],
    },
    {
        "role": "button",
        "label": "hello",
        "value": None,
        "identifier": "hello.right",
        "title": None,
        "frame": {"x": 220, "y": 560, "width": 120, "height": 44},
        "enabled": True,
        "focused": False,
        "hidden": False,
        "targetOID": 502,
        "viewOID": 502,
        "className": "UIButton",
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
        if request_type == "runtimeManifest":
            self.send_json(200, {
                "ok": True,
                "platform": "ios",
                "runtime": "embedded",
                "transport": "embedded-websocket",
                "enabled": True,
                "sdkVersion": "mock",
                "buildConfiguration": "debug",
                "capabilities": [
                    {"name": "runtime.manifest", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "state.app", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "state.scene", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "state.route", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "state.responder", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "snapshot", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "semantic.focus", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "semantic.set-text", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "semantic.select-segment", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "semantic.set-switch", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "ledger", "supported": True, "scope": "embedded", "boundary": "app-process"},
                    {"name": "press", "supported": False, "scope": "host-side", "boundary": "simulator-host", "reason": "Host-side HID is not available in the embedded runtime"},
                ],
                "limits": {"maxSnapshotBytes": 1048576, "maxAXNodes": 800, "maxLedgerEntries": 100},
                "redaction": {
                    "secureText": "length-only",
                    "clipboard": "not-collected",
                    "network": "opt-in-only",
                    "logs": "opt-in-only",
                    "fileArtifacts": "opt-in-only",
                    "policy": None,
                },
            })
        elif request_type == "stateApp":
            self.send_json(200, {
                "ok": True,
                "capturedAt": "2026-05-21T12:00:00Z",
                "runtime": "embedded",
                "targetConnectionState": "connected",
                "app": {
                    "bundleIdentifier": "dev.triton.intent-smoke",
                    "displayName": "Intent Smoke",
                    "version": "1.0",
                    "build": "42",
                    "localeIdentifier": "en_US",
                    "preferredLanguages": ["en-US"],
                    "preferredContentSizeCategory": "UICTContentSizeCategoryM",
                    "userInterfaceStyle": "light",
                    "processUptimeSeconds": 12.5,
                    "sceneCount": 1,
                    "windowCount": 1,
                },
                "warnings": [],
                "unsupported": [],
            })
        elif request_type == "stateScene":
            window = {
                "id": "window-0",
                "isKeyWindow": True,
                "isHidden": False,
                "alpha": 1,
                "windowLevel": 0,
                "bounds": {"x": 0, "y": 0, "width": 390, "height": 844},
                "safeArea": {"top": 59, "left": 0, "bottom": 34, "right": 0},
                "rootViewControllerClass": "IntentSmoke.RootViewController",
            }
            self.send_json(200, {
                "ok": True,
                "capturedAt": "2026-05-21T12:00:00Z",
                "runtime": "embedded",
                "targetConnectionState": "connected",
                "scenes": [{
                    "id": "scene-0",
                    "activationState": "foregroundActive",
                    "interfaceOrientation": "portrait",
                    "screenBounds": {"x": 0, "y": 0, "width": 390, "height": 844},
                    "screenScale": 3,
                    "windowCount": 1,
                    "windows": [window],
                }],
                "keyWindow": window,
                "warnings": [],
                "unsupported": [],
            })
        elif request_type == "stateRoute":
            self.send_json(200, {
                "ok": True,
                "capturedAt": "2026-05-21T12:00:00Z",
                "runtime": "embedded",
                "targetConnectionState": "connected",
                "rootController": {"className": "UITabBarController", "title": None, "oid": 1},
                "visibleController": {"className": "IntentSmoke.FormViewController", "title": "Form", "oid": 2},
                "presentedStack": [],
                "navigationStack": [
                    {"className": "IntentSmoke.HomeViewController", "title": "Home", "oid": 3},
                    {"className": "IntentSmoke.FormViewController", "title": "Form", "oid": 2},
                ],
                "tab": {"selectedIndex": 1, "selectedTitle": "Form", "tabs": ["Home", "Form"]},
                "swiftUIBoundary": False,
                "warnings": [],
                "unsupported": [],
            })
        elif request_type == "stateResponder":
            self.send_json(200, {
                "ok": True,
                "capturedAt": "2026-05-21T12:00:00Z",
                "runtime": "embedded",
                "targetConnectionState": "connected",
                "firstResponder": {
                    "oid": 99,
                    "className": "UITextField",
                    "frame": {"x": 120, "y": 198, "width": 246, "height": 44},
                    "windowIndex": 0,
                    "isTextInput": True,
                    "isEditable": True,
                    "isSecureTextEntry": False,
                    "keyboardType": "default",
                    "returnKeyType": "done",
                },
                "redaction": {"secureText": "length-only", "textContent": "not-collected"},
                "warnings": [],
                "unsupported": [],
            })
        elif request_type == "runtimeSnapshot":
            self.send_json(200, {
                "ok": True,
                "capturedAt": "2026-05-21T12:00:01Z",
                "runtime": "embedded",
                "targetConnectionState": "connected",
                "include": ["app", "scene", "route", "ax", "geometry"],
                "app": {
                    "bundleIdentifier": "dev.triton.intent-smoke",
                    "displayName": "Intent Smoke",
                    "version": "1.0",
                    "build": "42",
                    "localeIdentifier": "en_US",
                    "preferredLanguages": ["en-US"],
                    "preferredContentSizeCategory": "UICTContentSizeCategoryM",
                    "userInterfaceStyle": "light",
                    "processUptimeSeconds": 12.5,
                    "sceneCount": 1,
                    "windowCount": 1,
                },
                "scene": {
                    "ok": True,
                    "capturedAt": "2026-05-21T12:00:01Z",
                    "runtime": "embedded",
                    "targetConnectionState": "connected",
                    "scenes": [],
                    "keyWindow": None,
                    "warnings": [],
                    "unsupported": [],
                },
                "route": {
                    "ok": True,
                    "capturedAt": "2026-05-21T12:00:01Z",
                    "runtime": "embedded",
                    "targetConnectionState": "connected",
                    "rootController": {"className": "UITabBarController", "title": None, "oid": 1},
                    "visibleController": {"className": "IntentSmoke.FormViewController", "title": "Form", "oid": 2},
                    "presentedStack": [],
                    "navigationStack": [],
                    "tab": {"selectedIndex": 1, "selectedTitle": "Form", "tabs": ["Home", "Form"]},
                    "swiftUIBoundary": False,
                    "warnings": [],
                    "unsupported": [],
                },
                "geometry": {"screen": {"x": 0, "y": 0, "width": 390, "height": 844}, "windows": []},
                "ax": ax_nodes,
                "artifacts": [{"name": "ax", "capturedAt": "2026-05-21T12:00:01Z", "freshness": "fresh"}],
                "skipped": [],
                "truncation": {"truncated": False, "reason": None, "originalCount": None, "returnedCount": None},
            })
        elif request_type == "accessibility":
            self.send_json(200, ax_nodes)
        elif request_type == "hitTest":
            payload = base64.b64decode(request.get("payload", ""))
            point = json.loads(payload.decode())
            self.send_json(200, {
                "x": point.get("x"),
                "y": point.get("y"),
                "centerX": 243,
                "centerY": 220,
                "node": ax_nodes[1],
            })
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
            elif action.get("type") == "tap" and action.get("targetOID") in (501, 502):
                self.send_json(200, {
                    "ok": True,
                    "action": "tap",
                    "message": "mock duplicate hello tapped",
                    "targetOID": action.get("targetOID"),
                    "targetClassName": "UIButton",
                })
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
            elif action.get("type") == "type" and action.get("text") == "hello":
                self.send_json(200, {
                    "ok": True,
                    "action": "type",
                    "message": "mock text inserted",
                    "targetOID": 77,
                    "targetClassName": "UIKeyInput",
                    "secure": False,
                    "redacted": False,
                    "insertedLength": 5,
                })
            elif action.get("type") == "paste" and action.get("text") == "console" and action.get("x") == 243 and action.get("y") == 220:
                self.send_json(200, {
                    "ok": True,
                    "action": "paste",
                    "message": "mock text pasted",
                    "targetOID": 77,
                    "targetClassName": "UIKeyInput",
                    "secure": False,
                    "redacted": False,
                    "insertedLength": 7,
                })
            elif action.get("type") == "clear" and action.get("x") == 243 and action.get("y") == 220:
                self.send_json(200, {
                    "ok": True,
                    "action": "clear",
                    "message": "mock text cleared",
                    "targetOID": 77,
                    "targetClassName": "UIKeyInput",
                    "insertedLength": 0,
                })
            elif action.get("type") == "button" and action.get("button") == "home":
                self.send_json(200, {
                    "ok": True,
                    "action": "button",
                    "message": "mock button dispatched",
                })
            else:
                self.send_json(422, {"ok": False, "action": "tap", "message": "unexpected input"})
        elif request_type == "semanticAction":
            payload = base64.b64decode(request.get("payload", ""))
            action = json.loads(payload.decode())
            semantic_action = action.get("action")
            secure = bool(action.get("secure", False))
            inserted_length = len(action.get("text") or "")
            response = {
                "ok": True,
                "action": semantic_action,
                "strategy": action.get("strategy") or "selector-coordinate",
                "targetOID": action.get("targetOID"),
                "targetClassName": "UITextField" if semantic_action in ("focus", "setText") else ("UISwitch" if semantic_action == "setSwitch" else "UISegmentedControl"),
                "elapsedMs": 3,
                "message": "mock semantic action dispatched",
                "error": None,
                "redaction": {
                    "secure": secure,
                    "text": "length-only" if secure else "not-collected",
                    "insertedLength": inserted_length if semantic_action == "setText" else None,
                },
            }
            self.send_json(200, response)
        elif request_type == "runtimeLedger":
            self.send_json(200, {
                "ok": True,
                "entries": [
                    {
                        "id": 3,
                        "timestamp": "2026-05-21T12:00:04Z",
                        "source": "cli",
                        "requestType": "semanticAction",
                        "action": "setText",
                        "ok": True,
                        "elapsedMs": 3,
                        "errorCode": None,
                        "message": "mock semantic action dispatched",
                        "redaction": {"secure": True, "text": "length-only", "insertedLength": 6},
                    },
                    {
                        "id": 2,
                        "timestamp": "2026-05-21T12:00:03Z",
                        "source": "cli",
                        "requestType": "runtimeSnapshot",
                        "action": None,
                        "ok": True,
                        "elapsedMs": 5,
                        "errorCode": None,
                        "message": "snapshot returned",
                        "redaction": None,
                    },
                ],
                "limit": 50,
                "count": 2,
                "maxEntries": 100,
            })
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

"$triton" runtime manifest --host "$host" --port "$port" --json > "$out_dir/runtime-manifest.json"
jq -e '.ok == true and .platform == "ios" and .runtime == "embedded" and .enabled == true and .redaction.secureText == "length-only" and (.capabilities[] | select(.name == "state.route" and .supported == true and .scope == "embedded")) and (.capabilities[] | select(.name == "press" and .supported == false and .scope == "host-side"))' "$out_dir/runtime-manifest.json" >/dev/null

"$triton" state app --host "$host" --port "$port" --json > "$out_dir/state-app.json"
jq -e '.ok == true and .app.bundleIdentifier == "dev.triton.intent-smoke" and .app.sceneCount == 1 and .app.windowCount == 1' "$out_dir/state-app.json" >/dev/null
"$triton" state scene --host "$host" --port "$port" --json > "$out_dir/state-scene.json"
jq -e '.ok == true and .scenes[0].activationState == "foregroundActive" and .keyWindow.isKeyWindow == true' "$out_dir/state-scene.json" >/dev/null
"$triton" state route --host "$host" --port "$port" --json > "$out_dir/state-route.json"
jq -e '.ok == true and .visibleController.className == "IntentSmoke.FormViewController" and .tab.selectedIndex == 1' "$out_dir/state-route.json" >/dev/null
"$triton" state responder --host "$host" --port "$port" --json > "$out_dir/state-responder.json"
jq -e '.ok == true and .firstResponder.className == "UITextField" and .firstResponder.isTextInput == true and .redaction.textContent == "not-collected"' "$out_dir/state-responder.json" >/dev/null

"$triton" snapshot --include app,scene,route,ax,geometry --host "$host" --port "$port" --json > "$out_dir/snapshot.json"
jq -e '.ok == true and .include == ["app","scene","route","ax","geometry"] and .app.bundleIdentifier == "dev.triton.intent-smoke" and (.ax | length) >= 7 and .truncation.truncated == false' "$out_dir/snapshot.json" >/dev/null

"$triton" focus "名称" --host "$host" --port "$port" --json > "$out_dir/focus-name.json"
jq -e '.ok == true and .action == "focus" and .targetClassName == "UITextField" and .strategy == "selector-coordinate"' "$out_dir/focus-name.json" >/dev/null
"$triton" set-text "名称" "alice" --host "$host" --port "$port" --json > "$out_dir/set-text-name.json"
jq -e '.ok == true and .action == "setText" and .redaction.secure == false and .redaction.insertedLength == 5' "$out_dir/set-text-name.json" >/dev/null
"$triton" set-text "密码" "secret" --secure --host "$host" --port "$port" --json > "$out_dir/set-text-password-secure.json"
jq -e '.ok == true and .action == "setText" and .redaction.secure == true and .redaction.text == "length-only" and .redaction.insertedLength == 6' "$out_dir/set-text-password-secure.json" >/dev/null
"$triton" select-segment "协议" "HTTP" --host "$host" --port "$port" --json > "$out_dir/select-segment-protocol.json"
jq -e '.ok == true and .action == "selectSegment" and .targetClassName == "UISegmentedControl"' "$out_dir/select-segment-protocol.json" >/dev/null
"$triton" set-switch "记住我" on --host "$host" --port "$port" --json > "$out_dir/set-switch-remember.json"
jq -e '.ok == true and .action == "setSwitch" and .targetClassName == "UISwitch"' "$out_dir/set-switch-remember.json" >/dev/null
"$triton" ledger --limit 50 --host "$host" --port "$port" --jsonl > "$out_dir/ledger.jsonl"
jq -s -e 'length == 2 and .[0].requestType == "semanticAction" and .[0].redaction.secure == true and .[1].requestType == "runtimeSnapshot"' "$out_dir/ledger.jsonl" >/dev/null

"$triton" tap "HTTP" --host "$host" --port "$port" > "$out_dir/tap-http-omitted-target.json"
jq -e '.ok == true and .targetOID == 42 and .targetClassName == "UISegmentedControl"' "$out_dir/tap-http-omitted-target.json" >/dev/null

"$triton" find "名称" --host "$host" --port "$port" --json > "$out_dir/find-name-text-field.json"
jq -e '.role == "textField" and .strategy == "coordinate" and .request.x == 243 and .request.y == 220' "$out_dir/find-name-text-field.json" >/dev/null
"$triton" tap "名称" --host "$host" --port "$port" > "$out_dir/tap-name-text-field.json"
jq -e '.ok == true and .targetClassName == "UITextField"' "$out_dir/tap-name-text-field.json" >/dev/null

"$triton" find "HTTPS" --host "$host" --port "$port" --json > "$out_dir/find-https-visible-hierarchy.json"
jq -e '.source == "hierarchy-text" and .strategy == "coordinate" and .frame.y == 330 and .request.y < 350' "$out_dir/find-https-visible-hierarchy.json" >/dev/null
"$triton" tap "HTTPS" --host "$host" --port "$port" > "$out_dir/tap-https-visible-hierarchy.json"
jq -e '.ok == true and .targetClassName == "UISegmentedControl"' "$out_dir/tap-https-visible-hierarchy.json" >/dev/null

"$triton" type "hello" --host "$host" --port "$port" > "$out_dir/type-positional.json"
jq -e '.ok == true and .action == "type" and .targetClassName == "UIKeyInput"' "$out_dir/type-positional.json" >/dev/null

"$triton" find "hello" --all --host "$host" --port "$port" > "$out_dir/find-hello-all.json"
jq -e '.matchCount == 2 and (.candidates | length) == 2 and .candidates[1].targetOID == 502' "$out_dir/find-hello-all.json" >/dev/null
"$triton" tap "hello" --index 2 --host "$host" --port "$port" > "$out_dir/tap-hello-index.json"
jq -e '.ok == true and .targetOID == 502 and .targetClassName == "UIButton"' "$out_dir/tap-hello-index.json" >/dev/null
"$triton" tap "hello" --within 180,0,220,700 --host "$host" --port "$port" > "$out_dir/tap-hello-within.json"
jq -e '.ok == true and .targetOID == 502 and .targetClassName == "UIButton"' "$out_dir/tap-hello-within.json" >/dev/null
"$triton" find "hello" --at 240,580 --host "$host" --port "$port" > "$out_dir/find-hello-at.json"
jq -e '.matchCount == 1 and .matchIndex == 1 and .targetOID == 502' "$out_dir/find-hello-at.json" >/dev/null
"$triton" tap "hello" --at 240,580 --host "$host" --port "$port" > "$out_dir/tap-hello-at.json"
jq -e '.ok == true and .targetOID == 502 and .targetClassName == "UIButton"' "$out_dir/tap-hello-at.json" >/dev/null
"$triton" tap --at 243,220 --host "$host" --port "$port" > "$out_dir/tap-at-coordinate.json"
jq -e '.ok == true and .targetOID == 77 and .targetClassName == "UITextField"' "$out_dir/tap-at-coordinate.json" >/dev/null
"$triton" hit --at 243,220 --host "$host" --port "$port" --json > "$out_dir/hit-at-coordinate.json"
jq -e '.x == 243 and .y == 220 and .node.targetOID == 77' "$out_dir/hit-at-coordinate.json" >/dev/null
"$triton" paste "console" --at 243,220 --host "$host" --port "$port" > "$out_dir/paste-at-coordinate.json"
jq -e '.ok == true and .action == "paste" and .targetOID == 77 and .insertedLength == 7' "$out_dir/paste-at-coordinate.json" >/dev/null
"$triton" clear --at 243,220 --host "$host" --port "$port" > "$out_dir/clear-at-coordinate.json"
jq -e '.ok == true and .action == "clear" and .targetOID == 77 and .insertedLength == 0' "$out_dir/clear-at-coordinate.json" >/dev/null
"$triton" press home --host "$host" --port "$port" > "$out_dir/press-positional.json" 2>&1
jq -e '.ok == true and .action == "button" and .message == "mock button dispatched"' "$out_dir/press-positional.json" >/dev/null

set +e
"$triton" tap "Missing Label" --host "$host" --port "$port" > "$out_dir/tap-missing-label.json" 2>&1
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

"$triton" schema --command tap > "$out_dir/schema-tap-default.json"
jq -e '.commands[0].options[] | select(.name == "--format" and .defaultValue == "json")' "$out_dir/schema-tap-default.json" >/dev/null
jq -e '.commands[0].options[] | select(.name == "--at")' "$out_dir/schema-tap-default.json" >/dev/null
"$triton" schema --command type > "$out_dir/schema-type-default.json"
jq -e '.commands[0].options[] | select(.name == "<text>")' "$out_dir/schema-type-default.json" >/dev/null
"$triton" schema --command press > "$out_dir/schema-press-positional.json"
jq -e '.commands[0].options[] | select(.name == "<button>")' "$out_dir/schema-press-positional.json" >/dev/null
"$triton" schema --command runtime > "$out_dir/schema-runtime.json"
jq -e '.commands[0].providedCapabilities[] == "runtime-manifest" and .commands[0].runtimeScope == "embedded"' "$out_dir/schema-runtime.json" >/dev/null
"$triton" schema --command state > "$out_dir/schema-state.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "state-route")) and (.commands[0].examples[] | select(. == "triton state responder --json"))' "$out_dir/schema-state.json" >/dev/null
"$triton" schema --command snapshot > "$out_dir/schema-snapshot.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "snapshot")) and (.commands[0].examples[] | select(. == "triton snapshot --include app,scene,route,ax,geometry --json"))' "$out_dir/schema-snapshot.json" >/dev/null
"$triton" schema --command focus > "$out_dir/schema-focus.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "focus")) and (.commands[0].options[] | select(.name == "<selector>"))' "$out_dir/schema-focus.json" >/dev/null
"$triton" schema --command set-text > "$out_dir/schema-set-text.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "set-text")) and (.commands[0].options[] | select(.name == "--secure"))' "$out_dir/schema-set-text.json" >/dev/null
"$triton" schema --command select-segment > "$out_dir/schema-select-segment.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "select-segment")) and (.commands[0].options[] | select(.name == "<value>"))' "$out_dir/schema-select-segment.json" >/dev/null
"$triton" schema --command set-switch > "$out_dir/schema-set-switch.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "set-switch")) and (.commands[0].options[] | select(.type == "on|off|toggle"))' "$out_dir/schema-set-switch.json" >/dev/null
"$triton" schema --command ledger > "$out_dir/schema-ledger.json"
jq -e '.commands[0].runtimeScope == "embedded" and (.commands[0].providedCapabilities[] | select(. == "ledger")) and (.commands[0].outputFormats[] | select(. == "jsonl"))' "$out_dir/schema-ledger.json" >/dev/null

jq -s -e '
  any(.[]; .type == "input"
    and ((.payload | @base64d | fromjson).type == "tap")
    and ((.payload | @base64d | fromjson).targetOID == 42)
  )
' "$out_dir/mock-requests.ndjson" >/dev/null

jq -s -e '
  any(.[]; .type == "runtimeSnapshot")
  and any(.[]; .type == "semanticAction"
    and ((.payload | @base64d | fromjson).action == "setText")
    and ((.payload | @base64d | fromjson).sourceCommand == "set-text")
    and ((.payload | @base64d | fromjson).secure == true)
  )
  and any(.[]; .type == "runtimeLedger")
' "$out_dir/mock-requests.ndjson" >/dev/null

cat <<REPORT
intent-first CLI smoke passed
list: $out_dir/list.json
runtime-manifest: $out_dir/runtime-manifest.json
state-app: $out_dir/state-app.json
state-scene: $out_dir/state-scene.json
state-route: $out_dir/state-route.json
state-responder: $out_dir/state-responder.json
snapshot: $out_dir/snapshot.json
focus-name: $out_dir/focus-name.json
set-text-name: $out_dir/set-text-name.json
set-text-password-secure: $out_dir/set-text-password-secure.json
select-segment-protocol: $out_dir/select-segment-protocol.json
set-switch-remember: $out_dir/set-switch-remember.json
ledger-jsonl: $out_dir/ledger.jsonl
tap-http-omitted-target: $out_dir/tap-http-omitted-target.json
find-name-text-field: $out_dir/find-name-text-field.json
find-https-visible-hierarchy: $out_dir/find-https-visible-hierarchy.json
tap-missing-label: $out_dir/tap-missing-label.json
geometry-interrupted: $out_dir/geometry-interrupted.json
type-positional: $out_dir/type-positional.json
find-hello-all: $out_dir/find-hello-all.json
tap-hello-index: $out_dir/tap-hello-index.json
tap-hello-within: $out_dir/tap-hello-within.json
find-hello-at: $out_dir/find-hello-at.json
tap-hello-at: $out_dir/tap-hello-at.json
tap-at-coordinate: $out_dir/tap-at-coordinate.json
hit-at-coordinate: $out_dir/hit-at-coordinate.json
paste-at-coordinate: $out_dir/paste-at-coordinate.json
clear-at-coordinate: $out_dir/clear-at-coordinate.json
press-positional: $out_dir/press-positional.json
schema-tap-default: $out_dir/schema-tap-default.json
schema-type-default: $out_dir/schema-type-default.json
schema-press-positional: $out_dir/schema-press-positional.json
schema-runtime: $out_dir/schema-runtime.json
schema-state: $out_dir/schema-state.json
schema-snapshot: $out_dir/schema-snapshot.json
schema-focus: $out_dir/schema-focus.json
schema-set-text: $out_dir/schema-set-text.json
schema-select-segment: $out_dir/schema-select-segment.json
schema-set-switch: $out_dir/schema-set-switch.json
schema-ledger: $out_dir/schema-ledger.json
requests: $out_dir/mock-requests.ndjson
REPORT
