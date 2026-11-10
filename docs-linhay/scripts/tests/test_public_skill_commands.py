from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
VALIDATOR = ROOT / "docs-linhay/scripts/verify-public-skill-commands.py"
SCHEMA = ROOT / "docs-linhay/scripts/public-skill-command-schema.json"


class PublicSkillCommandValidatorTests(unittest.TestCase):
    def validate(self, markdown):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "SKILL.md").write_text(markdown, encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(VALIDATOR), "--skill-root", str(root), "--schema", str(SCHEMA)],
                capture_output=True, text=True, timeout=10,
            )

    def test_rejects_positional_wait_even_after_options(self):
        for command in (
            'triton wait text "成功" --platform <ios|android|harmony> --device <selector> --json',
            'triton wait --platform harmony text "Ready" --target placeholder --json',
            'triton wait "Ready" --device placeholder --json',
        ):
            with self.subTest(command=command):
                result = self.validate(f"```bash\n{command}\n```\n")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("unexpected positional argument", result.stderr)
                self.assertIn("SKILL.md:2:", result.stderr)

    def test_rejects_unknown_options_missing_values_and_flag_values(self):
        for command in (
            "triton wait --text-contains Ready --device placeholder --json",
            "triton wait --text --json",
            "triton wait --text",
            "triton wait --idle=true --json",
        ):
            with self.subTest(command=command):
                self.assertNotEqual(self.validate(f"```sh\n{command}\n```\n").returncode, 0)

    def test_accepts_aliases_platform_placeholders_and_quoted_values(self):
        for selector in ("--device", "--target"):
            for platform in ("ios", "android", "harmony", "<ios|android|harmony>"):
                result = self.validate(
                    f'```bash\ntriton wait --text "成功 Ready" --platform {platform} {selector} <selector> --json\n```\n'
                )
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_accepts_equals_continuations_and_literal_shell_metacharacters(self):
        result = self.validate('''```sh
triton wait --text="Ready now; $(do-not-run)" \\
  --device=<selector> --timeout 0.1 --json # text is a value
triton wait --predicate 'text.exists("Ready") && !text.exists("Loading")' --json
```
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_invalid_continuation_at_original_command_line(self):
        result = self.validate('```bash\ntriton wait --platform harmony \\\n  text Ready --json\n```\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SKILL.md:2:", result.stderr)

    def test_prose_fragments_and_other_command_positionals_keep_existing_behavior(self):
        result = self.validate('''Use `triton wait --text` or `triton wait --gone`.
```bash
triton act tap "Login" --device <selector> --json
triton verify text-exists "Ready" --json
```
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotEqual(self.validate("Use `triton tap Login`.\n").returncode, 0)

    def test_unclosed_quote_is_rejected_without_execution(self):
        self.assertNotEqual(self.validate('```bash\ntriton wait --text "Ready\n```\n').returncode, 0)

    def test_actual_public_skills_pass(self):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--skill-root", str(ROOT / "TritonKit.skills"), "--schema", str(SCHEMA)],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
