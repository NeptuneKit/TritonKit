# Agent Workflow Skill Governance

## 来源与取舍

本轮参考 `BuilderIO/skills` 的工作流设计，但只吸收可迁移的 agent 协作模式：

- `agent-watchdog`：监督另一个 agent 的完成状态、重建原始需求、核对证据、报告缺口。
- `plan-arbiter`：把多个方案归一化后裁决为一个可执行方向。
- `plow-ahead`：用户授权自治推进时，把普通疑问转为假设，只有真实 blocker 才停。
- `efficient-frontier`：主控 agent 保留判断、集成和最终质量，subagent 负责可并行的扫描、窄实现、测试和日志归纳。
- `visual-recap`：把已发生 diff 总结成文件地图、契约变化、关键 diff 和风险说明。
- `read-the-damn-docs`：对第三方快速变化 API / CLI / 框架优先读官方文档或本地 schema。

不吸收的部分：

- 不把 Agent-Native hosted Plan 作为 TritonKit 默认工作面。
- 不把模型品牌绑定到 skill 名称或流程。
- 不照搬 emoji 状态 footer，避免与当前中文交付规范冲突。
- 不把内部治理规则发布进 `TritonKit.skills/`。

## TritonKit 本地化规则

### 监督审计

涉及 subagent、外部 agent、PR、branch、thread、日志或运行摘要时，主控 agent 先识别模式：

- `watch only`：只观察到完成或阻塞，不改文件。
- `audit`：只审计需求、diff、测试、CI、截图和最终声明，不改文件。
- `audit and fix`：先审计，再对证据明确的缺口做窄修复。
- `compare`：比较多个 agent / 分支 / 计划是否满足同一原始需求。

审计报告固定覆盖：原始要求、观察到的改动、证据、缺口、已修复项、剩余风险。

### 计划裁决

多方案并行时不要把不同计划机械拼接。先把每个计划归一化为目标、假设、文件面、执行顺序、验证、风险和成本，再按以下优先级裁决：

1. 正确满足用户请求和 TritonKit 产品边界。
2. 事实依据来自真实文件、schema、测试、截图或官方文档。
3. 首个实现更小、更可回滚。
4. 验证和回滚路径更明确。
5. 质量相当时，优先选择执行成本更低的路径。

### 自治推进

用户授权无人值守、巡航或“你来负责”后，普通不确定性应转成明确假设继续推进。只有以下情况停止：

- 需要凭据、账号、私有数据或生产权限。
- 下一步是破坏性、不可逆或生产变更。
- 需要未授权的 branch/history 操作、force push、删除。
- 安全、隐私、法律或公开发布风险无法用保守本地选择降低。
- 用户明确保留某个决策。
- 同一验证失败经合理调查仍重复，下一步只能靠大范围猜测。

长任务按 wave 推进，默认不超过 3 个并行 subagent；每波结束后主控复核关键证据，再决定是否继续。

### 本地 visual recap

当 PR、branch、worktree 或一次会话改动较大，尤其触及 CLI schema、HTTP contract、release、模拟器接管、Web mock 或多端集成时，优先生成本地 recap 文档，而不是内联长总结。

默认落位：

- 单需求：`docs-linhay/spaces/<space-key>/plans/<YYYYMMDD>-recap-v01.md`
- 项目级治理：`docs-linhay/dev/<YYYYMMDD>-<topic>.md`

推荐结构：

1. 目标和范围。
2. 文件地图。
3. CLI / HTTP / schema / release / UI 契约变化。
4. 关键 diff 或关键代码引用。
5. 验证证据。
6. 审查风险和后续项。

### 官方文档优先

涉及 Xcode、SwiftPM、CocoaPods、Homebrew、GitHub Actions、Android Emulator、ADB、Harmony / DevEco、HDC、OpenAI / 其他模型 SDK 或其他快速变化第三方 API 时，优先读取本地 repo 文档、schema、生成类型、官方文档或官方 release notes。不要凭模型记忆写安装、配置、权限、认证、限制或迁移契约。

## 落地文件

- 新增：`.agents/skills/tritonkit-plan-arbiter/SKILL.md`
- 更新：`.agents/skills/tritonkit-subagent-supervision/SKILL.md`
- 更新：`.agents/skills/tritonkit-autonomous-cruise/SKILL.md`
- 更新：`.agents/skills/tritonkit-ops-governance/SKILL.md`

## 验证

本轮为 docs / internal skill 治理变更，不运行 Swift / Web 产品测试。验证以以下门禁为准：

- skill front matter 基础校验。
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`

## Skill 瘦身决策

后续瘦身按“复用流程留 skill，一次性拆单回 space plan”的原则执行：

- 合并 `tritonkit-android-subagent-orchestration` 与 `tritonkit-real-device-subagent-orchestration` 为 `tritonkit-device-subagent-orchestration`。两个旧 skill 都是设备类 subagent track 的执行包装，结构相同，适合由一个 router skill 按 track 读取对应 space plan。
- 移除 `.agents/skills/apple-docs` symlink。Apple 文档查询是通用本机 skill，来源仍在用户级 / 外部 skill 目录；TritonKit 仓库 `.agents/skills/` 只保留真实目录形式的项目治理、实现、监督和规划 skill。
- 合并 `tritonkit-session-skill-distill` 进 `tritonkit-ops-governance`。保留“整理 / 沉淀”触发词和收尾隔离、SwiftPM / CLI 修复沉淀规则，但由 ops governance 统一承载文档、memory、skill 和 AGENTS 同步边界，减少一个只做治理分流的独立入口。
