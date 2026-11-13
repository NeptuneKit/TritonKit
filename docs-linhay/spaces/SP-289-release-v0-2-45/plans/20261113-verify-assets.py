#!/usr/bin/env python3
"""Verify fully downloaded v0.2.45 assets in a fresh repository-external directory."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, importlib.util, json, re, subprocess, tarfile
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--repo-root',type=Path,required=True)
p.add_argument('--asset-dir',type=Path,required=True)
p.add_argument('--extract-dir',type=Path,required=True)
p.add_argument('--report',type=Path,required=True)
p.add_argument('--candidate',required=True)
a=p.parse_args();root=a.repo_root.resolve();assets=a.asset_dir.resolve();out=a.extract_dir.resolve()
assert not out.exists() and not out.is_relative_to(root),'Extraction must be fresh and repository-external'
expected={'triton-macos-arm64.tar.gz','tritonkit-skills.tar.gz'}
entries={}
for line in (assets/'tritonkit_checksums.txt').read_text().splitlines():
    m=re.fullmatch(r'([a-f0-9]{64}) [ *]([A-Za-z0-9_.-]+)',line)
    assert m and m[2] not in entries,'Malformed or duplicate manifest entry'
    entries[m[2]]=m[1]
assert set(entries)==expected,entries
records=[]
for name in sorted(expected):
    b=(assets/name).read_bytes();sha=hashlib.sha256(b).hexdigest();assert sha==entries[name],name
    records.append({'name':name,'bytes':len(b),'sha256':sha})
out.mkdir(mode=0o700,parents=True)
for name in sorted(expected):
    with tarfile.open(assets/name) as archive:
        for member in archive.getmembers():
            path=PurePosixPath(member.name)
            assert not path.is_absolute() and '..' not in path.parts,member.name
            assert member.isfile() or member.isdir(),member.name
        archive.extractall(out,filter='data')
binary=out/'triton-macos-arm64/triton'
architecture=subprocess.check_output(['file','-b',str(binary)],text=True).strip();assert 'arm64' in architecture and 'Mach-O' in architecture
version=json.loads(subprocess.check_output([str(binary),'version','--json'],cwd=out));assert version.get('version')=='0.2.45' and version.get('ok') is True
web=out/'triton-macos-arm64/web';assert (web/'index.html').is_file()
subprocess.run(['python3',str(root/'docs-linhay/scripts/verify-ios-runner-package.py'),'--archive',str(assets/'triton-macos-arm64.tar.gz'),'--version','0.2.45'],cwd=out,check=True)
skills=out/'TritonKit.skills';info=json.loads((skills/'BUILD_INFO.json').read_text())
assert info['version']=='0.2.45' and info['releaseTag']=='v0.2.45'
assert info['git']['commit']==a.candidate and info['git']['dirty'] is False,info['git']
names=['tritonkit-dev-feedback','tritonkit-emulator-cli-takeover','tritonkit-real-project-regression','tritonkit-update']
assert [s['name'] for s in info['skills']]==names
for name in names:
    assert re.search(r'^  version: 0[.]2[.]45$',(skills/name/'SKILL.md').read_text(),re.M)
subprocess.run(['python3',str(root/'docs-linhay/scripts/verify-public-skill-layout.py'),'--skill-root',str(skills)],cwd=out,check=True)
spec=importlib.util.spec_from_file_location('release_coverage',root/'docs-linhay/scripts/tests/test_public_skill_coverage.py')
coverage=importlib.util.module_from_spec(spec);spec.loader.exec_module(coverage)
files={q.relative_to(skills).as_posix():q.read_text() for q in skills.rglob('*.md')}
assert coverage.routing_errors(files)==[]
guides=[]
for name in sorted(coverage.GUIDES):
    actual=hashlib.sha256((skills/name).read_bytes()).hexdigest()
    expected_sha=hashlib.sha256((root/'TritonKit.skills'/name).read_bytes()).hexdigest()
    assert actual==expected_sha,name
    guides.append({'path':name,'sha256':actual,'matchesCandidateSource':True})
package_blob=subprocess.check_output(['git','rev-parse','v0.2.45:Package.swift'],cwd=root,text=True).strip()
expected_blob=subprocess.check_output(['git','rev-parse',a.candidate+':Package.swift'],cwd=root,text=True).strip();assert package_blob==expected_blob
result={'status':'pass','version':'0.2.45','candidate':a.candidate,'architecture':architecture,'assets':records,'cliVersion':version['version'],'webIndexPresent':True,'runnerVersion':'0.2.45','skillBuildInfo':info,'guideCount':len(guides),'guides':guides,'swiftPMPackageBlob':package_blob,'boundary':'archive/byte/metadata/version/readonly invocation only; not device or business acceptance'}
a.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'pass','assets':records,'guides':len(guides),'version':'0.2.45'},indent=2))
