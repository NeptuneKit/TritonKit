#!/usr/bin/env python3
"""Explicit owned single native container shallow metadata; no verified bundle identity or content."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser()
for n in ['triton','ownership','output-directory']: p.add_argument('--'+n,required=True)
p.add_argument('--allow-owned-boot',required=True,action='store_true'); a=p.parse_args(); os.umask(0o077)
binary=str(Path(a.triton).resolve(strict=True)); root=Path(a.output_directory).resolve(); root.mkdir(parents=True,mode=0o700,exist_ok=False)
owner=json.loads(Path(a.ownership).read_text()); assert owner['ownedBy']=='SP-183-current-acceptance' and owner['creation']['ok'] and owner['creation']['action']=='sim.create'; sid=owner['creation']['udid'].upper()
def cli(name,args,expected=0):
    result=subprocess.run([binary,*args,'--json'],capture_output=True,text=True,timeout=180)
    (root/(name+'.json')).write_text(result.stdout); (root/(name+'.stderr')).write_text(result.stderr)
    body=json.loads(result.stdout); assert result.returncode==expected,name+': inspect private evidence'; return body
schema=cli('schema',['schema','--command','device']); assert '--container-identifier' in json.dumps(schema) and 'directoryToken' in json.dumps(schema)
for index,(view,identifier) in enumerate([('mount-root','valid-component'),('app-data-containers','PRIVATE/../escape'),('app-group-containers','..'),('app-group-containers','')]):
    failure=cli('invalid-'+str(index),['device','fs','list','--view',view,'--container-identifier',identifier,'--device','intentionally-no-such-device'],1)
    assert failure['error']['code']=='parameter_conflict' and 'PRIVATE' not in json.dumps(failure)
before=cli('before',['device','list','--platform','ios','--scope','simulator'])['targets']; owned=[t for t in before if t['target'].upper()==sid]; assert len(owned)==1 and owned[0]['state']=='Shutdown' and owned[0]['name']==owner['name']
summary={'fullIntegrationComplete':False,'verifiedBundleGroupIdentity':False,'physicalQuery':False,'contentsRead':False,'deviceFSWrites':False,'views':{}}
try:
    cli('boot',['sim','boot',sid,'--wait','--timeout','120'])
    for view in ['app-data-containers','app-group-containers']:
        base=['device','fs','list','--device','sim:'+sid,'--scope','simulator','--view',view,'--timeout','30']
        namespace=cli(view+'-namespace-opt-in',[*base,'--include-sensitive'])
        candidates=sorted(e['name'] for e in namespace['entries'] if e['kind']=='directory'); assert candidates,'Actual namespace has no container candidate'
        identifier=candidates[0]; args=[*base,'--container-identifier',identifier]
        public=cli(view+'-container-default',args); sensitive=cli(view+'-container-opt-in',[*args,'--include-sensitive'])
        assert public['ok'] and public['action']=='device.fs.list' and public['target']['id']=='sim:'+sid and public['view']==view
        assert public['directoryToken'].startswith('directory:') and len(public['directoryToken'])==74 and public['directoryToken']==sensitive['directoryToken']
        assert public['count']==len(public['entries'])==sensitive['count'] and {e['token'] for e in public['entries']}=={e['token'] for e in sensitive['entries']}
        for e in public['entries']: assert set(e)<={'token','kind','sizeBytes'} and e['token'].startswith('file:')
        for e in sensitive['entries']: assert set(e)<={'token','kind','sizeBytes','name'} and 'name' in e
        for output in [public,sensitive]:
            assert 'containerIdentifier' not in output and 'relativePath' not in output
            # Opt-in leaf metadata may coincidentally match the requested name. It is not a scope echo.
            checked=json.loads(json.dumps(output))
            for entry in checked['entries']: entry.pop('name',None)
            assert identifier not in json.dumps(checked), 'requested identifier must not appear outside explicitly opt-in leaf names'
            assert output['hostFilesystemInspected']
            for flag in ['contentsRead','recursive','mountStateVerified','readWriteAuthorizationVerified','businessReadinessVerified']: assert output[flag] is False
            private=json.loads(Path(output['artifacts'][0]).read_text()); native=private['result']['dataPath']; assert native not in json.dumps(output)
            for command in output['sourceCommands']: assert native not in command and identifier not in command and sid not in command
            for artifact in output['artifacts']:
                path=Path(artifact); assert path.parent.stat().st_mode & 0o777==0o700 and path.stat().st_mode & 0o777==0o600
        limited=False
        if public['count']>1:
            assert cli(view+'-entry-bound',[*args,'--max-entries','1'],1)['error']['code']=='device_fs_limit_exceeded'; limited=True
        assert cli(view+'-json-bound',[*args,'--max-json-bytes','1'],1)['error']['code']=='device_mountpoint_limit_exceeded'
        summary['views'][view]={'count':public['count'],'explicitOneNativeChildFromOptInNamespace':True,'requestedIdentifierPrivateEvenOptIn':True,'entryNamesOnlyOptIn':True,'directoryAndEntryTokensStable':True,'privateArtifacts07000600':True,'entryLimitActualRejected':limited,'JSONLimitActualRejected':True,'emptyWouldNotProveInstalledApp':True}
finally:
    cli('shutdown',['sim','shutdown',sid])
after=cli('after',['device','list','--platform','ios','--scope','simulator'])['targets']; assert {t['id']:(t['name'],t['state']) for t in before}=={t['id']:(t['name'],t['state']) for t in after}
summary['isolation']={'ownedFinalState':'Shutdown','allSimulatorNamesStatesUnchanged':True}
(root/'20261009-devicefs-container-summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print('Owned explicit single-container shallow metadata privacy/budgets/restoration accepted')
