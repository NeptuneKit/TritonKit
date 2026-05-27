# 20260527 Revyl CLI Agent Entrypoint Research - Implementation Plan v01

## 目标

把 Revyl CLI 的可借鉴模式转化为 TritonKit 的 agent entrypoint 迭代计划：优先补齐 skill 分发、schema/workflow、evidence summary、状态模型和 CI 示例，再评估 MCP profile 与 named context。

## 当前状态

已完成：

1. `RevylAI/revyl-cli` 已克隆到 `docs-linhay/references/revyl-cli/`，HEAD `9931a77`。
2. `docs-linhay/references/revylai.md` 已有产品/架构层参考归档。
3. TritonKit 已具备 public skills 包、CLI/JSON-first、evidence、capture/assert、device/app/xcode 等基础能力。

未完成：

1. `triton` 尚无 skill list/install/export 命令。
2. `triton schema` 尚未系统输出 common workflows、错误码和 skill hints。
3. `.tritonevidence` 尚缺面向 agent/CI 的统一 summary projection。
4. CLI/HTTP/evidence/replay 状态尚未集中成共享 execution status model。
5. MCP profile 还没有进入 TritonKit 正式产品边界。

当前决策：本计划仅作为 backlog 执行蓝图保存，暂不启动 M1-M6 实现。

## 本轮成功标准

1. 需求边界已在 space 中明确，且不偏离本机 CLI / 本机模拟器产品边界。
2. P0 实现项能拆成小步 TDD：skill catalog、skill export/install、schema workflows、evidence summary、status model。
3. 每个实现项都有测试入口、文档入口和回归命令。
4. 不把 Revyl 的云设备、账号、dashboard、build upload 路线带入本期。
5. 文档、memory、qmd 同步完成。

## 里程碑

### M0. 需求冻结与契约草案

产出：

- 本 space README。
- 本 implementation plan。
- `docs-linhay/dev/agent-entrypoint-engineering.md`，描述 agent entrypoint 的目标模型、命令分层和与 Revyl 的差异。

验收：

- `docs-linhay/scripts/check-docs.sh` 通过。
- `qmd query "Revyl CLI agent entrypoint"` 能检索到本 space 或 memory。

### M1. Public skill catalog 与 skill 命令

目标：

- 新增 `triton skill list/show/export/install`。
- skill catalog 从 `.agents/tritonkit-skills/public/` 建模，不依赖手写散落逻辑。
- 支持 Codex / Claude Code / Cursor 项目级安装。

建议 TDD：

1. 先写 `SkillCatalogTests`：
   - 能发现 public skills。
   - 能读取 front matter `name/description/metadata.version`。
   - 能按 deterministic order 输出。
2. 先写 CLI tests：
   - `skill list --json` 输出合法 envelope。
   - `skill show <name> --json` 找不到时返回 `skill_not_found`。
   - `skill export <name> --output <path> --json` 写出文件和 checksum。
   - `skill install --codex --project --dry-run --json` 不写文件但列出计划。
3. 再实现最小 runtime：
   - 只支持项目级安装。
   - 先不做 global install。
   - 只管理 TritonKit-owned skill 名称。

验证命令：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter Skill
.build/cli/debug/triton skill list --json
.build/cli/debug/triton skill show tritonkit-real-project-regression --json
.build/cli/debug/triton skill export tritonkit-real-project-regression --output /tmp/triton-skill/SKILL.md --json
.build/cli/debug/triton skill install --codex --project --dry-run --json
```

文档同步：

- README：安装/刷新 public skills。
- `.agents/tritonkit-skills/public/*/SKILL.md`：必要时补最新命令示例。
- `docs-linhay/dev/agent-entrypoint-engineering.md`：记录 skill catalog 契约。

### M2. Schema workflows 与错误码

目标：

- 强化 `triton schema --json`。
- 增加 common workflows、错误码、输出模式说明和 skill hints。

建议 TDD：

1. Schema 输出包含 `workflows[]`，每个 workflow 包含 `name/description/steps/expectedArtifacts`。
2. Schema 输出包含 `errorCodes[]`，至少覆盖 skill/evidence/runtime/device 常见错误。
3. Schema 中 public skill hints 与 M1 catalog 一致。

首批 workflows：

- `doctor -> device list/use -> app launch -> capture/assert -> evidence summary`
- `xcode discover -> xcode build/test/run -> app launch -> capture`
- `runtime-url -> snapshot -> tap/type/assert`
- `evidence validate -> evidence summary -> artifact inspect`

验证命令：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter Schema
.build/cli/debug/triton schema --json
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command skill --json
```

### M3. Evidence summary projection

目标：

- 新增或强化 `triton evidence summary --input <dir.tritonevidence> --json`。
- 对 agent/CI 先输出摘要，再按需读取 manifest、screenshots、AX/layout、logs。

建议模型：

```json
{
  "ok": true,
  "evidence": {
    "case": "checkout-smoke",
    "path": "checkout.tritonevidence",
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

建议 TDD：

1. fixture evidence 通过 summary 输出 pass。
2. 缺 manifest 返回 `invalid_evidence`。
3. failed assertion 能设置 `runSuccess=false/failedStepIndex`。
4. artifact availability 不要求打开大文件。

验证命令：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter EvidenceSummary
.build/cli/debug/triton evidence summary --input <dir.tritonevidence> --json
```

### M4. Execution status model

目标：

- 统一 capture/assert/replay/evidence/runtime 相关状态。
- 避免 CLI、CI、agent 各自推断 pass/fail。

建议状态：

- active：`queued`、`starting`、`running`、`verifying`、`stopping`
- terminal：`completed`、`failed`、`cancelled`、`timeout`
- result：`passed`、`failed`、`skipped`、`unknown`

建议 TDD：

1. success 字段显式存在时优先。
2. `completed` + failed steps > 0 仍为失败。
3. `timeout/cancelled` 不推断为成功。
4. 未知状态默认不标成功。

迁移策略：

- 先新增 shared model 和 tests。
- 再让 evidence summary 使用。
- 最后逐步接入 replay/capture/assert 输出。

### M5. MCP profile 设计与最小实现评估

目标：

- 先出设计，不急着引入对外 API 承诺。
- 若实现，默认 `core` profile 只暴露少量 composite tools。

Core profile 候选：

- `doctor`
- `manage_device`
- `manage_app`
- `observe`
- `act`
- `assert`
- `evidence`
- `schema`

Full profile 候选：

- `xcode`
- `sim`
- `webview`
- `plan/replay`
- `skill`
- `config`

验收：

- `core` profile 工具数保持小而稳定。
- 每个 composite tool 的 action 列表与 CLI schema 可互相映射。
- MCP 不绕过 CLI/HTTP 事实入口。

### M6. CI / PR example templates

目标：

- 给真实项目接入提供可复制示例。
- 不依赖云设备；只用本机可用 runner 和清晰 skip 策略。

交付：

- `examples/ci-github-actions/triton-smoke.yml`
- `examples/pr-comment/triton-evidence-summary.md`
- README 链接入口
- public skill 中补“CI artifact + summary comment”路径

验收：

- workflow 能在无 simulator 时明确 skip 或 fail-fast hint。
- 有 simulator/runtime 时产出 `.tritonevidence` artifact。
- comment summary 包含 pass/fail、artifact、复现命令。

## 推荐执行顺序

1. M0：文档和设计冻结。
2. M1：先做 `triton skill`，因为它直接改善 agent 使用入口，风险低。
3. M3 + M4：先做 evidence summary 和 status model，服务真实回归闭环。
4. M2：强化 schema，把 skill/evidence/status 串起来。
5. M6：补 CI examples，让外部项目能复用。
6. M5：最后评估 MCP profile，避免过早承诺新接口面。

## 测试门禁

每个代码阶段至少满足：

```bash
swift test --package-path CLI --scratch-path .build/cli
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

涉及 release/skill 包时追加：

```bash
docs-linhay/scripts/verify.sh --ci-docs
docs-linhay/scripts/verify.sh --local
```

若某阶段只改文档：

- 跑 `docs-linhay/scripts/check-docs.sh`
- 跑 `docs-linhay/scripts/qmd-sync.sh`
- 明确说明未运行 Swift tests 的原因

## 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| skill install 覆盖用户文件 | 破坏用户本地 agent 配置 | 只管理 TritonKit-owned skill 名称，写入前检测，支持 dry-run/force |
| schema 输出过大 | agent 难以消费 | 支持 `--command`、profile、summary/workflows 单独查询 |
| evidence summary 与真实 manifest 漂移 | CI 判断不可信 | summary 基于 manifest schema 和 fixtures 测试，缺字段时降级为 unknown |
| MCP surface 过早扩大 | 维护成本上升 | 先设计 profile，CLI/HTTP 仍为事实入口 |
| 误学 Revyl 云平台路线 | 偏离 TritonKit 产品边界 | 本 space 明确 out of scope，任何云/账号/dashboard 另建 space |

## 文档收尾清单

- 更新本 space README 与计划进展。
- 新增或更新 `docs-linhay/dev/agent-entrypoint-engineering.md`。
- 更新 README 的 agent/skill/evidence 入口。
- 更新 public skills。
- 写入 `docs-linhay/memory/YYYY-MM-DD.md`。
- 执行 `docs-linhay/scripts/check-docs.sh`。
- 执行 `docs-linhay/scripts/qmd-sync.sh`。

## 当前状态

2026-05-27：已完成深度研究、space 需求文档和执行计划初版。当前不进入代码实现。
