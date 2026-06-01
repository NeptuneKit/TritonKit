# Round 07: Agent-Facing CLI Information Architecture

## 目标

正式进入方案 C 的信息架构阶段。第 7 轮只落技术方案和后续迁移边界，不改 CLI 行为，避免在没有权威架构文档前直接重排命令。

## 本轮完成

- 新增 `docs-linhay/dev/agent-facing-cli-information-architecture.md`：
  - 定义 `triton` 作为 AI agent 本机控制面的 10 个信息域：Bootstrap、Capabilities、Doctor、Target、Project/Xcode、Runtime、Observe、Action、Assert、Evidence/Replay。
  - 定义 agent 标准流程：`version -> schema -> doctor -> capabilities -> plan`。
  - 定义 target 选择流程：`target list -> resolve -> use -> current -> wait-ready`。
  - 定义 command schema、capabilities、doctor、plan、error envelope、evidence / replay 的机器可读契约。
  - 明确破坏性更新必须同步命令实现、schema、测试、README、public skills、dev 文档、checkpoint、memory 和 qmd。
  - 建立 Round 08 至 Round 14 的后续切片映射。
- 更新 `docs-linhay/spaces/20260527-command-surface-optimization/README.md`：
  - 将新架构文档加入当前 space 的关联文档。
- 更新 `docs-linhay/dev/ai-cli-readable-control.md`：
  - 标注长期信息架构以新文档为准，本文继续保留当前 CLI / HTTP / runtime 已实现契约与阶段性取舍。

## 验收

- 文档覆盖第 7 轮要求的新心智模型：
  - `schema`：命令事实源。
  - `capabilities`：环境能力源。
  - `doctor`：诊断恢复入口。
  - `target`：目标选择入口。
  - `project` / `xcode`：工程发现、构建、测试、运行入口。
  - `runtime` / `observe` / `webview`：观察入口。
  - `action`：动作入口。
  - `assert`：验收入口。
  - `evidence` / `record` / `replay`：证据与复跑入口。
- 文档没有新增历史迁移章节，保持面向当前绑定 CLI + skills 的目标契约。
- 本轮没有修改 CLI 行为，不需要 Swift 测试作为行为验收；收尾验证走 docs-only 门禁。

## 决策

- Round 07 只定义目标信息架构，不把现有命令立即改名或移动。
- 后续实现以新文档为权威目标，以 `triton schema --json` 为当前实际契约。
- 第 8 轮优先做 `target` 一等入口，因为 target resolver 是 app、runtime、observe、action、assert、evidence 的共同前置上下文。

## 风险

- 现有 README 与 public skills 仍大量使用 `device` / `sim` / 旧 target selector 口径；这是 Round 08 之后的迁移任务，本轮只建立迁移目标。
- `capabilities`、`doctor`、`plan` 当前实现仍未达到本文档目标形态，需要后续按 Round 09 至 Round 11 分批补测试和实现。

## 下一轮建议

进入 Round 08：建立 `target` 一等入口，优先通过测试锁定 `target list/use/current/resolve/wait-ready` 的 JSON shape，再迁移 `device` / `sim` 中属于目标选择的能力。
