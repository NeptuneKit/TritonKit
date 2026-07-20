# GitHub Issue #155：iOS Simulator App Process Console Capture

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#155](https://github.com/NeptuneKit/TritonKit/issues/155)
>
> Branch：`feat/20260720-issue-155-ios-simulator-process-console`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-155-ios-simulator-process-console/`

## 背景

`triton sim logs` 当前通过 `simctl spawn <simulator> log stream` 采集 bounded unified log。Swift runtime 的 continuation misuse 等诊断可能只写入目标 App process stdout/stderr，因此 unified log artifact 成功并不代表已覆盖 process console。#155 需要一个明确区分来源、可限时、可审计的 Triton CLI 契约，避免 agent 回退裸 `simctl launch --console-pty`。

## 范围

- 为 iOS Simulator 增加 bounded App process console capture，显式接收 simulator、bundle id、duration 与 output。
- 通过 Triton host adapter 执行 `simctl launch --console-pty`，保留 source command、退出状态、bytes、truncation 与来源元数据。
- JSON/JSONL 契约明确 `sourcesCaptured`，区分 `unified-log`、`stdout`、`stderr`；不把 unified log 描述为 process console。
- 更新 CLI help/schema、README、agent 控制文档、public emulator/real-project/dev-feedback skills 与 memory。

本期不做：真机 console/debugger attachment、LLDB、持续无界日志、Web/Wails UI、私有 App 内容上传、把既有 `sim logs` 静默改成 launch-and-capture。

## BDD 场景

### 场景 1：bounded process console 成功

- Given 一个 ready iOS Simulator 与已安装的 Debug App
- When agent 通过 Triton 请求 App process console，并提供 bundle id、duration、output
- Then Triton 以 bounded `simctl launch --console-pty` 执行并在 deadline 后结束 capture
- And 返回单个机器可读成功 envelope，包含 artifact path、bytes、duration、source command、process exit/termination 信息
- And `sourcesCaptured` 明确只包含 `stdout` 与 `stderr`，不包含 `unified-log`

### 场景 2：unified log 来源不被误报

- Given agent 使用既有 `triton sim logs`
- When 查询 schema 或读取结果
- Then contract 明确该 artifact 的来源为 `unified-log`
- And 不声称覆盖 App stdout/stderr

### 场景 3：launch/capture 失败保持单一错误契约

- Given bundle 不存在、Simulator 未 ready、output 不可写或 host command 失败
- When 执行 process console capture
- Then stdout 仍是单个合法 JSON failure envelope
- And 返回稳定 error code、hint、source command 与可重试/恢复信息
- And 不留下被描述为成功的空 artifact

### 场景 4：敏感 console 不进入摘要

- Given process console 含业务数据或 runtime diagnostic
- When capture 完成
- Then JSON 只返回 bounded metadata 与 artifact path，不内联 console 正文
- And artifact 保持本机文件，文档要求公开 issue 前脱敏

## 验收门禁

- 先补 argv/output/schema/failure 测试并确认红灯。
- focused host adapter/CLI tests 与完整 `swift test --package-path CLI` 通过。
- release CLI build、schema/public skill package、`docs-linhay/scripts/check-docs.sh` 与 `git diff --check` 通过。
- 真实 Simulator smoke 前保存 `triton status/doctor/capabilities/schema/plan` 事实；若现有 Triton schema 不覆盖 process console，保留 unsupported 证据后才允许用裸 `simctl` 建立 red baseline。
- 真实 smoke 至少证明 bounded 结束、artifact 非空、source metadata 正确，以及 stdout/stderr source 与 unified-log source 可区分。

## 停止条件

上述四个场景、自动化门禁、真实 Simulator 证据、文档/memory/public skill 写回全部满足，并将实现合入 `main`、关闭 #155。发布时创建下一 patch tag，不移动已发布的 `v0.2.12`。
