---
name: tritonkit-host-simulator-takeover
description: Use when designing, implementing, extending, or validating TritonKit host-side Apple Simulator takeover capabilities such as `triton sim`, `triton app`, xcrun/simctl wrappers, workspace simulator defaults, boot wait JSONL, app metadata, containers, preferences, host artifacts, plan/evidence integration, or replacing raw xcrun usage with Triton CLI contracts.
metadata:
  version: 0.1.0-dev
---

# TritonKit Host Simulator Takeover

## Principle

TritonKit should be the stable interface seen by AI agents and automation. Apple tools such as `xcrun simctl`, `xcodebuild`, `devicectl`, `xctrace`, and `xcresulttool` are implementation resources behind `triton` CLI/HTTP schema, not the default product contract exposed to agents.

Keep the boundary explicit:

- Embedded runtime handles DEBUG-only in-app observation and control.
- Host simulator adapter runs only in macOS CLI / `triton serve`.
- CLI/HTTP schema, JSON/JSONL output, stable error codes, and evidence/plan integration are the user-facing contract.
- Raw `xcrun simctl` is a fallback only when `triton schema --command sim --json` or `triton schema --command app --json` does not expose the required capability.

## Current P0 Contract

Simulator commands:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json
```

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

When a reusable `.tritonplan` proxy lifecycle needs listener policy, attach it only to the `proxy-serve` step: `mockRules` maps to `device proxy serve --mock-rules` in `mode=mock`, `policyRules` maps to `--policy-rules`, and `throttleMs` maps to `--throttle-ms` in `mode=throttle`. Do not propagate these listener-only flags to `proxy-start`, `proxy-stop`, certificate install, or restore review commands; those remain focused on audited Simulator proxy mutation and original-value restore. This still proves only host-listener policy behavior after traffic reaches the listener, not App-internal interception or decrypted HTTPS bodies.

`sim proxy doctor/status` / `device proxy doctor/status --platform ios` should keep `NetworkProxySession.cert` machine-readable even before certificate installation exists. Until trust setup is implemented and verified, expect `installed=false`, `trusted=false`, and scope `simulator`; this is evidence of limited HTTPS visibility, not proof of TLS interception.

For certificate preparation, use `triton device proxy cert doctor --platform ios --json` and `triton device proxy cert plan --platform ios --device <udid-or-booted> --certificate <path.cer> --json`. The plan may list `xcrun simctl keychain <target> add-root-cert <path.cer>` and a `proxy-certificate` artifact, but it is still plan-only: it must not call `simctl keychain`, install trust, or claim decrypted HTTPS visibility. After reviewing that ledger, `triton device proxy cert install --platform ios --device <udid-or-booted> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` may execute the Simulator root certificate install through the break-glass runner. Missing any policy flag must return `destructive_action_requires_policy`, and success still needs explicit limitations for certificate pinning, custom transports, and traffic bypassing the system proxy.

This lane must not require App-side URLProtocol, method swizzling, SDK network interceptors, or embedded runtime network providers. It configures and observes the simulator through host-side proxy state, certificate setup, capture artifacts, and stable JSON limitations. If traffic bypasses the system proxy, uses certificate pinning, custom sockets, private encryption, or unsupported QUIC paths, report limited visibility through explicit error/warning codes such as `proxy_visibility_limited`, `proxy_cert_untrusted`, or `proxy_unsupported_transport`.

`triton sim use` writes repo-local workspace defaults to `.triton/host-defaults.json`. Do not run smoke writes in the repository unless that file is intentionally part of the test. Use a temporary working directory for validation when possible.

`triton app open-url` only proves that the URL was submitted to Simulator. When an embedded runtime is connected, prefer `--wait-ready --snapshot` for a one-shot host action plus runtime readiness/snapshot summary. Otherwise always verify business completion with `triton wait`, `triton find`, `triton assert`, `triton app prefs get`, a fresh screenshot, or an evidence bundle.

`simctl appinfo` can exit 0 for a missing bundle while only echoing `CFBundleIdentifier`; Triton normalizes this to `app_info_not_available`. Do not treat raw `simctl` exit code alone as proof of installed app metadata.

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
docs-linhay/scripts/qmd-sync.sh
```

Run real simulator smoke only when it is safe for the current machine state:

```bash
.build/cli/debug/triton sim list --json
.build/cli/debug/triton app list --simulator booted --user-only --json
.build/cli/debug/triton app info --bundle-id <known-bundle-id> --simulator booted --json
.build/cli/debug/triton app info --bundle-id com.example.missing --simulator booted --json
```

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
- P2+: host UI snapshot/tap/type/press, record video, diagnose, xctrace, Xcode build/test, coverage, SwiftPM.

## Boundaries

- Do not add Web/Wails UI for host simulator control while CLI/HTTP can satisfy the automation contract.
- Do not put host-side process execution into the iOS embedded runtime.
- Do not expose XcodeBuildMCP tool names as TritonKit product API; use it as reference only.
- Do not use interactive confirmation gates for long-running automation. Use `riskLevel`, objective required config, audit metadata, and explicit command flags/policy instead.
