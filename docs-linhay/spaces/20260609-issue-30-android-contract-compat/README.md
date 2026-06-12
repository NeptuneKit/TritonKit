# Issue 30 Android Contract Compatibility

## Background

GitHub issue #30 要求 TritonKit 暴露 Android host-side adb/emulator workflow。当前 Android 主链路已经具备 device/app/observe/smoke 的基本能力，但 issue 原文里的两个字面入口仍可能让 agent 误判缺能力：

- `triton app inspect --platform android --bundle <bundle-id> --json`
- `triton ax --platform android --device <selector> --json`

本 space 只做收口兼容，不重写 Android lane，不启动真实 emulator，不执行破坏性 adb。

## Scope

包含：

- 为 Android `app inspect` 提供低风险兼容入口，语义等价于当前 Android `app info` / `dumpsys package` metadata inspection。
- 为 `ax --platform android` 提供低风险兼容入口，复用 Android `observe tree` / UIAutomator host layout 输出。
- 在 schema 中显式暴露 issue 原文字面入口与 Android platform-specific output contracts，避免 agent 只按命令名搜索时误判缺能力。
- 补充 Swift 测试覆盖 schema、ArgumentParser 入口和 Android fake ADB parser/runtime，不依赖真实 emulator。

不包含：

- 新增或重写 adb/emulator 主链路。
- 启动、安装、卸载、擦除或停止真实 Android emulator/device。
- 新增 Web/Wails/HTTP 产品面。
- Android embedded runtime。

## BDD Scenarios

### Scenario 1: Android app inspect 字面入口可发现且可解析

Given agent 从 issue #30 原文读取 `triton app inspect --platform android --bundle <bundle-id> --json`
When agent 查询 `triton schema --command app --json` 或 CLI 参数解析
Then schema 应包含 Android inspect usage/example
And CLI 应接受 `--platform android --bundle <bundle-id>`
And 该入口应复用 Android app info/dumpsys package metadata 契约，不要求 agent 改用裸 adb。

### Scenario 2: Android AX 字面入口可发现且可解析

Given agent 从 issue #30 原文读取 `triton ax --platform android --device android-a --json`
When agent 查询 schema 或执行参数解析
Then schema 应将 `ax --platform android` 显示为 Android observe tree/UIAutomator 等价入口
And output contract 应包含 `host.android-ax`
And 兼容入口不应依赖 embedded runtime。

### Scenario 3: Platform-specific output contract 名称显式暴露

Given agent 需要按 platform-specific contract 名称路由 Android host-side 输出
When agent 查询 `triton schema --json`
Then Android host contracts 应显式包含 issue 原文相关名称，例如 `host.android-device`、`host.android-app-inspect`、`host.android-app-install`、`host.android-app-launch`、`host.android-screenshot`、`host.android-ax`、`host.android-tap`、`host.android-wait`、`host.android-key-action`
And 每个 selector 应有稳定 model/field/failure 信息，避免从 prose 推断。

## Acceptance

- `DeviceCrossPlatformTests` 覆盖 Android app inspect / ax 兼容 schema。
- schema tests 覆盖 Android platform-specific output contract selector。
- parser/runtime tests 覆盖 Android inspect/ax 可用 fake ADB fixture，不触碰真实 emulator。
- 相关 Swift tests、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 通过；`qmd-sync` 尽量执行。
- 更新 memory；若对外 agent 使用口径变化，更新 public skill。
