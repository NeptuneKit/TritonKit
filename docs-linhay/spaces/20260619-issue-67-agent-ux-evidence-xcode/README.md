# 20260619 issue 67：Agent UX evidence 与 Xcode ergonomics

## 背景

线上 issue #67 汇总了真实 iOS Simulator UI audit 中的 agent 体验问题，包括动画证据、screenshot 元数据、安全覆盖、Xcode status 日志进度、DerivedData cleanup 和 app action 后续建议。

## 已完成切片

首轮只处理第 2 点：host-side screenshot JSON 增加 artifact metadata。

纳入范围：

- `triton screenshot --device/--platform ... --json` 返回的 `HostDeviceArtifactOutput`。
- 写入 artifact 后计算 `bytes`、`width`、`height`、`sha256`、`capturedAt`。
- schema 暴露 `host.artifact` 输出契约，供 agent 直接读取截图质量与可比对 hash。

## 本轮追加切片

本轮继续从 #67 剩余反馈中选择低风险 UX 小切片，只处理无需长进程、无需真实视频采集、不会改写主业务流程的机器可读输出增强：

- `triton xcode status --json` 暴露最近 Xcode JSONL/build/test/settings 日志摘要：`stdoutLogPath`、`stderrLogPath`、`lastOutputAt`、`stdoutBytes`、`stderrBytes`。
- host app action 输出增加顶层 `suggestedCommands[]`，把 `hostAction.nextAction` 对应的后续验证命令转成 agent 可直接消费的字符串列表。

继续暂不纳入范围：

- `--burst` / `record-video`。
- `triton device/sim screenshot --auto-suffix` 或 `--overwrite` 安全策略。
- DerivedData cleanup 命令。

## 验收标准

1. host screenshot 输出包含 `bytes`、`width`、`height`、`sha256`、`capturedAt`。
2. PNG fixture 能解析出 1x1 尺寸并生成 64 位 SHA-256 hex。
3. `triton schema --command screenshot --json` 暴露 `host.artifact` 契约及新增字段。
4. 不改变现有截图写入与覆盖拒绝策略。
5. `xcode status --json` 在存在最近 Xcode artifact 日志时，输出可直接定位的 stdout/stderr log path、字节数与最近输出时间；无日志时保持字段为 `null`，不误报。
6. `HostActionOutput` 顶层暴露 `suggestedCommands[]`，默认与 `hostAction.nextAction` 对齐，便于 agent 在 app launch/open-url/terminate 等 host action 后直接进入 smoke/wait/assert/evidence 验证。

## 验证

- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue67 --filter SimulatorAdvancedControlsTests`
- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue67 --filter SchemaFactSourceSurfaceContractTests`
- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue67 --filter 'XcodeDiagnosticsTests|AppOpenURLFlowTests|SchemaFactSourceSurfaceContractTests'`
- 通过：`git diff --check`
- 通过：`docs-linhay/scripts/check-docs.sh`
