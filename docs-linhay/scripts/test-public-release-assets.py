#!/usr/bin/env python3
"""Offline publication-boundary tests: no downloaded content is executed."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch
import urllib.error

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location(
    "public_assets", Path(__file__).with_name("verify-public-release-assets.py"))
assets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)


class PublicAssetsTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.output = Path(self.scratch.name) / "checksums.txt"
        self.archive = b"fixture archive bytes; never unpack or execute"
        self.sha = hashlib.sha256(self.archive).hexdigest()
        self.root = "https://github.com/NeptuneKit/TritonKit/releases/download/v0.2.45/"
        self.meta_url = "https://api.github.com/repos/NeptuneKit/TritonKit/releases/tags/v0.2.45"
        self.meta = dict(tag_name="v0.2.45", draft=False, prerelease=False,
                         published_at="2026-11-11T00:00:00Z", assets=[
            dict(name=name, state="uploaded", size=size, browser_download_url=self.root + name)
            for name, size in [(assets.ARCHIVE, len(self.archive)), (assets.CHECKSUMS, 100)]])
        self.manifest = f"{self.sha}  {assets.ARCHIVE}\n".encode()
        self.calls = []

    def download(self, url, destination, limit, deadline):
        self.calls.append(url)
        if url == self.meta_url:
            if isinstance(self.meta.get("assets"), list):
                for asset in self.meta["assets"]:
                    if isinstance(asset, dict) and asset.get("name") == assets.CHECKSUMS:
                        asset["size"] = len(self.manifest)
            payload = json.dumps(self.meta).encode()
        elif url == self.root + assets.CHECKSUMS:
            payload = self.manifest
        elif url == self.root + assets.ARCHIVE:
            payload = self.archive
        else:
            self.fail("unexpected URL " + url)
        destination.write_bytes(payload)
        return len(payload)

    def verify(self):
        return assets.verify_public_release("NeptuneKit/TritonKit", "v0.2.45",
                                           self.output, download=self.download)

    def reject(self):
        with self.assertRaises((ValueError, OSError)):
            self.verify()
        self.assertFalse(self.output.exists())

    def test_public_exact_tag_publishes_only_verified_arm64(self):
        self.manifest += ("a" * 64 + "  triton-macos-x86_64.tar.gz\n").encode()
        result = self.verify()
        self.assertEqual(self.output.read_text(), f"{self.sha}  {assets.ARCHIVE}\n")
        self.assertEqual(result["sha256"], self.sha)
        self.assertEqual(len(self.calls), 3)

    def test_release_not_public_stable_or_exact_never_downloads_assets(self):
        for key, value in [("draft", True), ("draft", "false"), ("draft", None),
                           ("prerelease", True), ("prerelease", 0),
                           ("tag_name", "v0.2.44"), ("published_at", None)]:
            with self.subTest(key=key, value=value):
                old = self.meta[key]
                self.meta[key] = value
                self.calls = []
                self.reject()
                self.assertEqual(self.calls, [self.meta_url])
                self.meta[key] = old

    def test_missing_duplicate_pending_or_wrong_asset_url_rejected(self):
        original = json.loads(json.dumps(self.meta["assets"]))
        for change in ["missing", "duplicate", "pending", "url"]:
            with self.subTest(change=change):
                self.meta["assets"] = json.loads(json.dumps(original))
                if change == "missing": self.meta["assets"].pop(0)
                if change == "duplicate": self.meta["assets"].append(self.meta["assets"][0])
                if change == "pending": self.meta["assets"][0]["state"] = "new"
                if change == "url": self.meta["assets"][0]["browser_download_url"] = "https://evil.test/a"
                self.reject()

    def test_manifest_duplicate_invalid_or_ambiguous_paths_rejected(self):
        for text in ["", f"{self.sha}  evil-{assets.ARCHIVE}\n",
                     f"{self.sha}  ../{assets.ARCHIVE}\n",
                     f"{self.sha}  /{assets.ARCHIVE}\n",
                     f"{self.sha}  {assets.ARCHIVE}\n{self.sha}  dist/{assets.ARCHIVE}\n",
                     f"invalid  {assets.ARCHIVE}\n"]:
            with self.subTest(text=text):
                self.manifest = text.encode()
                self.reject()

    def test_dist_prefix_is_normalized(self):
        self.manifest = f"{self.sha}  dist/{assets.ARCHIVE}\n".encode()
        self.verify()
        self.assertEqual(self.output.read_text(), f"{self.sha}  {assets.ARCHIVE}\n")

    def test_archive_hash_and_metadata_size_mismatch_rejected(self):
        original = self.archive
        self.archive += b"truncated or changed"
        self.reject()
        self.archive = original
        self.meta["assets"][0]["size"] += 1
        self.reject()

    def test_download_http_timeout_or_partial_failure_leaves_no_output(self):
        for fail_url in [self.meta_url, self.root + assets.CHECKSUMS, self.root + assets.ARCHIVE]:
            for error in [TimeoutError("deadline"), urllib.error.HTTPError(fail_url, 404, "missing", {}, None)]:
                with self.subTest(url=fail_url, error=type(error).__name__):
                    original = self.download
                    def failing(url, destination, limit, deadline):
                        if url == fail_url:
                            destination.write_bytes(b"partial")
                            raise error
                        return original(url, destination, limit, deadline)
                    with self.assertRaises(OSError):
                        assets.verify_public_release("NeptuneKit/TritonKit", "v0.2.45", self.output,
                                                     download=failing)
                    self.assertFalse(self.output.exists())
                    if isinstance(error, urllib.error.HTTPError):
                        error.close()

    def test_stale_output_is_not_accepted(self):
        self.output.write_text("old unverified checksum")
        self.meta["draft"] = True
        self.reject()

    def test_invalid_tag_or_repository_rejected_without_network(self):
        for repo, tag in [("owner/repo/extra", "v0.2.45"), ("NeptuneKit/TritonKit", "../x"),
                          ("NeptuneKit/TritonKit", "v0.2.45-rc1")]:
            with self.subTest(repo=repo, tag=tag):
                self.output.write_text("stale manifest")
                with self.assertRaises(ValueError):
                    assets.verify_public_release(repo, tag, self.output, download=self.download)
                self.assertEqual(self.calls, [])
                self.assertFalse(self.output.exists())

    def test_malformed_assets_are_rejected(self):
        for value in [None, "assets", {}, [None], ["not-object"]]:
            with self.subTest(value=value):
                self.meta["assets"] = value
                self.reject()

    def test_manifest_metadata_size_mismatch_rejected(self):
        original = self.download
        def mismatched(url, destination, limit, deadline):
            size = original(url, destination, limit, deadline)
            return size + 1 if url.endswith(assets.CHECKSUMS) else size
        with self.assertRaises(ValueError):
            assets.verify_public_release("NeptuneKit/TritonKit", "v0.2.45", self.output, download=mismatched)
        self.assertFalse(self.output.exists())

    def test_transport_has_no_auth_header_and_strict_https(self):
        with patch.object(assets.urllib.request, "build_opener") as build:
            build.return_value.open.side_effect = TimeoutError("offline")
            with self.assertRaises(TimeoutError):
                assets.download_public(self.meta_url, self.output, 1024, assets.time.monotonic() + 3)
            request = build.return_value.open.call_args.args[0]
            self.assertNotIn("authorization", {k.lower() for k, _ in request.header_items()})
            self.assertIsInstance(build.call_args.args[0], assets.HTTPSRedirectsOnly)
        with self.assertRaises(ValueError):
            assets.download_public("http://github.com/a", self.output, 1024, assets.time.monotonic() + 3)
        with self.assertRaises(ValueError):
            assets.HTTPSRedirectsOnly().redirect_request(None, None, 302, "redirect", {}, "http://github.com/a")

    def test_transport_total_deadline_and_byte_budget(self):
        with self.assertRaises(TimeoutError):
            assets.download_public(self.meta_url, self.output, 1024, assets.time.monotonic() - 1)
        class Response:
            headers = {}
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read1(self, size): return b"oversize"
        with patch.object(assets.urllib.request, "build_opener") as build:
            build.return_value.open.return_value = Response()
            with self.assertRaises(ValueError):
                assets.download_public(self.meta_url, self.output, 2, assets.time.monotonic() + 3)


if __name__ == "__main__":
    unittest.main()
