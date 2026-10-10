#!/usr/bin/env python3
"""Identity-bound actual readonly device info observation; no pairing/control/lifecycle."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--triton',required=True); p.add_argument('--output-directory',required=True); a=p.parse_args(); os.umask(0o077)
root=Path(a.output_directory).resolve(); root.mkdir(mode=0o700,parents=True,exist_ok=False); binary=str(Path(a.triton).resolve(strict=True))
def cli(name,args):
    r=subprocess.run([binary,*args,'--json'],capture_output=True,text=True,timeout=120)
    (root/(name+'.json')).write_text(r.stdout); (root/(name+'.stderr')).write_text(r.stderr)
    assert r.returncode==0,name+': inspect private evidence; do not pair/boot/fallback'; return json.loads(r.stdout)
schema=cli('schema',['schema','--command','device']); assert 'hardware.platformObservation.systemFamily' in json.dumps(schema)
devices=cli('discovery',['device','list','--platform','ios','--scope','real']); targets=sorted(t['id'] for t in devices['targets'] if t.get('scope')=='real' and t.get('kind')=='real-device'); assert targets,'No real readonly info target; no fabrication or pairing'
body=cli('info',['device','info','--platform','ios','--scope','real','--device',targets[0],'--timeout','30'])
assert body['ok'] and body['verification']=='executed-file-json' and body['riskLevel']=='readonly' and not body['businessReadinessVerified'] and not body['lockState']['requested']
assert body['target']['id']==targets[0] and body['target']['scope']=='real','Fresh identity-bound returned target must match selected public primary'
observation=body['hardware']['platformObservation']; assert observation['authority']=='explicit-sdk-hardware-only' and observation['sourceLayout'] in ['modern-properties-hardware','legacy-hardware-properties']
assert observation['systemFamily'] in ['ios','ipados','watchos','tvos','visionos','macos','unknown'] and observation['deviceFamily'] in ['iphone','ipad','watch','tv','spatial','mac','unknown'] and observation['reality'] in ['physical','simulated','unknown']
for key in ['legacyNamespaceIsOperatingSystemProof','actionCapabilitiesVerified','businessReadinessVerified']: assert observation[key] is False
assert set(observation)=={'systemFamily','deviceFamily','reality','sourceLayout','authority','legacyNamespaceIsOperatingSystemProof','actionCapabilitiesVerified','businessReadinessVerified'}
assert 'rawTargetAliases' not in json.dumps(body)
summary={'fullIntegrationComplete':False,'actualIdentityBoundReadonlyInfoAccepted':True,'observation':observation,'oldSelectorNamespaceDispatchArgvUnchanged':True,'metadataNotActionHardwareAuthenticityOrBusinessProof':True,'noPhysicalAdministrationOrSimulatorLifecycleActions':True,'legacySDKCompatibility':'Synthetic modern/legacy/Codable evidence only, no Xcode26 installation; fresh current SDK information only'}
(root/'20261010-hardware-observation-summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print('Actual fresh identity-bound readonly hardware observations accepted; no control, pairing or lifecycle acceptance')
