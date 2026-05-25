#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
triton="${TRITON_BIN:-$repo_root/.build/cli/debug/triton}"
out_dir="${1:-$repo_root/.build/harmony-runtime-base-url-smoke}"
host="127.0.0.1"
port="${TRITON_HARMONY_RUNTIME_SMOKE_PORT:-31867}"
base_url="http://$host:$port"
default_base_url="http://$host:28767"

mkdir -p "$out_dir"

fake_hdc="$out_dir/fake-hdc.sh"
cat > "$fake_hdc" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "-v" ]]; then
  echo "hdc 6.0.0"
  exit 0
fi

if [[ "$*" == "list targets -v" ]]; then
  echo "127.0.0.1:10100 TCP Connected localhost"
  exit 0
fi

if [[ "${1:-}" == "-t" && "${2:-}" == "127.0.0.1:10100" && "${3:-}" == "fport" ]]; then
  echo "Forwardport result:OK"
  exit 0
fi

echo "unsupported fake hdc invocation: $*" >&2
exit 2
SH
chmod +x "$fake_hdc"

"$triton" schema --command runtime --json > "$out_dir/schema-runtime.json"
jq -e '.commands[0].options[] | select(.name == "--runtime-base-url")' "$out_dir/schema-runtime.json" >/dev/null

"$triton" schema --command state --json > "$out_dir/schema-state.json"
jq -e '.commands[0].options[] | select(.name == "--runtime-base-url")' "$out_dir/schema-state.json" >/dev/null

"$triton" schema --command ledger --json > "$out_dir/schema-ledger.json"
jq -e '.commands[0].options[] | select(.name == "--runtime-base-url")' "$out_dir/schema-ledger.json" >/dev/null

"$triton" schema --command device --json > "$out_dir/schema-device.json"
jq -e '.commands[0].options[] | select(.name | startswith("runtime-url "))' "$out_dir/schema-device.json" >/dev/null
jq -e '.commands[0].options[] | select(.name == "runtime-url --device <selector>")' "$out_dir/schema-device.json" >/dev/null
jq -e '.commands[0].options[] | select(.name == "--local-port" and .defaultValue == "28767")' "$out_dir/schema-device.json" >/dev/null
jq -e '.commands[0].options[] | select(.name == "--remote-port" and .defaultValue == "28767")' "$out_dir/schema-device.json" >/dev/null

python3 - "$host" "$port" > "$out_dir/mock-server.log" 2>&1 <<'PY' &
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

host = sys.argv[1]
port = int(sys.argv[2])

def now():
    return "2026-05-21T12:00:00Z"

def manifest():
    return {
        "ok": True,
        "platform": "harmony",
        "runtime": "arkts-har",
        "transport": "embedded-http",
        "enabled": True,
        "sdkName": "tritonkit",
        "sdkVersion": "mock",
        "buildConfiguration": "debug",
        "serviceName": "tritonkit-harmony-smoke",
        "capabilities": [
            {"name": "runtime.manifest", "supported": True, "scope": "embedded", "boundary": "app-process"},
            {"name": "state.app", "supported": True, "scope": "embedded", "boundary": "app-process"},
            {"name": "state.route", "supported": True, "scope": "embedded", "boundary": "app-process"},
            {"name": "semantic.set-text", "supported": True, "scope": "embedded", "boundary": "app-process"},
            {"name": "ledger", "supported": True, "scope": "embedded", "boundary": "app-process"},
            {"name": "press", "supported": False, "scope": "host-side", "boundary": "simulator-host", "reason": "host-side only"},
        ],
        "limits": {
            "maxSnapshotBytes": 1048576,
            "maxAXNodes": 800,
            "maxLedgerEntries": 100,
            "maxLogRecords": 2000,
            "maxSources": 2000,
            "maxViewTreeRoots": 2000,
            "maxPayloadBytes": 1048576,
        },
        "redaction": {
            "secureText": "length-only",
            "clipboard": "not-collected",
            "network": "opt-in-only",
            "logs": "redacted",
            "fileArtifacts": "opt-in-only",
            "secureTextRedaction": "length-only",
            "logsDefaultRedacted": True,
            "requiresExplicitProviderForSensitiveData": True,
        },
        "generatedAt": now(),
    }

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        return

    def send_json(self, status, value):
        data = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        if parsed.path == "/v2/runtime/manifest":
            self.send_json(200, manifest())
            return
        if parsed.path == "/v2/runtime/state/route":
            self.send_json(200, {
                "ok": True,
                "capturedAt": now(),
                "runtime": "arkts-har",
                "provider": "mock-route-provider",
                "payload": {"currentPage": "Home", "navigationStack": ["Home"]},
            })
            return
        if parsed.path == "/v2/runtime/snapshot":
            self.send_json(200, {
                "ok": True,
                "capturedAt": now(),
                "runtime": "arkts-har",
                "include": query.get("include", [""])[0].split(","),
                "manifest": manifest(),
                "app": {"ok": True, "capturedAt": now(), "platform": "harmony", "appId": "dev.triton.harmony", "serviceName": "tritonkit-harmony-smoke", "sdkName": "tritonkit", "sdkVersion": "mock", "sourceCount": 1, "running": True},
                "route": {"ok": True, "capturedAt": now(), "runtime": "arkts-har", "provider": "mock-route-provider", "payload": {"currentPage": "Home"}},
                "responder": {"ok": False, "capturedAt": now(), "errorCode": "unsupported_runtime_scope", "message": "no responder provider", "reason": "no responder provider"},
                "health": {"status": "ok", "service": "tritonkit-harmony-smoke", "version": "mock", "startedAt": now()},
                "metrics": {"queueSize": 0, "queueCapacity": 2000, "droppedOverflow": 0, "totalIngested": 0, "totalExported": 0},
                "sources": [],
                "viewTree": {"snapshotId": "mock-view-tree", "capturedAt": now(), "platform": "harmony", "roots": []},
                "inspector": {"snapshotId": "mock-inspector", "capturedAt": now(), "platform": "harmony", "available": False, "payload": None, "reason": "mock"},
                "artifacts": [{"name": "manifest", "capturedAt": now(), "freshness": "fresh"}],
                "skipped": [{"name": "responder", "reason": "no responder provider"}],
            })
            return
        if parsed.path == "/v2/runtime/ledger":
            limit = int(query.get("limit", ["50"])[0])
            entries = [
                {"id": 1, "timestamp": now(), "source": "http", "requestType": "runtimeSnapshot", "ok": True, "elapsedMs": 1, "redaction": {"secure": False, "text": "not-collected"}},
                {"id": 2, "timestamp": now(), "source": "http", "requestType": "semantic-action", "action": "setText", "ok": True, "elapsedMs": 2, "redaction": {"secure": True, "text": "length-only", "insertedLength": 6}},
            ][:limit]
            self.send_json(200, {"ok": True, "entries": entries, "limit": limit, "count": len(entries), "maxEntries": 100})
            return
        self.send_json(404, {"ok": False, "error": {"code": "not_found", "message": parsed.path}})

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode() or "{}")
        if parsed.path == "/v2/runtime/action":
            text = body.get("text")
            secure = bool(body.get("secure", False))
            self.send_json(200, {
                "ok": True,
                "action": body.get("action", "unknown"),
                "strategy": "app-provider-selector",
                "elapsedMs": 3,
                "message": "handled by Harmony provider",
                "redaction": {
                    "secure": secure,
                    "text": "length-only" if secure else "not-collected",
                    "insertedLength": len(text) if isinstance(text, str) else None,
                },
            })
            return
        self.send_json(404, {"ok": False, "error": {"code": "not_found", "message": parsed.path}})

ThreadingHTTPServer((host, port), Handler).serve_forever()
PY
server_pid=$!
trap 'kill "$server_pid" >/dev/null 2>&1 || true' EXIT

for _ in {1..50}; do
  if "$triton" runtime manifest --runtime-base-url "$base_url" --json > "$out_dir/runtime-manifest.json" 2>"$out_dir/runtime-manifest.err"; then
    break
  fi
  sleep 0.1
done

jq -e '.ok == true and .platform == "harmony" and .runtime == "arkts-har" and (.capabilities[] | select(.name == "press" and .scope == "host-side"))' "$out_dir/runtime-manifest.json" >/dev/null

"$triton" device runtime-url --platform harmony --target 127.0.0.1:10100 --hdc "$fake_hdc" --no-forward --json > "$out_dir/runtime-url-defaults.json"
jq -e --arg base "$default_base_url" '.ok == true and .baseURL == $base and .localPort == 28767 and .remotePort == 28767 and .forwarded == false and (.manifest? == null)' "$out_dir/runtime-url-defaults.json" >/dev/null

"$triton" device runtime-url --device 127.0.0.1:10100 --hdc "$fake_hdc" --no-forward --json > "$out_dir/runtime-url-device-defaults.json"
jq -e --arg base "$default_base_url" '.ok == true and .baseURL == $base and .localPort == 28767 and .remotePort == 28767 and .forwarded == false and (.manifest? == null)' "$out_dir/runtime-url-device-defaults.json" >/dev/null

"$triton" device runtime-url --platform harmony --target 127.0.0.1:10100 --hdc "$fake_hdc" --local-port "$port" --remote-port "$port" --probe-manifest --json > "$out_dir/runtime-url.json"
jq -e --arg base "$base_url" '.ok == true and .baseURL == $base and .forwarded == true and .manifest.platform == "harmony"' "$out_dir/runtime-url.json" >/dev/null

"$triton" state route --runtime-base-url "$base_url" --json > "$out_dir/state-route.json"
jq -e '.ok == true and .provider == "mock-route-provider" and .payload.currentPage == "Home"' "$out_dir/state-route.json" >/dev/null

"$triton" snapshot --runtime-base-url "$base_url" --include app,route --json > "$out_dir/snapshot.json"
jq -e '.ok == true and .runtime == "arkts-har" and (.include[] | select(. == "route"))' "$out_dir/snapshot.json" >/dev/null

"$triton" ledger --runtime-base-url "$base_url" --limit 2 --jsonl > "$out_dir/ledger.jsonl"
jq -s -e 'length == 2 and .[1].requestType == "semantic-action" and .[1].redaction.text == "length-only"' "$out_dir/ledger.jsonl" >/dev/null

"$triton" set-text "密码" "secret" --secure --runtime-base-url "$base_url" --json > "$out_dir/set-text.json"
jq -e '.ok == true and .action == "setText" and .strategy == "app-provider-selector" and .redaction.secure == true and .redaction.insertedLength == 6' "$out_dir/set-text.json" >/dev/null

echo "harmony runtime base-url smoke ok: $out_dir"
