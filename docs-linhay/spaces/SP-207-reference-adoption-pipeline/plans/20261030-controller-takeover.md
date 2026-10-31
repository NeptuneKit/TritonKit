# 2026-10-30 长期主控接管

## Requested

用户要求当前聊天接手原“追踪 iCTRL 参考项目”聊天。继承SP-207现有33仓追踪与本地采用闭环；不新增远端/设备操作授权。

## Observed 与 Evidence

- 原聊天：`01a139bf-ab78-7783-b37a-ed336be2ef38`；read_thread返回最近3轮因远端compact连接失败而中断。10月29日没有成功日检产物；最近成功完整检查为10月28日。
- 新主控：`01a18a91-f44e-7fd0-8e4b-c891b44377e0`。automation_update更新原`ictrl`成功，并重新读取automation.toml确认target_thread_id为新主控；保留heartbeat、ACTIVE、每天北京时间10:00、名称和原prompt，没有创建重复任务。原聊天保留为历史入口。
- 实际main：`30185dc277ed305483aa789cb2d8c8b06fa21fe4`；16条adoption任务均为local_merged，逐一执行merge-base --is-ancestor全部通过。已关闭执行/主控不重开。
- 主目录有SP-244未提交工作，另有其他issue/release工作区；这些不属于参考采用遗留工作，不清理、不合并、不提交。原始文件hash清单保存于`.build/reference-monitor/20261030/takeover-wip-sha256.json`。
- 当天执行33仓补查；变化与完整性结果见[日报](20261030-reference-update-report.md)，不把接管成功当作日检成功，不补写10月29日虚假成功时间。

## Gaps 与 Fixes made

- 原自动任务仍绑定故障聊天：已通过正式工具迁移并读取确认。
- 旧finalize脚本硬编码历史版本/无待办结论且要求prior.complete，可能把旧partial永久锁住；本轮未运行旧finalize。恢复必须按缺口和本轮证据判断，不凭历史complete布尔值拒绝恢复，也不因成功取到新文本消除旧来源缺口。该检查规则写回正式采用流程。

## Remaining risk

旧许可/二进制/hosted来源缺口继续逐仓记录；上游代码和设备未运行。任务迁移仅验证配置持久化，未来调度执行仍依赖Codex运行环境。本轮不创建产品提交、推送或发布。

## 验证结果

配置重读确认、16条main祖先、不变量和716份证据hash通过；docs-only、独立check-docs（244 spaces）及diff检查通过。初次全WIP断言发现3份未写入文档并行变化，已收窄声明到产品WIP不变并保留变化，不覆盖或回滚；详见日报。

> 2026-10-31后续核对：本文所引.build原始证据当前已缺失，原因未知；当时hash验证为历史事实，当前可复核性以[保管记录](20261031-evidence-custody.md)为准。
