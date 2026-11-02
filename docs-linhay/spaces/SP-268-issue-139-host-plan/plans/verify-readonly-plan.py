#!/usr/bin/env python3
"""Read-only packaged CLI plan smoke; generated commands are never executed."""
import argparse
import json
from pathlib import Path
import shlex
import socket
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("binary", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
url = "example://audit?id=1&mode=two words"
evidence = "/fixture/evidence dir.tritonevidence"
# Reserve a local port without listening. This guarantees no embedded server
# receives the probe and does not start or stop a shared service.
with socket.socket() as reserved:
    reserved.bind(("127.0.0.1", 0))
    port = str(reserved.getsockname()[1])
    for platform in ("harmony", "android"):
        for goal in ("general", "open-url"):
            argv = [str(args.binary.resolve()), "plan"] + ([] if goal == "general" else [goal])
            argv += ["--platform", platform,
                    "--device", "__audit_no_device__", "--host", "127.0.0.1", "--port", port, "--json"]
            if goal == "open-url":
                argv += ["--url", url, "--text", "Ready now", "--evidence", evidence]
                if platform == "harmony":
                    argv += ["--bundle", "com.example.audit", "--ability", "EntryAbility",
                             "--hap", "/fixture/candidate file.hap"]
            result = subprocess.run(argv, capture_output=True, text=True, timeout=30)
            name = f"{platform}-{goal}"
            # Keep prior failed fixture evidence intact; reruns use a fresh directory.
            with (args.output / f"{name}.json").open("x") as output:
                output.write(result.stdout)
            # Plan.run prints a constructed plan and returns normally even when
            # plan.ok=false (for example unsupported requested evidence). Only
            # parser/validation errors use a nonzero process exit here.
            assert result.returncode == 0, (name, result.returncode, result.stderr)
            plan = json.loads(result.stdout)
            assert plan["nextStep"] == "device-doctor", plan
            assert plan["serverReachable"] is False, plan
            assert not plan.get("afterRecoverySteps"), plan
            for step in plan["steps"]:
                assert step["requiresServer"] is False, step
                assert "xcode" not in step["argv"] and "serve" not in step["argv"], step
                assert shlex.split(step["command"]) == step["argv"], step
            if goal == "open-url":
                flattened = [token for step in plan["steps"] for token in step["argv"]]
                assert flattened.count(url) == 1, flattened
                assert "__audit_no_device__" in flattened
                if platform == "harmony":
                    for token in ("com.example.audit", "EntryAbility", "/fixture/candidate file.hap", evidence):
                        assert token in flattened, flattened
                    assert plan["ok"] is True, plan
                else:
                    assert plan["ok"] is False, plan
                    assert plan["error"]["code"] == "unsupported_capability", plan
                    assert evidence in plan["error"]["message"], plan
            print(f"PASS {name}: read-only plan, no generated actions executed")
