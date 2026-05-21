# Technical Research: Runtime Ledger v01

## 背景

S4 的目标是让 AI agent 能复盘最近一轮 runtime 请求和动作结果，判断失败发生在观察、selector 解析、SDK 执行、业务异步状态，还是 embedded runtime 边界之外。

## 现有代码入口

- Shared DTO：`TKRuntimeLedgerRequest`、`TKRuntimeLedgerResponse`、`TKRuntimeLedgerEntry`
- Handler store：`RuntimeLedgerStore(maxEntries: 100)`
- 记录点：`TritonKitRequestHandler.didReceiveMessage`
- CLI：`triton ledger --limit 50 --jsonl`
- Smoke：`verify-intent-cli-smoke.sh`

## 可用公开 API

Ledger 不依赖额外平台 API，只记录 TritonKit runtime 已经可见的 request/response metadata：

- request type
- semantic/input action
- source command
- ok/errorCode/message
- elapsedMs
- redaction summary

## 不可做清单

1. 不记录 secure text 明文。
2. 不记录剪贴板内容、网络正文、业务日志正文或文件内容。
3. 不无界增长内存。
4. 不把 `ledger` 请求自身再次写入 ledger，避免读 ledger 污染复盘流。

## 推荐 DTO / 命令 Shape

```bash
triton ledger --limit 50 --jsonl
```

`TKRuntimeLedgerEntry` 字段：

- `id`
- `timestamp`
- `source`
- `requestType`
- `action`
- `ok`
- `elapsedMs`
- `errorCode`
- `message`
- `redaction`

`limit` 应 bounded 到 `maxEntries`；当前默认 ring buffer 为 100 条。

## 测试建议

1. Shared encode/decode 覆盖 bounded response 和 redaction。
2. CLI schema 覆盖 `--limit`、`--jsonl` 和 JSONL output format。
3. Mock smoke 覆盖 `runtimeLedger` 响应和 JSONL 解析。
4. 真实 runtime 后续验证 secure `set-text` 进入 ledger 时只有 `length-only`。

## 风险

1. Ledger 只能复盘 runtime 可见事实，不证明业务最终状态；仍需 `wait/assert/snapshot/evidence`。
2. 错误 response shape 多样，记录逻辑必须优先读取统一 error envelope，再退化为 generic JSON。
3. Ring buffer 是进程内内存，App 重启后不会保留历史；这是 DEBUG runtime 的预期边界。
