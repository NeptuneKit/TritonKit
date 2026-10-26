#!/usr/bin/env python3
"""Run only an explicitly supplied command in its own process group."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

directory = Path(__file__).resolve().parent
label, budget, *command = sys.argv[1:]
assert label.replace('-', '').isalnum() and command
started = time.monotonic()
with (directory / (label + '.log')).open('wb') as output:
    process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    print(f'{label}: pid={process.pid} watchdog={budget}s', flush=True)
    timed_out = False
    try:
        code = process.wait(timeout=float(budget))
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        code = 124
record = dict(command=command, cwd=os.getcwd(), pid=process.pid, exit=code,
              watchdog_seconds=float(budget), timed_out=timed_out,
              wall_seconds=round(time.monotonic() - started, 3),
              candidate_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              triton_cli_path=os.environ.get('TRITON_CLI_PATH'),
              log_sha256=hashlib.sha256((directory / (label + '.log')).read_bytes()).hexdigest())
(directory / (label + '.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
sys.exit(code)
