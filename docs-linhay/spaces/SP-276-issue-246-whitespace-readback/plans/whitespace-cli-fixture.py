#!/usr/bin/env python3
"""Independent fake-HDC readback acceptance; never contacts a device."""
import json, os, pathlib, subprocess, sys, tempfile
binary = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix='triton-whitespace-') as root:
    root = pathlib.Path(root)
    hdc = root / 'fake-hdc'
    hdc.write_text('''#!/usr/bin/env python3
import json,os,sys,pathlib
args=sys.argv[1:]
if args==['-v']: print('hdc 6.0.0')
elif args==['list','targets','-v']: print('127.0.0.1:10100 TCP Connected localhost')
elif args==['list','targets']: print('127.0.0.1:10100')
elif args[:3]==['-t','127.0.0.1:10100','shell'] and args[3:]==['uitest','dumpLayout']: print('DumpLayout saved to:/data/local/tmp/triton-layout.json')
elif args[:4]==['-t','127.0.0.1:10100','file','recv']:
 pathlib.Path(args[-1]).write_text(json.dumps({'attributes':{'text':os.environ['SP276_TEXT'],'type':'TextArea','bounds':'[0,0][40,20]','focused':True}})); print('FileTransfer finish')
else: print('unexpected fake command',file=sys.stderr);sys.exit(2)
''')
    hdc.chmod(0o700)
    results=[]
    for text in ['   ', '\t\n', ' test ']:
        env=dict(os.environ,SP276_TEXT=text)
        args=[binary,'observe','tree','--platform','harmony','--target','127.0.0.1:10100','--hdc',str(hdc),'--output',str(root/'layout.json'),'--json']
        proc=subprocess.run(args,env=env,capture_output=True,text=True,timeout=15)
        data=json.loads(proc.stdout)
        def values(x):
            if isinstance(x,dict):
                if x.get('role')=='TextArea': yield x.get('text')
                for v in x.values(): yield from values(v)
            elif isinstance(x,list):
                for v in x: yield from values(v)
        observed=list(values(data))
        results.append({'expected':text,'observed':observed,'exitCode':proc.returncode,'pass':proc.returncode==0 and text in observed})
    print(json.dumps({'binary':binary,'fixture':'fake-hdc-layout-only','results':results,'passed':sum(x['pass'] for x in results)},ensure_ascii=False,indent=2))
    sys.exit(0 if all(x['pass'] for x in results) else 1)
