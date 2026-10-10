# SP-182 TritonKit 可信执行系统设计

- 日期：2026-10-08
- 状态：设计已归档／实施待立项；未进入产品实现
- 需求：设计一套新的可信执行系统，将此前零散能力聚合、封装、消融；不是加总入口或继续堆命令。用户进一步明确：多端语义统一；agent自由组合单点命令与使用封装高级命令两条一等路径并存。
- 前置研究：[SP-181 Device Hub范式](../SP-181-device-hub-paradigm/README.md)。本需求将上一轮候选定位推进为用户明确认可的设计方向，不代表所有实现细节已批准。
- 工作区：本轮当天docs-only在主工作区完成；保留SP-181未提交文档与原ahead1提交，不stage、不提交、不推送。只读subagent审计旧执行/验证链，不拥有写入面。多日实现须另建同级worktree。

## 影响层与边界

设计 shared core / CLI / HTTP 的执行聚合与契约，定义Web/Wails只读投影边界。当前本机iOS Simulator、Android/Harmony emulator为首期；复用已有Debug embedded和host adapter。真机/远端/设备云、Web写控制、模型绑定、全面窗口产品不在首期。

本轮不改产品代码、不执行设备/构建/服务/设置操作、不迁移用户plan与历史证据、不删除命令或文档。

## 交付

- [双路径架构总图 PNG v2](screenshots/20261008-architecture-overview-proposal-v2.png) / [可编辑 SVG v2](20261008-trusted-execution-architecture-v2.svg)：单点自由组合与高级封装共存，共享ExecutionCore与多端语义；整图为proposal。v1仅保留为历史草图，不再作为当前双路径设计事实源。
- [绘图源程序](plans/20261008-render-architecture.py)：Pillow生成PNG与保留独立文本/形状的SVG；默认拒绝覆盖已有图，重绘应先审阅旧图再生成新版本。
- [新架构ADR](../../dev/20261008-trusted-execution-system-architecture.md)：核心对象、执行状态机、验证/恢复/审计、一致性与边界。
- [多端统一语义契约](../../dev/20261008-trusted-execution-semantics.md)：意图/effect、观察unknown/coverage、能力匹配、统一结果与跨端conformance；不以同名命令或最小公共集代替语义统一。
- [消融迁移与BDD](plans/20261008-convergence-migration.md)：已有能力的保留/下沉/合并/退场，阶段验收与回退；覆盖超时不重发、目标/geometry失效、并发/取消、证据不足、兼容plan与失败envelope。

## DoD

1. 单点命令与高级命令是一等路径；共享权威ExecutionCore，高级WorkflowEngine按需编排；不强制单点创建Run，也不重复底层dispatch/verify。
2. 明确SessionContext/Run/Step/Attempt的区别及各自生命周期；不把一个万能session变成全仓全局状态。
3. 执行、验证、恢复、证据完备度分别表达；未知和失败不是同一状态，ACK不是业务成功。
4. 消融明确到当前源码入口/模型，不仅写新模块名称；现有有界workspace action loop作为资产而非忽略。
5. 新能力/示例标注proposal，旧外部行为通过兼容投影保留，不自动升级成trusted。
6. 文档/索引/memory同步与门禁通过；本轮未跑产品tests明确标注。
7. 平台/入口共用语义契约；unknown不补false、能力不足不静默降级，跨端以同一conformance检查意图效果/验收/错误边界。

## 当前证据

已读当前workspace bounded action loop、action execution provider、replay plan models与model-action parser。已有observe→action→business checkpoint并非从零；新系统的关键是抽取共同内核和消除分散决策，不能再平行增加一个runner。

## 设计裁决

- Hybrid：agent可自行组合单点命令，也可使用高级命令。单点直接调用ExecutionCore，高级WorkflowEngine复用同Core；消融重复底层判断，不消融agent编排自由。Operation独立，Run仅高级聚合。吸收已有input verification boundary、有界循环与证据原语。
- SessionContext是revision化绑定；Run是一次执行聚合根；Step是意图；Attempt是实际发送。租约、连接generation与geometry revision分工明确。
- execution/verification/recovery/evidence四维，不以单一ok判可信；模型done、ACK、dry-run和截图文件存在均不等于业务pass。
- 未知交付先reconcile，不盲重试/切backend双发；不承诺exactly-once、外部GUI排他或业务通用rollback。
- 首片纯compiler/reducer与fake fault测试，再一个iOS动作三入口；后续消融旧循环/策略/成功判断，不同时维护双执行内核。
- 新trusted入口明确门禁；旧wire投影保留primitive/capture语义，不把兼容自动升级成trusted。

## 验证与风险

本轮只读审计主控复核加一个正常完成的subagent，没有产品源码改动或设备/构建/服务动作。已通过 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`（全部exit0，182 spaces一致）；多端语义补充后，5份设计相关文档42个本地链接/行锚核查通过；统一语义与跨端conformance目前仅为设计/BDD，未执行产品测试。跨进程writer协调、TOCTOU/外部干预、崩溃交付窗口、真实几何与平台矩阵在后续implementation space验证。

设计稳定后仍需先实现契约，再更新公共skill；本轮不把proposal写成可运行的CLI示例，不改AGENTS长期约束。
