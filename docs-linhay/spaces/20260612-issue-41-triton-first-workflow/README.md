# Issue 41: Triton-first emulator fallback gate

## 背景

GitHub issue #41 指出：agent 在执行本机 emulator / simulator 动作时，可能直接调用 `baguette`、`xcrun`、`hdc`、XcodeBuildMCP 等 fallback 工具，而没有先检查或使用 TritonKit 的机器可读控制面。

本需求要把 Triton-first before fallback 固化到面向 agent 的文档、public skills、内部治理 skill 和 schema / plan 契约中。目标不是新增 Web/Wails，也不是扩展真机或远端 agent，而是让本机 iOS Simulator、Android Emulator、HarmonyOS / DevEco Emulator 的自动化流程先经过 `triton` 的 status / capabilities / schema / plan 入口。

## 范围

- 更新 agent-facing README 与 `docs-linhay/dev/ai-cli-readable-control.md`，明确 fallback 前必须先产生 Triton 失败或 unsupported 证据。
- 更新 `TritonKit.skills/` public skills，让外部 agent 安装后也遵守同一规则。
- 更新 `.agents/skills/` 内部治理 skill，约束维护者和 issue worker 不绕过 Triton。
- 若 schema / plan 已有表达面，补充最小 schema 语义与测试，确保 `triton plan` 可作为 fallback gate 的机器可读事实源。
- 不新增 Web/Wails 控制面，不新增真实设备、远端 agent 或设备云边界。

## BDD 场景

### 场景 1：iOS Simulator 动作先走 Triton

Given agent 需要执行 iOS Simulator 的 target 选择、截图、安装、启动、deeplink、Xcode build/run 或观察动作
When agent 准备使用 `xcrun`、`simctl`、XcodeBuildMCP 或其他 fallback 工具
Then agent 必须先运行并记录至少一个 Triton 机器可读入口，例如 `triton status --json`、`triton capabilities --json`、`triton schema --command sim --json`、`triton schema --command app --json`、`triton schema --command xcode --json` 或 `triton plan ... --json`
And 只有当 Triton 返回 `server_unavailable`、`unsupported_capability`、缺少对应 schema / capability、或计划步骤明确无法覆盖该动作时，才能 fallback
And fallback 报告必须包含 Triton 命令、错误码 / unsupported 证据和 fallback 工具命令。

### 场景 2：Harmony / DevEco Emulator 动作先走 Triton

Given agent 需要执行 Harmony HDC target 发现、wait-ready、安装、启动、open-url、layout、tap、type、screenshot 或 smoke
When agent 准备直接使用 `hdc`、`aa`、`bm`、`uitest`、DevEco Emulator CLI 或其他 fallback
Then agent 必须先检查 `triton device doctor --platform harmony --json`、`triton device list --platform harmony --json`、`triton schema --command device --json`、`triton schema --command app --json`、`triton schema --command smoke --json` 或任务型 `triton plan ... --json`
And 只有当 Triton 明确失败、unsupported 或 schema 不暴露所需能力时，才能 fallback
And fallback 产物必须保留 Triton evidence，不得只写“hdc 可用”或“改用 fallback”。

### 场景 3：Android Emulator 能力尚未实现时仍需 Triton 证据

Given Android Emulator 是已接受但可能未完整实现的产品方向
When agent 需要使用 `adb`、`emu` 或 Android Studio emulator 工具
Then agent 必须先读取 `triton capabilities --json`、`triton schema --json` 或相关 command schema
And 若 Triton schema 尚未暴露 Android app / device / action 能力，fallback 记录应写明 “Triton unsupported / not exposed yet”，而不是静默绕过 Triton。

### 场景 4：文档和 skills 给出一致的 fallback gate

Given 维护者或外部使用者只阅读 README、dev 文档、public skill 或内部 skill 中任一入口
When 他们准备执行本机 emulator / simulator 自动化
Then 都能看到同一条约束：先用 Triton 的 status / capabilities / schema / plan 作为事实源；fallback 只能在 Triton 失败、unsupported 或 schema 缺口被记录后发生。

### 场景 5：Schema 测试守住 plan fallback gate

Given `triton plan` 是 agent 执行本机 emulator workflow 前的计划入口
When schema facts 被测试读取
Then `plan` schema 的 `outputSemantics` 必须明确说明 plan 也是 fallback gate，并要求 fallback 前记录 Triton failure / unsupported / missing schema 证据。

## 验收标准

- `docs-linhay/spaces/20260612-issue-41-triton-first-workflow/README.md` 记录本需求 BDD 与验收。
- README、`docs-linhay/dev/ai-cli-readable-control.md`、`TritonKit.skills/*` 和 `.agents/skills/*` 均出现 Triton-first fallback gate。
- `triton plan` 的 schema 语义与 `SchemaFactSourceTests` 能证明 plan 是 fallback gate 的机器可读入口。
- 文档不新增 Web/Wails、真机、远端 agent 或设备云边界。
- 验证命令覆盖 docs check、qmd sync 和相关 schema/docs tests。
