# SP-262-issue-251-json-parser-errors

当前交付状态（2026-11-02）：十二项独立修复已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 发布，发布提交/tag 为 `026d329e5346fce77ae62a2828e3d27ed2d94c2e`；候选、main/tag/Release CI、双架构制品与安装验证通过。公开安装版三端 HTTP/浏览器预览及自有资源清理已完成；完整状态见 [SP264](../SP-264-release-v0-2-39/README.md)，不将发布等同于原私有现场恢复。

状态：已通过 [PR #257](https://github.com/NeptuneKit/TritonKit/pull/257) 合入远端 main，合并提交 `46b052f80b730c29c8d9f1d3bfac1cf69f3a8198`；前批联合主线 `572b4afb` 的必要 CI 已通过。#251 的机制修复和本轮自动验收已完成，已随 v0.2.39 发布并通过制品/安装验证；issue 保持开放。

## 边界与 BDD

影响层仅 CLI 入口与 schema 输出契约。显式 `--json`、`--format json` 或 `--format=json` 请求的 parse/validate 失败在 stdout 输出单个 JSON、stderr 为空、exit 64，且不运行 command；运行阶段原有 domain envelope 不二次包装。缺失参数、未知选项、额外参数、非法标量及组合校验分型，输出仅受信任命令/字段名称与计数，不回显参数值或原错误文本。help/version 保持传统成功输出；没有有效 JSON 请求时保留传统 parser 行为，单独非法 format 回退文本。`--` 后的字面量不作为输出请求。

BDD 与验证矩阵见[验收计划](plans/20261102-parser-contract.md)。不操作设备、服务或私有App；全部验收可由agent独立完成。安装版0.2.38的三个安全parser进程均exit64/stdout空，已保存[实际RED证据](plans/20261102-parser-red.json)；首轮生产修复和测试候选当时待主控Swift槽验证；新增Swift测试未在旧源码执行，RED来自已发布旧版真实进程。后续GREEN与整合证据见下文。

## 归属与验收

分支 feat/SP-262-issue-251-json-parser-errors；worktree `../TritonKit-worktrees/SP-262-issue-251-json-parser-errors`。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和CI通过后已合并，issue保持开放。

## 前批整合检查点（2026-11-02，历史证据）

- JSONParserFailureTests及实际子进程用例在最终完整CLI回归通过；保留传统人类提示，JSON使用静态受信任迁移hint，不回显秘密。旧测试stderr预期和测试bundle定位的真实失败已修正并复验。
- 上述实现及本issue精确head CI通过后独立合并；当时联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 该历史检查点仅完成源码整合与自动验证；后续 v0.2.39 发布、公开制品、安装及三端预览已由[SP264](../SP-264-release-v0-2-39/README.md)完成，当前交付状态见顶部。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以顶部交付结论及SP264最终验收为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
