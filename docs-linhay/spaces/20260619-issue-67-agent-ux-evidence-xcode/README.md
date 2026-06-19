# 20260619 issue 67：Agent UX evidence 与 Xcode ergonomics

## 背景

线上 issue #67 汇总了真实 iOS Simulator UI audit 中的 agent 体验问题，包括动画证据、screenshot 元数据、安全覆盖、Xcode status 日志进度、DerivedData cleanup 和 app action 后续建议。

## 本轮切片

本轮只处理第 2 点：host-side screenshot JSON 增加 artifact metadata。

纳入范围：

- `triton screenshot --device/--platform ... --json` 返回的 `HostDeviceArtifactOutput`。
- 写入 artifact 后计算 `bytes`、`width`、`height`、`sha256`、`capturedAt`。
- schema 暴露 `host.artifact` 输出契约，供 agent 直接读取截图质量与可比对 hash。

暂不纳入范围：

- `--burst` / `record-video`。
- `--overwrite` / `--auto-suffix`。
- `xcode status` 活跃日志路径与 last output timestamp。
- DerivedData cleanup 命令。
- app action `suggestedCommands[]`。

## 验收标准

1. host screenshot 输出包含 `bytes`、`width`、`height`、`sha256`、`capturedAt`。
2. PNG fixture 能解析出 1x1 尺寸并生成 64 位 SHA-256 hex。
3. `triton schema --command screenshot --json` 暴露 `host.artifact` 契约及新增字段。
4. 不改变现有截图写入与覆盖拒绝策略。

## 验证

- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue67 --filter SimulatorAdvancedControlsTests`
- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue67 --filter SchemaFactSourceSurfaceContractTests`
- 待运行：`git diff --check`
- 待运行：`docs-linhay/scripts/check-docs.sh`
