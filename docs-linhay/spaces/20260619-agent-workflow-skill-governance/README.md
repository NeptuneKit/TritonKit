# Agent Workflow Skill Governance

## 背景

用户要求评估并吸收 `BuilderIO/skills` 中适合 TritonKit 的 agent 工作流模式。
本轮不直接复制外部 skill 包，而是把可复用模式本地化到 TritonKit 内部治理 skill 和文档中。

## 目标

1. 增强主控 agent 对 subagent / 外部 agent 工作的监督、审计和窄修复规则。
2. 新增多方案 / 多 agent 计划裁决入口，避免并行方案最后混成不可执行的折中稿。
3. 强化自动巡航和无人值守推进的自治边界、停止条件、决策复盘和分波推进规则。
4. 明确 visual recap 只吸收结构化复盘思想，默认使用本地 `docs-linhay` 产物，不引入 hosted Plan 依赖。
5. 明确涉及第三方快速变化工具链时的官方文档优先规则。

## 范围

包含：

- `.agents/skills/` 内部维护 skill 的新增和更新。
- `docs-linhay/dev/` 研发治理文档。
- `docs-linhay/memory/` 当日记忆追加。

不包含：

- 不修改 `TritonKit.skills/` 对外发布 skill 包。
- 不引入 BuilderIO / Agent-Native hosted Plan MCP 作为项目默认依赖。
- 不修改 CLI / HTTP / Web / Wails 产品代码。
- 不修改 `AGENTS.md`，除非后续证明这些规则已经稳定为 repo-wide 强约束。

## 验收标准

1. 新增内部 `tritonkit-plan-arbiter` skill，覆盖多 agent / 多方案裁决场景。
2. `tritonkit-subagent-supervision` 吸收 watchdog 模式：watch only、audit、audit and fix、compare，以及证据审计报告结构。
3. `tritonkit-autonomous-cruise` 吸收 plow-ahead / efficient-frontier 的自治推进和分波协作规则。
4. `tritonkit-ops-governance` 记录本地 visual recap、docs-first 和内部 / public skill 边界。
5. `docs-linhay/dev/` 有一份可检索的吸收决策文档。
6. 文档结构检查、skill 基础校验和 `git diff --check` 通过，或明确说明阻塞。

## P1 Skill 瘦身

目标：

1. 把 Android Emulator 和 cross-platform real-device 两个历史 subagent orchestration skill 合并为一个设备类 router skill。
2. 将历史 plan 中的旧 skill 路径更新为新统一入口。
3. 从 `.agents/skills/` 移除 `apple-docs` symlink，保留外部 / 用户级 Apple 文档 skill 来源。

验收：

1. `.agents/skills/` 中不再存在 `tritonkit-android-subagent-orchestration`、`tritonkit-real-device-subagent-orchestration` 和 `apple-docs`。
2. 新增 `tritonkit-device-subagent-orchestration`，覆盖 Android Emulator 与 real-device 两个 track。
3. `.agents/skills/README.md`、相关 space plan 和 dev 治理文档引用新入口。

## P2 Session Distill 合并

目标：

1. 将 `tritonkit-session-skill-distill` 的“整理 / 沉淀”触发、收尾隔离和 SwiftPM / CLI 修复沉淀规则并入 `tritonkit-ops-governance`。
2. 更新 `AGENTS.md` 与内部 skill 交叉引用，避免删除独立 skill 后触发链断开。
3. 删除 `.agents/skills/tritonkit-session-skill-distill/`，减少只做治理分流的入口。

验收：

1. `rg "tritonkit-session-skill-distill" AGENTS.md .agents docs-linhay/dev/20260619-agent-workflow-skill-governance.md docs-linhay/spaces/20260619-agent-workflow-skill-governance/README.md` 不再命中非历史说明。
2. `tritonkit-ops-governance` description 明确覆盖“整理 / 沉淀”触发。
3. skill front matter 校验、`git diff --check` 和文档结构检查完成，或明确说明既有 blocker。
