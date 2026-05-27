# Agent Entrypoint Engineering

## 来源

本设计来自 `docs-linhay/spaces/20260527-revyl-cli-agent-entrypoint-research/` 对 `RevylAI/revyl-cli` 的深度研究。

本地参考源码：

- `docs-linhay/references/revyl-cli/`
- Clone HEAD：`9931a77`

## 设计目标

当前状态：本文是参考研究后的技术设计入口，暂不代表当前 active roadmap，后续只有重新启动该 space 时才进入实现。

TritonKit 的 agent 入口应同时满足两类调用者：

1. AI agent：需要稳定、低歧义、机器可读、可恢复的命令和 artifacts。
2. CI / 自动化脚本：需要可复跑、可判断 pass/fail、可上传证据、可生成摘要的流程。

因此 agent entrypoint 不是一个单独命令，而是一组产品化入口：

- `triton skill`：安装、导出、刷新 public skills。
- `triton schema`：暴露命令、flags、错误码、common workflows。
- `triton evidence summary`：把证据包投影成统一摘要。
- 共享 execution status model：统一 success / terminal / active 判断。
- 可选 `triton mcp serve --profile core/full`：为支持 MCP 的 agent 暴露精选工具面。
- CI examples：把本机回归链路变成可复制 workflow。

## 与 Revyl 的差异

Revyl 的产品路线包括账号、云设备、build upload、dashboard 和远端 report。TritonKit 当前不采用这些方向。

TritonKit 的差异化边界保持不变：

1. 本机 CLI 优先。
2. 本机 iOS Simulator / Android Emulator / HarmonyOS DevEco Emulator。
3. embedded runtime + host adapter + machine-readable schema。
4. CLI/HTTP 是事实控制入口。
5. Web/Wails 不承载业务控制闭环。

## 命令分层

### Core commands

这些命令应优先面向 agent 稳定：

- `triton doctor`
- `triton schema`
- `triton device`
- `triton app`
- `triton capture`
- `triton assert`
- `triton evidence`
- `triton skill`

### Advanced commands

这些命令可以保持完整能力，但不应成为新 agent workflow 的首选入口：

- `triton sim`
- `triton xcode`
- `triton webview`
- `triton plan`
- `triton replay`
- 平台专属调试命令

## Skill catalog 契约

`triton skill` 应从 `.agents/tritonkit-skills/public/` 建立 catalog。

建议字段：

- `name`
- `description`
- `version`
- `visibility`
- `sourcePath`
- `checksum`
- `installTargets`

首批命令：

```bash
triton skill list --json
triton skill show <name> --json
triton skill export <name> --output <path> --json
triton skill install --codex --project --force --json
triton skill install --claude --project --force --json
triton skill install --cursor --project --force --json
```

安全约束：

1. 默认只写项目级目录。
2. 支持 `--dry-run`。
3. 只覆盖 TritonKit-owned skill。
4. 非 `--force` 时不覆盖已有文件。
5. JSON 输出必须列出 installed、updated、skipped、targetRoot。

## Schema workflows

`triton schema --json` 不应只列命令树，还应提供 agent 能直接使用的 workflow。

首批 common workflows：

1. 本机设备回归：`doctor -> device list/use -> app launch -> capture/assert -> evidence summary`
2. Xcode 回归：`xcode discover -> xcode build/test/run -> app launch -> capture`
3. Runtime direct control：`device runtime-url -> snapshot -> tap/type -> assert`
4. Evidence inspection：`evidence validate -> evidence summary -> artifact inspect`
5. Skill onboarding：`skill list -> skill install -> schema`

## Evidence summary

`.tritonevidence` 是证据包，`evidence summary` 是 agent 和 CI 的第一阅读入口。

摘要应回答：

1. 这次回归是否成功？
2. 失败发生在哪一步？
3. 有哪些 artifact 可用？
4. 复现命令是什么？
5. 下一步建议是什么？

建议输出：

```json
{
  "ok": true,
  "evidence": {
    "case": "checkout-smoke",
    "status": "completed",
    "runSuccess": true,
    "totalSteps": 6,
    "failedSteps": 0,
    "failedStepIndex": null,
    "artifacts": {
      "manifest": true,
      "screenshots": true,
      "layout": true,
      "logs": false
    },
    "replayCommand": "triton replay ..."
  }
}
```

## Execution status model

建议集中定义执行状态：

- active：`queued`、`starting`、`running`、`verifying`、`stopping`
- terminal：`completed`、`failed`、`cancelled`、`timeout`
- result：`passed`、`failed`、`skipped`、`unknown`

判断原则：

1. 显式 `success` / `runSuccess` 优先。
2. `completed` 只表示流程完成，不天然等于业务成功。
3. failed steps、failed assertions、timeout、cancelled 都不能推断为成功。
4. 未知状态默认 `unknown`，不伪装为通过。

## MCP profile

如果后续实现 MCP，采用 profile 化而不是工具平铺。

Core profile 候选：

- `doctor`
- `manage_device`
- `manage_app`
- `observe`
- `act`
- `assert`
- `evidence`
- `schema`

Full profile 可再加入：

- `xcode`
- `sim`
- `webview`
- `plan/replay`
- `skill`
- `config`

MCP 不绕过 CLI/HTTP 事实入口。每个 MCP action 应能映射回 CLI command 或 HTTP route。

## 实施优先级

1. `triton skill list/show/export/install`
2. `triton evidence summary --json`
3. 共享 execution status model
4. `triton schema` workflows/error codes/skill hints
5. CI / PR examples
6. MCP profile 设计和最小实现评估

## 不做事项

1. 不引入云设备。
2. 不引入账号体系。
3. 不引入 dashboard。
4. 不把自然语言 target 作为唯一 selector。
5. 不恢复 Web/Wails UI。
6. 不把 MCP 设为唯一入口。
