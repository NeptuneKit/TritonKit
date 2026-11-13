"""Public capability routing is preserved in the source AND the shipped bundle.
These checks prove documentation structure, not device/provider behavior.
"""
from pathlib import Path, PurePosixPath
import re
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[3]
SKILLS = ROOT / 'TritonKit.skills'
GUIDES = {
    'tritonkit-dev-feedback/references/dsh-integration.md',
    'tritonkit-emulator-cli-takeover/references/http-api.md',
    'tritonkit-emulator-cli-takeover/references/target-leases.md',
    'tritonkit-emulator-cli-takeover/references/ui-inspection.md',
    'tritonkit-emulator-cli-takeover/references/app-map.md',
    'tritonkit-emulator-cli-takeover/references/vlm-models.md',
    'tritonkit-emulator-cli-takeover/references/web-preview.md',
    'tritonkit-real-project-regression/references/test-recorder.md',
}
NODE_IDS = set('agent cli http dsh web discover target observe action verify evidence app webview inspect build replay workspace ioshost iossdk runner android harmony'.split())


def links(text):
    visible = []
    fence = None
    for line in text.splitlines():
        m = re.match(r'^\s*(`{3,}|~{3,})', line)
        if m:
            mark = m.group(1)
            if fence is None:
                fence = mark
            elif mark[0] == fence[0] and len(mark) >= len(fence):
                fence = None
            continue
        if fence is None:
            visible.append(re.sub(r'(`+).*?\1', '', line))
    return re.findall(r'\[[^]\n]+\]\(([^\s)]+)\)', '\n'.join(visible))


def resolve_link(owner, target):
    url = urlsplit(target.strip('<>'))
    if url.scheme or url.netloc or not url.path:
        return None
    parts = list(PurePosixPath(owner).parent.parts)
    for part in PurePosixPath(unquote(url.path)).parts:
        if part == '..':
            if not parts:
                raise ValueError('link escapes bundle')
            parts.pop()
        elif part not in ('', '.'):
            if part == '/':
                raise ValueError('absolute local link')
            parts.append(part)
    return '/'.join(parts)


def routing_errors(files):
    errors = []
    reachable = set()
    pending = ['README.md']
    pending += [name for name in files if name.endswith('/SKILL.md')]
    while pending:
        owner = pending.pop()
        if owner in reachable:
            continue
        reachable.add(owner)
        if owner not in files:
            errors.append('missing route: ' + owner)
            continue
        for target in links(files[owner]):
            try:
                path = resolve_link(owner, target)
            except ValueError:
                errors.append('outside bundle: ' + owner + ' -> ' + target)
                continue
            if path and path.endswith('.md'):
                pending.append(path)
    for guide in sorted(GUIDES):
        if guide not in files:
            errors.append('missing guide: ' + guide)
        elif guide not in reachable:
            errors.append('unrouted guide: ' + guide)
    return errors


class PublicSkillCoverageTests(unittest.TestCase):
    def source_files(self):
        return {p.relative_to(SKILLS).as_posix(): p.read_text() for p in SKILLS.rglob('*.md')}

    def test_all_gap_guides_are_reachable_inside_bundle(self):
        self.assertEqual(routing_errors(self.source_files()), [])

    def test_bundle_readme_maps_all_22_capability_ids(self):
        readme = (SKILLS / 'README.md').read_text()
        rows = re.findall(r'^\| `([a-z]+)` \|[^\n]+', readme, re.MULTILINE)
        self.assertEqual(set(rows), NODE_IDS)
        self.assertEqual(len(rows), len(NODE_IDS))

    def test_each_guide_has_actionable_sections(self):
        files = self.source_files()
        for guide in sorted(GUIDES):
            with self.subTest(guide=guide):
                self.assertTrue(guide in files, 'missing guide: ' + guide)
                if guide in files:
                    for heading in ('## Prerequisites', '## Workflow', '## Verification', '## Limits'):
                        self.assertIn(heading, files[guide])

    def test_routing_negatives_reject_absence_unrouted_and_escape(self):
        guide = sorted(GUIDES)[0]
        base = {g: '# Guide' for g in GUIDES}
        self.assertTrue(any('unrouted guide' in e for e in routing_errors({'README.md': '# Empty', **base})))
        linked = '\n'.join(f'[Guide]({g})' for g in sorted(GUIDES))
        good = {'README.md': linked, **base}
        self.assertEqual(routing_errors(good), [])
        missing = dict(good)
        del missing[guide]
        self.assertTrue(any('missing guide' in e for e in routing_errors(missing)))
        escaped = {**good, 'README.md': linked + '\n[Private](../docs-only.md)'}
        self.assertTrue(any('outside bundle' in e for e in routing_errors(escaped)))
        code_only = {'README.md': '```md\n' + linked + '\n```', **base}
        self.assertTrue(any('unrouted guide' in e for e in routing_errors(code_only)))

    def test_skill_entries_reach_guides_without_the_bundle_index(self):
        files = self.source_files()
        files['README.md'] = '# Bundle index intentionally omitted'
        self.assertEqual(routing_errors(files), [])

    def test_dsh_json_examples_match_the_current_cli_adapter(self):
        guide = (SKILLS / 'tritonkit-dev-feedback/references/dsh-integration.md').read_text()
        examples = re.findall(r'Tool: `triton_(schema|query|action|verify)`\n\n```json\n(.*?)\n```', guide, re.DOTALL)
        self.assertEqual(len(examples), 7)
        payloads = [[kind, json.loads(body)] for kind, body in examples]
        module_url = (ROOT / 'DSH/commands.js').as_uri()
        script = ('import {buildCommand} from ' + json.dumps(module_url) + ';'
                  'let body="";for await(const chunk of process.stdin)body+=chunk;'
                  'for(const [kind,args] of JSON.parse(body)) {'
                  'const argv=buildCommand(kind,args);if(!argv.includes("--json"))throw Error("JSON contract missing");}'
                  'console.log("Validated tool argument examples without executing CLI");')
        result = subprocess.run(['node', '--input-type=module', '-e', script],
                                input=json.dumps(payloads), capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_generated_archive_keeps_all_guides_and_routes(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'skills.tar.gz'
            result = subprocess.run([
                sys.executable, str(ROOT / 'docs-linhay/scripts/package-public-skills.py'),
                '--repo-root', str(ROOT), '--version', '9.8.7-dev', '--output', str(archive)
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            if result.returncode:
                return
            with tarfile.open(archive) as package:
                files = {m.name.removeprefix('TritonKit.skills/'): package.extractfile(m).read().decode('utf-8')
                         for m in package.getmembers() if m.isfile() and m.name.endswith('.md')}
            self.assertEqual(routing_errors(files), [])


if __name__ == '__main__':
    unittest.main()
