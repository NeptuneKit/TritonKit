# Issue #66：Xcode 增量构建 cache 语义

## 背景

`triton xcode build` 已默认使用 repo-local `.triton/DerivedData`，但 agent 只能从参数或历史经验推断它是否代表 Xcode 增量构建 cache。Issue #66 要求把 DerivedData cache 语义提升为机器可读契约：agent 应能明确知道 cache path、当前是否存在、是否预期命中增量构建，以及 cleanup 不应默认删除 DerivedData。

## 目标

1. `triton xcode use/status/build/test/run/settings` 的 JSON/JSONL 输出暴露 DerivedData cache 信息。
2. `triton schema --command xcode --json` 和 CLI help/docs 明确：保留 `.triton/DerivedData` 才能复用 Xcode incremental build；cleanup 不应默认删除它。
3. 不改变 `wait-idle` 的等待/超时语义；它只可通过嵌套 status 继承同一份 cache 信息。

## 非目标

- 不新增清理命令。
- 不自动删除或迁移 DerivedData。
- 不回退到裸 `xcodebuild` 或 XcodeBuildMCP。
- 不引入 Web/Wails 产品入口。

## BDD 场景

### 场景 1：agent 写入 Xcode defaults 时获得 cache 指引

- Given agent 运行 `triton xcode use --workspace App.xcworkspace --scheme App --json`
- When Triton 保存 repo-local defaults
- Then JSON 输出包含 `derivedDataCache.path=.triton/DerivedData`
- And `derivedDataCache.exists` 反映当前路径是否存在
- And `derivedDataCache.incrementalExpected` 只有在路径存在时为 `true`
- And `derivedDataCache.cleanupPolicy=preserve-by-default`
- And guidance 明确保留该目录才有 Xcode incremental build

### 场景 2：agent 构建后能判断是否预期增量构建

- Given agent 运行 `triton xcode build --jsonl`
- When final `TKXcodeActionSummary` 输出
- Then summary 包含 `derivedDataPath` 与 `derivedDataCache`
- And cache state 为 `warm` 时 `incrementalExpected=true`
- And cache state 为 `empty` 时 `incrementalExpected=false`

### 场景 3：agent 诊断状态时不误删 cache

- Given agent 运行 `triton xcode status --json`
- When 当前没有 Xcode 进程
- Then 输出仍包含默认或已保存的 `derivedDataCache`
- And guidance 提醒 cleanup 不应默认删除 DerivedData

### 场景 4：schema/help/docs 可发现 cache 契约

- Given agent 运行 `triton schema --command xcode --json`
- Then `xcode.final` output contract 暴露 `derivedDataCache`
- And `--derived-data-path` option 描述说明 repo-local cache 与增量构建语义
- And README / agent-facing docs 同步给出保留 cache 的 guidance

## 验收

- 先新增失败测试覆盖 cache model、status output、action summary 与 schema contract。
- 最小实现通过 focused Swift tests。
- 运行 `git diff --check` 与 `docs-linhay/scripts/check-docs.sh`。
- 本地 commit，不 push、不 merge、不关闭 issue。

## 验证记录

- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue66 --filter XcodeDiagnosticsTests`
- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue66 --filter SchemaFactSourceTests`
- 通过：`swift test --scratch-path .build/issue66-shared --filter TKXcodeWorkflowModelsTests`
- 待集成后运行：`git diff --check`
- 待集成后运行：`docs-linhay/scripts/check-docs.sh`
