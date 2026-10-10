#!/usr/bin/env python3
"""Owned metadata-only diagnostic after explicit fs list read_failed, never content/link follow."""
import argparse,json,os,stat,subprocess
from pathlib import Path
p=argparse.ArgumentParser()
for n in ['triton','ownership','output-directory']: p.add_argument('--'+n,required=True)
p.add_argument('--allow-owned-boot',required=True,action='store_true'); a=p.parse_args(); os.umask(0o077)
r=Path(a.output_directory).resolve(); r.mkdir(parents=True,mode=0o700,exist_ok=False)
b=str(Path(a.triton).resolve(strict=True)); o=json.loads(Path(a.ownership).read_text()); assert o['ownedBy']=='SP-183-current-acceptance' and o['creation']['ok'] and o['creation']['action']=='sim.create'; sid=o['creation']['udid'].upper()
def cli(n,args,exit=0):
    result=subprocess.run([b,*args,'--json'],capture_output=True,text=True,timeout=180)
    (r/(n+'.json')).write_text(result.stdout); (r/(n+'.stderr')).write_text(result.stderr)
    body=json.loads(result.stdout); assert result.returncode==exit,n; return body
before=cli('before',['device','list','--platform','ios','--scope','simulator'])['targets']
owned=[t for t in before if t['target'].upper()==sid]; assert len(owned)==1 and owned[0]['state']=='Shutdown' and owned[0]['name']==o['name']
fd=None
try:
    cli('boot',['sim','boot',sid,'--wait','--timeout','120'])
    failed=cli('triton-first-read-failure',['device','fs','list','--device','sim:'+sid,'--scope','simulator','--view','app-data-containers'],1); assert failed['error']['code']=='device_fs_read_failed'
    mount=cli('mountpoint',['device','mountpoint','--device','sim:'+sid,'--scope','simulator'])
    private=json.loads(Path(mount['artifacts'][0]).read_text()); args=private['info']['arguments']; assert args.count('--device')==1 and args[args.index('--device')+1]==sid
    native=private['result']['dataPath']; assert native==str(Path.home())+'/Library/Developer/CoreDevice/DeviceFS/device-'+sid+'.localized'
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC)
    for part in native.split('/')[1:]:
        child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=fd); os.close(fd); fd=child
    assert os.fstat(fd).st_uid==os.getuid()
    result={}
    for namespace in ['AppDataContainers','AppGroupContainers']:
        child=os.open(namespace,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=fd)
        try:
            assert os.fstat(child).st_uid==os.getuid()
            import ctypes
            # SDK sys/mount.h __DARWIN_STRUCT_STATFS64: fstypename offset72, length16; overallocate output.
            libc=ctypes.CDLL(None); buffer=ctypes.create_string_buffer(4096)
            assert libc.fstatfs(child, ctypes.byref(buffer))==0
            filesystem=buffer.raw[72:88].split(b'\0')[0].decode('ascii',errors='strict')
            records=[{'descriptorFilesystemType':filesystem}]
            with os.scandir(child) as it:
                for entry in it:
                    if len(records)>=1000: raise RuntimeError('Local diagnostic entry bound')
                    record={'name':entry.name,'readdirInode':entry.inode()}
                    try:
                        info=entry.stat(follow_symlinks=False); record.update({'statInode':info.st_ino,'mode':info.st_mode,'size':info.st_size,'isSymlink':stat.S_ISLNK(info.st_mode)})
                        second=os.stat(entry.name,dir_fd=child,follow_symlinks=False); record['secondStatInode']=second.st_ino
                    except OSError as e: record['statErrno']=e.errno
                    records.append(record)
            result[namespace]=records
        finally: os.close(child)
    (r/'private-namespace-metadata.json').write_text(json.dumps(result,indent=2)+'\n')
finally:
    if fd is not None: os.close(fd)
    cli('shutdown',['sim','shutdown',sid])
after=cli('after',['device','list','--platform','ios','--scope','simulator'])['targets']
assert {t['id']:(t['name'],t['state']) for t in before}=={t['id']:(t['name'],t['state']) for t in after}
print('Owned failed-list metadata diagnostic restored all Simulator states; no content or link target reads')
