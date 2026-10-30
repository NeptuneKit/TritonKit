## Validation

Start with the installed CLI and preserve the current contract before selecting any target:

```bash
triton version --json
triton schema --command device --json
triton schema --command app --json
triton schema --command smoke --json
triton schema --command evidence --json
triton device list --platform ios --scope simulator --json
triton device list --platform harmony --json
```

Use only an explicitly authorized, dedicated Simulator/emulator for action checks. Pass its exact selector instead of a shared `booted` default. Query readiness and installed App state before a scoped install/launch flow, then verify the App's postcondition and capture bounded evidence. Restore owned changes and check all other instances remain unchanged.

For Harmony runtime validation, use the verified URL from `triton device runtime-url --device <hdc-target> --probe-manifest --json`, then inspect the runtime manifest and snapshot with that URL. Reuse an existing healthy forward; do not create conflicting forwards to satisfy a smoke check.

Repository-maintainer Swift tests and smoke scripts require a separate source checkout and its instructions; they are not included in this public bundle. Installed CLI schema checks alone do not substitute for those tests or real device acceptance. See [Device Hub contracts](device-hub-contracts.md) for current Apple platform evidence levels.

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.

### Resource profile acceptance

Use the [resource workflow](current-implemented-surface.md#android--harmony-resource-management) only when the installed schema covers it and the task authorizes the selected feature changes.

1. On a dedicated local emulator, preserve exact identity, feature states, permissions, workload, and baseline measurements before applying the reviewed plan. A catalog entry or shell exit zero does not prove control availability.
2. Confirm the apply receipt was written, then run target-bound verify. Check `ok`, `partial`, and `error`; pending, uncertain, or conflicting entries are not complete success. Permission-denied Harmony images remain diagnostic-only; do not bypass the failure.
3. Verify the affected App workflow, settled screen content, input, and readiness separately. Restore through the same receipt and check original feature states; preserve later conflicts instead of forcing old values. If testing persistence across a restart, retain target/image identity and the receipt's platform-specific boot constraints.
4. Compare matched workloads and timing. Keep guest PSS, VM main-process physical footprint, capture-process peaks, and client buffers separate. An unavailable/partial measure is not zero usage; a lower guest total or GPU-cache counter is not proof of host savings. The resource commands intentionally leave `businessVerified=false` and `hostSavingsVerified=false`.

### Preview and packaged acceptance

Preview lifecycle changes are independent of resource profiles. Verify the actual candidate in both applicable source and packaged modes; a launch plan or HTML 200 does not prove a working frame stream.

1. For packaged acceptance, run the installed or extracted CLI from outside a source checkout. `triton web --print-command --json` must report `mode=packaged`; start the real server separately. Bind evidence to that binary, static assets, target, and server PID, preserving other running services and devices.
2. Decode actual frames and check dimensions and visible content. Android uses original PNG; native iOS framebuffer and Harmony use JPEG, and source iOS screenshot fallback keeps its actual format. Verify each multipart part's Content-Type and Content-Length against its bytes rather than assuming JPEG from `mjpeg`. For native iOS, prove primary-screen content; a large decodable black image is not acceptance.
3. Cover one preview, two subscribers, hiding one while the other continues, hiding all, restoring a fresh frame, and final unmount. The final subscriber must stop capture, including disconnect before the first frame; hiding only one must not cancel another subscriber. Do not stop the emulator, App, logs, or recording to obtain a lower count.
4. Observe the actual page/pane visibility and capture process. Keep visible positive controls, account for sampling gaps, and distinguish reconnect-request time from decoded-first-frame time: the hidden negative window ends before reconnection begins. Synthetic visibility events or helper tests do not establish native page visibility behavior.
5. Check the client engine being claimed. A Chromium fixture does not prove native WebKit compatibility; a WKWebView harness does not prove the complete desktop shell. Record measured bandwidth and capture-process memory separately from VM savings, and retain cancellation/backpressure checks after changing frame format.

Detailed platform, timeout, and compatibility limits are in [platform-commands.md](platform-commands.md). Source-only evidence does not establish later release-asset behavior.
