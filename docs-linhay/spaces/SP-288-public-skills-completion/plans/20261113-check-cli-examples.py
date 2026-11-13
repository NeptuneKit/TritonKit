#!/usr/bin/env python3
"""Check new guide examples without running device actions or inference.
Help/schema checks are not full argument validation or provider acceptance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shlex
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cli', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[4]
cli = args.cli.resolve()
files = [root / ('TritonKit.skills/' + path) for path in (
    'tritonkit-dev-feedback/references/dsh-integration.md',
    'tritonkit-emulator-cli-takeover/references/http-api.md',
    'tritonkit-emulator-cli-takeover/references/target-leases.md',
    'tritonkit-emulator-cli-takeover/references/ui-inspection.md',
    'tritonkit-emulator-cli-takeover/references/web-preview.md',
    'tritonkit-emulator-cli-takeover/references/app-map.md',
    'tritonkit-emulator-cli-takeover/references/vlm-models.md',
    'tritonkit-real-project-regression/references/test-recorder.md',
)]
result = {'cliSha256': hashlib.sha256(cli.read_bytes()).hexdigest(),
          'version': json.loads(subprocess.check_output([str(cli), 'version', '--json'])),
          'helpChecks': [], 'schemaChecks': [], 'recorder': [],
          'boundary': 'offline helper/schema and synthetic recorder only; no device, server, model or live test'}
with tempfile.TemporaryDirectory(prefix='triton-skills-examples-') as directory:
    cwd = Path(directory)
    def run(argv):
        return subprocess.run([str(cli), *argv], cwd=cwd, capture_output=True, text=True, timeout=15)
    for file in files:
        text = file.read_text()
        for block in re.findall(r'```(?:bash|sh)\n(.*?)\n```', text, re.DOTALL):
            for line in block.replace('\\\n', ' ').splitlines():
                if not line.strip().startswith('triton '):
                    continue
                template_argv = shlex.split(line.strip(), comments=True)[1:]
                # The guide requires replacing discovered OIDs; use a syntactically valid
                # numeric fixture for help parsing, never resolve/execute that ID.
                argv = ['1' if value == '<oid>' else value for value in template_argv]
                check = run([*argv, '--help'])
                row = {'guide': file.relative_to(root).as_posix(), 'argv': argv,
                       'exitCode': check.returncode, 'usagePresent': 'USAGE:' in check.stdout}
                result['helpChecks'].append(row)
                if check.returncode != 0 or not row['usagePresent']:
                    raise SystemExit('Help check failed: ' + json.dumps(row) + '\n' + check.stderr)
                if argv[:1] == ['schema'] and '--command' in argv:
                    command = argv[argv.index('--command') + 1]
                    schema = run(['schema', '--command', command, '--json'])
                    payload = json.loads(schema.stdout)
                    result['schemaChecks'].append({'command': command, 'exitCode': schema.returncode})
                    if schema.returncode or payload.get('ok') is False:
                        raise SystemExit('Schema query failed: ' + command)
    case = cwd / 'sample.tritontestcase'
    def record(label, argv):
        command = run(argv)
        payload = json.loads(command.stdout)
        result['recorder'].append({'step': label, 'exitCode': command.returncode,
                                   'ok': payload.get('ok'), 'kind': payload.get('kind'),
                                   'eventCount': payload.get('eventCount')})
        if command.returncode or payload.get('ok') is False:
            raise SystemExit('Offline recording failed: ' + label + '\n' + command.stderr)
        return payload
    started = record('start', ['testrec', 'start', '--platform', 'ios', '--case', 'login-flow', '--output', str(case), '--json'])
    session = started['sessionId']
    record('route', ['testrec', 'event', '--session', session, '--kind', 'page-route', '--payload-json', '{"id":"p1","route":"login"}', '--json'])
    record('action', ['testrec', 'event', '--session', session, '--kind', 'action', '--payload-json', '{"id":"a1","kind":"tap","target":{"label":"Continue"}}', '--json'])
    stopped = record('stop', ['testrec', 'stop', '--session', session, '--json'])
    assert stopped['eventCount'] == 2
    record('inspect', ['testrec', 'inspect', str(case), '--json'])
    compile_result = run(['testrec', 'compile', str(case), '--json'])
    compiled = json.loads(compile_result.stdout)
    if compile_result.returncode or compiled.get('ok') is not True or compiled.get('status') != 'compiled':
        raise SystemExit('Offline compilation failed; no overall pass is published: ' + json.dumps({
            'exitCode': compile_result.returncode, 'ok': compiled.get('ok'), 'status': compiled.get('status')
        }))
    # A small explicit-event sample is deliberately not represented as a live verdict.
    result['recorder'].append({'step': 'compile', 'exitCode': compile_result.returncode,
                               'ok': compiled.get('ok'), 'kind': compiled.get('kind'),
                               'status': compiled.get('status'), 'liveVerdict': False})
assert len(result['helpChecks']) >= 20
result['status'] = 'pass'
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(f"Passed {len(result['helpChecks'])} help checks, {len(result['schemaChecks'])} schema queries and synthetic recorder flow.")
