# TritonKit Public Skills

This directory is the canonical source and install bundle for TritonKit skills distributed to external users and adopting projects.

Use the guarded [installation/update workflow](tritonkit-update/SKILL.md) for the whole `TritonKit.skills/` directory. Inspect the installed CLI schema and dry-run before an authorized update; do not overwrite locally modified skills or remove receipts to bypass a refusal. Cross-skill references require all four bundled skills, not four isolated SKILL.md copies.

Old separate top-level skill directories are migrated only when empty or byte-identical; preserve modifications for an explicit conflict decision. Skills install neither the CLI nor the App SDK/Runner automatically.

Release automation packages this directory into `tritonkit-skills.tar.gz`; extracting that asset into the agent skills directory creates `TritonKit.skills/`.

The bundle contains:

- `tritonkit-dev-feedback`
- `tritonkit-emulator-cli-takeover`
- `tritonkit-real-project-regression`
- `tritonkit-update`

`tritonkit-runtime` is not a member of the official TritonKit public bundle. If an adopting project has a separately maintained skill with that name, update it against `triton schema --json` before use. For CLI 0.2.8 and later, legacy action roots such as `find`, `tap`, `type`, `paste`, `clear`, `focus`, `set-text`, and `input` belong under `triton act`; the legacy `ax` and `geometry` roots belong under `triton debug`. Compatibility aliases are intentionally not promised.

Release packaging validates every literal `triton` command root in public Markdown against the release’s checked CLI command-schema snapshot. The `act` and `debug` subcommand sets are also strict. A CLI hierarchy change must update that snapshot and its CLI contract test before public skills can be packaged.

Repository-maintenance, governance, planning, supervision, and implementation skills live under `.agents/skills/` and must not be packaged into public release skill bundles.

## Capability routing

This is a **capability-family index**, not a promise that every leaf option/provider is available in every installed release. Start from an observed target and the installed `version`/command `schema`. A document, mock, ACK, confirmation or complete capture does not prove business success. Source changes appear in installed skills only after a separately verified bundle update/release.

| ID | Capability | Read the smallest applicable guide |
| --- | --- | --- |
| `agent` | Agent/automation workflow | [Real-project workflow](tritonkit-real-project-regression/references/workflow.md) |
| `cli` | CLI/JSON contracts | [Schema contracts](tritonkit-emulator-cli-takeover/references/schema-contracts.md) |
| `http` | Local HTTP/runtime channel | [Local HTTP API](tritonkit-emulator-cli-takeover/references/http-api.md) |
| `dsh` | Optional DSH four-tool wrapper | [DSH integration](tritonkit-dev-feedback/references/dsh-integration.md) |
| `web` | Readonly Web/desktop preview | [Web preview](tritonkit-emulator-cli-takeover/references/web-preview.md) |
| `discover` | Version, capability and planning discovery | [Triton-first entry](tritonkit-emulator-cli-takeover/SKILL.md) |
| `target` | Device/runtime binding and optional lease | [Target leases](tritonkit-emulator-cli-takeover/references/target-leases.md), [device contracts](tritonkit-emulator-cli-takeover/references/device-hub-contracts.md) |
| `observe` | Tree, alias, OCR, settle, health | [Observation contracts](tritonkit-dev-feedback/references/observation-feedback.md) |
| `action` | Provider-bound input and receipts | [Runtime action evidence](tritonkit-dev-feedback/references/evidence-ios-runtime.md), [host evidence](tritonkit-dev-feedback/references/evidence-host-devices.md) |
| `verify` | Wait/assert/business postconditions | [Regression entry](tritonkit-real-project-regression/SKILL.md) |
| `evidence` | Original facts, capture, inspect, explicit redact | [Evidence and issues](tritonkit-real-project-regression/references/evidence-and-issues.md) |
| `app` | Device/App/environment/resource lifecycle | [Implemented surface](tritonkit-emulator-cli-takeover/references/current-implemented-surface.md) |
| `webview` | DOM/form/bridge/network boundaries | [WebView actions](tritonkit-emulator-cli-takeover/references/webview-actions.md), [proxy](tritonkit-emulator-cli-takeover/references/network-proxy.md) |
| `inspect` | Details, solo/group images, readonly 3D | [UI inspection](tritonkit-emulator-cli-takeover/references/ui-inspection.md) |
| `build` | Build/test/archive/diagnostics | [Xcode contracts](tritonkit-dev-feedback/references/xcode-feedback.md) |
| `replay` | Explicit recording, import and live test | [Test recorder](tritonkit-real-project-regression/references/test-recorder.md), [command replay](tritonkit-real-project-regression/references/replay-plans.md) |
| `workspace` | Workspace/Atlas/map and optional inference | [Workspace](tritonkit-emulator-cli-takeover/references/workspace-runs.md), [App-map](tritonkit-emulator-cli-takeover/references/app-map.md), [VLM models](tritonkit-emulator-cli-takeover/references/vlm-models.md) |
| `ioshost` | iOS Simulator host adapter | [Platform commands](tritonkit-emulator-cli-takeover/references/platform-commands.md) |
| `iossdk` | Debug-only iOS embedded SDK | [iOS integration](tritonkit-real-project-regression/references/ios-integration.md) |
| `runner` | Independent iOS XCTest session | [Bundled Runner](tritonkit-real-project-regression/SKILL.md#bundled-ios-runner-regression) |
| `android` | ADB/UIAutomator/Bridge | [Implemented surface](tritonkit-emulator-cli-takeover/references/current-implemented-surface.md) |
| `harmony` | HDC/ArkWeb/standalone runtime | [Harmony integration](tritonkit-real-project-regression/references/harmony-integration.md) |
