# iOS Host AX Tap Smoke Evidence

Date: 2026-07-06

Target:

- Simulator: `TritonKit Dedicated iPhone 17`
- UDID: `0333546D-2AC6-4C22-AF01-293E2F4BA5BC`
- Runtime: `iOS 26.5`

## Triton-First Facts

Commands:

```bash
.build/cli/arm64-apple-macosx/debug/triton status --json
.build/cli/arm64-apple-macosx/debug/triton doctor --json
.build/cli/arm64-apple-macosx/debug/triton capabilities --json
.build/cli/arm64-apple-macosx/debug/triton schema --command observe --json
.build/cli/arm64-apple-macosx/debug/triton schema --command node --json
.build/cli/arm64-apple-macosx/debug/triton schema --command act --json
.build/cli/arm64-apple-macosx/debug/triton schema --command sim --json
.build/cli/arm64-apple-macosx/debug/triton plan --format json
```

Observed:

- Local management server was unavailable, so `status/doctor/plan` reported the
  expected server bootstrap path.
- Host-side schema and capabilities remained available without the embedded
  server.
- `capabilities --json` reported `observe-ios-host-ax`, `ios-host-ax`,
  `ios-host-hid`, and `ios-simulator-host-tap` as supported.
- `schema --command act --json` exposed `host.ios-tap` and tap failure codes
  including `ios_host_ax_action_unavailable`.

## Readonly Smoke

Boot:

```bash
.build/cli/arm64-apple-macosx/debug/triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl
```

Result:

- JSONL final event: `ok=true`, `ready=true`, `state=Booted`.

AX and observe:

```bash
.build/cli/arm64-apple-macosx/debug/triton sim ax --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
.build/cli/arm64-apple-macosx/debug/triton observe tree --platform ios --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --max-nodes 30 --json
.build/cli/arm64-apple-macosx/debug/triton node resolve --platform ios --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --text "设置" --json
```

Observed:

- `sim ax` returned SpringBoard nodes including `设置`.
- `observe tree` returned `ok=true`, `primarySource.name=host-layout`, and
  `sourceCommands=["triton sim ax --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json"]`.
- `node resolve --text "设置"` returned `matchCount=1` and a tappable
  `AXButton` at frame `x=306,y=389,width=68,height=90.6667`.

## Host Tap Smoke

First action:

```bash
.build/cli/arm64-apple-macosx/debug/triton act tap --platform ios --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --text "设置" --json
```

Observed:

- Returned `ok=true`, `platform=ios`, `query=设置`, `x=340`, `y=434`.
- Initial implementation also surfaced an uncaught
  `accessibilityTranslationRootParentWithToken:` callback exception after JSON
  output. The fix added that delegate callback to `TokenDispatcher`.

Regression action after callback fix:

```bash
.build/cli/arm64-apple-macosx/debug/triton act tap --platform ios --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --text "通用" --json
.build/cli/arm64-apple-macosx/debug/triton observe tree --platform ios --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --max-nodes 30 --json
```

Observed:

- Tap returned clean JSON with no private-framework exception:
  `ok=true`, `query=通用`, `match.role=AXButton`,
  `match.identifier=com.apple.settings.general`.
- Post-action observe returned `ok=true`, `primarySource.name=host-layout`,
  and labels including `通用` and `关于本机`, proving the host tap navigated from
  Settings root into General.

## Validation

Commands:

```bash
swift test --disable-sandbox --package-path CLI --scratch-path .build/cli-test --filter SelectorFlagTests
swift test --disable-sandbox --package-path CLI --scratch-path .build/cli-test --filter SchemaFactSourceTests
swift test --disable-sandbox --package-path CLI --scratch-path .build/cli-test --filter FailureDiagnosticsTests
swift build --package-path CLI --scratch-path .build/cli --product triton
```

Result:

- All commands passed.
