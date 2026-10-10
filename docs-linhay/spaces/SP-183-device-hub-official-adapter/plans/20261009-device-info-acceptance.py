#!/usr/bin/env python3
"""Readonly Device Hub info acceptance; optional boot/shutdown of an explicitly owned simulator.

Raw results stay in the caller's private evidence directory. Never installs apps,
pairs/unlocks physical devices, erases devices, or changes global toolchain selection.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--triton', required=True)
parser.add_argument('--output-directory', required=True)
parser.add_argument('--ownership', required=True)
parser.add_argument('--allow-owned-boot', action='store_true')
parser.add_argument('--verify-real-readonly', action='store_true')
parser.add_argument('--expect-simulator-lock-unsupported', action='store_true', help='Explicit observed-device restriction; never silently downgrade a failed lock query')
args = parser.parse_args()
os.umask(0o077)
binary = Path(args.triton).resolve(strict=True)
root = Path(args.output_directory).resolve()
root.mkdir(parents=True, exist_ok=True, mode=0o700)
root.chmod(0o700)
summary = {}

def check(name, argv, expected=0):
    output = root / f'20261009-{name}.json'
    stderr = root / f'20261009-{name}.stderr'
    if output.exists() or stderr.exists():
        raise RuntimeError(f'Refuse to overwrite evidence: {name}')
    process = subprocess.run([str(binary), *argv, '--json'], capture_output=True, text=True, timeout=180)
    output.write_text(process.stdout)
    stderr.write_text(process.stderr)
    body = json.loads(process.stdout)  # Exactly one JSON envelope, not JSONL or terminal text.
    if process.returncode != expected:
        raise RuntimeError(f'{name}: exit {process.returncode}; inspect private evidence')
    summary[name] = {'exitCode': process.returncode, 'ok': body.get('ok'), 'errorCode': body.get('error', {}).get('code')}
    return body

check('schema', ['schema', '--command', 'device'])
check('invalid-platform', ['device', 'info', '--platform', 'android'], 1)
# ArgumentParser requires the equals form for a negative option value.
check('invalid-timeout', ['device', 'info', '--platform', 'ios', '--timeout=-1'], 1)
check('missing-target', ['device', 'info', '--platform', 'ios', '--device', 'ios-real:missing-fixture'], 1)
if args.verify_real_readonly:
    devices = check('real-list', ['device', 'list', '--platform', 'ios', '--scope', 'real'])['targets']
    if not devices:
        raise RuntimeError('No physical iOS target for explicitly requested readonly verification')
    real = check('real', ['device', 'info', '--platform', 'ios', '--device', devices[0]['id'], '--scope', 'real', '--lock-state', '--timeout', '30'])
    assert real['verification'] == 'executed-file-json' and not real['businessReadinessVerified']
    assert real['lockState']['requested'] and real['target']['scope'] == 'real'
    assert 'rawTargetAliases' not in json.dumps(real)

ownership = json.loads(Path(args.ownership).read_text())
assert ownership['ownedBy'] == 'SP-183-current-acceptance'
assert ownership['creation']['ok'] and ownership['creation']['action'] == 'sim.create'
sid = str(uuid.UUID(ownership['creation']['udid'])).upper()
assert ownership['name'].startswith('SP183-CommandCompat-')
before = check('sim-before', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']
owned = [device for device in before if device['target'] == sid]
assert len(owned) == 1 and owned[0]['name'] == ownership['name']
assert owned[0]['state'] in ['Shutdown', 'Booted']
started = owned[0]['state'] == 'Shutdown'
if started and not args.allow_owned_boot:
    raise RuntimeError('Owned target is shutdown; explicit --allow-owned-boot required')
try:
    if started:
        check('owned-boot', ['sim', 'boot', sid, '--wait', '--timeout', '120'])
    unprobed = check('simulator-not-probed', ['device', 'info', '--platform', 'ios', '--device', 'sim:' + sid, '--timeout', '30'])
    assert unprobed['target']['id'] == 'sim:' + sid and unprobed['target']['scope'] == 'simulator'
    assert not unprobed['businessReadinessVerified']
    assert unprobed['lockState']['verification'] == 'not-probed' and not unprobed['lockState']['requested']
    simulated = check('simulator-lock', ['device', 'info', '--platform', 'ios', '--device', 'sim:' + sid, '--lock-state', '--timeout', '30'], expected=1 if args.expect_simulator_lock_unsupported else 0)
    if args.expect_simulator_lock_unsupported:
        assert not simulated['ok'] and simulated['error']['code'] == 'unsupported_device_info_query'
    else:
        assert simulated['lockState']['requested']
finally:
    if started:
        check('owned-shutdown', ['sim', 'shutdown', sid])
after = check('sim-after', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']
assert next(device['state'] for device in after if device['target'] == sid) == owned[0]['state']
assert {device['id']: device['state'] for device in before if device['target'] != sid} == {device['id']: device['state'] for device in after if device['target'] != sid}
summary_path = root / '20261009-info-live-summary.json'
assert not summary_path.exists()
summary_path.write_text(json.dumps(summary, indent=2) + '\n')
print('Device info live acceptance passed; private results and sanitized outcome ledger preserved')
