# SP-203 — 发现与连接安全

## 状态与授权

- 状态：已由 SP-206 验证并合入本地 main（0a246d00）；未发布或设备运行接替。
- 用户授权：2026-10-16“拆新的会话去执行这些改动”。本轮授权开发和验证，不自动提交、推送或发布。
- 需求来源：[SP-202 采用评估](../SP-202-ictrl-security-assessment/plans/20261016-assessment.md)。
- 范围：P1：serve 广播显式开启、发布状态与 embedded SDK 自动发现/候选信任边界。
- 影响层：CLI / HTTP 与 shared runtime，按切片实际范围验收；Web/Wails 不新增写控制。
- 计划 branch：`feat/SP-203-ictrl-discovery-hardening`；worktree：`../TritonKit-worktrees/SP-203-ictrl-discovery-hardening/`。初始 main 基线 `dd613a994abe45aa14e072c381662a0e3d868f03`，执行前重新核对。

## 文件所有权与协作

Sources/TritonKitCLI/CLIServeCommand.swift、发现/发布的新 helper、Sources/TritonKit/TritonKit.swift 与 SDK 发现 helper、对应 ServeCommandTests / TKPlatformFallbackTests、help/schema 和本 space 文档。不得修改 CLIServerRuntime 或 Runner 协议。

不单独拥有共享空间索引和 memory；本轮由当前追踪会话统一登记分派。独立会话在自己的 worktree 写回本 space，避免改主工作区和其他会话 WIP，不使用 stash；需要跨责任面时先记录依赖，不覆盖他人改动。

## BDD 与验收

- 先读取来源评估中该切片的失败场景，写入实施计划；先失败测试，再最小实现和回归。
- 保留既有兼容条件，新增配置覆盖默认值、环境覆盖和非法值。
- 验收绑定候选源码和实际入口，区分 fixture、受控集成与真实运行；产品未测项明确原因与限制。
- 跑受影响测试和适用本地门禁；docs-only 门禁在文档齐备后执行，不能把缺失依赖当通过。
- 不运行 iCTRL 或安装依赖，不自动操作外部项目/设备、签名或 DDI；Runner 先使用隔离本地协议验证。
- 交付自己的实现、测试、限制和集成说明；未验证完成不得标已完成，不自动 commit/push/release。

## 实施与交付记录

- [BDD 实施计划](./plans/20261016-implementation.md)
- [开发、验证、风险与 memory 移交](./plans/20261016-delivery.md)
- [仅供门禁的外部文档上下文（排除集成）](./plans/20261016-gate-context.json)
- [集成文件与候选摘要](./plans/integration-files.json)

## SP-206 联合验收

本切片已冻结交接，主控在联合候选上重跑适用完整门禁通过，实现提交6bfeba80，已由0a246d00合入本地main；原独立交付记录保留其历史范围。最终整合状态和证据见 [SP-206](../SP-206-ictrl-security-integration/README.md)，未发布或设备运行接替。

## 2026-10-16 工作区收口

已核对本期产品实现进入本地 main，原 worktree 与本地 feature 分支已清理。原始验证日志、历史未提交副本已保存至仓库外私有归档；本次清理不改变发布与真实设备验收边界。详见[本地 worktree 与分支收口](../../dev/20261016-worktree-closeout.md)。
