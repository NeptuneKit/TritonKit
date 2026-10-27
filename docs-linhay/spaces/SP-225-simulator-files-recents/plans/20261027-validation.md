# SP-225 开发候选验证（2026-10-27）

## 候选与边界

- worktree：`/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-225-simulator-files-recents`；branch：`feat/SP-225-simulator-files-recents`；基线 `d0ef4e4503e46386e90c1645a94b3ce03762728c`。
- 环境：macOS 27.0.1 / 26A434，arm64；Apple Swift 6.4（swiftlang-6.4.0.34.1）。
- 只改 catalog、catalog/inspection 测试和 SP-225 文档。新增精确 `searchd` feature 和 search downside；catalogCommit/sourceCommit 保持 `6518ba7eab1123d7e1d7797b0e05f51043b42a5b`，新增来源 `d961aa6d4fff29ad4727b9c052d02066f378fd16` 由独立注释说明。
- 不改 inspector、服务读取、重试、mutation、默认策略或 managed labels；无设备动作、第三方代码执行、依赖安装或远端写入。健康仅代表 `service-overrides-only`，不证明 Files UI 恢复。

## 红绿证据

所有 Swift 命令均在上述 worktree 串行执行，使用已有 root 缓存，并显式绑定实际 CLI：

```bash
export TRITON_CLI_PATH=/Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build/debug/triton
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update --filter 'SimulatorResource(Catalog|Inspection)Tests'
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update --filter 'SimulatorResource(Catalog|Inspection|Command)Tests|SchemaFactSourceTests'
```

1. **红：exit 1**。仅先改测试，生产 catalog 仍为基线。XCTest 8 项运行，新增 3 项因 `unknownFeature("files-recents")` 失败；Swift Testing 8 项运行，feature 数量 24≠25 与新增依赖测试共 2 issues。真实行为失败，非编译失败或零测试。
2. **绿：exit 0**。最小 catalog 改动后，XCTest 10 项（inspection 8、既有 command/parser 2）和 Swift Testing 132 项（catalog 8、既有 SchemaFactSourceTests 124）全部通过。筛选集合有重叠，不累加为独立回归总数。
3. **离线 CLI：exit 0**。实际缓存二进制运行 `triton sim resource features`、`triton sim resource profiles`；用 JSON parser 确认 ok、25 features、精确 searchd-only、旧 catalogCommit 和 search downside 的 Files/document picker Recents。无需服务或目标发现。
4. **完整 CLI / local 总门禁：未执行**。主控指示本候选完成 focused 后冻结，由 SP-226 在共享 scratch 串行安排完整 CLI 与整合验收；无 shared core 改动，不重跑 root 包。真实 UI/服务恢复验收不在本切片范围。

## 文档门禁

- `docs-linhay/scripts/verify.sh --ci-docs`：通过，exit 0。
- `docs-linhay/scripts/check-docs.sh`：通过，exit 0，226 spaces registered。
- `git diff --check`：通过，exit 0。
- 最终报告写入后重复上述文档门禁与 diff 检查；不重复已通过的同源码候选 focused。

## 可核对 hash

原始编译/测试日志和离线 JSON 保存在本 worktree ignored `.build/SP-225/20261027/`，不把原始 warnings 纳入 tracked 文档。SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `Sources/TritonKitCLI/CLISimulatorResourceCatalog.swift` | `1bf60e90019ed8908022b5e626e850ba218cf59b056170c08ef258c6ced0100a` |
| `CLI/Tests/TritonKitCLITests/SimulatorResourceCatalogTests.swift` | `5afdf694f6aab04a1c14282277fea07642c593a5e803b8c0576db8fd9baf305b` |
| `CLI/Tests/TritonKitCLITests/SimulatorResourceInspectionTests.swift` | `09fa3d42901a9306fefef85fd6c0c27eb7b5ba3efea67f7f00fdb1abc2bad5ff` |
| `red.log` | `bb133ae8f1df6692626295a29867d031b2230ee18f2f19a397d103f77ee6b321` |
| `focused.log` | `396205f2aee38de9759993cff9b669ebc5b96cc42427977b28889589808e9a3e` |
| `features.json` | `f01d4032e771a731535649bb4de7b685aa4c2416b31781d4c932bdeff0630b7f` |
| `profiles.json` | `cf453125a9acd006e946b7b74c751fc4e8b52b595e73116fc2a85468e9c2be7e` |
| 缓存 `debug/triton` | `f759018545849d7f22169726b65a5742d662dff8674fcd4e968d4f6d8e805282` |

共享缓存后续可被主控重建；hash 绑定本次运行时产物，而非保证缓存永远不变。

## 治理回看与交接

沿用原权威的来源分层、精确依赖、service-overrides-only 与源码/运行证据分层规则；本轮无新增跨任务经验，不扩写 skill。实施与证据沉淀于本 space；共享索引、memory、adoption-state 由 root 维护。本地候选提交后冻结停止写入/测试并释放 scratch；尚未整合、发布或完成真实用户场景验收。
