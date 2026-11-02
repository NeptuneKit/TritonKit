# SP-261-issue-250-leaf-option-parity

状态：已通过 [PR #255](https://github.com/NeptuneKit/TritonKit/pull/255) 合入远端 main，合并提交 `fbf7c2ff671df9e143f3ecbdb1c4f67628a2ba08`；最新联合主线 `572b4afb` 的必要 CI 已通过。#250 的机制修复和本轮自动验收已完成，待 v0.2.39 发布及安装复验；issue 保持开放。

## 边界与 BDD

核对 `sim.boot`、`act.tap` 的 CLI schema 参数、默认值和位置参数，并补齐 #245 路径身份反馈所需 `device.stop` 的真实参数与输出契约，不改动作执行或 #247 的 sideEffect 字段，不操作用户设备。Given 实际 parser，When 查询 full/compact schema，Then 三个范围内命令的公开参数与 parser 一致；`device.runner.stop` 与 `device.stop` 的完整身份保持可区分。详见 [BDD 与验证计划](plans/20261102-leaf-option-parity.md)。有限命令验收不代表全库 parser parity。

## 归属与验收

分支 feat/SP-261-issue-250-leaf-option-parity；worktree /Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-261-issue-250-leaf-option-parity。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和CI通过后已合并，issue保持开放。

已完成 `LeafOptionParityTests` 与 BDD、SP256 已验证二进制的实际进程 RED、最小 schema 修复。10 项缺失参数/默认值断言均失败，原始查询元数据和 help 见 [RED 证据](plans/20261102-red-evidence.json)。主控首次 focused Swift 为 142 tests / 1 issue：原 boot/tap parity 通过，stop 路径对照揭示缺失输出契约；[新增 RED](plans/20261102-stop-contract-red.json)保留日志 hash。已补 `HostDeviceStopOutput` 专属合同、stop 参数/default/confirmation 与 DTO/parser 测试，随后由主控复制冻结候选并重跑通过；只解析 argv、读取 schema/help 和编码 DTO，不运行 boot/tap/stop。该段原始RED和候选记录保留；当前已合并、未发布，全局索引/memory由主控收口。

## 主控初次整合记录

整合分支 codex/integrate-sp261 基于main3374e41a，实际CLI四查询已通过：sim.boot默认60/1、act.tap宽高、device.stop专属输出与两种stop身份。初轮142测试1失败揭示device.stop元数据缺失，已修订并保留测试；当时第二轮测试仍执行；后续144项focused与完整回归GREEN后才合并。docs/skill门禁通过，无设备动作。

## 主控最终整合检查点（2026-11-02）

- 首次142项focused测试揭示device.stop专属输出契约缺失；补齐后144项focused回归通过，实际CLI四查询确认sim.boot的60/1默认、act.tap宽高、device.stop输出及两种stop完整身份。未运行任何boot/tap/stop动作。
- 上述实现及本issue精确head CI通过后独立合并；最新联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 当前仅完成源码整合与所述自动验证；v0.2.39尚未发布，双架构资产、Homebrew、public skills安装与包外浏览器验收由[SP264](../SP-264-release-v0-2-39/README.md)继续收口。后续发布结果以该Space实际记录为准，不将本检查点解释为已发布。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以上方整合检查点为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
