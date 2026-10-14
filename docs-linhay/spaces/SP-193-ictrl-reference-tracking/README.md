# SP-193 — iCTRL 长期参考与更新追踪

## 状态与范围

- 状态：参考登记完成，长期追踪已启用。
- 用户请求：将 [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) 列为参考项目，长期追踪更新。
- 影响层：项目文档、memory 和本聊天自动追踪；无 CLI/HTTP/shared core/Web/Wails 产品实现变更。
- 本次为当天文档配置任务，在主工作区完成；不新建实现分支或 worktree。
- 独立于 [SP-192 借鉴机制实现](../SP-192-ictrl-adoption-feasibility/README.md)，不改变其已验收范围。

## 参考与追踪入口

- 正式参考档案：[iCTRL 参考与追踪](../../dev/ictrl-reference-tracking.md)。该文件进入版本管理。
- 本地参考入口：`docs-linhay/references/ictrl.md`；references 目录按既有规则忽略，长期记录以正式档案为准。
- 机器可读检查点：[upstream-state.json](./plans/upstream-state.json)。
- 自动化：`ictrl` / `iCTRL 上游更新追踪`，ACTIVE，绑定当前聊天，每天北京时间 10:00 检查。
- 首次核对：2026-10-14；默认分支 `main`，HEAD `99dbfecdb39836ba26a0b2b0dcfde90f705a6835`；最新稳定版本 [v1.97.1](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.1)，发布于 2026-10-13 19:33:32（北京时间），许可证 Apache-2.0。

## BDD 与验收

- Given 项目已登记，When 后续会话查阅参考项目，Then 可从长期 memory 到达参考档案、上游与 SP-192。
- Given 成功检查点，When HEAD、Release 或许可证变化，Then 读取增量原始资料，记录事实、影响及可借鉴价值；完成摘要后才推进对应检查点。
- Given 上游未变或同一变化已记录，When 周期检查，Then 保持安静，不重复通知。
- Given 查询失败、分页或比较截断，When 无法确认完整变化，Then 保留最后成功检查点，记录首次/变化故障及恢复，不把失败报告为无变化。
- Given 有值得借鉴的机制、安全或兼容性变化，When 完成核对，Then 中文通知并附上游链接；不把上游性能自述当作 TritonKit 实测。
- 登记验收：正式档案、索引、长期及每日 memory、JSON 检查点齐备；已确认自动化 ACTIVE 与计划；文档门禁通过。未来周期执行结果由自动化产生，本次不宣称已执行。

## 采用边界

只读查询上游并写本地追踪记录；不自动运行第三方代码、升级依赖、签名 Runner、挂载 DDI、操作设备、实现功能或提交/推送/发布。后续采用另建实现 space。重点追踪 live ref/alias 新鲜度、采集预算、视觉稳定/OCR、UI 健康/熔断、agent schema/错误反馈，以及 Runner/DDI/签名兼容和安全修复。

## 验证

本次仅文档和自动化配置，不新增产品测试。`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 均通过（193 个 space）；JSON 基线、参考链接及已保存自动化的 ACTIVE 状态、每日 10:00 计划和当前聊天绑定校验通过。自动化执行依赖 Codex 调度环境可用。
