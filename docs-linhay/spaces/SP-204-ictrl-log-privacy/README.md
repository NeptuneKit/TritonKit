# SP-204 — 日志脱敏与降噪

## 状态与授权

- 状态：独立 worktree 实现及验证通过（专项、完整 CLI、根包、Release 与隔离本地门禁）；待主控集成。
- 用户授权：2026-10-16“拆新的会话去执行这些改动”。本轮授权开发和验证，不自动提交、推送或发布。
- 需求来源：[SP-202 采用评估](../SP-202-ictrl-security-assessment/plans/20261016-assessment.md)。
- 范围：P2：响应日志默认元数据化、脱敏、限长；保留失败与统计，不重复实现 id=0 心跳静默。
- 影响层：CLI / HTTP 与 shared runtime，按切片实际范围验收；Web/Wails 不新增写控制。
- 计划 branch：`feat/SP-204-ictrl-log-privacy`；worktree：`../TritonKit-worktrees/SP-204-ictrl-log-privacy/`。初始 main 基线 `dd613a994abe45aa14e072c381662a0e3d868f03`，执行前重新核对。

## 文件所有权与协作

Sources/TritonKitCLI/CLIServerRuntime.swift、独立日志 helper、对应日志测试与本 space 文档。不得修改 CLIServeCommand、SDK 连接/bootstrap 或 Runner 协议。

不单独拥有共享空间索引和 memory；本轮由当前追踪会话统一登记分派。独立会话在自己的 worktree 写回本 space，避免改主工作区和其他会话 WIP，不使用 stash；需要跨责任面时先记录依赖，不覆盖他人改动。

## BDD 与验收

- 先读取来源评估中该切片的失败场景，写入实施计划；先失败测试，再最小实现和回归。
- 保留既有兼容条件，新增配置覆盖默认值、环境覆盖和非法值。
- 验收绑定候选源码和实际入口，区分 fixture、受控集成与真实运行；产品未测项明确原因与限制。
- 跑受影响测试和适用本地门禁；docs-only 门禁在文档齐备后执行，不能把缺失依赖当通过。
- 不运行 iCTRL 或安装依赖，不自动操作外部项目/设备、签名或 DDI；Runner 先使用隔离本地协议验证。
- 交付自己的实现、测试、限制和集成说明；未验证完成不得标已完成，不自动 commit/push/release。

## 独立会话

已创建并发送开发验证任务：SP-204 日志脱敏与降噪；thread ID `01a14285-3be0-7213-9433-374c139189bd`，host `local`。会话创建不代表实现完成，实际进度以该会话与本 space 后续交付为准。

## 本轮实现与证据

- [实施计划与 BDD](plans/20261016-implementation.md)
- [交付清单、字段白名单、验证和边界](plans/20261016-delivery.md)
- 默认响应日志只保留类型、ID、字节数、本地结果分类和计数；最大 512 UTF-8 字节/行。payload、未知键名、App/设备/层级文本及 SDK 字段不输出。
- 普通健康 ping 首次及每 100 次成功汇总；失败和异常 UI health 保留。id=0 ping 维持原有静默。
- 本 space 为独立实现证据；共享索引和每日 memory 由主控集成时写回。工作区内复制的 SP-201/202/203/205 与共享索引仅用于门禁上下文，不属于交付。

## SP-206 联合验收

本切片已冻结交接，主控在联合候选上重跑适用完整门禁通过，实现提交6bfeba80，已由0a246d00合入本地main；原独立交付记录保留其历史范围。最终整合状态和证据见 [SP-206](../SP-206-ictrl-security-integration/README.md)，未发布或设备运行接替。
