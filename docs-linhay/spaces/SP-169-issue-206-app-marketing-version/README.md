# SP-169：iOS App 营销版本（marketingVersion）与构建号（buildNumber）结构化输出

## 边界

- 对应 GitHub issue：#206 `[Feature] app info/list should expose marketing version (CFBundleShortVersionString) as a distinct structured field`
- 影响层：CLI `triton app info` / `triton app list` 的 iOS installed-app metadata DTO（`TKHostInstalledApp`）、agent-facing schema output contracts（`host.app-info` / `host.app-list`）、focused tests 与文档；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-169-issue-206-app-marketing-version/`
- 分支：`feat/SP-169-issue-206-app-marketing-version`
- 基线：`origin/main@8cc72765`
- 目标：iOS installed app 元数据同时返回 `marketingVersion`（`CFBundleShortVersionString`）与 `buildNumber`（`CFBundleVersion`）两个无歧义字段；保留 legacy `version` 字段用于兼容，并明确其映射到 build number（iOS）。

## 非目标

- 不连接、启动或修改真实 Simulator / 真机 / emulator；只用纯 DTO / output-contract / schema fixture 测试。
- 不改 Android / Harmony parser 语义：共享 `TKHostInstalledApp` 的新字段对 Android 仅自然落出（`buildNumber` 取当前 parser 写入的 `CFBundleVersion`，即 `versionName`；`marketingVersion` 为 nil），不新增 `versionCode` 解析。
- 不添加 HTTP/Web/Wails 表面；不触碰其他 worktree 或 main 仓库。
- 不把 `app list` / `app info` 的机器可读字段扩展用于 text 输出行（text 行保持 bundleID/type/name/path）。

## BDD 验收

### 场景 1：`triton app info --json` 返回无歧义版本字段

- Given Simulator 已安装 bundle 的 Info.plist 含 `CFBundleShortVersionString = "2.4.1"` 与 `CFBundleVersion = 42`
- When 执行 `triton app info --bundle-id <id> --json`
- Then `app.marketingVersion == "2.4.1"` 且 `app.buildNumber == "42"`，两个字段均存在且互不混淆。

### 场景 2：`triton app list --json` 每个 app 暴露同一组字段

- Given `simctl listapps` 的 OpenStep plist fixture 含上述两个键
- When 执行 `triton app list --json`
- Then `apps[]` 每项含 `marketingVersion`、`buildNumber` 与 legacy `version`。

### 场景 3：legacy `version` 保留并明确映射

- Given 同一 iOS bundle
- Then `version == buildNumber == "42"`（iOS 上 `version` 是 build number 的 legacy alias），文档与 schema 明确标注新消费方应改用 `marketingVersion` / `buildNumber`，`version` 视为 deprecated。

### 场景 4：schema output contract 暴露新字段

- Given `triton schema --command app --json`
- Then `outputContracts` 同时包含 `host.app-info` 与 `host.app-list`，其 fields 覆盖 `app.marketingVersion`、`app.buildNumber`、`app.version`（及 `apps[].*` 对应项），`list` / `info` subcommand 的 `outputSelectors` 覆盖这两个 selector。

## 验收命令

```bash
swift test --scratch-path .build/sp169-206-root --filter TKHostAdapterModelsTests
swift test --package-path CLI --scratch-path .build/sp169-206 --filter SchemaFactSourceContractTests
swift test --package-path CLI --scratch-path .build/sp169-206 --filter executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts
swift test --package-path CLI --scratch-path .build/sp169-206 --filter DeviceCrossPlatformTests
swift build --package-path CLI --scratch-path .build/sp169-206-release -c release --product triton
.build/sp169-206-release/release/triton schema --command app --json
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实 Simulator / 私有 App 不作为本次验收前置条件；Info.plist 解析以 OpenStep plist fixture 与 DTO/schema contract 验证，禁止设备状态操作。

## 当前状态

- 已完成（本地）：`TKHostInstalledApp` 新增 `marketingVersion`（`CFBundleShortVersionString`）与 `buildNumber`（`CFBundleVersion`）；legacy `version` 保持映射到 build number（iOS），并在代码注释、schema description、`outputSemantics` 与文档中明确 deprecated 指引。
- 修复既有 schema 缺口：`host.app-info` contract 此前已定义但从未挂到 `app` schema 的 `outputContracts`；本轮挂载 `hostAppInfoOutputContract()` 并新增 `hostAppListOutputContract()`（selector `host.app-list`），`list` / `info` subcommand 的 `outputSelectors` 相应覆盖。
- TDD red：新增 shared model 断言（`marketingVersion` / `buildNumber`）与 schema contract 断言（`host.app-info` / `host.app-list` 字段与 model）时，前者因模型缺少成员编译失败，后者因 contract 未挂载而断言失败；补入最小实现后全部转绿。
- focused 证据：`TKHostAdapterModelsTests` 42/42、root 全量 241/241（`.build/sp169-206-root`）、`SchemaFactSourceContractTests` 52 项仅剩 2 个既有基线失败（Xcode archive/export artifact taxonomy、`connectedCapabilityMap` 缺 `providedCapability`，均与本次无关，stash 对比确认）、surface contract 断言通过、`DeviceCrossPlatformTests` 101/101。
- release CLI：`swift build -c release --product triton` 通过；release `triton schema --command app --json` 的 `host.app-info` / `host.app-list` contract 包含 `marketingVersion` / `buildNumber` / legacy `version` 字段。
- 文档：`docs-linhay/spaces/SP-169-issue-206-app-marketing-version/README.md` 建立并登记 `INDEX.md` / `spaces/README.md`；`docs-linhay/memory/2026-08-11.md` 追加；`docs-linhay/dev/ai-cli-readable-control.md`、根 `README.md` 与 `tritonkit-host-simulator-takeover` skill 澄清 legacy `version` 映射。
- 风险：未连接真实 Simulator / 私有 App，Info.plist 解析仅以 fixture 验证；Android 侧 `buildNumber` 语义沿用共享 parser 的 `versionName` 映射，未做 `versionCode` 扩展。
- 共享文件冲突风险：`docs-linhay/spaces/INDEX.md`、`spaces/README.md` 与 SP-164～168 占位 README 与并行 worktree（SP-164～168）共享同一登记面，合入时可能 both-add 冲突，应以各 worktree 正式内容为准。
- 已评论并关闭远端 #206（合并提交 `5dbbdc90`，CI `31791782001` 全绿）；真实 Simulator 的 Info.plist 解析保留为后续设备验证。
