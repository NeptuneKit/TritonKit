# 20260617 Issue 57 Xcode DerivedData Diagnostics

## 背景

Issue #57 反馈：`triton xcode build --jsonl` 在底层 `xcodebuild` 输出大量类似 `Stale file '<old-repo-path>/.triton/DerivedData/.../some-output-file' is located outside of the allowed root paths.` 的 stale DerivedData / outside-root-path 诊断并最终失败时，当前 TritonKit 只暴露泛化 `xcodebuild_failed` / `** BUILD FAILED **`，agent 需要继续人工翻 stdout/stderr artifact 才能判断恢复动作。

该问题属于 Xcode workflow takeover 的 CLI/agent-facing 诊断增强。TritonKit 仍以 `triton xcode` JSONL 与最终 summary / error envelope 为产品契约，不暴露 XcodeBuildMCP API，不新增 Node 依赖。

## 目标

1. 从 `xcodebuild` stdout/stderr 中识别 stale DerivedData outside-root-path 失败模式。
2. 在 `triton xcode build --jsonl` 的最终机器可读输出中结构化暴露诊断，而不是只依赖泛化 `xcodebuild_failed` 文本。
3. 诊断至少包含匹配数量、首批样例、恢复建议和 machine-readable `nextAction`。
4. 保持现有 Xcode JSONL envelope 向后兼容：新增字段应为可选字段，不破坏既有消费者。

## 范围

### 本次包含

- 新增或更新 focused Swift tests，覆盖 stale file outside-root pattern。
- 最小实现输出解析和 summary/error 诊断字段。
- 更新本 space README 记录验收场景与测试计划。

### 本次不包含

- 不执行真实 `xcodebuild` 大型项目回归。
- 不引入 XcodeBuildMCP、Node runtime 或 MCP tool 名。
- 不新增 Web/Wails UI。
- 不清理用户机器上的 `.triton/DerivedData`，只给出可执行恢复建议。
- 不运行 `docs-linhay/scripts/qmd-sync.sh`，由主控统一处理 qmd/memory 集成。

## BDD 验收场景

### 场景一：识别 stale DerivedData outside-root-path 输出

- Given `xcodebuild` stdout/stderr 中包含多条 `Stale file '<old-repo-path>/.triton/DerivedData/.../file' is located outside of the allowed root paths.`。
- When TritonKit 解析 Xcode action 输出。
- Then 生成 `kind=stale-derived-data-outside-root` 的诊断。
- And 诊断包含 `matchCount`。
- And 诊断包含首批 `samples`，每个 sample 包含 stale file path 与原始消息。
- And 诊断包含恢复建议，提示使用 fresh `--derived-data-path` 或清理 `.triton/DerivedData`。
- And 诊断包含 machine-readable `nextAction`。

### 场景二：失败 build summary 暴露结构化诊断

- Given `triton xcode build --jsonl` 底层 `xcodebuild` 非 0 退出。
- And stdout/stderr 中包含 stale DerivedData outside-root-path 输出。
- When 命令输出最终 summary 或错误 envelope。
- Then 输出仍保留 `xcodebuild_failed` 失败语义。
- And 输出包含 stale DerivedData 诊断字段。
- And agent 不需要再解析 `** BUILD FAILED **` 或整份 stdout/stderr artifact 才能得到恢复动作。

### 场景三：非匹配输出不产生误报

- Given `xcodebuild` 失败输出只包含普通编译错误或 `** BUILD FAILED **`。
- When TritonKit 解析 Xcode action 输出。
- Then 不产生 stale DerivedData 诊断。

## 测试计划

1. 先新增 `XcodeDiagnosticsTests` focused 单元测试并确认失败。
2. 实现解析器与可选 summary 字段后运行：

```bash
swift test --package-path CLI --filter XcodeDiagnosticsTests
```

3. 若模型字段影响 schema 或共享模型测试，再补跑相关 filter：

```bash
swift test --filter TKXcodeWorkflowModelsTests
```

4. 本 worker 不运行 `qmd-sync`。
