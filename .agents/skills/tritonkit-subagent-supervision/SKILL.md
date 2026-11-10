---
name: tritonkit-subagent-supervision
description: TritonKit 监督交付模式：任务可安全拆分或用户要求并行时，由主控调度 subagent 并完成集成闭环。
---

# TritonKit Subagent Supervision

开工与交付按[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)只读命中主题，未命中再检索；读取、证据、修订与退出遵循[治理闭环](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。

当任务可安全拆分且预计能明显提升速度或质量，或用户明确要求“用 subagent 做、主控 agent 负责监督到完成”时，进入本模式。简单任务、同一文件的紧耦合改动、共享环境或副作用冲突不强行并行。

## 目标

1. subagent 负责边界清晰的实现任务。
2. 主控 agent 负责需求边界、任务拆分、集成、验证、文档、memory 和最终完成判断。
3. 主控 agent 可主动创建、调度、改派、停止或续跑 subagent，目标是快速推进完整闭环，而不是等待用户逐步指挥。
4. subagent 和其他 agent 的报告只作为证据线索；主控 agent 必须复核关键文件、diff、命令输出、截图或 CI 状态后才能宣称完成。

## 监督模式

根据用户措辞选择模式：

1. `watch only`：监控 session、thread、PR、branch、CI 或日志直到完成、阻塞或失效；不改文件。
2. `audit`：重建原始需求，核对实际改动和验证证据，输出缺口报告；不改文件。
3. `audit and fix`：先审计，再对证据明确的缺口做窄修复和最小验证。
4. `compare`：比较多个 agent / branch / PR / plan 是否满足同一原始需求，归并差异和风险。

权限不明确时默认 `audit`，只报告会修什么，不直接改。

## 审计证据

审计另一个 agent 或 subagent 工作时，先建立 contract：

1. 用户原始请求和后续范围变化。
2. 明确约束：当前 main、文件责任面、禁止事项、验证要求、截图、文档、隐私和发布边界。
3. 隐含验收：用户可见行为、机器可读契约、测试、CI、docs / memory、截图或 evidence。
4. 被审计 agent 的最终声明和无法完成项。

再核对 evidence，而不是凭总结判断：

- `git status`、diff、最近 commit 和 touched files。
- 相关未改文件的上下文，避免只看 patch。
- 声称运行的命令、真实输出、失败或跳过原因；按治理闭环绑定候选 diff、环境和入口，变化后重跑，关键风险在隔离副本证明旧错可被测试抓住。
- CI、测试日志、浏览器截图、模拟器 / 真机证据、GitHub review thread。
- UI / Web mock 变更优先看截图或浏览器 / DOM 验收。

问题分类使用：

- `Gap`：需求行为缺失或未完成。
- `Bug`：实现可能失败或回归。
- `Verification miss`：实现可能正确，但证据不足。
- `Scope drift`：越界改动或违反约束。
- `No issue`：证据显示已覆盖。

审计报告固定包含：`Requested`、`Observed`、`Evidence`、`Gaps`、`Fixes made`、`Remaining risk`。未授权修复时省略 `Fixes made`。

## 执行顺序

1. 先确认需求文档、当前维护权限、命中经验、范围和验收标准；handoff 给出已命中的权威链接与本次候选证据基线。
2. 按写入面拆分 subagent 任务，避免冲突。
3. 给每个 subagent 自包含 handoff：repo path、目标、文件范围、禁止范围、预期证据、验证命令和停止条件。
4. 主控 agent 持续集成 subagent 结果，不等到最后统一收口。
5. 跑完整个需求闭环后才停止：
   - 代码集成
   - 自动化验证
   - HTTP 接口或端到端验收
   - docs / memory 写回
   - 文档结构检查
6. 如果仍有未完成项，继续推进；如果卡住，明确写出 blocker 和剩余工作。

## 主控自主管理

进入本模式后，主控 agent 默认不再为每次调度逐项请求用户介入，可以自行：

1. 按 `space`、计划和 `.codex/agents/` 配置选择 subagent。
2. 分批启动互不冲突的 subagent。
3. 根据结果改派、停止、续跑或补开验证 agent。
4. 合并结果并跑门禁。
5. 只在需求边界变化、破坏性操作、权限/环境 blocker 或必须用户取舍时打断用户。

主控 agent 仍必须保留最终完成判断；subagent 的“完成”只能作为输入，不能替代 DoD。

用户授权主控负责自己开启的会话全流程时，责任持续到在当前 main 串行实现、测试、验收、必要本地提交、证据归档及会话归档。依据真实thread ID与main合并证据关闭已完成执行/批次主控聊天；保留长期主控，归档失败单独记录，不能用idle或完成声明替代验收。该授权不扩大到push/tag/release或关闭远端issue；参考采用细则见[现有流程](../../../docs-linhay/dev/reference-project-adoption-workflow.md)。

## Handoff Packet

分派 subagent 时使用紧凑但完整的任务包：

1. 工作目录和对应 `space` / issue / branch。
2. 本次目标和验收标准。
3. 允许读写的文件或模块；明确禁止触碰的范围。
4. 必须返回的证据：文件、行号、diff 摘要、命令、失败、截图、剩余疑问。
5. 验证命令和成功标准。
6. 停止条件：代码与假设不符、需要越界文件、命令重复失败、缺少凭据、需要用户决策。

不要让多个 subagent 同时编辑同一批文件；只读审计可以并行，写入型任务必须按文件面隔离。

## GitHub Issue 处理与收口

2026-11-11 用户裁决：所有开发在当前 `main` 完成，不创建或推荐 branch/worktree。下述规则替代历史按 issue 隔离工作区的流程。

1. 一个 issue 对应一个 Space、明确文件面和验收边界；只读调研/审查可并行，写入统一由主控在 main 串行完成。
2. 开工核对当前分支、HEAD、staged/unstaged/untracked 差异，保留其他任务 WIP；不使用 stash、reset 或整目录覆盖。
3. 主控核对真实 diff、测试和错误语义，串行运行 focused/full 与适用 docs/local 门禁；只提交本 issue 的精确文件面。
4. 用户授权推送/关闭 issue 时，先推送 main 并核对精确 SHA 的 CI，再关闭本轮已验证的 issue；未完成或新出现的 issue 保留。
5. 复杂 Markdown 评论通过 `--body-file` 发送。收口保存初始、增量和最终 open 快照，更新 Space/memory，归档提交自身也须验证。
6. 当前阶段未完成就继续修复；不把 subagent 的完成声明或历史绿色结果当作当前验收。

## 停止条件

只有以下情况可以停止：

1. 需求已经完整闭环。
2. 用户明确暂停。
3. 当前环境存在无法自行解决的具体 blocker。

“代码已改完”不是停止条件。
