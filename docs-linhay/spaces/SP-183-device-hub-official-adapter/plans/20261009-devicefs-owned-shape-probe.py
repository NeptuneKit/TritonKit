#!/usr/bin/env python3
"""Owned-instance metadata-only protocol probe after a Triton schema gap.
No physical query, contents, installs, writes to DeviceFS, Finder or explicit mount.
"""
import argparse,json,os,stat,subprocess
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--triton',required=True); p.add_argument('--ownership',required=True); p.add_argument('--output-directory',required=True); p.add_argument('--allow-owned-boot',required=True,action='store_true'); a=p.parse_args()
os.umask(0o077)
r=Path(a.output_directory).resolve(); r.mkdir(parents=True,mode=0o700,exist_ok=False)
owner=json.loads(Path(a.ownership).read_text()); assert owner['ownedBy']=='SP-183-current-acceptance' and owner['creation']['ok'] and owner['creation']['action']=='sim.create'
sid=owner['creation']['udid'].upper(); binary=str(Path(a.triton).resolve(strict=True))
def cli(name,argv):
    result=subprocess.run([binary,*argv,'--json'],capture_output=True,text=True,timeout=180)
    (r/(name+'.json')).write_text(result.stdout); (r/(name+'.stderr')).write_text(result.stderr)
    assert result.returncode==0,name
    return json.loads(result.stdout)
schema=cli('20261009-schema-before',['schema','--command','device'])
assert 'host.device-fs-list' not in json.dumps(schema),'Use implemented Triton listing instead of probe'
before=cli('20261009-before',['device','list','--platform','ios','--scope','simulator'])['targets']
owned=[t for t in before if t['target'].upper()==sid]; assert len(owned)==1 and owned[0]['name']==owner['name'] and owned[0]['state']=='Shutdown'
fd=None
try:
    cli('20261009-boot',['sim','boot',sid,'--wait','--timeout','120'])
    output=cli('20261009-mountpoint',['device','mountpoint','--device','sim:'+sid,'--scope','simulator'])
    raw=json.loads(Path(output['artifacts'][0]).read_text())
    args=raw['info']['arguments']; assert args.count('--device')==1 and args[args.index('--device')+1]==sid
    native=raw['result']['dataPath']; base=str(Path.home()/'Library/Developer/CoreDevice/DeviceFS')
    assert native==base+'/device-'+sid+'.localized'
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC)
    for part in native.split('/')[1:]:
        child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=fd)
        os.close(fd); fd=child
    details=[]
    with os.scandir(fd) as entries:
        for entry in entries:
            if len(details)==30: raise RuntimeError('Owned root metadata entry bound exceeded')
            info=entry.stat(follow_symlinks=False)
            record={'name':entry.name,'mode':info.st_mode,'uid':info.st_uid,'gid':info.st_gid,'size':info.st_size,'isDirectory':stat.S_ISDIR(info.st_mode),'isSymlink':stat.S_ISLNK(info.st_mode)}
            if entry.name in ['DiagnosticReports','root'] and stat.S_ISDIR(info.st_mode):
                directory=os.open(entry.name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=fd)
                try:
                    with os.scandir(directory) as shallow:
                        children=[]
                        for leaf in shallow:
                            if len(children)==30: raise RuntimeError('Owned crash metadata entry bound exceeded')
                            item=leaf.stat(follow_symlinks=False); children.append({'name':leaf.name,'mode':item.st_mode,'size':item.st_size,'isSymlink':stat.S_ISLNK(item.st_mode)})
                        record['shallowMetadata']=children
                finally: os.close(directory)
            details.append(record)
    (r/'20261009-private-root-metadata.json').write_text(json.dumps({'rootMode':os.fstat(fd).st_mode,'rootUID':os.fstat(fd).st_uid,'entries':details},indent=2)+'\n')
finally:
    if fd is not None: os.close(fd)
    cli('20261009-shutdown',['sim','shutdown',sid])
after=cli('20261009-after',['device','list','--platform','ios','--scope','simulator'])['targets']
assert {t['id']:(t['name'],t['state']) for t in before}=={t['id']:(t['name'],t['state']) for t in after}
(r/'20261009-summary.json').write_text(json.dumps({'metadataOnly':True,'physicalQuery':False,'noDeviceFSWrites':True,'fileContentsFetched':False,'ownedFinalState':'Shutdown','allSimulatorNamesStatesUnchanged':True},indent=2)+'\n')
print('Owned root/DiagnosticReports shallow metadata probe restored all Simulator states')
