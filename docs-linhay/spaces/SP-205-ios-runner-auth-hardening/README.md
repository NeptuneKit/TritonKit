# SP-205 — Runner 鉴权强化

## 状态与授权

- 状态：本地实现与验证完成，待主控集成；设备运行未验收。
- 用户授权：2026-10-16“拆新的会话去执行这些改动”。本轮授权开发和验证，不自动提交、推送或发布。
- 需求来源：[SP-202 采用评估](../SP-202-ictrl-security-assessment/plans/20261016-assessment.md)。
- 范围：P2：实际路由错 token/session/过期负例；评估并修复本机恶意监听器先读 Bearer 再伪造 echo 的边界。
- 影响层：CLI / HTTP 与 shared runtime，按切片实际范围验收；Web/Wails 不新增写控制。
- 计划 branch：`feat/SP-205-ios-runner-auth-hardening`；worktree：`../TritonKit-worktrees/SP-205-ios-runner-auth-hardening/`。初始 main 基线 `dd613a994abe45aa14e072c381662a0e3d868f03`，执行前重新核对。

## 文件所有权与协作

CLIIOSRunnerRuntime/Wire/Transport 与随包 ios-runner 鉴权协议、对应 Runner 测试和本 space 文档。不得修改 serve/Bonjour/SDK bootstrap 或 CLIServerRuntime。

不单独拥有共享空间索引和 memory；本轮由当前追踪会话统一登记分派。独立会话在自己的 worktree 写回本 space，避免改主工作区和其他会话 WIP，不使用 stash；需要跨责任面时先记录依赖，不覆盖他人改动。

## BDD 与验收

- 先读取来源评估中该切片的失败场景，写入实施计划；先失败测试，再最小实现和回归。
- 保留既有兼容条件，新增配置覆盖默认值、环境覆盖和非法值。
- 验收绑定候选源码和实际入口，区分 fixture、受控集成与真实运行；产品未测项明确原因与限制。
- 跑受影响测试和适用本地门禁；docs-only 门禁在文档齐备后执行，不能把缺失依赖当通过。
- 不运行 iCTRL 或安装依赖，不自动操作外部项目/设备、签名或 DDI；Runner 先使用隔离本地协议验证。
- 交付自己的实现、测试、限制和集成说明；未验证完成不得标已完成，不自动 commit/push/release。

## 独立会话

已创建并发送开发验证任务：SP-205 Runner 鉴权强化；thread ID `01a14285-3edd-7722-9c46-538e6f6066f4`，host `local`。会话创建不代表实现完成，实际进度以该会话与本 space 后续交付为准。

## 本轮实现与交付（2026-10-16）

- 当前状态：独立 worktree 实现完成，离线/隔离socket及无签名iOS SDK编译已通过；本地总门禁已通过（Simulator运行步骤显式跳过），未主线整合/提交/发布/运行接替。
- [实施与BDD](plans/20261016-implementation.md)、[交付证据/风险/集成清单](plans/20261016-delivery.md)、[候选文件摘要](plans/candidate-files.json)。
- v2 服务HMAC持密证明 + HKDF方向分离 + AES-GCM加密HTTP；网络不发送token/Bearer，旧HTTP服务fail closed。完整target/USB选择、request/session关联、单deadline与unknown不重放均保留。
- 生产server/router拆离UIKit executor，11条真实路由逐错密钥/session/method/过期拒绝，UI计数为零且不stop；排队后过期、同连接重复帧、跨连接重放和allowlist另有实际socket负例。
- 红灯已证明旧客户端泄露token并接受伪echo、旧服务过期仍执行UI；绿色覆盖CLI↔随包server真实链路，设备动作运行仍未测。
- 自动沉淀写回 `docs-linhay/dev/ios-runner-product.md`；共享索引与每日memory由分派主控依据本space交付记录更新。复制到本worktree的SP-201..204和两份索引仅作为门禁上下文，非本切片交付。

## SP-206 联合验收

本切片已冻结交接，主控在联合候选上重跑适用完整门禁通过，实现提交6bfeba80，已由0a246d00合入本地main；原独立交付记录保留其历史范围。最终整合状态和证据见 [SP-206](../SP-206-ictrl-security-integration/README.md)，未发布或设备运行接替。
