#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "release package version verification failed: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 <version>" >&2
}

[[ $# -eq 1 ]] || {
  usage
  exit 2
}

version="$1"
[[ "${version}" =~ ^[0-9]+([.][0-9]+){1,2}([-+][0-9A-Za-z.-]+)?$ ]] || fail "invalid version: ${version}"

python3 - "${root}" "${version}" <<'PYTHON'
import sys
import os
import re
import json

root = sys.argv[1]
expected = sys.argv[2]

def fail(message):
    sys.stderr.write("release package version verification failed: " + message + "\n")
    sys.exit(1)

def read(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        fail("missing " + path)

# Check TritonKit.podspec
podspec_path = os.path.join(root, "TritonKit.podspec")
text = read(podspec_path)
match = re.search(r'^\s*s\.version\s*=\s*[\'"]([^\'"]+)[\'"]', text, re.MULTILINE)
if not match:
    fail("missing s.version in TritonKit.podspec")
actual = match.group(1)
if actual != expected:
    fail("TritonKit.podspec version " + actual + " does not match " + expected)

# Check Web/package.json
web_package_path = os.path.join(root, "Web/package.json")
try:
    web_package = json.loads(read(web_package_path))
except Exception as e:
    fail("failed to parse Web/package.json: " + str(e))
actual = web_package.get("version")
if actual != expected:
    fail("Web/package.json version " + repr(actual) + " does not match " + expected)

# Check Web/package-lock.json
lock_path = os.path.join(root, "Web/package-lock.json")
try:
    lock = json.loads(read(lock_path))
except Exception as e:
    fail("failed to parse Web/package-lock.json: " + str(e))
root_version = lock.get("version")
if root_version != expected:
    fail("Web/package-lock.json root version " + repr(root_version) + " does not match " + expected)

packages = lock.get("packages", {})
root_pkg = packages.get("")
if not root_pkg:
    fail("Web/package-lock.json packages[''] is missing")
package_root_version = root_pkg.get("version")
if package_root_version != expected:
    fail("Web/package-lock.json packages[''] version " + repr(package_root_version) + " does not match " + expected)
PYTHON

echo "release package version verification passed: ${version}"
