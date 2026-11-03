"""Isolated direct-runtime acceptance. Usage: python3 http-fixture.py BINARY NEW_OUTPUT_DIR [--baseline]."""
import hashlib,http.server,json,pathlib,socket,subprocess,sys,threading
binary=sys.argv[1]; out=pathlib.Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=False)
calls=[]; provider={'ok':False,'action':'webview.snapshot','platform':'harmony','target':'fixture','error':{'code':'webview_provider_unavailable','message':'Fixture has no provider','hint':'Use a provider-enabled fixture'}}
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  body=self.rfile.read(int(self.headers.get('Content-Length','0'))); calls.append({'port':self.server.server_port,'path':self.path,'method':'POST','body':json.loads(body)})
  payload=json.dumps(provider).encode(); self.send_response(self.server.fixture_status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
servers=[]
for status in [200,503,200]:
 server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);server.fixture_status=status;threading.Thread(target=server.serve_forever,daemon=True).start();servers.append(server)
blocked=socket.socket();blocked.bind(('127.0.0.1',0))
base=[binary,'webview','snapshot','--platform','harmony','--target','__isolated_fixture__','--host','127.0.0.1','--port',str(servers[2].server_port),'--include','metadata,text','--json']
results=[]
try:
 for name,port in [('provider200',servers[0].server_port),('provider503',servers[1].server_port),('unavailable',blocked.getsockname()[1]),('missing',None)]:
  args=base+(['--runtime-base-url',f'http://127.0.0.1:{port}/ignored/base?ignored=1'] if port else [])
  p=subprocess.run(args,text=True,capture_output=True,timeout=20); r={'case':name,'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'json':json.loads(p.stdout)};results.append(r)
 for r in results:
  assert r['exit']!=0
 assert results[0]['json']==provider
 assert len(calls)==2 and all(c['port']!=servers[2].server_port for c in calls)
 assert all(c['path']=='/v2/runtime/webview/snapshot' and c['body']=={'include':['metadata','text']} for c in calls)
 diagnostics=results[2]['json'];error=diagnostics['error'];expected=f'http://127.0.0.1:{blocked.getsockname()[1]}/v2/runtime/webview/snapshot'
 accepted=error.get('endpoint')==expected and diagnostics.get('platform')=='harmony' and diagnostics.get('target')=='__isolated_fixture__' and 'iOS' not in error.get('hint','') and 'nextAction' not in error
 assert 'requires --runtime-base-url' in results[3]['json']['error']['message']
 assert results[3]['json']['error'].get('nextAction',{}).get('command')!='serve'
 summary={'binarySHA256':hashlib.sha256(pathlib.Path(binary).read_bytes()).hexdigest(),'binary':binary,'results':results,'requests':calls,'expectedEndpoint':expected,'diagnosticsAccepted':accepted,'provider200Preserved':results[0]['json']==provider,'provider503Preserved':results[1]['json']==provider,'serverOptionRequests':sum(c['port']==servers[2].server_port for c in calls)}
 (out/'result.json').write_text(json.dumps(summary,indent=2)); print(json.dumps({k:v for k,v in summary.items() if k not in ['results','requests']},indent=2))
 if '--baseline' not in sys.argv[3:]:
  assert accepted and summary['provider503Preserved'], 'Direct runtime diagnostics regression'
finally:
 blocked.close()
 for s in servers: s.shutdown();s.server_close()
