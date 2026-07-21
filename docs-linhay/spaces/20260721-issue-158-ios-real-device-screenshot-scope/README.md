# GitHub Issue #158：iOS Real-Device Screenshot Scope

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#158](https://github.com/NeptuneKit/TritonKit/issues/158)
>
> Branch：`feat/20260721-issue-158-ios-real-device-screenshot-scope`
>
> Worktree：`../TritonKit-worktrees/20260721-issue-158-ios-real-device-screenshot-scope/`

## 背景

`triton screenshot --platform ios --device <ios-real-selector>` 当前把显式真机 selector 落入 Simulator 校验，最终返回泛化 `host_action_failed` 与 simctl-only recovery。相同 selector 已可用于真机 install/launch，因此 screenshot 必须在执行 host adapter 前明确区分 real/simulator scope。

## 范围

- 从统一 target inventory 解析显式 iOS 真机 selector，不再落入 simulator validator。
- 若现有 host adapter 可安全截图，则走 schema-backed 真机 capture；否则在执行 platform tool 前返回稳定、机器可读的 unsupported scope/capability。
- 对齐 `screenshot --help`、schema、capabilities、错误 code/hint/nextAction。
- 增加 ready `ios-real:*` selector 契约回归；不扩展 Web/Wails，不引入未声明的远端设备能力。

## BDD 场景

### 场景 1：显式真机 selector 不进入 Simulator 校验

- Given inventory 中存在 ready、connected、scope=real 的 iOS target
- When screenshot 使用该 selector
- Then 在 host action 前解析为 iOS real-device scope
- And 不返回 `Invalid device` 或 simulator UDID hint

### 场景 2：当前不支持真机截图时返回明确边界

- Given 已解析出 ready iOS real-device target
- And 当前 adapter 未暴露 screenshot capture
- When 执行 screenshot
- Then 返回稳定 unsupported code、scope 与 next action
- And help/schema/capabilities 明确该边界

### 场景 3：Simulator screenshot 不回归

- Given booted iOS Simulator selector
- When 执行 screenshot
- Then 继续走现有 simctl capture 与输出文件契约

## 验收门禁

- 先补 selector 与 command contract 失败测试并确认红灯。
- focused CLI tests、根包 `swift test`、release CLI build 与 local gate 通过。
- 保存 `triton status/doctor/capabilities/schema/plan` 与显式 selector 的机器可读前后证据；只有 schema 缺口明确时才使用平台工具探测。
- help/schema/capabilities、public skills、docs 与 memory 同步。

## 停止条件

三个场景、自动化门禁、机器可读证据、main 集成与线上 CI 全部满足后关闭 #158；确认线上 open issues 清零后发布下一 patch，不移动 `v0.2.13`。

## 实现与验收记录

- 当前 Xcode `devicectl device` 帮助面只有 copy/info/install/notification/orientation/process/reboot/sysdiagnose/uninstall，没有 screenshot/capture；因此本期选择明确 unsupported，而不是引入未验证第三方真机工具。
- `captureHostDeviceScreenshot` 在 ready 检查后、输出路径与平台工具执行前识别 iOS `scope=real` / `kind=real-device`，抛出专用边界错误；JSON 映射为 `unsupported_scope`、Simulator-only hint 与 `schema --command screenshot --json` nextAction。
- root `screenshot` 与 `device screenshot` help/schema 已声明 iOS host capture 只支持 Simulator；`device doctor --platform ios --scope real` 不再广告 `device.screenshot`，capabilities 分离 `ios-simulator-screenshot` 与 unsupported `ios-real-device-screenshot`。
- 失败测试先证明 real selector 会落入 simctl `Invalid device`；实现后同 selector 返回 `unsupported_scope` 且 exit=1。真实 booted Simulator 同时返回 `ok=true` 并写出 PNG，证明原路径未回归。机器可读证据保存于 `/private/tmp/triton-issue-158-baseline/` 与 `/private/tmp/triton-issue-158-green/`。
- release CLI 再验同样得到 real exit=1 / `unsupported_scope` / `nextAction.category=diagnose`，Simulator exit=0 且 PNG 非空；`ios-simulator-screenshot.supported=true`、`ios-real-device-screenshot.supported=false`。
- `docs-linhay/scripts/verify.sh --local` 全绿：根包 226 项、CLI release build/smoke、Harmony host smoke、iOS runtime observe smoke、docs/diff gate 均通过；public skill bundle 打包验证通过。
- 非标准 `/private/tmp` scratch 的 CLI 全量 662 项中，本次新增及受影响测试通过；整套仍有 43 个既有路径/schema/Harmony timing 基线 issue（其中多项因测试硬编码寻找 `CLI/.build` 下 binary），不把它们伪报为 #158 已修复。标准仓库门禁不依赖该非标准 scratch 布局。
- feature commit `ddf3fde6` 已通过 merge commit `a61ed5d7` 合入并推送 `main`；线上 CI run `29801150199` 全绿，完成评论留证后关闭 GitHub #158。
