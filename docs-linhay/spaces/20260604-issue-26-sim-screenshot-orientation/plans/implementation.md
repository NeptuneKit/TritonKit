# Issue 26 Implementation Plan

## 验收场景

Given 一个 iPad Simulator 已启动并可截图
When agent 执行 `triton sim screenshot --simulator <UDID> --output <png> --json`
Then 命令应成功写出 PNG
And JSON 输出应包含 `screenshot` metadata，明确当前 artifact 是 `raw-simctl-framebuffer` 语义
And metadata 应暴露 PNG `pixelWidth` / `pixelHeight`、`normalizationApplied` 与 `normalizationStrategy`
And schema contract 应声明 `host.simulator-screenshot-metadata`，避免 agent 将 raw framebuffer 当成 display-normalized screenshot

## 实现记录

- `HostActionOutput` 增加可选 `screenshot` metadata。
- `triton sim screenshot` 写出单个 artifact 时读取 PNG IHDR 宽高，并返回 metadata。
- 当前最小修复采用 `metadata-only` 策略，不对 PNG 做旋转归一化，避免在缺少可靠 display orientation 来源时产生二次误导。
- schema 的 `sim` 命令输出语义与 output contract 同步说明 raw framebuffer orientation。

## 验证

在 issue worktree 目录名不是 `TritonKit` 时，SwiftPM local package identity 会把根包识别成 worktree slug，导致 `CLI/Package.swift` 中 `package: "tritonkit"` 依赖解析失败。因此测试通过 `/tmp/tritonkit-issue26-copy/TritonKit` 临时副本执行。

已运行：

```sh
swift test --package-path /tmp/tritonkit-issue26-copy/TritonKit/CLI --filter DeviceCrossPlatformTests.simulatorScreenshotMetadataDocumentsRawFramebufferOrientationSemantics
swift test --package-path /tmp/tritonkit-issue26-copy/TritonKit/CLI --filter SchemaFactSourceTests.hostWorkflowSchemasExposeTargetAndArtifactContracts
swift test --package-path /tmp/tritonkit-issue26-copy/TritonKit/CLI --filter SchemaFactSourceTests.schemaOutputContractsExposeNonemptyFields
swift test --package-path /tmp/tritonkit-issue26-copy/TritonKit/CLI --filter SchemaFactSourceTests.schemaOutputContractKindsStayWithinAgentTaxonomy
swift test --package-path /tmp/tritonkit-issue26-copy/TritonKit/CLI --filter SchemaFactSourceTests.schemaOutputContractModelsStayMachineReadable
swift test --package-path /tmp/tritonkit-issue26-copy/TritonKit/CLI --filter SchemaFactSourceTests.schemaOutputContractSelectorsAndKindsUseStableAgentKeys
```

结果均通过。

## 剩余风险

- 本次没有实现图像旋转归一化；输出仍保持 `xcrun simctl io screenshot` 原始 framebuffer。该选择是为了先让 agent/evidence consumer 具备机器可读方向语义，后续若能可靠取得当前 display orientation，可另起需求实现归一化。
- 未在真实 iPad mini Simulator 上复测，因为当前任务收口以 CLI schema/model 单元测试为主。
