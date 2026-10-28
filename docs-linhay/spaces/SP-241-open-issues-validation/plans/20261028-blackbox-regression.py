import argparse, json, os, pathlib, subprocess, tempfile
root_repo=pathlib.Path(__file__).resolve().parents[4]
parser=argparse.ArgumentParser(description="Compare isolated fixtures against released 0.2.33 and the local candidate; never calls a real device")
parser.add_argument('--baseline', type=pathlib.Path, required=True)
parser.add_argument('--candidate', type=pathlib.Path, default=root_repo/'CLI/.build/debug/triton')
args=parser.parse_args()
baseline=args.baseline.resolve(); candidate=args.candidate.resolve()
assert json.loads(subprocess.check_output([str(baseline),'version','--json']))['version']=='0.2.33' 
results=[]
with tempfile.TemporaryDirectory(prefix='triton-issue-regression-') as d:
 root=pathlib.Path(d); bins=root/'bin'; bins.mkdir()
 adb=bins/'adb'
 adb.write_text('''#!/bin/sh
case "$*" in
 'devices -l') printf 'List of devices attached\\nemulator-5554 device product:fixture model:Fixture device:fixture transport_id:1\\n' ;;
 *'get-state') echo device ;;
 *'getprop sys.boot_completed') echo 0 ;;
 *'pm path android') echo package:/system/framework/framework-res.apk ;;
 *'uiautomator dump'*) echo 'ERROR: null root node returned by UiTestAutomationBridge.' >&2 ;;
 *'shell cat'*) echo '<hierarchy><node text="stale" class="android.widget.Button" bounds="[0,0][100,100]"/></hierarchy>' ;;
 *'shell rm'*) exit 0 ;;
 *) exit 64 ;;
esac
'''); adb.chmod(0o700)
 gradle=bins/'fake-gradle'; gradle.write_text('''#!/bin/sh
echo '> Task :buildSrc:checkKotlinGradlePluginConfigurationErrors'
echo 'w: file:///fixture/Sample.kt:1:1 named error'
exec /bin/sleep 10
'''); gradle.chmod(0o700)
 env=dict(os.environ,PATH=str(bins)+os.pathsep+os.environ['PATH'])
 for label,binary in [('released-0.2.33',baseline),('candidate',candidate)]:
  for issue,args in [
   (227,['build','android','--project',d,'--gradle',str(gradle),'--timeout','2','--json']),
   (228,['device','wait-ready','--platform','android','--scope','emulator','--device','android:emulator-5554','--adb',str(adb),'--timeout','1','--interval','0.1','--json']),
   (229,['observe','tree','--platform','android','--device','android:emulator-5554','--json'])]:
   run=subprocess.run([str(binary),*args],cwd=d,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=15,text=True)
   obj=json.loads(run.stdout)
   row={'binary':label,'issue':issue,'exitCode':run.returncode,'ok':obj.get('ok'),'errorCode':(obj.get('error') or {}).get('code')}
   if issue==227:
    row.update(durationMs=obj.get('durationMs'),errorCount=(obj.get('diagnostics') or {}).get('errorCount'),warningCount=(obj.get('diagnostics') or {}).get('warningCount'))
    row['passesRequirement']=row['durationMs']>=2000 and row['errorCount']==0 and row['warningCount']==1
   elif issue==228: row['passesRequirement']=run.returncode!=0 and obj.get('ok') is False
   else:
    row['staleReturned']=any(n.get('text')=='stale' for n in obj.get('nodes',[]))
    row['passesRequirement']=run.returncode!=0 and row['errorCode']=='hierarchy_unavailable' and not row['staleReturned']
   results.append(row)
assert all(not x['passesRequirement'] for x in results if x['binary']=='released-0.2.33'),results
assert all(x['passesRequirement'] for x in results if x['binary']=='candidate'),results
out=pathlib.Path(__file__).with_name('20261028-cli-blackbox-red-green.json')
out.write_text(json.dumps({'scope':'isolated fake Gradle/ADB, no real devices','baselineVersion':'0.2.33','results':results},indent=2)+'\n')
print(out)
for r in results: print(r)
