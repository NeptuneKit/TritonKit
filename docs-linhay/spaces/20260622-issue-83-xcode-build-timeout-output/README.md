# 20260622 Issue 83 Xcode Build Timeout Output

## 背景

GitHub issue #83 记录：真实 iOS 项目中 `triton xcode build --json` 和追加 `--timeout 600` 后，agent wrapper 只看到 `exit_code=143` 与空输出；等价裸 `xcodebuild` 可以成功。

## 范围

- 只修 `triton xcode build/settings/test/run` 共用的 Xcode host command streaming 输出与 timeout 证据。
- 不把裸 `xcodebuild` fallback 作为用户入口。
- 不改变 stdout 最终 JSON summary 合约。

## BDD 场景

### 场景一：timeout 传入 host command

Given agent 执行 `triton xcode build --timeout 600 --json`
When Triton 构造底层 `xcodebuild` host command
Then host command 使用 600s timeout
And timeout 失败时 error detail 包含配置的 timeout 与 stdout/stderr artifact path

### 场景二：JSON 模式不再长时间空输出

Given agent 使用 `triton xcode build --json` 执行长构建
When 底层 `xcodebuild` 仍在运行
Then Triton 在 stderr 输出机器可读 progress JSONL，包括 invocation、stdout/stderr sample、heartbeat 或 timeout summary
And stdout 仍保留最终 JSON summary/error，便于脚本解析

## 验收

- 新增测试证明 streaming host command honor `defaultTimeoutSeconds` 并保留 artifact paths。
- `swift test --package-path CLI --filter XcodeCommandTests` 通过。

