# 20260619 issue 66：Xcode 增量缓存可观测性

## 背景

线上 issue #66 反馈 `triton xcode build` 的增量构建 / 缓存行为不够清晰。当前默认使用 `.triton/DerivedData`，但 agent 不能从 JSON / schema / help 中明确判断该目录是否存在、是否预期复用增量缓存，以及清理策略是否应保留 DerivedData。

## 范围

- `triton xcode build/test/run/settings/use/status` 相关 CLI 输出与 schema。
- 共享 Xcode workflow JSON 模型。
- 不新增自动删除 DerivedData 行为；清理能力必须显式、可审计，默认保留缓存。

## 验收标准

1. `triton xcode build --jsonl` 最终摘要包含 `derivedDataPath` 和 `derivedDataCache`。
2. `derivedDataCache` 至少包含 `path`、`exists`、`cacheState`、`incrementalExpected`、`cleanupPolicy`、`guidance`。
3. `triton schema --command xcode --json` 暴露上述字段，并说明 `--derived-data-path` 是增量构建缓存路径，cleanup 默认保留。
4. 单元测试覆盖模型编码、cache 状态推导、action summary 和 schema 契约。
5. 不改变默认 `.triton/DerivedData` 路径，不隐式删除缓存。

## 验证

- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue66 --filter XcodeDiagnosticsTests`
- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue66 --filter SchemaFactSourceTests`
- 通过：`swift test --scratch-path .build/issue66-shared --filter TKXcodeWorkflowModelsTests`
- 待运行：`git diff --check`
- 待运行：`docs-linhay/scripts/check-docs.sh`
