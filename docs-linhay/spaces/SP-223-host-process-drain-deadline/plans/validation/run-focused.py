#!/usr/bin/env python3
"""External watchdog: signal only our launched Swift process and recorded fixture PIDs."""
import pathlib, subprocess, sys, time, os, signal
root = pathlib.Path(__file__).resolve().parents[5]
log = pathlib.Path(sys.argv[1])
started = time.monotonic()
with log.open('w') as out:
    process = subprocess.Popen(['swift', 'test', '--package-path', 'CLI', '--no-parallel', '--disable-automatic-resolution', '--skip-update', '--filter', sys.argv[2] if len(sys.argv) > 2 else 'HostProcessDrainTests'], cwd=root, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
    print(f'watchdog swift_pid={process.pid} cwd={root}', flush=True)
    try:
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        code = 124
print(f'exit={code} elapsed={time.monotonic()-started:.3f}s log={log}', flush=True)
sys.exit(code)
