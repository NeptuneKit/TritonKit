#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PUBLIC_SKILLS = [
    "tritonkit-dev-feedback",
    "tritonkit-emulator-cli-takeover",
    "tritonkit-real-project-regression",
    "tritonkit-update",
]


def run(root: Path, args: list[str]) -> str:
    result = subprocess.run(args, cwd=root, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def git_info(repo_root: Path) -> dict[str, Any]:
    full_hash = run(repo_root, ["git", "rev-parse", "HEAD"])
    dirty_status = run(repo_root, ["git", "status", "--short"])
    return {
        "commit": full_hash,
        "shortCommit": full_hash[:7],
        "dirty": bool(dirty_status),
    }


def read_skill_version(skill_file: Path) -> str:
    in_metadata = False
    for line in skill_file.read_text(encoding="utf-8").splitlines():
        if line == "metadata:":
            in_metadata = True
            continue
        if in_metadata and line.startswith("  version:"):
            return line.partition(":")[2].strip().strip('"')
        if in_metadata and line and not line.startswith(" "):
            in_metadata = False
    raise ValueError(f"missing metadata.version in {skill_file}")


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    return "__pycache__" in parts or path.name == ".DS_Store" or path.suffix == ".pyc"


def copy_skill(source: Path, destination: Path) -> None:
    def ignore(_dir: str, names: list[str]) -> set[str]:
        return {name for name in names if should_skip(Path(name))}

    shutil.copytree(source, destination, ignore=ignore)


def stamp_skill(repo_root: Path, version: str, skill_file: Path) -> None:
    subprocess.run(
        [str(repo_root / "docs-linhay/scripts/stamp-skill-version.sh"), version, str(skill_file)],
        cwd=repo_root,
        check=True,
    )


def build_info(repo_root: Path, work_dir: Path, version: str, release_tag: str | None) -> dict[str, Any]:
    skills = []
    for skill_name in PUBLIC_SKILLS:
        skill_file = work_dir / skill_name / "SKILL.md"
        skills.append(
            {
                "name": skill_name,
                "path": f"TritonKit.skills/{skill_name}/",
                "version": read_skill_version(skill_file),
            }
        )

    return {
        "name": "tritonkit-skills",
        "bundlePath": "TritonKit.skills/",
        "version": version,
        "releaseTag": release_tag,
        "git": git_info(repo_root),
        "builtAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "skills": skills,
    }


def package_public_skills(
    repo_root: Path,
    skill_root: Path,
    output: Path,
    version: str,
    release_tag: str | None,
) -> dict[str, Any]:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with tempfile.TemporaryDirectory(prefix="tritonkit-skills.") as tmp:
        work_dir = Path(tmp) / "TritonKit.skills"
        work_dir.mkdir()
        readme = skill_root / "README.md"
        if readme.is_file():
            shutil.copy2(readme, work_dir / "README.md")
        for skill_name in PUBLIC_SKILLS:
            source = skill_root / skill_name
            if not (source / "SKILL.md").is_file():
                raise FileNotFoundError(f"missing public skill source: {source}")
            destination = work_dir / skill_name
            copy_skill(source, destination)
            stamp_skill(repo_root, version, destination / "SKILL.md")

        info = build_info(repo_root, work_dir, version, release_tag)
        (work_dir / "BUILD_INFO.json").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        with tarfile.open(output, "w:gz") as archive:
            archive.add(work_dir, arcname="TritonKit.skills")

    return {"output": str(output), "buildInfo": info}


def main() -> int:
    parser = argparse.ArgumentParser(description="Package TritonKit public skills with build metadata.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--skill-root", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=Path("dist/tritonkit-skills.tar.gz"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--release-tag")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    skill_root = args.skill_root.resolve() if args.skill_root else repo_root / "TritonKit.skills"
    output = args.output.resolve()
    payload = package_public_skills(repo_root, skill_root, output, args.version, args.release_tag)

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"Packaged {payload['output']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
