# SP-197 执行清单

> 状态：S0–S3已实现并验收通过；P1/跨端未实现；已合入本地main（`7b1a2f76`）。2026-10-14 整理。本文件是执行队列；产品边界见 [space](../README.md)，身份/恢复语义以[契约](./20261014-mark-restore-contract.md)为准，平台证据见[调研](./20261014-cross-platform-research.md)，模块架构见[技术设计](../../../dev/20261014-view-annotation-design.md)。

## 已确定的实施边界

1. 高亮是可选能力。用户无须为了普通查看、操作或截图接入内置SDK；官方Debug provider是一个可选实现，不是产品强制依赖。
2. 独立入口为 `highlight apply/status/clear`；真实修改App节点属性，runtime/provider保存强类型原值。截图消费者后置。
3. P0只实现iOS普通UIView/CALayer的outline，映射borderColor/borderWidth；不支持无可靠内容epoch的cell子树。现有Debug runtime作为首个可选provider，shared/CLI不硬编码只有这一种实现。自定义provider扩展契约先保留，P0不承诺可动态加载第三方插件。
4. Android foreground、Harmony注册outline provider、Compose/SwiftUI专用适配属于后续实验；不在P0同时实现。任意host/AX节点不因有ID就拥有属性写权限。
5. 同runtime最多一个活动或残留待处理会话，1–10节点，TTL默认30秒/范围1–300秒；无永久会话、自动续期、force restore和嵌套覆盖。
6. iOS使用snapshot_compare_restore；跨端managed_override保留契约但不伪造已有实现。业务写冲突保护当前值并报告可能残留。

## 执行前置与分支边界

- 在现有同级worktree `../TritonKit-worktrees/SP-194-view-annotation/`、分支 `feat/SP-194-view-annotation` 继续；当前基线 `8aaf6c31`。开始实现时先核查主线变化和本分支diff，避免覆盖并行工作，不自动重置或合并dirty主仓。
- SP-192/SP-193目录及其dev文档是本worktree的文档快照，不能算实现依赖已集成，也不混入SP-197提交。每日memory为共享内容，后续提交/集成须逐段裁决。
- P0 selector先使用已有registry nodeRef/OID或当前runtime唯一解析；SP-192 alias为可选增强，不以未集成alias阻塞独立高亮。无新鲜度证据的alias明确拒绝。
- 本轮没有提交授权；进入编码不等于获准push、PR、merge或release。

## 顺序与文件责任

文件名为拟新增模块；编辑前以实际代码确认。每块由唯一owner持有；接线文件由主控串行集成。S0完成后S1/S2可按明确接口拆分，构建、服务和设备动作仍串行。

| 切片 | 文件责任 | 先写的失败测试 | 交付/停止条件 |
| --- | --- | --- | --- |
| S0 契约与能力 | shared新增TKHighlightModels；现有TKMessage、TKCLITransportModels及capability/schema模型接线由主控持有 | 无截图字段round-trip；旧目标缺能力；unsupported原因；错误单envelope；旧receipt兼容；重复ID/非法TTL/超节点数 | DTO、错误表、capability字段和状态词统一，测试通过后冻结接口 |
| S1 运行时与UIKit | runtime新增HighlightSessionManager及UIKit provider、专用request handler；TKObjectRegistry只做必要复用；TritonKit.swift生命周期由此owner持有 | original/nil、物理layer去重、operation幂等、预检零写、部分写补偿、组冲突、部分clear、TTL/reconnect/stop、旧runtime拒绝、cell拒绝 | 普通UIView真实apply/status/clear及异常清理通过；未清理状态不丢失 |
| S2 CLI/HTTP/schema | CLI新增CLIHighlightCommands/Runtime/Models、CLISchemaHighlightCommands；沿用本地request transport，根命令注册由主控接线 | 完整argv；status二选一；clear子集；未知/旧provider；正常CLI退出不clear；单一JSON；不新增SDK安装步骤 | 无截图独立使用；HTTP透传同一契约，无新Web控制面 |
| S3 集成与P0验收 | Tests/TritonKitSharedTests、Tests/TritonKitTests及CLI实际测试目录；验收证据放本space/screenshots或脱敏evidence | 同名节点精确命中、前/中/后画面、真实MainActor/生命周期、普通无SDK截图保持可用、Release no-op | P0所有必需场景通过并记录证据；未通过不得宣称功能交付 |
| S4 可选截图消费者（P1） | CLIEvidenceCommands/CaptureRuntime/ArtifactsRuntime、schema与public skill | prefer零写unsupported继续原图；required失败；只清自有session；截图成功/恢复冲突仍失败；取消finally | 原图/高亮图/receipt关联完整；普通截图不依赖高亮 |
| S5 跨端实验（后续） | Android可选App内模块；Harmony独立仓provider；各自独立文件面/分支再分配 | 按调研C–F；foreground布局/交互无变化，outline主题/资源/复用恢复，未注册unsupported | 每端有真实证据才启用capability；不阻塞P0发布判断 |

## S0必须固定的接口细节

- 能力按目标/provider返回：supported、reason、presets、restorationModes、nodeKinds、limits、renderObservation；不能只有全局平台布尔值。缺能力是正常探测结果；显式apply返回highlight_unsupported。
- operationID由CLI生成或显式传入，绑定runtimeInstanceID+规范化payload；status接受sessionID/operationID二选一；clear必须指定session，可重复mark子集。快照不离开provider。
- receipt分别记录session state、mark outcome、cleanupComplete、restorationVerified、residualState、ownershipAssurance、restorationMode、restoredTo、renderObservation。不要用一个ok同时表示请求送达、可见和已恢复。
- 会话state仅active/partially_active/restoring/closed/needs_attention；validated/originals_saved/applied等是内部phase。renderReady只表示有界渲染机会；真实可见由画面验收，不能混作session state。
- 建议P0初始运行预算：最多10节点、1活动/残留会话、1024个operation去重键，终态详情最多保留128条；活跃/待清理记录不可淘汰。去重容量满返回highlight_capacity_exceeded，不能为继续服务重放旧ID。数值在S0预算测试后固定进schema，修改须同步测试与文档。
- 新增明确失败码：highlight_unsupported、highlight_target_ambiguous、highlight_target_not_found、highlight_identity_unverifiable、highlight_identity_changed、highlight_stale_runtime、highlight_busy、highlight_operation_conflict、highlight_capacity_exceeded、highlight_receipt_expired、highlight_render_timeout、highlight_restore_conflict、highlight_restore_failed；输入非法沿用validation_failed。expired/no_change是结果原因，不自动当恢复成功。
- shutdown设计：transport断连不销毁manager；保留现有同步stop兼容路径，并新增可等待清理结果的内部异步shutdown路径。同步入口只能安排清理，不能声称同步恢复完成；清理未完保留manager。禁止阻塞MainActor等自身回滚。

## 截图组合的结果表（P1）

拟议参数 `--highlight <spec> --highlight-policy prefer|required`；未请求高亮不执行能力探测/修改，requested时默认prefer。具体argv随S4 schema测试固定。

| 条件 | prefer | required |
| --- | --- | --- |
| 无可写provider，且从未写入 | 保存普通截图，highlight=unsupported、imageAnnotated=false，capture成功可ok=true | 明确失败，不伪造高亮产物 |
| 高亮/截图/清理全部验证通过 | 保存原图与高亮图及receipt | 同左 |
| selector歧义、busy、输入错误 | 返回明确错误，不当作缺能力跳过 | 同左 |
| 部分写入、截图失败、恢复冲突/未知 | 尽力清理本次会话并返回失败/partial，保留证据 | 同左 |

prefer无写入跳过应在manifest保留skipped原因；P1需用兼容测试固定既有partial/exit含义，不改变其他evidence失败规则。零写unsupported跳过不满足“已高亮成功”，但可满足普通capture成功。

## 验证与交付证据

每切片先失败测试、最小实现、focused回归。P0集成时串行执行：

1. shared/状态机测试：身份、幂等、去重容量、恢复组、无SDK能力缺失、配置边界。
2. CLI完整参数/schema/HTTP透传测试，再完整CLI测试（使用本次构建的TRITON_CLI_PATH；stdout相关测试不并行）。
3. 根包测试与真实iOS destination测试分别报告；macOS下UIKit条件跳过不计通过。
4. Simulator验证前保存Triton status/doctor/capabilities/schema/plan事实；按Triton-first使用真实窗口普通View演示，记录apply后、clear后属性回读和脱敏截图，测布局及点击行为未改变。
5. `docs-linhay/scripts/verify.sh --local`；文档门禁、链接和diff检查；Debug开关与Release no-op回归。
6. space、索引、技术文档、memory写回；public skill只描述已验收能力，强调可选接入。每项证据标注源码版本、平台、命令、结果、限制。

需要保留的失败证据：业务改一半边框导致conflict；App不可达与TTL到期仍unknown；apply响应丢失查询原operation；断连重连不失会话；无SDK普通截图可用。未能制造的挂起/卡主线程场景列为未验证，不能以定时器单测替代。

## 开工队列

- [x] S0：shared DTO、capability、失败测试与参数预算固定。
- [x] S1：独立管理器和UIKit provider。
- [x] S2：CLI/HTTP/schema闭环。
- [x] S3：真实UIKit、普通无SDK路径、完整回归及P0证据。
- [ ] S4：可选截图消费者。
- [ ] S5：Android/Harmony按实验结果启用，不做平台支持占位成功。

本轮完成S0–S2与S3核心模拟器验收，详见[验收记录](./20261014-p0-validation.md)。最终完整CLI、根包、iOS Release及文档门禁通过，S3完成；S4/S5明确后置；本轮实现、skills与证据已提交并由`7b1a2f76`合入本地main。
