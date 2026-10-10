#!/usr/bin/env python3
"""Read-only command contract checks; DEVELOPER_DIR applies only to child CLI.

Use a fresh, ignored output directory. Never switches xcode-select or executes
boot/install/launch. Unsupported old toolchains are diagnostic results, not
permission to retry an action via another backend.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--triton', required=True)
parser.add_argument('--developer-directory')
parser.add_argument('--output-directory', required=True)
options = parser.parse_args()
binary = Path(options.triton).resolve(strict=True)
output = Path(options.output_directory).resolve()
output.mkdir(parents=True, exist_ok=False, mode=0o700)
environment = dict(os.environ)
if options.developer_directory:
    environment['DEVELOPER_DIR'] = str(Path(options.developer_directory).resolve(strict=True))
summary = {'verification': 'help-advertised-only', 'scopes': {}, 'developerDirectoryOverrideApplied': bool(options.developer_directory)}
for scope in ['simulator', 'real', 'all']:
    result = subprocess.run([str(binary), 'device', 'doctor', '--platform', 'ios', '--scope', scope, '--json'], env=environment, capture_output=True, text=True, timeout=120)
    for suffix, text in [('json', result.stdout), ('stderr', result.stderr)]:
        path = output / (scope + '.' + suffix)
        path.write_text(text)
        path.chmod(0o600)
    assert result.returncode == 0, 'diagnostic process failed; private output retained'
    payload = json.loads(result.stdout)
    commands = payload['commandSupport']
    assert all(c['verification'] == 'help-advertised-only' for c in commands)
    if scope == 'simulator':
        assert all(not c['name'].startswith('devicectl') for c in commands)
    if scope == 'real':
        assert all(not c['name'].startswith('simctl') for c in commands)
    required = {'simctl.list'} if scope == 'simulator' else ({'devicectl.list-devices'} if scope == 'real' else {'simctl.list', 'devicectl.list-devices'})
    assert required <= {c['name'] for c in commands}
    expected_ok = all(t['available'] for t in payload['tools']) and all(c['supported'] for c in commands if c['name'] in required)
    assert payload['ok'] == expected_ok, 'tool health disagrees with required discovery contract'
    summary['scopes'][scope] = {'ok': payload['ok'], 'commands': [{k: c[k] for k in ['name', 'supported', 'missingOptions', 'verification']} for c in commands], 'version': next(t.get('versionSummary') for t in payload['tools'] if t['name'] == 'xcodebuild')}
(output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
