# SP-197 — 独立 App 视图临时高亮能力

## 状态与边界

- 状态：P0独立iOS高亮已实现、验收通过并合入本地main（`7b1a2f76`）。用户明确方向：agent 主动临时改变 App 视图属性；“定位节点 → 保存原属性 → 应用高亮”是独立、通用功能，截图汇报是调用方。
- 核心流程：定位节点 → 保存属性 → 临时修改真实 UIView/CALayer 外观 → 返回高亮会话。独立提供 status/clear；截图、现场观察和调试均可消费该会话。
- 影响层：embedded runtime、shared 契约、CLI、现有本地 HTTP 请求转发和 evidence。Web/Wails 无新增控制面。
- 首期原型验证范围（非产品接入要求）：自愿启用 Debug TritonKit runtime 的 iOS App、UIKit 可映射视图；包括能映射到真实 UIView/CALayer 的 SwiftUI 宿主，不能把任意 SwiftUI 虚拟节点视为可写视图。首期验收使用 iOS Simulator；其他平台另行适配，只有 host AX/OCR 的目标不能改 App 属性。
- 基线 `main@8aaf6c31`；分支 `feat/SP-194-view-annotation`；worktree `../TritonKit-worktrees/SP-194-view-annotation/`。
- 本轮shared/runtime/CLI/HTTP与专用Simulator验收已完成；实现、技术方案、6张截图和skills已提交并合入本地main；未推送或发布。SP-192/SP-193旧文档快照不混入本功能提交。

编号说明：规划/实现阶段使用SP-194；合并时发现主线SP-194已用于参考更新、SP-195用于Runner，SP-196被上游优化并行任务使用，现规范登记为SP-197。原分支、worktree、测试设备名及gitignored证据目录保留历史名称，避免断开验收链路。

## 可选能力原则

高亮是可选增强，不强制接入内置SDK。已有节点查看、操作和普通截图保持各自原有接入条件。按目标探测可写provider；既有调试provider、用户自定义适配和自愿接入的独立Debug模块均可参与，官方SDK不是唯一入口。缺能力时仅高亮返回unsupported，不自动安装或注入。可选截图高亮默认prefer：unsupported则继续普通截图并明确未标注；显式required才阻断组合请求。部分修改/恢复冲突须报告，不能静默降级。

## 产品决策

1. P0 仅修改目标 layer 的 borderColor/borderWidth，背景色后置；所有修改有 before/applied/restore receipt。默认不改布局、文本、可访问性或交互行为。
2. 由 runtime 保存真实原值并负责恢复；不让 agent 自己记颜色、最后再拼一条反向 patch。
3. 第一等入口为 highlight apply/status/clear。apply 成功表示高亮已应用并返回活动 session，不要求截图或恢复；iOS P0 clear 成功表示原属性已恢复并回读；跨端声明式provider撤销覆盖后恢复当前业务样式，receipt明确区分。evidence capture 是可选组合流程，只有该流程要求截图与恢复均成功。
4. 未高亮原图与 App 高亮态截图分别保存；后者明确标为经过临时外观修改的说明图，不作为未修改 UI 的视觉回归基准。
5. MVP 同 runtime 只允许一个活动高亮会话；应用/恢复串行，拒绝重叠属性写入。高亮持有期间不独占全部 UI 动作，允许观察、截图和不冲突的调试；对象失效时清理并报告，不把 UI 冻结。
6. 检测到 App 写入变化时，整组保留当前样式并报告冲突，可能残留。未观测同值写/ABA 无通用检测保证；不能宣称绝对无损恢复。MainActor 卡死、进程挂起时不承诺定时恢复实时执行。
7. 图片后处理、箭头、编号图例和编辑器后置，不作为本期主路径。

## BDD 与验收

| 场景 | Given / When | Then |
| --- | --- | --- |
| 独立应用 | 唯一可写 UIView，apply 请求高亮 | 保存原属性、应用高亮并返回 active session；不调用截图、不自动 clear |
| 独立查询/恢复 | apply 进程已正常退出，从另一 CLI 调用 status/clear | runtime 仍持有会话，status 返回活动事实，clear 恢复并回读；重复 clear 幂等 |
| 多节点 | 3 个合法节点 | 全部预检再统一修改，返回一个会话；任一预检失败不改其他节点 |
| 无节点/歧义 | OID 失效或同名候选多项 | 修改前拒绝，不默认选择首项，不注入假节点 |
| 图像真实性 | 保存未高亮图和高亮截图 | 分别标 source/target/session 和不同时间，报告不称两图为完全相同时刻 |
| 原值恢复 | nil 颜色、原有边框、颜色空间 | 保留 runtime 原始类型及 nil 语义，按 border 组恢复回读，不经 hex 往返重建 |
| 独立消费者失败 | 手工截图或观察命令失败 | 不擅自结束调用者的高亮会话，仍可 status/clear；按期限兜底 |
| 组合流程失败 | evidence 自己创建高亮，capture 失败或取消 | evidence 清理自己拥有的会话；capture/restore 状态分别返回 |
| CLI 退出/断连 | apply 正常退出或响应丢失 | 会话不绑定 CLI 连接寿命；可按 operationID 查询，不重复应用；显式 clear 或 runtime TTL 清理 |
| 并行操作 | 活动高亮下执行查询或不冲突动作/重叠 patch | 前者允许并检查节点有效性，后者拒绝；同目标第二个 apply 返回 busy |
| 业务并发变色 | App 把已修改属性写成不同值 | 不覆盖新值，返回 restore conflict；绝不宣称全量恢复成功 |
| 复用/替换节点 | cell 被复用、页面切换或对象离树 | 标记 identity changed，使高亮会话失效；已知预失效时清理；内容已变不写旧值，缺可靠 epoch 的 cell 子树首期拒绝 |
| 属性组冲突 | 业务只改边框颜色 | 整组不写，不自动只恢复宽度；报告可能残留 |
| 部分还原 | clear 指定 markID 子集 | 其余标记保持 active；重复 clear 不再写旧值 |
| 同对象重复命中 | viewOID/layerOID 指向同一 layer | 同预设合并，不重复保存高亮后的值；不同预设拒绝 |
| 显示未提交 | 属性 setter 成功但画面未更新 | 等待有界渲染机会；超时恢复并失败，不能把 setter ACK 当已可渲染；是否在截图中可见由消费方另验 |
| 可选接入 | 未接入SDK或没有可写provider，调用普通截图/可选高亮截图 | 普通截图按原能力执行；可选高亮标记unsupported并保留原图，不强制接入SDK |
| 非支持对象 | host AX、系统 UI、无 runtime、Release | 明确 unsupported，不自动转为普通图并声称完成高亮 |

## 文档入口与执行队列

1. [执行清单](./plans/20261014-execution-checklist.md)：开工顺序、文件owner边界、接口冻结项与验收门禁；S0–S3已完成实现/验收；P1截图消费者后置。
2. [技术设计](../../dev/20261014-view-annotation-design.md)：模块与集成架构。
3. [标记/还原契约](./plans/20261014-mark-restore-contract.md)：身份、快照、冲突、状态及恢复的规范事实源。
4. [跨平台调研](./plans/20261014-cross-platform-research.md)：官方证据、可行性与待验证假设。
5. [产品流程](./plans/20261014-view-annotation-plan.md)：命令草案和截图消费者流程。

范围/验收以本README为入口；恢复语义以契约为准；执行清单只编排工作，不另创一套恢复规则。P0交付独立iOS能力，P1接截图，跨端适配按实验单独开放。

## 产物与下一步

- [跨平台技术调研与裁决](./plans/20261014-cross-platform-research.md)
- [高亮标记与还原契约 v1](./plans/20261014-mark-restore-contract.md)
- [产品流程与实施计划](./plans/20261014-view-annotation-plan.md)
- [临时高亮事务技术设计](../../dev/20261014-view-annotation-design.md)
- P0独立highlight capabilities/apply/status/clear 的CLI/HTTP/runtime闭环已完成并验收；下一步P1 evidence消费方另行实施验收。
- 已更新三个 public skills 及独立 view-highlight 参考流程，明确能力、可选接入、恢复检查和平台边界。
- screenshots/ 已归档6张真实脱敏Simulator截图，见[验收记录](./plans/20261014-p0-validation.md)。

## 验证

本轮P0验收见[实现与模拟器报告](./plans/20261014-p0-validation.md)：19项真实UIKit、37步App端到端、断连重连、无SDK设置截图及local gate通过。原P0完整CLI1219项、根包53+277项、iOS Release3项与文档门禁通过；与最新observation/Runner主线集成后CLI1321项+36项XCTest、根包63+287项及main最终local gate通过；挂起/卡死、同值ABA、跨端与自动截图组合未验证。以下保留先前文档阶段历史。

- 修订后文档验证：`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 与本期相对链接检查均通过（194 spaces）。仅文档通过，不代表高亮或恢复已实现。

- 标记/还原契约v1补充后，上述文档门禁与链接检查再次通过；对象复用、属性组冲突和TTL仍是待实现验收项。

- 跨端调研交付检查：`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 及SP-197相对链接检查通过（194 spaces）。仅文档验证，不代表各端原型运行通过。

- 执行前整理验证：docs-only门禁、独立结构检查、SP-197相对链接及差异检查通过（194 spaces）；源码/设备验收尚未开始。
