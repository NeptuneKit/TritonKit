# Checkpoint Integration Arbitration v01

## Decision

**Revise first：不直接把现有本地 checkpoint 合入 `main`；先以当前 `main` 为唯一集成基线，完成编号、产品边界、文件重叠与验证方案的重审。**

- `SP-141-packaged-web-simulator-input` 是已发布并登记在当前 `main` 的唯一合法 SP-141；保留旧 `feat/SP-141-schema-fact-source-contract-baseline` 供审计，但不 merge、重命名、删除或复用它。
- `triton web` / `/web/*` 采用严格 readonly：展示层只消费 DTO、诊断与可视化；控制继续走 `triton act`、`debug patch-node` 或既有通用 HTTP 契约。该裁决遵循 AGENTS 的长期产品边界，SP-142 是待重验的实现候选。
- SP-143～146 的 Stage 1 可靠性合同和 SP-147～148 的 schema 修复均保留为独立本地 checkpoint；它们不代表已集成、已发布或已完成真实采样。

此备忘录不是 merge/rebase/cherry-pick 指令，也不授权 runtime、Simulator、server、设备、真实 `test run`、push、PR、tag 或 release。

## Why

1. 当前 `main` 已把 `SP-141-packaged-web-simulator-input` 登记为已发布；旧 schema branch 同用 SP-141 编号，原样进入主线会破坏 `INDEX.md` 的一号一 space 事实。
2. SP-142、SP-143 分别从 `SP-140@d016979d` 独立分出；SP-143→SP-144→SP-145→SP-146 才是线性可靠性链。它们不是可按文档名假定的 “SP-141→SP-142→SP-143” 父子链。
3. SP-147→SP-148 从当前 `main@d2578089` 独立分出；SP-143～146 与 SP-148 均修改 `CLISchemaTestCommands.swift`，并共同改动 space registry、总览与当日日志。未经实际集成 diff / tests，不能声称无冲突。
4. 发布过的 `/web/host-input` 写入口与 README / AGENTS 的 readonly 边界矛盾。严格 readonly 是当前项目规则的较小、可验证、可回滚方向；不能通过仅改文案继续维持浏览器写控制面。
5. 当前授权不含本地合并、rebase 或删除 worktree / branch；真实 3 × 20 + 1 还需要独立的 live authorization packet。

## Execution Plan（获本地集成授权后）

1. **冻结与核对。** 保留所有既有 ref、worktree 与 #164 WIP；在新的、从届时 `main` 创建的 integration worktree 只记录 candidate commit、base、文件重叠和预期验证。不复制或补造历史 space。
2. **SP-142 重验。** 以 strict-readonly 为唯一产品方向，复跑 `WebCommandTests`、`SingleDeviceWebPageTests`、相关 Node contract tests、`npm run build` 与 `git diff --check`。browser write route 必须 405、单一 JSON envelope、无 payload 解析/转发，且页面有可见 readonly 标识。
3. **Stage 1 合同链重放。** 只按 `33ad1f9d`（SP-143）→`ab6cbf1e`（SP-144）→`50c89bea`（SP-145）→`ac958399` / `e7bb0cb6`（SP-146）顺序，在 integration worktree 做逐提交审查；每个提交都以当前 `main` 的 API / schema 为事实源处理冲突，而非把旧基线覆盖回来。
4. **Schema 收口。** 以 `98110f60`（SP-147）替代旧同编号 schema candidate；再将 `76c9c3b9`（SP-148）的 `<canonical>` placeholder 修复与已集成的 `CLISchemaTestCommands.swift` 合并。不得回退任一 receipt / anchor / identity-chain / Stage 1 字段。
5. **文档与门禁。** 使用已发布 SP-141、合法 SP-142、SP-143～148 的真实 README 重建连续 registry / overview / memory；不创建 placeholder。通过 `check-docs.sh`、`verify.sh --ci-docs` 和 `git diff --check` 后，才可把集成候选交给用户审查。
6. **再谈 live。** 只有集成候选通过离线门禁且用户完整批准 live packet 后，另建 live-sampling space，先受控 preflight，再决定是否开始 3 × 20 + 1。

## Borrowed

- 从旧 SP-141 保留“machine-readable schema 必须反映 parser 事实”的目标，但使用 SP-147 的 current-main 实现，而非冲突编号的 checkpoint。
- 从 SP-142 保留 readonly route / UI / error-envelope 合同；不继承浏览器输入行为。
- 从 SP-143～146 保留 receipt authority、external anchor、private identity-chain 和 Stage 1A / 1B 指标；仍只接受私有、授权后的真实 evidence。
- 从 SP-148 保留一个 argv token 对应一个完整 `<canonical>` placeholder 的 schema contract。

## Rejected

- 直接 merge / rebase 旧 SP-141，或通过改编号、删除 ref、空目录、假 README 规避登记册连续性。
- 把 SP-142 的历史 browser host-input 当成 Web readonly 的例外；没有新的产品 space 不扩展 Web 写控制面。
- 用合成 evidence、local-simulated、单条 imported proof 或离线 unit tests 宣称 3 × 20 + 1 / Stage 1 已完成。
- 以冲突解决为由触碰 #164 WIP，或提前推进 testrec、workspace、Android、Harmony、真实项目、真机或远端设备。

## Verification

- SP-142：Swift route / page tests、Node readonly contract tests、Web build。
- SP-143～146：各 checkpoint 记录的 reliability focused suites、release `triton` build、动态 `test` schema、`SchemaFactSourceContractTests` 基线差异重审。
- SP-147～148：schema fact / failure diagnostics / placeholder focused suites、动态 `schema --command device|test --json` contract 检查。
- 集成后：`git diff --check`、`docs-linhay/scripts/check-docs.sh`、`docs-linhay/scripts/verify.sh --ci-docs`；不启动 server、Simulator、Xcode、设备或 live runner。

## Executor 与停止条件

- 主控独占 integration worktree 的写入、冲突处理、stage / commit 与验证；subagent 仅做只读 diff / test-plan 审计。
- 发现 parser/runtime 行为必须改变、SP-142 写入口无法证明无副作用、任何 secret / private evidence 风险、docs 需要伪造历史、或与 #164 有重叠时，立即停止并请求新的裁决。
- 任何 merge、rebase、push、PR、tag、release、删除 worktree / branch、或 live sampling 都留待用户明确授权。
