# 20260608 Issue 35 Selector Flags

## 背景

GitHub issue #35: <https://github.com/NeptuneKit/TritonKit/issues/35>

当前 agent-facing iOS simulator 流程中，`triton app ... --device <selector>` 与 `triton find` / `triton tap` 的 selector 词汇不一致。`find` 和 `tap` 只接受 `--target`，当 agent 从 app host-side workflow 切到 UI observation / action workflow 时，容易复用 `--device` 并被 CLI 参数解析直接拒绝。

## 范围

本期优先修复 CLI 与 schema 的机器可读契约：

1. `triton find` 接受 `--device <selector>` 作为 `--target <selector>` 的别名。
2. `triton tap` 接受 `--device <selector>` 作为 `--target <selector>` 的别名。
3. 同一 action / assertion / observation surface 中复用相同 runtime target 参数结构的命令，也应接受 `--device`，避免 agent 在 `wait`、`assert`、`swipe`、`type`、`paste`、`clear`、`press`、`input` 等闭环步骤里再次撞到 selector vocabulary 不一致。
4. `triton schema --command find --json` 与 `triton schema --command tap --json` 暴露 agent 可用 selector option，清楚标明 `--target` 与 `--device` 是同一 selector 入口。

不在本期范围：

1. 不新增 Web / Wails UI。
2. 不改变 host app / sim selector 解析模型。
3. 不调整 `triton screenshot` 已存在的 host `--device` 语义。
4. 不做真机、远端 agent 或设备云能力。

## BDD 场景

### 场景 1：find 复用 app workflow 的 device selector

Given agent 已通过 `triton app ... --device <sim-udid>` 操作 iOS Simulator

When agent 执行 `triton find "WebDAV Live Fixture" --device <sim-udid> --json`

Then CLI 参数解析接受 `--device`

And 命令内部使用同一 selector 值解析 runtime target

And 不再返回 `Unknown option '--device'`

### 场景 2：tap 复用 app workflow 的 device selector

Given agent 已通过 `triton app ... --device <sim-udid>` 操作 iOS Simulator

When agent 执行 `triton tap "WebDAV Live Fixture" --device <sim-udid> --json`

Then CLI 参数解析接受 `--device`

And 命令内部使用同一 selector 值解析 runtime target

And 不再返回 `Unknown option '--device'`

### 场景 3：schema 明确 selector vocabulary

Given agent 需要生成自动化计划

When agent 执行 `triton schema --command find --json` 或 `triton schema --command tap --json`

Then schema 的 options 中暴露 selector option

And selector option 名称包含 `--target/--device`

And 描述说明 `--device` 是 `--target` 的别名，可传 target id、simulator UDID 或唯一目标自动选择。

### 场景 4：相近 action/assertion 命令保持一致

Given agent 在同一个 iOS runtime target 上执行 `wait`、`assert`、`swipe`、`type`、`paste`、`clear`、`press` 或 `input`

When agent 使用 `--device <selector>`

Then CLI 参数解析应与 `--target <selector>` 等价

And schema 应复用同一 selector option 词汇。

## 验收标准

1. CLI parser 测试覆盖 `Find.parse(["query", "--device", "booted"])` 与 `Tap.parse(["query", "--device", "booted"])`。
2. schema 测试覆盖 `find` 与 `tap` 的 selector option 为 `--target/--device`。
3. 若实现扩展到相近命令，测试覆盖至少一个 assertion / wait 类命令的 `--device` 解析。
4. 相关 Swift 测试通过。
5. `docs-linhay/memory/2026-06-08.md` 记录本期决策、验证与风险。
