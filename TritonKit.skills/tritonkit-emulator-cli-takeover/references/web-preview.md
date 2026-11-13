# Readonly Web preview and desktop boundaries

## Prerequisites

Use the complete version-matched CLI package, including Web assets and any selected native helper resources. A browser/desktop shell is a presentation surface; CLI or explicit local HTTP contracts own business actions. The React/Vite checkout is also a design/prototype environment, not proof of a restored Wails control plane.

First inspect the installed CLI without starting anything:

```bash
triton version --json
triton schema --command web --json
triton web --print-command --json
triton web status --json
triton web doctor --json
```

`web --json` returns a launch plan; it does **not** start a server. Verify its mode, asset root, binary and port. Default Web port is 34127; the local runtime HTTP service uses 19421. Do not replace another session's listener to make these numbers available.

## Workflow

1. For a release check, run from outside a source checkout and require `mode=packaged`. From a checkout, source mode may be selected; report it as such instead of claiming release-asset acceptance.
2. Discover/authorize the exact target through CLI before preview. `--simulator-only`, `--no-usb`, and `--no-lan` constrain Web discovery; they do not broaden provider capability.
3. When startup is authorized, run the non-JSON command in an owned foreground/managed process and open the exact URL it reports:

```bash
triton web --simulator-only
```

Source mode may prepare missing npm dependencies. Inspect the plan first; use `--no-install` when installing dependencies is not authorized, and resolve its explicit missing-dependency error rather than silently installing. Do not start a second server to mask a failed current one.
4. Select the observed device and read its preview, hierarchy and applicable Run/Atlas/evidence views. For layer details/3D use [UI inspection](ui-inspection.md); feature presentation does not assert provider readiness.
5. Perform business mutations through an explicitly authorized CLI flow, then refresh/re-observe the display. `/web/input`, `/web/node-property`, `/web/host-input`, `/web/command` and similar browser-write routes are readonly refusals, not alternate action APIs.
6. Close/hide the preview to release its subscription; stop only the Web process owned by this task when finished. Do not stop the device, App, recorder or another visible subscriber as a preview cleanup shortcut.

## Verification

Require an actual decoded frame with correct target, primary-screen content, dimensions and current timestamp/observation, not just a launch plan, HTML 200 or open socket. Black-but-decodable output is not acceptance.

Validate one/two subscribers, hiding one, hiding all, visible recovery with a fresh frame, and disconnect before the first frame. The last subscriber retires capture; a remaining subscriber keeps it active. A synthetic visibility event alone does not prove actual native page/pane behavior.

Android preview parts retain PNG; native iOS framebuffer and Harmony paths use JPEG, while the source iOS screenshot fallback preserves its actual format. Honor each multipart part's Content-Type/length even on a legacy `mjpeg` URL. Compare capture-process memory, transport bandwidth and VM footprint separately; no fixed resource saving follows from subscription cancellation.

Use the full [preview acceptance checklist](validation.md#preview-and-packaged-acceptance) for source/package/native-engine claims. A Chromium fixture is not complete desktop/WKWebView acceptance.

## Limits

Web is readonly. No browser operation, menu or App-map display grants business-action authority. Formal Wails business controls, remote fleet management, public multi-tenant hosting and automatic action replay are outside this workflow.

Read `/web/*` provider/error fields rather than treating a host candidate as a connected embedded runtime. Target-bound Resize/display/HID restrictions remain in force, and successful streaming does not establish input support. See [platform command constraints](platform-commands.md).
