#!/usr/bin/env python3
"""Read-only official discovery acceptance. Never boots/launches/installs a device.

Raw results (including private device names/identifiers) remain in the caller's
fresh output directory. stdout contains counts and verdicts only. Run against the
newly built binary, not an installed binary with the same version string.
"""
import argparse
import collections
import json
import pathlib
import shlex
import subprocess
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--triton', required=True)
    parser.add_argument('--output-directory', required=True)
    options = parser.parse_args()
    binary = pathlib.Path(options.triton).resolve(strict=True)
    output = pathlib.Path(options.output_directory).resolve()
    output.mkdir(parents=True, exist_ok=False, mode=0o700)
    exits = {}

    def run(label, args, expected=0):
        result = subprocess.run([str(binary), *args, '--json'], capture_output=True, text=True, timeout=120)
        for suffix, text in [('json', result.stdout), ('stderr', result.stderr)]:
            path = output / f'{label}.{suffix}'
            path.write_text(text)
            path.chmod(0o600)
        exits[label] = result.returncode
        assert result.returncode == expected, f'{label}: unexpected exit (private output retained locally)'
        payload = json.loads(result.stdout)  # rejects multiple failure envelopes
        assert isinstance(payload, dict), f'{label}: not one JSON object'
        return payload

    def raw_coredevice(payload):
        tokens = shlex.split(payload['sourceCommand'])
        artifact = pathlib.Path(tokens[tokens.index('--json-output') + 1]).resolve(strict=True)
        assert artifact.name == 'list-devices.json'
        assert artifact.parent.name.startswith('triton-devicectl-list-devices-')
        raw = json.loads(artifact.read_text())
        local = output / ('raw-' + str(len(list(output.glob('raw-*.json')))) + '.json')
        local.write_text(json.dumps(raw, indent=2) + '\n')
        local.chmod(0o600)
        return raw

    def real_id(identifier):
        value = 0xcbf29ce484222325
        for byte in identifier.encode('utf-8'):
            value = ((value ^ byte) * 0x100000001b3) & 0xffffffffffffffff
        return f'ios-real:{value & 0x0000ffffffffffff:012x}'

    version = run('version', ['version'])
    schema = run('schema-device', ['schema', '--command', 'device'])
    assert 'Device Hub' in json.dumps(schema), 'new discovery schema missing'
    inventory = run('ios-all', ['device', 'list', '--platform', 'ios', '--scope', 'all'])
    assert inventory.get('ok') is True
    targets = inventory['targets']
    ids = [target['id'] for target in targets]
    assert len(ids) == len(set(ids)), 'duplicate canonical targets'
    assert all(not t['ready'] for t in targets if t.get('scope') == 'unknown')
    raw = raw_coredevice(inventory)
    expected_real = set()
    expected_sim = set()
    reality_counts = collections.Counter()
    for record in raw['result']['devices']:
        modern = record.get('properties')
        hardware = modern.get('hardware', {}) if isinstance(modern, dict) else ({} if 'properties' in record else record.get('hardwareProperties', {}))
        hardware = hardware if isinstance(hardware, dict) else {}
        reality = hardware.get('reality', 'unknown')
        reality_counts[reality] += 1
        if hardware.get('platform', '').lower() != 'ios':
            continue
        if reality == 'physical':
            expected_real.add(real_id(record['identifier']))
        elif reality == 'simulated' and hardware.get('udid'):
            expected_sim.add('sim:' + str(uuid.UUID(hardware['udid'])).upper())
    actual_real = {t['id'] for t in targets if t.get('scope') == 'real'}
    actual_sim = {t['id'] for t in targets if t.get('scope') == 'simulator'}
    assert actual_real == expected_real, 'physical classification mismatch'
    assert expected_sim <= actual_sim, 'CoreDevice simulator identity missing'

    real = run('ios-real', ['device', 'list', '--platform', 'ios', '--scope', 'real'])
    assert all(t.get('scope') == 'real' and t.get('kind') == 'real-device' for t in real['targets'])
    simulations = run('ios-simulator', ['device', 'list', '--platform', 'ios', '--scope', 'simulator'])
    assert 'devicectl' not in simulations['sourceCommand'], 'simulator-only discovery used physical backend'
    assert all(t.get('scope') == 'simulator' for t in simulations['targets'])
    first = next(iter(simulations['targets']), None)
    resolved = None
    if first:
        resolution = run('resolve-simulator', ['target', 'resolve', first['id'], '--platform', 'ios'])
        assert resolution.get('ok') is True
        assert resolution['selection']['target']['id'] == first['id']
        resolved = True
    missing = run('missing-simulator', ['target', 'resolve', 'sim:00000000-0000-0000-0000-000000000000', '--platform', 'ios'], expected=1)
    assert missing.get('ok') is False and isinstance(missing.get('error'), dict)
    summary = {
        'ok': True, 'binaryVersion': version['version'],
        'jsonVersion': raw.get('info', {}).get('jsonVersion'),
        'devicectlVersion': raw.get('info', {}).get('version'),
        'rawRealityCounts': dict(reality_counts),
        'mergedScopeCounts': dict(collections.Counter(t.get('scope', 'unknown') for t in targets)),
        'duplicateCanonicalTargets': 0, 'simulatorResolved': resolved,
        'singleFailureEnvelope': True, 'commandExitCodes': exits,
        'boundary': 'readonly discovery/selection; no boot/install/launch/input; no business-ready verdict',
    }
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
