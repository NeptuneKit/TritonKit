补充调研后，设计里追加了一批首版未列出的 simulator takeover 能力，并按优先级分层：

## P1: real-project state preparation

- `sim media add`: wrap `simctl addmedia` for photos, videos, Live Photos, and vCard contacts.
- `sim keychain add-root-cert/add-cert/reset`: install trusted roots and certificates for HTTPS proxying and enterprise cert testing.
- `app data install`: wrap `simctl install_app_data` for `.xcappdata` sandbox restoration.
- `app info/list`: expose `simctl appinfo` and `simctl listapps`.
- `sim icloud sync`: wrap `simctl icloud_sync`.

## P2: advanced debugging and host state

- `sim pasteboard sync`: wrap `simctl pbsync` for host-to-simulator and simulator-to-host pasteboard sync.
- `sim env get`: wrap `simctl getenv`.
- Environment mutation can be modeled through `simctl spawn <udid> launchctl setenv/unsetenv` later.
- `sim diagnose`, video recording, and log stream should remain JSON/JSONL artifact-producing commands.

## P3: Xcode workflow parity inspired by XcodeBuildMCP

- coverage summary / uncovered lines from `.xcresult`
- SwiftPM build/test/run
- project scaffolding
- project/workflow discovery and session defaults

## P4: runtime maintenance and multi-device topology

- watch/iPhone pair, unpair, pair activate
- simulator upgrade / clone / rename
- simulator runtime add/delete/list/verify/match/dyld shared cache
- personalization manifest management

Destructive commands such as `runtime delete`, `keychain reset`, `sim erase`, `app uninstall`, and `.xcappdata` install should require `--confirm` or `confirm: true` in `.tritonplan`.
