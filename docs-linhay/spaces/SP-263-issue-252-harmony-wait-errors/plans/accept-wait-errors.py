#!/usr/bin/env python3
"""Run a real CLI against an isolated fake HDC; never contacts a device."""
import argparse
import json
import os
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--cli', required=True)
p.add_argument('--output', required=True)
a = p.parse_args()
cli = str(Path(a.cli).resolve())
output = Path(a.output).resolve()
output.mkdir(parents=True, exist_ok=True)
hdc = output / 'hdc'
hdc.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$SP263_TRACE_PATH"
if [ "$SP263_TRANSPORT_FAILURE" = 1 ]; then
  echo 'synthetic host transport failure' >&2
  exit 7
fi
printf 'fake-one TCP Connected localhost\\n'
''')
hdc.chmod(0o700)
base = ['wait', '--platform', 'harmony', '--text', 'Ready', '--hdc', str(hdc), '--json']
cases = [
    ('missing-target', base + ['--target', '__missing__'], 'target_not_found', False),
    ('missing-device-alias', base + ['--device', '__missing__'], 'target_not_found', False),
    ('observe-parity', ['observe', 'tree', '--platform', 'harmony', '--device', '__missing__', '--hdc', str(hdc), '--json'], 'target_not_found', False),
    ('missing-hdc-path', ['wait', '--platform', 'harmony', '--target', '__missing__', '--text', 'Ready', '--hdc', str(output / 'absent-hdc'), '--json'], 'harmony_hdc_not_found', False),
    ('missing-hdc-name', ['wait', '--platform', 'harmony', '--target', '__missing__', '--text', 'Ready', '--hdc', '__sp263_hdc_does_not_exist__', '--json'], 'harmony_hdc_not_found', False),
    ('host-transport', base + ['--target', 'fake-one'], 'host_action_failed', True),
    ('idle-fast-reject', ['wait', '--platform', 'harmony', '--target', 'fake-one', '--idle', '--hdc', str(hdc), '--json'], 'unsupported_capability', False),
    ('condition-timeout', base + ['--target', 'fake-one', '--timeout', '0.001'], None, False),
    ('runtime-server', ['wait', '--text', 'Ready', '--host', '127.0.0.1', '--port', '1', '--json'], 'server_unavailable', False),
]
rows = []
for name, argv, code, transport_failure in cases:
    trace = output / (name + '.calls')
    trace.write_text('')
    env = dict(os.environ, SP263_TRACE_PATH=str(trace), SP263_TRANSPORT_FAILURE='1' if transport_failure else '0')
    process = subprocess.run([cli] + argv, capture_output=True, text=True, timeout=15, env=env)
    (output / (name + '.stdout.json')).write_text(process.stdout)
    (output / (name + '.stderr')).write_text(process.stderr)
    checks = {'nonzero': process.returncode != 0}
    try:
        result = json.loads(process.stdout)
        checks['singleJSON'] = isinstance(result, dict)
        error = result.get('error', {})
        if code is None:
            checks['conditionResult'] = result.get('timedOut') is True and result.get('matched') is False and 'error' not in result
        else:
            checks['code'] = error.get('code') == code
            checks['endpoint'] = bool(error.get('endpoint')) if name == 'runtime-server' else error.get('endpoint') is None
        if name in ('missing-target', 'missing-device-alias'):
            checks['targetedRecovery'] = error.get('nextAction', {}).get('args') == ['list', '--platform', 'harmony', '--hdc', str(hdc), '--json']
        if name.startswith('missing-hdc'):
            action = error.get('nextAction', {})
            checks['configurationRecovery'] = '--hdc' in action.get('args', []) and '--hdc' in error.get('hint', '') and action.get('command') != 'serve'
        if name == 'idle-fast-reject':
            checks['backendUntouched'] = trace.read_text() == ''
    except (ValueError, TypeError) as error:
        checks['singleJSON'] = False
    rows.append({'case': name, 'exit': process.returncode, 'checks': checks, 'passed': all(checks.values())})
report = {'cli': cli, 'version': subprocess.run([cli, '--version'], capture_output=True, text=True, check=True).stdout.strip(), 'cases': rows, 'passed': all(r['passed'] for r in rows)}
(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'passed': report['passed'], 'cases': len(rows), 'failed': [r['case'] for r in rows if not r['passed']]}))
raise SystemExit(0 if report['passed'] else 1)
