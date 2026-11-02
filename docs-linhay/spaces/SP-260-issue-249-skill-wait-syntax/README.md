# SP-260-issue-249-skill-wait-syntax

状态：已通过 [PR #256](https://github.com/NeptuneKit/TritonKit/pull/256) 合入远端 main，合并提交 `9c7cdb56470b6da7fd153f7671661972795640be`；最新联合主线 `572b4afb` 的必要 CI 已通过。#249 的机制修复和本轮自动验收已完成，待 v0.2.39 发布及安装复验；issue 保持开放。

## 边界与 BDD

- 公开 `wait` 示例使用 `--text`，保留正式 `--device` alias；三个平台与 `--target` 等价形式都可由真实 parser 接受。
- 打包检查器拒绝完整 fenced 命令中的旧 positional 语法、未知选项和缺值；合法引用/占位符/续行通过。`wait` 参数快照经 Swift schema 测试核对，官方示例直接送入真实 `parseAsRoot`，测试不调用 `run()`。
- 影响层为公开 skill、打包检查器与 CLI parser 测试；无产品 runtime、版本、设备或服务操作。安装 CLI 的验证统一追加 `--timeout 0`，在设备发现前退出。

## 归属与验收

分支 `feat/SP-260-issue-249-skill-wait-syntax`；同名独立 worktree。主控拥有全局 space 索引、memory、Swift 验证槽、整合与远端动作。

[首轮验收场景与验证记录](plans/20261102-validation.md)保留真实旧CLI RED、官方例GREEN、Python回归及当时待完成门禁；当前整合结果见下文。fixture/parser 通过不代表设备 wait 运行验收。本任务修复语法，设备运行不属于影响面。

## 主控最终整合检查点（2026-11-02）

- Python21项及public skill打包通过；PublicSkillCommandSchemaTests在最终完整CLI回归通过，直接解析官方示例并保留device/target alias。初次缺Space索引的docs失败已经联合登记后复验通过。
- 上述实现及本issue精确head CI通过后独立合并；最新联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 当前仅完成源码整合与所述自动验证；v0.2.39尚未发布，双架构资产、Homebrew、public skills安装与包外浏览器验收由[SP264](../SP-264-release-v0-2-39/README.md)继续收口。后续发布结果以该Space实际记录为准，不将本检查点解释为已发布。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以上方整合检查点为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
