# 20260524 Autonomous Evolution

## 背景

用户将离开一段时间，希望 TritonKit 进入“自动巡航进化”状态。该 space 用来约束长期规划、执行优先级、验收门禁和风险边界，避免无人值守期间把项目带偏。

当前仓库状态（2026-05-24）：

- 主仓 `main` 已领先 `origin/main` 1 个提交。
- 工作区存在 Xcode workflow takeover 相关未提交 WIP，包含 CLI、Shared models、测试和文档。
- 当前没有活跃 Web / Wails UI；继续坚持 CLI / HTTP / filesystem evidence 机器可读契约优先。
- 长期产品边界仍是本机 CLI + 本机 iOS Simulator / Android Emulator / HarmonyOS / DevEco Emulator + Debug-only embedded runtime。

## 目标

1. 把 TritonKit 从“可用的模拟器/运行时工具”推进成“agent 可长期依赖的本机回归控制面”。
2. 让 agent 面对未知 App 仓库时，可以完成发现、构建、运行、观察、操作、断言、证据归档和失败报告。
3. 所有演进都保持 BDD / TDD：先验收场景，再失败测试，再实现。
4. 每个阶段都输出机器可读契约、文档、记忆和可复跑验证命令。
5. 无人值守期间只做低风险、小步、可验证改动；遇到高风险动作时停下并记录阻塞。

## 非目标

1. 不默认恢复 Web / Wails 产品面。
2. 不做真机、远端 agent、设备云、多租户、Postgres / Kafka / webhook 平台化能力。
3. 不内置模型供应商 SDK，不把 TritonKit 变成 LLM agent runtime。
4. 不做破坏性 simulator / runtime 维护动作，除非有显式 dry-run、确认门禁和测试覆盖。
5. 不发布 tag、不推送 release、不修改 Homebrew tap，除非用户明确授权。
6. 不处理真实账号、密码、证书、签名资产或私有项目敏感信息。

## 自动巡航规则

1. 优先收敛现有 WIP，不在脏工作区上开启无关大改。
2. 每个切片必须能用 `docs-linhay/scripts/verify.sh --local` 或更小的等价测试命令验证。
3. CLI / HTTP schema 是事实入口；Web / Wails 只能消费只读 DTO，不能先定义业务控制面。
4. 证据优先落 filesystem portable artifact：JSON / JSONL / manifest / screenshot / logs。
5. 大文件和长任务输出只返回 path、bytes、truncation、summary，不内嵌到 CLI JSON。
6. 每次有关键决策、里程碑或风险结论，写入 `docs-linhay/memory/YYYY-MM-DD.md` 并执行 qmd 同步。
7. 若发现可复用流程，优先更新 `.agents/tritonkit-skills/`；只有 repo-wide 稳定规则才更新 `AGENTS.md`。

## 停止条件

自动巡航遇到以下情况必须暂停并等待用户：

1. 需要真实账号、密码、证书、Apple Developer 资产、GitHub token 或私有项目信息。
2. 需要 destructive action，例如 erase simulator、删除 runtime、重置 git、覆盖 release asset。
3. 需要推送分支、打 tag、发布 GitHub Release、更新 Homebrew tap。
4. 需要改变长期产品边界，例如启用 Web UI、真机默认路径、远端 agent 或云设备。
5. 本地验证连续失败且无法用小步回滚到清晰状态。

## BDD 验收场景

### 场景一：无人值守切片可追踪

- Given 用户离开且没有即时反馈
- When agent 选择下一个自动巡航任务
- Then 任务必须落入本 space 的路线图或已有 active space
- And 任务必须有明确验收场景、测试命令和回滚边界

### 场景二：机器可读契约优先

- Given 新增一个能力
- When agent 设计命令或接口
- Then 先定义 CLI / HTTP JSON 或 JSONL envelope
- And 测试覆盖 schema、错误码、artifact path 和边界输入

### 场景三：证据闭环

- Given 一次回归或 smoke 失败
- When agent 收集证据
- Then 产出 `.tritonevidence` 或等价目录
- And manifest、logs、screenshots、run events 可被离线读取

### 场景四：高风险动作暂停

- Given 下一步需要凭证、发布、删除或产品边界改变
- When agent 检测到风险
- Then 不继续执行该动作
- And 在 memory / plan 中记录阻塞原因和建议选项

## 关联资料

- 路线图：`docs-linhay/spaces/20260524-autonomous-evolution/plans/roadmap-v01.md`
- Xcode workflow takeover：`docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- Simulator takeover：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Harness UX run evidence：`docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`
- AI CLI readable control：`docs-linhay/dev/ai-cli-readable-control.md`
