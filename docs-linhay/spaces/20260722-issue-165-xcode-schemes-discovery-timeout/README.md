# GitHub Issue #165：Xcode Schemes Discovery Timeout

## 状态

- GitHub：[#165](https://github.com/NeptuneKit/TritonKit/issues/165)
- 状态：已归档
- 交付分支：`main`
- 实现提交：`b3cdd40c`
- CI：[`29973762696`](https://github.com/NeptuneKit/TritonKit/actions/runs/29973762696)（通过）

## 背景

从仓库根目录执行 `triton xcode discover --json` 时，默认深度只扫描两层，可能返回 `ok=true` 但 project/workspace 为空；同一仓库中，已保存 container 的 `triton xcode schemes --json` 却能找到更深层 `.xcodeproj`，形成不一致事实。

`xcode schemes` 底层 `xcodebuild -list -json` 还固定 60 秒 host timeout。含 Swift packages 的真实项目可能在 scheme listing 阶段触发依赖解析并超过该时限；当前 CLI 没有 schemes 专用 timeout 参数，timeout hint 也只建议使用“command-specific timeout”，无法直接执行恢复。

## 目标

1. `xcode discover` 默认递归深度能覆盖常见 monorepo / nested app 布局，同时继续跳过 build、DerivedData、Pods、Carthage 与 node_modules 噪声目录。
2. `xcode schemes` 提供 schema-backed `--timeout-seconds`，调用方可覆盖固定 host timeout。
3. `xcode schemes` 可显式禁止自动 Swift package resolution，避免只读 scheme 枚举意外等待远端依赖更新。
4. schemes timeout 返回稳定错误码与可直接执行的 Triton `nextAction`，不要求 agent 回退裸 `xcodebuild`。

## 非目标

- 不改变 build/test/run 的既有 `--timeout` 契约。
- 不内置远端 package 下载或凭据处理。
- 不引入 XcodeBuildMCP 对外 API。
- 不扫描 `.build`、DerivedData、Pods、Carthage、node_modules 等生成目录。

## BDD 验收场景

### 场景一：默认 discover 找到深层 App container

- Given 仓库在 `apps/ios/Customer/App.xcodeproj` 存在有效 project
- When 执行 `triton xcode discover --path <repo> --json`
- Then projects 包含该 project
- And recommended container 与相同递归候选集一致
- And 生成目录中的伪 project 仍被忽略。

### 场景二：调用方覆盖 schemes timeout

- Given project scheme listing 需要超过旧固定 60 秒
- When 执行 `triton xcode schemes --project <path> --timeout-seconds 300 --json`
- Then host command 的 timeout 为 300 秒
- And schema/help 明确暴露该参数与默认值。

### 场景三：只读枚举可禁止自动 package resolution

- Given Xcode project 引用了 Swift packages
- When 执行 `triton xcode schemes --disable-automatic-package-resolution --json`
- Then `xcodebuild` argv 包含 `-disableAutomaticPackageResolution`
- And 不通过 shell 拼接参数。

### 场景四：timeout 提供机器可读恢复动作

- Given schemes host command 超时
- When CLI 输出 JSON failure envelope
- Then error code 为稳定 `xcode_schemes_timeout`
- And `nextAction` 指向 `triton xcode schemes --timeout-seconds 300 --disable-automatic-package-resolution --json`
- And schema failure codes 与 project recovery taxonomy 覆盖该错误。

## 验证计划

1. shared discovery / command builder、CLI 参数与 schema 测试先红。
2. 最小实现递归默认值、timeout override、package resolution flag 与 timeout recovery。
3. 聚焦运行 `TKXcodeWorkflowModelsTests`、`XcodeCommandTests` 与相关 failure/schema tests。
4. 使用 fake `xcodebuild` 验证 argv 和 timeout，不依赖真实 package 网络。
5. 权限恢复后独立提交、推送，等待 main CI 通过再关闭 #165。

## 环境记录

- 仓库约定的 `docs-linhay/scripts/create-space.sh` 当前不存在，本 space 按固定结构手工创建。
- 初始执行环境曾将 `.git` / `.agents` 设为只读，后续权限已恢复；本 issue 与 #164 按独立提交收口。

## 实现结果

- `TKXcodeProjectDiscovery.discover` 与 `triton xcode discover` 的默认 `maxDepth` 从 2 提升为 8；现有 `--max-depth` 仍可显式覆盖，生成目录排除规则保持不变。
- `triton xcode schemes` 新增 `--timeout-seconds`，默认 300 秒；非有限值或小于等于零会在 host command 启动前返回 validation failure。
- 新增 `--disable-automatic-package-resolution`，通过独立 argv 追加 `-disableAutomaticPackageResolution`，不经过 shell 拼接。
- scheme listing timeout 识别为 `xcode_schemes_timeout`；`nextAction` 保留原 `--workspace` / `--project`，package 模式保留 working directory，并提供至少 300 秒、或当前 timeout 两倍的 Triton 重试。
- xcode schema 已同步 `--max-depth`、schemes 专用参数、failure code、示例、subcommand optional options 与 project recovery taxonomy。

## 验证记录

- 红灯：shared Xcode command builder 因不接受 timeout/package-resolution 参数而编译失败。
- `TKXcodeWorkflowModelsTests`：20/20 通过，覆盖深层 project discovery、build noise 排除与 schemes argv/timeout。
- `XcodeCommandTests`：18/18 通过，覆盖参数解析、schema 与 timeout 边界。
- `FailureDiagnosticsTests`：12/12 通过，覆盖 `xcode_schemes_timeout`，并直接验证 workspace、project、package 三种 container 均被结构化恢复动作保留。
- `SchemaFactSourceContractTests`：50 项中 44 项通过；新增 xcode failure/recovery/schema 契约均通过，剩余 6 项是既有 `device` 与 `sim app-console` 契约债务。
- 权限恢复后的完整根 Swift 包：231/231 通过；此前 localhost sandbox `EPERM` 不再复现。
- 原样 `docs-linhay/scripts/verify.sh --local` 完整通过：SwiftPM dependency boundary、iOS DEBUG isolation、Swift tests、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs 与 diff 门禁均为绿灯。
- Triton-first fake-host smoke：先保存 status/doctor/capabilities/schema/plan；localhost status/doctor 受沙箱限制返回 `request_failed` / `EPERM`，离线 schema/plan 可用。随后 `xcode discover` 成功发现 `apps/ios/Customer/App.xcodeproj` 并忽略 `build/generated/Noise.xcodeproj`；`xcode schemes` 成功返回 `App`，sourceCommand/argv 包含 `-disableAutomaticPackageResolution`；0.05 秒 timeout smoke 稳定返回 `xcode_schemes_timeout` 与含原 project 的 nextAction。
- release 真实 Xcode smoke：`triton xcode discover --path . --json` 成功返回根 package、CLI package 与深层 reference/example containers；`triton xcode schemes --package Package.swift --timeout-seconds 300 --disable-automatic-package-resolution --json` 在约 3 秒内成功返回 `TritonKit`、`TritonKit-Package`、`TritonKitShared`，`sourceCommand` 明确包含 `-disableAutomaticPackageResolution`。
- README、AI CLI 控制文档、三个 public skill reference 与项目内部 `.agents/skills/tritonkit-xcode-workflow-takeover` 均已同步。
- 2026-07-23 复审：`XcodeDiscover.parse([])` 直接断言 CLI 默认深度为 8；workspace/project/package timeout recovery 与 18 项 `XcodeCommandTests`、12 项 `FailureDiagnosticsTests` 合并运行共 30 项全部通过。
- 实现由 `b3cdd40c` 推送到 `main`，GitHub CI `29973762696` 全绿后关闭 #165，本 space 完成归档。
