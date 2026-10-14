#!/usr/bin/env python3
"""Validate and stage a whole skill bundle; never overwrite local edits."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import sys
import tarfile
import tempfile
import uuid

SKILLS = ["tritonkit-dev-feedback", "tritonkit-emulator-cli-takeover", "tritonkit-real-project-regression", "tritonkit-update"]
MANIFEST = ".triton-install.json"
MAX_FILES = 10000
MAX_BYTES = 100 * 1024 * 1024


def reject_links(path):
    raw = os.fspath(path)
    if any(part in (".", "..") for part in raw.split("/")):
        raise ValueError("skills path must not contain relative traversal components")
    absolute = Path(os.path.abspath(path))
    # System temporary paths may contain platform-owned aliases (/var -> /private/var).
    # Resolve that parent once, then reject the caller-owned root and every descendant.
    if absolute.is_symlink(): raise ValueError("skills path must not be a symbolic link")
    for candidate in [absolute, *absolute.parents]:
        if candidate.is_symlink():
            if str(candidate) in ("/var", "/tmp"): continue
            raise ValueError("skills path contains a symbolic link")
    return absolute


def hashes(root):
    reject_links(root)
    result = {}; size = 0
    for path in sorted(root.rglob("*")):
        if path.is_symlink(): raise ValueError("skill bundle contains a symbolic link")
        if path.is_dir(): continue
        if not path.is_file(): raise ValueError("skill bundle contains a special file")
        rel = path.relative_to(root).as_posix()
        size += path.stat().st_size
        if size > MAX_BYTES: raise ValueError("skill bundle exceeds bounds")
        if rel == MANIFEST: continue
        if len(result) >= MAX_FILES or size > MAX_BYTES: raise ValueError("skill bundle exceeds bounds")
        result[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def validate(root):
    for name in SKILLS:
        if not (root/name/"SKILL.md").is_file(): raise ValueError("bundle missing required skill: " + name)
    info = root/"BUILD_INFO.json"
    if info.exists():
        data = json.loads(info.read_text())
        if data.get("name") != "tritonkit-skills" or data.get("bundlePath") != "TritonKit.skills/":
            raise ValueError("invalid BUILD_INFO")
    return hashes(root)


def extract(archive, destination):
    total = 0; seen = set()
    with tarfile.open(archive, "r:gz") as tar:
        members = []
        for item in tar:
            if len(members) >= MAX_FILES: raise ValueError("archive has too many entries")
            members.append(item)
            parts = PurePosixPath(item.name).parts
            if not parts or parts[0] != "TritonKit.skills" or item.name.startswith("/") or ".." in parts:
                raise ValueError("archive member escapes skill bundle")
            if not (item.isfile() or item.isdir()) or item.issym() or item.islnk():
                raise ValueError("archive links/special files are not allowed")
            if item.name in seen: raise ValueError("duplicate archive member")
            seen.add(item.name); total += item.size
            if total > MAX_BYTES or item.size < 0: raise ValueError("archive exceeds size limit")
        for item in members:
            target = destination.joinpath(*PurePosixPath(item.name).parts)
            if item.isdir(): target.mkdir(parents=True, exist_ok=True, mode=0o700)
            else:
                target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                stream = tar.extractfile(item)
                if stream is None: raise ValueError("archive member unreadable")
                with target.open("xb") as output: shutil.copyfileobj(stream, output)
                target.chmod(0o700 if item.mode & 0o111 else 0o600)


def check_current(root, incoming):
    if not root.exists(): return
    reject_links(root)
    current = hashes(root)
    receipt = root/MANIFEST
    if receipt.exists():
        baseline = json.loads(receipt.read_text())
        if baseline.get("schemaVersion") != 1 or not isinstance(baseline.get("files"), dict): raise ValueError("unsupported installation baseline")
        expected = baseline["files"]
        if current != expected: raise ValueError("local skill modifications detected; update refused")
    elif current != incoming:
        raise ValueError("existing bundle has no installation baseline; preserve it and resolve the conflict")


def exchange(left, right):
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == "darwin":
        fn = libc.renamex_np; fn.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_uint]
        result = fn(os.fsencode(left),os.fsencode(right),2) # RENAME_SWAP
    elif hasattr(libc,"renameat2"):
        fn=libc.renameat2; fn.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint]
        result=fn(-100,os.fsencode(left),-100,os.fsencode(right),2)
    else: raise ValueError("atomic directory exchange is unavailable")
    if result: raise OSError(ctypes.get_errno(), "atomic directory exchange failed")


def install(args):
    target = reject_links(args.agent_skills_dir)
    with tempfile.TemporaryDirectory(prefix="triton-skills-validate-") as tmp:
        stage = Path(tmp)
        if args.from_tar:
            archive=reject_links(args.from_tar)
            if not stat.S_ISREG(archive.stat().st_mode): raise ValueError("archive must be a regular file")
            if archive.stat().st_size > MAX_BYTES: raise ValueError("compressed archive exceeds size limit")
            if args.sha256 and hashlib.sha256(archive.read_bytes()).hexdigest() != args.sha256.lower():
                raise ValueError("archive checksum mismatch")
            extract(archive,stage)
        else:
            source=Path(__file__).resolve().parents[2]/"TritonKit.skills"
            hashes(source) # reject links before copy
            shutil.copytree(source,stage/"TritonKit.skills")
        source=stage/"TritonKit.skills"
        incoming=validate(source)
        destination=target/"TritonKit.skills"
        check_current(destination,incoming)
        # Legacy folders are removed only if byte-identical to incoming skills.
        legacy=[]
        for name in SKILLS:
            old=target/name
            if old.exists() or old.is_symlink():
                reject_links(old)
                if hashes(old) and hashes(old) != hashes(source/name): raise ValueError("legacy skill local changes detected: "+name)
                legacy.append(old)
        if args.dry_run:
            print("Validated skill update (dry-run); no installation files changed")
            return
        target.mkdir(parents=True,exist_ok=True)
        lock=target/".triton-skills-update.lock"
        lock.mkdir(mode=0o700) # exclusive; never delete another updater's lock
        incoming_path=target/(".triton-skills-stage-"+uuid.uuid4().hex)
        previous_at_stage=False
        try:
            check_current(destination,incoming)
            for old in legacy:
                if hashes(old) and hashes(old) != hashes(source/old.name): raise ValueError("legacy skill changed during update")
            shutil.copytree(source,incoming_path)
            if hashes(incoming_path) != incoming: raise ValueError("skill source changed during staging")
            for item in [incoming_path,*incoming_path.rglob("*")]:
                item.chmod(0o700 if item.is_dir() or item.stat().st_mode & 0o111 else 0o600)
            receipt=incoming_path/MANIFEST
            receipt.write_text(json.dumps({"schemaVersion":1,"files":incoming},sort_keys=True)+"\n")
            receipt.chmod(0o600)
            check_current(destination,incoming)
            for old in legacy:
                if hashes(old) and hashes(old) != hashes(source/old.name): raise ValueError("legacy skill changed during staging")
            if destination.exists():
                exchange(incoming_path,destination)
                previous_at_stage=True
                backup=target/(".triton-skills-backup-"+uuid.uuid4().hex)
                os.rename(incoming_path,backup)
            else: os.rename(incoming_path,destination)
            for old in legacy:
                os.rename(old,target/(".triton-skills-legacy-"+old.name+"-"+uuid.uuid4().hex))
        finally:
            if incoming_path.exists() and not previous_at_stage: shutil.rmtree(incoming_path)
            lock.rmdir()
        print("Installed TritonKit.skills to "+str(destination))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("agent_skills_dir")
    parser.add_argument("--from-tar")
    parser.add_argument("--sha256",help="Expected SHA-256 for a downloaded archive")
    parser.add_argument("--dry-run",action="store_true")
    args=parser.parse_args()
    try: install(args)
    except (ValueError,OSError,tarfile.TarError) as error:
        print("Skill update refused: "+str(error),file=sys.stderr);return 1
    return 0

if __name__ == "__main__": sys.exit(main())
