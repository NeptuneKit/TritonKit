# SP-260-issue-249-skill-wait-syntax

当前交付状态（2026-11-02）：十二项独立修复已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 发布，发布提交/tag 为 `026d329e5346fce77ae62a2828e3d27ed2d94c2e`；候选、main/tag/Release CI、双架构制品与安装验证通过。公开安装版三端 HTTP/浏览器预览及自有资源清理已完成；完整状态见 [SP264](../SP-264-release-v0-2-39/README.md)，不将发布等同于原私有现场恢复。

状态：已通过 [PR #256](https://github.com/NeptuneKit/TritonKit/pull/256) 合入远端 main，合并提交 `9c7cdb56470b6da7fd153f7671661972795640be`；前批联合主线 `572b4afb` 的必要 CI 已通过。#249 的机制修复和本轮自动验收已完成，已随 v0.2.39 发布并通过制品/安装验证；issue 保持开放。

## 边界与 BDD

- 公开 `wait` 示例使用 `--text`，保留正式 `--device` alias；三个平台与 `--target` 等价形式都可由真实 parser 接受。
- 打包检查器拒绝完整 fenced 命令中的旧 positional 语法、未知选项和缺值；合法引用/占位符/续行通过。`wait` 参数快照经 Swift schema 测试核对，官方示例直接送入真实 `parseAsRoot`，测试不调用 `run()`。
- 影响层为公开 skill、打包检查器与 CLI parser 测试；无产品 runtime、版本、设备或服务操作。安装 CLI 的验证统一追加 `--timeout 0`，在设备发现前退出。

## 归属与验收

分支 `feat/SP-260-issue-249-skill-wait-syntax`；同名独立 worktree。主控拥有全局 space 索引、memory、Swift 验证槽、整合与远端动作。

[首轮验收场景与验证记录](plans/20261102-validation.md)保留真实旧CLI RED、官方例GREEN、Python回归及当时待完成门禁；当前交付结果见顶部与SP264最终验收。fixture/parser 通过不代表设备 wait 运行验收。本任务修复语法，设备运行不属于影响面。

## 前批整合检查点（2026-11-02，历史证据）

- Python21项及public skill打包通过；PublicSkillCommandSchemaTests在最终完整CLI回归通过，直接解析官方示例并保留device/target alias。初次缺Space索引的docs失败已经联合登记后复验通过。
- 上述实现及本issue精确head CI通过后独立合并；当时联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 该历史检查点仅完成源码整合与自动验证；后续 v0.2.39 发布、公开制品、安装及三端预览已由[SP264](../SP-264-release-v0-2-39/README.md)完成，当前交付状态见顶部。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以顶部交付结论及SP264最终验收为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
