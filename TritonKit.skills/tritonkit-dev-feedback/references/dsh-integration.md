# DSH tools integration

## Prerequisites

The optional TritonKit Host bundle wraps an installed macOS `triton`; installing the skill alone neither installs the CLI nor registers DSH tools. Before installing the plugin, confirm the CLI and its resources are installed and `triton version --json` succeeds. The plugin has no exact `engines.dsh` pin; successful loading does not prove a newer DSH runtime still provides compatible services.

## Install in DSH

1. Download the plugin archive and `SHA256SUMS.txt` from the [standalone TritonKit DSH Host 0.1.4 GitHub Release](https://github.com/NeptuneKit/TritonKit/releases/tag/dsh-tritonkit-host-v0.1.4). This is a separate release, not the TritonKit CLI or skills archive, and is not distributed through npm.
2. With both files in the same directory, run `shasum -a 256 -c SHA256SUMS.txt` there. Stop if the archive is missing or the checksum does not match. Unpack the verified archive to a permanent location; the extracted `package` directory must contain `package.json`.
3. In the intended DSH profile, open **Plugins → Add plugin** and select the extracted `package` directory. With the user's authorization, an agent can instead call `plugin_manager` with `action: install_bundle` and `target` set to that directory's absolute path. For a source checkout, use its `DSH/` directory instead. DSH links local directory installations: keep the selected directory in place and do not edit profile manifests by hand. If an existing installation points to a deleted directory, use the plugin manager to remove that entry before reinstalling.
4. Check that `@neptunekit/dsh-tritonkit-host` is enabled and, if the manager reports `restart-required`, restart DSH before checking activation. In a new session in the same profile, call `triton_query` with `{"operation":"version"}`. A successful result confirms the plugin can invoke the CLI, not that device actions were tested.

All four tools require DSH Full access (`danger-full-access`) before subprocess startup; they refuse narrower modes rather than asking for escalation. This requirement is not authorization for a particular device/App action.

## Workflow

1. Confirm the tools are actually available in this agent. Start with version, then a narrow schema. JSON blocks below are **tool arguments**, not shell commands; replace discovery placeholders before use.

Tool: `triton_query`

```json
{"operation":"version"}
```

Tool: `triton_schema`

```json
{"command":"act.tap"}
```

2. Discover namespaced IDs. Query operations are `version`, `status`, `doctor`, `capabilities`, `plan`, `targets`, `observe-current`, `observe-tree`. `targets` requires platform; observation requires both platform and target. Maximum nodes defaults to 100, range 1–1000.

Tool: `triton_query`

```json
{"operation":"targets","platform":"ios"}
```

Tool: `triton_query`

```json
{"operation":"observe-tree","platform":"ios","target":"sim:<observed-UDID>","maxNodes":100}
```

3. After explicit action authorization, submit one supported action: `tap`, `type`, `press`, or `swipe`. Choose a text query **or** an x/y pair for tap. Swipe uses `startX/startY/endX/endY` and optional `duration` (0.05–5 seconds). Press buttons are `home/back/lock/power/volume-up/volume-down`, subject to provider support.

Tool: `triton_action`

```json
{"action":"tap","target":"sim:<observed-UDID>","x":120,"y":300}
```

For iOS type/press, use the connected embedded runtime target and omit platform; `platform:ios` is not accepted for those two actions. An optional `oid` is a decimal UInt64 **string**, only for embedded input without platform.

Tool: `triton_action`

```json
{"action":"type","target":"triton:ios-simulator:<observed-UDID>/app:<bundle-id>","text":"sample"}
```

4. Observe again and assert the business postcondition. Verify conditions are `text-exists` or `text-not-exists`, with optional role/count; verify requires a connected server/runtime, not merely a host device selector.

Tool: `triton_verify`

```json
{"condition":"text-exists","target":"triton:ios-simulator:<observed-UDID>/app:<bundle-id>","text":"Done","count":1}
```

## Verification

Inspect `success`, actual `exitCode`/`signal`, `truncated`, original `payload`/`payloadStream` and `error.code`. A schema response need not contain `ok`; do not manufacture a failure from its absence. Nonzero exit, signal, `ok:false`, `partial:true`, or provider errors are not a successful result. ACK proves submission only; independently verify the App state.

Timeout/cancellation may occur after delivery. Do not retry an action or switch backend automatically. `cleanup_uncertain` blocks subsequent dispatch until provider ownership is resolved; do not bypass that guard by opening another caller.

## Limits

- IDs must come from discovery and keep `sim:`, `ios-real:`, `android:`, `harmony:` or `triton:`. Bare names, raw serials/UUIDs, aliases and `local/current/booted/default` are rejected, even when the CLI itself accepts some of them. Host and embedded IDs are not interchangeable.
- Optional fields may be omitted; strict backends may use null for known optional fields. Unknown fields still fail. Text options reject NUL/newline, excessive length and leading dash where option safety requires it; assertion text retains its positional semantics.
- No arbitrary argv/env, custom adb/hdc, output paths, serve/web/update, Runner lifecycle, install/uninstall, deletion or replay is exposed by these tools. Use an independently authorized CLI workflow, not an invented fifth tool.
- Config keys are `executable` (absolute path or bare command), `timeoutMs` (10–120000, default 30000) and `maxOutputBytes` (1024–1048576 per stream, default 262144). Deadline includes queueing; there is no automatic CLI download or Settings form promise.
- CLI `--secure` on type limits CLI echo but does not remove text from DSH tool-argument history. Preserve original local facts; content policy and permission to publish are separate caller decisions.
- Plugin subprocess handling is not an OS sandbox or a guarantee to observe every escaped descendant. A local successful version/schema call is not device mutation or GUI acceptance.

For operations outside the wrapper, use the [bundle capability index](../../README.md) and [HTTP/CLI provider boundaries](../../tritonkit-emulator-cli-takeover/references/http-api.md).
