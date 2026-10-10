#!/usr/bin/env python3
"""Explicit owned-Simulator DeviceFS mount-root metadata; no content or domain traversal."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--triton',required=True)
p.add_argument('--ownership',required=True)
p.add_argument('--output-directory',required=True)
p.add_argument('--allow-owned-boot',action='store_true',required=True)
a=p.parse_args(); os.umask(0o077)
binary=Path(a.triton).resolve(strict=True)
root=Path(a.output_directory).resolve(); root.mkdir(mode=0o700,parents=True,exist_ok=False)
owner=json.loads(Path(a.ownership).read_text())
assert owner['ownedBy']=='SP-183-current-acceptance' and owner['creation']['ok'] and owner['creation']['action']=='sim.create'
sid=owner['creation']['udid'].upper()
summary={'fullIntegrationComplete':False,'domainNavigationImplemented':False,'physicalQuery':False,'fileContentsFetched':False,'deviceFSWrites':False}
def check(name,argv,expected=0):
    r=subprocess.run([str(binary),*argv,'--json'],capture_output=True,text=True,timeout=180)
    (root/('20261009-'+name+'.json')).write_text(r.stdout)
    (root/('20261009-'+name+'.stderr')).write_text(r.stderr)
    body=json.loads(r.stdout)
    assert r.returncode==expected,name+': inspect private evidence'
    summary[name]={'exitCode':r.returncode,'ok':body.get('ok'),'errorCode':body.get('error',{}).get('code')}
    return body
base=['device','fs','list']
assert 'host.device-fs-list' in json.dumps(check('schema',['schema','--command','device']))
for name,argv,code in [('platform',[*base,'--platform','android'],'unsupported_device_fs_platform'),('timeout',[*base,'--timeout=-1'],'parameter_conflict'),('entries',[*base,'--max-entries','0'],'parameter_conflict')]:
    assert check(name,argv,1)['error']['code']==code
before=check('before',['device','list','--platform','ios','--scope','simulator'])['targets']
owned=[d for d in before if d['target'].upper()==sid]
assert len(owned)==1 and owned[0]['state']=='Shutdown' and owned[0]['name']==owner['name']
try:
    check('boot',['sim','boot',sid,'--wait','--timeout','120'])
    argv=[*base,'--device','sim:'+sid,'--scope','simulator','--timeout','30']
    output=check('root-default',argv)
    assert output['ok'] and output['action']=='device.fs.list' and output['target']['id']=='sim:'+sid
    assert output['backend']=='devicefs' and output['view']=='mount-root' and output['hostFilesystemInspected']
    for flag in ['contentsRead','recursive','mountStateVerified','readWriteAuthorizationVerified','businessReadinessVerified']: assert output[flag] is False
    assert output['verification']=='executed-file-json-and-descriptor-metadata'
    assert output['count']==len(output['entries']) and output['count']>1
    sensitive=check('root-opt-in',[*argv,'--include-sensitive'])
    assert sensitive['count']==output['count']
    assert {e['token'] for e in sensitive['entries']}=={e['token'] for e in output['entries']}
    for entry in output['entries']:
        assert entry['token'].startswith('file:') and 'name' not in entry and 'relativePath' not in entry
        assert set(entry)<= {'token','kind','sizeBytes'}
    # Names can coincide with harmless contract vocabulary (e.g. root in mount-root).
    # Check exact JSON string values, not arbitrary text substrings; whitelist above proves entry fields.
    def strings(value):
        if isinstance(value,str): return [value]
        if isinstance(value,list): return [s for v in value for s in strings(v)]
        if isinstance(value,dict): return [s for v in value.values() for s in strings(v)]
        return []
    for entry in sensitive['entries']: assert entry['name'] not in strings(output)
    for body in [output,sensitive]:
        private=json.loads(Path(body['artifacts'][0]).read_text())
        assert private['result']['dataPath'] not in json.dumps(body)
        for command in body['sourceCommands']: assert sid not in command and private['result']['dataPath'] not in command
        for artifact in body['artifacts']:
            path=Path(artifact); assert path.parent.stat().st_mode & 0o777==0o700 and path.stat().st_mode & 0o777==0o600
    assert check('entry-budget',[*argv,'--max-entries','1'],1)['error']['code']=='device_fs_limit_exceeded'
    assert check('json-budget',[*argv,'--max-json-bytes','1'],1)['error']['code']=='device_mountpoint_limit_exceeded'
    summary['acceptance']={'defaultNamesPrivate':True,'includeSensitiveNamesOnly':True,'tokensStableAcrossFreshQuery':True,'entryCount':output['count'],'actualEntryLimitRejected':True,'actualJSONLimitRejected':True,'privateArtifactPermissionsVerified':True,'nativePathPrivate':True,'noContentOrMountAuthorizationClaims':True}
finally:
    check('shutdown',['sim','shutdown',sid])
after=check('after',['device','list','--platform','ios','--scope','simulator'])['targets']
assert {d['id']:(d['name'],d['state']) for d in before}=={d['id']:(d['name'],d['state']) for d in after}
summary['isolation']={'ownedFinalState':'Shutdown','allSimulatorNamesStatesUnchanged':True}
(root/'20261009-devicefs-list-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('Owned explicit DeviceFS root metadata privacy/bounds/restoration accepted')
