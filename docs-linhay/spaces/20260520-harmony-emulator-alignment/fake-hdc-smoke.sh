#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "-v" ]]; then
  echo "hdc fake version 1.0.0"
  exit 0
fi

if [[ "$*" == "list targets -v" ]]; then
  cat <<'OUT'
127.0.0.1:10100    Connected
127.0.0.1:10200    Offline
FMR0224C03001399    Connected
OUT
  exit 0
fi

if [[ "$*" == "-t 127.0.0.1:10100 shell param get bootevent.boot.completed" ]]; then
  echo "true"
  exit 0
fi

echo "unsupported fake hdc command: $*" >&2
exit 2
