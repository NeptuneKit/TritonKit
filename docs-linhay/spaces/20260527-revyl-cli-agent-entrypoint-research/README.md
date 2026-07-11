# 20260527 Revyl CLI Agent Entrypoint Research

## 背景

用户要求对 `RevylAI/revyl-cli` 做深度研究，并将可借鉴方向沉淀为 TritonKit 的需求和执行计划。

本地参考源码已归档到 `docs-linhay/references/revyl-cli/`，当前 clone HEAD 为 `9931a77`。既有调研文档见 `docs-linhay/references/revylai.md`。

Revyl CLI 的核心参考价值不在云设备平台本身，而在它把 AI agent 使用路径产品化成一条完整链路：

1. CLI onboarding：`doctor`、`init`、`config`、`build`、`dev`、`test`、`workflow`、`device`。
2. Agent skills：`skill list/install/show/export`，并按 Codex、Claude Code、Cursor 安装到不同目录。
3. MCP surface：`mcp serve --profile core|full`，用少量 composite tools 覆盖高频 journey，避免 agent 面对过多平铺工具。
4. Machine-readable schema：从 Cobra 命令树生成 CLI schema，并补 common workflows。
5. Run artifact projection：把 report、steps、failed step、artifact availability 投影成统一 summary。
6. 状态治理：集中定义 queued/running/completed/failed/cancelled/timeout 等执行状态和 success 推断。
7. CI / examples：提供 GitHub Actions、generic CI、PR review playbook 和 YAML test 示例，让使用者能复用完整 workflow。

TritonKit 当前产品边界仍是本机 CLI + 本机模拟器/仿真器 + embedded runtime，不引入云设备、账号体系、远端 agent、多租户或 Web/Wails UI。因此本 space 的目标是“借鉴 agent entrypoint 工程化模式”，不是照搬 Revyl 的平台路线。

## 研究对象

### 已重点阅读的 Revyl 源码/文档

- `docs-linhay/references/revyl-cli/README.md`
- `docs-linhay/references/revyl-cli/docs/COMMANDS.md`
- `docs-linhay/references/revyl-cli/docs/integrations/skills.md`
- `docs-linhay/references/revyl-cli/cmd/revyl/skill.go`
- `docs-linhay/references/revyl-cli/internal/skillcatalog/catalog.go`
- `docs-linhay/references/revyl-cli/cmd/revyl/mcp.go`
- `docs-linhay/references/revyl-cli/internal/mcp/composite_tools.go`
- `docs-linhay/references/revyl-cli/internal/schema/cli_schema.go`
- `docs-linhay/references/revyl-cli/internal/runinspect/summary.go`
- `docs-linhay/references/revyl-cli/internal/status/status.go`
- `docs-linhay/references/revyl-cli/examples/`
- `docs-linhay/references/revyl-cli/skills/`

### 与 TritonKit 的对齐点

| Revyl 模式 | TritonKit 可借鉴方向 | 优先级 |
| --- | --- | --- |
| `revyl skill list/install/show/export` | `triton skill list/install/show/export`，安装 public TritonKit skills 到 Codex/Claude/Cursor | P0 |
| `mcp serve --profile core/full` | `triton mcp serve --profile core/full` 或等价 agent tool profile，默认只暴露核心闭环 | P1 |
| CLI schema 自动生成 + workflows | 强化 `triton schema`，输出命令、flags、错误码、common workflows、示例 | P0 |
| run summary | `triton evidence summary --json`，统一 pass/fail、失败点、artifact availability | P0 |
| status package | 收敛 CLI/HTTP/evidence/replay 状态和 success 推断 | P0 |
| dev context | named host device/app context，服务多 worktree、多模拟器并行 | P1 |
| CI examples | `examples/ci-*` 和 PR comment 模板，推动真实项目回归接入 | P1 |
| Auth bypass skill family | 对外 skill 中增加 iOS/Harmony Debug-only test hook 指南，但不内置业务绕过 | P2 |

## 产品目标

当前决策：本 space 只作为参考研究与 backlog 归档，暂不进入代码实现。

让 TritonKit 的 agent 入口从“有很多机器可读命令”升级为“可安装、可发现、可校验、可复跑的一组 agent workflow”。

目标不是新增 UI，而是让 Codex / Claude / Cursor / CI 能通过稳定入口完成：

1. 发现 TritonKit 能力和当前版本。
2. 安装/刷新与 CLI 版本匹配的 public skills。
3. 获取当前 CLI command schema、核心 workflow 和错误码。
4. 运行本机 simulator/emulator 回归后，读取统一 summary。
5. 在失败时拿到明确状态、失败步骤、artifact availability 和下一步建议。
6. 在 CI 中复用同一套命令，产出 evidence artifact 和 PR/issue comment。

## 范围

### In Scope

1. 设计并实现 `triton skill list/show/export/install`。
2. 将 `TritonKit.skills/` 的 skill catalog 显式建模，包含 name、description、version、visibility、source path、install targets。
3. 支持安装到 Codex、Claude Code、Cursor 的项目级目录；user-level/global 安装可作为后续增强。
4. 强化 `triton schema` 的 agent-facing 输出：命令树、flags、examples、common workflows、错误码和 public skill hints。
5. 新增或强化 `triton evidence summary --json`，把 `.tritonevidence` manifest、steps、assertions、artifacts 投影成稳定 summary。
6. 建立共享 execution status / result model，统一 active、terminal、success、failure、timeout、cancelled 的判断。
7. 设计 `triton mcp serve --profile core/full` 的范围和工具分组；本期可先出设计与 schema，不强制实现完整 MCP。
8. 新增真实项目/CI 接入示例：本机 CLI install、device/app run、capture/assert、artifact upload、comment summary。
9. 同步 README、public skills、`docs-linhay/dev/`、memory 与 文档记录。

### Out of Scope

1. 不引入 Revyl 账号、云设备、build upload、dashboard、远端 agent 或多租户服务。
2. 不恢复 Web/Wails UI。
3. 不把自然语言 target 作为唯一交互契约；TritonKit 仍坚持 AX/text/role/bounds/index/within 等可审计 selector。
4. 不在本 space 内实现 screenshot visual regression、Figma diff、AI BFS exploration 或 PR bot 全自动评审；这些应另建 space。
5. 不改变 Homebrew release asset 的既有契约，除非 skill install 需要读取已发布版本信息。
6. 不把 MCP 作为唯一入口；CLI/JSON 仍是事实控制入口。

## BDD 验收

### 场景一：agent 查看可安装 skills

- Given 本地安装了 `triton`
- When 执行 `triton skill list --json`
- Then 输出单个 JSON object
- And `skills[]` 至少包含 `tritonkit-dev-feedback`、`tritonkit-real-project-regression`、`tritonkit-emulator-cli-takeover`
- And 每个 skill 包含 `name/version/description/visibility/source/installTargets`

### 场景二：agent 导出单个 skill

- Given public skill `tritonkit-real-project-regression` 存在
- When 执行 `triton skill export tritonkit-real-project-regression --output /tmp/skill/SKILL.md --json`
- Then 文件被写出
- And JSON 输出包含 `ok=true/name/output/checksum`
- And 导出的 front matter version 与当前 CLI build info 或 packaged skill version 一致

### 场景三：agent 安装 skills 到项目级 Codex 目录

- Given 当前目录是一个业务 App repo
- When 执行 `triton skill install --codex --project --force --json`
- Then `.codex/skills/<skill-name>/SKILL.md` 被创建或刷新
- And JSON 输出列出 installed、updated、skipped、targetRoot
- And 不覆盖非 TritonKit-owned skill

### 场景四：CLI schema 提供核心 workflows

- Given agent 需要知道如何完成本机回归
- When 执行 `triton schema --json`
- Then 输出包含 command schema、global flags、error codes、common workflows
- And workflows 至少覆盖 `doctor -> device list/use -> app launch -> capture/assert -> evidence summary`

### 场景五：evidence summary 可直接判断回归结果

- Given 已存在 `.tritonevidence` 目录
- When 执行 `triton evidence summary --input <dir.tritonevidence> --json`
- Then 输出包含 `ok/runSuccess/status/failedStepIndex/artifacts`
- And artifact availability 至少覆盖 screenshot、AX/layout、logs、manifest
- And 失败时返回可操作 hint，而不是要求 agent 直接遍历全部文件

### 场景六：MCP core profile 不暴露过量工具

- Given 后续实现 `triton mcp serve --profile core`
- When agent 查询工具列表
- Then core profile 只包含 device/app/evidence/assert/schema/doctor 等核心 composite tools
- And full profile 才包含高级管理或实验性工具

### 场景七：CI 示例可复跑

- Given 一个接入 TritonKit 的真实项目
- When 复制示例 GitHub Actions workflow
- Then CI 能安装 `triton`、运行本机可用的 smoke 或跳过不可用设备、上传 evidence artifact
- And 产出 Markdown summary，明确 pass/fail、artifact path 和复现命令

## 非功能要求

1. 所有 agent-facing 命令默认或通过 `--json` 输出单个 JSON object；长任务可用 JSONL，但必须有明确 schema。
2. skill 安装命令必须幂等，可 dry-run，可 force，可明确 skipped 原因。
3. 不得删除用户已有 skill；只管理 TritonKit-owned 目录或带明确 marker 的文件。
4. 错误码必须稳定，至少覆盖 `skill_not_found`、`unsupported_agent_target`、`permission_denied`、`invalid_evidence`、`schema_unavailable`。
5. 对外 public skill 的版本要与 CLI release 产物保持一致。
6. 文档必须把“本机 CLI/HTTP 优先、无云设备假设、无 Web UI 假设”写清楚。

## 深度研究结论

### 1. Skill 是产品能力，不只是仓库文档

Revyl 的 `skillcatalog` 把 public、default install、legacy/internal skill 分开，并提供 deterministic order。TritonKit 目前已经有 public skills 包和 release asset，但用户仍需要知道路径或手动安装。下一步应让 `triton` 自己成为 skill 分发入口。

### 2. Profile 化比平铺工具更适合 agent

Revyl MCP 早期保留 flat tools，但推荐 `core/full` profile。TritonKit 如果对 MCP 或 tool surface 扩展，应默认 profile 化，避免 agent 同时看到几十个低层动作。CLI/HTTP schema 仍保留完整能力，MCP 是“精选入口”。

### 3. Summary projection 能降低 agent 决策成本

Revyl 的 run summary 不要求 agent 先理解全部 artifact，而是先回答“是否成功、失败在哪、还有哪些证据”。TritonKit 的 `.tritonevidence` 已经适合作为证据包，但还需要一个 summary layer，让 agent 在真实项目回归里先读摘要，再按需打开具体 artifact。

### 4. 状态模型要集中，否则 success 判断会漂移

Revyl 把 terminal/active/success 推断集中管理。TritonKit 的 CLI、HTTP runtime、capture、assert、replay、evidence 都会产生状态，若各自判断，会让 CI 和 agent 出现不同结论。本 space 应先定义共享模型，再让命令逐步迁移。

### 5. Onboarding 命令要同时服务人和 agent

Revyl 的 `doctor/init/config/dev` 很强调新手体验，但它同时给 CI/agent 提供检测和修复路径。TritonKit 可以不做交互 wizard，但 `doctor/preflight/schema` 应提供机器可读 hints，告诉 agent 缺什么、下一步该跑什么。

## 暂不沉淀为 AGENTS 的规则

本 space 当前是需求和执行计划，不直接修改 repo-wide AGENTS 规则。只有当 `triton skill`、`evidence summary`、`mcp profile` 等能力落地并成为长期默认入口后，再评估是否把“agent entrypoint 工程化”写入 AGENTS。

## 当前状态

2026-05-27：研究、需求和计划已归档；当前不启动实现，不创建 worktree，不占用 active roadmap。

## 执行计划

详见 [implementation-plan-v01.md](plans/implementation-plan-v01.md)。

## 2026-07-11 路线裁决

- 状态：废弃。
- 原 M1-M6 不再作为独立 roadmap 执行。
- 研究中的 skill、schema、evidence summary、update 和 agent workflow 价值已被后续实现及 Agent Mobile Runtime Platform 吸收。
- 保留本 space 和参考源码作为历史研究材料；未来不得直接按旧计划恢复实现。
