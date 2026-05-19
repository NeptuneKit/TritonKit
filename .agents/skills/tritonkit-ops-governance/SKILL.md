---
name: tritonkit-ops-governance
description: TritonKit 流程治理：CLI/HTTP/Wails 开发回路、文档记忆写回、AGENTS 同步与 qmd 索引。
---

# TritonKit Operations & Governance

## CLI / HTTP / Wails 开发回路

- 需求变更先写 `docs-linhay/features/` 的 BDD 场景。
- 先补失败测试，再实现最小代码。
- HTTP handler 用 `httptest` 优先验证，只有进程生命周期或信号处理才启动真实 server。
- CLI 行为优先测试参数解析和命令分发，不在单元测试里长期占用端口。
- AI agent 首期只需要 CLI/HTTP 机器可读契约；能通过 CLI/HTTP 完成读取和控制时，不新增 Web/SSE 渲染入口。
- 设备控制参考 Baguette 时，先区分 embedded TritonKit runtime 与 macOS host-side adapter：embedded runtime 只能承诺公开 UIKit API 可验证的 in-app 控制；SimulatorKit / HID / Home / App Switcher 等设备级动作必须等 host-side adapter，当前要返回明确 unsupported。
- Wails 绑定先测绑定对象和 DTO；有真实 UI 后再补桌面窗口验收。
- 当前前端为空白 Wails 静态入口；任何恢复 UI 的工作必须先新建或更新 `space` 与 BDD 场景。
- Package Manager 集成时，embedded TritonKit runtime 只在 `DEBUG` 编译配置下生效；Release 下 API 保持可编译但 runtime 必须 no-op，不按端类型或 UIKit 可导入性决定是否启用。
- Package Manager 分发同时覆盖 SwiftPM 与 CocoaPods；CocoaPods 规格必须保留 `TritonKitShared` / `TritonKit` 两个 Swift module，避免 `TritonKit` 中的 `import TritonKitShared` 在 pod 集成时失效。
- 新增配置项时同步覆盖默认值、环境变量覆盖和非法值。
- 新增外部依赖时先说明必要性；首期优先 Go 标准库。
- GitHub CI / Release 必须同时产出 macOS arm64 / x86_64 `triton` CLI 包、checksum manifest 和项目级 skill 包；当前至少包含 `.agents/skills/tritonkit-dev-feedback` 与 `.agents/skills/tritonkit-real-project-regression`，便于外部使用者拿到开发阶段反馈流程和真实项目回归流程。
- `triton` CLI 的外部分发必须支持 Homebrew 二进制安装与更新；tag release 后用 GitHub Release 资产和 `tritonkit_checksums.txt` 渲染并更新 tap formula。

## 文档与记忆

- 需求与验收：`docs-linhay/features/`。
- 架构、技术方案、测试策略：`docs-linhay/dev/`。
- 关键决策、里程碑、风险结论：`docs-linhay/memory/YYYY-MM-DD.md`。
- 写回 docs 或 memory 后执行 `qmd update` 与 `qmd embed`。
- 调整 CI、Release 或发布产物契约时，同步更新 `docs-linhay/dev/` 与 memory。
- 调整 Homebrew、tap、checksum 或 release asset 命名时，同步更新 README、`.github/homebrew/`、`docs-linhay/dev/` 与 memory。

## AGENTS 同步

- 只有 repo-wide、长期稳定、每次都应遵守的规则才进入 `AGENTS.md`。
- 单个领域或流程的可复用动作优先进入 `.agents/skills/`。
- 新增 skill 前先判断是否能补充既有 skill，避免入口膨胀。
- skill 的 front matter `description` 只写触发场景和能力边界，详细规则写正文。

## Subagent 监督交付

- 只有用户明确要求 subagent / 并行 agent / 监督交付时才启用。
- 主控 agent 负责边界、拆分、集成、验证、文档和最终完成判断。
- subagent 任务必须有清晰写入面；多个 subagent 不应写同一批文件。
- 主控 agent 不把“代码已改完”当作完成，必须跑完验证与写回。

## 完成检查

- BDD 场景满足。
- 相关测试已运行并通过，或明确说明阻塞和风险。
- 文档与 memory 已更新。
- `qmd update` 与 `qmd embed` 已执行。
- 若产生可复用模式，已更新对应 skill 或说明暂不沉淀。
- 若任务要求“从头开始”，需同步检查 docs、skills 和 AGENTS 是否仍残留旧方向规则。
