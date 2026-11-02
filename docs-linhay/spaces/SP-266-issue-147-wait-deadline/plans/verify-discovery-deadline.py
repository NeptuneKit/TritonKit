#!/usr/bin/env python3
"""Exercise one explicit CLI binary against a synthetic HDC; no device access."""
import argparse, hashlib, json, os, pathlib, subprocess, tempfile, time
p=argparse.ArgumentParser()
p.add_argument('--binary',required=True,type=pathlib.Path)
p.add_argument('--output',required=True,type=pathlib.Path)
a=p.parse_args()
binary=a.binary.resolve()
a.output.mkdir(parents=True,exist_ok=False)
results=[]
for name,verbose,plain,connected,timeout,expected in [
 ('slow-verbose',10,0,False,2,'harmony_discovery_timeout'),
 ('custom-tool',10,0,False,2,'harmony_discovery_timeout'),
 ('slow-fallback',0.05,10,False,2,'harmony_discovery_timeout'),
 ('condition-timeout',0,0,True,2,'condition-timeout'),
 ('fast-missing',0,0,False,2,'target_not_found')]:
 with tempfile.TemporaryDirectory(prefix='sp266-') as td:
  root=pathlib.Path(td); tool=root/('custom-hdc' if name=='custom-tool' else 'hdc')
  verbose_command=f'exec /bin/sleep {verbose}' if verbose>=1 else f'/bin/sleep {verbose}' if verbose else ':'
  plain_command=f'exec /bin/sleep {plain}' if plain>=1 else f'/bin/sleep {plain}' if plain else ':'
  tool.write_text(f'''#!/bin/sh
root='{root}'
printf '%s\\n' "$*" >> "$root/calls"
printf '%s' "$$" > "$root/pid"
if [ "$1" = list ] && [ "$2" = targets ]; then
 if [ "$3" = -v ]; then
  {verbose_command}
 else
  {plain_command}
 fi
 {'echo "fake-one TCP Connected localhost"' if connected else ':'}
elif [ "$3" = shell ]; then
 echo 'DumpLayout saved to: /data/local/tmp/sp266.json'
elif [ "$3" = file ] && [ "$4" = recv ]; then
 for path in "$@"; do :; done
 printf '%s' '{{"attributes":{{"text":"Other","bounds":"[0,0][100,50]"}}}}' > "$path"
 echo 'File recv finish'
else
 exit 9
fi
''')
  tool.chmod(0o700)
  argv=[str(binary),'wait','--platform','harmony','--target','fake-one','--text','Absent','--hdc',str(tool),'--timeout',str(timeout),'--json']
  start=time.monotonic();r=subprocess.run(argv,capture_output=True,text=True,timeout=10);elapsed=time.monotonic()-start
  value=json.loads(r.stdout)
  calls=(root/'calls').read_text().splitlines() if (root/'calls').exists() else []
  alive=False
  if (root/'pid').exists():
   try: os.kill(int((root/'pid').read_text()),0);alive=True
   except ProcessLookupError: pass
  got='condition-timeout' if value.get('timedOut') is True and not value.get('matched') else value.get('error',{}).get('code')
  ok=r.returncode!=0 and got==expected and elapsed<timeout+0.8 and not alive
  if name=='condition-timeout': ok=ok and value.get('pollCount',0)>0 and value.get('elapsedMs',0)>0
  if name=='slow-verbose': ok=ok and calls==['list targets -v']
  results.append(dict(case=name,ok=ok,elapsed=elapsed,timeout=timeout,result=value,exitCode=r.returncode,stderr=r.stderr,calls=calls,childAlive=alive))
report=dict(ok=all(x['ok'] for x in results),binary=str(binary),sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),scope='synthetic HDC only; no native tools or devices',cases=results)
(a.output/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='cases'}))
raise SystemExit(0 if report['ok'] else 1)
