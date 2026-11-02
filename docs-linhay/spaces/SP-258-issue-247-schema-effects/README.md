# SP-258-issue-247-schema-effects

状态：已通过 [PR #259](https://github.com/NeptuneKit/TritonKit/pull/259) 合入远端 main，合并提交 `2525f7472010e08cb4dc4b654f390d73974719f0`；最新联合主线 `572b4afb` 的必要 CI 已通过。#247 的机制修复和本轮自动验收已完成，待 v0.2.39 发布及安装复验；issue 保持开放。

## 边界与 BDD

影响层为 shared schema wire model 与 CLI 元数据。审计 act/app/sim/build 全部一层操作；缺失声明初始化或旧 JSON 解码为 unknown，只有显式审计的 reserved sim.type 保留 none。查询、输入、生命周期、文件落盘与构建分别声明潜在效果；混合命令提供带 scope 的条件元数据，未知参数不匹配只读条件。full/compact 与 JSON roundtrip 保留条件。BDD、字段理由及兼容边界见 [方案](plans/20261102-effects-contract.md)。

不改变 parser、执行确认、重试或动作授权。无需人工验收；只运行 schema 查询、parse-only 与模型回归，不操作设备或私有项目。

## 首轮证据与归属

既有 SP256 已验证 binary 的 act.tap/app.launch/sim.boot/build.harmony 查询仍返回 none；断言 exit 1 已保存在同级 archives/SP258/effects-red.log 与四份 before JSON。新测试 SchemaEffectsTests 共 5 个场景，尚未编译运行；此时不宣称 GREEN。

分支 feat/SP-258-issue-247-schema-effects；worktree ../TritonKit-worktrees/SP-258-issue-247-schema-effects。主控串行分配 Swift 槽与 Git 写操作。shared 模型变更要求完整 root/CLI 回归；主控负责独立审阅、CI、集成与发布。未重复实施 #245，仅按授权最小透传新增安全字段。

## 主控最终整合检查点（2026-11-02）

- SchemaEffectsTests 全部5场景通过；58项声明覆盖、旧JSON unknown默认、条件/roundtrip/compact以及不放松确认语义均进入最终完整CLI回归。
- 上述实现及本issue精确head CI通过后独立合并；最新联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 当前仅完成源码整合与所述自动验证；v0.2.39尚未发布，双架构资产、Homebrew、public skills安装与包外浏览器验收由[SP264](../SP-264-release-v0-2-39/README.md)继续收口。后续发布结果以该Space实际记录为准，不将本检查点解释为已发布。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以上方整合检查点为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
