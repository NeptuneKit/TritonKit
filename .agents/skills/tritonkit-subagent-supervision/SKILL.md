---
name: tritonkit-subagent-supervision
description: TritonKit 监督交付模式：用户要求 subagent 实做且主控 agent 监督闭环时触发。
---

# TritonKit Subagent Supervision

当用户明确要求“用 subagent 做、主控 agent 负责监督到完成”时，默认进入本模式。

## 目标

1. subagent 负责边界清晰的实现任务。
2. 主控 agent 负责需求边界、任务拆分、集成、验证、文档、memory 和最终完成判断。

## 执行顺序

1. 先确认需求文档、范围和验收标准。
2. 按写入面拆分 subagent 任务，避免冲突。
3. 主控 agent 持续集成 subagent 结果，不等到最后统一收口。
4. 跑完整个需求闭环后才停止：
   - 代码集成
   - 自动化验证
   - HTTP 接口或端到端验收
   - docs / memory 写回
   - `qmd update`
   - `qmd embed`
5. 如果仍有未完成项，继续推进；如果卡住，明确写出 blocker 和剩余工作。

## 停止条件

只有以下情况可以停止：

1. 需求已经完整闭环。
2. 用户明确暂停。
3. 当前环境存在无法自行解决的具体 blocker。

“代码已改完”不是停止条件。
