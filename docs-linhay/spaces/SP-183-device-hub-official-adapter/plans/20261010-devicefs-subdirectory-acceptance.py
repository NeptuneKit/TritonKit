#!/usr/bin/env python3
"""Owned explicit container-relative selected-directory shallow metadata, no writes/content/recursive."""
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
schema=cli('schema',['schema','--command','device']); assert 'container-relative-directory' in json.dumps(schema)
for index,args in enumerate([['--subdirectory','Library'],['--view','app-data-containers','--container-identifier','id','--subdirectory','PRIVATE/../escape'],['--view','app-group-containers','--container-identifier','id','--subdirectory','/absolute'],['--view','app-group-containers','--container-identifier','id','--subdirectory','a//b']]):
    failure=cli('invalid-'+str(index),['device','fs','list','--device','intentionally-absent-device',*args],1)
    assert failure['error']['code']=='parameter_conflict' and 'PRIVATE' not in json.dumps(failure)
before=cli('before',['device','list','--platform','ios','--scope','simulator'])['targets']; owned=[t for t in before if t['target'].upper()==sid]; assert len(owned)==1 and owned[0]['state']=='Shutdown' and owned[0]['name']==owner['name']
summary={'fullIntegrationComplete':False,'physicalQuery':False,'contentsRead':False,'recursive':False,'deviceFSWrites':False,'verifiedBundleIdentity':False,'views':{}}
allowed={'ok','action','runtimeScope','riskLevel','backend','view','directoryToken','target','mountpointToken','entries','count','sensitiveMetadataIncluded','maximumJSONBytes','maximumEntries','recursive','hostFilesystemInspected','contentsRead','mountStateVerified','readWriteAuthorizationVerified','businessReadinessVerified','entryIdentityVerification','verification','limitSemantics','sourceCommands','artifacts'}
try:
    cli('boot',['sim','boot',sid,'--wait','--timeout','120'])
    for view in ['app-data-containers','app-group-containers']:
        base=['device','fs','list','--device','sim:'+sid,'--scope','simulator','--view',view,'--timeout','30']
        namespace=cli(view+'-namespace-opt-in',[*base,'--include-sensitive']); candidates=sorted(e['name'] for e in namespace['entries'] if e['kind']=='directory'); assert candidates
        identifier=candidates[0]; containerArgs=[*base,'--container-identifier',identifier]
        container=cli(view+'-container-opt-in',[*containerArgs,'--include-sensitive'])
        directories=sorted(e['name'] for e in container['entries'] if e['kind']=='directory'); assert directories,'No existing subdirectory; do not create one'
        selected='Library' if 'Library' in directories else directories[0]; args=[*containerArgs,'--subdirectory',selected]
        public=cli(view+'-selected-default',args); sensitive=cli(view+'-selected-opt-in',[*args,'--include-sensitive'])
        assert public['ok'] and public['action']=='device.fs.list' and public['view']==view and public['target']['id']=='sim:'+sid
        assert public['directoryToken']==sensitive['directoryToken'] and public['directoryToken']!=container['directoryToken']
        assert public['count']==len(public['entries'])==sensitive['count'] and {e['token'] for e in public['entries']}=={e['token'] for e in sensitive['entries']}
        for e in public['entries']: assert set(e)<={'token','kind','sizeBytes'}
        for e in sensitive['entries']: assert set(e)<={'token','kind','sizeBytes','name'} and 'name' in e
        for output in [public,sensitive]:
            # Static protocol words, diagnostic artifact paths and opt-in leaves may coincide with selected names.
            # Field whitelist establishes no selection-field echo; no whole-JSON substring false positives.
            assert set(output)<=allowed and 'subdirectory' not in output and 'containerIdentifier' not in output and 'relativePath' not in output
            assert output['hostFilesystemInspected']
            for flag in ['contentsRead','recursive','mountStateVerified','readWriteAuthorizationVerified','businessReadinessVerified']: assert output[flag] is False
            private=json.loads(Path(output['artifacts'][0]).read_text()); native=private['result']['dataPath']; assert native not in json.dumps(output)
            for command in output['sourceCommands']: assert native not in command and sid not in command and identifier not in command
            for artifact in output['artifacts']:
                path=Path(artifact); assert path.parent.stat().st_mode & 0o777==0o700 and path.stat().st_mode & 0o777==0o600
        entryLimit=False
        if public['count']>1:
            assert cli(view+'-entry-budget',[*args,'--max-entries','1'],1)['error']['code']=='device_fs_limit_exceeded'; entryLimit=True
        assert cli(view+'-json-budget',[*args,'--max-json-bytes','1'],1)['error']['code']=='device_mountpoint_limit_exceeded'
        summary['views'][view]={'count':public['count'],'existingDirectoryExplicitlySelected':True,'selectedDirectoryTokenDistinctFromContainer':True,'stableFreshQueryDirectoryAndEntryTokens':True,'defaultEntryNamesPrivate':True,'scopeFieldsNotEchoed':True,'optInLeafNamesOnly':True,'artifacts07000600':True,'actualEntryMax1Rejected':entryLimit,'entryLimitEvidence':'actual overflow' if entryLimit else '0 or 1 actual entry cannot prove max1 overflow; generic reader overflow fixtures separately accepted','actualJSONMax1Rejected':True,'emptyNotBusinessOrInstallationProof':True}
finally:
    cli('shutdown',['sim','shutdown',sid])
after=cli('after',['device','list','--platform','ios','--scope','simulator'])['targets']; assert {t['id']:(t['name'],t['state']) for t in before}=={t['id']:(t['name'],t['state']) for t in after}
summary['isolation']={'ownedFinalState':'Shutdown','allSimulatorNamesStatesUnchanged':True}
(root/'20261010-devicefs-subdirectory-summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print('Owned bounded container-relative directory metadata privacy/budgets/restoration accepted')
