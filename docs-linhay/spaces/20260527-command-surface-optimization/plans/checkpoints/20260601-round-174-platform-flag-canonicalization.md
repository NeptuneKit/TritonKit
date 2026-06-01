# Round 174 - platform flag canonicalization

## 目标

新增 capability `nextAction --platform` 参数的规范化门禁，保证 agent 在跨平台能力中拿到稳定且可推断的平台语义。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityNextActionPlatformFlagsStayCanonicalAndFamilyAligned`。
2. 新增约束（覆盖 connected/disconnected/server-unreachable 三态）：
   - `--platform` 的值只能是 `ios` 或 `harmony`。
   - `harmony-*` capability 若声明 `--platform`，必须是 `harmony`。
   - `ios-*` capability 以及 `observe-ios` 若声明 `--platform`，必须是 `ios`。
3. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionPlatformFlagsStayCanonicalAndFamilyAligned`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
