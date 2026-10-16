#!/usr/bin/env python3
"""Run the candidate CLI against isolated fake Homebrew; never mutates real installs."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('binary', type=Path)
args = parser.parse_args()
binary = args.binary.resolve()
results = []
with tempfile.TemporaryDirectory(prefix='triton-update-process-') as folder:
    root = Path(folder)
    fake_bin = root / 'bin'
    fake_bin.mkdir()
    prefix = root / 'Cellar/triton/999.0.0'
    (prefix / 'bin').mkdir(parents=True)
    brew = fake_bin / 'brew'
    brew.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
args=sys.argv[1:]
with open(os.environ['UPDATE_TEST_CALLS'], 'a') as f: f.write(json.dumps(args)+'\\n')
if args == ['info', '--json=v2', 'neptunekit/tap/triton']:
 print(json.dumps({'formulae':[{'versions':{'stable':os.environ['UPDATE_TEST_FORMULA']}}]}))
elif args == ['--prefix', 'neptunekit/tap/triton']:
 print(os.environ['UPDATE_TEST_PREFIX'])
elif args not in [['update'], ['upgrade', 'neptunekit/tap/triton']]:
 sys.exit(9)
''')
    brew.chmod(0o700)
    installed = prefix / 'bin/triton'
    installed.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
assert sys.argv[1:] == ['version', '--json']
print(json.dumps({'ok': True, 'version': os.environ['UPDATE_TEST_INSTALLED']}))
''')
    installed.chmod(0o700)
    calls = root / 'calls.jsonl'
    base_env = dict(os.environ, PATH=str(fake_bin)+os.pathsep+os.environ['PATH'], UPDATE_TEST_CALLS=str(calls), UPDATE_TEST_PREFIX=str(prefix), UPDATE_TEST_FORMULA='999.0.0', UPDATE_TEST_INSTALLED='999.0.0')
    old_path = str(root / 'Cellar/triton/0.2.19/bin/triton')
    def run(name, flags, *, formula='999.0.0', installed_version='999.0.0', expected_error=None):
        calls.write_text('')
        env=dict(base_env, UPDATE_TEST_FORMULA=formula, UPDATE_TEST_INSTALLED=installed_version)
        result=subprocess.run([str(binary),'update','--current-executable',old_path,'--json']+flags, env=env, capture_output=True,text=True,timeout=40)
        # json.loads rejects multiple envelopes and any trailing non-whitespace.
        output=json.loads(result.stdout)
        observed=[json.loads(line) for line in calls.read_text().splitlines()]
        if expected_error:
            assert result.returncode != 0 and output['ok'] is False, (name,result.returncode,output)
            assert output['error']['code']==expected_error, (name, output)
        else:
            assert result.returncode==0 and output['ok'] is True, (name,result.stderr,output)
        results.append({'case':name,'exitCode':result.returncode,'ok':output['ok'],'errorCode':output.get('error',{}).get('code'), 'hostCommandCount':len(observed)})
        return output, observed
    out, commands=run('check-is-readonly',['--version','999.0.0','--check'])
    assert out['targetVersion']=='999.0.0' and out['updateAvailable'] and not commands
    out, commands=run('confirmation-before-mutation',['--version','999.0.0'],expected_error='confirmation_required')
    assert not commands
    out, commands=run('invalid-target',['--version','garbage','--check'],expected_error='release_resolution_failed')
    assert not commands
    out, commands=run('stale-formula',['--version','999.0.0','--yes'],formula='0.2.24',expected_error='homebrew_version_mismatch')
    assert ['upgrade','neptunekit/tap/triton'] not in commands
    out, commands=run('wrong-installed-version',['--version','999.0.0','--yes'],installed_version='0.2.24',expected_error='installed_version_mismatch')
    assert out['cliUpdateAttempted'] and not out['updated']
    assert out['targetVersion']=='999.0.0' and out['installSource']=='homebrew'
    out, commands=run('verified-upgrade',['--version','999.0.0','--yes'])
    assert out['cliUpdateAttempted'] and out['updated'] and out['installedVersion']=='999.0.0'
    assert out['skillsUpdated'] is False
print(json.dumps({'ok':True,'scope':'candidate CLI process with isolated fake Homebrew; no real installation update','cases':results},indent=2))
