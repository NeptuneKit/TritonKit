#!/usr/bin/env python3
"""Bound mandatory feedback context and validate its progressive-disclosure routes."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys

MAX_BYTES = 8192
MAX_LINES = 150
MAX_LINE_CHARACTERS = 600
REQUIRED_REFERENCES = {
    'issue-filing', 'evidence-ios-runtime', 'evidence-host-devices',
    'schema-contract-feedback', 'app-integration-ios', 'app-integration-harmony',
    'device-hub-feedback', 'xcode-feedback', 'discovery-migration',
    'observation-feedback', 'reliability-feedback', 'picker-feedback', 'runner-feedback',
    'dsh-integration',
}


def validate_feedback_layout(skill_root: Path) -> list[str]:
    root = skill_root / 'tritonkit-dev-feedback'
    entry = root / 'SKILL.md'
    text = entry.read_text(encoding='utf-8')
    lines = text.splitlines()
    errors = []
    if len(text.encode('utf-8')) > MAX_BYTES:
        errors.append(f'feedback SKILL.md exceeds {MAX_BYTES} UTF-8 bytes')
    if len(lines) > MAX_LINES:
        errors.append(f'feedback SKILL.md exceeds {MAX_LINES} lines')
    if max(map(len, lines), default=0) > MAX_LINE_CHARACTERS:
        errors.append(f'feedback SKILL.md exceeds {MAX_LINE_CHARACTERS} characters on one line')
    routes = re.findall(r'\]\((references/[^)#]+\.md)(?:#[^)]*)?\)', text)
    if not routes:
        errors.append('feedback SKILL.md requires explicit Markdown reference routes')
    for name in sorted(REQUIRED_REFERENCES):
        if f'references/{name}.md' not in routes:
            errors.append(f'feedback reference route missing: {name}.md')
    reference_texts = []
    for route in sorted(set(routes)):
        path = (root / route).resolve()
        if not path.is_relative_to((root / 'references').resolve()) or not path.is_file():
            errors.append(f'feedback reference missing or outside references/: {route}')
            continue
        reference_texts.append(path.read_text(encoding='utf-8'))
    # Long specialized prose belongs in its routed reference, not both copies.
    for paragraph in re.split(r'\n\s*\n', text):
        paragraph = paragraph.strip()
        if len(paragraph) >= 160 and not paragraph.startswith(('---', '|', '#')):
            if any(paragraph in reference for reference in reference_texts):
                errors.append('feedback entry duplicates a routed paragraph of at least 160 characters')
                break
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skill-root', type=Path, required=True)
    args = parser.parse_args()
    errors = validate_feedback_layout(args.skill_root)
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print('public skill layout verified')
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
