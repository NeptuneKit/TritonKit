---
name: tritonkit-emulator-cli-takeover
description: Use when designing, implementing, extending, or validating TritonKit local CLI takeover of iOS Simulator, Android Emulator, or HarmonyOS / DevEco Emulator capabilities. Covers single-machine emulator target discovery, app lifecycle, readiness, screenshots, AX/layout, logs, command ledger, evidence, destructive-action policy, and deciding what belongs in `triton` CLI without adding Web, remote agents, real-device orchestration, or device-cloud services.
metadata:
  version: 0.1.0-dev
---

# TritonKit Emulator CLI Takeover

## Principle

TritonKit's emulator takeover surface is **local CLI + local simulator/emulator**.

The product boundary is:

- Include: iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator, DEBUG-only embedded runtime, local `.tritonevidence`, `.tritonplan`, `.tritoncase`, and `.tritonbatch`.
- Exclude by default: physical devices, remote agents, device cloud, Web / Wails UI, public HTTP product APIs, Postgres, Kafka, Webhook, multi-tenant operations, and built-in VLM loops.

The `triton` CLI is the stable interface for AI agents. Platform tools such as `xcrun simctl`, `adb`, `emu`, `hdc`, `aa`, `bm`, `uitest`, and `hilog` are implementation details behind JSON / JSONL contracts.

## Reference Docs

Start from the current space and technical design:

- `docs-linhay/spaces/20260521-ai-phone-emulator-cli/README.md`
- `docs-linhay/spaces/20260521-ai-phone-emulator-cli/technical-design.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/references/ai-phone.md`

For platform-specific slices, also check:

- iOS Simulator: `docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Harmony Emulator: `docs-linhay/spaces/20260520-harmony-emulator-alignment/README.md`
- Evidence UX runs: `docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`

## CLI Admission Rules

Put a capability into `triton` CLI when an agent needs it to prepare, observe, execute, verify, replay, or archive a local emulator regression with machine-readable output.

Default in-scope CLI domains:

- `schema`, `doctor`, `capabilities`, and `plan`;
- `device list/use/wait-ready --platform ios|android|harmony`;
- iOS `sim list/use/boot/shutdown/screenshot/status-bar/privacy/location/ui/pasteboard/push`;
- iOS `sim proxy start/status/stop/export` for host-side Simulator proxy network takeover;
- app lifecycle: `list/info/install/uninstall/launch/terminate/open-url`;
- app data: containers, preferences, safe data reset/snapshot when policy is explicit;
- UI artifacts: screenshot, AX/layout tree, bounded logs;
- hybrid observation: host-side emulator layout/screenshot/frontmost-app evidence fused with DEBUG-only embedded runtime snapshots when available;
- runtime actions: `find/tap/swipe/type/paste/clear/wait/assert`;
- replay and evidence: `.tritonplan`, `.tritonevidence`, command ledger, case lint, local batch.

Do not add Web / Wails UI, remote orchestration, real-device flows, or central services to satisfy this domain. If the requirement truly needs those, create a new space and reset the product boundary first.

For iOS network takeover, use the host-side Simulator proxy lane. Do not require App-side `URLProtocol`, method swizzling, SDK network interceptors, or embedded runtime network providers. The proxy contract must expose certificate setup, simulator proxy configuration, capture/mock/block/throttle mode, request artifacts, restore state, and explicit limitations for certificate pinning, traffic that bypasses the system proxy, custom sockets, private encryption, or unsupported QUIC paths.

Current P0/P1 exposes `triton device proxy doctor|start|status|export|stop --platform ios|android|harmony --json` and the iOS alias `triton sim proxy doctor|start|status|export|stop --simulator <udid|booted> --json`. Treat them as the safe contract skeleton plus explicit runner opt-in: `doctor/status` are executable discovery/status surfaces. Ordinary `export` still returns `ok:false` with `proxy_platform_not_supported` until a real capture session exists. Ordinary `start/stop` are break-glass policy-gated: missing `--confirm --audit-record <id> --execute-runner` returns `destructive_action_requires_policy`; iOS / Android may execute the command ledger only when all three flags are present; Harmony returns `proxy_unverified_platform_proxy` and remains probe-only until a real DevEco proxy setting command is verified.

Use `triton device proxy probe --platform ios|android|harmony --device <selector> --json` when an agent needs readonly platform proxy capability evidence before planning takeover. The response is still a `host.device-proxy` `NetworkProxySession` with `action=proxy.probe`, `configured=false`, `sourceCommands[]`, `probeResults[]`, and `proxy_probe_readonly:not_mutated`. iOS / Android probe must stay on readonly snapshot commands. Harmony probe may run HDC readiness, shell probe, and `param ls -r proxy|http`; candidate proxy-looking output only means `proxy_harmony_candidate_parameters_found:manual_verification_required`, not a verified mutation command or permission to execute `start`.

`triton plan network-proxy --platform ios|android|harmony ... --certificate <path.cer> --audit-record <id> --json` should make `device proxy probe --plan-only` the first proxy-specific next step after target/doctor context, then include `device proxy cert plan --platform <platform> --device <selector> --certificate <path.cer> --json` followed by `device proxy cert install --platform <platform> --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` as a break-glass audit command before `device proxy serve --jsonl`. After serve readiness, include `device proxy start --plan-only`, then `device proxy start --confirm --audit-record <id> --execute-runner --json` as the platform proxy break-glass audit command. The final stop review should use `device proxy stop --restore-snapshot <restore-state-json> --plan-only --json`, followed by `device proxy stop --restore-snapshot <restore-state-json> --confirm --audit-record <id> --execute-runner --json` as the restore break-glass audit command; when the task plan has a concrete `--output`, resolve that token to `<output>/restore-state.json` so an agent audits the original-value restore ledger that start writes before any break-glass restore execution. This keeps the three-platform task plan evidence-first, surfaces HTTPS visibility preparation, certificate install review, platform proxy mutation review, and restore review before capture/cleanup, and prevents Harmony from hiding unverified proxy or certificate mutation behind the later start step.

Network takeover is simulator/emulator scoped. If a target has `scope=real` or `kind=real-device`, `device proxy start|stop|status|export|cert plan` and break-glass helper paths must return `proxy_real_device_not_supported`, keep `configured=false`, and leave `sourceCommands[]` / `artifacts[]` empty. The proxy planner must preserve `ios-real:`, `android-real:`, and `harmony-real:` selector prefixes as real-device targets so they hit the same rejection envelope instead of being coerced into simulator/emulator ids. Do not generate `networksetup`, ADB, or HDC proxy mutation ledgers for real-device targets without a separate real-device space that resets this boundary.

`device proxy --device <selector>` must reuse the workspace host target selector store. Resolve aliases and `current` from `.triton/host-targets.json` before building plan-only, status, export, cert plan, or break-glass helper targets. The iOS alias `sim proxy --simulator <selector>` must use the same selector resolver instead of treating friendly aliases as raw Simulator ids. Normalize `sim:`, `android:`, and `harmony:` alias targets to the platform's actual simulator/emulator id before generating `networksetup`, ADB, or HDC probe ledgers. If the selector or alias resolves to `scope=real`, `kind=real-device`, or an `ios-real:` / `android-real:` / `harmony-real:` target, keep the real-device rejection envelope and leave mutation ledgers empty.

Use `triton device proxy start --platform ios|android|harmony --device <selector> --mode record --output <dir> --plan-only --json` when an agent needs the current platform command ledger. Plan-only output must return `ok=true`, `configured=false`, `sourceCommands[]`, and `proxy_plan_only:not_executed`; it is proof of an auditable plan, not proof that proxy takeover has been applied.

Use `triton device proxy stop --platform ios|android|harmony --device <selector> --restore --plan-only --json` when an agent needs the restore ledger. Plan-only restore output must keep `restore.restored=false`; Harmony remains probe-only and must include `proxy_restore_probe_only:no_verified_harmony_proxy_mutation` until a real DevEco proxy mutation command is verified.

Use `triton device proxy export --platform ios|android|harmony --device <selector> --output <path.har|path.ndjson> --plan-only --json` when an agent needs to predeclare the network evidence artifact path. Plan-only export output must include a `network-capture` artifact with `bytes=null`, `configured=false`, `proxy_plan_only:not_executed`, and `proxy_export_plan_only:artifact_not_written`; it must not read session capture files or write HAR / NDJSON.

Use `triton device proxy start|stop ... --confirm --audit-record <id> --execute-runner --json` only after reviewing the corresponding `--plan-only` output. iOS and Android may call the real command runner only when `--confirm`, `--audit-record`, and `--execute-runner` are all present; missing any of those must return `destructive_action_requires_policy` and must not execute host commands. Harmony must return `proxy_harmony_probe_only:no_verified_proxy_mutation` even when `--execute-runner` is present, until a real DevEco / Harmony proxy mutation command is verified.

Before any iOS / Android start runner mutation, perform a host-side endpoint preflight against `--proxy <host:port>`. If the proxy listener is unreachable, return `proxy_endpoint_unreachable`, keep `configured=false`, preserve `sourceCommands[]` for audit, and do not call `networksetup` or ADB. Android still uses the Mac host endpoint for preflight even when loopback is rewritten to `10.0.2.2:<port>` in the emulator ledger.

For iOS / Android break-glass runner execution, write a restore snapshot before mutation whenever `--output <dir>` is provided. The current snapshot schema is `triton.proxy.restore.v1` at `<dir>/restore-state.json` and records `platform`, `target`, `proxyEndpoint`, `auditRecord`, `snapshotCommands`, `startCommands`, `restoreCommands`, `snapshotSourceCommands[]`, `sourceCommands[]`, and `restoreSourceCommands[]`. iOS snapshots use readonly `networksetup -getwebproxy/-getsecurewebproxy/-getsocksfirewallproxy/-getproxybypassdomains` and store `serviceSnapshots[]`; Android snapshots use readonly `adb shell settings get global http_proxy` and store `androidOriginalHTTPProxy`. Prefer `stop --restore-snapshot <path> --plan-only --json` for non-mutating review of the original-value `restoreCommands`, then `stop --restore-snapshot <path> --confirm --audit-record <id> --execute-runner --json` so the restore path consumes the same audited restore ledger from start. If that restore runner fails, TritonKit writes `<snapshot-dir>/restore-failure.json` with schema `triton.proxy.restore-failure.v1`, returns it as `artifacts[].kind=proxy-restore`, and adds `proxy_restore_failure_artifact_written`; treat this as archive/evidence recovery context, not proof that restore succeeded.

For iOS / Android break-glass runner execution with `--output <dir>`, also persist the file-backed session state. The current session schema is `triton.proxy.session.v1` at `<dir>/session-state.json`; it records platform, target, capture mode, proxy endpoint, configured state, cert state, visibility, limitations, artifacts, restore snapshot path, and source commands. Use `device proxy status --platform <platform> --device <selector> --session <dir> --json` or `sim proxy status --simulator <udid|booted> --session <dir> --json` to read that state across CLI invocations; if an older session lacks `cert`, status/export must fall back to conservative platform certificate state. If `<dir>/restore-failure.json` or the `restoreSnapshotPath` sibling restore failure file exists, status adds it to `artifacts[]` as `kind=proxy-restore` so agents can see failed-restore context after the original error envelope has scrolled away. Use `device proxy export --platform <platform> --device <selector> --session <dir> --output <path.ndjson|path.har> --json` or `sim proxy export --simulator <udid|booted> --session <dir> --output <path.ndjson|path.har> --json` to export the persisted capture artifact. `.ndjson` output copies the capture artifact as-is; `.har` output converts `proxy.serve.request` events into a HAR 1.2 metadata-only skeleton. Forwarded requests keep `status=0/not captured`; mock / block / throttle requests write policy response statuses `200 TritonKit Proxy Mock` / `502 TritonKit Proxy Blocked` / `429 TritonKit Proxy Throttled`. The same policy response is also present on NDJSON request events as `responseStatus` / `responseStatusText`, so agents can inspect policy effects without first exporting HAR. If `device proxy serve` is not running, `<dir>/requests.ndjson` may only prove that the session artifact path exists; require `proxy.serve.request` events before claiming the capture proxy observed traffic. The HAR skeleton must not be treated as decrypted traffic evidence because it omits header values, bodies, TLS decrypted content, and real response payloads.

`device proxy export --session` responses should expose export summary fields directly on `NetworkProxySession`: `requestCount`, `redaction`, and `truncation`. Treat `requestCount=0` as "artifact exists but no observed proxy traffic yet"; treat `redaction=headers-names-only` as metadata-only capture; and route `proxy_artifact_write_failed` through an archive recovery path when the session capture is missing, unreadable, or cannot be written to the requested output.

When archiving network takeover evidence, use `triton evidence --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` or `triton capture --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json`. This import path reads `<dir>/session-state.json`, validates the `triton.proxy.session.v1` schema, copies the declared `network-capture` artifact into `artifacts/network/requests.ndjson`, and marks both artifacts as sensitive. If `<dir>/restore-failure.json`, a declared `proxy-restore` artifact, or the `restoreSnapshotPath` sibling restore failure file exists, the same import path copies it to `artifacts/network/restore-failure.json` as sensitive `proxy-restore` evidence with policy `proxy-restore-failure-recovery`. Treat `network-capture` as the primary traffic artifact and `proxy-restore` as recovery context; still require `proxy.serve.request` events before claiming traffic was observed, and never treat `proxy-restore` as proof that platform proxy restore succeeded. If the declared capture artifact is missing or unreadable, preserve `network.proxy-session`, import `proxy-restore` when present, and skip only `network-capture` so the archive still retains proxy configuration and recovery context.

When a reusable `.tritonplan` needs to archive a proxy session, use an `evidence` step with `include: "network.proxy-session"` and `proxySession: "<dir>"`. `triton plan inspect <file.tritonplan> --json` and `triton replay <file.tritonplan> --dry-run --json` must preserve `--proxy-session` in `steps[].argv` and expose `network.proxy-session` plus `network-capture` in `expectedArtifacts[]`. Real replay may then import that existing session into `.tritonevidence`. If a real replay fails before that evidence step, it should stop later business actions/assertions but still execute a proxy-only archive from the later `network.proxy-session` evidence step, so the failure keeps proxy state without starting a listener or mutating platform proxy settings.

When a reusable `.tritonplan` needs to describe proxy lifecycle preparation, use `proxy-probe`, `proxy-serve`, `proxy-start`, `proxy-export`, and `proxy-stop` steps only as inspect / dry-run audit steps. They should emit `triton device proxy probe --plan-only`, `serve --jsonl`, `start --plan-only`, `export --plan-only`, and `stop --restore --plan-only` argv, with `network-capture`, `host-device-proxy`, or `proxy-restore` expected artifacts. When a concrete session directory is available, task-level network-proxy plans should prefer `stop --restore-snapshot <restore-state-json> --plan-only` and resolve it to that directory's `restore-state.json`, so the stop review matches the original proxy state captured by start. `plan inspect` should also surface proxy lifecycle defects in `steps[].validationErrors[]`: missing `platform`, missing `device`, missing `proxy`, missing `output`, `proxy-export` before `proxy-start`, or `proxy-stop` without `restore=true`. Real replay must not start the proxy listener or execute platform proxy mutation on its own; it should report the lifecycle steps as dry-run-only / unsupported and require explicit command execution after policy review.

`device proxy doctor/status` should expose conservative certificate state through `NetworkProxySession.cert` instead of omitting the field. Until certificate installation/trust is actually implemented and verified, expect `installed=false`, `trusted=false`, and scope `simulator` for iOS or `emulator` for Android/Harmony. Treat this as HTTPS visibility limitation evidence, not as proof that TLS interception is available.

Use `triton device proxy cert doctor --platform ios|android|harmony --json` and `triton device proxy cert plan --platform ios|android|harmony --device <selector> --certificate <path.cer> --json` to inspect or plan certificate trust preparation. This is a plan-only ledger: iOS may list `xcrun simctl keychain <target> add-root-cert <path.cer>`, Android may list `adb push` plus an `android.credentials.INSTALL` user-install intent, and Harmony must stay `proxy_cert_harmony_probe_only` until a real DevEco/Harmony trust command is verified. Do not treat `network-certificate-plan` or `proxy_cert_untrusted` as proof that TLS interception, CA trust, or decrypted HTTPS bodies are available. After reviewing that ledger, `triton device proxy cert install --platform ios|android --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` may execute the iOS / Android certificate setup through the break-glass runner. Missing any policy flag must return `destructive_action_requires_policy`. iOS success can mark the Simulator root cert installed and trusted; Android success only means the CA file was pushed and the certificate install UI was opened, so user trust may still be pending. Harmony must still return `proxy_unverified_platform_proxy` / `proxy_cert_harmony_probe_only` even when `--execute-runner` is present.

Use `triton device proxy serve --listen 127.0.0.1:19431 --output <dir> --mode record|mock|block|throttle --jsonl` as the shared local capture / mock / block / throttle proxy for iOS Simulator, Android Emulator, and future verified Harmony proxy adapters. Keep this long-running process alive before pointing `device proxy start --proxy 127.0.0.1:19431 --output <dir> --confirm --audit-record <id> --execute-runner --json` at it. `serve` writes `triton.proxy.capture.v1` metadata-only request events into `<dir>/requests.ndjson` and emits `proxy.serve.ready`, `proxy.serve.request`, `proxy.serve.connection-failed`, and final `proxy.serve.summary` JSONL; the `device` schema exposes these through `jsonlEvents[]` with `finalEventKind=proxy.serve.summary`. It records method, URL, host, port, path, CONNECT tunnel metadata, and header names only; it does not store header values, bodies, or decrypted TLS. `--mode record` records metadata then attempts upstream forwarding. `--mode mock` records metadata, writes `policyAction=mocked`, `responseStatus=200`, and `responseStatusText="TritonKit Proxy Mock"`, then returns a fixed JSON mock response without connecting upstream. `--mode block` records metadata, writes `policyAction=blocked`, `responseStatus=502`, and `responseStatusText="TritonKit Proxy Blocked"`, then returns `502 TritonKit Proxy Blocked` without connecting upstream. `--mode throttle` records metadata, writes `policyAction=throttled`, `responseStatus=429`, and `responseStatusText="TritonKit Proxy Throttled"`, then returns `429 TritonKit Proxy Throttled` plus `Retry-After: 1` without connecting upstream; this is a synthetic rate-limit policy, not bandwidth shaping or real latency injection. Treat `proxy.serve.request` as proof that the capture proxy saw traffic, but not proof of HTTPS body visibility. Treat mock / block / throttle mode as shared host-side proxy policies; they do not mean Harmony platform proxy mutation is verified.

For proxy adapter implementation work, first use the fake proxy adapter, pure host-command planners, and the injectable `NetworkProxyCommandRunner` test boundary. The fake adapter may write temporary restore/capture artifacts for tests, and fake command runners may simulate iOS / Android ledger execution and `proxy_start_failed` / `proxy_restore_failed` envelopes, but neither path may touch host or emulator proxy settings. The real CLI runner path is break-glass and requires explicit policy, audit metadata, restore snapshot, evidence, and smoke validation; the ordinary path without `--execute-runner` must remain non-mutating.

Current platform planner boundary:

- iOS Simulator: `networksetup` planner may generate HTTP / HTTPS proxy override, SOCKS disable, and original-value restore commands from a readonly service snapshot. Do not execute it without break-glass policy.
- Android Emulator: ADB planner may generate `settings put global http_proxy <host>:<port>`, `settings get global http_proxy`, and restore via either `settings put global http_proxy <original>` or `settings delete global http_proxy` for emulator targets. The `--proxy` flag describes the Mac host listener; if it is `127.0.0.1:<port>`, `localhost:<port>`, or `::1:<port>`, the Android emulator ledger must use `10.0.2.2:<port>` in `sourceCommands[]` because emulator loopback points at the emulator itself. Keep `proxyEndpoint` as the requested host endpoint, and treat the mutation ledger as break-glass with target / timeout / audit metadata.
- Harmony / DevEco Emulator: only probe with HDC readiness / shell commands until a real DevEco proxy-setting command is verified. Do not invent Harmony proxy mutation commands or mark `start` supported from analogy.

`triton capabilities --json` is the agent-facing environment matrix, not a flat help list. Each capability should expose `name`, `supported`, `reason`, `group`, `requiredBy`, `nextAction`, and `evidence` so an agent can choose between target selection, runtime connection, host tooling, action, assertion, and evidence capture without reading prose docs.

`triton doctor --json` is the ordered recovery view over that matrix. It should expose top-level `nextWorkflows`, plus `checks[].id`, `status`, `code`, `hint`, `nextAction`, `relatedCapabilities`, and `workflowCategories` so an agent can distinguish missing server, missing target/runtime, limited action surface, and available planning commands without re-joining doctor and capabilities by hand.

`triton plan ios-smoke|open-url|webview-check --json` is the first task planning layer. It should return ordered command recommendations for local emulator work, but it must not execute those commands or replace explicit wait/assert/evidence proof.

`triton plan --json` should also expose `mode`, with `bootstrap` for environment recovery/discovery planning and `task` for goal-specific workflow planning. Emulator agents should use `mode` to decide whether to recover local simulator state first or proceed into a smoke/open-url/webview workflow.

`triton plan --json` should also expose top-level `nextWorkflows`. Emulator agents should be able to align plan routing with `doctor.nextWorkflows` and `capabilities[].requiredBy` directly, instead of inferring the lane only from `goal` or the first step command.

`plan.steps[]` should also expose `workflowCategories`. Emulator agents should be able to enter a concrete step and still know whether it belongs to `target`, `app`, `observe`, `route`, `assert`, `evidence`, `smoke`, or another workflow lane without rebuilding that mapping from command roots.

`triton plan inspect` and `triton replay --dry-run` steps should preserve the same `workflowCategories` vocabulary. Emulator agents should be able to compare offline replay planning and dry-run execution lanes without inventing a separate replay-specific taxonomy.

Bootstrap entry responses should expose top-level `surface` fields. Emulator agents should be able to distinguish `status`, `doctor`, `capabilities`, and `plan` JSON responses without relying on the invoking shell command string or surrounding logs.

Generic `triton plan --json` steps must also be executable Triton commands, not prose. If the runtime target is missing, the default connect step should point to `triton xcode run --json`; agents can then use schema/failure codes to choose a fallback.

`plan.nextStep` must be one of the returned `steps[].id` values. Do not make agents infer the first actionable command from an abstract category such as `observe`.

Task plan command strings must stay schema-aligned. If a plan recommends `triton <command> ...`, the root command, subcommand, and every `--flag` should be present in `triton schema --json`; fix schema or the plan before relying on undocumented arguments.

Subcommand-level `nextCommands[]` entries are recovery contracts too. When adding or changing host-device, app, sim, smoke, Xcode, evidence, or action subcommands, verify every subcommand suggestion against `triton schema --json`.

Command-level and subcommand-level `nextCommands[]` must be single `triton ...` invocations. Do not put pipes, redirects, command substitutions, or shell scripts into recovery suggestions; describe stdin or artifact prerequisites in schema metadata or surrounding docs.

Command-level and subcommand-level `nextCommands[]` lists must not contain blank entries or duplicates at the same level. Agents should be able to treat the list as ordered recovery candidates without ad hoc filtering.

Command-level and subcommand-level `nextCommands[]` roots must stay in the fixed recovery command taxonomy. Emulator recovery suggestions should point to known diagnostic, discovery, target, project/Xcode, observe, action, assert, evidence, replay, or smoke roots; do not introduce a new root command as a recovery suggestion without defining its recovery role and updating tests/docs/skills.

Each recovery root also needs a stable category: `diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, or `plan`. Use this to keep emulator recovery flows stage-aware instead of treating all next commands as an undifferentiated list.

Use schema `recoveryCommands[]` as the structured recovery surface when available. It mirrors `nextCommands[]` and adds `category`, so emulator workflows can distinguish target preparation, observation, action, verification, and evidence archive steps without parsing prose.

Use `plan.steps[].category` as the structured workflow stage when available. It uses the same category taxonomy as `recoveryCommands[]`, so emulator workflows can plan target preparation, project setup, action, verification, archive, smoke, and policy-review phases without re-parsing each command string.

For smoke/evidence/replay flows, `triton capabilities --json` should expose separate `evidence`, `evidence-summary`, `evidence-redact`, `capture`, `smoke-ios`, `smoke-harmony`, `record`, `plan-inspect`, `replay`, and `replay-dry-run` entries. `plan-inspect` only summarizes a `.tritonplan` offline, and `replay-dry-run` only validates it; neither is execution proof.

Every schema-level `providedCapabilities[]` entry must be discoverable through `triton capabilities --json`, with a non-`misc` `group`, a usable `nextAction`, and non-empty `evidence`. When adding emulator, host, app, Xcode, action, WebView, smoke, or evidence capabilities, update both the schema and capabilities matrix in the same slice.

Capability names are index keys and must be unique in both schema `providedCapabilities[]` and the capabilities matrix. Do not duplicate a capability name to express multiple transports; use group, requiredBy, evidence, or distinct capability names instead.

Capability metadata arrays must be clean: `requiredBy` and `evidence` values should be non-empty and unique per capability. Use distinct evidence names when a host-side flow produces multiple artifacts.

Capability `nextAction.category` values must match the same recovery category taxonomy used by schema `recoveryCommands[]` and `plan.steps[].category`. Emulator workflows should be able to route capability next actions by category without parsing the command root.

Doctor check `nextAction.category` values should be available through the doctor output contract as well. Emulator takeover agents should use doctor for ordered diagnostics and capabilities for the detailed matrix, while both surfaces share the same category vocabulary.

Doctor checks should also expose workflow taxonomy directly. `checks[].workflowCategories` must be derived from the referenced capabilities' `requiredBy[]`, and `doctor.nextWorkflows` should mirror the first actionable `fail`/`warn` check. Emulator agents should be able to pick a recovery lane from doctor alone, then consult capabilities only for deeper evidence and next-action detail.

Error envelope `nextAction.category` values should be visible in both schema failure shapes and any `TKCLIErrorDetail?` output contract. Emulator takeover agents should route recoverable failures by category instead of parsing prose hints or command roots.

Plan steps should expose `requires`, `expectedArtifacts`, and `stopConditions` arrays. Emulator takeover flows should use those fields to decide when to prepare a target, wait for runtime readiness, capture evidence, or stop after timeout/assertion/artifact failures.

Plan steps should expose executable `argv` arrays. Emulator takeover agents should execute `argv` directly and keep `command` for logging or human copy/paste, not as the primary machine contract.

`triton plan inspect <file.tritonplan> --json` should expose the same execution metadata vocabulary on `steps[]`: `argv`, `category`, `requires`, `expectedArtifacts`, `stopConditions`, and `validationErrors`. Use it to audit reusable emulator smoke flows offline before `replay --dry-run` or real replay.

`triton replay <file.tritonplan> --dry-run --json` should expose `argv`, `category`, `requires`, `expectedArtifacts`, and `stopConditions` on each returned step. Compare dry-run `steps[].argv` with inspect `steps[].argv` before executing emulator flows against a live app; keep `steps[].command` as the human-readable/logging form.

Replay dry-run should reject statically invalid emulator smoke steps before touching a runtime: multiple `tap` selectors, multiple `wait` conditions, missing `paste/type` text, and missing `wait` condition are validation failures.

Capability groups must stay in the fixed agent taxonomy: `action`, `assert`, `bootstrap`, `evidence`, `host`, `observe`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview`, and `xcode`. Do not create near-duplicate groups or fall back to `misc` for new emulator, host, app, or evidence capabilities.

Capability `requiredBy` values must stay in the fixed workflow taxonomy: `action`, `app`, `assert`, `evidence`, `observe`, `project`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview-check`, and `xcode`. Add a new workflow category only when it changes agent planning behavior, and update schema tests, docs, and public skills in the same slice.

Capability `evidence` values must stay in the fixed artifact taxonomy. For emulator takeover, new evidence names must correspond to real host command JSON, host artifacts, screenshots, host layout, runtime AX/snapshot/ledger, WebView provider output, input results, evidence bundles, smoke summaries, or replay plans; do not use prose labels as evidence identifiers.

Every capability must expose at least one evidence source. Low-level observe capabilities such as hierarchy, attrs, object, geometry, hit, and archive export should point to surface tree, runtime AX, hierarchy node, snapshot JSON, target resolution, screenshot metadata, or host artifact evidence instead of leaving the array empty.

Use `nextAction.requiresLongRunningProcess=true` only for actual process bootstrap that an agent must keep alive or wait on. In the current capabilities matrix this means the server bootstrap `serve --host 127.0.0.1 --port 19421`; emulator list, wait-ready, screenshot, action, smoke, evidence, and schema discovery next actions should stay one-shot commands.

Keep `nextAction.args` placeholders as complete argv tokens. Use `<selector>`, `<path>`, `<path.png>`, `<udid|booted>`, `<x,y>`, or similar standalone tokens; do not mix placeholders into partial strings that an agent would need to parse with ad hoc string logic.

Apply the same placeholder rule to schema `nextCommands[]`, schema examples, and plan step `argv`. Avoid `sim:<udid>` style partial placeholders in executable suggestions; use a standalone placeholder such as `<sim-target-id>`. Plan execution facts should stay pure Triton argv and should not depend on shell redirection syntax.

Plan step `command` values must still be single `triton ...` invocations for logging and copy/paste. Do not put pipes, redirects, command substitutions, or shell scripts into `plan.steps[].command`; agent execution should use `plan.steps[].argv`, and stdin or artifact prerequisites should live in step metadata.

Every command that exposes `providedCapabilities[]` must also expose parseable `outputContracts[]`: non-empty `selector`, non-empty `model`, non-empty field list, no duplicate field names, and non-empty field `name`, `type`, and `description`. Within one command, each `outputContracts[].selector` must be unique so an agent can map a selector to one output model. Any `subcommands[].outputSelectors[]` value must be covered by the parent command's `outputContracts[].selector` set. Emulator and host-side commands often return multiple envelope shapes; declare the stable primary output models instead of relying on prose.

Output contract field types must be machine-readable. Use scalar or DTO names, optional `?`, arrays `[Type]`, dictionaries `[Key:Value]`, or unions `TypeA|TypeB`; do not describe field types with prose.

Output contract models must also be machine-readable. Use stable model names, arrays, dictionaries, or unions; avoid prose such as "metadata dictionary" and avoid raw Swift generic snippets that agents would need to parse specially.

Output contract selectors and kinds must be stable agent keys. Use dot-separated lower-kebab selectors such as `host.device-list` and single lower-kebab kinds such as `host-device-list`; do not introduce spaces, camelCase, underscores, or prose labels.

Output contract formats must stay in the fixed taxonomy `json`, `jsonl`, and `archive`. Use `json` for single envelopes, `jsonl` for progress/event streams, and `archive` for inspectable artifacts; do not invent emulator-specific format labels in schema.

Output contract kinds must stay in the fixed agent taxonomy. When adding emulator, host, app, smoke, evidence, or runtime output models, add a stable kind with clear response/event/artifact semantics and update the schema tests, docs, and public skills in the same slice.

Every command with a failure surface must expose stable `failureCodes[]`. Host-side emulator commands may fail through HDC, simctl, artifact writing, target selection, or runtime transport; keep those codes explicit in schema so agents can classify recovery without scraping stderr.

Failure codes must be lower_snake_case and non-duplicated within each command or subcommand. Emulator recovery branches should consume `error.code` as-is instead of normalizing prose labels, hyphenated names, or aliases.

Subcommand failure codes must be covered by parent command failure codes. When adding host-device, app, sim, smoke, Xcode, or evidence subcommands, update the parent code set in the same slice.

Options and subcommands must expose enough metadata for agents to plan without reading source: non-empty option `name`, `type`, and `description`; non-empty subcommand `name` and `summary`; no duplicates inside the same parent command.

Command names, subcommand names, and pure long flag names are CLI routing keys. Keep root and subcommand names lower-kebab, and keep slash-separated long flag aliases such as `--refresh/--no-refresh` lower-kebab per alias.

Subcommand and task synopsis belongs in `usageForms[]`, not `options[]`. Emulator commands with many host-side forms such as `sim runtime ...`, `sim privacy ...`, `device alias set ...`, or `app open-url ...` should expose those forms through `usageForms[]` so agents can distinguish command shapes from flags.

Positional arguments belong in `argumentForms[]`, not `options[]`. Emulator commands that accept `<selector>`, `<path>`, `<text>`, `<bundle>`, or similar argv positions should expose them as argument forms; `options[]` should remain pure `--long-flag` metadata.

Subcommand parameter references must be covered by the parent schema. If an emulator, app, sim, smoke, Xcode, evidence, or action subcommand declares `requiredOptions[]`, `optionalOptions[]`, or `oneOfRequiredOptions[]`, every referenced flag or positional argument must exist in the parent command's `options[]` or `argumentForms[]`.

Command-level `requiredOptions[]` is for direct command invocation only. If a command exposes `subcommands[]`, keep subcommand-specific requirements on the subcommand and do not summarize them on the parent command with prose or `subcommand:--flag` strings.

Default providers and inherited defaults must be schema-backed Triton commands. Use values such as `triton xcode use` or `triton sim use`; do not put raw tool names, README references, or prose setup notes into `defaultProviders[]` or `inheritsDefaultsFrom[]`.

Command and subcommand `artifacts[]` values must stay in the fixed schema artifact taxonomy. For emulator and host flows, use stable names such as `simulator-screenshot`, `simulator-video`, `simulator-logs`, `simulator-diagnostics`, `app-container`, `app-preferences`, `harmony-layout`, `screenshot`, `evidence-bundle`, `stdout-log`, `stderr-log`, `trace`, and `coverage-json`.

JSONL long-running event contracts must be stable. Keep `jsonlEvents[]` as dot-separated event keys, keep subcommand final events concrete such as `xcode.build.summary`, and ensure `finalEventKind` appears in the same `jsonlEvents[]` list.

Retryable host commands and subcommands must expose recovery `nextCommands[]`. If an emulator, Xcode, xctrace, coverage, app, evidence, or smoke command is marked retryable, agents need a schema-backed next command to recover, continue, or archive evidence.

Failure-code-bearing commands and subcommands must also expose a recovery path. If a command has `failureCodes[]`, keep command-level `nextCommands[]` non-empty; if a subcommand has `failureCodes[]`, provide subcommand-level `nextCommands[]` or make sure the parent command recovery path is usable for that failure surface. This applies even when the command is not marked retryable, such as action or observation commands that can fail through target resolution or runtime transport.

Failure-code families must map to recovery categories. Host emulator failures such as target unavailable, runtime disconnected, host command timeout, unsupported actions, artifact output rejection, and assertion mismatch should all be classifiable into the fixed recovery category taxonomy before agents choose concrete recovery commands.

Artifact and output failure codes must expose an archive-oriented recovery path. If simulator video, screenshot, logs, diagnostics, trace, coverage, or plan output fails because a path is rejected, a write fails, or output is too large, `recoveryCommands[]` should include an `archive` category such as evidence/capture/export/screenshot/xcresult so the agent can preserve failure context.

Assertion, route, and text-not-found failures must expose a verification-oriented recovery path. If an emulator smoke, wait, assert, route, find, or semantic action reports `assertion_failed`, `route_mismatch`, or `text_not_found`, `recoveryCommands[]` should include a `verify` category such as wait/assert/route so the agent can re-check the expected state.

Runtime transport failures must expose a diagnostic recovery path. If embedded runtime or host-adapter commands report `server_unavailable`, `request_failed`, `request_timeout`, `runtime_unavailable`, or `runtime_not_connected`, `recoveryCommands[]` should include a `diagnose` category such as status/doctor/capabilities so the agent can check server, target, runtime, and hierarchy/cache state before retrying.

Target failures must expose a target-preparation recovery path. If emulator, simulator, app, Xcode, observation, action, assertion, evidence, smoke, or replay commands report `ambiguous_target`, `device_not_ready`, `simulator_not_found`, `target_not_found`, `target_offline`, or `target_unavailable`, `recoveryCommands[]` should include a `prepare-target` category such as `triton target resolve <selector> --json` so the agent can resolve, select, or wait for the target before continuing.

Project and Xcode failures must expose a project recovery path. If build, test, run, xcresult, xctrace, coverage, smoke, or app launch flows report `ambiguous_workspace`, `invalid_workspace_path`, `scheme_not_found`, `workspace_not_found`, or `xcode_not_idle`, `recoveryCommands[]` should include a `project` category such as `triton xcode discover --path . --json` so the agent can rediscover workspace/project/scheme context before retrying.

Action and replay step failures must expose an action recovery path. If emulator, runtime, smoke, replay, or batch input flows report `action_failed` or `step_failed`, `recoveryCommands[]` should include an `act` category such as `triton input --json --summary --strict` so the agent can return to an executable action surface with a strict summary gate.

Destructive and confirmation failures must expose a planning recovery path. If simulator, emulator, app lifecycle, runtime maintenance, or host-state commands report `confirmation_required` or `destructive_action_requires_policy`, `recoveryCommands[]` should include a `plan` category such as `triton plan --format json` so the agent can return to a policy-aware planning step before executing a destructive command.

Unsupported failures must expose a planning recovery path. If emulator, embedded runtime, WebView, semantic action, or provider-backed commands report `action_not_supported`, `unsupported_capability`, `unsupported_runtime_scope`, `webview_method_not_allowed`, or `webview_wait_unsupported`, `recoveryCommands[]` should include a `plan` category such as `triton plan --format json` so the agent can choose a supported capability or alternate workflow instead of retrying the unsupported command.

Command-level `outputFormats[]` values must stay in the fixed taxonomy `text`, `json`, `jsonl`, `logs`, `tree`, `auto`, `archive`, `file`, and `json-metadata`, with no duplicates inside one command. This is the selectable CLI output mode, separate from `outputContracts[].format`.

Examples are agent-facing argv samples. Keep `triton sim`, `triton app`, `triton device`, `triton smoke`, and action examples schema-backed: every example flag must be declared in `triton schema --json`, including host-only flags such as `--duration`, `--style`, `--confirm`, `--dry-run`, `--bundle`, `--ability`, `--user-only`, and `--kind`.

Each schema example must contain exactly one extractable `triton` invocation. Pipelines and stdin preparation are acceptable for examples such as batch input, but do not put multiple `triton` calls into one example; multi-step emulator workflows belong in `triton plan`, `.tritonplan`, or procedural docs.

Action capability `nextAction` values must match the current executable schema. Use `swipe --start-x/--start-y/--end-x/--end-y`, `clear --at x,y`, and `input --json --summary --strict`; embedded `press` remains unsupported and should point to schema/diagnostics rather than claiming host HID availability.

Host capability `nextAction` values must also be schema-aligned. For example, Harmony app install uses `app install --platform harmony --hap <path.hap>`, while iOS install uses `--app <path.app>`; simulator artifacts should expose documented `--simulator`, `--output`, `--bundle-id`, and `--payload` flags in `triton schema --command sim --json`.

## Integration Guide Contract

When changing iOS / Harmony / CLI onboarding or usage guides, keep these entry points aligned:

- `README.md` must split iOS embedded runtime, Harmony host-side adapter, Harmony embedded SDK, and CLI install/run guidance.
- `tritonkit-dev-feedback` must be able to guide external users through iOS, Harmony, or CLI adoption before filing feedback.
- `tritonkit-real-project-regression` must treat iOS and Harmony apps as external systems under test, using host-side checks when embedded runtime is not required.
- Harmony docs must state that host-side HDC / DevEco Emulator control does not require embedded SDK integration.
- Harmony embedded SDK docs must state package id/import path `tritonkit`, Debug-only runtime, Release disabled/no-op behavior, provider-owned business semantics, and `--runtime-base-url` direct checks while standalone.
- CLI docs must keep Homebrew as the released install path and local `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` as the unreleased-source fallback.

## Current Implemented Surface

Cross-platform host device entry:

```bash
triton device doctor --platform ios --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform harmony --json
triton device alias set iphone15 --platform ios --target <simulator-udid> --json
triton device alias set harmony-a --platform harmony --target <hdc-target> --json
triton device use iphone15 --json
triton device current --json
triton device resolve iphone15 --json
triton device wait-ready --device iphone15 --json
triton device wait-ready --device harmony-a --json
triton device screenshot --device iphone15 --output /tmp/<case>-sim.png --json
triton device screenshot --device harmony-a --output /tmp/<case>.jpeg --json
triton device stop --platform harmony --hvd "Codex Test Phone" --path ~/.Huawei/Emulator/deployed --confirm --json
```

Use `--device <selector>` as the default agent-facing target selector for common host-side commands. Selectors can be aliases, full ids such as `sim:<udid>` / `harmony:<target>`, raw platform ids, `booted`, or `current`. `--platform`, `--name`, `--runtime`, `--state`, and `--ready` are filters; they may auto-select only when the filtered candidate set is unique. Keep `sim` for iOS-only advanced maintenance; `device runtime-url --device <selector>` is the Harmony embedded runtime port-forward setup path, and `--platform harmony --target <target>` remains the direct raw-target form.

For Harmony target discovery, expect HDC output shape drift. `triton device list --platform harmony --json` should parse `hdc list targets -v` stdout and stderr, fallback to plain `hdc list targets` when verbose output has no target rows, and treat single-column plain targets such as `127.0.0.1:5555` as connected DevEco emulator candidates. Do not parse prose errors such as `Connect server failed` as targets.

When a Harmony HVD was started through Triton's `triton-harmony-emulator` launchd keepalive job, stop it through `triton device stop --platform harmony ... --confirm --json`. The command checks and unloads `gui/<uid>/triton-harmony-emulator` before running DevEco `Emulator -stop`, which prevents launchd from immediately restarting the emulator.

iOS Simulator:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json
triton sim record --simulator <udid-or-booted> --output /tmp/<case>-sim.mov --duration 10 --json
triton sim logs --simulator <udid-or-booted> --output /tmp/<case>-sim.ndjson --duration 5 --json
triton sim status-bar list --simulator booted --json
triton sim privacy grant location com.example.app --simulator booted --json
triton sim location set 37.7749,-122.4194 --simulator booted --json
triton sim ui appearance dark --simulator booted --json
triton sim diagnose --output /tmp/sim-diagnostics --json
triton sim logverbose booted enable --json
triton sim runtime list --json
triton sim pasteboard set "hello" --simulator booted --json
triton sim push --bundle-id com.example.app --payload /tmp/push.json --simulator booted --json
triton sim pair <watch-udid> <phone-udid> --json
triton sim unpair <pair-uuid> --json
triton sim clone <udid> "Clone for Smoke" --json
triton sim erase <udid> --confirm --json
triton sim upgrade <udid> <runtime-id> --json
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

triton app list --device iphone15 --user-only --json
triton app info --device iphone15 --bundle-id <bundle-id> --json
triton app install --device iphone15 --app <path.app> --json
triton app uninstall --device iphone15 --bundle-id <bundle-id> --confirm --json
triton app launch --device iphone15 --bundle-id <bundle-id> --json
triton app terminate --device iphone15 --bundle-id <bundle-id> --json
triton app open-url '<url>' --device iphone15 --json
triton app open-url '<url>' --device iphone15 --wait-ready --snapshot --json
triton app container --device iphone15 --bundle-id <bundle-id> --kind data --json
triton app prefs get <key> --device iphone15 --bundle-id <bundle-id> --json
triton app prefs dump --device iphone15 --bundle-id <bundle-id> --json
triton app prefs set <key> <json-value> --device iphone15 --bundle-id <bundle-id> --json
triton smoke ios --device iphone15 --bundle-id <bundle-id> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.png --evidence /tmp/<case>.tritonevidence --json
```

HarmonyOS / DevEco Emulator:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device use harmony-a --json
triton device wait-ready --device harmony-a --json
triton app inspect --platform harmony --bundle <bundle> --json
triton app install --device harmony-a --hap <debug-signed.hap> --json
triton app launch --device harmony-a --bundle <bundle> --ability <ability> --json
triton smoke harmony --device harmony-a --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
triton observe current --device harmony-a --json
triton observe tree --device harmony-a --json
triton node resolve --device harmony-a --text "登录" --json
triton tap "登录" --platform harmony --device harmony-a --json
triton swipe --platform harmony --device harmony-a --start-x 350 --start-y 900 --end-x 350 --end-y 300 --json
triton type "hello" --platform harmony --device harmony-a --json
triton paste "hello" --platform harmony --device harmony-a --json
```

For Harmony host actions, schema exposes host-side output selectors alongside embedded runtime contracts. Parse `tap --platform harmony` as `host.harmony-tap`, `swipe --platform harmony` as `host.harmony-swipe`, and `type` / `paste --platform harmony` as `host.harmony-text-input`; do not reuse the embedded `input.result` parser for those host outputs. Parse `wait --platform harmony` as `host.harmony-wait`; do not reuse the embedded `wait.result` parser. Parse `ax/screenshot --platform harmony` as `host.harmony-artifact`; do not reuse `host.artifact`. Parse `press --platform harmony` as `host.harmony-key-action`; do not reuse `host.key-action`. Treat `clear --platform harmony` as an explicit unsupported boundary (`harmony-clear-text`) until a stable host clear primitive exists, and treat any reappearance of legacy selectors (`host.tap`, `host.swipe`, `host.text-input`, `host.wait`) as schema regression.

Standalone Harmony embedded HTTP runtime:

```bash
triton device runtime-url --device harmony-a --probe-manifest --json
# Compatibility path:
triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json
triton runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton state route --runtime-base-url http://127.0.0.1:28767 --json
triton snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

iOS embedded runtime observation:

```bash
triton list --json
triton ax --target triton:ios-simulator:<SIMULATOR_UDID> --json
triton tap "登录" --target <SIMULATOR_UDID> --json
triton observe current --platform ios --json
triton observe tree --platform ios --runtime-base-url <baseURL> --json
triton node resolve --platform ios --text "登录" --json
triton webview list --platform ios --json
triton webview current --platform ios --json
triton webview current-url --platform ios --json
triton route assert-current-url https://example.invalid/path --platform ios --json
triton webview call <method> --platform ios --json
triton webview events --platform ios --limit 50 --json
triton evidence summary /tmp/<case>.tritonevidence --json
triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json
triton xctrace record --template "Time Profiler" --device <SIMULATOR_UDID> --time-limit 5s --output /tmp/<case>.trace --json
triton coverage report --xcresult /tmp/<case>.xcresult --output /tmp/<case>-coverage.json --json
```

`triton evidence summary` / `inspect` now expose `primaryArtifacts[]`; agent should inspect those first before traversing the entire artifact set.

`triton replay ... --json` should also be consumed top-down: check `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, and `suggestedCommands[]` before traversing every replay step. Then inspect the failed step `error` payload when present, including `wait/input/evidence` failures that only returned `ok=false`. If `failureError.nextAction` exists, expect replay recovery commands to expose the same path. Prefer replay failures that preserve runtime/target/transport error codes directly; treat unnecessary fallback to `step_failed` as a control-surface bug.

`webview list/current` 当前是 Web 容器候选发现能力，证据可能来自 WebView provider、iOS runtime AX/tree 或 Harmony host layout。先读取 `primarySource`：WebView 语义优先 `webview-provider`，其次 `runtime-tree`，再次 `host-layout`。`webview current-url/snapshot/call/events/wait` 与 `route assert-current-url` 是 provider 级能力：只断言 provider URL 或读取 provider 显式暴露的 bounded snapshot、allowlist bridge 与 page events，不操作 H5 页面，也不是任意 JavaScript eval。没有 WebView provider 时，输出必须保持 `candidateOnly=true`、`providerStatus=unavailable`、`bridgeStatus=unavailable`，并在 `missingCapabilities` 中声明 `webview.url`、`webview.dom`、`webview.bridge-call`、`webview.tap`、`webview.type` 等缺失项；不得把 AX/WebKit 容器误报为 DOM/JS/bridge 可用。Harmony 侧若未注册 WebView provider，也只能保持 host-only layout/candidate 边界，不能声明页面 bridge 可用。

When multiple iOS Simulator apps connect to the same `triton serve`, embedded runtime targets use stable ids shaped as `triton:ios-simulator:<SIMULATOR_UDID>`. Runtime commands may pass either the full target id or the simulator UDID. If more than one runtime target is connected and the command still uses the default `triton:local`, the expected result is `error.code=ambiguous_target`, not last-connection wins.

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is the device-to-host gateway fallback port.

When debugging Harmony direct runtime defaults, verify against a real HDC target before changing CLI defaults:

```bash
TRITON_BIN=.build/cli-scratch/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Use `--no-forward` when the HDC fport already exists, because repeating `hdc fport tcp:28767 tcp:28767` can fail with a host listen conflict even though the existing forwarded endpoint is healthy. Keep mock contract smoke separate from real emulator smoke: the mock script should use an isolated test port while asserting the schema/default output remains `28767`.

Android Emulator host-side support is now part of the implemented local CLI takeover surface. Treat `adb`-backed device discovery, readiness, screenshot, app lifecycle, UIAutomator observe/wait/tap, and `smoke android` as schema-backed Triton commands; continue to keep DTOs, evidence, and command-ledger schemas platform-neutral across iOS, Android, and Harmony.

## Safety Rules

- Destructive or state-changing host actions must require explicit flags or policy. Current example: `app uninstall` requires `--confirm` and otherwise returns `destructive_action_requires_policy`.
- Host command success is not business success. After `launch`, `open-url`, `install`, or `uninstall`, verify with `wait`, `find`, `assert`, screenshot, app prefs, layout/AX, or evidence.
- Multiple local targets must return `ambiguous_target` instead of picking an unsafe default.
- Every host action should preserve source command, target, elapsed time, risk/policy metadata when available, and next verification advice.
- Logs, screenshots, layout dumps, and data snapshots must be bounded and redacted when persisted into evidence.
- When a platform has both host-side and embedded runtime observation, keep source boundaries visible. Host layout can prove current visible nodes and coordinates; embedded runtime can prove App-private route, responder, semantic action, WebView controller, and bridge state; WebView/page bridge can prove DOM/JS/page events. Fusion may produce stable `fusedNodeId` values, but must preserve `sources`, `confidence`, `missingSources`, and `candidateOnly` when Web/runtime semantics are absent.

## Implementation Workflow

1. Update the relevant `space` README or technical design with BDD acceptance before code changes.
2. Add or update model/parser tests first:
   - iOS simctl argv and parser behavior;
   - Harmony hdc / aa / bm parser behavior;
   - Android adb parser behavior when that adapter lands;
   - error envelopes and destructive policy failures.
3. Implement shared contracts before CLI glue when a DTO or source-command shape is reusable.
4. Expose the CLI in a focused file under `Sources/TritonKitCLI/`, keeping JSON / JSONL as the agent-facing default.
5. Update `commandSchemas()` for every agent-facing command.
6. Sync docs and skills:
   - `README.md`;
   - `docs-linhay/dev/ai-cli-readable-control.md`;
   - current emulator takeover space;
   - `tritonkit-real-project-regression`;
   - `tritonkit-dev-feedback`;
   - memory entry.
7. If a new user-facing skill is added, include it in CI/release asset packaging and version stamping.

## Validation

Minimum local validation:

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
.build/cli/debug/triton schema --command evidence --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-host-smoke.sh
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

Run real emulator smoke only when safe for the current machine:

```bash
.build/cli/debug/triton sim list --json
.build/cli/debug/triton sim status-bar list --simulator booted --json
.build/cli/debug/triton app uninstall --device booted --bundle-id com.example.missing --confirm --json
.build/cli/debug/triton app launch --device booted --bundle-id com.example.missing --json
.build/cli/debug/triton device list --platform harmony --json
.build/cli/debug/triton device wait-ready --device <hdc-target> --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.
