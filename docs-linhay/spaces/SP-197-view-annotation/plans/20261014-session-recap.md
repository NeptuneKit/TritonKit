# 2026-10-14 高亮功能会话沉淀

以下保留各阶段当时的范围和验证结论。规范编号已由历史SP-194调整为SP-197，集成状态以space README为准。

## SP-197 — 独立 App 视图临时高亮规划

- 用户最终明确“定位节点 → 保存原属性 → 应用高亮”应为独立通用功能；规划以公开 highlight apply/status/clear 为基础，截图/观察/调试是消费者，P0 自身即可交付。
- 独立 worktree `feat/SP-194-view-annotation`，本轮只修订文档，不实现、提交或执行设备动作。主工作区不变，SP-192/SP-193 文档快照供编号核对，不含源码集成。
- apply 返回 active session；runtime 保存原值，CLI 正常退出/连接关闭不恢复。status/clear 可跨请求调用，TTL 默认建议30s、范围1–300s；幂等重试不续期，丢响应按operationID查询。
- 只在短修改临界区串行；活动会话保护覆盖字段，不长期阻止无关动作。重叠 patch 拒绝，节点失效清理，业务写冲突不覆盖，MainActor卡住/挂起报告pending/unknown，保留CAS的ABA限制。
- evidence --highlight 后置为组合入口，只清理自己创建的会话；普通截图失败不自动clear。独立apply成功不依赖截图/恢复，组合成功才同时检查capture和restore。
- [Space](../README.md)、[技术设计](../../../dev/20261014-view-annotation-design.md) 及索引已同步；CLI命令均为草案，功能/UIKit/设备验收待实现。
- 独立功能拆分后的文档门禁：verify --ci-docs、独立check-docs、diff检查及本期相对链接均通过（194 spaces）；不代表功能实现或设备验证。

### SP-197 — 标记与还原契约细化

- 用户要求仔细制定标记/还原方案；新增[契约v1](../plans/20261014-mark-restore-contract.md)，继续只做规划。
- 只读核查 registry：进程内OID递增且weak引用，重启重用编号；连接generation不能作为runtimeInstanceID；view/layer不同OID需按物理layer去重，controller.view不得因定位隐式加载。
- P0只做outline，以borderColor/borderWidth为恢复组；业务改其中一项则整组保留现值并报conflict/可能残留，不机械半还原。其他mark可独立恢复，支持markID子集clear，详细区分cleanupComplete/restorationVerified。
- 快照只在runtime保存强类型原值，nil不经hex还原；apply幂等不能重存高亮值。cell缺可靠contentEpoch首期拒绝；token/CAS不宣称能检测未知同值写/ABA。
- runtime重连保留会话，SDK stop先清理，TTL不等于已恢复；去重键不因详情淘汰而可重放，未清快照不LRU丢弃。每类边界已写BDD/失败测试计划。
- 契约细化后verify --ci-docs、独立check-docs、git diff --check及本期相对链接检查通过（194 spaces）；仍无实现或真实UIKit验收。

- SP-197 跨端身份问答：Android resourceId可重复、Accessibility uniqueId API33+可空；Harmony FrameNode uniqueId API12+存在，但当前HDC dump nodeID并非已验证的FrameNode句柄。iOS地址也仅在对象存活期有意义；统一采用runtimeInstanceID+provider+对象token+contentEpoch，恢复依赖embedded对象绑定。官方来源和现有代码事实已补入契约第11节；未实现跨端高亮。


### SP-197 — 跨平台技术调研

- 完成[技术调研与裁决](../plans/20261014-cross-platform-research.md)：统一会话、分平台provider；iOS实际CALayer边框最先PoC，Android新增目标App内Debug provider，先验证空foreground替换；外部AccessibilityService不能改目标View属性。
- Android补充API29 getUniqueDrawingId，但恢复仍使用runtime token/弱引用/内容epoch；Drawable.mutate不是克隆。Harmony UniqueID可查询不等于声明式节点通用读写，优先注册响应式AttributeModifier控制outline；AttributeUpdater不自动支持主题变化，reset不是undo。
- Harmony独立仓库及本机API24 SDK只读核查完成；独立仓已有dirty改动未触碰，不声称其代码已合入主仓。
- 契约新增snapshot_compare_restore与managed_override；后者撤销覆盖恢复当前业务样式，receipt明确original/current_base。iOS同步stop和渲染completion存在集成前提，不能将网络断线当runtime销毁或将completion当截图证明。
- 本轮只做官方文档/源码/SDK核对与文档交付，无高亮实现、设备动作、编译或视觉验收。方案先iOS A/B，再Android C/D与Harmony E/F实验。

- 跨端调研交付检查：`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 及SP-197相对链接检查通过（194 spaces）。仅文档验证，不代表各端原型运行通过。


### SP-197 — 用户校正可选接入

- 用户明确高亮是可选能力，不强制接入内置SDK。已同步space/计划/技术调研/恢复契约/索引：既有查看、操作、普通截图不新增SDK前提；官方SDK只是可选provider实现，也允许已有调试能力或自定义适配，不自动安装或注入。
- 显式apply不支持则typed unsupported；截图组合默认prefer，零写入unsupported继续普通截图并标明未高亮；显式required才阻断。部分写入或恢复冲突仍显式返回，不静默降级。


### SP-197 — 执行前整理

- 按用户要求整理space与技术方案，新增[执行清单](../plans/20261014-execution-checklist.md)，明确S0契约→S1 runtime→S2 CLI/HTTP→S3验收，P1截图与跨端实验后置。当前待进入S0，未开始源码实现。
- 固定文档责任：README为边界入口、contract为恢复语义、dev为架构、research为证据、execution checklist为队列。统一可选SDK/provider、prefer/required、session state与内部phase，记录容量初始预算及shutdown集成要求。
- SP-192/SP-193为既有文档快照，未纳入本功能实现；独立Harmony仓只读研究，不改其dirty工作区。尚无提交/合并/发布；不变更锁文件或生成产物。
- 这次沉淀是尚未验收的功能设计，不升格为AGENTS或全局skill规则；public skill更新放在P0功能验收后。

- 执行前整理验证：docs-only门禁、独立结构检查、SP-197相对链接及差异检查通过（194 spaces）；源码/设备验收尚未开始。

### SP-197 — 独立高亮实现与模拟器验收

- 用户授权开始实现并模拟器验证；独立feat/SP-194-view-annotation/worktree基线8aaf6c31，未提交/合并/推送。完成可选highlight capabilities/apply/status/clear、sharedDTO、HTTP路由、DebugUIKit border provider和App-owned会话；普通截图不强制内置SDK。
- 原值CGColor?/CGFloat留App，nil无损还原；整组CAS保护业务新值，弱祖先链拒绝重绑；1024 dedupe键/128终态详情，TTL连续时钟1–300秒。只对预检通过已接纳operation幂等；零写拒绝不登记。丢apply响应保留operation/runtimeID未知残留，断连不丢会话。
- 审计后补setter重入零写节点、等待apply期间partial clear失效、祖先container迁移、stop每次epoch/TaskLocal旧请求隔离及旧queued cleanup拒绝；不以同值ABA或MainActor卡死假设强制成功。
- 真实iOS27.1 Simulator 19项高亮/生命周期测试、37步fixture CLI/HTTP/WebSocket真实属性+布局点击+画面、service重启同session恢复、未接SDK系统设置截图通过；6图归档到space。默认双屏device抓screen3黑屏，保留失败，Triton未覆盖enum时只读fallback检查display，再回Triton --display1取有效画面。
- 默认19421仍有用户App，使用隔离临时测试服务，不改产品默认端口、不停止默认服务。verify.sh --local通过；最终CLI/Release/文档检查见[验收报告](../plans/20261014-p0-validation.md)。初期CLI taxonomy和误设CALayer默认nil失败均保留，修后重跑。public skills/README补可选使用与恢复边界。
- P1自动截图消费者、Android/Harmony/Compose provider、动态adapter加载、真机以及真实挂起/卡死证明均未完成；当前只交付P0 UIKit，不伪称跨端支持。

- SP-197最终收口：完整CLI1219项、SDK根包53项/shared277项、真实Debug UIKit19项、真实iOS Release3项、Release CLI 37步fixture及docs门禁全过。S0–S3完成、P0待集成，P1/S5未实现；原服务保持可达。测试会话已clear验证，专用fixture/Simulator与隔离service收尾，不删除worktree/未授权提交。

## 可复用结论

- 对象地址仅作存活对象的注册表token，不从裸地址重建对象；祖先链和runtime身份共同限定恢复对象。
- 原属性保存为平台类型，按属性组比较恢复；业务写入冲突、外部自行恢复、对象消失与verified回写分别记录。
- 只对已接纳/可能写入操作保存幂等tombstone；零写拒绝不消耗operation，丢响应保留恢复键。
- 会话归App而非CLI连接；stop代际隔离与连续时钟TTL兜底不能替代显式清理回读。
- 模拟器截图需看实际画面；默认display成功写黑图不能计视觉通过，显式display与App层截图证据分开。
- Release测试ENABLE_TESTABILITY只是@testable编译配置，不启用运行时功能；SwiftPM/macOS通过不能代替真实UIKit测试。
- 三个public skills与host-simulator内部skill已声明能力和可选接入边界；保持CLI/HTTP入口，不新增Web控制面。


## 本地main集成收口

用户授权整理、沉淀并合入main。实现`ee9a9ab7`经主线observation与SP-195 Runner集成后，由`7b1a2f76`合入本地main；最终CLI1321项+36项XCTest、SDK63项/shared287项通过。新增UIHealth忙状态下独立高亮capabilities/status/clear强类型路由回归。三个public skills、内部host skill、技术方案和6张真实截图均已进入main。并行任务的WIP按文件/段落保留，SP-196仅提交编号预留；未push/release。

main最终local gate exit 0；Release CLI、Simulator编译、observe/host smoke、结构与差异检查通过。CI-docs及独立check-docs通过；另行校验暂存快照197个space编号连续且链接完整，不把并行SP-198的未提交门禁配置当本次提交。
