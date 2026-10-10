#!/usr/bin/env python3
"""Real SDK read-only policy-plan envelopes; no operation execution/collection.
Native nonexecution assurance is source review + DI tests, NOT process tracing.
Triton pins /usr/bin/xcrun, so PATH interception is intentionally not a proof.
"""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--triton',required=True); p.add_argument('--output-directory',required=True); a=p.parse_args(); os.umask(0o077)
root=Path(a.output_directory).resolve(); root.mkdir(parents=True,mode=0o700,exist_ok=False); binary=str(Path(a.triton).resolve(strict=True))
def cli(name,args,expected=0):
    r=subprocess.run([binary,*args,'--json'],capture_output=True,text=True,timeout=180)
    (root/(name+'.json')).write_text(r.stdout); (root/(name+'.stderr')).write_text(r.stderr)
    assert r.returncode==expected,name+': inspect private evidence'; return json.loads(r.stdout)
schema=cli('schema',['schema','--command','device']); assert 'host.device-administration-plan' in json.dumps(schema)
for n,args in enumerate([['pair','--device','PRIVATE-MISSING'],['unpair','--device','PRIVATE-MISSING','--plan-only','--scope','simulator'],['diagnose','--device','PRIVATE-MISSING','--plan-only'],['diagnose','--device','PRIVATE-MISSING','--plan-only','--output','PRIVATE\n.zip']]):
    body=cli('invalid-'+str(n),['device',*args],1); assert body['error']['code']=='parameter_conflict' and 'PRIVATE' not in json.dumps(body)
devices=cli('discovery',['device','list','--platform','ios','--scope','real']); targets=sorted(t['id'] for t in devices['targets'] if t.get('scope')=='real' and t.get('kind')=='real-device')
summary={'fullIntegrationComplete':False,'metadataOnly':True,'nativeAdministrationExecuted':False,'nonexecutionEvidence':'Source review and DI boundary tests, not external process trace or physical state postcondition','planExecutable':False,'archiveCreated':False,'preflightBeforeToolIOEvidence':'DI resolver/probe counters zero; actual CLI static parameter_conflict envelope','actualPlans':{},'scopeBoundary':'Metadata discovery/help may communicate/cache; no assertion of zero internal service side effects'}
if targets:
    target=targets[0]; archive=root/'PRIVATE-ARCHIVE.zip'; assert not archive.exists()
    for operation in ['pair','unpair','diagnose']:
        args=['device',operation,'--platform','ios','--scope','real','--device',target,'--plan-only']
        if operation=='diagnose': args+=['--output',str(archive)]
        body=cli(operation,args)
        assert body['ok'] and body['action']=='device.'+operation and body['target']==target and body['riskLevel']=='readonly'
        assert body['planOnly'] and not body['executable'] and not body['executed'] and body['verification']=='planned-not-executed' and body['blockedRequirements']
        for key in ['operationArtifactsCreated','pairingStateVerified','diagnosticArchiveVerified']: assert body[key] is False
        assert 'PRIVATE-ARCHIVE' not in json.dumps(body) and not archive.exists()
        support=body['commandSupport']; assert support['verification']=='help-advertised-only'
        preview=body.get('plannedSourceCommand')
        if support['supported']:
            assert preview and '--json-output' in preview and '--log-output' in preview and '<redacted>' in preview
            if operation=='diagnose':
                for flag in ['--devices','--no-finder','--no-include-host-sysdiagnose','--archive-destination']: assert flag in preview
                assert 'host' in body['diagnosticScopeHint']
        else: assert preview is None and 'required-sdk-help-flags-not-advertised' in body['blockedRequirements']
        summary['actualPlans'][operation]={'produced':True,'sdkHelpAdvertised':support['supported'],'plannedNativePreviewRedacted':bool(preview),'executionOrOperationAcceptance':False}
else: summary['actualPlanGap']='No fresh iOS real target; no target fabricated, metadata/preflight/schema only; fixture plans separately verified'
(root/'20261010-device-administration-summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print('Administration schema/preflight and available real-target read-only policy plans accepted; not native action acceptance')
