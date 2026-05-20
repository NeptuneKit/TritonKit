## Background

TritonKit already provides embedded runtime observation and in-app control, but real-project regression still requires agents to directly call host-side tools such as `xcrun simctl`, `xcodebuild`, `devicectl`, `xctrace`, and plist readers.

This creates a split workflow: TritonKit controls the app once the runtime is connected, but simulator setup, app lifecycle, system permissions, deep links, app containers, preferences, logs, video, diagnostics, and Xcode build/test are outside the `triton` machine-readable contract.

## Expected Behavior

TritonKit should provide first-class simulator takeover capabilities through `triton` CLI/HTTP schema:

- Simulator discovery and lifecycle: list, use, boot, shutdown, erase, clone.
- App lifecycle: list, install, uninstall, launch, terminate, open URL.
- App data: container lookup, preferences dump/get.
- Simulator environment: privacy, location, appearance, content size, status bar, pasteboard, push.
- Host evidence: framebuffer screenshot, video recording, logs, diagnostics.
- Runtime binding: connect simulator/app targets with embedded runtime targets.
- Plan/evidence integration: `.tritonplan` host steps and `.tritonevidence` host artifacts.
- Later phases: host UI automation, xctrace performance capture, Xcode discover/build/test/result workflows.

All outputs should use stable JSON envelopes or JSONL progress events, with stable error codes, hints, and next actions.

## Reference Projects

- XcodeBuildMCP: `https://github.com/getsentry/XcodeBuildMCP`
- Existing TritonKit research: `docs-linhay/spaces/20260520-xcrun-host-adapter-research/README.md`
- New design space: `docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Technical design: `docs-linhay/spaces/20260520-simulator-takeover/technical-design.md`

## Proposed First Slice

Implement P0:

- `triton sim list/use/boot/shutdown/screenshot`
- `triton app list/install/launch/terminate/open-url/container/prefs`
- `triton schema/doctor/capabilities/plan` support for host adapter commands
- Fake process runner tests that assert generated `simctl` argv and JSON envelope mapping

## Notes

XcodeBuildMCP is a reference for workflow grouping, shared CLI/MCP handlers, structured output, JSONL progress, workspace daemon, and session defaults. TritonKit should not directly expose XcodeBuildMCP tool names or depend on its Node runtime as the primary implementation path.
