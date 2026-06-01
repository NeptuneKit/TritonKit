# Round 15 Schema / Capabilities Global Invariant

## 目标

把前几轮手工修补的 schema / capabilities 对齐，升级成全局测试不变量：任何 `triton schema --json` 暴露的 `providedCapabilities[]` 都必须能在 `triton capabilities --json` 的 matrix 中发现。

## 完成结果

- 新增 `SchemaFactSourceTests.schemaProvidedCapabilitiesAreDiscoverableInCapabilitiesMatrix`。
- 补齐 capabilities matrix 中缺失的 schema 能力：
  - host target / device selector：`host-device-selector`、`device-alias`、`device-current`、`device-resolve`、`ios-device`、`harmony-device`
  - host simulator：`host-simulator`、`sim-video`、`sim-logs`、`sim-diagnostics`、`sim-runtime`、`sim-runtime-maintenance`、`sim-device-maintenance`、`sim-personalization`、`sim-status-bar`、`sim-privacy`、`sim-location`、`sim-ui`、`sim-pasteboard`、`sim-push`
  - host app：`host-app`、`host-app-open-url-ready`、`host-app-open-url-snapshot`、`host-preferences`、`harmony-app`
  - Harmony action：`harmony-swipe`、`harmony-type-text`、`harmony-paste-text`、`harmony-press-key`
  - Xcode：`xcode-defaults`、`xcode-diagnostics`、`xcodebuild`
  - screenshot / semantic：`host-device-screenshot`、`ios-screenshot`、`semantic-action`
- 为新增能力补 `group`、`requiredBy`、`nextAction` 和 `evidence` 的默认 enrichment。

## 改动文件

- `Sources/TritonKitCLI/CLIRuntimeTransport.swift`
- `CLI/Tests/TritonKitCLITests/SchemaFactSourceTests.swift`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaProvidedCapabilitiesAreDiscoverableInCapabilitiesMatrix` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，12 个 Swift Testing 用例通过。

## 剩余风险

- 新增 matrix 项当前主要保证 agent 能发现命令面和恢复入口；具体 host tool 是否存在、target 是否 ready、bundle 或 simulator 是否有效，仍要由真实命令执行结果证明。
- `nextAction` 是推荐入口，不保证所有参数在具体项目里可直接成功。

## 下一步

Round 16 建议检查 `triton schema --command <name> --json` 的过滤输出与 README / public skills 中的 agent 首选路径是否完全一致，尤其是 `target -> plan -> execute -> wait/assert -> evidence -> replay` 的示例链。
