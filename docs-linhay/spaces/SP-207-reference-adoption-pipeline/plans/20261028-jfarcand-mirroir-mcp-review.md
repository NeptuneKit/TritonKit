# mirroir-mcp 2026-10-28 增量审阅

结论：**observe（观察，不新建采用）**。6 提交 / 69 文件中，产品变化集中于上游自己的 SKILL.md 编译重放链；Triton 实际 main 没有这条双源链。新增“支持 compiled SKILL.md”会引入 MCP/自然语言执行产品面，收益未形成已授权场景。

## 固定来源与完整性

- [完整比较](https://github.com/jfarcand/mirroir-mcp/compare/502c5e466da4d82df8f65ffa9a598c01e152b56b...317dc15fa21b63cf3e6b997784bd1c4ce6607392)：GitHub compare page=1, per_page=100，total_commits=6，收到6，69 changed files 均有文本 patch；逐提交 API 分别30/4/25/9/4/2文件，不存在达到100的待分页结果。69 文件先按文本扩展名筛选后取得固定 SHA UTF-8 全文，coverage.json 逐项绑定摘要；没有二进制下载，也未执行上游代码。
- 主变化 [8a018c79](https://github.com/jfarcand/mirroir-mcp/commit/8a018c79becc2c6e06108a09e4a02eb643b242fd)：compiled step 的 replayValue、source hash/version、record 序号归一化、SKILL.md/YAML 选择与重放。
- [v0.41.0 完整 notes](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.41.0) 与 [runner-v0.4.0 完整 notes](https://github.com/jfarcand/mirroir-mcp/releases/tag/runner-v0.4.0) 已读，原文另存 release-notes-reviewed.md；runner notes 只有完整比较链接，不能把 v0.41.0 的 game/model 路由 release 汇总当作今日新代码。两产品标签独立保留，result.json 的最新发布观察为 runner-v0.4.0，不按列表首项擅自覆盖。
- [固定 LICENSE](https://github.com/jfarcand/mirroir-mcp/blob/317dc15fa21b63cf3e6b997784bd1c4ce6607392/LICENSE)：Apache-2.0 全文已读，若以后复制代码需保留 license/attribution、标识修改并核对 NOTICE。今天未复制产品代码，许可证不作为采用理由。
- complete_review=true **仅表示上述本日 delta 文本审阅完整**。不追认 imported_observation 的 historical_observation_not_full_incremental_checkpoint，也不替代上游全史、安全审计、编译、资产或设备验收。

## 机制、收益与实际 gap

| 机制 | 上游实际实现 / 收益 | Triton 对照与裁决 |
|---|---|---|
| Markdown 技能可确定重放 | SkillFileLoader 从 .compiled.json 恢复 type/label，拒绝缺失、source/hash/version陈旧；runner名称与MCP选择保持一致，YAML fallback不冒充另一份Markdown | **观察**。Triton .tritonplan 是单一typed JSON，不存在 prose 与 compiled 并存、YAML twin覆盖或get_skill/record_step/save_compiled入口；尚无需要引入第二套执行器的实际gap |
| 保留步骤语义 | replayValue携带timeout、duration、modifier、drag两端、target map、measure子动作；乱序/重试index排序去重，缺口/负数拒绝；未知nested action在执行前拒绝 | **已覆盖原则，观察格式特例**。TKReplayPlanStep直接Codable保存字段，数组顺序即执行顺序；TKReplayAction枚举不识别值解码失败，无compiled index配对链。不能从上游index缺口推导Triton缺陷 |
| 不把无动作当成功 | tap无OCR匹配回退真实执行，measure和longPress不再降级sleep/短tap；坐标-only tap不走空label OCR | **已覆盖相关边界**。Triton tap是直接typed执行，等待是wait条件；readReplayPlan拒绝空steps，runReplayPlan预生成命令且失败后停止；SP-196已交付dry-run/skipped不能当业务通过。上游sleep编译策略不应迁入 |
| 占位符与秘密 | 编译写回${VAR}，执行逐字段替换，诊断使用placeholder而匹配使用resolved值，带引号/逗号不重解析损坏 | **已有同类基础契约**。TKReplaySubstituteVariables在解码后逐字段替换；secure字段/红actedValue贯穿文本输入与结果。不声称已审计所有日志/截图；本日无证据证明Triton有同类compiled label泄露，因为Triton无此文件 |
| registry传递 | live/compiled/autoRecompile共享TargetRegistry，target步骤不丢注册上下文 | **观察**。上游三执行器依赖注入修复，Triton当前计划target/runtimeClient契约不同；没有复现到Triton上下文丢失 |
| Rust依赖与工具链 | serde_yaml→serde_norway；rustls/tokio/webpki/sha2与roots锁文件更新，Rust1.99.1、CI clippy断言修订，runner0.4发布 | **拒绝直接采用**。Triton CLI为Swift，没有这些Rust依赖；不因上游advisory引入Rust或替换本项目依赖。上游测试代码文本检查不等于本地cargo-deny已运行 |
| 网站/npm/版本 | 展示、准确命令、star banner、版本号 | **拒绝**。无Triton产品gap，不复制上游营销或分发入口 |

## 实际 main 与已交付去重

本次绑定实际 main `a0d187ace03d6e56b79b50a7a601c91b359b7955`，通过git show读取而非假定当前工作目录就是main。快照保存在triton-main-text/：TKReplayPlanModels.swift（typed步骤/target/secure/变量替换）、CLIEvidenceReplayRuntime.swift（schema与空计划拒绝、逐步执行、真实input request、脱敏值）、ReplayCommandTests.swift（资源动作执行前整体拒绝、dry-run不解析runtime、失败单envelope）。这是源码/测试文本证据，本轮未跑这些测试。

SP-192是已交付的输入/观察等基线，SP-196已交付失败/skip/证据和测试复用，SP-200已集成的本机target动作并明确排除MCP server/云fleet。不重复派发这些能力，也不将上游iPhone Mirroring、游戏/模型解释器扩张到Triton emulator控制面。

无adopt条目，因此无开发BDD任务。未来只有用户场景明确需要“自然语言技能先录制为机器计划再复放”时再立项；最低BDD应覆盖源哈希变更拒绝、完整typed round-trip、重名来源不替换、变量含引号/逗号、secure不落盘与日志、空/全部skip非业务成功、失败前无额外设备动作。不能直接复制上游坐标-only confidence豁免或陈旧geometry继续执行策略。

验证阶段：只读API与源码审阅完成；未构建、未运行上游/本地测试、未下载release二进制、未设备验证。经验检查完成，无新通用规则；结果限定写入本任务证据目录，由主控负责共享索引和memory收口。
