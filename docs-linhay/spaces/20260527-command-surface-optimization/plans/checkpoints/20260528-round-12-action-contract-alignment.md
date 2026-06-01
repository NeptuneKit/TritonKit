# Round 12: Action Contract Alignment

## 目标

让 action 层在 `schema`、`capabilities` 和 `doctor` 中保持同一事实口径，避免 agent 从 capabilities 读到当前 CLI schema 不支持的命令参数或错误的支持状态。

## 完成结果

- 修正 action capabilities 的 `nextAction`：
  - `swipe` 使用当前 schema 支持的 `--start-x/--start-y/--end-x/--end-y`。
  - `clear` 使用 `--at <x,y>`，不再给出不存在的 `<query>` 参数。
  - `input` 使用 `--json --summary --strict`，不再给出不存在的 `--file` 参数。
  - embedded `press` 仍为 unsupported，`nextAction` 指向 `schema --command press --json`。
- 为 action capabilities 补齐 evidence：
  - `tap/swipe/type/paste/clear/input` 暴露 `input.result` 与 `runtime-ledger`。
  - `press` 暴露 `unsupported-envelope` 与 `command-schema`。
- 修正 `input` schema 的 `providedCapabilities`：包含 `input/tap/swipe/type/paste/clear`，不再把 unsupported `press` 作为 input 已提供能力。
- 更新 dev 文档和 public skills，明确 action capability `nextAction` 必须与当前 schema 可执行参数一致。

## 验收场景

1. agent 从 `triton capabilities --json` 读取 `swipe.nextAction` 时，得到当前 CLI 可执行的 `--start-x/--start-y/--end-x/--end-y` 参数。
2. `clear.nextAction` 不再暗示支持文本 query。
3. `input.nextAction` 不再暗示支持 `--file`，而是引导使用 stdin + `--summary --strict`。
4. embedded `press` 仍明确 unsupported，并引导 agent 查看 schema，而不是误以为 host HID 可用。
5. `triton schema --command input --json` 不再把 `press` 标为 provided capability。

## 已运行验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，11 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，82 个 Swift Testing 用例通过。

## 后续队列

- Round 13：整理 observe / webview / route 层，优先检查 schema、capabilities、doctor 和 plan 对 hybrid/provider 边界的表达是否一致。
- 后续可继续把 action 层细化为显式 `action` namespace，但当前阶段不做命令重命名。
