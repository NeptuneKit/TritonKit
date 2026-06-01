# Round 164 - capability supported/reason state machine

## 目标

为 capability 的 `supported/reason` 关系建立三态状态机门禁，防止 fallback 分支出现“unsupported 无原因”或 reason 语义漂移。

## 变更

1. 新增测试 `SchemaFactSourceTests.capabilitySupportedAndReasonKeepStableStateMachineInvariants`。
2. 在 `runtime-connected` / `runtime-disconnected` / `server-unreachable` 三态上校验：
   - `supported=true` 时 `reason` 必须为空；
   - `supported=false` 时 `reason` 必须非空；
   - unsupported reason 必须落在已知词汇表：
     - `Requires connected embedded TritonKit runtime`
     - `Requires WebView provider metadata from embedded runtime or --runtime-base-url`
     - `Host-side Harmony clear is not available in the current adapter`
     - `Host-side HID is not available in the embedded runtime`
3. 补充边界锁定：
   - connected 态仅允许 `press` 与 `harmony-clear-text` 为 unsupported；
   - `press` / `harmony-clear-text` 在三态下都保持 unsupported，且 reason 不变；
   - 所有 schema capability 在 disconnected 与 server-unreachable 两态 reason 必须一致，防止 fallback 分支静默漂移。
4. 本轮仅新增测试门禁，不改 runtime 行为与 schema 事实源。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilitySupportedAndReasonKeepStableStateMachineInvariants`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
