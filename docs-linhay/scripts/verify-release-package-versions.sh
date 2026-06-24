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

ruby -rjson - "${root}" "${version}" <<'RUBY'
root = ARGV.fetch(0)
expected = ARGV.fetch(1)

def fail(message)
  warn "release package version verification failed: #{message}"
  exit 1
end

def read(path)
  File.read(path)
rescue Errno::ENOENT
  fail "missing #{path}"
end

{
  "TritonKit.podspec" => File.join(root, "TritonKit.podspec")
}.each do |label, path|
  text = read(path)
  match = text.match(/^\s*s\.version\s*=\s*['"]([^'"]+)['"]/)
  fail "missing s.version in #{label}" unless match
  actual = match[1]
  fail "#{label} version #{actual} does not match #{expected}" unless actual == expected
end

web_package_path = File.join(root, "Web/package.json")
web_package = JSON.parse(read(web_package_path))
actual = web_package["version"]
fail "Web/package.json version #{actual.inspect} does not match #{expected}" unless actual == expected

lock_path = File.join(root, "Web/package-lock.json")
lock = JSON.parse(read(lock_path))
root_version = lock["version"]
fail "Web/package-lock.json root version #{root_version.inspect} does not match #{expected}" unless root_version == expected

package_root_version = lock.dig("packages", "", "version")
fail "Web/package-lock.json packages[''] version #{package_root_version.inspect} does not match #{expected}" unless package_root_version == expected
RUBY

echo "release package version verification passed: ${version}"
