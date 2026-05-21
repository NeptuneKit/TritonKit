# Technical Research: Semantic Selector v01

## 背景

S3 的目标是让 AI agent 用语义命令操作 App，减少 `tap` 后再 `type` 的坐标链不确定性。首批只覆盖表单最常见的 `focus`、`set-text`、`select-segment`、`set-switch`。

## 现有代码入口

- Selector 解析复用：`Sources/TritonKitCLI/main.swift` 的 `resolveTapTarget`
- CLI 语义命令：`Snapshot` 后的 `Focus`、`SetText`、`SelectSegment`、`SetSwitch`
- Shared request/response：`TKSemanticActionRequest`、`TKSemanticActionResponse`
- Embedded action routing：`TritonKitRequestHandler.performSemanticAction`
- Mock smoke：`verify-intent-cli-smoke.sh`

## 可用公开 API

1. CLI 侧先通过现有 AX/hierarchy/hit-test 解析 selector，得到 `targetOID` 或坐标。
2. 重复候选沿用 `--index`、`--within x,y,width,height`、`--at x,y`。
3. Embedded runtime 根据 `targetOID` 或坐标解析 UIKit view，不依赖私有 selector。
4. 输出保留 `strategy`，让 agent 能解释是通过 AX、hierarchy 文本还是坐标命中。

## 不可做清单

1. 不让 selector 直接执行任意业务方法。
2. 不在 CLI 内猜测业务完成，只确认 runtime 动作结果。
3. 不在重复候选中静默选择不可解释目标；首期沿用现有 `find/tap` 收敛规则。
4. 不读取 secure text 明文。

## 推荐 DTO / 命令 Shape

```bash
triton focus "用户名" --json
triton set-text "用户名" "alice" --json
triton set-text "密码" "$TRITON_PASSWORD" --secure --json
triton select-segment "协议" "HTTP" --json
triton set-switch "记住我" on --json
```

`TKSemanticActionRequest` 包含：

- `action`
- `selector`
- `sourceCommand`
- `strategy`
- `targetOID` 或 `x/y`
- action-specific 字段：`text/secure/segmentTitle/segmentIndex/switchValue`

`TKSemanticActionResponse` 包含：

- `ok/action/strategy/targetOID/targetClassName/elapsedMs/message/error/redaction`

## 测试建议

1. Shared encode/decode 覆盖 response 和 redaction。
2. CLI transport mapping 覆盖 `semanticAction`。
3. Schema 覆盖四个命令的 selector、消歧参数、secure 参数和 success shape。
4. Mock smoke 覆盖四个 CLI 命令和 `sourceCommand`。

## 风险

1. Selector 解析和 runtime 执行之间页面可能变化，`targetOID` 可能失效；保留坐标 fallback 和策略字段用于复盘。
2. 自定义控件可能不是标准 UIKit 类型，首期应返回明确失败，不伪造成功。
3. 后续 `submit/scroll-to-visible` 需要更强的控件语义和 harness 覆盖，不应混入首批表单切片。
