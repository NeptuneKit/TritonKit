# Round 165 - capability reason/nextAction state machine

## 目标

把 capability `reason` 与 `nextAction` 的恢复路径耦合关系纳入三态门禁，防止 runtime/webview-provider 边界在 fallback 分支出现恢复动作漂移。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilityReasonAndNextActionKeepStableRecoveryTransitions`。
2. 对所有 schema capability 在三态（connected/disconnected/server-unreachable）校验以下状态转移：

### Runtime reason（`Requires connected embedded TritonKit runtime`）

- connected 态 `reason` 必须为空（不泄漏 unsupported reason）；
- disconnected 态：
  - 若 nextAction 是 `status --json`，则 server-unreachable 必须升级为 `serve --host 127.0.0.1 --port 19421` 且 `requiresLongRunningProcess=true`；
  - 若 nextAction 不是 `status`，则必须与 connected 态命令级 nextAction 保持一致，且不能标记 long-running。
- server-unreachable 态按上面两分支保持一致，不允许出现漂移动作。

### WebView-provider reason（`Requires WebView provider metadata from embedded runtime or --runtime-base-url`）

- connected 态 `reason` 必须为空；
- disconnected / server-unreachable 两态都不得回退到 `serve` 或 `status`；
- disconnected 态必须与 connected 态保持同一命令级 nextAction；
- server-unreachable 态必须与 disconnected 态保持同一命令级 nextAction；
- 以上两态都不能标记 long-running。

3. 本轮仅新增测试门禁，不改 runtime 行为或 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityReasonAndNextActionKeepStableRecoveryTransitions`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
