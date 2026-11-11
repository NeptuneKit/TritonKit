#!/usr/bin/env python3
"""Prove stable public arm64 bytes before making a Homebrew formula available."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import tempfile
import time
import urllib.parse
import urllib.request

ARCHIVE = "triton-macos-arm64.tar.gz"
CHECKSUMS = "tritonkit_checksums.txt"


def require_https(url):
    parsed = urllib.parse.urlsplit(url)
    host = parsed.hostname or ""
    if (parsed.scheme != "https" or parsed.username or parsed.password
            or parsed.port not in (None, 443)
            or not (host in {"github.com", "api.github.com"}
                    or host.endswith(".githubusercontent.com"))):
        raise ValueError("public download must use a GitHub HTTPS endpoint")


class HTTPSRedirectsOnly(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        require_https(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def remaining(deadline):
    value = deadline - time.monotonic()
    if value <= 0:
        raise TimeoutError("public asset verification total deadline exhausted")
    return min(20, value)


def download_public(url, destination, limit, deadline):
    require_https(url)
    timeout = remaining(deadline)
    # Standard HTTPSHandler verifies TLS. No gh/curl config, cookies or token is used.
    opener = urllib.request.build_opener(HTTPSRedirectsOnly())
    accept = "application/vnd.github+json" if urllib.parse.urlsplit(url).hostname == "api.github.com" else "application/octet-stream"
    request = urllib.request.Request(url, headers={"User-Agent": "TritonKit-public-asset-check",
                                                  "Accept": accept})
    total = 0
    with opener.open(request, timeout=timeout) as response, destination.open("wb") as output:
        length = response.headers.get("Content-Length")
        expected = int(length) if length is not None else None
        if expected is not None and (expected < 0 or expected > limit):
            raise ValueError("public response exceeds byte budget")
        while True:
            remaining(deadline)
            chunk = response.read1(64 * 1024)
            remaining(deadline)
            if not chunk:
                break
            total += len(chunk)
            if total > limit:
                raise ValueError("public response exceeds byte budget")
            output.write(chunk)
        if expected is not None and total != expected:
            raise ValueError("public response was incomplete")
    return total


def arm64_checksum(text):
    matches = []
    for line in text.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64}) [ *]((?:dist/)?[A-Za-z0-9_.-]+)", line)
        if not match:
            raise ValueError("invalid checksum manifest entry")
        digest, filename = match.groups()
        if filename in (ARCHIVE, "dist/" + ARCHIVE):
            matches.append(digest)
    if len(matches) != 1:
        raise ValueError("manifest must contain exactly one arm64 archive")
    return matches[0]


def verify_public_release(repository, tag, output, download=download_public):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    # An unsuccessful rerun must never leave a previous checksum usable by a caller.
    output.unlink(missing_ok=True)
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("invalid repository")
    if not re.fullmatch(r"v[0-9]+(?:\.[0-9]+){1,2}", tag):
        raise ValueError("Homebrew publication requires a stable version tag")
    deadline = time.monotonic() + 300
    with tempfile.TemporaryDirectory(prefix=".public-assets-", dir=output.parent) as scratch:
        scratch = Path(scratch)
        metadata = scratch / "release.json"
        download(f"https://api.github.com/repos/{repository}/releases/tags/{tag}",
                 metadata, 8 * 1024 * 1024, deadline)
        release = json.loads(metadata.read_text())
        if not isinstance(release, dict):
            raise ValueError("release metadata must be an object")
        if (release.get("tag_name") != tag or release.get("draft") is not False
                or release.get("prerelease") is not False
                or not isinstance(release.get("published_at"), str)
                or not release["published_at"]):
            raise ValueError("release is not the exact published stable tag")
        root = f"https://github.com/{repository}/releases/download/{tag}/"
        entries = release.get("assets")
        if not isinstance(entries, list) or any(not isinstance(a, dict) for a in entries):
            raise ValueError("release assets must be an array of objects")
        known = {}
        for name in (ARCHIVE, CHECKSUMS):
            selected = [a for a in entries if a.get("name") == name]
            if (len(selected) != 1 or selected[0].get("state") != "uploaded"
                    or selected[0].get("browser_download_url") != root + name
                    or type(selected[0].get("size")) is not int or selected[0]["size"] <= 0):
                raise ValueError("release asset missing, ambiguous or not uploaded")
            known[name] = selected[0]
        manifest = scratch / CHECKSUMS
        manifest_size = download(root + CHECKSUMS, manifest, 128 * 1024, deadline)
        if manifest_size != known[CHECKSUMS]["size"] or manifest.stat().st_size != manifest_size:
            raise ValueError("public manifest size differs from release metadata")
        digest = arm64_checksum(manifest.read_text())
        archive = scratch / ARCHIVE
        size = download(root + ARCHIVE, archive, 512 * 1024 * 1024, deadline)
        if size != known[ARCHIVE]["size"] or archive.stat().st_size != size:
            raise ValueError("public archive size differs from release metadata")
        with archive.open("rb") as payload:
            actual = hashlib.file_digest(payload, "sha256").hexdigest()
        if actual != digest:
            raise ValueError("public archive sha256 does not match manifest")
        remaining(deadline)
        candidate = scratch / "verified-checksums.txt"
        candidate.write_text(f"{digest}  {ARCHIVE}\n")
        # Publish only the verified arm64 entry, atomically and without overwriting a race.
        os.link(candidate, output)
    return dict(ok=True, repository=repository, tag=tag, artifact=ARCHIVE, sha256=digest, bytes=size)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output-checksums", type=Path, required=True)
    args = parser.parse_args()
    def deadline_expired(signum, frame):
        raise TimeoutError("public asset verification total deadline exhausted")
    # Unix CI/macOS helper: interrupt DNS and trickling socket reads as well as loops.
    signal.signal(signal.SIGALRM, deadline_expired)
    signal.setitimer(signal.ITIMER_REAL, 300)
    try:
        result = verify_public_release(args.repository, args.tag, args.output_checksums)
    except (OSError, ValueError) as error:
        parser.exit(1, f"public release asset verification failed: {type(error).__name__}: {error}\n")
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
