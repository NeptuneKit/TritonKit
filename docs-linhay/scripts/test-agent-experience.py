#!/usr/bin/env python3
"""Isolated contract fixtures; never rewrites the live repository."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "experience", Path(__file__).with_name("check-agent-experience.py"))
experience = importlib.util.module_from_spec(spec)
spec.loader.exec_module(experience)


class ExperienceChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.index = self.root / experience.INDEX
        self.write(experience.INDEX, "# 经验\n\n| 触发条件 | 下次检查重点 | 权威链接 |\n"
                   "| --- | --- | --- |\n| schema 改动 | 检查最终 JSON | [契约](../dev/contract.md) |\n")
        self.write("docs-linhay/dev/contract.md", "# 契约\n")
        for name in experience.ROUTES:
            target = self.root / name
            link = os.path.relpath(self.index, target.parent)
            self.write(name, f"[经验索引]({link})\n")
        self.write(".agents/skills/tritonkit-fixture/SKILL.md",
                   "---\nname: tritonkit-fixture\ndescription: fixture\n---\n"
                   "[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)\n")
        for name in experience.AUTO_DISTILL_ROUTES:
            path = self.root / name
            body = path.read_text() if path.is_file() else "[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)\n"
            self.write(name, body + "\n自动沉淀经验：无需用户提醒。\n")

    def write(self, name, body):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)

    def check(self):
        return experience.check(self.root)

    def test_valid(self):
        self.assertEqual([], self.check())

    def test_missing_index(self):
        self.index.unlink()
        self.assertTrue(self.check())

    def test_missing_authority(self):
        (self.root / "docs-linhay/dev/contract.md").unlink()
        self.assertTrue(self.check())

    def test_empty_check(self):
        self.index.write_text(self.index.read_text().replace("检查最终 JSON", ""))
        self.assertTrue(self.check())

    def test_wrong_columns(self):
        self.index.write_text(self.index.read_text().replace("检查最终 JSON |", "检查最终 JSON | 多余 |"))
        self.assertTrue(self.check())

    def test_duplicate_trigger(self):
        row = self.index.read_text().splitlines()[-1]
        self.index.write_text(self.index.read_text() + row + "\n")
        self.assertTrue(self.check())

    def test_no_rows(self):
        self.index.write_text("\n".join(self.index.read_text().splitlines()[:-1]))
        self.assertTrue(self.check())

    def test_no_authority_link(self):
        self.index.write_text(self.index.read_text().replace("[契约](../dev/contract.md)", "只有描述"))
        self.assertTrue(self.check())

    def test_external_authority(self):
        self.index.write_text(self.index.read_text().replace("../dev/contract.md", "https://example.com"))
        self.assertTrue(self.check())

    def test_multiple_valid_links(self):
        self.index.write_text(self.index.read_text().replace(
            "[契约](../dev/contract.md)", "[契约](../dev/contract.md)、[流程](../dev/contract.md)"))
        self.assertEqual([], self.check())

    def test_invalid_second_link(self):
        self.index.write_text(self.index.read_text().replace(
            "[契约](../dev/contract.md)", "[契约](../dev/contract.md)、[缺失](../dev/missing.md)"))
        self.assertTrue(self.check())

    def test_nested_repository_authority(self):
        (self.root / "docs-linhay/dev/.git").mkdir()
        self.assertTrue(self.check())

    def test_code_fence_route_does_not_count(self):
        self.write("AGENTS.md", "```markdown\n[经验](docs-linhay/memory/EXPERIENCE.md)\n```\n")
        self.assertTrue(self.check())

    def test_tilde_fence_route_does_not_count(self):
        self.write("AGENTS.md", "~~~markdown\n[经验](docs-linhay/memory/EXPERIENCE.md)\n~~~\n")
        self.assertTrue(self.check())

    def test_tilde_fence_table_does_not_count(self):
        self.index.write_text("~~~markdown\n" + self.index.read_text() + "~~~\n")
        self.assertTrue(self.check())

    def test_indented_route_does_not_count(self):
        self.write("AGENTS.md", "    [经验](docs-linhay/memory/EXPERIENCE.md)\n")
        self.assertTrue(self.check())

    def test_inline_code_route_does_not_count(self):
        self.write("AGENTS.md", "`[经验](docs-linhay/memory/EXPERIENCE.md)`\n")
        self.assertTrue(self.check())

    def test_shorter_fence_does_not_close_block(self):
        self.write("AGENTS.md", "````markdown\n```\n[经验](docs-linhay/memory/EXPERIENCE.md)\n````\n")
        self.assertTrue(self.check())

    def test_visible_route_after_fence(self):
        self.write("AGENTS.md", "~~~markdown\n示例\n~~~\n[经验](docs-linhay/memory/EXPERIENCE.md)\n"
                   "自动沉淀经验：无需用户提醒。\n")
        self.assertEqual([], self.check())

    def test_path_escape(self):
        self.index.write_text(self.index.read_text().replace("../dev/contract.md", "../../../../outside.md"))
        self.assertTrue(self.check())

    def test_symlink_escape(self):
        with tempfile.TemporaryDirectory() as other:
            outside = Path(other) / "contract.md"
            outside.write_text("# External\n")
            authority = self.root / "docs-linhay/dev/contract.md"
            authority.unlink()
            authority.symlink_to(outside)
            self.assertTrue(self.check())

    def test_missing_root_route(self):
        self.write("AGENTS.md", "# No route\n")
        self.assertTrue(self.check())

    def test_commented_route_does_not_count(self):
        self.write("AGENTS.md", "<!-- [经验](docs-linhay/memory/EXPERIENCE.md) -->\n")
        self.assertTrue(self.check())

    def test_missing_skill_route(self):
        self.write(".agents/skills/tritonkit-fixture/SKILL.md", "# No route\n")
        self.assertTrue(self.check())

    def test_missing_automatic_trigger(self):
        self.write("AGENTS.md", "[经验索引](docs-linhay/memory/EXPERIENCE.md)\n")
        self.assertTrue(self.check())

    def test_automatic_trigger_in_example_does_not_count(self):
        self.write("AGENTS.md", "[经验索引](docs-linhay/memory/EXPERIENCE.md)\n"
                   "```markdown\n自动沉淀经验：无需用户提醒。\n```\n")
        self.assertTrue(self.check())

    def test_governance_trigger_removed(self):
        name = "docs-linhay/dev/20260619-agent-workflow-skill-governance.md"
        self.write(name, (self.root / name).read_text().replace("自动沉淀经验", "手动整理"))
        self.assertTrue(self.check())

    def test_skill_trigger_removed(self):
        name = ".agents/skills/tritonkit-ops-governance/SKILL.md"
        self.write(name, (self.root / name).read_text().replace("无需用户提醒", "等待用户指令"))
        self.assertTrue(self.check())


if __name__ == "__main__":
    unittest.main()
