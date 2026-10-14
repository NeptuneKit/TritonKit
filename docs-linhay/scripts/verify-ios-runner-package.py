#!/usr/bin/env python3
"""Verify a directory/tar Runner package or run offline packaging regression fixtures."""
import argparse
import importlib.util
import json
import tarfile
import tempfile
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location("runner_package", Path(__file__).with_name("package-ios-runner-resources.py"))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def verify_archive(archive, version):
    with tempfile.TemporaryDirectory() as temporary, tarfile.open(archive, "r:gz") as tar:
        members = tar.getmembers()
        manifests = [member for member in members if member.name.endswith("/resources/ios-runner/" + helper.MANIFEST)]
        if len(manifests) != 1:
            raise ValueError("archive must contain exactly one bundled Runner manifest")
        prefix = manifests[0].name.removesuffix(helper.MANIFEST)
        seen = set()
        root = Path(temporary)
        for member in members:
            if not member.name.startswith(prefix):
                continue
            relative = member.name[len(prefix):].rstrip("/")
            if not relative:
                continue
            if member.isdir():
                if not any(name.startswith(relative + "/") for name in helper.ALLOWED):
                    raise ValueError("unexpected archive Runner directory")
                continue
            if not member.isfile() or relative in seen or relative not in helper.ALLOWED | {helper.MANIFEST}:
                raise ValueError("unsafe or duplicate Runner archive member")
            seen.add(relative)
            if member.size > 2 * 1024 * 1024:
                raise ValueError("Runner archive member exceeds size budget")
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(tar.extractfile(member).read())
        return helper.verify(root, version)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        for name in helper.REQUIRED:
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("unsigned fixture\n")

    def packaged(self):
        output = self.root / "package"
        helper.package(self.source, output, "0.2.99-test")
        return output

    def test_portable_archive_is_complete(self):
        output = self.packaged()
        archive = self.root / "triton.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(output, arcname="triton-macos-arm64/resources/ios-runner")
        self.assertEqual(verify_archive(archive, "0.2.99-test")["sourceVersion"], "0.2.99-test")

    def test_missing_required_file_rejected(self):
        (self.source / sorted(helper.REQUIRED)[0]).unlink()
        with self.assertRaises(ValueError):
            self.packaged()

    def test_tampered_file_rejected(self):
        output = self.packaged()
        (output / sorted(helper.REQUIRED)[0]).write_text("tampered")
        with self.assertRaises(ValueError):
            helper.verify(output)

    def test_extra_private_file_rejected(self):
        (self.source / "token.json").write_text("private")
        with self.assertRaises(ValueError):
            self.packaged()

    def test_symlink_rejected(self):
        target = self.source / sorted(helper.REQUIRED)[0]
        target.unlink()
        target.symlink_to("/etc/passwd")
        with self.assertRaises(ValueError):
            self.packaged()

    def test_version_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            helper.verify(self.packaged(), "wrong-version")

    def test_missing_packaged_file_rejected(self):
        output = self.packaged()
        (output / sorted(helper.REQUIRED)[0]).unlink()
        with self.assertRaises(ValueError):
            helper.verify(output)

    def test_duplicate_archive_member_rejected(self):
        output = self.packaged()
        archive = self.root / "duplicate.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(output, arcname="pkg/resources/ios-runner")
            name = sorted(helper.REQUIRED)[0]
            tar.add(output / name, arcname="pkg/resources/ios-runner/" + name)
        with self.assertRaises(ValueError):
            verify_archive(archive, None)

    def test_archive_symlink_rejected(self):
        archive = self.root / "unsafe.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            manifest = tarfile.TarInfo("pkg/resources/ios-runner/RUNNER_MANIFEST.json")
            manifest.type = tarfile.SYMTYPE
            manifest.linkname = "/etc/passwd"
            tar.addfile(manifest)
        with self.assertRaises(ValueError):
            verify_archive(archive, None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--version")
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PackagingTests))
        raise SystemExit(0 if result.wasSuccessful() else 1)
    if bool(args.root) == bool(args.archive):
        parser.error("provide exactly one --root or --archive")
    manifest = helper.verify(args.root, args.version) if args.root else verify_archive(args.archive, args.version)
    print(json.dumps({"ok": True, "sourceVersion": manifest["sourceVersion"], "fileCount": len(manifest["files"])}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, json.JSONDecodeError, tarfile.TarError) as error:
        raise SystemExit(f"Runner package verification failed: {error}")
