# Issue #65: Xcode Wait Idle Host Timeout

## 背景

GitHub Issue #65 反馈：真实 iOS App 工作流中，triton xcode build 正在运行且后续构建成功，但 triton xcode wait-idle --workspace <workspace>.xcworkspace --timeout 1800 --json 因内部 pgrep 进程查询 5 秒超时直接返回 host_command_timeout。

该失败不是构建失败，也不是用户指定的 wait timeout 到期，而是一次 host process lookup 的瞬时超时被当成最终结果。

## 目标

1. wait-idle 不应因为单次 pgrep / ps 查询超时就提前结束。
2. 如果后续 poll 能观察到 active xcodebuild，最终总 timeout 到期时应返回 xcode_not_idle，并包含 blocking PIDs。
3. 如果整个等待周期内始终无法获得任何 status，才保留底层 host_command_timeout。

## BDD 验收

### 场景：进程查询瞬时超时但构建仍活跃

- Given wait-idle 第一次 poll 的 pgrep 查询触发 HostCommandRunError.timeout
- And 后续 poll 能看到 matching workspace 的 active xcodebuild
- When 总 timeout 到期
- Then CLI 应返回 xcode_not_idle
- And 不应把第一次 pgrep 的 host_command_timeout 当作最终结果。

## 实现摘要

waitForXcodeIdle 将 HostCommandRunError.timeout 视为 transient poll failure，记录错误后继续等待到调用者 timeout。若期间拿到 lastStatus，最终按 lastStatus 返回 XcodeDiagnosticsError.notIdle；只有完全没有 status 时才抛出最后一次 transient timeout。

## 验证

- swift test --package-path CLI --scratch-path .build/cli-issue65 --filter XcodeDiagnosticsTests
- git diff --check
- docs-linhay/scripts/check-docs.sh

## 剩余风险

未在真实长时间 xcodebuild 上做 live smoke；本轮用诊断 runtime 单元测试锁定错误转换语义。
