"""Offline CLI process acceptance: explicit fake ADB, never a real device."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

cli = str(Path(sys.argv[1]).resolve())
evidence = Path(sys.argv[2]).resolve()
evidence.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='triton-sp213-') as folder:
    root = Path(folder)
    adb = root / 'adb-fixture'
    adb.write_text('''#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
if args == ["devices", "-l"]:
    print("List of devices attached\\nemulator-5554 device product:sdk_gphone model:Fixture device:fixture transport_id:1")
elif args[:3] == ["-s", "emulator-5554", "shell"] and "dumpsys" in " ".join(args[3:]):
    if os.environ["SP213_CASE"] == "backend-failure":
        sys.exit(42)
    print(os.environ["SP213_RECORD"])
else:
    sys.exit(43)
''')
    adb.chmod(0o700)
    cases = [
        ('top', 'topResumedActivity=ActivityRecord{abc u0 com.fixture/.Main t1}', 'com.fixture.Main'),
        ('legacy', 'mResumedActivity: ActivityRecord{abc u0 com.fixture/com.fixture.Main t1}', 'com.fixture.Main'),
        ('bare', 'mResumedActivity: ActivityRecord{abc u0 com.fixture/Main t1}', 'Main'),
        ('malformed-top', 'topResumedActivity=null\nmResumedActivity: ActivityRecord{abc u0 com.stale/.Main t1}', None),
        ('window-focus', 'mCurrentFocus=Window{abc u0 com.stale/.Dialog}', None),
        ('conflicting', 'mResumedActivity: ActivityRecord{abc u0 com.one/.Main t1}\nmResumedActivity: ActivityRecord{def u0 com.two/.Main t2}', None),
        ('backend-failure', '', None),
    ]
    for name, record, expected in cases:
        env = dict(os.environ, SP213_CASE=name, SP213_RECORD=record)
        result = subprocess.run([cli, 'device', 'foreground', '--platform', 'android', '--scope', 'emulator', '--device', 'emulator-5554', '--adb', str(adb), '--json'], cwd=root, env=env, capture_output=True, text=True, timeout=30)
        (evidence / (name + '.json')).write_text(result.stdout)
        data = json.loads(result.stdout)  # rejects a second error envelope
        assert data['executed'] is False if 'executed' in data else name == 'backend-failure'
        if name == 'backend-failure':
            assert result.returncode != 0 and data['ok'] is False
            assert data['error']['code'] == 'device_environment_backend_failed'
        else:
            assert result.returncode == 0 and data['ok'] is True
            observed = data['observed']
            assert observed['scope'] == 'resumed-activity'
            assert data['businessReadinessVerified'] is False
            if expected:
                assert data['verified'] is True and observed['activity'] == expected
                assert observed['identityState'] == 'current' and observed['component'].startswith('com.fixture/')
            else:
                assert data['verified'] is False and observed['identityState'] == 'unknown'
                assert 'activity' not in observed and 'component' not in observed
    for command in ('sim.ax', 'observe', 'act', 'wait', 'node'):
        result = subprocess.run([cli, 'schema', '--command', command, '--json'], capture_output=True, text=True, timeout=30, check=True)
        data = json.loads(result.stdout)
        assert 'ios_host_ax_geometry_unavailable' in result.stdout, command
        (evidence / ('schema-' + command + '.json')).write_text(result.stdout)
print(json.dumps({'ok': True, 'foregroundCases': len(cases), 'schemaCases': 5, 'deviceActions': False}))
