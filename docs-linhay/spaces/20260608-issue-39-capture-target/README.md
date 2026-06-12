# Issues 39 and 44 - capture/evidence explicit target propagation

## 背景

GitHub Issue #39 与 #44 报告同根问题：多 iOS Simulator target 同时连接时，`triton capture --target <id>` 与 `triton evidence --target <id>` 的顶层 target 能正确解析，但嵌套采集 hierarchy、AX、screenshot、geometry、archive 时仍以 `triton:local` 或空 target 请求 runtime，最终被 server 判定为 `ambiguous_target` 并跳过 artifact。

## 目标

修复 evidence/capture 嵌套 artifact collector 的 target 透传。只要用户显式传入 `--target <id>`，所有 runtime artifact 请求都必须使用解析后的稳定 target id，不依赖单 target 自动选择。

## 范围

- 覆盖 `triton evidence --target <id>` 默认 include 中的 `hierarchy`、`ax`、`screenshot`。
- 覆盖 `triton capture --target <id>` 默认 include 中额外的 `geometry`、`archive`。
- 使用 fake server / fixture 做 CLI 单元测试，不依赖真实 Simulator。
- 不新增 Web/Wails UI，不改变 host/xcode read-only artifact 采集语义。
- #44 不单独拆 space；它与 #39 共享修复、测试和验收。

## BDD 场景

### 场景：多 target 下 evidence 嵌套 runtime artifact 使用显式 target

Given Triton server 返回两个已连接 iOS runtime target
And 用户选择 `triton:ios-simulator:SIM-2`
When agent 执行 `triton evidence --target triton:ios-simulator:SIM-2 --include list,hierarchy,ax,screenshot --output <dir> --json`
Then `/targets` 可以用于解析显式 target
And 后续 `hierarchy`、`accessibility`、`screenshot` 的 `/request` body 都包含 `target = triton:ios-simulator:SIM-2`
And evidence manifest 不应因 `ambiguous_target` 跳过这些 artifact

### 场景：多 target 下 capture 嵌套 geometry/archive 使用同一显式 target

Given Triton server 返回两个已连接 iOS runtime target
And 用户选择 `triton:ios-simulator:SIM-2`
When agent 执行 `triton capture --target triton:ios-simulator:SIM-2 --include list,geometry,archive --output <dir> --json`
Then `geometry` 请求使用 `triton:ios-simulator:SIM-2`
And archive 内部再次采集 `hierarchy`、`geometry`、`accessibility`、`screenshot` 时也使用 `triton:ios-simulator:SIM-2`
And manifest 中 `target.id` 等于 `triton:ios-simulator:SIM-2`

## 验收标准

1. 新增或更新 Swift 测试能在 fake 多 target server 上复现旧行为失败，并验证修复后通过。
2. `captureEvidenceBundle` 在 `list` include 先解析出 target 后，同步使用 target-scoped `TritonKitHTTPClient`。
3. hierarchy、AX、screenshot、geometry、archive 全部复用同一个 resolved target，不回退到 `triton:local`。
4. 至少运行相关 Swift 测试；若未跑全量门禁，交付说明中明确原因与风险。

## 2026-06-12 核验

- #39 与 #44 均由 `captureEvidenceBundle` 的 nested runtime artifact client 未继承 resolved target 引起。
- 已有本地 commit `6bc275c` 覆盖运行时修复、fake 多 target 测试、space 与 memory。
- `CLI/Package.swift` 当前未提交修改是 SwiftPM path dependency identity 的 worktree 测试支撑项：worktree 目录名不是 `TritonKit` 时，显式 `.package(name: "tritonkit", path: "..")` 才能让 `swift test --package-path CLI` 直接解析既有 `.product(..., package: "tritonkit")` 依赖。
