#!/usr/bin/env python3
"""Owned fixed DeviceFS container namespace metadata, no content/domain-ID mapping."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser()
for name in ['triton','ownership','output-directory']: p.add_argument('--'+name,required=True)
p.add_argument('--allow-owned-boot',required=True,action='store_true')
a=p.parse_args(); os.umask(0o077)
binary=Path(a.triton).resolve(strict=True); root=Path(a.output_directory).resolve(); root.mkdir(parents=True,mode=0o700,exist_ok=False)
owner=json.loads(Path(a.ownership).read_text()); assert owner['ownedBy']=='SP-183-current-acceptance' and owner['creation']['ok'] and owner['creation']['action']=='sim.create'
sid=owner['creation']['udid'].upper()
summary={'fullIntegrationComplete':False,'domainIdentifierNavigation':False,'physicalQuery':False,'fileContentsFetched':False,'deviceFSWrites':False}
def cli(name,argv,expected=0):
    r=subprocess.run([str(binary),*argv,'--json'],capture_output=True,text=True,timeout=180)
    (root/(name+'.json')).write_text(r.stdout); (root/(name+'.stderr')).write_text(r.stderr)
    body=json.loads(r.stdout); assert r.returncode==expected,name+': inspect private evidence'
    return body
schema=cli('20261009-schema',['schema','--command','device']); assert 'app-data-containers' in json.dumps(schema) and 'app-group-containers' in json.dumps(schema)
before=cli('20261009-before',['device','list','--platform','ios','--scope','simulator'])['targets']
owned=[d for d in before if d['target'].upper()==sid]; assert len(owned)==1 and owned[0]['name']==owner['name'] and owned[0]['state']=='Shutdown'
try:
    cli('20261009-boot',['sim','boot',sid,'--wait','--timeout','120'])
    summary['views']={}
    for view in ['mount-root','app-data-containers','app-group-containers']:
        base=['device','fs','list','--device','sim:'+sid,'--scope','simulator','--view',view,'--timeout','30']
        public=cli('20261009-'+view+'-default',base)
        sensitive=cli('20261009-'+view+'-opt-in',[*base,'--include-sensitive'])
        assert public['ok'] and public['view']==view and public['backend']=='devicefs' and public['target']['id']=='sim:'+sid
        assert public['count']==len(public['entries'])==sensitive['count']
        assert public['hostFilesystemInspected']
        for flag in ['contentsRead','recursive','mountStateVerified','readWriteAuthorizationVerified','businessReadinessVerified']: assert public[flag] is False
        assert {e['token'] for e in public['entries']}=={e['token'] for e in sensitive['entries']}
        for entry in public['entries']:
            assert set(entry)<= {'token','kind','sizeBytes'} and entry['token'].startswith('file:')
            if entry['kind']!='regular-file': assert 'sizeBytes' not in entry
        for entry in sensitive['entries']: assert set(entry)<= {'token','kind','sizeBytes','name'} and 'name' in entry
        for output in [public,sensitive]:
            private=json.loads(Path(output['artifacts'][0]).read_text()); assert private['result']['dataPath'] not in json.dumps(output)
            for command in output['sourceCommands']: assert sid not in command and private['result']['dataPath'] not in command
            for artifact in output['artifacts']:
                path=Path(artifact); assert path.parent.stat().st_mode & 0o777==0o700 and path.stat().st_mode & 0o777==0o600
        limited=False
        if public['count']>1:
            assert cli('20261009-'+view+'-entry-budget',[*base,'--max-entries','1'],1)['error']['code']=='device_fs_limit_exceeded'; limited=True
        assert cli('20261009-'+view+'-json-budget',[*base,'--max-json-bytes','1'],1)['error']['code']=='device_mountpoint_limit_exceeded'
        summary['views'][view]={'entryCount':public['count'],'emptyIsNotAppExistenceEvidence':True,'defaultEntryNamePrivate':True,'namesOnlyOptIn':True,'stableFreshQueryTokens':True,'artifactPermissions07000600Verified':True,'nativePathPrivate':True,'actualEntryLimitRejected':limited,'entryLimitReason': 'actual max1 rejection' if limited else '0 or 1 observed entry cannot demonstrate max1 overflow; bounded fixture coverage separate','actualJSONLimitRejected':True}
finally:
    cli('20261009-shutdown',['sim','shutdown',sid])
after=cli('20261009-after',['device','list','--platform','ios','--scope','simulator'])['targets']
assert {d['id']:(d['name'],d['state']) for d in before}=={d['id']:(d['name'],d['state']) for d in after}
summary['isolation']={'ownedFinalState':'Shutdown','allSimulatorNamesStatesUnchanged':True}
(root/'20261009-devicefs-namespace-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('Owned fixed container namespaces metadata privacy/bounds/restoration accepted')
