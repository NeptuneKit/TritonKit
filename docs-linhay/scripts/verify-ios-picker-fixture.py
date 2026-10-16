"""Pair with PickerGesture XCTest; only controls the explicitly selected public fixture."""
import argparse
import json
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--triton', required=True)
parser.add_argument('--simulator', required=True)
parser.add_argument('--port', type=int, default=19422)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--timeout', type=float, default=120)
parser.add_argument('--xcode-events', type=Path, help='Current triton xcode test JSONL; wait for XCTest readiness before acting')
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
target = f'triton:ios-simulator:{args.simulator}/app:com.neptunekit.tritonkit.testfixture'
common = ['--target', target, '--port', str(args.port), '--json']
checks = []

def command(name, argv, expected=0):
    result = subprocess.run([args.triton, *argv, *common], text=True, capture_output=True, timeout=20)
    (output / f'{name}.json').write_text(result.stdout)
    if result.stderr:
        (output / f'{name}.stderr').write_text(result.stderr)
    data = json.loads(result.stdout)
    assert result.returncode == expected, (name, result.returncode, data)
    checks.append(name)
    return data

# XCTest must finish its zero-click assertions before the external action.
# Selection validity alone is not a handoff: it can become valid before those assertions.
if args.xcode_events:
    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        lines = args.xcode_events.read_text().splitlines() if args.xcode_events.exists() else []
        events = []
        for line in lines:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass  # Writer may still be completing the last line.
        raw = next((Path(event['stdoutLogPath']) for event in events if event.get('stdoutLogPath')), None)
        if raw and raw.exists() and "Added attachment named 'picker-button-selected-ready-for-cli'" in raw.read_text():
            break
        if any(event.get('action') == 'xcode.test' for event in events):
            raise RuntimeError('XCTest finished before handoff')
        time.sleep(0.5)
    else:
        raise RuntimeError('XCTest readiness handoff timed out')

# XCTest owns launch and touch delivery; wait for its explicitly selected button.
deadline = time.monotonic() + args.timeout
while time.monotonic() < deadline:
    result = subprocess.run([args.triton, 'inspect', 'selection', *common], text=True, capture_output=True, timeout=10)
    try:
        state = json.loads(result.stdout)
    except json.JSONDecodeError:
        state = {}
    selection = state.get('selection', {})
    if state.get('state') == 'valid' and selection.get('target', {}).get('identifier') == 'fixture.picker.increment':
        break
    time.sleep(0.5)
else:
    raise RuntimeError('XCTest did not produce an actionable fixture button selection before the deadline')
(output / 'selection.json').write_text(json.dumps(state, indent=2))
command('verify-no-business-click', ['verify', 'text-exists', 'Picker Clicks: 0'])
ax = command('ordinary-ax', ['debug', 'ax'])
assert 'triton.picker.dot' not in json.dumps(ax), 'Inspector must not appear in the business AX tree'
command('ordinary-screenshot', ['screenshot', '--output', str(output / 'business-only.png')])
guard = ['act', 'tap', '--selection', selection['id'], '--selection-revision', str(selection['revision']), '--runtime-instance-id', state['runtimeInstanceID']]
wrong_revision = guard.copy()
wrong_revision[wrong_revision.index('--selection-revision') + 1] = str(selection['revision'] + 1)
assert command('reject-wrong-revision', wrong_revision, 1)['error']['code'] == 'selection_revision_mismatch'
wrong_runtime = guard.copy()
wrong_runtime[-1] = 'another-runtime-instance'
assert command('reject-wrong-runtime', wrong_runtime, 1)['error']['code'] == 'selection_stale'
command('verify-after-rejections', ['verify', 'text-exists', 'Picker Clicks: 0'])
assert command('guarded-tap', guard)['ok']
# XCTest independently waits for 1 and checks that it stays 1. Do not send another tap.
summary = {'ok': True, 'checks': checks, 'target': target, 'postcondition': 'XCTest must separately confirm Picker Clicks: 1'}
(output / 'summary.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary))
