---
name: tritonkit-plan-arbiter
description: Use when TritonKit work has two or more competing plans, agent proposals, PR strategies, session summaries, issue approaches, or implementation directions that need one executable decision; compare plans against real repo context, product boundaries, validation gates, cost, and risk, then choose adopt, hybrid, or revise-first.
---

# TritonKit Plan Arbiter

把多个方案裁决成一个可执行方向。不要把不同计划机械拼成折中稿；先归一化、核对事实，再给出明确采用、混合或退回重写的决定。

## 触发场景

- 用户让多个 agent 分别出方案后要求主控选择。
- 同一 issue / space / PR 出现多个可行实现路径。
- subagent 报告互相矛盾，需要主控判定。
- 发布、模拟器接管、Xcode workflow、Web mock 或真实项目回归涉及高成本取舍。
- 用户要求“比较这些计划”“合并最好的部分”“选一个执行方向”。

若只有一个直接、低风险、已被用户明确接受的计划，不启用本 skill。

## 输入收集

优先读取原始来源，而不是只读摘要：

1. 用户原始需求和后续范围变化。
2. 各计划正文、thread、PR、branch、issue、space 或 subagent 报告。
3. 相关真实文件、schema、测试、截图、CI 或官方文档。
4. TritonKit 固定边界：CLI / HTTP 机器可读契约优先，Web / Wails 不先定义业务控制。

如果某个来源无法解析，继续使用现有材料，并把缺失来源列为风险。

## 归一化每个计划

对每个候选方案提取：

- 目标和明确不做什么。
- 关键假设和未决问题。
- 会触碰的文件、模块、CLI command、HTTP route、schema、DTO、测试或文档。
- 执行顺序和每步可回滚性。
- 验证门禁：单测、CLI schema、HTTP smoke、Web test、截图、release contract、docs check。
- 风险：产品边界、兼容性、隐私、发布、真实设备 / 模拟器环境依赖。
- 预计成本：实现复杂度、测试成本、对并行 worktree 的影响。

不要奖励长篇计划；优先事实扎实、范围清楚、验证具体的方案。

## 裁决顺序

按以下优先级决策：

1. 正确满足用户请求和当前 `space` 验收标准。
2. 符合 TritonKit 产品边界和 AGENTS 规则。
3. 依据来自真实文件、schema、测试、截图或官方文档。
4. 首个切片更小、更可验证、更可回滚。
5. 验证和失败诊断路径更清楚。
6. 对并行工作和未提交改动的冲突更少。
7. 质量接近时，选择执行成本更低的路径。

输出只能是三类之一：

- `Adopt`：基本采用某个计划。
- `Hybrid`：明确借用哪些部分，形成一个新执行序列。
- `Revise first`：所有计划都缺关键事实或违反边界，先退回补计划。

## 输出格式

用短决策备忘录收口：

```md
Decision
- Adopt Plan A / Hybrid / Revise first.

Why
- 决定性证据和取舍。

Execution Plan
- 可执行步骤，列文件面或命令面。

Borrowed
- 从非获选方案保留的具体点。

Rejected
- 明确不采用的点和理由。

Verification
- 必跑测试、CLI/HTTP 验收、截图、CI 或 docs check。

Executor
- 主控执行还是 subagent 执行；若 subagent 执行，写清文件范围和停止条件。
```

如果用户已经授权执行，裁决后继续推进；否则停在决策备忘录，等待确认。
