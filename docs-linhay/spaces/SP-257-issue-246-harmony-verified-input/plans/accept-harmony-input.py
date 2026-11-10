#!/usr/bin/env python3
"""Acceptance on the task-owned public ArkUI probe. Never replay an input."""
import argparse
import json
from pathlib import Path
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--triton', required=True)
p.add_argument('--device', required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--case', choices=['normal', 'duplicate', 'disabled', 'password', 'delayed', 'reject'], required=True)
p.add_argument('--text', default='SP257-M')
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
sequence = 0


def run(label, args):
    global sequence
    sequence += 1
    result = subprocess.run([a.triton, *args, '--json'], capture_output=True, timeout=80)
    stem = a.output / f'{sequence:02d}-{label}'
    stem.with_suffix('.json').write_bytes(result.stdout)
    stem.with_suffix('.stderr').write_bytes(result.stderr)
    value = json.loads(result.stdout)
    return result.returncode, value


def observe(label):
    code, tree = run(label, ['observe', 'tree', '--platform', 'harmony', '--device', a.device])
    assert code == 0 and tree['ok'], tree
    raw = Path(tree['artifacts'][0]).read_bytes()
    (a.output / f'{sequence:02d}-{label}-raw.json').write_bytes(raw)
    fields = []

    def visit(node):
        if isinstance(node, list):
            for item in node:
                visit(item)
        elif isinstance(node, dict):
            attrs = node.get('attributes', {})
            if attrs.get('id') in ('editor', 'probe-status', 'probe-value', 'probe-observed'):
                fields.append(attrs)
            visit(node.get('children', []))
    visit(json.loads(raw))
    return fields


code, selected = run('select-mode', ['act', 'tap', a.case.capitalize(), '--platform', 'harmony', '--device', a.device])
assert code == 0 and selected['ok'], selected
deadline = time.monotonic() + 8
while True:
    before = observe('before')
    if any(n.get('id') == 'probe-status' and n.get('text') == f'mode={a.case} changes=0' for n in before):
        break
    assert time.monotonic() < deadline, 'Probe mode did not settle; input was not attempted'
    time.sleep(0.2)

expected = a.text + '-settled' if a.case == 'delayed' else a.text
code, receipt = run('verified-input', ['act', 'type', '--platform', 'harmony', '--device', a.device,
    '--verify', '--selector', 'id:editor', '--text', a.text, '--expect-value', expected, '--timeout', '8'])
# Stop on uncertain delivery: no replay, reset, or alternative backend.
assert receipt['submission'] != 'unknown', receipt
after = observe('after')
statuses = [n['text'] for n in after if n.get('id') == 'probe-status']
assert len(statuses) == 1, f'Probe status unavailable after command; receipt={receipt}'
status = statuses[0]
editors = [n for n in after if n.get('id') == 'editor']
if a.case in ('normal', 'delayed'):
    assert code == 0 and receipt['ok'] and receipt['submission'] == 'submitted' and receipt['verification'] == 'match', receipt
    assert len(editors) == 1 and editors[0]['text'].encode() == expected.encode(), editors
    assert status == f'mode={a.case} changes=1', status
elif a.case == 'reject':
    assert code != 0 and not receipt['ok'] and receipt['submission'] == 'submitted', receipt
    assert receipt['verification'] == 'mismatch', receipt
    assert len(editors) == 1 and editors[0]['text'] == 'REJECTED', editors
    assert status == 'mode=reject changes=1', status
else:
    error = {'duplicate': 'harmony_input_ambiguous', 'disabled': 'harmony_input_not_editable',
             'password': 'harmony_input_secure_unsupported'}[a.case]
    assert code != 0 and not receipt['ok'] and receipt['submission'] == 'not-sent' and receipt['code'] == error, receipt
    assert status == f'mode={a.case} changes=0', status

summary = {'case': a.case, 'passed': True, 'receipt': receipt, 'independentStatus': status,
           'valueReadbackMatched': a.case in ('normal', 'delayed'), 'verifiedCommandInvocations': 1}
(a.output / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False))
