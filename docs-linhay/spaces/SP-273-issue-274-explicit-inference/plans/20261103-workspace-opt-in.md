# Workspace 显式推理实现证据

基线：9578782a7cbfd855228f8e996b07d93437725870。影响层：CLI、HTTP DTO/runtime、机器可读 schema；无 Web/桌面或设备变更。

## 契约

- `workspace run --enable-llm` / `--enable-vlm` 为独立 Bool flags，默认 false。
- HTTP `/workspace/run` 的 `enableLLM` / `enableVLM` 可缺省或 false；只有 true 启用对应 provider。非 Bool 值由 Codable 拒绝。
- URL/model/provider/API-key-env/remote approval/execute-actions 配置不构成推理启用；禁用 provider 不执行配置验证、读取 API key 或构造 helper。
- 默认仍采集已有 workspace 基础事实，运行状态 paused，phase `inference_disabled`，nextAction `external_agent_inference`；不提示缺少必须配置的 AI provider。
- LLM 可单独启用；VLM-only 不启用已配置的 LLM。第一步、bounded loop、实际 VLM grounding 均有开关边界。
- `dryModelFixture` 只产生 synthetic model decision；无论是否传启用 flags/在线/MLX配置，均不调用 provider/helper。报告 `providerStatus=fixture`、`providersReady=false`，enabled 字段仍记录显式请求值。Mock decision 不宣称已使用 VLM。
- `vlm ground/compare --provider ...` 本身是专用显式请求；默认 mock、不读取 workspace 全局启用状态。
- Online LLM 的共享 `postAIJSON` 总 deadline 由有界性负责人实现；这里接入并保留 workspace typed HTTP error，未引入 retry/fallback。

## RED

新增 WorkspaceInferenceOptInTests 先在旧产品实现上执行：2 tests / 3 cases，6 issues。缺省 enabled=true、缺失 provider 配置提示，以及配置 online 时（包含 dry fixture）错误调用注入 provider 均被证实。

命令：`swift test --package-path CLI --scratch-path ../SP-271-issue-139-runtime-diagnostics/CLI/.build -j 4 --no-parallel --filter WorkspaceInferenceOptInTests`。

原始日志：`../archives/SP273/opt-in-red.log`。首次构建未知 exit143 与主动改用 -j4 的第二次退出另见 `../archives/SP273/build-interruption.md`，两者均未执行测试，不计为产品 RED。

## 回归范围

持久测试新增：CLI flag default/explicit、HTTP nil/false/true/非法值、resolved request flag 传播、配置不启用、禁用非法配置不构造 provider、VLM-only 不调用 LLM、dry fixture 即使显式配置也无 provider/helper 调用、显式 provider 错误保留且仅调用一次。

既有 WorkspaceRun / ActionExecution / BusinessReadiness / VisualFeedback 场景补充显式 flags，保留原断言与设备注入。真实 LLM、在线服务、模型下载与设备未使用；原私有 App/用户 llama-server 原始进程因缺乏采样证据不能宣称归因或恢复。

GREEN：86 tests / 11 suites 通过（Workspace 过滤同时命中3个既有相邻suite）。命令：`TRITON_CLI_PATH=/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-271-issue-139-runtime-diagnostics/CLI/.build/out/Products/Debug/triton swift test --package-path CLI --scratch-path ../SP-271-issue-139-runtime-diagnostics/CLI/.build -j 4 --no-parallel --skip-build --filter Workspace`。

首次 GREEN 编译通过，85/86测试通过；唯一失败是历史真实CLI测试在外部scratch未自动找到triton。使用现有 `TRITON_CLI_PATH` override指向本轮实际构建的Debug产物后原测试全部通过，未修改locator或跳过测试。对应日志已分别保存 `../archives/SP273/workspace-green-initial-locator-failure.log` 与 `workspace-green.log`。

CLI schema已新增两个flags与defaultfalse说明。`docs-linhay/scripts/public-skill-command-schema.json` 只列workspace子命令、不列其选项，无须更改。无额外依赖。完整 CLI 与发布验收由主控负责。
