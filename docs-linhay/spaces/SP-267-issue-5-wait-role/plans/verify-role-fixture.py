#!/usr/bin/env python3
"""Run a real CLI against a synthetic HDC. No real device or backend access."""
import argparse, hashlib, json, pathlib, subprocess, time
p=argparse.ArgumentParser();p.add_argument('--triton',required=True);p.add_argument('--output',required=True)
a=p.parse_args();root=pathlib.Path(a.output).resolve();root.mkdir(parents=True,exist_ok=False)
exe=pathlib.Path(a.triton).resolve();fake=root/'fake-hdc';calls=root/'calls.jsonl'
fake.write_text('''#!/usr/bin/env python3
import sys,json,pathlib
args=sys.argv[1:]
with pathlib.Path(__file__).with_name('calls.jsonl').open('a') as f: f.write(json.dumps(args)+'\\n')
if args[:2]==['list','targets']: print('role-fixture\\tUSB\\tConnected')
elif 'aa' in args and 'dump' in args: print('[]')
elif 'dumpLayout' in args: print('DumpLayout saved to: /data/local/tmp/role-fixture.json')
elif 'recv' in args:
 def node(kind,text,y): return {'attributes':{'type':kind,'text':text,'bounds':f'[0,{y}][200,{y+20}]','enabled':'true','visible':'true'},'children':[]}
 tree={'attributes':{'type':'Column','bounds':'[0,0][200,600]'},'children':[node('Text','Item0',0),node('Button','Submit',40),node('Button','Different',80),node('Text','Shared',120),node('Button','Shared',160)]}
 pathlib.Path(args[-1]).write_text(json.dumps(tree));print('File recv finish')
else: sys.exit(2)
''');fake.chmod(0o755)
cases=[('text-no-role','--text','Item0',None,True),('exists-no-role','--exists','Item0',None,True),('text-correct-role','--text','Item0',' text ',True),('exists-correct-role','--exists','Submit','button',True),('text-wrong-role','--text','Item0','button',False),('exists-wrong-role','--exists','Item0','button',False),('text-absent','--text','Absent','button',False),('exists-absent','--exists','Absent','button',False),('same-node','--text','Shared','BUTTON',True),('gone-present','--gone','Submit','button',False),('gone-other-role','--gone','Item0','button',True),('gone-absent','--gone','Absent','button',True)]
report={'binary':str(exe),'sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'scope':'synthetic HDC only; no real UI/device acceptance','cases':[]}
for name,selector,text,role,expected in cases:
 cmd=[str(exe),'wait','--platform','harmony','--device','role-fixture','--hdc',str(fake),selector,text,'--timeout','3','--interval','0.05','--json']
 if role is not None:cmd+=['--role',role]
 start=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=8)
 (root/(name+'.stdout.json')).write_text(r.stdout);(root/(name+'.stderr.log')).write_text(r.stderr)
 try:
  v=json.loads(r.stdout)
  ok=v.get('matched') is expected and v.get('timedOut') is (not expected) and v.get('ok') is expected and (r.returncode==0)==expected and r.stderr==''
  if name=='same-node':ok=ok and v.get('match',{}).get('bounds',{}).get('y')==160
 except Exception:ok=False
 report['cases'].append({'name':name,'expectedMatched':expected,'exitCode':r.returncode,'elapsedSeconds':time.monotonic()-start,'passed':ok})
for selector in ['--text','--exists','--gone']:
 for role in ['', '   ']:
  name=selector[2:]+'-'+('empty' if role=='' else 'blank')+'-role'
  before=len(calls.read_text().splitlines()) if calls.exists() else 0
  cmd=[str(exe),'wait','--platform','harmony','--device','role-fixture','--hdc',str(fake),selector,'Item0','--role',role,'--timeout','3','--interval','0.05','--json']
  r=subprocess.run(cmd,capture_output=True,text=True,timeout=8)
  (root/(name+'.stdout.json')).write_text(r.stdout);(root/(name+'.stderr.log')).write_text(r.stderr)
  backend_calls=(len(calls.read_text().splitlines()) if calls.exists() else 0)-before
  try:
   v=json.loads(r.stdout);ok=r.returncode!=0 and r.stderr=='' and v.get('ok') is False and v.get('error',{}).get('code')=='validation_failed' and backend_calls==0
  except Exception:ok=False
  report['cases'].append({'name':name,'expectedError':'validation_failed','exitCode':r.returncode,'backendCalls':backend_calls,'passed':ok})
report['passed']=all(c['passed'] for c in report['cases']);(root/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));raise SystemExit(0 if report['passed'] else 1)
