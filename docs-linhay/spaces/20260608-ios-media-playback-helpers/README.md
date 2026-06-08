# 20260608 iOS Media Playback Helpers

## Background

GitHub issue [#36](https://github.com/NeptuneKit/TritonKit/issues/36) records a real iOS regression gap: an app using `AVPlayerViewController` could render remote SMB video, but system playback controls were not reliably exposed through accessibility after taps, coordinate taps, key events, or player re-entry. An app-owned overlay with stable accessibility identifiers made pause, resume, seek, progress, and route cleanup assertions repeatable.

## Goal

Expose first-class, machine-readable iOS media playback observation and guidance so agents can distinguish:

- visible rendered media surfaces;
- AX-discoverable playback controls;
- fallback requirements when system `AVPlayerViewController` controls are not accessible enough for automation;
- evidence commands that preserve media-control context in snapshots and evidence bundles.

## Scope

In scope for this issue:

- add a `media` section to embedded runtime snapshots;
- discover visible AVPlayer-backed media surfaces from public UIKit / AVFoundation / AVKit APIs where available;
- summarize AX playback-control candidates such as play, pause, seek, progress, elapsed, and duration;
- expose machine-readable fallback advice recommending app-owned DEBUG overlay controls with stable identifiers when system controls are absent;
- update CLI schema, capability metadata, README, project skills, and memory.

Out of scope for this issue:

- private API or SimulatorKit media-control injection;
- claiming reliable system `AVPlayerViewController` play/pause/seek control when AX does not expose actionable controls;
- adding Web/Wails UI;
- requiring every app to implement a custom overlay before media surfaces can be observed.

## Acceptance Scenarios

1. Given an embedded iOS runtime snapshot includes `media`, when an AVPlayer-backed surface is visible, then the snapshot returns a `media` artifact with surface identity, frame, player status/rate/time metadata where available, and evidence commands.
2. Given the AX tree contains stable app-owned playback controls, when `media` is evaluated, then the snapshot reports control candidates by action and marks automation confidence as `actionable-controls`.
3. Given rendered media is visible but no actionable playback controls are discoverable, when `media` is evaluated, then the snapshot reports automation confidence as `surface-only` and includes fallback advice for app-owned overlay controls.
4. Given agents inspect `triton capabilities --json` or `triton schema --command snapshot --json`, then they can discover the `media-playback` capability and use `triton snapshot --include media,ax,screenshot-metadata --json` as the next action.

## Verification

- `swift test --filter TKRuntimeStateModelsTests`
- `swift test --filter TKRuntimeMediaSnapshotTests`
- `swift test --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
