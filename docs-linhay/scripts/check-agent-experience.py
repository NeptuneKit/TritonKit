#!/usr/bin/env python3
"""Validate the deliberately small experience table and its entry links."""
import argparse
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

INDEX = Path("docs-linhay/memory/EXPERIENCE.md")
ROUTES = (
    "AGENTS.md", "README.md", ".agents/skills/README.md",
    "docs-linhay/memory/MEMORY.md",
    "docs-linhay/dev/20260619-agent-workflow-skill-governance.md",
)
AUTO_DISTILL_ROUTES = (
    "AGENTS.md",
    ".agents/skills/tritonkit-ops-governance/SKILL.md",
    "docs-linhay/dev/20260619-agent-workflow-skill-governance.md",
)
LINK = re.compile(r"\[[^\]\n]+\]\(([^\s)]+)\)")
HEADER = ["触发条件", "下次检查重点", "权威链接"]


def visible_markdown(text):
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    visible = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if fence is not None:
            if marker and marker[1][0] == fence[0] and len(marker[1]) >= len(fence) and not marker[2].strip():
                fence = None
            continue
        if marker:
            fence = marker[1]
            continue
        if line.startswith(("    ", "\t")):
            continue
        visible.append(re.sub(r"(`+).*?\1", "", line))
    return "\n".join(visible)


def local_target(root, source, value):
    url = urlsplit(value)
    if url.scheme or url.netloc or url.query or url.fragment or value.startswith("/"):
        raise ValueError("需要仓库内相对文件链接（不含 query/anchor）")
    target = (source.parent / unquote(url.path)).resolve()
    if not target.is_relative_to(root):
        raise ValueError("链接越出仓库（含 symlink）")
    if not target.is_file():
        raise ValueError("链接目标不存在或不是文件")
    for parent in target.parents:
        if parent == root:
            break
        if (parent / ".git").exists():
            raise ValueError("链接进入独立仓库")
    return target


def check(root):
    root = Path(root).resolve()
    index = root / INDEX
    errors = []
    if not index.is_file():
        return [f"{INDEX}: 缺少经验索引"]
    text = visible_markdown(index.read_text(encoding="utf-8"))
    rows = [line.strip() for line in text.splitlines() if line.lstrip().startswith("|")]
    cells = lambda row: [cell.strip() for cell in row.strip("|").split("|")]
    if len(rows) < 3 or cells(rows[0]) != HEADER or any(
            not re.fullmatch(r":?-{3,}:?", cell) for cell in cells(rows[1])) or len(cells(rows[1])) != 3:
        errors.append(f"{INDEX}: 需要三列标题、分隔行和至少一条经验")
    seen = set()
    for row in rows[2:]:
        parts = cells(row)
        if len(parts) != 3 or not all(parts):
            errors.append(f"{INDEX}: 每条经验必须有三个非空字段: {row}")
            continue
        if parts[0] in seen:
            errors.append(f"{INDEX}: 重复触发条件: {parts[0]}")
        seen.add(parts[0])
        if not LINK.search(parts[2]):
            errors.append(f"{INDEX}: 权威字段缺少 Markdown 文件链接: {parts[0]}")
    for value in LINK.findall(text):
        try:
            local_target(root, index, value)
        except ValueError as error:
            errors.append(f"{INDEX}: {value}: {error}")
    skills = sorted(root.glob(".agents/skills/tritonkit-*/SKILL.md"))
    if not skills:
        errors.append(".agents/skills: 缺少 TritonKit 内部 skills")
    for source in [*(root / name for name in ROUTES), *skills]:
        if not source.is_file():
            errors.append(f"{source.relative_to(root)}: 缺少经验入口文件")
            continue
        links = LINK.findall(visible_markdown(source.read_text(encoding="utf-8")))
        linked = False
        for value in links:
            try:
                linked = linked or local_target(root, source, value) == index
            except ValueError:
                continue  # This check owns experience links, not every historical link.
        if not linked:
            errors.append(f"{source.relative_to(root)}: 缺少有效经验索引链接")
    for name in AUTO_DISTILL_ROUTES:
        source = root / name
        if not source.is_file():
            errors.append(f"{name}: 缺少自动沉淀规则入口")
            continue
        visible = visible_markdown(source.read_text(encoding="utf-8"))
        if not any("自动沉淀经验" in line and "无需用户提醒" in line for line in visible.splitlines()):
            errors.append(f"{name}: 缺少可见的自动沉淀经验规则（无需用户提醒）")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    errors = check(args.root)
    for error in errors:
        print(error)
    if not errors:
        print("agent experience index and routes ok")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
