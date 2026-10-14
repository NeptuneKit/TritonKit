import argparse, json, subprocess, time
from pathlib import Path
parser=argparse.ArgumentParser(description="Validate only TritonKitTestFixture on an explicitly owned Simulator")
parser.add_argument('--triton',required=True); parser.add_argument('--simulator',required=True)
parser.add_argument('--target',required=True); parser.add_argument('--port',type=int,default=19421)
parser.add_argument('--lease',required=True); parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--display',default='1')
opts=parser.parse_args(); SIM=opts.simulator; TARGET=opts.target; LEASE=opts.lease; BIN=opts.triton; OUT=opts.output.resolve()
assert TARGET==f'triton:ios-simulator:{SIM}/app:com.neptunekit.tritonkit.testfixture', 'Only the explicitly owned public fixture is accepted'
OUT.mkdir(parents=True,exist_ok=True)
COMMON=['--target',TARGET,'--port',str(opts.port),'--json']; checks=[]; session=None; RUN=str(time.time_ns())

def cmd(name,args,expected=0):
 p=subprocess.run([BIN,*args],capture_output=True,text=True,timeout=35)
 (OUT/(name+'.json')).write_text(p.stdout)
 if p.stderr: (OUT/(name+'.stderr')).write_text(p.stderr)
 assert p.returncode==expected,(name,p.returncode,p.stdout,p.stderr)
 x=json.loads(p.stdout); checks.append(name); return x

def tap(name,identifier):
 return cmd(name,['act','tap',identifier,*COMMON,'--lease',LEASE])
def find(name,identifier):
 return cmd(name,['act','find',identifier,'--all',*COMMON])
def hierarchy(name):
 x=cmd(name,['debug','hierarchy',*COMMON]); nodes={}
 def walk(v):
  if isinstance(v,dict):
   if 'viewObject' in v:nodes[v['viewObject']['oid']]=v
   for vv in v.values():walk(vv)
  elif isinstance(v,list):
   for vv in v:walk(vv)
 walk(x);return nodes

def shot(name):
 return cmd(name,['sim','screenshot','--simulator',SIM,'--display',opts.display,'--output',str(OUT/(name+'.png')),'--json'])
def spec(items):return json.dumps({'items':[{'markID':m,'selector':{'identifier':i}} for m,i in items]})
BOTH=[('primary','fixture.highlight.target'),('nil','fixture.highlight.nil')]
S=spec(BOTH)
def apply(name,s=S,ttl=120,expected=0):
 global session
 x=cmd(name,['highlight','apply','--spec',s,'--operation-id',RUN+'-'+name,'--ttl',str(ttl),*COMMON],expected)
 if x.get('sessionID') and x.get('ok'):session=x['sessionID']
 return x

def clear(name,marks=[],expected=0):
 return cmd(name,['highlight','clear','--session',session,*sum((['--mark',m] for m in marks),[]),*COMMON],expected)
def status(name):return cmd(name,['highlight','status','--session',session,*COMMON])
try:
 tap('reset-original','fixture.highlight.reset')
 p=find('find-primary','fixture.highlight.target'); n=find('find-nil','fixture.highlight.nil'); oid=p['viewOID']; nid=n['viewOID']
 assert len({c['viewOID'] for c in find('same-text-two-candidates','Highlight Target')['candidates']})==2
 orig=hierarchy('before'); assert orig[oid]['layerBorderWidth']==1 and orig[nid]['layerBorderWidth']==0 and 'layerBorderColor' not in orig[nid]
 shot('before')
 a=apply('apply-two'); assert a['ok'] and a['state']=='active' and len(a['marks'])==2
 replay=cmd('replay-apply',['highlight','apply','--spec',S,'--operation-id',RUN+'-apply-two','--ttl','120',*COMMON]); assert replay['sessionID']==session and replay['expiresAt']==a['expiresAt']
 h=hierarchy('during'); assert h[oid]['layerBorderWidth']==h[nid]['layerBorderWidth']==3
 for k in (oid,nid):assert h[k]['frame']==orig[k]['frame'] and h[k]['bounds']==orig[k]['bounds']
 tap('click-during','fixture.highlight.read'); assert 'changed/3.0' in find('readback-during','fixture.highlight.readback')['label']
 shot('highlighted')
 e=clear('unknown-mark',['missing'],1);assert e['error']['code']=='validation_failed'
 e=apply('busy-other',expected=1);assert e['error']['code']=='highlight_busy'
 c=clear('clear-primary',['primary']); assert c['state']=='partially_active' and not c['cleanupComplete']
 h=hierarchy('partial');assert h[oid]['layerBorderWidth']==1 and h[nid]['layerBorderWidth']==3
 tap('read-partial','fixture.highlight.read');shot('partial-clear')
 c=clear('clear-all'); assert c['cleanupComplete'] and c['restorationVerified'] and c['residualState']=='none'
 h=hierarchy('restored'); assert h[oid]['layerBorderColor']==orig[oid]['layerBorderColor'] and h[oid]['layerBorderWidth']==1 and h[nid]['layerBorderWidth']==0 and 'layerBorderColor' not in h[nid]
 tap('read-restored','fixture.highlight.read'); shot('restored'); clear('clear-again')
 replay=cmd('replay-closed',['highlight','apply','--spec',S,'--operation-id',RUN+'-apply-two','--ttl','120',*COMMON]);assert replay['state']=='closed'
 h=hierarchy('no-reapply');assert h[nid]['layerBorderWidth']==0
 apply('ttl-two-seconds',spec([BOTH[0]]),2);time.sleep(2.3);c=status('ttl-expired');assert c['state']=='closed' and c['restorationVerified']
 h=hierarchy('ttl-restored');assert h[oid]['layerBorderWidth']==1
 apply('business-conflict',spec([BOTH[0]]));tap('business-change-color','fixture.highlight.change')
 c=clear('clear-conflict',expected=1);assert c['state']=='needs_attention' and not c['cleanupComplete'] and c['residualState']=='possible' and c['error']['code']=='highlight_restore_conflict'
 h=hierarchy('conflict');assert h[oid]['layerBorderWidth']==3 and h[oid]['layerBorderColor']['green']>0.5
 shot('business-conflict')
 tap('business-resets-original','fixture.highlight.reset');c=status('conflict-resolved');assert c['cleanupComplete'] and c['residualState']=='none'
 apply('after-conflict');clear('final-clear');session=None
 (OUT/'summary.json').write_text(json.dumps({'ok':True,'checks':checks,'platform':'iOS Simulator','layoutUnchanged':True,'clickDuringHighlight':True,'realPropertyReadback':True},indent=2))
 print(json.dumps({'ok':True,'checks':len(checks),'output':str(OUT)}))
finally:
 if session:
  try:clear('cleanup-owned')
  except Exception:pass
