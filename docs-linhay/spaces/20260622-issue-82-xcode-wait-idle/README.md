# 20260622 Issue 82 Xcode Wait Idle

## 背景

GitHub issue #82 记录了两个线上问题：

1. `triton xcode wait-idle --timeout 600 --json` 在内部 `ps` 探测固定 5s 超时时返回裸 `host_command_timeout`，没有体现 wait loop 的长 timeout 语义。
2. `triton xcode status` 把无关 SwiftPM provider 进程（例如 `swift-build --package-path Tools/TritonMLXProvider -c release --product triton-mlx-provider`）计入 Xcode active，导致真实 app build 结束后仍显示 busy。

## 范围

- 只修 `triton xcode status` / `wait-idle` 的 Xcode 进程诊断契约。
- 不新增裸 `xcodebuild` fallback。
- 不扩大到 Xcode build/test/run 行为。

## BDD 场景

### 场景一：无关 SwiftPM provider 不阻塞 Xcode status

Given host 上只有 `swift-build --package-path Tools/TritonMLXProvider ...` 进程
When agent 执行 `triton xcode status --json`
Then 输出 `active=false`
And `processes` 不包含该 `swift-build` 进程
And `summary.buildServiceCount=0`

### 场景二：Xcode build service 仍可被观测

Given host 上有 `XCBBuildService` 或 `SwiftBuildService`
When agent 执行 `triton xcode status --json`
Then 输出仍包含该 build service
And `summary.buildServiceCount` 反映 Xcode build service 数量

### 场景三：wait-idle 内部 ps timeout 只作为瞬时错误

Given `wait-idle` 的某次内部 process lookup 超时
When 后续轮询仍能获得 active Xcode 状态
Then `wait-idle` 继续按命令级 timeout 轮询
And 最终超时时返回 `xcode_not_idle` 与最近状态，而不是首个 `host_command_timeout`

## 验收

- 新增单元测试覆盖无关 `swift-build` 过滤。
- 既有 `wait-idle` transient timeout 测试保持通过。
- `swift test --package-path CLI --filter XcodeDiagnosticsTests` 通过。

