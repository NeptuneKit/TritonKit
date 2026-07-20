#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


TRITON_COMMAND = re.compile(
    r"(?<![A-Za-z0-9_./-])triton[ \t]+"
    r"(?P<root>[a-z][a-z0-9-]*)"
    r"(?:[ \t]+(?P<subcommand>[a-z][a-z0-9-]*))?"
)
PREFERRED_SUGGESTION_ROOTS = ["act", "debug", "app", "device", "sim"]


@dataclass(frozen=True)
class CommandProblem:
    path: Path
    line: int
    message: str

    def render(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


def load_schema(path: Path) -> tuple[dict[str, set[str]], set[str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schemaVersion") != 1:
        raise ValueError(f"unsupported public skill command schema: {path}")
    commands = {
        str(root): {str(subcommand) for subcommand in subcommands}
        for root, subcommands in payload["commands"].items()
    }
    strict_groups = {str(value) for value in payload.get("validatedSubcommandGroups", [])}
    unknown_groups = strict_groups.difference(commands)
    if unknown_groups:
        raise ValueError(f"validatedSubcommandGroups are not schema roots: {sorted(unknown_groups)}")
    return commands, strict_groups


def preferred_migration(root: str, commands: dict[str, set[str]]) -> str | None:
    candidates = [candidate for candidate, subcommands in commands.items() if root in subcommands]
    candidates.sort(
        key=lambda candidate: (
            PREFERRED_SUGGESTION_ROOTS.index(candidate)
            if candidate in PREFERRED_SUGGESTION_ROOTS
            else len(PREFERRED_SUGGESTION_ROOTS),
            candidate,
        )
    )
    if not candidates:
        return None
    return f"triton {candidates[0]} {root}"


def validate_markdown(
    path: Path,
    display_path: Path,
    commands: dict[str, set[str]],
    strict_groups: set[str],
) -> list[CommandProblem]:
    problems: list[CommandProblem] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        for match in TRITON_COMMAND.finditer(line):
            root = match.group("root")
            subcommand = match.group("subcommand")
            if root not in commands:
                migration = preferred_migration(root, commands)
                message = f"unknown Triton command root `{root}`"
                if migration:
                    message += f"; use `{migration}`"
                problems.append(CommandProblem(display_path, line_number, message))
                continue
            if root in strict_groups and subcommand and subcommand not in commands[root]:
                problems.append(
                    CommandProblem(
                        display_path,
                        line_number,
                        f"unknown Triton subcommand `{root} {subcommand}`; inspect `triton schema --command {root} --json`",
                    )
                )
    return problems


def validate_skill_root(skill_root: Path, schema_path: Path) -> list[CommandProblem]:
    commands, strict_groups = load_schema(schema_path)
    problems: list[CommandProblem] = []
    for path in sorted(skill_root.rglob("*.md")):
        problems.extend(validate_markdown(path, path.relative_to(skill_root), commands, strict_groups))
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate public skill Triton commands against the checked CLI schema snapshot.")
    parser.add_argument("--skill-root", type=Path, required=True)
    parser.add_argument("--schema", type=Path, required=True)
    args = parser.parse_args()

    problems = validate_skill_root(args.skill_root.resolve(), args.schema.resolve())
    if problems:
        for problem in problems:
            print(problem.render(), file=sys.stderr)
        return 1
    print("public skill command validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
