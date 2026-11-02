#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shlex
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
    argument_rules = json.loads(schema_path.read_text(encoding="utf-8")).get("validatedCommandArguments", {})
    problems: list[CommandProblem] = []
    for path in sorted(skill_root.rglob("*.md")):
        problems.extend(validate_markdown(path, path.relative_to(skill_root), commands, strict_groups))
        problems.extend(validate_fenced_arguments(path, path.relative_to(skill_root), argument_rules))
    return problems


def fenced_commands(markdown: str):
    """Read complete shell examples without expanding placeholders or executing shell code.

    Inline prose often names an option without its value; it is deliberately not an argv.
    Root/subcommand validation still scans all Markdown via validate_markdown.
    """
    fence = None
    shell = False
    pending = ""
    start = 0
    for line_number, line in enumerate(markdown.splitlines(), start=1):
        stripped = line.strip()
        marker = re.fullmatch(r"(`{3,}|~{3,})([\w-]*)\s*", stripped)
        if marker:
            if fence is None:
                fence = marker.group(1)
                shell = marker.group(2) in {"", "bash", "sh", "shell", "zsh", "text"}
            elif marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence):
                if pending:
                    yield start, pending
                fence, pending, shell = None, "", False
            continue
        if not shell:
            continue
        if not pending:
            if not re.match(r"triton\s", stripped):
                continue
            start = line_number
        pending += stripped
        if pending.endswith("\\"):
            pending = pending[:-1] + " "
            continue
        yield start, pending
        pending = ""
    if pending:
        yield start, pending


def validate_fenced_arguments(path: Path, display_path: Path, rules: dict) -> list[CommandProblem]:
    problems: list[CommandProblem] = []
    for line, command in fenced_commands(path.read_text(encoding="utf-8")):
        match = TRITON_COMMAND.match(command)
        if not match or match.group("root") not in rules:
            continue
        root = match.group("root")
        try:
            arguments = shlex.split(command, comments=True)[2:]
        except ValueError as error:
            problems.append(CommandProblem(display_path, line, f"invalid `{root}` example quoting: {error}"))
            continue
        options = rules[root]["options"]
        index = 0
        while index < len(arguments):
            argument = arguments[index]
            name, separator, _ = argument.partition("=")
            message = None
            if not name.startswith("-"):
                message = f"unexpected positional argument `{argument}` for `{root}`; use `--text <text>` for visible text"
            elif name in {"--help", "-h"} and not separator:
                pass
            elif name not in options:
                message = f"unknown option `{name}` for `{root}`"
            elif options[name] == 0 and separator:
                message = f"flag `{name}` does not accept a value"
            elif options[name] == 1 and not separator:
                if index + 1 == len(arguments) or arguments[index + 1].startswith("--"):
                    message = f"missing value for `{name}`"
                else:
                    index += 1
            if message:
                problems.append(CommandProblem(display_path, line, message))
                break
            index += 1
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
