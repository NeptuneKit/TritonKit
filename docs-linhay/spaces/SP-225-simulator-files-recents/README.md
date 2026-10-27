# SP-225 — Simulator Files Recents 精确服务诊断

## 边界与来源

影响层为CLI只读resource features/doctor与search类别说明；现有doctor采用service-overrides-only边界，不证明Files UI可用或已经恢复。来源[simslim固定提交](https://github.com/MobAI-App/simslim/commit/d961aa6d4fff29ad4727b9c052d02066f378fd16)，MIT全文hash `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e`；由Triton现有模型独立实现，不复制Go实现。上游性能未经本地验证。

main缺口：features没有files-recents；spotlight同时要求searchd/searchtoold，不能代替searchd-only。search downside未提示Files/document picker Recents。SP-221读取重试已交付，不重复开发。

## BDD与验收

1. searchd disabled时doctor requires files-recents明确ok=false、disabledLabels仅searchd。
2. searchd enabled、searchtoold disabled时files-recents仍按服务覆盖健康，spotlight保持原判定。
3. features机器契约包含files-recents且只绑定searchd，search downside明确Files/document picker Recents；其它类别/managed labels/默认策略不变。
4. 非法requirement在读取前拒绝；空/缺失服务覆盖沿用既有含义，verificationBoundary仍service-overrides-only，不新增UI健康承诺。

先测试红，再最小实现与focused；独立主控复核candidate diff、focused、完整CLI及实际离线features JSON。合main后再跑完整CLI/docs三门禁。无shared core修改无需重跑root；不运行真实设备/上游/依赖安装或远端写入。

## 文件面与协作

执行仅拥有Sources/TritonKitCLI/CLISimulatorResourceCatalog.swift、CLI/Tests/TritonKitCLITests/SimulatorResourceCatalogTests.swift、SimulatorResourceInspectionTests.swift以及本space。必要schema/parser测试如需扩展先报告主控。源catalog sourceCommit保持原基线，不冒称整catalog更新；新增feature来源用独立注释或元信息说明。

主控为[SP-226](../SP-226-files-recents-integration/README.md)。共享索引、memory、adoption-state由root维护。branch feat/SP-225-simulator-files-recents；worktree ../TritonKit-worktrees/SP-225-simulator-files-recents。模型gpt-6.1-sol显式锁定；非独占仓库，不撤销WIP。共享测试scratch/提交串行，禁止stash。

## 当前状态

实现与 focused 验证完成，候选提交后冻结交 SP-226 独立审查；详细红绿命令、测试数量、源码与日志 hash 见[验证报告](plans/20261027-validation.md)。完整 CLI、main 合并及合后验证由主控串行安排。共享索引、memory、adoption-state 由 root 统一写回；未 push/tag/release。
