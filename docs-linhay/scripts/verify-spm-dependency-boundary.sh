#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "spm dependency boundary verification failed: $*" >&2
  exit 1
}

root_manifest="${tmp_dir}/root-package.json"
swift package --disable-sandbox --package-path "${root}" describe --type json >"${root_manifest}"

if grep -Eq '"(hummingbird|hummingbird-websocket|swift-argument-parser)"' "${root_manifest}"; then
  fail "root Package.swift must not expose CLI-only package dependencies"
fi

if grep -Eq '"TritonKitCLI"|"triton"' "${root_manifest}"; then
  fail "root Package.swift must not expose the CLI target or executable product"
fi

test -f "${root}/CLI/Package.swift" || fail "missing CLI/Package.swift"
test -e "${root}/CLI/Sources/TritonKitCLI" || fail "missing CLI package source shim"

swift package --disable-sandbox --package-path "${root}/CLI" describe --type json >"${tmp_dir}/cli-package.json"
grep -q '"triton"' "${tmp_dir}/cli-package.json" || fail "CLI package must expose the triton executable product"
grep -q '"swift-argument-parser"' "${tmp_dir}/cli-package.json" || fail "CLI package must own ArgumentParser"
grep -q '"hummingbird"' "${tmp_dir}/cli-package.json" || fail "CLI package must own Hummingbird"

echo "spm dependency boundary verification passed"
