# Round 74: Assertion Failure Verify Recovery

## 目标

继续按单一 failure family 收紧命令级恢复覆盖：assertion / route / text-not-found 失败必须能导向 `verify` category。

## 初始红灯

新增 `SchemaFactSourceTests.assertionFailureCodesExposeVerifyRecoveryCategories` 后，红灯集中在：

- `focus:text_not_found`
- `select-segment:text_not_found`
- `set-switch:text_not_found`
- `route:route_mismatch`
- `smoke:text_not_found`
- `smoke:assertion_failed`
- `assert:assertion_failed`
- `find:text_not_found`

## 本轮改动

- semantic action 命令补充 `triton wait --text <selector> --json`。
- `route` 补充 `triton route assert-current-url <expected-url> --json`。
- `smoke` 补充 `triton assert text-exists <text> --json`。
- `assert` 补充 `triton wait --text <text> --json`。
- `find` 补充 `triton wait --text <query> --json`。

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/assertionFailureCodesExposeVerifyRecoveryCategories`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI`

结果：全部通过，完整 CLI package 当前 135 个 Swift Testing 用例通过。

## 后续

继续按 failure family 小步收紧，例如 server/runtime transport 失败导向 `diagnose`，target 失败导向 `prepare-target`。
