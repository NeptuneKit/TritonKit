import importlib.util
from pathlib import Path
import tempfile
import shutil
import subprocess
import sys
import unittest

SCRIPT_ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('public_skill_layout', SCRIPT_ROOT / 'verify-public-skill-layout.py')
layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layout)


class PublicSkillLayoutTests(unittest.TestCase):
    def check_fixture(self, body, reference='Reference details.', route='references/details.md'):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            skill = root / 'tritonkit-dev-feedback'
            (skill / 'references').mkdir(parents=True)
            links = []
            for name in sorted(layout.REQUIRED_REFERENCES):
                (skill / f'references/{name}.md').write_text(f'# {name}\n')
                links.append(f'[{name}](references/{name}.md)')
            if reference is not None:
                (skill / 'references/details.md').write_text(reference)
            (skill / 'SKILL.md').write_text(body + '\n\n[Details](' + route + ')\n' + '\n'.join(links))
            return layout.validate_feedback_layout(root)

    def test_repository_entry_is_bounded_and_routed(self):
        self.assertEqual(layout.validate_feedback_layout(SCRIPT_ROOT.parents[1] / 'TritonKit.skills'), [])

    def test_valid_routed_entry(self):
        self.assertEqual(self.check_fixture('# Feedback\n\nFile redacted evidence.'), [])

    def test_utf8_bytes_not_character_or_line_count(self):
        errors = self.check_fixture('\n'.join(['界' * 100] * 30))
        self.assertIn('feedback SKILL.md exceeds 8192 UTF-8 bytes', errors)
        self.assertFalse(any('lines' in e or 'one line' in e for e in errors))

    def test_line_budget(self):
        self.assertTrue(any('150 lines' in e for e in self.check_fixture('x\n' * 151)))

    def test_long_line_budget(self):
        self.assertTrue(any('600 characters' in e for e in self.check_fixture('x' * 601)))

    def test_missing_reference(self):
        self.assertTrue(any('reference missing' in e for e in self.check_fixture('Feedback', None)))

    def test_route_cannot_escape(self):
        self.assertTrue(any('outside references' in e for e in self.check_fixture('Feedback', route='references/../SKILL.md')))

    def test_entry_cannot_reembed_reference_paragraph(self):
        paragraph = 'Specialized protocol detail. ' * 8
        self.assertTrue(any('duplicates a routed paragraph' in e for e in self.check_fixture(paragraph.strip(), paragraph)))

    def test_reference_route_cannot_silently_disappear(self):
        with tempfile.TemporaryDirectory() as directory:
            skill = Path(directory) / 'tritonkit-dev-feedback'
            (skill / 'references').mkdir(parents=True)
            (skill / 'references/issue-filing.md').write_text('Preserved file without route')
            (skill / 'SKILL.md').write_text('# Feedback\n')
            self.assertIn('feedback reference route missing: issue-filing.md', layout.validate_feedback_layout(Path(directory)))

    def test_packaging_rejects_multibyte_bloat_before_archive(self):
        repo = SCRIPT_ROOT.parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            skill_root = root / 'skills'
            shutil.copytree(repo / 'TritonKit.skills', skill_root)
            entry = skill_root / 'tritonkit-dev-feedback/SKILL.md'
            with entry.open('a') as stream:
                stream.write('\n' + '\n'.join(['界' * 100] * 30) + '\n')
            archive = root / 'skills.tar.gz'
            result = subprocess.run([
                sys.executable, str(SCRIPT_ROOT / 'package-public-skills.py'),
                '--repo-root', str(repo), '--skill-root', str(skill_root),
                '--version', '9.8.7-dev', '--output', str(archive),
            ], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(archive.exists())
            self.assertIn("exceeds 8192 UTF-8 bytes", result.stderr)


if __name__ == '__main__':
    unittest.main()
