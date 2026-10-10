#!/usr/bin/env python3
"""Rename only an explicitly task-owned Simulator, independently observe, and restore.
No boot/install/erase/delete, physical action, global toolchain switch or backend fallback.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--triton', required=True)
parser.add_argument('--ownership', required=True)
parser.add_argument('--output-directory', required=True)
parser.add_argument('--allow-owned-rename', action='store_true', required=True)
args = parser.parse_args()
os.umask(0o077)
binary = Path(args.triton).resolve(strict=True)
root = Path(args.output_directory).resolve()
root.mkdir(mode=0o700, parents=True, exist_ok=True)
root.chmod(0o700)
owner = json.loads(Path(args.ownership).read_text())
assert owner['ownedBy'] == 'SP-183-current-acceptance'
assert owner['creation']['ok'] and owner['creation']['action'] == 'sim.create'
sid = owner['creation']['udid'].upper()
old_name = owner['name']
assert old_name.startswith('SP183-CommandCompat-')
new_name = old_name + ' 重命名验收'
summary = {}

def check(name, argv, expected=0):
    output = root / ('20261009-' + name + '.json')
    error = root / ('20261009-' + name + '.stderr')
    assert not output.exists() and not error.exists(), 'Do not overwrite prior evidence'
    result = subprocess.run([str(binary), *argv, '--json'], capture_output=True, text=True, timeout=120)
    output.write_text(result.stdout)
    error.write_text(result.stderr)
    body = json.loads(result.stdout)
    if result.returncode != expected:
        raise RuntimeError(name + ': unexpected exit; inspect private evidence')
    summary[name] = {'exitCode': result.returncode, 'ok': body.get('ok'), 'errorCode': body.get('error', {}).get('code')}
    return body

def inventory(name):
    return check(name, ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']

def owned(devices):
    matches = [device for device in devices if device['target'].upper() == sid]
    assert len(matches) == 1
    return matches[0]

check('schema', ['schema', '--command', 'sim'])
for name, argv in [('invalid-selector', ['all', 'name']), ('blank-name', [sid, ' ']), ('invalid-timeout', [sid, 'name', '--timeout=-1'])]:
    failure = check(name, ['sim', 'rename', *argv], 1)
    assert not failure['ok'] and failure['error']['code'] == 'parameter_conflict'
before = inventory('before')
original = owned(before)
assert original['name'] == old_name and original['state'] == 'Shutdown'
try:
    submitted = check('rename', ['sim', 'rename', sid, new_name, '--timeout', '30'])
    assert submitted['ok'] and submitted['action'] == 'sim.rename'
    assert submitted['target'] == 'sim:' + sid
    assert not submitted['hostAction']['businessReady']
    observed = owned(inventory('observed'))
    assert observed['name'] == new_name and observed['id'] == original['id']
    assert observed['state'] == original['state']
finally:
    current = owned(inventory('pre-restore'))
    if current['name'] == new_name:
        check('restore', ['sim', 'rename', sid, old_name, '--timeout', '30'])
    elif current['name'] != old_name:
        raise RuntimeError('Unexpected third-party name change; refuse to overwrite it')
after = inventory('after')
restored = owned(after)
assert (restored['name'], restored['id'], restored['state']) == (original['name'], original['id'], original['state'])
assert {device['id']: (device['name'], device['state']) for device in before if device['target'].upper() != sid} == {device['id']: (device['name'], device['state']) for device in after if device['target'].upper() != sid}
summary['postcondition'] = {'observedNameChanged': True, 'canonicalIdentityPreserved': True, 'bootStatePreserved': True, 'originalNameRestored': True, 'otherSimulatorNamesAndStatesUnchanged': True}
(root / '20261009-rename-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print('Owned Simulator rename independently observed and original name/state restored')
