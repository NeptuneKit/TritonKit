# 20260520 Simulator Takeover

## 结论

本需求的核心不是“把所有 Apple 工具重新做一遍”，而是让 AI agent 在真实项目回归中只面对一个稳定入口：`triton`。底层可以调用 `xcrun simctl`、`xcodebuild`、`devicectl`、`xctrace`、`xcresulttool`，但命令发现、参数、错误、证据、回放和审计都必须收敛到 TritonKit 的 JSON 契约。

我的评估是：P0/P1 应优先解决真实回归已经频繁发生的问题，即 simulator/App 准备、deep link、App container、preferences、截图、权限、定位、媒体、证书、日志和 evidence。系统 UI 自动化、Xcode build/test、coverage、SPM、runtime 磁盘维护和 watch pair 都有价值，但不应进入首个实现切片。

## 背景

TritonKit 目前已经具备 embedded runtime 的 App 内观察和控制能力：

- 观察：`status`、`list`、`hierarchy`、`ax`、`geometry`、`screenshot`
- 控制：`find`、`tap`、`swipe`、`type`、`paste`、`clear`、`wait`、`assert`
- 回归：`capture`、`evidence`、`.tritonplan`、`replay`

真实项目回归仍会绕回宿主工具：

- `xcrun simctl openurl`：打开调试 deep link。
- `xcrun simctl get_app_container` + `plutil`：读取 App preferences。
- `xcrun simctl privacy/location/ui/status_bar`：准备系统环境。
- `xcrun simctl io screenshot/recordVideo`：采集 framebuffer 证据。
- `xcrun simctl spawn ... log stream`：读取 simulator 日志。
- `xcodebuild` / `xcresulttool`：构建、测试和结果汇总。

这会让 agent 在 `triton` JSON 契约和裸 Apple CLI 之间来回切换，结果不可发现、不可审计，也难以写入 `.tritonplan`。

## 参考

- 前置调研：`docs-linhay/spaces/20260520-xcrun-host-adapter-research/README.md`
- 技术设计：`docs-linhay/spaces/20260520-simulator-takeover/technical-design.md`
- XcodeBuildMCP 参考：`docs-linhay/references/xcodebuildmcp.md`
- Harness 参考：`docs-linhay/references/harness.md`
- ai-phone 参考：`docs-linhay/references/ai-phone.md`
- ai-phone emulator CLI：`docs-linhay/spaces/20260521-ai-phone-emulator-cli/README.md`
- Baguette 参考：`docs-linhay/dev/device-control-from-baguette.md`
- AI CLI 契约：`docs-linhay/dev/ai-cli-readable-control.md`
- Host adapter issue：`https://github.com/NeptuneKit/TritonKit/issues/11`
- Simulator takeover issue：`https://github.com/NeptuneKit/TritonKit/issues/12`

## 目标

1. **统一入口**：simulator 准备、App 生命周期、系统环境、host 证据、runtime 观察、回放和诊断都通过 `triton` 暴露。
2. **机器可读**：所有一次性命令输出 JSON；长任务输出 JSONL progress；错误稳定包含 `error.code`、`hint`、`nextAction`。
3. **可组合**：host-side 动作和 runtime 动作都能进入 `.tritonplan`，并由 `replay`、`capture`、`evidence` 编排。
4. **可审计**：每个 host action 记录底层工具、参数摘要、target、耗时、退出码和 artifact。
5. **可降级**：能力不可用时返回明确 unsupported，并给出 fallback，不伪装成功。
6. **边界清晰**：embedded runtime 继续只处理 App 内 DEBUG-only 能力；host adapter 只运行在 macOS CLI / `triton serve`。

补充参考 ai-phone 后，本 space 的 host-side action 还需要预留 `command ledger`、device readiness、lock 和 remote host agent 字段。即使 P0 只跑本机 simulator，也不要把 schema 写死为单机、单 target、无调度证据。

## 非目标

1. 不直接把 TritonKit 改成 XcodeBuildMCP 包装器。
2. 不在 iOS embedded runtime 内执行宿主命令。
3. 不首期承诺真机完整接管；真机走后续 `devicectl` 分期。
4. 不用 Web/Wails 先定义业务控制能力。
5. 不把系统弹窗点击伪装成 in-app tap。
6. 不把 runtime 磁盘删除、personalization、dyld cache 等维护命令放入默认回归路径。

## Target 模型

TritonKit 需要从单一 `triton:local` 扩展为可绑定的多层 target：

- `sim:<udid>`：一个 simulator。
- `sim:<udid>:app:<bundle-id>`：simulator 上的 App。
- `runtime:<target-id>`：已连接 TritonKit embedded runtime 的 App 进程。
- `triton:ios-simulator:<udid>`：由 iOS Simulator 内 embedded runtime 暴露的稳定 target id；`triton list --json` 同时返回 `simulatorUDID`，runtime 命令的 `--target` 可传该 id 或直接传 UDID。
- `host:<workspace>`：当前仓库/工作区的 host adapter session。

默认选择规则：

1. 只有一个 booted simulator 时，host-side simulator 命令可自动选择。
2. 只有一个 runtime target 时，runtime 命令保持当前自动选择。
3. App target 与 runtime target 可通过 bundle id 绑定时，`triton plan` 输出绑定关系。
4. 多个候选时返回 `ambiguous_target`，列出 candidates 和推荐参数。

## 验收场景

### 场景零：并行 simulator 的 embedded runtime 消歧

- Given 两个 iOS Simulator 同时运行同一个启用 TritonKit 的 App
- When 两个 App 都连接到同一个 `triton serve`
- Then `triton list --json` 返回两个 embedded runtime target，且每个 iOS Simulator target id 为 `triton:ios-simulator:<SIMULATOR_UDID>`
- When 执行 `triton ax --json` 或 `triton tap "筛选" --json` 且未显式传 `--target`
- Then 返回 `error.code=ambiguous_target`，不静默选择最后连接的 runtime
- When 执行 `triton ax --target <SIMULATOR_UDID> --json` 或 `triton tap "筛选" --target triton:ios-simulator:<SIMULATOR_UDID> --json`
- Then 命令只发送到对应 simulator 的 embedded runtime WebSocket

### 场景一：发现并选择 simulator

- Given 当前机器安装 Xcode 且存在可用 simulator
- When 执行 `triton sim list --json`
- Then 输出 `udid/name/runtime/platform/state/isAvailable/isBooted/source`
- When 执行 `triton sim use <udid> --json`
- Then 当前 workspace 记录默认 simulator

### 场景二：启动 simulator 并等待就绪

- Given 指定 simulator 处于 shutdown
- When 执行 `triton sim boot <udid> --wait --jsonl`
- Then 输出 boot progress
- And 最终 summary 返回 `ok=true,state=Booted`
- And 失败时返回 `simulator_boot_failed` 和 `nextAction`

### 场景三：安装、启动和终止 App

- Given 已构建出 `.app`
- When 执行 `triton app install --simulator <udid> --app <path> --json`
- Then 返回 bundle id、simulator udid、安装结果
- When 执行 `triton app launch --bundle-id <id> --json`
- Then 返回 launch ack 或 process id
- When 执行 `triton app terminate --bundle-id <id> --json`
- Then 返回终止结果

### 场景四：通过 deep link 准备业务状态

- Given 目标 App 已安装并响应调试 deep link
- When 执行 `triton app open-url <url> --json`
- Then 返回 `ok=true`
- And note 明确该结果只代表 URL 已提交给 simulator
- And `nextAction` 推荐使用 `triton wait/find/assert` 验证业务完成

### 场景五：读取 App container 和 preferences

- Given 目标 App data container 存在
- When 执行 `triton app prefs get --bundle-id <id> --key DEBUG-mock --json`
- Then 输出 value、type、plist path、container path
- And agent 不需要解析 `plutil` 人读输出

### 场景六：准备系统环境

- Given simulator 已 boot
- When 执行 `triton sim privacy grant photos --bundle-id <id> --json`
- Then 权限变更结果进入 JSON envelope
- When 执行 `triton sim location set 31.2304,121.4737 --json`
- Then simulator 定位被设置
- When 执行 `triton sim ui appearance dark --json`
- Then 外观设置成功并可读取当前值

### 场景七：准备媒体、联系人、证书和固定 sandbox

- Given simulator 已 boot
- When 执行 `triton sim media add <path>... --json`
- Then 照片、视频、Live Photo 或 vCard 联系人被导入
- When 执行 `triton sim keychain add-root-cert <cert> --json`
- Then 证书被加入信任根或 keychain
- When 执行 `triton app data install --xcappdata <path> --confirm --json`
- Then App container 被替换，并在结果中明确记录 App 会被终止

### 场景八：处理系统弹窗边界

- Given App 触发 SpringBoard / CoreSimulatorBridge 系统弹窗
- When 执行 `triton ax --json`
- Then embedded runtime 可返回 `runtime_ui_interrupted`
- When 执行 `triton host ui snapshot --json`
- Then host adapter 返回系统 UI 快照
- When 执行 `triton host ui tap --text 允许 --json`
- Then 结果标记 `runtimeScope=host-ui`，不混同于 embedded runtime tap

### 场景九：采集 host-side 证据

- Given simulator 已 boot
- When 执行 `triton sim screenshot --output <png> --json`
- Then 写出 framebuffer 截图并返回 metadata
- When 执行 `triton sim record --output <mov> --duration 10 --jsonl`
- Then 输出开始、结束和文件路径事件
- When 执行 `triton logs stream --bundle-id <id> --jsonl`
- Then 输出结构化日志行，并可通过 SIGINT 收敛为 summary

### 场景十：完整 evidence 与 replay

- Given simulator、App 和 runtime 已绑定
- When 执行 `triton capture --case login-smoke --include host --output <dir.tritonevidence> --json`
- Then evidence 包含 host simulator status、app info、host screenshot、runtime ax、runtime screenshot、日志摘要和 action trace
- When `.tritonplan` 包含 `sim.boot`、`app.openURL`、`runtime.wait`、`app.prefs.get`、`sim.screenshot`
- And 执行 `triton replay <plan> --json`
- Then 每一步都有 JSON ack，任何 host-side 失败会停止后续 runtime assertion

## 分期

### P0：替代裸 xcrun 的最小闭环

- `triton sim list/use/boot/shutdown/screenshot`
- `triton app list/info/install/uninstall/launch/terminate/open-url/container/prefs`
- `schema/doctor/capabilities/plan` 暴露 host adapter 能力
- fake process runner 单元测试覆盖 argv 与 JSON 映射

### P1：真实项目回归准备闭环

- `sim privacy/location/ui/status-bar/push`
- `sim media add`
- `sim keychain add-root-cert/add-cert/reset`
- `sim pasteboard copy/sync`
- `sim icloud sync`
- `app data install`
- `.tritonplan` host steps
- `capture/evidence --include host`
- `logs stream --jsonl`

### P2：系统 UI 与高级调试

- `host ui snapshot/tap/type/swipe/press`
- 评估 WebDriverAgent 作为无 embedded runtime 的 iOS 黑盒输入 fallback；不作为 P0/P1 默认依赖
- 系统弹窗识别与推荐动作
- `sim record`、`sim diagnose`
- `sim env get` 与 `sim spawn launchctl setenv/unsetenv`
- `perf templates/record/export`

### P3：Xcode 开发工作流

- project/workspace/scheme discovery
- simulator build/test/run
- xcresult build/test result 汇总
- coverage 摘要和未覆盖行
- SwiftPM build/test/run
- project scaffolding

### P4：低频维护与多平台拓扑

- watch/iPhone pair、unpair、pair activate
- simulator clone、rename、upgrade runtime
- runtime add/delete/list/verify/match/dyld shared cache
- personalization manifest 管理

P4 默认不进入真实业务回归命令推荐；所有破坏性命令必须要求 `--confirm` 或 `.tritonplan` 中 `confirm: true`。

## 方案评估

### 方案 A：直接依赖 XcodeBuildMCP

优点是能力面广、已有 MCP/CLI 和 simulator workflow。缺点是引入第二套工具语义、Node 运行时和 MCP tool name，难以和 TritonKit 的 runtime、evidence、plan 统一。结论：作为参考和可选 bridge，不作为主路径。

### 方案 B：Triton 原生 host adapter 封装 Apple CLI

优点是保持 `triton` 单一产品契约，能最小化接入真实回归的 P0/P1，底层仍使用 Apple 官方 CLI。缺点是需要自己维护 adapter、schema 和测试。结论：主路径。

### 方案 C：直接调用私有 CoreSimulator / SimulatorKit

优点是潜在能力最强。缺点是签名、系统版本、稳定性和发布风险高。结论：只作为 P2+ 实验，不进入默认实现。

## 风险与约束

- `simctl` / `xcodebuild` 输出随 Xcode 变化：adapter 必须记录 tool version，并映射为稳定 error code。
- 多 simulator / 多 App / 多 runtime：默认选择必须谨慎，多候选返回 `ambiguous_target`。
- host UI automation 不等于 runtime input：所有结果必须标记 `runtimeScope`。
- `.xcappdata`、erase、uninstall、keychain reset、runtime delete 等破坏状态：必须显式确认。
- XcodeBuildMCP 能力面很广：TritonKit 首期只实现直接服务真实回归的命令，不追求一次性覆盖全部开发工作流。

## 完成定义

1. `triton schema --json` 可发现 P0/P1 host simulator/app 命令。
2. 常规回归文档不再需要直接调用 `xcrun simctl openurl/get_app_container/plutil`。
3. `.tritonplan` 能混排 host-side 和 runtime-side step。
4. `capture/evidence` 能同时记录 host artifact 和 runtime artifact。
5. 所有失败路径具备稳定 `error.code`、`hint` 和 `nextAction`。
