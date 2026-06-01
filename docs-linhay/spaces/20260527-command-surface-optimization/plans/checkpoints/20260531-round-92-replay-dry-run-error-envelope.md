# Round 92: replay dry-run error envelope

## 目标

在 Round 91 的 replay step 静态 validation 基础上，补一层进程级 CLI 护栏：invalid `.tritonplan` 执行 `triton replay <file> --dry-run --json` 时，必须返回单个机器可读 JSON 错误 envelope，不能发生二次包装或多个 JSON 对象串联。

## Subagent 分工

- Hilbert（worker）：新增进程级测试，优先只写 `CLI/Tests/TritonKitCLITests/`，不改 runtime。
- 主控：复核测试 fixture、补临时目录清理、跑 CLI 全量验证、写回 docs / memory / qmd。

## 完成内容

1. 新增 `CLI/Tests/TritonKitCLITests/ReplayCommandTests.swift`。
2. 测试构造 invalid `.tritonplan`：`tap` 同时包含 `text` 与 `oid`。
3. 测试以真实 `triton` 可执行文件运行 `replay <file> --dry-run --json`。
4. 验收以下行为：
   - exit code 非 0。
   - stdout / stderr 只有一个非空流。
   - 非空流能解码为 `TKCLIErrorResponse`。
   - `ok == false`。
   - `error.code == "validation_failed"`。
   - `error.message` 包含 `Replay tap step requires exactly one selector`。
5. 主控补充临时目录 `defer` 清理，避免测试留下 plan 文件。
6. 当前实现已经满足目标行为，未修改 runtime。

## 验证

- `swift test --package-path CLI --filter ReplayCommandTests/invalidDryRunJSONReplayEmitsOneErrorEnvelope`：通过。
- `swift test --package-path CLI`：148 个 Swift Testing 用例通过。

## 风险

1. 测试需要定位 SwiftPM 构建出的 `triton` 可执行文件；测试中已支持 `TRITON_CLI_PATH` override，并从 test bundle / `.build` 搜索兜底。
2. 本轮只覆盖 ambiguous tap selector；后续可继续补 wait / paste / type 的进程级 invalid plan fixtures。

## 下一步

1. 按 Socrates 审计建议，优先推进 `plan-inspect` 作为一等 capability。
2. 继续补 replay dry-run invalid plan 的 step-level 诊断，避免 agent 只能从 message 中解析 step 问题。
