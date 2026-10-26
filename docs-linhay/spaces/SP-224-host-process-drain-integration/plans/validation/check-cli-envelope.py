#!/usr/bin/env python3
"""Exercise the shipped argv route with our fake adb; no SDK or device used."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

output = Path(__file__).resolve().parent
binary = Path(os.environ['TRITON_CLI_PATH']).resolve()
rows = []
with tempfile.TemporaryDirectory(prefix='triton-sp224-fake-') as temporary:
    root = Path(temporary)
    fake = root / 'adb'
    fake.write_text('''#!/bin/sh
set -eu
printf '%s\\n' "$*" >> "$SP224_CALLS"
case "$SP224_MODE" in
  complete) printf 'List of devices attached\\n'; exit 0 ;;
  nonzero) printf 'fixture-nonzero' >&2; exit 7 ;;
  incomplete|incomplete7)
    (/bin/sleep 3) 2>/dev/null &
    echo $! > "$SP224_PID"
    printf 'List of devices attached\\n'
    if [ "$SP224_MODE" = incomplete7 ]; then exit 7; fi
    exit 0 ;;
esac
exit 89
''')
    fake.chmod(0o700)
    for mode in ['complete', 'nonzero', 'incomplete', 'incomplete7']:
        calls = root / (mode + '.calls')
        pid_path = root / (mode + '.pid')
        env = dict(os.environ, SP224_MODE=mode, SP224_CALLS=str(calls), SP224_PID=str(pid_path))
        argv = [str(binary), 'device', 'list', '--platform', 'android', '--scope', 'emulator', '--adb', str(fake), '--json']
        started = time.monotonic()
        process = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            try:
                stdout, stderr = process.communicate(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                raise
            elapsed = time.monotonic() - started
            envelope = json.loads(stdout)  # Rejects additional JSON objects/noise.
            assert isinstance(envelope, dict)
            assert calls.read_text().splitlines() == ['devices -l'], 'Command replay or unexpected argv'
            row = dict(mode=mode, command=argv, exit=process.returncode, wall_seconds=round(elapsed, 3),
                       stdout=envelope, stderr=stderr.decode(errors='replace'), cli_pid=process.pid)
            if mode == 'complete':
                assert process.returncode == 0 and envelope['ok'] is True and envelope['targets'] == []
            else:
                assert process.returncode != 0 and envelope['ok'] is False
                expected = 'host_action_failed' if mode == 'nonzero' else 'host_output_incomplete'
                assert envelope['error']['code'] == expected, envelope
                if mode == 'incomplete7':
                    assert 'exitCode: 7' in envelope['error']['message']
                if mode.startswith('incomplete'):
                    pid = int(pid_path.read_text())
                    assert pid > 1
                    os.kill(pid, 0)
                    row['holder_pid'] = pid
                    row['holder_alive_before_fixture_cleanup'] = True
                    assert elapsed < 1.5
            rows.append(row)
        finally:
            if pid_path.exists():
                # Only the PID recorded by this invocation's self-created shell.
                pid = int(pid_path.read_text())
                if pid > 1:
                    try:
                        os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
record = dict(binary=str(binary), binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
              candidate_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              no_device_or_sdk=True, cases=rows)
(output / 'cli-envelope-cases.json').write_text(json.dumps(record, indent=2) + '\n')
print('PASS: four actual CLI fake-adb cases, single JSON, exact argv once, bounded incomplete capture and exit7 retained')
