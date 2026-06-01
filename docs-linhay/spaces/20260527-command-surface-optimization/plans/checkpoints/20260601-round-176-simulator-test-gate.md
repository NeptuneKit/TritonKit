# Round 176 - simulator test gate baseline

## 目标

定义并固化“模拟器测试门禁”，让后续轮询在提交前有统一、可复跑、可升级的 simulator domain 验证入口。

## 变更

1. 新增脚本 `docs-linhay/scripts/verify-simulator-gate.sh`：
   - `quick`（默认）：
     - `swift test --package-path CLI --filter SimulatorAdvancedControlsTests`
     - `swift test --package-path CLI --filter DeviceCrossPlatformTests`
     - `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionTargetSelectorPlaceholdersStayCanonical`
     - `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionPlatformFlagsStayCanonicalAndFamilyAligned`
     - `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionTextPlaceholdersStayCanonical`
     - `docs-linhay/scripts/verify-ios-runtime-observe-smoke.sh`
   - `full`（需要 `TRITON_SIMULATOR`）：
     - 包含 `quick` 全部项
     - 加跑 `docs-linhay/scripts/verify-ios-webview-harness.sh`
2. 该门禁默认用于每轮主动提交前的 simulator 相关质量校验。

## 验证

- `docs-linhay/scripts/verify-simulator-gate.sh quick`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
