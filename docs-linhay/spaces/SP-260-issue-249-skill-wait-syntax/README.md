# SP-260-issue-249-skill-wait-syntax

状态：本地候选已实现；Python / public skill 打包通过，等待主控串行 Swift parser 验证与联合文档登记。关联 [GitHub #249](https://github.com/NeptuneKit/TritonKit/issues/249)，未提交或发布，issue 保持开放。

## 边界与 BDD

- 公开 `wait` 示例使用 `--text`，保留正式 `--device` alias；三个平台与 `--target` 等价形式都可由真实 parser 接受。
- 打包检查器拒绝完整 fenced 命令中的旧 positional 语法、未知选项和缺值；合法引用/占位符/续行通过。`wait` 参数快照经 Swift schema 测试核对，官方示例直接送入真实 `parseAsRoot`，测试不调用 `run()`。
- 影响层为公开 skill、打包检查器与 CLI parser 测试；无产品 runtime、版本、设备或服务操作。安装 CLI 的验证统一追加 `--timeout 0`，在设备发现前退出。

## 归属与验收

分支 `feat/SP-260-issue-249-skill-wait-syntax`；同名独立 worktree。主控拥有全局 space 索引、memory、Swift 验证槽、整合与远端动作。

[验收场景与验证记录](plans/20261102-validation.md)记录真实旧 CLI RED、官方例 GREEN、Python 回归及待完成门禁；fixture/parser 通过不代表设备 wait 运行验收。本任务修复语法，设备运行不属于影响面。
