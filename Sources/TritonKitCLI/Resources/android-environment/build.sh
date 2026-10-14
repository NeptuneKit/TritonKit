#!/bin/sh
set -eu
# Release preparation only. End users consume the bundled dex, never a host JDK.
resource_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
android_sdk_dir=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
d8_tool=${TRITON_D8:-$(find "$android_sdk_dir/build-tools" -name d8 -type f | sort | tail -1)}
[ -x "$d8_tool" ] || { echo "Android d8 is required for resource packaging" >&2; exit 1; }
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT HUP INT TERM
javac -source 8 -target 8 -d "$build_dir" "$resource_dir/ClipboardBridge.java"
"$d8_tool" --min-api 26 --output "$build_dir" "$build_dir/ClipboardBridge.class"
cp "$build_dir/classes.dex" "$resource_dir/clipboard.dex"
chmod 600 "$resource_dir/clipboard.dex"
