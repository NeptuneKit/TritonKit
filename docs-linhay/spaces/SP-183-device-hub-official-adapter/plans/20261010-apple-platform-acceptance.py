#!/usr/bin/env python3
"""Validate actual readonly platform report envelopes, not platform control/actions."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--triton',required=True); p.add_argument('--output-directory',required=True); a=p.parse_args(); os.umask(0o077)
root=Path(a.output_directory).resolve(); root.mkdir(parents=True,mode=0o700,exist_ok=False); binary=str(Path(a.triton).resolve(strict=True))
def cli(name,args,code=0):
    r=subprocess.run([binary,*args,'--json'],capture_output=True,text=True,timeout=120)
    (root/(name+'.json')).write_text(r.stdout); (root/(name+'.stderr')).write_text(r.stderr)
    assert r.returncode==code,name+': inspect private evidence'; return json.loads(r.stdout)
schema=cli('schema',['schema','--command','device']); assert 'host.apple-platform-report' in json.dumps(schema)
base=cli('catalog',['device','platforms']); assert len(base['profiles'])==6 and not base['inventoryObserved'] and not base['simulatorCounts'] and not base['sourceCommands']
selected=cli('watch-catalog',['device','platforms','--apple-platform','watchos']); assert len(selected['profiles'])==1 and selected['profiles'][0]['family']=='watchos' and not selected['inventoryObserved']
invalid=cli('invalid-unknown',['device','platforms','--apple-platform','unknown','--inventory'],1); assert invalid['error']['code']=='parameter_conflict'
inventory=cli('inventory',['device','platforms','--inventory']); assert inventory['inventoryObserved'] and len(inventory['simulatorCounts'])==7 and len(inventory['sourceCommands'])==1
assert sum(row['count'] for row in inventory['simulatorCounts'])>0,'owned Simulator should be in available metadata; no fake count or boot'
assert next(row['count'] for row in inventory['simulatorCounts'] if row['family']=='ipados')==0
for body in [base,selected,inventory]:
    assert body['ok'] and body['riskLevel']=='readonly' and not body['physicalInventoryObserved'] and not body['actionsExecuted']
    assert all(not profile['actionsAuthorized'] and not profile['platformSpecificControlAccepted'] and profile['missingCapabilities'] and profile['verification']=='catalog-only-not-host-sdk-or-action-acceptance' for profile in body['profiles'])
    assert all(set(row)=={'family','count'} for row in body['simulatorCounts'])
    for key in ['targets','id','name','udid','rawRuntime','dataPath','rawTarget']: assert key not in body
summary={'fullIntegrationComplete':False,'catalogAndFilterAccepted':True,'defaultNoQueryEvidence':'Source guard + DI provider counter zero, not external process tracing','actualAvailableSimulatorMetadataAccepted':True,'actualAvailableSimulatorCount':sum(row['count'] for row in inventory['simulatorCounts']),'noRawInventoryIdentityOrNames':True,'unknownBeforeIOEvidence':'Actual parameter_conflict plus DI zero provider counter','legacyNamespaceIDsArgvChanged':False,'physicalInventoryOrPlatformControlsAccepted':False,'noLifecycleActions':True,'noIPadOSOrMacAssumedFromRuntimeOrNames':True,'zeroCountsNotUnavailableProof':True}
(root/'20261010-apple-platform-summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print('Apple catalog/filter/available Simulator metadata accepted; no control, physical inventory or lifecycle action acceptance')
