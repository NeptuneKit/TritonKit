#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OHPM="${OHPM:-/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm}"
HVIGORW="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"

cd "$ROOT"

"$OHPM" install
DEVECO_SDK_HOME="$DEVECO_SDK_HOME" "$HVIGORW" --mode module -p module=entry@default assembleHap

HAP="$(find entry/build -name '*.hap' | head -1)"
if [[ -z "$HAP" ]]; then
  echo "missing HAP output" >&2
  exit 1
fi

echo "$HAP"
