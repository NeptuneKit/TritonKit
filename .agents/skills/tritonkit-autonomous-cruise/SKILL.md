---
name: tritonkit-autonomous-cruise
description: TritonKit 内部自动巡航流程。用户要求长期计划、自动巡航、无人值守推进、离开一段时间让 agent 自主进化、提前巡航或巡航收尾时使用。
---

# TritonKit Autonomous Cruise

## 触发条件

- 用户说“长期计划”“自动巡航”“巡航进化”“提前巡航”“我离开一段时间你来推进”。
- 用户要求 agent 在无人值守状态下持续推进 TritonKit，而不是只完成一个短任务。
- 需要把若干可独立验证的小切片排队推进，并在用户回来前保持可回滚、可审计状态。

## 启动前边界

1. 明确巡航目标、时间/预算、禁止事项和停止条件。
2. 建立或复用 `docs-linhay/spaces/<space-key>/`；长期巡航默认使用可追踪英文 slug，例如 `20260524-autonomous-evolution`。
3. 写入 BDD 验收边界：本轮要交付什么、明确不做什么、哪些结果只进入 backlog。
4. 确认风险护栏：
   - 不 push、不 tag、不 release、不更新 Homebrew，除非用户明确授权。
   - 不改外部仓或私有项目，除非用户明确授权并说明边界。
   - 不执行破坏性命令；需要时单独请求确认。
   - 不把临时失败、subagent 中间观点或命令流水升级为长期规则。

## 巡航执行节奏

1. 先做只读盘点：`git status --short --branch`、相关 docs/space、最近 memory、当前测试门禁。
2. 拆成小切片，每个切片都要满足：
   - 有明确验收点。
   - 先补测试或可执行证据，再实现。
   - 改动集中，避免横跨无关模块。
   - 完成后运行聚焦验证。
3. 大切片或高风险切片可以使用 subagent，但主控 agent 仍负责边界、集成、验证和最终判断。
4. 每个稳定 checkpoint 后写入 memory；必要时提交本地 commit，commit message 要能说明切片结果。
5. 巡航中优先推进能增强 agent 自主使用 TritonKit 的能力：CLI/HTTP schema、机器可读证据、Xcode/Simulator takeover、失败诊断、artifact 安全、redaction、真实项目回归闭环。

## Subagent 使用

- 只有任务可并行且写入面清晰时才启用 subagent。
- 只读审计适合交给 subagent：安全审计、架构审计、外部 agent 使用体验、遗漏风险扫描。
- 代码实现型 subagent 必须有明确文件范围；多个 subagent 不写同一批文件。
- 主控 agent 不把 subagent 结论原样当事实；需要与本地 diff、测试、文档和产品边界对齐后再采纳。

## Checkpoint 规则

每个 checkpoint 至少记录：

- 本切片目标和完成结果。
- 改动文件或能力边界。
- 运行过的验证命令和结果。
- 剩余风险与后续队列。
- 是否已提交；若已提交，记录 commit hash。

长期巡航可以有多个 checkpoint commit，但每个 commit 都必须保持可解释、可回归，避免把半成品和临时文件混入。

## 收尾流程

用户返回、预算耗尽或触发停止条件时：

1. 停止新增功能切片，先做状态盘点。
2. 写最终巡航报告到对应 `space`，命名示例：`cruise-wrap-report-<YYYYMMDD>-v01.md`。
3. 报告至少包含：目标、实际完成、commit checkpoint、验证、文档/skill/memory 写回、未完成 backlog、风险。
4. 运行合适门禁：
   - 代码变更默认跑 `docs-linhay/scripts/verify.sh --local`。
   - 纯 docs/skill 整理至少跑 `git diff --check`、`docs-linhay/scripts/check-docs.sh`、`docs-linhay/scripts/qmd-sync.sh`。
5. 写入 `docs-linhay/memory/YYYY-MM-DD.md`，执行 qmd sync。
6. 做独立收尾 commit。
7. 只有所有必要收尾完成后，才宣称巡航结束或目标完成。

## 输出标准

- 巡航中给用户的阶段更新要短：当前切片、验证状态、下一步。
- 用户回来询问进度时，先列“已完成 / 正在做 / 下一步 / 风险”。
- 快速收尾时优先报告事实和证据，不补做大改动。
- 最终回答必须说明是否 push/tag/release；默认结论是未执行这些动作。

## 与其他 skill 的关系

- 文档、memory、qmd、AGENTS 同步：使用 `tritonkit-ops-governance`。
- 会话整理和模式沉淀：使用 `tritonkit-session-skill-distill`。
- subagent 监督交付：使用 `tritonkit-subagent-supervision`。
- 具体领域能力按需叠加 Xcode、host simulator、emulator 或真实项目回归相关 skill。
