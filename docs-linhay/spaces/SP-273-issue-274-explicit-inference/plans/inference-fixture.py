#!/usr/bin/env python3
"""Isolated real-process inference acceptance. No devices, downloads, or remote API.

--baseline runs only old CLI syntax and records the prior implicit-enable behavior.
--http additionally starts an owned loopback triton serve: requires controller slot.
Output must be fresh. Every failure and watchdog result remains in report.json.
"""
import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


class FakeAPI:
    def __init__(self):
        self.requests = []
        self.mode = "success"
        self.stop = threading.Event()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *args):
                pass

            def do_POST(self):
                raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                try:
                    body = json.loads(raw)
                except ValueError:
                    body = {}
                owner.requests.append({"path": self.path, "model": body.get("model"),
                                       "mode": owner.mode, "at": time.monotonic(),
                                       "authorizationPresent": bool(self.headers.get("Authorization"))})
                if owner.mode == "disconnect":
                    self.close_connection = True
                    self.connection.shutdown(socket.SHUT_RDWR)
                    self.connection.close()
                    return
                if owner.mode == "slow":
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", "1000000")
                    self.end_headers()
                    try:
                        # Continual bytes distinguish a total budget from an idle timeout.
                        while not owner.stop.wait(0.5):
                            self.wfile.write(b" ")
                            self.wfile.flush()
                    except (BrokenPipeError, ConnectionResetError, OSError):
                        pass
                    self.close_connection = True
                    return
                if owner.mode == "unauthorized":
                    data = b'{"error":{"message":"fixture unauthorized","type":"authentication_error"}}'
                    code = 401
                else:
                    decision = {"action": "tap", "query": "Begin", "confidence": 0.9,
                                "summary": "Synthetic fixture decision", "expected": "Begin is visible"}
                    data = json.dumps({"choices": [{"message": {"role": "assistant",
                                               "content": json.dumps(decision)}}]}).encode()
                    code = 200
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = "http://127.0.0.1:%s/v1" % self.server.server_port

    def close(self):
        self.stop.set()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)


def stop_owned(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=3)


def http_request(port, method, path, body=None, timeout=45):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    try:
        connection.request(method, path, json.dumps(body) if body is not None else None,
                           {"Content-Type": "application/json"})
        response = connection.getresponse()
        return response.status, response.read().decode()
    finally:
        connection.close()


def codes(value):
    if isinstance(value, dict):
        return ([value["code"]] if isinstance(value.get("code"), str) else []) + [
            c for item in value.values() for c in codes(item)]
    if isinstance(value, list):
        return [c for item in value for c in codes(item)]
    return []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--http", action="store_true", help="Start owned triton serve; controller slot required")
    args = parser.parse_args()
    if args.baseline and args.http:
        parser.error("baseline is CLI-only; do not start serve")
    binary = args.binary.resolve(strict=True)
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    fakebin = root / "fake-bin"
    fakebin.mkdir()
    marker = root / "backend-invocations.txt"
    for name in ["llama-server", "ollama", "triton-mlx-provider", "xcrun", "adb", "hdc"]:
        path = fakebin / name
        path.write_text('#!/bin/sh\nprintf "%s\t%s\t%s\\n" "$SP273_CONTEXT" "${0##*/}" "$*" >> "$SP273_MARKER"\nexit 97\n')
        path.chmod(0o755)
    # Do not inherit API credentials/provider overrides. Keep the user's HOME unchanged.
    env = {k: os.environ[k] for k in ["HOME", "TMPDIR", "LANG", "LC_ALL"] if k in os.environ}
    env.update(PATH=str(fakebin) + ":/usr/bin:/bin:/usr/sbin:/sbin",
               SP273_MARKER=str(marker), SP273_CONTEXT="cli", TRITON_MLX_HELPER=str(fakebin / "triton-mlx-provider"),
               TRITON_ADVERTISE="false", SP273_API_KEY="synthetic-fixture-key")
    report = {"binary": str(binary), "binarySHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
              "baseline": args.baseline, "httpRequested": args.http, "cases": [],
              "limits": ["Markers cover only configured executable/PATH entrypoints, not every host process.",
                         "Dry workspace fixture: no device action, live observation, model download, or business acceptance.",
                         "Fake OpenAI is loopback only; no actual model or remote API is called."], "cleanup": {}}
    api = FakeAPI()
    serve = None
    serve_log = None
    try:
        version = subprocess.run([str(binary), "--version"], cwd=root, env=env, capture_output=True, text=True, timeout=15)
        report["version"] = version.stdout.strip()
        # First controls have no opt-in, even though one supplies complete configuration.
        cases = [("defaults", "success", False, False, False),
                 ("configured-disabled", "success", True, False, False)]
        if not args.baseline:
            cases += [("enabled-llm", "success", True, True, False),
                      ("enabled-both", "success", True, True, True),
                      ("enabled-vlm-mock", "success", False, False, True),
                      ("unauthorized", "unauthorized", True, True, False),
                      ("disconnect", "disconnect", True, True, False),
                      ("slow-drip", "slow", True, True, False)]
        transports = ["cli"]
        port = None
        if args.http:
            with socket.socket() as reservation:
                reservation.bind(("127.0.0.1", 0))
                port = reservation.getsockname()[1]
            serve_log = (root / "serve.log").open("wb")
            serve = subprocess.Popen([str(binary), "serve", "--host", "127.0.0.1", "--port", str(port), "--no-advertise"],
                                     cwd=root, env={**env, "SP273_CONTEXT": "serve"}, stdout=serve_log, stderr=subprocess.STDOUT, start_new_session=True)
            report["serve"] = {"pid": serve.pid, "port": port}
            until = time.monotonic() + 15
            while True:
                if serve.poll() is not None:
                    raise RuntimeError("Owned serve exited before ready; inspect serve.log")
                try:
                    if http_request(port, "GET", "/health", timeout=0.5)[0] == 200:
                        break
                except (OSError, http.client.HTTPException):
                    pass
                if time.monotonic() > until:
                    raise RuntimeError("Owned serve readiness exceeded 15 seconds")
                time.sleep(0.1)
            transports.append("http")
        for transport in transports:
            for name, mode, configured, llm, vlm in cases:
                case_dir = root / (transport + "-" + name)
                case_dir.mkdir()
                api.mode = mode
                before = len(api.requests)
                api.stop.clear()
                body = {"app": "com.example.sp273.fixture", "goal": "Inspect Begin", "target": "fixture-no-device",
                        "appMode": "dry", "runsDir": str(case_dir / "runs"), "runID": "fixture",
                        "maxSteps": 1, "observeLive": False, "executeActions": False, "resolveTarget": False}
                argv = [str(binary), "workspace", "run", "--app", body["app"], "--goal", body["goal"],
                        "--target", body["target"], "--app-mode", "dry", "--runs-dir", body["runsDir"],
                        "--run-id", "fixture", "--max-steps", "1", "--json"]
                if configured:
                    body.update(llmProvider="openai-compatible", llmBaseURL=api.base,
                                llmModel="fixture", llmAPIKeyEnv="SP273_API_KEY", vlmProvider="mock")
                    argv += ["--llm-provider", "openai-compatible", "--llm-base-url", api.base,
                             "--llm-model", "fixture", "--llm-api-key-env", "SP273_API_KEY", "--vlm-provider", "mock"]
                if not args.baseline:
                    body.update(enableLLM=llm, enableVLM=vlm)
                    if llm:
                        argv.append("--enable-llm")
                    if vlm:
                        argv.append("--enable-vlm")
                started = time.monotonic()
                item = {"name": name, "transport": transport, "mode": mode, "request": body, "argv": argv}
                process = None
                raw = stderr = ""
                try:
                    if transport == "cli":
                        process = subprocess.Popen(argv, cwd=root, env=env, stdout=subprocess.PIPE,
                                                   stderr=subprocess.PIPE, text=True, start_new_session=True)
                        raw, stderr = process.communicate(timeout=45)
                        item["exitCode"] = process.returncode
                    else:
                        item["httpStatus"], raw = http_request(port, "POST", "/workspace/run", body)
                    item["response"] = json.loads(raw)
                except Exception as error:
                    item["fixtureError"] = str(error)
                    if process is not None:
                        stop_owned(process)
                        raw, stderr = process.communicate()
                    if transport == "http":
                        # A watchdog is a fixture failure; do not leave work running or run more cases.
                        stop_owned(serve)
                finally:
                    item["elapsedSeconds"] = time.monotonic() - started
                    api.stop.set()
                    item["requests"] = api.requests[before:]
                    (case_dir / "stdout.json").write_text(raw)
                    (case_dir / "stderr.txt").write_text(stderr)
                response = item.get("response", {})
                ai = response.get("ai", {})
                expected_requests = 1 if configured and (args.baseline or llm) else 0
                checks = {"validJSON": "response" in item, "within45Seconds": item["elapsedSeconds"] < 45,
                          "noLocalModelHelper": not any(n in (marker.read_text() if marker.exists() else "").split() for n in ["llama-server", "ollama", "triton-mlx-provider"]),
                          "onlyBlockedServeDiscovery": all(line in ["serve\tadb\tdevices -l", "serve\thdc\tlist targets -v", "serve\thdc\tlist targets"] for line in (marker.read_text().splitlines() if marker.exists() else [])),
                          "requestCount": len(item["requests"]) == expected_requests,
                          "onlyConfiguredEndpoint": all(r["path"] == "/v1/chat/completions" and r["model"] == "fixture" for r in item["requests"])}
                if mode == "success":
                    checks.update(workspaceContract=response.get("kind") == "triton.workspace.run",
                                  llmEnabled=ai.get("llmEnabled") == (True if args.baseline else llm),
                                  vlmEnabled=ai.get("vlmEnabled") == (True if args.baseline else vlm),
                                  noErrorExit=item.get("exitCode", 0) == 0)
                else:
                    # A typed non-success envelope is required; a parser failure cannot satisfy it.
                    # Both public workspace adapters intentionally wrap provider errors in
                    # workspace_failed. Bind the existing code AND specific upstream cause.
                    error = response.get("error", {})
                    message = error.get("message", "")
                    cause = {"unauthorized": "HTTP 401", "disconnect": "Code=-1005", "slow": "Code=-1001"}[mode]
                    checks["typedWorkspaceProviderFailure"] = (error.get("code") == "workspace_failed"
                        and "OpenAI-compatible workspace LLM" in message and cause in message
                        and bool(error.get("hint")))
                    checks["failureTransportStatus"] = (item.get("exitCode") == 1 if transport == "cli"
                                                        else item.get("httpStatus") == 409)
                    checks["notSuccessfulRun"] = response.get("ok") is False or response.get("status") in ["failed", "paused", "blocked"]
                    if mode == "slow":
                        checks["exercisedProductionBudget"] = item["elapsedSeconds"] >= 20
                item["checks"] = checks
                item["ok"] = all(checks.values())
                save(case_dir / "result.json", item)
                report["cases"].append(item)
                save(root / "report.json", report)
                if transport == "http" and "fixtureError" in item:
                    break
    except Exception as error:
        report["fixtureError"] = str(error)
    finally:
        api.close()
        if serve is not None:
            stop_owned(serve)
            report["cleanup"]["serveExited"] = serve.poll() is not None
        if serve_log:
            serve_log.close()
        report["cleanup"]["fakeServerStopped"] = not api.thread.is_alive()
        report["helperMarker"] = marker.read_text() if marker.exists() else ""
        report["ok"] = bool(report["cases"]) and all(c["ok"] for c in report["cases"]) and "fixtureError" not in report
        save(root / "report.json", report)
    print(json.dumps({"ok": report["ok"], "baseline": args.baseline, "cases": len(report["cases"]),
                      "report": str(root / "report.json")}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
