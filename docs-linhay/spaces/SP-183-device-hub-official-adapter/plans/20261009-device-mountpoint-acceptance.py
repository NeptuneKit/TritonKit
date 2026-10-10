#!/usr/bin/env python3
"""Private mountpoint metadata acceptance on one explicitly owned Simulator only.
No contents, physical query, returned-path filesystem access, explicit mount/unmount or Finder.
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
parser.add_argument('--allow-owned-boot', action='store_true', required=True)
args = parser.parse_args()
os.umask(0o077)
binary = Path(args.triton).resolve(strict=True)
root = Path(args.output_directory).resolve()
root.mkdir(mode=0o700, parents=True, exist_ok=False)
owner = json.loads(Path(args.ownership).read_text())
assert owner['ownedBy'] == 'SP-183-current-acceptance' and owner['creation']['ok'] and owner['creation']['action'] == 'sim.create'
sid = owner['creation']['udid'].upper()
summary = {'fullIntegrationComplete': False, 'physicalMountpointQueried': False, 'returnedPathFilesystemAccess': False, 'fileContentsFetched': False, 'explicitMountUnmount': False}

def check(name, argv, expected=0):
    output = root / ('20261009-' + name + '.json')
    error = root / ('20261009-' + name + '.stderr')
    assert not output.exists() and not error.exists()
    result = subprocess.run([str(binary), *argv, '--json'], capture_output=True, text=True, timeout=180)
    output.write_text(result.stdout)
    error.write_text(result.stderr)
    body = json.loads(result.stdout)
    if result.returncode != expected:
        raise RuntimeError(name + ': unexpected exit; inspect private evidence')
    summary[name] = {'exitCode': result.returncode, 'ok': body.get('ok'), 'errorCode': body.get('error', {}).get('code')}
    return body

base = ['device', 'mountpoint']
schema = check('schema', ['schema', '--command', 'device'])
assert 'host.device-mountpoint' in json.dumps(schema)
for name, argv, code in [
    ('platform', [*base, '--platform', 'android'], 'unsupported_device_mountpoint_platform'),
    ('timeout', [*base, '--timeout=-1'], 'parameter_conflict'),
    ('limit', [*base, '--max-json-bytes', '0'], 'parameter_conflict'),
]:
    failure = check(name, argv, 1)
    assert failure['error']['code'] == code and not failure['ok']

before = check('sim-before', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']
owned = [device for device in before if device['target'].upper() == sid]
assert len(owned) == 1 and owned[0]['state'] == 'Shutdown' and owned[0]['name'] == owner['name']
try:
    check('sim-boot', ['sim', 'boot', sid, '--wait', '--timeout', '120'])
    output = check('sim-mountpoint', [*base, '--device', 'sim:' + sid, '--scope', 'simulator', '--timeout', '30'])
    assert output['ok'] and output['action'] == 'device.mountpoint' and output['target']['id'] == 'sim:' + sid
    for flag in ['hostFilesystemInspected', 'mountStateVerified', 'contentsListed', 'businessReadinessVerified']:
        assert output[flag] is False
    assert output['verification'] == 'executed-file-json' and output['identityBinding'] == 'exact-file-json-device-argument'
    assert output['mountpointToken'].startswith('devicefs:') and len(output['mountpointToken']) == 73
    private = json.loads(Path(output['artifacts'][0]).read_text())
    text = json.dumps(output)
    assert private['result']['dataPath'] not in text and 'dataPath' not in output
    for command in output['sourceCommands']:
        assert sid not in command and private['result']['dataPath'] not in command
    for artifact in output['artifacts']:
        path = Path(artifact)
        assert path.parent.stat().st_mode & 0o777 == 0o700
        assert path.stat().st_mode & 0o777 == 0o600
    # No Path/private['result']['dataPath'] open/stat/realpath/list: metadata is not mount-state proof.
    limited = check('sim-local-limit', [*base, '--device', 'sim:' + sid, '--scope', 'simulator', '--max-json-bytes', '1'], 1)
    assert limited['error']['code'] == 'device_mountpoint_limit_exceeded'
    summary['metadataAcceptance'] = {'pathNotInlined': True, 'commandOperandRedaction': True, 'artifactPermissionsVerified': True, 'actualOneByteLimitRejected': True, 'mountStateNotClaimed': True}
finally:
    check('sim-shutdown', ['sim', 'shutdown', sid])
after = check('sim-after', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']
assert {device['id']: (device['name'], device['state']) for device in before} == {device['id']: (device['name'], device['state']) for device in after}
summary['isolation'] = {'ownedFinalState': 'Shutdown', 'allSimulatorNamesAndStatesUnchanged': True}
(root / '20261009-mountpoint-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print('Owned mountpoint metadata privacy/bounds and all Simulator names/states restoration accepted')
