# SP-226 独立候选验收（2026-10-27）

## Requested

独立验收冻结候选 `46bbf1c95c919f9ac0c6bcc6bc0386f97179af4f` 的 Files Recents searchd-only CLI 诊断。保留原类别/labels/defaults、非法 requirement 读取前拒绝和 service-overrides-only；只写 SP-226，不改共享登记或 SP-225。

## Observed

审查 worktree `/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-226-files-recents-integration`；静态文档先提交 `84fbac0c`，整合精确执行候选后的测试 HEAD 为 `32fd37321acde93e4f15b559467a76340fc47c1e`。测试时 git status 干净，产品/CLI tests 与执行候选无差异；其后仅修改 SP-226 文档。环境 macOS 27.0.1 / 26A434、arm64、Apple Swift 6.4（swiftlang-6.4.0.34.1）。

变更仅生产 catalog + 两个测试文件 + SP-225 文档。新增 files-recents labels 精确为 searchd，search downside 提及 Files/document picker Recents；sourceCommit 仍为旧整 catalog SHA，局部采用来源单独注释，原 MIT 归属保留。inspector、读取、重试、mutation、默认策略和 parser 未变。

## Evidence

root 明确分配共享 scratch 独占后，以下命令均在本 worktree 串行运行；每次显式设置：

```bash
export TRITON_CLI_PATH=/Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build/debug/triton
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update --filter 'SimulatorResource(Catalog|Inspection|Command)Tests|SchemaFactSourceTests'
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update --filter FramebufferHelperTests
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update --filter FramebufferHelperTests.timedOutAndroidHelperIsNotAutomaticallyRelaunched
swift test --package-path CLI --scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build --no-parallel --disable-automatic-resolution --skip-update
```

- **红证据复核**：读取执行 worktree `.build/SP-225/20261027/red.log`，实际 SHA-256 为 `bb133ae8f1df6692626295a29867d031b2230ee18f2f19a397d103f77ee6b321`，与登记一致。8 XCTest 中 3 个新增场景因 unknownFeature(files-recents) 失败；8 Swift Testing 中数量断言与新增依赖测试共 2 issues。属于真实行为失败；红时旧源码状态来自执行日志/报告记录，未独立重新构造旧候选。
- **独立 focused 通过 exit 0**：10 XCTest + 132 Swift Testing，覆盖 catalog/inspection/command/schema。新增 searchd-disabled、searchtoold-only-disabled、missing override 均通过，既有非法/空 requirement 读取前拒绝覆盖保留。
- **首轮完整 CLI 失败 exit 1**：94 XCTest 通过；1528 Swift Testing 报 1 issue：FramebufferHelperTests.timedOutAndroidHelperIsNotAutomaticallyRelaunched 读取 marker invocations 时 NSCocoaErrorDomain 260（文件不存在）。原始失败保留于 full-cli.log，不算通过。
- **有限复核通过 exit 0**：未改动 framebuffer suite 11 项通过；精确单项 1 项通过；相同冻结产品第二轮完整 CLI 94 XCTest + 1528 Swift Testing 通过。两轮完整回归均有 3 项显式跳过：1 个真实 Simulator framebuffer 用例因未配置 owned Simulator 跳过，2 个 Real NetService 用例跳过；均不能当真实运行通过；重叠筛选和重跑计数不相加。
- **失败诊断边界**：候选未修改 CLIAndroidHarmonyFramebufferService.swift、CLIFramebufferHelper.swift 或 FramebufferHelperTests.swift。fixture 启动独立 Thread，captureTimeout=0.5，固定 sleep 1.5 后读取 helper 写入 marker；缺 marker 可能发生于 helper 启动前或未完成写入，但首轮无 per-process 启动时序/资源快照，无法归因。根因仍未知，不声称已修复、不扩大 timeout、不改无关代码；稳定复现需独立跟踪启动与 marker 时序。
- **实际离线输出通过 exit 0**：候选 debug/triton 的 `sim resource features` 与 `sim resource profiles` stdout 各为单 JSON、stderr 为空。Python 解析整个 stdout 并检查 features=25、唯一 files-recents 精确 searchd、原24个 id/name/labels 全量一致；categories=15、slimmable=168、managed=171、旧 catalogCommit 与 search downside 正确。另将基线 catalog 与候选逐段比对：类别/保护规则仅 downside 变化，managedLabels 派生与 resolve/desired/delta 源码完全一致。
- **显式 --json 失败 exit 64**：`triton sim resource features --json` 返回 Unknown option '--json'，stdout 空，已保留 features-jsonflag.stderr。该参数在基线 SimResourceFeatures 中也未声明；默认入口已输出 JSON。root 已裁决这是验收命令误写，实际默认 JSON 入口是本切片正确入口，不作为产品 gap；保留 exit64 及纠正证据，不扩改 parser。

候选二进制 SHA-256：`092c5e60e072e70c75895720cfe712e1323208e7d39eb3ba325c1fd18edeeab5`。共享缓存可被后续重建，hash 绑定本次产物。原始大日志/JSON 均留本 worktree ignored `.build/SP-226/20261027/`，root 清理 worktree 前须归档。

| 原始证据 | SHA-256 |
| --- | --- |
| `features-jsonflag.json` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `features-jsonflag.stderr` | `e1cd0a23331b6a88307fc026e79c96854ed206dc769b02e3d7345f4756932bfb` |
| `features.json` | `f01d4032e771a731535649bb4de7b685aa4c2416b31781d4c932bdeff0630b7f` |
| `features.stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `focused.log` | `77bcdba291f7cada1e6b01e27a9bceb76cbc8c90a83e73446c0c50b9e811f839` |
| `framebuffer-exact-recheck.log` | `cd1f908757d8ed423423e4255d77122f2823d84675ed679c77b7f44b170afd51` |
| `framebuffer-recheck.log` | `3b614ab4d26b5262351ebc13b91f4eb5d14d84c8794142ed5d7f3c890e3f11d7` |
| `full-cli-recheck.log` | `de2236b87901c5fcdf919f8aafe25e9af882bdb6b12e1709de65a02d9e911146` |
| `full-cli.log` | `ebfbe02a0d8d602e2d8ba77ab7bde9b872bbedde32b969cd501256bb47137f64` |
| `offline-validation.json` | `310a34d8af7ac19b61d296e38941e8408069e1e7ffc014970f3c5940466815d9` |
| `profiles.json` | `cf453125a9acd006e946b7b74c751fc4e8b52b595e73116fc2a85468e9c2be7e` |
| `profiles.stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `static-comparison.json` | `55d6ee0f100c11c19291d135cde9a39ee7ebef308927b6e5f99d1f30bf1c8db4` |

文档三门禁实际通过 exit 0：`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`（226 spaces）。原始文档日志 hash：

| 原始证据 | SHA-256 |
| --- | --- |
| `docs-verify.log` | `6b0a383d5118fb0e2cf2a07e5f31584fd90b81ec30f3ed93bf515e901d60fecc` |
| `docs-check.log` | `51a3684b45382c238600158845f0bc32a21da760d7998f557a75c99495506966` |
| `diff-check.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

## Gaps

原验收命令误加 `--json` 导致 exit64；经 root 裁决已纠正为现有默认 JSON 入口并通过，不作为产品缺口。首轮 framebuffer 非稳定失败根因未知，复跑绿色不消除历史失败。最终 main 整合、main 合后 full/docs、证据归档和会话/worktree 清理由 root 完成；当前不声明整体交付完成。

## Fixes made

仅写 SP-226 静态/独立审查文档和 README 导航；不修改无关产品或测试。没有依赖安装升级、设备/签名/DDI、第三方执行、远端写入、main 操作。

## Remaining risk

真实 Files/document picker UI 与 Simulator 均未运行，fixture 只证明 service-overrides-only。无 shared core 改动，未跑根 Swift 包或 local 总门禁。沿用候选绑定/共享缓存串行/失败不覆盖/真实验收分层规则；本轮未知失败已记入本 space 作为下一次可复现检查入口，共享 memory/索引由 root 收口，无新增跨任务规则。
