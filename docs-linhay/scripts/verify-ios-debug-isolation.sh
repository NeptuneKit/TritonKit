#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "iOS DEBUG isolation verification failed: $*" >&2
  exit 1
}

bootstrap="$root/Examples/TritonKitDemo/TritonKitDemo/TritonKitDebugBootstrap.swift"
app_entry="$root/Examples/TritonKitDemo/TritonKitDemo/App.swift"
runtime="$root/Sources/TritonKit/TritonKit.swift"
package_manifest="$root/Package.swift"

for path in "$bootstrap" "$app_entry" "$runtime" "$package_manifest"; do
  test -f "$path" || fail "missing $(basename "$path")"
done

python3 - "$bootstrap" "$app_entry" "$runtime" "$package_manifest" <<'PY'
import pathlib
import re
import sys

bootstrap, app_entry, runtime, package_manifest = map(pathlib.Path, sys.argv[1:])
root = runtime.parents[2]
failures = []

def fail(message):
    failures.append(message)

def first_nonempty_line(path):
    for line in path.read_text().splitlines():
        if line.strip():
            return line.strip()
    return ""

if first_nonempty_line(bootstrap) != "#if DEBUG":
    fail(f"{bootstrap.relative_to(root)} must start with file-level #if DEBUG")
bootstrap_text = bootstrap.read_text()
if "import TritonKit" not in bootstrap_text or "#endif" not in bootstrap_text:
    fail(f"{bootstrap.relative_to(root)} must contain a guarded TritonKit bootstrap")

def is_debug_guarded(path, needle):
    depth = 0
    stack = []
    bad = []
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#if"):
            debug = stripped == "#if DEBUG" or stripped.startswith("#if DEBUG ")
            stack.append(debug)
            depth += int(debug)
        elif stripped.startswith("#else") or stripped.startswith("#elseif"):
            if stack and stack[-1]:
                depth -= 1
                stack[-1] = False
        elif stripped.startswith("#endif") and stack:
            if stack.pop():
                depth -= 1
        if needle in line and depth <= 0:
            bad.append(lineno)
    return bad

for needle in ("import TritonKit", "TritonKit.shared", "TritonKitDebugBootstrap"):
    for path in sorted((root / "Examples").rglob("*.swift")):
        bad = is_debug_guarded(path, needle)
        if bad:
            fail(f"{path.relative_to(root)} references {needle!r} outside #if DEBUG at lines {bad}")

package_text = package_manifest.read_text()
if ".iOS(.v16)" not in package_text:
    fail("Package.swift must declare iOS 16 as the minimum supported platform")
if 'define("TRITONKIT_RUNTIME_ENABLED", .when(configuration: .debug))' not in package_text:
    fail("Package.swift must define TRITONKIT_RUNTIME_ENABLED for the TritonKit target in Debug configuration")
if any("TRITONKIT_COCOAPODS_SINGLE_POD" in path.read_text(errors="ignore") for path in (root / "Sources/TritonKit").rglob("*.swift")):
    fail("CocoaPods single-pod compatibility macro must be removed from Sources/TritonKit")

runtime_text = runtime.read_text()
if "public static var isRuntimeEnabled" not in runtime_text:
    fail("Sources/TritonKit/TritonKit.swift must expose isRuntimeEnabled")
if not re.search(r"public static var isRuntimeEnabled:\s*Bool\s*\{\s*#if TRITONKIT_RUNTIME_ENABLED\s*true\s*#else\s*false\s*#endif\s*\}", runtime_text, re.S):
    fail("TritonKit.isRuntimeEnabled must be controlled by TRITONKIT_RUNTIME_ENABLED/#else")
if "guard Self.isRuntimeEnabled else" not in runtime_text:
    fail("runtime start/connect/send paths must guard Self.isRuntimeEnabled")

if failures:
    for item in failures:
        print(item, file=sys.stderr)
    sys.exit(1)
PY

echo "iOS DEBUG isolation verification passed"
