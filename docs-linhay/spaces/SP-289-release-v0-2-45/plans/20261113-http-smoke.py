#!/usr/bin/env python3
"""Readonly packaged Web smoke; one complete synthetic input DTO must be refused."""
from pathlib import Path
import argparse, hashlib, json, re, urllib.error, urllib.parse, urllib.request
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--base-url',required=True)
p.add_argument('--raw-dir',type=Path,required=True)
p.add_argument('--report',type=Path,required=True)
a=p.parse_args();base=a.base_url.rstrip('/');origin=urllib.parse.urlsplit(base)
assert origin.scheme=='http' and origin.hostname in ('127.0.0.1','localhost') and origin.port
assert not a.raw_dir.exists();a.raw_dir.mkdir(mode=0o700,parents=True)
records=[]
def fetch(path,method='GET',body=None):
    url=urllib.parse.urljoin(base+'/',path)
    parsed=urllib.parse.urlsplit(url);assert parsed.scheme==origin.scheme and parsed.netloc==origin.netloc
    headers={'Content-Type':'application/json'} if body is not None else {}
    req=urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
    try:response=urllib.request.urlopen(req,timeout=30)
    except urllib.error.HTTPError as error:response=error
    with response:
        data=response.read(8*1024*1024+1);assert len(data)<=8*1024*1024
        status=response.status;content_type=response.headers.get('Content-Type','')
    suffix='json' if 'json' in content_type else 'html' if 'html' in content_type else 'bin'
    file=a.raw_dir/(f'{len(records):02d}.'+suffix);file.write_bytes(data)
    records.append({'method':method,'path':path,'status':status,'contentType':content_type,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'privateRawFile':file.name})
    return status,data
status,html=fetch('/');assert status==200
text=html.decode();assert '/@vite/client' not in text,'Unexpected Vite dev shell'
js=re.findall(r'<script[^>]+src="([^"]+)"',text)
css=[href for href in re.findall(r'<link[^>]+href="([^"]+)"',text) if href.split('?')[0].endswith('.css')]
assert js and css,'No bundled script/style found'
for path in js+css:
    status,_=fetch(path);assert status==200,path
status,data=fetch('/web/target-registry');assert status==200
registry=json.loads(data);assert isinstance(registry,dict)
dto={'target':'host:ios:release-probe','type':'tap','x':10,'y':10,'width':400,'height':800}
status,data=fetch('/web/host-input','POST',dto);payload=json.loads(data)
assert status==405 and payload.get('error',{}).get('code')=='web_host_input_readonly',payload
result={'status':'pass','origin':base,'scriptCount':len(js),'styleCount':len(css),'registryKeys':sorted(registry),'inputProbe':{'syntheticNonDeviceTarget':True,'completeDTO':dto,'expectedStatus':405,'expectedCode':'web_host_input_readonly','nativeInputExecuted':False},'requests':records,'boundary':'HTTP/static-assets/readonly refusal only; raw registry bodies kept private, not device or stream acceptance'}
a.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'pass','scripts':len(js),'styles':len(css),'readonlyInputStatus':status},indent=2))
