#!/usr/bin/env python3
"""Package the unsigned iOS Runner source using a closed file inventory (stdlib only)."""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

MANIFEST = "RUNNER_MANIFEST.json"
PROJECT = "TritonIOSRunner.xcodeproj"
SCHEME = "TritonIOSRunner"
ALLOWED = {
    "README.md", "Package.swift", "project.yml",
    "FixtureApp/RunnerFixtureApp.swift",
    "RunnerTests/TritonIOSRunnerTests.swift", "RunnerTests/HTTPProtocol.swift",
    "ProtocolTests/HTTPProtocolTests.swift",
    f"{PROJECT}/project.pbxproj",
    f"{PROJECT}/xcshareddata/xcschemes/{SCHEME}.xcscheme",
    f"{PROJECT}/project.xcworkspace/contents.xcworkspacedata",
}
REQUIRED = {
    "FixtureApp/RunnerFixtureApp.swift", "RunnerTests/TritonIOSRunnerTests.swift",
    "RunnerTests/HTTPProtocol.swift", f"{PROJECT}/project.pbxproj",
    f"{PROJECT}/xcshareddata/xcschemes/{SCHEME}.xcscheme",
}


def inventory(root):
    root = Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Runner source root must be a regular directory")
    entries = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise ValueError(f"symlink is prohibited: {relative}")
        if path.is_dir():
            if not any(name.startswith(relative + "/") for name in ALLOWED):
                raise ValueError(f"unexpected directory: {relative}")
            continue
        if relative == MANIFEST:
            continue
        if not path.is_file() or relative not in ALLOWED:
            raise ValueError(f"unexpected Runner resource: {relative}")
        if path.stat().st_size > 2 * 1024 * 1024:
            raise ValueError(f"Runner resource exceeds size budget: {relative}")
        data = path.read_bytes()
        entries.append({"path": relative, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    if not REQUIRED.issubset({entry["path"] for entry in entries}):
        raise ValueError("required Runner project/source files are missing")
    return entries


def verify(root, expected_version=None):
    root = Path(root)
    manifest_path = root / MANIFEST
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError("Runner manifest is missing or is a symlink")
    if manifest_path.stat().st_size > 64 * 1024:
        raise ValueError("Runner manifest exceeds size budget")
    manifest = json.loads(manifest_path.read_text())
    if set(manifest) != {"schemaVersion", "sourceVersion", "project", "scheme", "files"}:
        raise ValueError("invalid Runner manifest fields")
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1 or manifest["project"] != PROJECT or manifest["scheme"] != SCHEME:
        raise ValueError("unsupported Runner manifest contract")
    if not isinstance(manifest["sourceVersion"], str) or not manifest["sourceVersion"].strip() or len(manifest["sourceVersion"]) > 128:
        raise ValueError("Runner source version is missing")
    if expected_version is not None and manifest["sourceVersion"] != expected_version:
        raise ValueError("Runner source version does not match the release")
    if not isinstance(manifest["files"], list):
        raise ValueError("Runner manifest file inventory must be an array")
    for entry in manifest["files"]:
        if not isinstance(entry, dict) or set(entry) != {"path", "size", "sha256"}:
            raise ValueError("invalid Runner file entry")
        if type(entry["size"]) is not int or not isinstance(entry["path"], str) or not isinstance(entry["sha256"], str):
            raise ValueError("invalid Runner file entry types")
    if manifest["files"] != inventory(root):
        raise ValueError("Runner manifest inventory or SHA-256 mismatch")
    return manifest


def package(source, output, version):
    source, output = Path(source), Path(output)
    entries = inventory(source)
    if not version.strip() or len(version) > 128:
        raise ValueError("invalid source version")
    if source.resolve() != output.resolve():
        if output.exists():
            raise ValueError("output already exists; use a fresh package directory")
        output.mkdir(parents=True)
        for entry in entries:
            target = output / entry["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / entry["path"], target)
            target.chmod(0o644)
    manifest = {"schemaVersion": 1, "sourceVersion": version, "project": PROJECT, "scheme": SCHEME, "files": entries}
    (output / MANIFEST).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    (output / MANIFEST).chmod(0o644)
    return verify(output, version)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[2] / "CLI/Sources/TritonKitCLI/Resources/ios-runner")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    manifest = package(args.source, args.output, args.version)
    print(json.dumps({"ok": True, "sourceVersion": manifest["sourceVersion"], "fileCount": len(manifest["files"])}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"Runner packaging failed: {error}", file=sys.stderr)
        sys.exit(1)
