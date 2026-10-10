#!/usr/bin/env python3
"""Readonly file metadata acceptance. Only explicitly owned Simulator boot is allowed.
All raw JSON, identifiers and file names remain private; no contents/copy/temporary query.
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
parser.add_argument('--verify-real-readonly', action='store_true')
args = parser.parse_args()
os.umask(0o077)
binary = Path(args.triton).resolve(strict=True)
root = Path(args.output_directory).resolve()
root.mkdir(mode=0o700, parents=True, exist_ok=False)
owner = json.loads(Path(args.ownership).read_text())
assert owner['ownedBy'] == 'SP-183-current-acceptance' and owner['creation']['ok']
sid = owner['creation']['udid'].upper()
summary = {'fullIntegrationComplete': False, 'physicalWrites': False, 'temporaryDomainQueried': False, 'fileContentsFetched': False}

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

base = ['device', 'files', '--domain-type', 'systemCrashLogs']
check('schema', ['schema', '--command', 'device'])
for name, argv, code in [
    ('platform', [*base, '--platform', 'android'], 'unsupported_device_files_platform'),
    ('path', [*base, '--subdirectory', '../escape'], 'parameter_conflict'),
    ('timeout', [*base, '--timeout=-1'], 'parameter_conflict'),
    ('limit', [*base, '--max-json-bytes', '0'], 'parameter_conflict'),
    ('missing-domain-id', ['device', 'files', '--domain-type', 'appDataContainer'], 'parameter_conflict'),
    ('temporary-policy', ['device', 'files', '--domain-type', 'temporary', '--domain-identifier', 'never-created'], 'device_file_domain_policy_required'),
]:
    failure = check(name, argv, 1)
    assert failure['error']['code'] == code and not failure['ok']

if args.verify_real_readonly:
    real = check('real-list', ['device', 'list', '--platform', 'ios', '--scope', 'real'])['targets']
    assert real, 'No physical target; do not substitute another platform'
    selector = real[0]['id']
    output = check('real-files', [*base, '--device', selector, '--scope', 'real', '--timeout', '30'])
    assert output['ok'] and output['action'] == 'device.files' and output['target']['id'] == selector
    assert not output['recursive'] and not output['businessReadinessVerified'] and not output['sensitiveMetadataIncluded']
    private = json.loads(Path(output['artifacts'][0]).read_text())['result']
    assert output['count'] == len(private['files'])
    text = json.dumps(output)
    assert private['deviceIdentifier'] not in text
    assert all('name' not in entry and 'relativePath' not in entry and 'isWritable' not in entry for entry in output['entries'])
    for artifact in output['artifacts']:
        path = Path(artifact)
        assert path.parent.stat().st_mode & 0o777 == 0o700
        assert path.stat().st_mode & 0o777 == 0o600
    limited = check('real-local-limit', [*base, '--device', selector, '--scope', 'real', '--max-json-bytes', '1'], 1)
    assert limited['error']['code'] == 'device_files_limit_exceeded'
    summary['physicalMetadataOnly'] = {'countMatchesPrivateBackend': True, 'identitiesNamesPathsNotInlined': True, 'privateArtifactPermissionsVerified': True, 'localByteLimitRejected': True}

before = check('sim-before', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']
owned = [device for device in before if device['target'].upper() == sid]
assert len(owned) == 1 and owned[0]['state'] == 'Shutdown' and owned[0]['name'] == owner['name']
try:
    check('sim-boot', ['sim', 'boot', sid, '--wait', '--timeout', '120'])
    failure = check('sim-files-restriction', [*base, '--device', 'sim:' + sid, '--scope', 'simulator'], 1)
    assert failure['error']['code'] == 'unsupported_device_file_query'
finally:
    check('sim-shutdown', ['sim', 'shutdown', sid])
after = check('sim-after', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])['targets']
assert {device['id']: (device['name'], device['state']) for device in before} == {device['id']: (device['name'], device['state']) for device in after}
summary['isolation'] = {'ownedFinalState': 'Shutdown', 'allSimulatorNamesAndStatesUnchanged': True, 'businessReadinessVerified': False}
(root / '20261009-files-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print('Physical metadata privacy/bounds and owned Simulator restriction/restoration accepted')
