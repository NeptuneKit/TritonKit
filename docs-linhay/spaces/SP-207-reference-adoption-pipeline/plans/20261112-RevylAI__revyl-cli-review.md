# Revyl CLI 2026-11-12 增量审查

结论：今日安全文本增量已读完，决定 `partial_observe`。未确认需要直接开发的独立本地缺口；整体读取仍不完整，不得推进成功 checkpoint。

## 固定范围

- 今日 delta：`dcf5f2ab9fdd181a3bbe770410f4ad19dc36fed9` → `dd8c128d8043ca09961fb6e59d0a0cfe95d923ed`。前者是昨日观测 head，并非完整成功 checkpoint。
- 实际 main：`0ec972e6151eb27372b3bdf5aa940940c56c30b0`。产品结论只使用保存的 `git show` blobs；当前 dirty WIP 不算已交付。
- 未闭合 full scope 从 `a50ee179e5c01a1f25f15cef951a78eddab5fa3e` 起：昨日83 commits的全量语义、hosted/binary来源及许可仍未补齐。今日14 commits不能覆盖这些缺口。
- 今日 commits 分页1页读到 delta base；14 commits / 14 parent edges / 15完整非截断递归trees。47路径含43安全文本、4个`.pyc`。118文本blob版本共8528368字节，逐个Git object SHA1和SHA256验证。4个pyc取前排除，未下载、反编译或执行，语义缺口仍存在。
- 全部43路径文本变化已阅读；parent差异经去重为2614行可读文本，加完整JSON递归比较的15处OpenAPI变化。原始完整blob、parent差异、结构化OpenAPI差异均保存；单行OpenAPI展示截断已通过递归值差异补足，不以截断输出充当已读。版本同步经历0.1.234→235→236→0.2.0→0.2.1→0.2.2→0.2.3，没有把最终diff遗漏的版本阶段当业务变化。
- Release完整2页，最新非draft仍为v0.1.234；全文见review-release-notes.md，只有安装/嵌入skill/checksum说明，未宣称0.2.3已发布。LICENSE API仍404；README badge及pyproject的MIT声明不替代许可证全文，不能认定复制授权。

## 逐机制评估

### WebSocket正常关闭：观察，未证明本地缺口

[3269a3c7](https://github.com/RevylAI/revyl-cli/commit/3269a3c7a2f32aef93e175ee4a76f7ab13271b5b) 的Metro诊断在101响应后发送masked status1000 close frame；relay将1005映射1000，合法1000–1014（排除1004/1005/1006）和3000–4999保持，其他映射1001，并在发送ws.close及本地WriteControl两处使用。收益是避免保留本地报告用途的close code被转发给Node ws。今日未新增对应测试；rand.Read/close-frame Write错误被忽略，所以仅能说明best effort关闭，不证明真实Metro恢复。

当前main `CLIHostHarmonyArkWebCDPSession.swift:33`、`TritonKit.swift:693,861` 使用URLSessionWebSocketTask `.goingAway`，没有这条自制Metro relay整数close-code透传链。不能从共享“WebSocket”名推断同一故障；未作网络fixture，也未声明所有transport已覆盖该机制。

### test diff/pull完整定义与Git发布滞后：观察

[db1e1f78](https://github.com/RevylAI/revyl-cli/commit/db1e1f78653e246526fcf7ada739a221e59d00ef) 抽出remoteTestDefinition供pull及diff共用，diff从blocks/tasks JSON改成去_meta的完整TestDefinition YAML，纳入variables、tags、env vars、build/device/location。tags/variables/launch vars读取失败由忽略改为失败，避免把未知当空；app lookup与name mapping仍有各自既有降级，不能声称所有依赖均fail-closed。新增location由run_config.execution_mode.initial_location读取。今日没有resolver/config_remote测试改动，运行正确性未验证。

config validate 仅在git_default_branch authority、已应用commit是HEAD祖先、HEAD属于origin默认分支且本地config等于远端tip时，解释为尚未应用commit并建议等待；任一Git查询失败不下结论，共用Git timeout。Triton当前没有该托管测试同步/default-branch发布后台；本地 `HostWorkspaceConfigStorage` 有descriptor identity、lock、atomic publish及changed-before-publish防护，属于不同状态域，不能当作云同步完整覆盖。没有建立新增云管理范围。

### feedback friction、会话节流、agent归因：局部原则已覆盖，机制观察

[3080a5e7](https://github.com/RevylAI/revyl-cli/commit/3080a5e7761f3188587a828b2ab1ae735a08f3a2) 新增friction类型，后端422时一次降级other加`[friction] `并预留11字符。其检测仅看422状态，不验证错误字段确为type，不能称精准兼容协商。新增测试涵盖有/无降级及消息预算。

新增stderr提示按agent/session、60分钟idle gap和最多8会话节流；状态锁争用/写失败保持静默，skip auth/update/help/feedback/mcp serve；失败提示继续30分钟窗口。测试包括交错会话、无ID不同agent、淘汰、时钟倒退、锁争用、Cobra拒绝及JSON stdout不污染。telemetry新增hint-shown事实、agent识别扩展及显式名字正则；身份标记不代表授权。

当前main公开`tritonkit-dev-feedback/SKILL.md`已要求真实需求/bug/friction证据、open/closed去重、脱敏、未知动作不重放与独立验收；不需要重复新增feedback产品面。没有对应Revyl支持API/telemetry/提示session存储，不能将其报告发送、自动升级或`Do not ask`文字作为本任务授权；本次未发送任何反馈。AgentFeedbackSchemaTests只覆盖observe/settle/ui-health/outcome，不冒称覆盖支持工单上传。

### Unicode输入：前置合法UTF8局部已覆盖；远端能力观察

[c305c056](https://github.com/RevylAI/revyl-cli/commit/c305c056bab0089b3a6f5ce71cfb8d65a994d69e) 将帮助/MCP/docs由ASCII改为Unicode，文案称≤500码点/1500 UTF8 bytes、只允许换行/tab control且不支持时types nothing；公开Go validator实际新增只有utf8.ValidString，加已有1–500 rune校验，没有1500byte/control完整验证。其新增fixture是非法UTF8拒绝，不能用文案证明远端Unicode原子输入实现。

当前main `CLIDeviceActionsRuntime.swift:34` 对type文本文件校验非空、≤4096 bytes及合法UTF8；DeviceActionsTests有私有text-file参数/输入冻结测试，HarmonyVerifiedInputTests区分原始Unicode匹配。它们不证明所有平台Unicode输入全成功，也无需照搬500/1500任意阈值；真实设备执行本次未做。Triton不同入口的unsupported边界保持原契约。

### 框架警告、Atlas截图与容量/版本错误：观察

[c851e7a1](https://github.com/RevylAI/revyl-cli/commit/c851e7a14547823b2984e6f1477ef0fce9226127) 新增SwiftUI/UIKit warning enum和report警告图标；文档明确实验性不开启默认、无raw excerpt、UUID/arch匹配符号、无verified app frames时empty stack、observation time为null不能seek录像。公开增量只提供DTO/显示/文档，采集与symbolication后端不在该差异，不能宣称完整捕获或根因。

[8baac882](https://github.com/RevylAI/revyl-cli/commit/8baac882b079aa628571ce62376ef50c71a17247) AtlasEdgeRun新增source/target screenshot key/url和tap ratio字段；当前main WorkspaceActionLoopRuntime已有本地observations、evidenceRefs及transition记录，字段增加不是图像已读取或业务验证成功，未发现独立缺口。SP-281当前相关WIP不作为本次main交付证据。

OpenAPI另增device-start 503 rejection/no_capable_worker/requested_session_id、test/workflow 426 cli_upgrade_required；docs增加平台子session容量409。实现主要位于托管服务，公开声明不证明执行端拒绝先于副作用，当前本机产品不扩展远端Computer调度。版本、三处dev-loop技能副本、README与安装包元数据同步已读，无独立开发需求。

## 验收/下一步

本次完成：安全文本delta采集、逐parent与JSON差异审阅、固定main对照、证据hash核对。未执行：上游代码/测试、产品测试、发布安装、设备、模型、网络控制fixture；未修改repo/main/WIP、metadata/result、昨日冻结证据、checkpoint、Git或远端。

无`adopt`候选，无实现BDD/文件面分派。若未来出现对应本地故障，再用最小BDD验证：无效close code不出站且原异常保留；依赖读取失败diff不伪空；提示不污染JSON且锁冲突静默；非法UTF8在任何副作用前拒绝。它们是复评条件，不是新增产品需求。

整体仍需补昨日83commit语义/hosted来源、许可全文及排除pyc来源语义；本报告不能解除上述缺口。经验沿用现有固定SHA、安全筛选、读取与采用分离规则，正式SP-207与memory由主控串行回写。
