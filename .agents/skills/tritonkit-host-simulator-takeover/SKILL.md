---
name: tritonkit-host-simulator-takeover
description: Use when designing, implementing, extending, or validating TritonKit host-side Apple Simulator takeover capabilities such as `triton sim`, `triton app`, xcrun/simctl wrappers, workspace simulator defaults, boot wait JSONL, app metadata, containers, preferences, host artifacts, plan/evidence integration, or replacing raw xcrun usage with Triton CLI contracts.
metadata:
  version: 0.1.0-dev
---

# TritonKit Host Simulator Takeover

## Device Hub Delivery and Evidence Rules

Deliver by capability groups: semantic App/Group containers and file-domain policies, administration execution, specialized platforms, then full compatibility acceptance. Preserve independent commands and old namespace/IDs/argv; no mandatory server/Run. Keep help advertisement, synthetic fixtures, source/DI, actual envelopes, actions and business postconditions separate; pinned /usr/bin/xcrun cannot be traced by a PATH shim. Review every discovery-error branch for raw candidates/logs/paths, preserving stable codes with static messages. DeviceFS authority is exact bytes and the same nofollow FD chain/owners/double-stat, not path re-resolution; native devicefs inode exception never broadens other filesystems. Serialize scratch/device work and set this build's TRITON_CLI_PATH. A requested local commit stages only the task's reviewed manifest, no raw evidence/builds/other spaces; do not copy unrelated research or soften docs gates to close a registry gap. A committed slice is not full Device Hub/action/platform acceptance; merge/push/release need separate authorization.

## Principle

TritonKit should be the stable interface seen by AI agents and automation. Apple tools such as `xcrun simctl`, `xcodebuild`, `devicectl`, `xctrace`, and `xcresulttool` are implementation resources behind `triton` CLI/HTTP schema, not the default product contract exposed to agents.

Keep the boundary explicit:

- Embedded runtime handles DEBUG-only in-app observation and control.
- Host simulator adapter runs only in macOS CLI / `triton serve`.
- CLI/HTTP schema, JSON/JSONL output, stable error codes, and evidence/plan integration are the user-facing contract.
- Raw `xcrun simctl`, XcodeBuildMCP, or raw `xcodebuild` are fallback paths only after a Triton-first check. Preserve `triton status --json`, `triton doctor --json`, `triton capabilities --json`, `triton schema --command sim|app|xcode --json`, or `triton plan ... --json` output showing failure, unsupported scope/capability, or a missing schema/capability before using those tools.

## Device Hub Official Inventory

For Xcode 27 compatibility, capture versioned JSON through the existing Triton discovery path before editing parsers. `devicectl list devices` may include both physical and simulated devices; actual captured properties, not terminal-table wording or details release notes alone, establish supported shapes. Modern `properties` is authoritative even when incomplete/null; do not fall back to stale deprecated mirrors to claim readiness. Preserve `sim:<UDID>` identity and simctl lifecycle authority when joining inventories. Explicit iOS `scope=all` fails on backend failure; known `sim:` / `triton:ios-simulator:` selectors with no explicit scope must stay simulator-only so unavailable physical discovery cannot break them. Unknown readiness remains `ready=false`; physical eligibility does not prove lock state, App runtime readiness or a business outcome. Keep UDID/ECID aliases and captures private, preserve legacy paired lazy-tunnel behavior, and test source precedence, shutdown, incomplete identity, default selectors and single failure envelopes.

## Old/New Xcode Command Compatibility

Keep common argv before inventing version branches. Run `triton device doctor --platform ios --scope simulator|real|all --json` against the selected toolchain: `commandSupport` records readonly nested help and mandatory options, with `verification=help-advertised-only`. This is advertised syntax, not an executed device action or business verification. Use file JSON/log output for both families; do not universally append new-only `--omit-deprecated-fields-in-json`, use new stdout JSON conventions, or retain removed details `--show`. Simulator-only health must not query/require CoreDevice; real/all must require CoreDevice discovery. Probe version through xcrun, inherit/override DEVELOPER_DIR only in child environment, and never change global selection or retry a failed write through another backend. Distinguish contract fixtures from actual old/new installations; unavailable old toolchains remain an explicit validation gap.

For old-Xcode command retention, preserve existing registrations and standalone argument forms; do not make a workflow/Run mandatory or require installing a second Xcode. With explicit permission for isolated action validation, use `triton sim create <name> --device-type <identifier> --runtime <identifier> --json`, record ownership, and mutate only that new device. An existing shutdown/default device is not isolation. Booted state and a screenshot file do not prove UI/business readiness. After a write timeout, query app info/list before recovery; installation may have completed even though the client timed out. Never blindly reinstall or change backends.

## Device Hub readonly information

`triton device info --platform ios --device <selector> [--scope simulator|real|all] [--lock-state] [--timeout <seconds>] --json` is a standalone CoreDevice file-JSON query, not a workflow/Run prerequisite. Simulators must already be started and physical devices paired; it never boots, pairs or unlocks automatically. Missing/failed/mismatched snapshots fail closed, not via a second backend. Raw identifiers, aliases, serials, IPs, screenViewingURL, human stdout and Apple capability arrays must not enter public information output. Hardware is whitelisted; `--lock-state` exposes observed `passcodeRequired`/`unlockedSinceBoot`, not `screenLocked` or business readiness. Missing booleans stay unknown; without the flag lockState is `not-probed`. Timeout is per query and nil keeps old backend defaults. Structured CoreDevice1001 getlockstate rejection returns `unsupported_device_info_query`; never silently drop the requested flag or infer a global Simulator restriction. Details without the flag are a separate deliberate query, not a recovery success for the failed lock probe. Full Device Hub support requires per-capability mapping and verification, not only discovery or a help probe.

`triton device files --platform ios --device <selector> --domain-type systemCrashLogs --json` is standalone shallow metadata, not content transfer. App domains require --domain-identifier; optional domain-relative --subdirectory/--username must bind to file JSON. Default names/paths are private correlation tokens; --include-sensitive only reveals those metadata fields, never owners/xattrs/content/raw identities. JSON/count bounds are local acceptance only, not remote disk limits. Preserve unsupported_device_file_query for exact CoreDevice1001 listFiles restrictions; temporary returns device_file_domain_policy_required before backend, not blanket platform unsupported. Never automatically boot/pair/unlock, query temporary, copy or retry DeviceFS. Non-directory does not prove a regular file, isReadable stays unknown when missing, and upstream isWritable is not authorization.

`device mountpoint --platform ios --device <selector> --json` is a separate CoreDevice metadata query, not recovery success for failed files. Require exact unique echoed --device (result has no device identity); never bind by path or stale aliases. Output only devicefs correlation token/redacted target/private JSON-log references; dataPath/raw identities never inline. No stat/realpath/open/list of returned path/Finder/explicit mount-unmount, no auto boot/pair/unlock/fallback. hostFilesystemInspected/mountStateVerified/contentsListed/businessReadinessVerified=false. Service communication/private artifacts are side effects; no existence/mounted/read/write claim. JSON budget is local acceptance, unknown feature query_failed rather than guessed unsupported.

Identity-bound `device info` exposes optional hardware.platformObservation: exact ASCII explicit hardware systemFamily/deviceFamily/reality whitelist, modern/legacy sourceLayout; old archived hardware missing it Codable-compatible. Never infer OS/iPadOS/physical from name/product/marketing/runtime/legacy ios namespace/capabilities. iOS+iPad remains ios/ipad, unknown reality not physical, unknown raw observations not echoed. Present modern properties even null/partial block deprecated mirrors. Preserve dispatch/IDs/argv and do not grant controls/readiness. Require nested schema/CLI propagation/roundtrip plus bound current SDK readonly proof; other families fixture-only, no platform-wide action claim.

Use `device platforms --json` for compiled six-family Apple integration catalog, not current SDK/actions/business acceptance. Optional --apple-platform filters catalog only; --inventory is one readonly available Simulator query and global counts, unknown retained/no IDs/names/raw runtime. Default zero queries, no physical query/boot/control/server. iOS runtime never proves iPadOS or distinguishes iPhone/iPad; no Mac Simulator/name guess, zero not unavailability. Catalog control/auth flags false are report-only/no authorization, not existing-function denial. Keep legacy ios namespace/IDs/argv; no Apple capability-array or generic sim command autoenable. Require strict ASCII numeric runtime fixture, zero/default/filter provider counters and private failure/static code, actual envelopes not native action/state proof.

Administration `device pair|unpair|diagnose --platform ios --scope real --device <selector> --plan-only --json` is readonly policy review ONLY (diagnose requires private ZIP --output), not old sim operations. Always executable/executed=false; ok can include unsupported SDK with support=false/blockers/no preview. Never execute or collect/pair/Finder/profile install/DDI mount; metadata discovery/help may cache/communicate. Require pre-IO invalid guard tests, fresh real primary hash, preview/input/error privacy and static discovery errors with stable codes, not raw logs/candidates/paths. SDK help and policy plan do not accept native action JSON/postconditions/auth/audit/archive content/permission/nooverwrite/nofollow/size. Disable host sysdiagnose does NOT exclude host CoreDevice logs. No device-only/crash equivalence, no action fallback or mandatoryserver/Run. Triton pins /usr/bin/xcrun: PATH wrapper is not invocation trace; do not claim external trace/physical state proof from plan envelopes.

Use optional `--subdirectory <container-relative-directory>` only with explicit container and app-data/app-group view. Raw 1...32 components/4096 UTF8 bytes/255 per component, no absolute/dot/dotdot/empty/control, never normalize or URLdecode; omitted retains container-root tokens. Preflight input and standard-root shape total64-depth/16384-byte before discovery/artifacts (UUID placeholder never opened/queried/authorizes); fresh actual root UTF8 bytes/discovery UUID binding and repeated budget still required before directory IO. Same-FD `index+1 >= rootCount` checks root and every relative layer; system ancestors nofollow, not required to be current uid. Scope tokens add exact subdirectory bytes, no input-field echo, opt-in leaves may coincide. Actual owned subdirectory must already appear in opted-in container metadata, no creation; shallow metadata/default+optin/privacy/bounds/finally all name/state restore, never content/recursive/outsidecontainer/Finder/autoprep/fallback. App container tmp is not DeviceFS Temporary-domain creation. Root prefix authority compares UTF8 bytes, not Swift canonical String equality.

`device fs list --view app-data-containers|app-group-containers --container-identifier <native-child-name> --json` accepts one explicit native child (1...255 UTF8 bytes; no slash/dot/dotdot/controls, unchanged bytes), not a hostpath, outside-container path or verified bundle/group identity. Validate before discovery/artifacts; check device-root and each relative-layer owner on same FD nofollow chain. Omitted selection keeps old tokens, explicit selection emits opaque directoryToken/view+container salted entries. No selector-field echo, even opt-in; opt-in leaf names can coincide with selector. Exact 255-byte and NFC/NFD-byte-token fixtures covered; not proof of physical object equality/secrecy. Require owned metadata-only actual acceptance and all name/state restoration, no content/write/install/launch/recursive/Finder/autoprep/fallback.

`device fs list --platform ios --device <selector> --json` is an explicit fixed-namespace DeviceFS backend: --view mount-root(default)|app-data-containers|app-group-containers, not bundle/group-ID navigation or files-error fallback. Check device-root owner before relative open then namespace owner, same FD chain. Native DeviceFS exposes non-comparable synthetic readdir/stat IDs: same-FD fstatfs must report exact devicefs to admit that difference, always require double nofollow stat inode/device/kind stability; other FS types retain strict dirent binding. entryIdentityVerification is not atomic snapshot or provenance proof. Old mount-root token algorithm stays; new views salted to avoid equal-name collisions. It reuses fresh private mountpoint fileJSON exact identity binding, admits only exact standard home parent/device-UUID.localized root matching current discovery primary (physical) or UUID aliases (Simulator), opens original bytes with per-component nofollow, checks owner on same final FD. Default entries are token/kind/regular size; include-sensitive admits names only. No hostpath/subdirectory input/content/recursive/domain guess/temporary/Finder/explicitmount/autoprep; mount/readWrite/business verification false, hostFilesystemInspected true. Root directory name is not domain mapping evidence. Do not map Simulator crash logs by guessing DiagnosticReports: owned-instance metadata can expose a different root namespace. Descriptor-relative O_NOFOLLOW path walking and fstatat(AT_SYMLINK_NOFOLLOW) prevent following symlinks; never substitute realpath normalization for that boundary. Budgets bound accepted entries/depth/path bytes, not FUSE syscall deadlines/remote transfers, and listings are not atomic snapshots. APFS may reject invalid UTF8 fixture creation; test the exact dirent-byte decoding boundary instead of counting impossible fixture creation as product failure.

## Current P0 Contract

Simulator commands:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim rename <explicit-uuid> "New Name" --timeout 30 --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json
triton sim record --simulator <udid-or-booted> --output /tmp/<case>-sim.mov --duration 10 --json
triton sim logs --simulator <udid-or-booted> --output /tmp/<case>-sim.ndjson --duration 5 --json
triton sim app-console --simulator <udid-or-booted> --bundle-id <bundle-id> --output /tmp/<case>-app-console.log --duration 5 --max-bytes 10485760 --json
triton observe tree --platform ios --device <udid-or-booted> --json
triton wait --platform ios --device <udid-or-booted> --text <visible-text> --json
```

`wait --platform ios` is the host-side companion to Simulator AX observation. It supports `--text`, `--exists`, and `--gone` with an optional AX `--role`, resolves only ready local Simulator targets, and returns `host.ios-wait`. It must not query embedded `/targets` or require `triton serve`; use plain `wait` without `--platform ios` for embedded runtime conditions such as idle, hierarchy change, or predicates.

`sim record` success requires media validation, not only `simctl` exit zero. The JSON response exposes requested, actual encoded-sample, minimum accepted, container, and track durations. Container/track timelines can report the requested duration even when the MOV has only one frame, so Triton computes `actualDurationSeconds` from `AVSampleCursor` encoded samples. Treat `sim_record_truncated` and `sim_record_invalid_artifact` as failed evidence and never claim a usable recording from the file path alone.

For iOS Simulator evidence, treat the host-composited framebuffer as the visual acceptance fact. When the embedded runtime target exposes a reliable `simulatorUDID`, `triton evidence capture --include screenshot` publishes the host framebuffer as primary `screenshot.png` with `scope=host-simulator`, `source=simctl-framebuffer`, and `fidelity=full-screen`, while retaining the embedded App-layer image as `screenshot.runtime`. If host capture fails, the runtime screenshot remains diagnostic only and the manifest must return `evidence_capture_partial` plus `host_screenshot_unavailable` and a structured `triton sim screenshot` recovery action. Never claim system sheet, keyboard, SpringBoard, or other compositor content from an App-layer screenshot.

`sim logs` and `sim app-console` are deliberately separate. The former captures bounded unified logging and declares only `sourcesCaptured=[unified-log]`. The latter preflights App metadata, terminates/relaunches the bundle through `simctl launch --console-pty`, and writes merged process stdout/stderr to a sensitive duration/byte-bounded artifact. Require `sourcesCaptured=[process-stdout,process-stderr]`, `streamLayout=merged-pty`, bytes/truncation metadata, redacted env values, and no inline console body in JSON.

App commands:

```bash
triton app list --simulator <udid-or-booted> --user-only --json
triton app info --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app install --app <path.app> --simulator <udid-or-booted> --json
triton app uninstall --bundle-id <bundle-id> --simulator <udid-or-booted> --confirm --json
triton app launch --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app terminate --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app open-url '<url>' --simulator <udid-or-booted> --json
triton app open-url '<url>' --simulator <udid-or-booted> --wait-ready --snapshot --json
triton app container --bundle-id <bundle-id> --kind data --simulator <udid-or-booted> --json
triton app prefs get <key> --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app prefs dump --bundle-id <bundle-id> --simulator <udid-or-booted> --json
```

Phase 3 host-side maintenance commands:

```bash
triton sim pair <watch-udid> <phone-udid> --json
triton sim unpair <pair-uuid> --json
triton sim clone <udid> "Clone for Smoke" --json
triton sim erase <udid> --confirm --json
triton sim upgrade <udid> <runtime-id> --json
triton sim runtime list --json
triton sim runtime verify <runtime-id> --json
triton sim runtime add /tmp/iOSSimulatorRuntime.dmg --json
triton sim runtime delete all --dry-run --json
triton sim runtime delete <runtime-id> --confirm --json
triton sim runtime unmount <runtime-id> --json
triton sim runtime scan-and-mount --json
triton sim runtime match list --json
triton sim runtime match set iphoneos26.5 23F77 --json
triton sim runtime match set iphoneos26.5 --default --json
triton sim runtime dyld-cache update <runtime-id> --json
triton sim runtime dyld-cache remove <runtime-id> --confirm --json
triton sim personalization personalize <runtime-id> --json
triton sim personalization remove-manifest manifest.plist --confirm --json
triton sim personalization remove-all-manifests --confirm --json
triton sim personalization remove-personalization <id> --confirm --json
triton sim personalization revoke-manifests --confirm --json
triton sim personalization scan-and-personalize --json
```

Host-side Simulator proxy is the accepted iOS network takeover lane:

```bash
triton sim proxy start --simulator <udid-or-booted> --mode record --output <dir> --json
triton sim proxy status --simulator <udid-or-booted> --json
triton sim proxy export --simulator <udid-or-booted> --output <path.har|path.ndjson> --json
triton sim proxy stop --simulator <udid-or-booted> --restore --json
```

Current P0 implementation exposes the alias command and schema safely: `doctor/status` return the shared `host.device-proxy` envelope, while CLI `start/export/stop` return `ok:false` with `proxy_platform_not_supported` until the real host proxy adapter, certificate setup, capture export, and restore workflow land.

Current P1 implementation has a fake iOS proxy adapter, pure `networksetup` command planners, an injectable proxy command runner test boundary, endpoint preflight, original-value restore snapshots, file-backed session state, a shared local capture/mock/block/throttle proxy service, metadata-only HAR export, and explicit CLI runner opt-in for `device proxy` / `sim proxy`. Use them for tests before touching host state: fake start/status/export/stop writes only temporary restore/capture artifacts, override/restore planners generate `networksetup` argv and mark mutation commands `break-glass` with audit/timeout requirements, and fake command runners can prove success plus `proxy_start_failed` / `proxy_restore_failed` envelopes without calling host tools. Real execution requires `--confirm --audit-record <id> --execute-runner`; missing any part must remain non-mutating. Start writes `<output>/restore-state.json` when `--output` is provided, including readonly `networksetup -getwebproxy/-getsecurewebproxy/-getsocksfirewallproxy/-getproxybypassdomains` snapshot commands and `serviceSnapshots[]`; stop can consume it through `--restore-snapshot <path>`. Use `sim proxy stop --simulator <udid-or-booted> --restore-snapshot <path> --plan-only --json` to review the snapshot `restoreCommands` without changing host settings before running the break-glass restore command. If snapshot restore fails, TritonKit writes `<snapshot-dir>/restore-failure.json` with schema `triton.proxy.restore-failure.v1`, returns it as `artifacts[].kind=proxy-restore`, and keeps `restore.restored=false`. Start also writes `<output>/session-state.json` with schema `triton.proxy.session.v1`, including persisted cert state, and `<output>/requests.ndjson` as the session capture artifact. Use `sim proxy status --simulator <udid-or-booted> --session <dir> --json` to read persisted state; older sessions without cert fall back to conservative certificate state. When `restore-failure.json` is present next to the session or restore snapshot, status includes a `proxy-restore` artifact so the failed-restore context stays discoverable. Use `sim proxy export --simulator <udid-or-booted> --session <dir> --output <path.ndjson|path.har> --json` to export the persisted capture artifact. `.ndjson` copies the capture artifact as-is, while `.har` converts `proxy.serve.request` events into a HAR 1.2 metadata-only skeleton: forwarded requests keep `status=0/not captured`, while mock / block / throttle requests write `200 TritonKit Proxy Mock` / `502 TritonKit Proxy Blocked` / `429 TritonKit Proxy Throttled`; HAR entry `comment` summarizes `captureMode`, `policyAction`, optional `mockRuleId`, optional `throttleDelayMs`, and the metadata-only redaction boundary. NDJSON request events also expose the synthetic local policy response through `responseStatus` / `responseStatusText`, so agents can inspect block/mock/throttle evidence without exporting HAR. Use `device proxy serve --listen 127.0.0.1:19431 --output <dir> --mode record|mock|block|throttle --jsonl` as the local listener/capture writer before running the iOS `networksetup` runner; it writes `proxy.serve.request` metadata-only events and records header names only. `record` attempts upstream forwarding; `mock` returns a fixed JSON mock response without upstream and writes `responseStatus=200`; `block` returns `502 TritonKit Proxy Blocked` without upstream and writes `responseStatus=502`; `throttle` returns `429 TritonKit Proxy Throttled` plus `Retry-After: 1` without upstream as a synthetic rate-limit policy and writes `responseStatus=429`. Do not treat its CONNECT metadata, synthetic response fields, or HAR skeleton as decrypted HTTPS body visibility. Do not expand beyond this runner path without richer capture export evidence and smoke coverage.

`device proxy serve --policy-rules <path.json>` is the shared host-side per-request policy layer for the same listener. Rules use schema `triton.proxy.policy-rules.v1`, match method / host / path / pathPrefix, and choose `forward`, `mock`, `block`, or `throttle`; matched request events and HAR comments expose `policyRuleId`. Synthetic response bodies remain client-only and must not enter `requests.ndjson` or HAR. Treat this as iOS Simulator proxy policy evidence only after traffic reaches the host listener; it is not App-internal interception and not decrypted HTTPS body visibility.

Use `triton device proxy probe --platform ios --device <udid-or-booted> --json` when an iOS Simulator workflow needs readonly proxy capability evidence before runner review. The response should keep `action=proxy.probe`, `configured=false`, `probeResults[]`, and `proxy_probe_readonly:not_mutated`; it may inspect `networksetup` snapshot state but must not modify host proxy settings.

`triton plan network-proxy --platform ios ... --certificate <path.cer> --audit-record <id> --json` should surface `device proxy probe --plan-only` as the first proxy-specific next step, then `device proxy cert plan --platform ios --device <udid-or-booted> --certificate <path.cer> --json`, then `device proxy cert install --platform ios --device <udid-or-booted> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` as a break-glass audit command, before `device proxy serve --jsonl`. The `proxy-serve` step should expose `requiresLongRunningProcess=true`, `readyEvents=["proxy.serve.ready"]`, `finalEvents=["proxy.serve.summary"]`, and `terminationSignals=["sigint","sigterm"]`, so agents keep the listener alive through the ready event while reviewing or executing later Simulator proxy mutation / status / export / restore steps, then stop it cleanly and read the summary event. If the task plan includes `--policy-rules <path.json>`, only the `proxy-serve` argv should receive that flag; Simulator proxy mutation and restore review commands should stay focused on audited platform state changes. After the listener is ready, it should show `device proxy start --plan-only` followed by `device proxy start --confirm --audit-record <id> --execute-runner --json` as the Simulator proxy mutation audit command, and finish with `device proxy stop --restore-snapshot <restore-state-json> --plan-only --json` followed by `device proxy stop --restore-snapshot <restore-state-json> --confirm --audit-record <id> --execute-runner --json` as the restore audit command. When the task plan has a concrete `--output`, the restore snapshot path should resolve to `<output>/restore-state.json`. This lets an agent review readonly Simulator proxy state, certificate preparation, certificate install policy, platform proxy mutation policy, and the original-value restore ledger before planning break-glass runner execution.

The iOS proxy lane is Simulator-only. Any `HostDeviceTarget` with `scope=real` or `kind=real-device` must return `proxy_real_device_not_supported`, keep `configured=false`, and leave `sourceCommands[]` / `artifacts[]` empty. The proxy planner must preserve `ios-real:` selector prefixes as real-device targets so they hit this rejection envelope instead of being coerced into Simulator ids; do not route real iPhones through the Simulator `networksetup` runner or alias.

`device proxy --device <selector>` and the iOS `sim proxy --simulator <selector>` alias should honor workspace target aliases consistently. Resolve `.triton/host-targets.json` aliases and `current` before generating proxy plan targets, normalize `sim:` aliases to the raw Simulator UDID / `booted` token, and preserve real-device aliases as `proxy_real_device_not_supported`. Do not let a friendly alias such as `iphone15` leak into `host.device-proxy` target fields, `networksetup` ledgers, or future `simctl keychain` ledgers when it maps to a concrete Simulator id.

`sim proxy export --session` / `device proxy export --session` should return `requestCount`, `eventCount`, `failureCount`, `redaction`, and `truncation` on the `NetworkProxySession` envelope. Use those fields as the first proof of capture quality before inspecting the artifact: `eventCount=0` means no observed serve events yet, `requestCount=0` means no successful `proxy.serve.request` events, and `failureCount>0` means capture/proxy failures such as `proxy.serve.connection-failed` are present. If the capture artifact is missing or cannot be exported, expect `proxy_artifact_write_failed` with archive recovery.

`device proxy serve --jsonl` final `proxy.serve.summary` should also return `eventCount`, `requestCount`, and `failureCount`. In this live serve summary, `eventCount` counts stdout JSONL events emitted before the summary itself, including `proxy.serve.ready`, request events, and connection failures; `failureCount>0` is an immediate signal that the listener observed malformed, disconnected, or failed upstream traffic before export.

Use `triton evidence --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` or `triton capture --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` to archive an iOS Simulator proxy session into `.tritonevidence`. This copies `session-state.json` and the declared `network-capture` artifact as sensitive evidence; if a restore failure artifact is present through `<dir>/restore-failure.json`, a declared `proxy-restore` artifact, or the `restoreSnapshotPath` sibling file, it is also copied to `artifacts/network/restore-failure.json` as sensitive `proxy-restore` recovery evidence. Still require `proxy.serve.request` events before claiming observed traffic, and treat `proxy-restore` as failed-restore context rather than proof that restore succeeded. If the capture artifact is missing, keep `network.proxy-session`, import `proxy-restore` when present, and skip only `network-capture`.

For reusable replay plans, encode the same archive path as an `evidence` step with `include: "network.proxy-session"` and `proxySession: "<dir>"`. `plan inspect` and `replay --dry-run` should both expose `--proxy-session` in `steps[].argv` and list `network.proxy-session` / `network-capture` in `expectedArtifacts[]`; real replay imports the existing session. If a real replay fails before that evidence step, it should stop later business actions/assertions but still execute a proxy-only archive from the later `network.proxy-session` evidence step, so the failure keeps proxy state without starting a listener or mutating Simulator proxy settings.

For reusable proxy lifecycle plans, use `proxy-probe`, `proxy-serve`, `proxy-start`, `proxy-export`, and `proxy-stop` only as inspect / dry-run audit steps. They should emit `triton device proxy probe --plan-only`, `serve --jsonl`, `start --plan-only`, `export --plan-only`, and `stop --restore --plan-only` argv; when a concrete session directory is known, use `stop --restore-snapshot <restore-state-json> --plan-only` for the final restore review and resolve that token to the session directory's `restore-state.json`. `plan inspect` should also expose lifecycle defects in `steps[].validationErrors[]`, including missing platform/device/proxy/output, export before start, and stop without `restore=true`. Real replay must not start the proxy listener or mutate Simulator proxy settings and should return dry-run-only / unsupported until an operator explicitly executes the reviewed command.

When a reusable `.tritonplan` proxy lifecycle needs listener policy, attach it only to the `proxy-serve` step: `mockRules` maps to `device proxy serve --mock-rules` only in `mode=mock`, `policyRules` maps to `--policy-rules`, and `throttleMs` maps to `--throttle-ms` in `mode=throttle`. Non-mock serve modes should reject `--mock-rules` instead of silently ignoring it. Do not propagate these listener-only flags to `proxy-start`, `proxy-stop`, certificate install, or restore review commands; those remain focused on audited Simulator proxy mutation and original-value restore. This still proves only host-listener policy behavior after traffic reaches the listener, not App-internal interception or decrypted HTTPS bodies.

`sim proxy doctor/status` / `device proxy doctor/status --platform ios` should keep `NetworkProxySession.cert` machine-readable even before certificate installation exists. Until trust setup is implemented and verified, expect `installed=false`, `trusted=false`, and scope `simulator`; this is evidence of limited HTTPS visibility, not proof of TLS interception.

For certificate preparation, use `triton device proxy cert doctor --platform ios --json` and `triton device proxy cert plan --platform ios --device <udid-or-booted> --certificate <path.cer> --json`. The plan may list `xcrun simctl keychain <target> add-root-cert <path.cer>` and a `proxy-certificate` artifact, but it is still plan-only: it must not call `simctl keychain`, install trust, or claim decrypted HTTPS visibility. After reviewing that ledger, `triton device proxy cert install --platform ios --device <udid-or-booted> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` may execute the Simulator root certificate install through the break-glass runner. Missing any policy flag must return `destructive_action_requires_policy`, and success still needs explicit limitations for certificate pinning, custom transports, and traffic bypassing the system proxy.

This lane must not require App-side URLProtocol, method swizzling, SDK network interceptors, or embedded runtime network providers. It configures and observes the simulator through host-side proxy state, certificate setup, capture artifacts, and stable JSON limitations. If traffic bypasses the system proxy, uses certificate pinning, custom sockets, private encryption, or unsupported QUIC paths, report limited visibility through explicit error/warning codes such as `proxy_visibility_limited`, `proxy_cert_untrusted`, or `proxy_unsupported_transport`.

`triton sim use` writes repo-local workspace defaults to `.triton/host-defaults.json`. Do not run smoke writes in the repository unless that file is intentionally part of the test. Use a temporary working directory for validation when possible.

For `triton workspace run` flows that use a selector such as `current`, `booted`, or a workspace alias, add `--resolve-target` (HTTP `resolveTarget=true`) before app lifecycle, live observe, action, wait, or assertion steps. Workspace target resolution reuses host target discovery, writes the stable host target id plus `selector`, raw `hostTarget`, readiness metadata, and `sourceCommands` to `evidence/model/target.json`, then uses the resolved raw target downstream. Business readiness can be proven by runtime wait (`--business-ready-live-wait`) or runtime verify text-exists (`--business-ready-assert` / HTTP `businessReadyAssert=true`). Keep default dry / fixture runs unresolved unless the run should touch host discovery. When the selector depends on custom tools, preserve `--hdc` / `--adb` in the workspace command so the target sourceCommands remain reproducible.

`triton app open-url` only proves that the URL was submitted to Simulator. When an embedded runtime is connected, prefer `--wait-ready --snapshot` for a one-shot host action plus runtime readiness/snapshot summary. Otherwise always verify business completion with `triton wait`, `triton find`, `triton assert`, `triton app prefs get`, a fresh screenshot, or an evidence bundle.

For `triton act tap`, pure coordinate input with an explicit Simulator host selector (`sim:<UDID>`, raw UUID, `booted`, or `current`) must route to the ready local host-HID adapter before embedded `/targets` lookup. Do not let the legacy same-`simulatorUDID` runtime fallback send coordinates to a stale/background App. Canonical `triton:ios-simulator:<UDID>` and `/app:<bundle-id>` remain embedded selectors. Host-HID acknowledgement remains submission-only and requires a separate business postcondition check.

`simctl appinfo` can exit 0 for a missing bundle while only echoing `CFBundleIdentifier`; Triton normalizes this to `app_info_not_available`. Do not treat raw `simctl` exit code alone as proof of installed app metadata.

`triton app info` and `triton app list` expose installed iOS app metadata as distinct structured fields: `marketingVersion` (from `CFBundleShortVersionString`, e.g. `2.4.1`) and `buildNumber` (from `CFBundleVersion`, e.g. `42`). Use them to verify an installed Simulator app matches an expected release version instead of reading `Info.plist` separately. The legacy `version` field is retained for compatibility and maps to the build number on iOS (identical to `buildNumber`); new consumers should prefer `marketingVersion` / `buildNumber` and treat `version` as deprecated. The `host.app-info` and `host.app-list` schema contracts document these fields.

## Implementation Workflow

1. Start from the simulator takeover space:
   - `docs-linhay/spaces/20260520-simulator-takeover/README.md`
   - `docs-linhay/spaces/20260520-simulator-takeover/technical-design.md`
   - `docs-linhay/dev/20260520-simulator-takeover-architecture.md`
2. Define or update BDD acceptance in the space before code changes.
3. Add shared model tests first:
   - command argv builders in `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift`;
   - parser behavior for JSON/OpenStep plist/plain text outputs;
   - stable error edge cases such as missing apps or ambiguous targets.
4. Implement shared contracts in `Sources/TritonKitShared/TKHostAdapterModels.swift`.
5. Expose CLI commands in a focused file under `Sources/TritonKitCLI/`, keeping output machine-readable:
   - one-shot commands return JSON;
   - progress commands return JSONL when requested;
   - failures return `{ ok:false, error:{ code, message, hint, nextAction? } }`;
   - host actions include source command / risk metadata where available.
6. Update `commandSchemas()` for every agent-facing command.
7. Sync documentation:
   - `README.md`;
   - `docs-linhay/dev/ai-cli-readable-control.md`;
   - simulator takeover space implementation notes;
   - `tritonkit-emulator-cli-takeover` when cross-platform emulator CLI boundaries change;
   - `tritonkit-real-project-regression` when real app validation flow changes;
   - `tritonkit-dev-feedback` when issue evidence commands change;
   - memory entry for decisions, risks, and verification.

## Validation

Minimum local validation for host simulator adapter changes:

```bash
swift test --filter TKHostAdapterModelsTests
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command sim --json
.build/cli/debug/triton schema --command app --json
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/check-docs.sh
```

Run real simulator smoke only when it is safe for the current machine state:

```bash
.build/cli/debug/triton sim list --json
.build/cli/debug/triton app list --simulator booted --user-only --json
.build/cli/debug/triton app info --bundle-id <known-bundle-id> --simulator booted --json
.build/cli/debug/triton app info --bundle-id com.example.missing --simulator booted --json
```

For simulator camera hook smoke, keep injection scoped and clean it up:

```bash
.build/cli/debug/triton camera on --bundle-id <bundle-id> --json
.build/cli/debug/triton camera serve --socket /tmp/tritonkit-sim-camera.sock --json
.build/cli/debug/triton app launch --bundle-id <bundle-id> --device <udid-or-booted> --json
.build/cli/debug/triton list --json
.build/cli/debug/triton act tap --target <ios-runtime-target-from-triton-list> --x <x> --y <y> --json
.build/cli/debug/triton observe tree --platform ios --device <udid-or-booted> --outline --json
.build/cli/debug/triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-camera.png --json
.build/cli/debug/triton camera off --bundle-id <bundle-id> --json
```

Success needs all three facts: `app launch` redacts `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` / `SIMCTL_CHILD_TRITON_SIM_CAMERA_SOCKET`, `observe tree` shows camera status plus an increasing frame count, and the screenshot shows rendered frame content. Stop `camera serve` after the smoke; do not leave bundle injection enabled.

For `sim use`, validate in `/tmp` or another disposable directory:

```bash
mkdir -p /tmp/triton-sim-use-smoke
(cd /tmp/triton-sim-use-smoke && /path/to/triton sim use <udid> --json)
```

Avoid destructive or stateful smoke such as reinstalling business apps, erasing simulators, uninstalling apps, replacing `.xcappdata`, or modifying privacy/location unless the current task explicitly requires it.

## Priority Backlog

Keep P0/P1 focused on real-project regression value:

- P0 remaining: safer default simulator resolution, app install result enrichment.
- P1: `sim privacy`, `sim location`, `sim ui/status-bar`, push notification, media/contact import, keychain certificates, pasteboard, iCloud sync, `.xcappdata`, logs, host evidence artifacts.
- P1: Simulator proxy record/mock/block/throttle/export with host-side certificate and restore workflow.
- P2+: host UI snapshot/tap/type/press, richer record-video progress/diagnostics, diagnose, xctrace, Xcode build/test, coverage, SwiftPM.

## Boundaries

- Do not add Web/Wails UI for host simulator control while CLI/HTTP can satisfy the automation contract.
- Do not put host-side process execution into the iOS embedded runtime.
- Do not expose XcodeBuildMCP tool names as TritonKit product API; use it as reference only.
- Do not use interactive confirmation gates for long-running automation. Use `riskLevel`, objective required config, audit metadata, and explicit command flags/policy instead.

## Device Hub 容器与管理执行证据

SDK apps 显式 bundle/group 成员与原生路径绑定不等于 DeviceFS 目录绑定；保留两个独立后端，禁止目录名猜语义。Temporary 按可能创建域建模，完整执行策略与持久审计前不得query。管理命令以严格原生JSON和独立后置状态判结果，现代字段存在（包括null）不得复活旧镜像；未知 result 布局保持partial，trust不冒充pairing。诊断ZIP校验须关联central/local records与payload边界，安全发布与真实采集验收分开，fixture不能称真机验证。

`device platform-control --platform <watchos|tvos|visionos|macos> --action <control> --json` 目前只提供事实契约：watchOS Crown/Action 与 tvOS remote/focus 返回 `fixture-only`（Crown 需有限非零 `--delta`），visionOS gaze/pinch/scene、watchOS side-button 与 macOS Device Hub 控制返回 `unsupported`。所有这些结果均为 `executable=false`、`actionsExecuted=false`；没有 Triton XCTest runner 或目标绑定时，不得把 XCTest API 名称、fixture 或 GUI 证据升级为真实输入验收。

显式执行门禁（仍需专用 runner 产物和专用 runtime）：`device platform-control ... --device <exact-udid> --xctestrun <private.xctestrun> --test-identifier <target/class[/method]> --result-bundle <fresh.xcresult> --audit-record <id> --execute-runner --confirm --json`。只接受精确 UDID，执行前校验 watchOS/tvOS runtime family，使用 `xcodebuild test-without-building`；结果必须绑定 target/action/nonce/event/postcondition。普通 exit 0、缺结果、超时或目标替换保持 unknown，不自动重试。
