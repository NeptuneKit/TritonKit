# 20260525 Cross-Platform CLI Simplification

## 背景

当前 `triton` 命令已经覆盖 iOS Simulator、Harmony Emulator、embedded runtime、WebView、evidence 和 replay，但 agent 在常用设备回归链路里仍要记住多个平台入口：

- iOS Simulator 发现、选择、等待和截图主要在 `triton sim`。
- Harmony Emulator 发现、选择、等待和 runtime URL 主要在 `triton device`。
- App 生命周期已经基本通过 `triton app --platform ios|harmony` 收敛。
- UI 动作已经基本通过 `tap/swipe/type/paste/clear/press --platform harmony` 收敛。

本轮目标是先抹平最常用的 host device 差异，而不是删除旧命令。

## 范围

### In Scope

1. `triton device` 支持 `--platform ios|harmony`。
2. `device list` 输出统一 envelope，iOS 内部复用 `simctl list devices available`，Harmony 内部复用 `hdc list targets -v`。
3. `device use` 支持 iOS simulator UDID 和 Harmony HDC target。
4. `device wait-ready` 支持 iOS Booted 与 Harmony `bootevent.boot.completed=true`。
5. 新增 `device screenshot --platform ios|harmony --output <path>`，对齐常用截图入口。
6. 保留 `triton sim` 作为 iOS 高级维护入口，不做破坏性迁移。

### Out of Scope

1. 不删除 `sim` / `app` / `webview` / `observe` 旧入口。
2. 不把 iOS runtime、Harmony embedded runtime 和 WebView provider 强行合并。
3. 不引入 Web/Wails UI。
4. 不做 Android adapter。
5. 不改 Release 分发或 Homebrew 契约。

## BDD 验收

### 场景一：agent 用统一入口列设备

- Given 本机有 iOS Simulator 或 Harmony Emulator
- When 执行 `triton device list --platform ios --json`
- Then 输出 `ok=true/platform=ios/targets[]`
- And 每个 target 至少包含 `id/platform/name/state/isReady/source`

- When 执行 `triton device list --platform harmony --json`
- Then 输出同一个 envelope 形状
- And Harmony target 仍保留 `rawTarget/transport`

### 场景二：agent 用统一入口选择设备

- Given iOS simulator UDID 已知
- When 执行 `triton device use --platform ios --target <udid> --json`
- Then 写入与 `triton sim use <udid>` 相同的 workspace defaults

- Given Harmony target 已知
- When 执行 `triton device use --platform harmony --target <target> --json`
- Then 输出同一 envelope，且不会写 iOS simulator defaults

### 场景三：agent 用统一入口等待 ready

- Given iOS simulator 已 Booted
- When 执行 `triton device wait-ready --platform ios --target <udid> --json`
- Then 输出 `ready=true`

- Given Harmony target ready
- When 执行 `triton device wait-ready --platform harmony --target <target> --json`
- Then 输出 `ready=true`

### 场景四：agent 用统一入口截图

- Given iOS simulator 或 Harmony target 可访问
- When 执行 `triton device screenshot --platform <platform> --target <target> --output <path> --json`
- Then 通过对应 host tool 写出截图
- And 输出统一 action envelope，保留底层 `sourceCommand`

## 方案

选择“统一常用入口 + 保留高级旧入口”：

- `device` 是 agent 默认入口。
- `sim` 继续承载 iOS 专属高级能力：boot/shutdown/runtime/status-bar/privacy/location/pasteboard/push/personalization。
- 文档和 schema 把推荐路径改为 `device --platform`，但旧命令保持可回归。

该方案回滚成本低，只需要回滚 `device` 新分支，不影响旧脚本。

## 2026-05-25 实施结果

已完成第一轮精简：`device` 作为 agent 默认 host device 入口，覆盖 iOS Simulator 与 Harmony Emulator 的发现、选择、ready 等待和截图。

新增或调整的统一入口：

```bash
triton device doctor --platform ios --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform harmony --json
triton device alias set ios-dedicated --platform ios --target <simulator-udid> --json
triton device alias set harmony-a --platform harmony --target <hdc-target> --json
triton device use ios-dedicated --json
triton device current --json
triton device resolve --platform ios --name "iPhone 15" --ready --json
triton device wait-ready --device ios-dedicated --json
triton device wait-ready --device harmony-a --json
triton device screenshot --device ios-dedicated --output <path.png> --json
triton device screenshot --device harmony-a --output <path.jpeg> --json
```

统一输出 envelope 以 `HostDeviceTarget` 为核心：

- `platform`: `ios` 或 `harmony`
- `id`: `sim:<udid>` 或 `harmony:<target>`
- `target`: 平台原生 target id
- `state`
- `ready`
- `source`
- iOS 附加 `name/runtime`
- Harmony 附加 `transport`

`device use <selector>` 会写入 `.triton/host-targets.json` 的 current selector；`selector` 支持 alias、`sim:<udid>`、`harmony:<target>`、raw id、`booted` 和 `current`。旧的 `--platform/--target` 仍作为兼容路径保留。

`device screenshot` 会先检查统一 target 的 `ready` 状态；未 ready 时直接返回 `device_not_ready`，避免把已关机 simulator 交给底层 `simctl` 后卡到 host command timeout。

## 真实验证

本机验证通过：

```bash
swift test --package-path CLI --scratch-path .build/cli
swift test --filter TKHostAdapterModelsTests
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton device list --platform ios --json
.build/cli/debug/triton device list --platform harmony --json
.build/cli/debug/triton device alias set ios-dedicated --platform ios --target 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
.build/cli/debug/triton device alias set harmony-a --platform harmony --target 127.0.0.1:10100 --json
.build/cli/debug/triton device use ios-dedicated --json
.build/cli/debug/triton device resolve harmony-a --json
.build/cli/debug/triton device wait-ready --platform ios --target 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --timeout 5 --interval 0.5 --json
.build/cli/debug/triton device wait-ready --platform harmony --target 127.0.0.1:10100 --timeout 5 --interval 0.5 --json
.build/cli/debug/triton device wait-ready --device harmony-a --timeout 5 --interval 0.5 --json
.build/cli/debug/triton device screenshot --platform ios --target 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --output /tmp/triton-device-ios-20260525-smoke-v01.png --json
.build/cli/debug/triton device screenshot --platform harmony --target 127.0.0.1:10100 --output /tmp/triton-device-harmony-20260525-smoke-v01.jpeg --json
.build/cli/debug/triton device screenshot --device harmony-a --output /tmp/triton-device-harmony-selector-20260525-smoke-v01.jpeg --json
.build/cli/debug/triton device screenshot --platform ios --target 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --output /tmp/triton-device-ios-not-ready-20260525-smoke-v01.png --json
.build/cli/debug/triton device screenshot --platform harmony --target 127.0.0.1:10100 --output /tmp/triton-device-harmony-20260525-final-smoke-v01.jpeg --json
```

真实目标：

- iOS：`TritonKit Dedicated iPhone 17`，UDID `0333546D-2AC6-4C22-AF01-293E2F4BA5BC`，`iOS 26.5`，`Booted`。
- Harmony：HDC target `127.0.0.1:10100`，`Connected`，`bootevent.boot.completed=true`。

2026-05-25 追加复测时，iOS simulator 已变为 `Shutdown`；`device screenshot` 对该目标快速返回 `device_not_ready`，未生成输出文件，确认不会再交给底层 `simctl` 等待超时。Harmony target 仍为 `Connected/ready=true`，截图成功输出 `/tmp/triton-device-harmony-20260525-final-smoke-v01.jpeg`。

截图证据：

- `docs-linhay/spaces/20260525-cross-platform-cli-simplification/screenshots/20260525/device/20260525-device-screenshot-ios-after-v01.png`
- `docs-linhay/spaces/20260525-cross-platform-cli-simplification/screenshots/20260525/device/20260525-device-screenshot-harmony-after-v01.jpeg`

## 未对齐项

本轮只精简了最常用 host device 操作，没有把所有平台能力强行拉平：

1. `triton sim` 仍保留 iOS 高级维护能力，包括 boot/shutdown/record/logs/diagnose/runtime/status-bar/privacy/location/ui/pasteboard/push/personalization；这些能力暂不迁入 `device`。
2. `device runtime-url` 仍仅支持 Harmony，因为这是 Harmony embedded HTTP runtime 的 HDC `fport` 准备动作；iOS embedded runtime 继续通过 `triton serve` 与 runtime target 选择处理。
3. `device screenshot` 在 iOS 侧输出 PNG，在 Harmony 侧通过 `snapshot_display` 输出 JPEG；统一的是命令入口和 artifact envelope，不伪装图片格式。
4. WebView provider / DOM / bridge 能力没有并入 `device`。iOS WebView provider 已有 metadata/snapshot/bridge 路径，Harmony 仍是 host-layout candidate 边界。
5. Android 仍未实现，只保留 DTO 与命令命名的未来兼容空间。
6. Alias 只保存稳定 selector，不保证目标一直 ready；截图等 artifact 动作会在执行前检查 ready 并返回明确错误。
