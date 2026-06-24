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
podspec="$root/TritonKit.podspec"

test -f "$bootstrap" || fail "missing Demo app debug bootstrap file"
test -f "$app_entry" || fail "missing Demo app entry file"
test -f "$runtime" || fail "missing TritonKit runtime source"
test -f "$package_manifest" || fail "missing Package.swift"
test -f "$podspec" || fail "missing TritonKit.podspec"

python3 - "$bootstrap" "$app_entry" "$runtime" "$package_manifest" "$podspec" <<'PY'
import pathlib
import re
import sys

bootstrap = pathlib.Path(sys.argv[1])
app_entry = pathlib.Path(sys.argv[2])
runtime = pathlib.Path(sys.argv[3])
package_manifest = pathlib.Path(sys.argv[4])
podspec = pathlib.Path(sys.argv[5])
root = runtime.parents[2]

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def first_nonempty_line(path: pathlib.Path) -> str:
    for line in path.read_text().splitlines():
        if line.strip():
            return line.strip()
    return ""

# Business-app integration sample must make source-level isolation visible:
# the file itself starts with #if DEBUG, and imports/starts TritonKit only inside it.
if first_nonempty_line(bootstrap) != "#if DEBUG":
    fail(f"{bootstrap.relative_to(root)} must start with file-level #if DEBUG")

bootstrap_text = bootstrap.read_text()
if "import TritonKit" not in bootstrap_text:
    fail(f"{bootstrap.relative_to(root)} must contain the app-side TritonKit import")
if "#endif" not in bootstrap_text:
    fail(f"{bootstrap.relative_to(root)} must close the file-level #if DEBUG")


def is_debug_guarded(path: pathlib.Path, needle: str) -> list[int]:
    debug_depth = 0
    conditional_stack: list[bool] = []
    unguarded: list[int] = []
    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("#if"):
            is_debug = stripped == "#if DEBUG" or stripped.startswith("#if DEBUG ")
            conditional_stack.append(is_debug)
            if is_debug:
                debug_depth += 1
        elif stripped.startswith("#else") or stripped.startswith("#elseif"):
            if conditional_stack and conditional_stack[-1]:
                # We are no longer in the DEBUG branch after #else/#elseif.
                debug_depth -= 1
                conditional_stack[-1] = False
        elif stripped.startswith("#endif"):
            if conditional_stack:
                was_debug = conditional_stack.pop()
                if was_debug:
                    debug_depth -= 1
        if needle in line and debug_depth <= 0:
            unguarded.append(lineno)
    return unguarded

for needle in ("import TritonKit", "TritonKit.shared", "TritonKitDebugBootstrap"):
    for path in sorted((root / "Examples").rglob("*.swift")):
        bad_lines = is_debug_guarded(path, needle)
        if bad_lines:
            rel = path.relative_to(root)
            fail(f"{rel} references {needle!r} outside #if DEBUG at lines {bad_lines}")

# Package-level Release no-op remains the second safety net; it does not replace app-side isolation.
runtime_text = runtime.read_text()
package_text = package_manifest.read_text()
podspec_text = podspec.read_text()
readme = root / "README.md"
public_skills = [
    root / "TritonKit.skills/tritonkit-dev-feedback/SKILL.md",
    root / "TritonKit.skills/tritonkit-real-project-regression/SKILL.md",
]
for doc in [readme, *public_skills]:
    text = doc.read_text()
    for needle in ("TRITONKIT_RUNTIME_ENABLED", "startIfEnabled", "--triton-enabled", "TRITON_ENABLED", "#if DEBUG"):
        if needle not in text:
            fail(f"{doc.relative_to(root)} must document recommended opt-in DEBUG bootstrap with {needle}")
    if "pod 'TritonKitShared'" in text or 'pod "TritonKitShared"' in text:
        fail(f"{doc.relative_to(root)} must not ask users to add TritonKitShared explicitly")
    if "pod 'TritonKit'" not in text and 'pod "TritonKit"' not in text:
        fail(f"{doc.relative_to(root)} must show user-facing CocoaPods integration with TritonKit")

if 'define("TRITONKIT_RUNTIME_ENABLED", .when(configuration: .debug))' not in package_text:
    fail("Package.swift must define TRITONKIT_RUNTIME_ENABLED for the TritonKit target in Debug configuration")

if "OTHER_SWIFT_FLAGS[config=Debug]" not in podspec_text or "TRITONKIT_RUNTIME_ENABLED" not in podspec_text:
    fail("TritonKit.podspec must define TRITONKIT_RUNTIME_ENABLED for the TritonKit pod target Debug configuration")
if re.search(r"['\"]OTHER_SWIFT_FLAGS['\"]\s*=>\s*['\"][^'\"]*TRITONKIT_RUNTIME_ENABLED", podspec_text):
    fail("TritonKit.podspec must not define TRITONKIT_RUNTIME_ENABLED through unscoped OTHER_SWIFT_FLAGS")
if re.search(r"OTHER_SWIFT_FLAGS\[config=Release\].*TRITONKIT_RUNTIME_ENABLED", podspec_text):
    fail("TritonKit.podspec must not define TRITONKIT_RUNTIME_ENABLED for Release configuration")

if "public static var isRuntimeEnabled" not in runtime_text:
    fail("Sources/TritonKit/TritonKit.swift must expose isRuntimeEnabled")
if not re.search(r"public static var isRuntimeEnabled:\s*Bool\s*\{\s*#if TRITONKIT_RUNTIME_ENABLED\s*true\s*#else\s*false\s*#endif\s*\}", runtime_text, re.S):
    fail("TritonKit.isRuntimeEnabled must be controlled by #if TRITONKIT_RUNTIME_ENABLED/#else")
if re.search(r"public static var isRuntimeEnabled:\s*Bool\s*\{\s*#if DEBUG", runtime_text, re.S):
    fail("TritonKit.isRuntimeEnabled must not bind directly to bare #if DEBUG")
if "guard Self.isRuntimeEnabled else" not in runtime_text:
    fail("runtime start/connect/send paths must guard Self.isRuntimeEnabled")

if failures:
    for item in failures:
        print(item, file=sys.stderr)
    sys.exit(1)
PY

echo "iOS DEBUG isolation verification passed"
