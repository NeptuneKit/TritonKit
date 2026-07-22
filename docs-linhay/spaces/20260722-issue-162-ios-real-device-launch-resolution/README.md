# GitHub Issue #162：iOS Real-Device Launch Resolution

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#162](https://github.com/NeptuneKit/TritonKit/issues/162)
>
> Branch：`feat/20260722-issue-162-ios-real-device-launch-resolution`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-162-ios-real-device-launch-resolution/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。本 issue 明确建立 iOS 真机 app lifecycle 的有限边界，不扩展到远端设备、设备云或 Web 控制面。

## 背景

显式 `ios-real:*` selector 在初始 offline/DDI-missing 状态下可被 `app install` 与 `app info` 动态建立 tunnel 后接受，但 `app launch` 在等价 live-device resolution 前返回 `target_not_found`。

## 范围

- 统一 real-device install/info/launch 对显式 selector 的 live tunnel/readiness 解析语义。
- launch 复用现有受测 resolver/service，不复制一条独立 selector 分支。
- 若 launch 确实需要更严格状态，返回一致、可操作的 readiness error，而不是错误的 `target_not_found`。
- 保持 devicectl argv、环境变量脱敏、sourceCommand 与 app lifecycle schema 契约。

## BDD 场景

### 场景 1：显式 selector 可经 live resolution 启动

- Given paired real device 初始 inventory 为 offline/DDI-missing
- And live resolver 可建立 tunnel 并返回 ready target
- When `app launch` 使用同一显式 selector
- Then 调用 devicectl launch 并返回 resolved target

### 场景 2：install/info/launch 解析一致

- Given 同一 selector 与同一 fake/live inventory sequence
- When 分别执行 install、info、launch
- Then 三者使用相同 target identity 与 readiness transition

### 场景 3：真实不可用时错误可操作

- Given tunnel 建立后仍无法得到 launch-ready device
- When 执行 launch
- Then 返回稳定 readiness/target error 与 next action
- And 不误报已启动或泄漏敏感 selector/environment value

## 验收门禁

- 先补 fake devicectl/resolver 失败测试并确认红灯。
- focused CLI tests、nested CLI full tests、release build 与本地门禁通过。
- 真机动作前保存 `triton status/doctor/capabilities/schema/plan`；只有 Triton 失败/unsupported 后才用 devicectl fallback，并保留脱敏证据。
- 同步 real-device app lifecycle 文档、相关 public skills、memory 与 space 索引。

## 停止条件

三个场景、自动化验证、可用环境下的脱敏真机 smoke、main 集成与线上 CI 全部满足后评论并关闭 #162。

## 实施记录

- 根因是 `hostDeviceDiscoveryScope` 仅在 request 已显式携带 `platform=ios` 时把 selector discovery 扩为 `.all`。`app install/info` 会注入默认 iOS 平台，而 `app launch --device ios-real:*` 在未传 `--platform` 时保留 nil，导致 iOS discovery 只枚举 Simulator 并在 devicectl 前误报 `target_not_found`。
- resolver 现在把无显式 platform 的 `ios-real:*` / `triton:ios-real:*` 识别为 iOS real-device selector，并进入与 install/info 相同的 live `.all` discovery；raw CoreDevice identity 只用于 host argv，公开 target 仍为 redacted stable selector。
- devicectl non-zero handling 现在读取配套 `--json-output` artifact。CoreDevice error 1011 / “unable to locate a device” 稳定映射为 `target_offline`，同时返回 category=`prepare-target` 的 `triton device wait-ready --platform ios --scope real --device <selector> --json` next action；既有 lock/trust/Developer Mode/DDI mappings 保持不变。
- 红灯：无 `--platform` 的 `HostDeviceSelectionRequest(device: "ios-real:abc123")` discovery scope 原为 nil；devicectl JSON 参数测试最初因 mapper 不支持 `jsonData` 编译失败。实现后 DeviceCrossPlatform 96 tests 与 AppOpenURLFlow 7 tests 通过。
- Triton-first facts 已采集并脱敏：status/doctor/capabilities/schema/plan 均可读，schema 暴露 `ios-real-app` 和 app lifecycle failure codes；当前 real-device inventory 全部为 offline/DDI-missing。修复后的 platform-less `triton target resolve <ios-real:*> --json` 成功解析 real-device。
- 真实 host user-entry smoke 使用不存在的测试 bundle id，确保不会启动业务 App：`triton app launch --device <ios-real-selector> --bundle-id dev.tritonkit.issue162.nonexistent --json` 已进入 devicectl，并返回 `target_offline` + structured `prepare-target` nextAction，而非 `target_not_found`。设备当前不可用，因此未宣称真实 App 启动成功；该结果覆盖不可用设备的 BDD 边界。
- README、agent 控制文档、app schema 与两个 public skill reference 已同步。
- nested CLI focused suites 已通过：`DeviceCrossPlatformTests` 96 tests、`AppOpenURLFlowTests` 7 tests。nested CLI 全量测试仍有 22 个既有环境/契约基线问题，其中 `SchemaFactSourceTests` 的 13 个失败已在未改动的 main 独立复现，另有 TestRecorder 对本机 target 状态的环境依赖；这些失败不由本 issue 引入，未纳入本次修复范围。
- 完整本地门禁通过：`git diff --check`、`check-docs.sh`、SwiftPM boundary、iOS DEBUG isolation、Swift 227 tests / 27 suites、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build 均成功。main 集成和线上 CI 待收口。
