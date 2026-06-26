# 20260520 Xcrun Host Adapter Research

## 背景

真实项目回归中，AI agent 已经能通过 TritonKit runtime 读取 AX、截图和执行 in-app 控制，但仍会在准备环境、切换状态、验证宿主侧文件时直接调用 `xcrun simctl`。典型链路包括：

- `xcrun simctl openurl <udid> <deeplink>`：触发 App 内部调试路由。
- `xcrun simctl get_app_container <udid> <bundle-id> data`：定位 App data container。
- `plutil -p <container>/Library/Preferences/<bundle-id>.plist`：验证环境、mock、账号等偏好状态。

这说明 TritonKit 当前的 CLI 覆盖了 embedded runtime 可观察/可控范围，但 host-side simulator/device adapter 还没有产品化入口。只要求 agent “优先用 Triton CLI”不够；CLI 必须提供同等或更高层、更可发现、更机器可读的能力。

## 目标

1. 盘点 `xcrun` 及其常用子工具中 TritonKit 可复用的能力。
2. 明确为什么其他 AI 会绕过 `triton` 直接使用 `xcrun`。
3. 定义首批 host-side adapter 的 CLI 方向，让 agent 不需要记忆裸 `simctl` 命令。
4. 评估 `SKProcessRunner` 是否适合作为 Swift CLI 内部执行 `xcrun` 的进程封装。

## 追踪

- GitHub issue：`https://github.com/NeptuneKit/TritonKit/issues/11`
- 后续主需求：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- 新增参考：`docs-linhay/references/serve-sim/`，EvanBacon/serve-sim，本地快照 `f94d57c`

## 当前定位

本 space 是 simulator takeover 的前置调研，不再作为独立并行方案推进。这里保留 `xcrun`、`simctl`、`devicectl`、`xcdevice`、`xctrace`、`xcresulttool` 和 `SKProcessRunner` 的调研结论；具体需求分期、target 模型、CLI 契约、plan/evidence 扩展和测试策略以后以 `20260520-simulator-takeover` space 为准。

`serve-sim` 作为下期参考项目进入需求池：只吸收 host-side Simulator streaming、normalized input、permission、camera injection 和 agent skill 的能力设计；不复制其 Web preview 作为业务控制入口，不引入 npm runtime 作为 Triton CLI 的默认依赖。

## 本机环境

- Xcode：`Xcode 26.5`，Build `17F42`
- Developer dir：`/Applications/Xcode.app/Contents/Developer`
- `xcrun`：version `72`
- SDK：iOS / iOS Simulator / macOS / tvOS / watchOS / visionOS / DriverKit 26.5 系列

## xcrun 本身的定位

`xcrun` 不是单一业务工具，而是 Xcode active developer directory 下工具的定位和执行入口。它能按 SDK、toolchain 查找工具路径，并执行对应工具。

可直接用于 TritonKit 的基础能力：

- `xcrun --find <tool>`：定位开发工具。
- `xcrun --sdk <sdk> --show-sdk-path`：查询 SDK 路径。
- `xcrun --show-sdk-version` / `--show-sdk-build-version`：查询 SDK 版本。
- `xcrun --kill-cache` / `--no-cache`：处理工具查找缓存。

TritonKit 真正应封装的是 `xcrun` 后面的工具能力，而不是把 `xcrun` 作为用户需要理解的抽象。

## 可复用能力盘点

### simctl：Simulator 控制主入口

高优先级：

- 设备生命周期：`list`、`boot`、`shutdown`、`erase`、`create`、`clone`、`delete`。
- App 生命周期：`install`、`uninstall`、`launch`、`terminate`、`openurl`、`appinfo`、`listapps`。
- App 数据：`get_app_container`、`install_app_data`。
- 画面证据：`io screenshot`、`io recordVideo`、`io enumerate`。
- 环境准备：`privacy grant|revoke|reset`、`location set|start|clear|run`、`ui appearance|content_size|increase_contrast`、`status_bar override|clear`。
- 文本与剪贴板：`pbcopy`、`pbpaste`、`pbsync`。
- 通知：`push`。
- 日志和进程：`spawn <device> log stream ...`、`diagnose`、`logverbose`。

对 TritonKit 的价值：

- 补齐 embedded runtime 做不到的宿主侧动作，例如 deep link、App 安装、数据容器读取、系统权限和系统 UI 状态准备。
- 让回归脚本可以在一个 `triton` JSON 契约里完成“准备环境 -> 操作 App -> 读取状态 -> 采集证据”。

### devicectl：CoreDevice / 真机控制入口

`devicectl` 支持 JSON 输出到文件，并明确标准输出只供人读，不保证稳定。这个约束和 TritonKit 的机器可读契约一致，适合作为真机 host-side adapter 的基础。

可复用能力：

- `list devices`：列出 CoreDevice 可见设备。
- `device install app` / `device uninstall`：安装与卸载。
- `device process launch|terminate|suspend|resume|signal|sendMemoryWarning`：进程控制。
- `device info apps|details|displays|lockState|processes|files`：设备与 App 状态读取。
- `device copy to|from`：文件拷贝。
- `device sysdiagnose`：诊断包。
- `device orientation`：方向控制。
- `device notification`：Darwin notification。

首期不应承诺真机所有能力，但应在 schema 中暴露 `runtimeScope=host-device`、是否需要已连接设备、是否需要 unlock/trust/developer mode。

### xcdevice：设备发现与无线调试

可复用能力：

- `list`：列出设备和模拟器。
- `observe` / `wait`：等待设备出现，适合 CI 或人工插拔设备。
- `enable` / `disable` / `check`：无线调试开关状态。

这部分适合作为 `triton devices` 或 `triton host devices` 的补充发现层。

### xctrace：性能采集与 Instruments 能力

可复用能力：

- `list devices|templates|instruments`：查询可用设备、模板和 instruments。
- `record`：按模板采集 trace。
- `export`：导出 trace 内容。
- `symbolicate`：符号化 trace。

本机标准模板包括 Time Profiler、Allocations、Leaks、SwiftUI、Swift Concurrency、App Launch、Network、Power Profiler、Animation Hitches 等。适合后续 `triton perf record --template "Time Profiler"`，但不是首批阻止 agent 使用裸 `xcrun` 的关键路径。

### xcresulttool：Xcode 结果包解析

可复用能力：

- `get test-results`：读取测试结果摘要与失败信息。
- `get build-results`：读取构建结果、警告和 issue。
- `get log`：读取 build/action/console log。
- `metadata`、`merge`、`compare`：结果包元数据、合并和对比。

适合服务于 CI / 回归报告汇总，和 App 实时控制链路关系较弱。

## 为什么其他 AI 没有先用 Triton CLI

核心原因不是 agent 偏好 `xcrun`，而是 TritonKit 暂时没有为这些动作提供同等入口：

1. **能力缺口**：现有 `triton` 强在 runtime 内的 `status/list/ax/find/tap/type/wait/assert/evidence/capture`，但没有 `openurl`、`get_app_container`、preferences 读取、App 安装、系统权限、location、status bar 等 host-side 命令。
2. **schema 不可发现**：`triton schema --json` 没有声明“deep link launch 属于 unsupported / planned / host-side adapter”，agent 看到需求只能自行寻找 `simctl`。
3. **状态准备不在 Triton 闭环内**：切 mock、切环境、切账号这类动作常通过 App deep link 或 App Group / Preferences 完成；如果 CLI 没有高层命令，agent 会复制项目文档里的裸命令。
4. **验证信号不统一**：`simctl openurl` 无输出，`get_app_container` 输出路径，`plutil` 输出人读 plist；agent 需要自己解释成功/失败，TritonKit 没有提供统一 `{ok, command, target, artifacts, error}` envelope。
5. **文档示例反向强化**：真实项目文档里已经存在 `xcrun simctl openurl` 示例；在没有 Triton 替代命令前，其他 AI 会合理地照抄这些路径。

因此正确修复不是单纯要求“不要用 xcrun”，而是把这些动作吸收到 Triton CLI：底层仍可 shell out 到 `xcrun`，但用户和 agent 面对的是稳定的 `triton` 契约。

## 首批 CLI 方向

建议新增一组 host-side 命令，命名可在实现前再收敛：

### 设备与模拟器发现

```bash
triton host devices --json
triton host simulators --json
triton host boot <udid> --json
```

输出统一包含 `source=simctl|devicectl|xcdevice`、`udid`、`name`、`platform`、`runtime`、`state`、`isBooted`。

### Deep Link / URL 打开

```bash
triton app open-url 'dxy-dxyer://nativejump/test/switchEnv?env=dev' --device <udid> --json
```

底层可映射到 `xcrun simctl openurl`。输出至少包含 `ok`、`deviceUDID`、`url`、`bundleID?`、`launchedAt`、`note`。因为 `simctl openurl` 本身无业务 ack，CLI 应提示“只证明 URL 已交给 simulator，不证明 App 内路由完成”，并建议后续用 `triton wait/find/assert` 验证 UI 或状态。

### App Container 与 Preferences

```bash
triton app container --device <udid> --bundle-id cn.example.app --kind data --json
triton app prefs get --device <udid> --bundle-id cn.example.app --key DEBUG-mock --json
triton app prefs dump --device <udid> --bundle-id cn.example.app --json
```

底层可映射到 `simctl get_app_container` + plist 解析。输出必须是 JSON，不让 agent 解析 `plutil` 文本。

### 环境准备

```bash
triton app prepare --device <udid> --bundle-id cn.example.app --open-url <url> --wait-text <text> --json
triton sim privacy grant photos --device <udid> --bundle-id cn.example.app --json
triton sim location set 31.2304,121.4737 --device <udid> --json
triton sim ui appearance dark --device <udid> --json
```

`prepare` 可以作为复合命令或 `.tritonplan` step，把 host-side action 和 runtime assertion 串起来。

### 日志

```bash
triton logs stream --device <udid> --bundle-id cn.example.app --level debug --jsonl
```

参考 Baguette 经验，底层优先用 `xcrun simctl spawn <udid> log stream ...`，因为 Apple-signed `simctl` 的执行上下文比直接调用 CoreSimulator 私有能力更稳。

## SKProcessRunner 评估

仓库：`https://github.com/linhay/SKProcessRunner`

适合作为候选底座：

- SwiftPM library，Swift 5.9+，macOS 支持 `run` / `runSync`。
- 支持 executable path / `$PATH` 解析、cwd、env、stdin、stdout/stderr 捕获、流式输出、timeout、输出上限和截断标记。
- 支持长生命周期 `SKProcessPipeSession` 与 PTY session，可覆盖 `log stream`、`xctrace record` 这类持续输出命令。
- 错误模型包含 executable not found、non-zero exit、timeout、truncated 等，便于映射成 TritonKit JSON error。

注意点：

- Package.swift 当前是 Swift tools 5.8，README 写 Swift 5.9+；引入前需要确认与 TritonKit 当前 toolchain 和平台声明一致。
- TritonKit embedded runtime 不应依赖 host-side process runner；依赖只能放在 CLI / macOS host adapter 侧，避免 iOS runtime 产生无意义依赖。
- 如果只封装少量短命 `simctl` 命令，标准库 `Process` 也能完成；但考虑日志流、timeout、截断和后续 `xctrace`，统一用 SKProcessRunner 更利于维护。

## BDD 验收草案

### 场景一：agent 可通过 Triton CLI 打开 deep link

- Given 指定 simulator 已 boot，目标 App 已安装
- When 执行 `triton app open-url <url> --device <udid> --json`
- Then CLI 返回 `ok=true`
- And 输出包含 `deviceUDID`、`url`、底层工具 `simctl`
- And 文档明确该结果只证明 URL 已提交，业务完成需继续用 `triton wait/find/assert` 验证

### 场景二：agent 可读取 App preferences 验证环境状态

- Given 目标 App data container 存在
- When 执行 `triton app prefs get --device <udid> --bundle-id <bundle-id> --key DEBUG-mock --json`
- Then CLI 返回机器可读 value、plist path、container path
- And 不要求 agent 解析 `plutil -p` 人读文本

### 场景三：agent 可生成环境准备证据

- Given `.tritonplan` 包含 `open-url`、`wait`、`prefs-get` 三类步骤
- When 执行 `triton replay <plan> --json`
- Then 每一步输出 JSON ack
- And 最终 evidence 中能关联 host-side actions 与 runtime assertions

## 结论

`xcrun` 能力应成为 TritonKit CLI 的底层实现资源，而不是交给 agent 直接使用的默认接口。首批优先级应放在 `simctl openurl`、`get_app_container`、preferences JSON 读取、privacy/location/UI 准备、日志流这几类真实项目回归已经反复出现的动作。完成后，项目文档和 skills 应把裸 `xcrun` 示例替换为 `triton` 命令，只在 `triton` 返回 unsupported 或 schema 未覆盖时保留 fallback。
