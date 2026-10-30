# Platform Command Surfaces

Use this reference when changing iOS Simulator, Android Emulator, Harmony / DevEco, app lifecycle, observe, screenshot, or host action commands.

## Common Target Commands

```bash
triton device doctor --platform ios --json
triton device doctor --platform android --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform android --json
triton device list --platform harmony --json
triton device alias set iphone15 --platform ios --target <simulator-udid> --json
triton device use iphone15 --json
triton device current --json
triton device resolve iphone15 --json
triton device wait-ready --device iphone15 --json
```

Use `--device <selector>` as the default agent-facing target selector for common host-side commands. Selectors can be aliases, full ids, raw platform ids, `booted`, or `current`.

## Observation

Prefer fresh outline before selecting numbered nodes:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton node resolve @1 --platform <ios|android|harmony> --device <selector> --json
```

`@N` aliases are repo-local snapshots written to `.triton/node-aliases.json`. If stale, refresh instead of guessing.

## iOS Simulator

Examples:

```bash
triton sim list --json
triton sim boot <udid> --wait --jsonl
triton sim screenshot --simulator <udid-or-booted> --output /tmp/case.png --json
triton app install --device iphone15 --app <path.app> --json
triton app launch --device iphone15 --bundle-id <bundle-id> --json
```

Embedded runtime targets use stable ids shaped as `triton:ios-simulator:<SIMULATOR_UDID>` or `triton:ios-simulator:<SIMULATOR_UDID>/app:<bundle-id>`. Get them from `triton list --json`. Runtime gestures such as `triton act swipe` need that runtime target through `--target`; do not pass host selectors such as `sim:<udid>`. If more than one runtime target is connected and the command uses default `triton:local`, return `ambiguous_target`.

```bash
triton act swipe --target <ios-runtime-target-from-triton-list> --start-x 110 --start-y 700 --end-x 110 --end-y 140 --duration 0.6 --json
```

## Android Emulator

Android Emulator host-side support includes ADB-backed discovery, readiness, start/stop, screenshot, app lifecycle, UIAutomator observe/wait/tap, and `smoke android`.

Keep DTOs, evidence, and command-ledger schemas platform-neutral across iOS, Android, and Harmony.

### Host memory investigation

- Bind observations to the live PID, startup time and its log files. Compare persistent `config.ini` with the generated `hardware-qemu.ini` and current startup log: the emulator may raise requested RAM, select a different renderer or restore a snapshot. A configured RAM value is not the process's total memory footprint.
- On macOS, record `vmmap -summary <pid>` physical footprint separately from RSS, virtual reservations and system swap/compression. These metrics are not interchangeable, and one sample does not establish a leak or attribute allocations to graphics or snapshots.
- Headless execution still renders the guest display. Confirm the actual graphics backend from the current log; software Vulkan/GLES and snapshot restore are candidates for controlled comparison, not proven causes of excess memory.
- After checking the installed schema, `device start --platform android --avd <name> --gpu host --no-snapshot-load --plan-only --json` can preview a cold-start comparison. `planOnly=true` / `started=false` proves planning only. Restart after active tests and streams have finished; compare identical workloads and verify readiness, screenshots and app behavior before claiming improvement.
- Do not lower display resolution on a regression device without accounting for changed layout, coordinates and screenshot baselines. Do not assume `--memory` or `--gpu` applies to Harmony: the current launch options are Android-specific, and lower Harmony RAM requires separate support and runtime verification.
- When the goal is feature slimming, inventory live package/service PSS and dependencies first. Exiting the emulator, lowering RAM or changing graphics does not substitute for a requested selective feature profile. Features already off or services already demand-loaded and absent have no observed immediate process-memory saving.
- Android package-level plans should preserve each user's exact enabled state: `default-state` and explicit `enable` are different restore operations. Preserve Google services, WebView/Custom Tabs, input, networking and active test/stream processes unless their feature scope explicitly permits removal. Enumerate PID/suffixed process names before per-process memory queries; a missing base process is not proof of an absent package.
- Harmony service names and startup/critical/on-stop/ondemand rules must come from the selected image. Check current `begetctl service_control` and `bm` help instead of assuming Android-like package disable commands. Shell exit zero can still contain HDC failure or a parameter permission error; verify the payload, PID/SA state and affected dependencies. Do not equate command availability with control permission or successful restoration.
- Guest PSS reduction does not establish host footprint reduction. Verify actual balloon/free-page-reporting device binding and host measurements; module presence or upstream QEMU support is insufficient. Keep separate receipts for feature state, process-memory change, business verification and host-memory change. Match emulator executables and both `-start`/`-hvd` launch forms before assuming a Harmony instance is stopped.
- Check the installed schema before using the new Android startup flags: `--no-snapshot` disables both loading and saving, overrides `--no-snapshot-load`, and does not delete snapshots; `--disable-vulkan` is only for tests that do not require Vulkan. Both default to false and reject non-Android targets. The existing `--gpu host` is an explicit choice, not a guaranteed memory reduction.
- Audit optimizer source and benchmarks before adoption. A fixed baseline is not a measured before/after comparison. Native `-lowram` can remove the emulator's minimum RAM bound without enabling `ro.config.low_ram`; always compare actual guest MemTotal, feature states and UI. In SP-244, an old emulator plus unit-suffixed config produced a much smaller guest and System UI ANR; explicit equal RAM removed the apparent saving. Do not expose this as service slimming or copy destructive snapshot cleanup / broad package disabling.
- Distinguish capture frequency, transport FPS and visibility. Hidden previews may keep collecting screenshots; verify the last subscriber actually cancels capture before claiming buffer savings. Native gfxstream callback buffer counts do not describe Triton's adb/hdc screenshot-loop implementation. Source Web previews release hidden subscriptions and reconnect on visibility restoration. For Android/Harmony, bind each release to its acquired session, acquire within the HTTP response body, and observe inbound close even before the first frame; otherwise early disconnects or terminal-session reuse can leave capture running or a new preview permanently connecting. Validate actual native page visibility and multiple subscribers against the current server PID. The fifth-round evidence covered source Web only; its packaged-route gap is superseded by the sixth-round implementation below, while the historical evidence remains limited to its tested candidate and does not establish a fixed memory saving.
- For cache-reclaim experiments, compare against a sham action after the same release workload. Validate actual timestamps and stability of the pre-action samples; automatic reclaim can cross the baseline window and create a false benefit even when PID/schema checks pass. Harmony hidumper Total Pss already includes SwapPss. ArkWeb may wrap runJavaScript JSON output in an extra JSON string; validate the decoded state rather than accepting undefined as readiness.
- A successful zRAM compact write and an increasing pages_compacted counter do not prove sustained pool reduction or host reclaim. Record net mem_used_total and host footprint separately. Any isolated debug-root experiment must verify unroot and original state restoration; it does not establish ordinary-shell product availability.
- Check platform overrides after feature defaults: current AOSP Mac code disables file-backed Quickboot despite its ini setting. Linux KSM is not a macOS memory-deduplication switch. zRAM/freezer may already be enabled; allocator compaction, swap writeback and host physical reclaim are different outcomes. ArkWeb trim is an application-scoped cache request, not an HDC-wide service switch.

## Preview streaming and packaged runtime

SP-244 sixth-round implementation and local acceptance are complete; consult the [sixth-round report](../../../docs-linhay/spaces/SP-244-emulator-service-slimming/plans/20261030-harmony-packaged-preview.md) for actual platform/mode results. All three packaged platform paths passed on the recorded local candidate; this is not a published release or a cross-toolchain guarantee. Keep the [fifth-round record](../../../docs-linhay/spaces/SP-244-emulator-service-slimming/plans/20261030-preview-auto-pause.md) as historical evidence, not proof for later assets.

- Both source Web and packaged mode register `/web/android/mjpeg` and `/web/harmony/mjpeg`. Source Web uses the existing dev proxy/framebuffer path; packaged routes subscribe to the in-process framebuffer directly, without the dev bridge or a separate port-19421 service. Invalid packaged target/FPS queries return JSON errors rather than a SPA document.
- Use the shared executable finder even when SDK tools are absent from PATH. ADB checks `~/Library/Android/sdk/platform-tools/adb`; HDC checks `~/harmonyOS-command-line-tools/bin/hdc`, then `~/Library/Huawei/Sdk/openharmony/12/toolchains/hdc` and the corresponding `11/toolchains/hdc`, before PATH. Require actual executable files, preserve ordinary missing-tool failures, and do not add implicit installation or privilege escalation.
- Explicit Android/Harmony preview selectors use only that platform's lightweight target list and existing selector resolution. Preserve canonical IDs, aliases and stored current selections; avoid unrelated platforms and foreground-app enrichment. Only an unresolved `current` may use the constrained legacy current-target query. Keep identity, platform and readiness validation.
- Harmony `snapshot_display` and `file recv` each have a bounded 15-second budget; they run sequentially, so this is not a 15-second whole-frame deadline. The frontend's first-frame probe has a monotonic 45-second deadline and stops after the actual network frame arrives. Hiding, disconnecting or unmounting cancels immediately instead of waiting for that deadline. A larger budget is not evidence that capture or recovery succeeded.
- Packaged iOS deliberately acquires its validated startup reference before the body to preserve synchronous startup `409` errors. A RAII subscription owns that reference and releases it once, including when the body never starts or a connection closes before the first frame. Do not generalize this change to every source-iOS capture path. Android/Harmony continue to acquire within the response body and release only their acquired session generation.

These are preview subscriptions, not device shutdown, app termination, recording or log controls. Verify that another visible subscriber keeps receiving frames when one preview hides, and that the last subscriber stops capture.

## Harmony / DevEco Emulator

Examples:

```bash
triton device list --platform harmony --json
triton device wait-ready --device harmony-a --json
triton app install --device harmony-a --hap <debug-signed.hap> --json
triton app launch --platform harmony --device harmony-a --bundle <bundle> --ability <ability> --json
triton observe tree --device harmony-a --outline --json
triton act tap "登录" --platform harmony --device harmony-a --json
```

HDC output shape drifts. Parse verbose and plain target outputs, and do not parse prose errors as targets.

Foreground app identity from Harmony host discovery is optional host fact, not app lifecycle proof.

### SP-244 功能开关入口

源码新增 `triton device resource profiles|features|status|doctor|plan|apply|verify|restore|measure`；先用 `triton schema --command device.resource --json` 核对实际安装版本。Android `ui-minimal` 包含搜索助手、YouTube、音乐、数字健康与蓝牙，可用 `--keep bluetooth` 或 `--profile custom --disable youtube,music` 调整。apply/restore 要求 `--confirm` 与私有 receipt；原 enabled=0 必须恢复 default-state，后续冲突保留。Harmony camera/audio/analytics 先检测权限，商用镜像 boot ID/服务状态拒绝时仅诊断，不自动提权。`memory` 和 `hostMemory` 分别报告guest PSS与VM主进程footprint；任一partial/不可用不得当成零占用。运行中关闭未必让host立即回收。

Android状态解析仅接受顶级Packages段，排除Queries/hidden段的User 0；meminfo --oom按PSS分组解析且忽略分类汇总，数字右对齐使缩进长度可变。Bluetooth的Exec/Success回执必须与请求动作匹配并读回。未完成receipt的verify始终保留partial；新失败码同步schema恢复分类与public命令snapshot。

- iOS stream acceptance must check the actual primary-screen content and dimensions, not only a decodable JPEG. An off Resizable display can retain the largest IOSurface. Keep normal target-bound Resize/display guards, then uniquely match native descriptor `screenProperties.uniqueId` to the validated primary `uniqueId`; `port.uuid` is a different framebuffer namespace. Missing/duplicate identity or a missing primary surface must not redirect capture. Do not extend the explicit primary-still unsupported-Resize exception to streaming. See the [SP-244 packaged preview evidence](../../../docs-linhay/spaces/SP-244-emulator-service-slimming/plans/20261030-harmony-packaged-preview.md).


### Further memory investigation guardrails (SP-244 round seven)

- Native startup flags can remove host virtual hardware while breaking guest services. The tested API34 camera/UWB/Bluetooth/GNSS bundle produced a Bluetooth crash dialog; do not recommend it from lower footprint alone. Check settled screenshots, exact package/Bluetooth states, camera enumeration and matched timing. First-boot state drift and concurrent host workloads invalidate a savings claim.
- Android VM selection supports exactly one `@AVD` or `-avd NAME`; reject mixed/duplicate/malformed selectors and retain PID/port identity checks. Preserve unavailable/partial measurements rather than substituting RSS for physical footprint.
- Harmony6.1.1.200 already enables free-page reporting in the checked image/kernel logs. Guest reporting does not establish host page reclamation. A camera feature gate in shared image metadata is only a candidate until isolated runtime and memory validation pass.
- For development MJPEG proxies, honor writable backpressure and cancel drain waits on close/error/abort; queue bytes from a bounded TCP fixture are not VM savings. Apply RAII to successful eager iOS subscriptions on both direct and packaged routes, including never-executed bodies and disconnects before the first frame.


### Encoding-memory evidence (SP-244 round eight)

- Separate native encoder-process peaks, retained payload/queues, client decoding and VM physical footprint. Per-frame autoreleasepool bounds transient iOS encoding objects during continuous work; paced workloads may already be flat. Preserve image lifetime outside the pool and stop/late-frame behavior.
- PNG passthrough can avoid Android host decode/JPEG allocations, but changes MIME, client compatibility and bandwidth. A fake-adb full-loop result plus a Chromium fixture is not a product/WKWebView acceptance result. Smaller thumbnails can raise peak memory when full PNG decoding and resizing coexist.
- Native diagnostic tools may return exit0 with usage text for an unavailable action. The current Harmony commercial image did exactly this for upstream trimMem; verify command support and output before claiming a cache operation. Android HWUI app_memory_policy is a separate property from emulator -lowram, and requires target-version, fresh-process, matched idle timing and preserved-App validation before any option is adopted.

### Android PNG adoption (SP-244 round nine)

Android previews now preserve the captured PNG bytes. Native iOS framebuffer and Harmony capture retain JPEG; the source iOS screenshot fallback preserves its actual image format. Existing `mjpeg` endpoint names remain, but clients must decode each part according to its Content-Type rather than assume JPEG. The common writer carries a typed format and matching length. PNG validation bounds input size and container structure before no-cache metadata checks; it avoids full-image decoding and does not guarantee every CRC or compressed-pixel payload is valid.

On the recorded real API34 Settings workload, four independent HTTP processes in JPEG/PNG/PNG/JPEG order reduced the median streaming peak from 18.99 to 8.56 MiB, while sustained median usage fell only 0.55 MiB. Payload rose 9.87%; the earlier two-image 17.60% was another sample. These are capture-process results, not emulator-VM savings or universal bandwidth ratios. Actual source proxy, extracted package and native WKWebView checks passed for this candidate; the native harness is not full desktop-shell acceptance. See the [ninth-round evidence](../../../docs-linhay/spaces/SP-244-emulator-service-slimming/plans/20261030-png-adoption-commit.md).

Use one configured upstream for readiness, streaming and stream-internal fallback. Do not hide hardcoded addresses with test-only fetch rewrites. Record both reconnect-request time and decoded-first-frame time; hidden negative observation windows end before reconnection begins. Keep visible positive controls and distinguish process sampling from exact frame counts.

Source iOS screenshot fallback sessions are scoped to upstream URL, CLI path and device. The last subscriber retires its generation and cancels pending HTTP capture/timers; an immediate reconnect must not revive the old loop or consume a different upstream's frames. Already-started native CLI work may finish, but its late result cannot publish into the new generation or schedule another capture.
