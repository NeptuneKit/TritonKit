#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

checksums="${tmp_dir}/tritonkit_checksums.txt"
formula="${tmp_dir}/triton.rb"

cat > "${checksums}" <<'CHECKSUMS'
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  dist/triton-macos-arm64.tar.gz
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  dist/triton-macos-x86_64.tar.gz
CHECKSUMS

"${repo_root}/docs-linhay/scripts/render-homebrew-formula.sh" \
  "v0.1.0" \
  "${checksums}" \
  "${repo_root}/.github/homebrew/triton.rb.template" \
  "${formula}"

grep -q 'version "0.1.0"' "${formula}"
grep -q 'releases/download/v0.1.0/triton-macos-arm64.tar.gz' "${formula}"
grep -q 'releases/download/v0.1.0/triton-macos-x86_64.tar.gz' "${formula}"
grep -q 'sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "${formula}"
grep -q 'sha256 "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' "${formula}"
grep -Fq 'Dir["triton-macos-*/triton"].first || Dir["triton"].first' "${formula}"
grep -Fq 'Dir["triton-macos-*/web"].first || Dir["web"].first' "${formula}"
grep -Fq 'pkgshare.install web_dir => "web"' "${formula}"
grep -Fq 'JSON.parse(shell_output("#{bin}/triton version --json"))' "${formula}"
grep -Fq 'assert_equal true, version_json["ok"]' "${formula}"
grep -Fq 'assert_path_exists pkgshare/"web/index.html"' "${formula}"
grep -Fq 'JSON.parse(shell_output("#{bin}/triton web --print-command --json"))' "${formula}"
grep -Fq 'assert_equal "packaged", web_plan["mode"]' "${formula}"
grep -Fq 'assert_equal "#{pkgshare}/web", web_plan["bundledWebRoot"]' "${formula}"

ruby -c "${formula}" >/dev/null

echo "homebrew formula verification passed"
