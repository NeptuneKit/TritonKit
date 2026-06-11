# 20260608 Single Device Web Preview

## Background

TritonKit needs a Baguette-like browser surface for previewing and operating a connected runtime target. This iteration intentionally restores only one Web entry: a single device detail page. It must be platform-aware for all three local emulator lanes: iOS Simulator, Android Emulator, and HarmonyOS / DevEco Emulator. It does not introduce a device list page, routing shell, Wails UI, multi-device switching, remote agent control, or a new product-level HTTP surface.

The business control contract remains the existing local `triton serve` management API. The Web page is a human-friendly client for the same machine-readable endpoints.

## Scope

- Add one browser entry at `/web/device`.
- Add a root browser entry at `/` that renders the same single device detail page while preserving the WebSocket runtime control channel.
- Add a Baguette-compatible detail entry at `/simulators/<id>` that renders the same page with an initial target selector.
- Show a Baguette-like device mirror surface: floating toolbar, codec segmented control, selected target title, phone shell, and a large live screenshot preview.
- Keep mirror chrome outside the app framebuffer by default: the target switcher is collapsed until requested, the connection / geometry metadata is not overlaid on the phone screen, and the action log appears only after a real action or error.
- Surface the selected target platform as machine-readable `/web/targets` data and human-readable chrome: iOS Simulator, Android Emulator, or Harmony / DevEco Emulator.
- Prefer ready host-side emulator targets for the Web preview: iOS Simulator screenshots use `simctl`, Android Emulator screenshots use `adb screencap`, and Harmony / DevEco Emulator screenshots use `hdc snapshot_display`.
- Keep embedded runtime targets as the source for app identity, hierarchy cache state, and fallback runtime screenshot / input behavior.
- Keep target identity, runtime cache state, and recent action result available in compact chrome instead of a left-side debug panel.
- Support single-target operations from the page:
  - refresh status / screenshot
  - tap by clicking on the screenshot preview
  - swipe up / down using window coordinate points
  - type, paste, and clear against the focused or coordinate-targeted input behavior already exposed by `TKInputRequest`
- For host targets, Android and Harmony support basic tap, swipe, type / paste, and button events through host tools; iOS host-side framebuffer preview is supported through `simctl`, and iOS app-level input is proxied to the connected embedded runtime on the same simulator UDID when available.
- Keep the page self-contained and served by `triton serve`.
- If zero ready host targets or runtime targets are connected, show an empty operational state.
- If more than one ready target is available on this machine, select one active target by default and allow switching from the compact target strip without hiding the device preview.
- If more than one ready target is available on this machine, select one active target by default and allow switching from the compact target strip when the target button is opened.
- When `/simulators/<id>` or `/web/device?target=<id>` is used, prefer a target whose id, simulator UDID, or host id suffix matches `<id>`. This supports iOS simulator UDIDs, Android emulator serials, and Harmony / DevEco target ids.

## Out Of Scope

- Multi-device list page, tabs, routing, or navigation.
- Wails desktop shell revival.
- Vite/React frontend project setup.
- iOS host-side HID actions such as Home, App Switcher, and hardware buttons.
- Real-device, remote agent, device-cloud, webhook, Postgres, or external HTTP productization.

## BDD Scenarios

### Scenario: Open the single device detail page

- Given `triton serve` is running
- When the browser opens `/web/device`
- Then the response is an HTML document with the `single-device-detail` page marker
- And the page fetches `/status` and `/web/targets`
- And no other Web page navigation is required

### Scenario: Open the browser root page

- Given `triton serve` is running
- When the browser opens `/`
- Then the response renders the same `single-device-detail` page
- And the runtime WebSocket channel remains available at `ws://<host>:<port>/`

### Scenario: Open a specific simulator detail page

- Given `triton serve` is running
- And a ready host target exists for the selector
- When the browser opens `/simulators/<id>`
- Then the response renders the same `single-device-detail` page
- And the page initially selects the target whose id, simulator UDID, or host id suffix matches `<id>`
- And the preview screenshot is loaded without requiring a manual target-strip click

### Scenario: Preview one connected device

- Given exactly one target is connected
- When the page loads
- Then it renders the target id, app identity, device description, platform, and hierarchy cache state
- And it requests the device screenshot through `/web/screenshot?target=<target-id>`
- And a ready host iOS / Android / Harmony target is rendered from the host emulator framebuffer when available

### Scenario: Operate the single device from the preview

- Given exactly one target is connected
- When the user clicks the screenshot preview
- Then the page posts a `tap` `TKInputRequest` to `/web/input?target=<target-id>`
- And the action result is shown in the page

### Scenario: Render Baguette-like device mirror chrome

- Given at least one target is connected
- When the page loads
- Then it renders a floating toolbar with the selected app title
- And it renders codec mode controls for H.264 and MJPEG
- And it renders the screenshot inside a rounded phone shell instead of a debug panel
- And target switching, connection metadata, and action logs do not cover the app framebuffer before the user asks for them

### Scenario: Render a platform-aware runtime target

- Given a connected target summary reports `platform = ios`, `android`, or `harmony`
- When the page renders the selected target
- Then the toolbar and target strip show the corresponding emulator family label
- And the hidden detail region exposes the selected platform for automation
- And the page calls `/web/geometry?target=...`, `/web/screenshot?target=...`, and `/web/input?target=...` with the exact target id

### Scenario: Prefer host-side simulator screenshots

- Given a booted iOS Simulator is available
- And the embedded runtime reports app identity for the same simulator UDID
- When the page loads `/`
- Then `/web/targets` returns a `host:ios:<udid>` selected target
- And the target keeps the runtime app name / bundle identifier
- And the screenshot preview is loaded from the host simulator framebuffer rather than the embedded runtime screenshot payload

### Scenario: Match selectors across all emulator families

- Given `/web/targets` contains `host:ios:<udid>`, `host:android:<serial>`, or `host:harmony:<target>`
- When the page receives an initial selector from `/simulators/<id>` or `?target=<id>`
- Then it matches exact ids, simulator UDIDs, and host id suffixes
- And it can select iOS, Android, or Harmony targets through the same single-device detail page

### Scenario: Expose ready Android and Harmony emulators

- Given a ready Android Emulator or Harmony / DevEco Emulator is connected through host tools
- When the page loads
- Then `/web/targets` includes `host:android:<serial>` or `host:harmony:<target>`
- And `/web/screenshot` captures the emulator framebuffer through `adb` or `hdc`
- And `/web/input` can submit basic coordinate and text actions for the selected host target

### Scenario: Decode older target summaries

- Given an older `/targets` payload does not include `platform`
- When TritonKit decodes the target summary
- Then it infers `ios`, `android`, or `harmony` from target id, simulator UDID, transport, device description, or OS description
- And iOS remains the default for legacy embedded runtime payloads

### Scenario: Select one active target when multiple app runtimes connect

- Given more than one runtime target is connected for the same local device
- When the page loads
- Then the page selects an active target
- And the device preview remains visible and operable
- And the compact target strip allows switching between app runtimes

## Acceptance

- CLI tests cover the Web page contract and Web target aggregation for runtime, iOS host simulator, Android host emulator, and Harmony host emulator.
- Shared transport tests cover platform-aware target summaries for iOS, Android, Harmony, and legacy payloads.
- `triton serve` logs the Web URL on startup.
- Local browser smoke can load `/` and `/web/device`.
- Local browser smoke can load `/simulators/<ios-udid>` and select that simulator without a manual click.
- Screenshot smoke confirms the page preview image uses a host screenshot natural size when a host simulator target is selected.
- Screenshot smoke confirms Baguette-like chrome stays outside the app framebuffer by default: the target strip and action log are hidden, and the phone screen has no connection / geometry overlay.
- Web input smoke confirms iOS host targets can proxy app-level input to the same-UDID embedded runtime, and Android / Harmony host targets can submit basic button or coordinate actions through `adb` / `hdc`.
- Documentation and memory are updated.

## Baguette Capability / UI Comparison

Reference checked on `http://localhost:8421/simulators/F4E55B8E-0141-4C46-9965-263CCE782B5F`.

- Matched in this iteration: stable `/simulators/<id>` detail route, selected app title in a floating toolbar, H.264 / MJPEG segmented chrome, centered phone shell, visible side buttons, host framebuffer screenshot preview, root `/` fallback, and target-specific iOS / Android / Harmony selection.
- Partially matched: H.264 / MJPEG are display controls only; the current Web page polls screenshots and does not yet expose Baguette's real stream / FPS pipeline.
- Not matched yet: live logs, accessibility inspector, rotate, iOS host HID Home / App Switcher / hardware buttons as real device-level actions.
- Verified UI correction after comparison: the target switcher is collapsed by default, hidden target/action elements use explicit CSS `display:none`, and the phone framebuffer is not covered by TritonKit chrome on initial load.
- Verified screenshot smoke after comparison on 2026-06-09:
  - iOS: `/simulators/60667794-96F8-40E6-8664-85538EC4663E` selected `host:ios:60667794-96F8-40E6-8664-85538EC4663E`, rendered `丁香园`, and loaded a `1206 x 2622` host screenshot.
  - Android: `/simulators/emulator-5556` selected `host:android:emulator-5556`, rendered `sdk_gphone64_arm64`, and loaded a `1080 x 2400` host screenshot.
  - Harmony: `/simulators/127.0.0.1%3A5555` selected `host:harmony:127.0.0.1:5555` and loaded a `1308 x 2880` host JPEG screenshot.
- Verified Web operation smoke after comparison on 2026-06-09:
  - iOS: `POST /web/input?target=host%3Aios%3A60667794-96F8-40E6-8664-85538EC4663E` with `{"type":"tap","targetOID":282}` logged `via triton:ios-simulator:60667794-96F8-40E6-8664-85538EC4663E` and returned `ok:true`.
  - Android: `POST /web/input?target=host%3Aandroid%3Aemulator-5556` with `{"type":"button","button":"home"}` returned `ok:true` through `adb input keyevent KEYCODE_HOME`.
  - Harmony: `POST /web/input?target=host%3Aharmony%3A127.0.0.1%3A5555` with `{"type":"button","button":"back"}` returned `ok:true` through `hdc uitest`.
- Screenshot evidence:
  - `docs-linhay/spaces/20260608-single-device-web-preview/screenshots/20260609-web-ios-detail-after-v04.png`
  - `docs-linhay/spaces/20260608-single-device-web-preview/screenshots/20260609-web-android-detail-after-v02.png`
  - `docs-linhay/spaces/20260608-single-device-web-preview/screenshots/20260609-web-harmony-detail-after-v02.png`
- Stability correction from smoke: Web refresh and screenshot polling now have frontend in-flight guards and screenshot fetch timeout, preventing repeated pending screenshot requests from leaving the page selected but blank.
