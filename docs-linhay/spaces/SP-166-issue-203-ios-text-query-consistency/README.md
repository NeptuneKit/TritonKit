# SP-166：iOS embedded runtime 文本查询一致性

## 边界

- 对应 GitHub issue：#203 `[Bug] iOS embedded runtime text queries disagree with observe for the same AX text node`
- 影响层：CLI `act find` / `wait --text` 的 embedded-runtime 文本匹配与归一化、`verify text-exists` 同一 wait 文本族、共享归一化 helper、focused tests 与文档；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-166-issue-203-ios-text-query-consistency/`
- 分支：`feat/SP-166-issue-203-ios-text-query-consistency`
- 基线：`origin/main@8cc72765`
- 目标：同一显式 runtime target 上，`observe tree`/`observe current` 展示的可见/可用 AX 文本节点，必须能被 `wait --text` 与 `act find` 以同一归一化规则命中；`act find` 对“无匹配”必须返回结构化 not-found envelope 与非零退出，禁止“exit 0 + 空 stdout”。

## 非目标

- 不读取、启动或修改真实 Simulator、业务 App、embedded runtime 或 host HID 状态；纯 unit/contract/fixture 测试。
- 不改变 `observe` 使用的 AX tree 发现逻辑；`observe` 输出保持权威。
- 不新增 HTTP/Web/Wails 文本查询面。
- 不修改 `act find` 的参数解析/schema（避免与 #201 Harmony `--platform` 并行写入面冲突）；只改文本匹配/归一化与 not-found envelope 契约。
- 不扩大范围到 `node resolve`（保持精确匹配）与 semantic action selector（各有独立路径）。

## BDD 验收

### 场景 1：observe 展示的文本可被 wait/find 命中

- Given 同一 embedded runtime AX fixture（可见/可用文本节点：`登录`、`Complex harness: 1`、`Login`、`Café`）
- When `observe tree`/`observe current` 展示这些文本
- Then `wait --text` 以去空白、大小写折叠、diacritic 折叠与 substring 语义命中同一节点（targetOID 一致）
- And `act find` 以同一归一化命中同一节点

### 场景 2：visibility 规则共享

- Given AX fixture 含一个 `hidden=true` 的文本节点
- When 执行 `wait --text` 与 `act find`
- Then 两者都排除该节点
- And `observe` 仍列出该节点并携带 `hidden=true` 元数据（权威视图）

### 场景 3：`act find` 无匹配时禁止成功空输出

- Given `act find "<query>" --all --json` 且 runtime AX 中不存在该文本
- When 执行解析
- Then 不返回 `matchCount=0` 的成功 envelope，而是抛出结构化 `TKTapTargetResolutionFailure`（含 query/message/candidateCount/nearestCandidates/suggestedCommands）
- And CLI 错误映射为 `text_not_found` 并抛出 `ExitCode.failure`（非零退出）

### 场景 4：`act find` 命中时返回匹配

- Given runtime AX 中存在该文本节点
- When 执行 `act find "<query>" --all --json`
- Then 返回 `TapTargetResolution`，`matchCount >= 1`，`--all` 时 `candidates` 非空，JSON 输出非空

## 验收命令

```bash
swift test --disable-sandbox --filter TKTextMatchingTests
swift test --disable-sandbox --filter TKWaitModelsTests
swift test --package-path CLI --scratch-path .build/sp166-203 --filter IOSTextQueryConsistencyTests
swift test --package-path CLI --scratch-path .build/sp166-203 --filter InputOutputTests
swift test --package-path CLI --scratch-path .build/sp166-203 --filter FailureDiagnosticsTests
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实 Simulator/私有 App 不作为本次验收前置条件；文本一致性以共享 fixture 与 contract tests 验证，禁止设备状态操作。

> 注：`check-docs.sh` 的连续编号门禁（SP-001 起无空洞）在本 worktree 内唯一失败于 SP-164/SP-165 空缺——两者属于并行 worktree（#201 `SP-164-issue-201-harmony-act-find`、#202 `SP-165-issue-202-sim-tap-help-dimensions`），尚未合入本分支。除连续编号外，目录/README/索引链接/登记链接/数量/去重检查全部通过（164 目录 = 164 唯一 ID）；SP-164/SP-165 分支合入后登记表恢复连续，门禁自动通过。`git diff --check` 与其余 `--ci-docs` 门禁（version-stamping / skill-package / release-automation）均通过。

## 当前状态

- 已完成（本地）：共享归一化 helper `TKTextMatching.swift`（trim + case/diacritic fold + substring/exact 两种模式）落地 TritonKitShared；`wait --text`（`TKWaitFindTextMatch`）与 `verify text-exists`（`TKUIAssertEvaluate`）改走共享匹配；`act find`（`selectAXNodesByQuery`/`tapTargetCandidates`）改走共享匹配并排除 hidden 节点；deterministic test-run `match=exact` 显式保持 exact 模式。
- TDD red：新增 `TKTextMatchingTests` 先因 helper 不存在编译失败；`IOSTextQueryConsistencyTests` 归一化/visibility 断言首次 9 项失败，`act find` 无匹配契约测试先行通过（作为回归 pin）。
- focused green：共享 matcher/wait/assert 套件通过；`IOSTextQueryConsistencyTests` 4/4 通过；`InputOutputTests`/`FailureDiagnosticsTests` 回归无新增失败。
- 风险：未连接真实 Simulator 或私有 App；substring 语义使 `wait --text "1"` 之类短查询可能命中包含它的长文本，与 Android/iOS host wait 既有行为一致；远端 issue 未评论或关闭。

## 合并冲突风险

- `Sources/TritonKitCLI/CLIActionCommands.swift` 与 `CLISchemaActionCommands.swift` 未修改（#201 Harmony `--platform` 并行写入面）。
- `Sources/TritonKitCLI/CLITargetingRuntime.swift` 的 `selectAXNodesByQuery` 签名新增 `match` 参数（默认 `.substring`）；`CLITestRunRuntime.swift:741` 显式传 `.exact` 保持 deterministic test-run 语义，若 #201/#126 并行改动同一函数需三方协调。
