# SP-261-issue-250-leaf-option-parity

状态：主控 focused Swift 发现 device.stop 缺失契约后已最小补齐；新候选冻结，等待重跑 Swift 验证。关联 GitHub #250。

## 边界与 BDD

核对 `sim.boot`、`act.tap` 的 CLI schema 参数、默认值和位置参数，并补齐 #245 路径身份反馈所需 `device.stop` 的真实参数与输出契约，不改动作执行或 #247 的 sideEffect 字段，不操作用户设备。Given 实际 parser，When 查询 full/compact schema，Then 三个范围内命令的公开参数与 parser 一致；`device.runner.stop` 与 `device.stop` 的完整身份保持可区分。详见 [BDD 与验证计划](plans/20261102-leaf-option-parity.md)。有限命令验收不代表全库 parser parity。

## 归属与验收

分支 feat/SP-261-issue-250-leaf-option-parity；worktree /Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-261-issue-250-leaf-option-parity。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和 CI 通过后合并，issue 保持开放。

已完成 `LeafOptionParityTests` 与 BDD、SP256 已验证二进制的实际进程 RED、最小 schema 修复。10 项缺失参数/默认值断言均失败，原始查询元数据和 help 见 [RED 证据](plans/20261102-red-evidence.json)。主控首次 focused Swift 为 142 tests / 1 issue：原 boot/tap parity 通过，stop 路径对照揭示缺失输出契约；[新增 RED](plans/20261102-stop-contract-red.json)保留日志 hash。已补 `HostDeviceStopOutput` 专属合同、stop 参数/default/confirmation 与 DTO/parser 测试，等待主控复制冻结候选后重跑；只解析 argv、读取 schema/help 和编码 DTO，不运行 boot/tap/stop。未提交或发布，全局索引/memory 由主控收口。

## 主控整合

整合分支 codex/integrate-sp261 基于main3374e41a，实际CLI四查询已通过：sim.boot默认60/1、act.tap宽高、device.stop专属输出与两种stop身份。初轮142测试1失败揭示device.stop元数据缺失，已修订并保留测试；第二轮测试仍执行，合并前必须GREEN。docs/skill门禁通过，无设备动作。
