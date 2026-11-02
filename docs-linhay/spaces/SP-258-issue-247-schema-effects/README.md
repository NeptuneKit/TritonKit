# SP-258-issue-247-schema-effects

当前交付状态（2026-11-02）：十二项独立修复已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 发布，发布提交/tag 为 `026d329e5346fce77ae62a2828e3d27ed2d94c2e`；候选、main/tag/Release CI、双架构制品与安装验证通过。公开安装版三端 HTTP/浏览器预览及自有资源清理已完成；完整状态见 [SP264](../SP-264-release-v0-2-39/README.md)，不将发布等同于原私有现场恢复。

状态：已通过 [PR #259](https://github.com/NeptuneKit/TritonKit/pull/259) 合入远端 main，合并提交 `2525f7472010e08cb4dc4b654f390d73974719f0`；前批联合主线 `572b4afb` 的必要 CI 已通过。#247 的机制修复和本轮自动验收已完成，已随 v0.2.39 发布并通过制品/安装验证；issue 保持开放。

## 边界与 BDD

影响层为 shared schema wire model 与 CLI 元数据。审计 act/app/sim/build 全部一层操作；缺失声明初始化或旧 JSON 解码为 unknown，只有显式审计的 reserved sim.type 保留 none。查询、输入、生命周期、文件落盘与构建分别声明潜在效果；混合命令提供带 scope 的条件元数据，未知参数不匹配只读条件。full/compact 与 JSON roundtrip 保留条件。BDD、字段理由及兼容边界见 [方案](plans/20261102-effects-contract.md)。

不改变 parser、执行确认、重试或动作授权。无需人工验收；只运行 schema 查询、parse-only 与模型回归，不操作设备或私有项目。

## 首轮证据与归属

既有 SP256 已验证 binary 的 act.tap/app.launch/sim.boot/build.harmony 查询仍返回 none；断言 exit 1 已保存在同级 archives/SP258/effects-red.log 与四份 before JSON。当时新测试 SchemaEffectsTests 共 5 个场景尚未编译运行；后续5项与完整回归均通过，见下方历史整合证据及顶部最终交付状态。

分支 feat/SP-258-issue-247-schema-effects；worktree ../TritonKit-worktrees/SP-258-issue-247-schema-effects。主控串行分配 Swift 槽与 Git 写操作。shared 模型变更要求完整 root/CLI 回归；主控负责独立审阅、CI、集成与发布。未重复实施 #245，仅按授权最小透传新增安全字段。

## 前批整合检查点（2026-11-02，历史证据）

- SchemaEffectsTests 全部5场景通过；58项声明覆盖、旧JSON unknown默认、条件/roundtrip/compact以及不放松确认语义均进入最终完整CLI回归。
- 上述实现及本issue精确head CI通过后独立合并；当时联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 该历史检查点仅完成源码整合与自动验证；后续 v0.2.39 发布、公开制品、安装及三端预览已由[SP264](../SP-264-release-v0-2-39/README.md)完成，当前交付状态见顶部。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以顶部交付结论及SP264最终验收为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
