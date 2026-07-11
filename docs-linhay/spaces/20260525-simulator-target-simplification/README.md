# 20260525 Simulator Target Simplification

## 背景

已发布版本已经支持多开 iOS Simulator 后通过 `--simulator <udid>` 指定单个模拟器，也支持 Harmony 通过 `--target <hdc-target>` 指定单个 emulator。但 agent 仍需要记住不同平台和命令族里的目标参数：

- iOS host-side 操作使用 `--simulator <udid|booted>`。
- Harmony host-side 操作使用 `--target <hdc-target>`。
- embedded runtime 操作使用 `--target <runtime-target>`，iOS 可传 `triton:ios-simulator:<udid>` 或 UDID。
- `sim use` / workspace default 只能保存一个默认 simulator，无法表达多个常用目标。

本 space 设计目标是简化“指定哪个模拟器/仿真器”的 agent 入口，降低多开场景下的误选风险；不是做批量并发调度。

## 范围

### In Scope

1. 设计一个统一 target selector，让常用 host-side 命令可接受同一种目标表达。
2. 保留已发布命令兼容性，不删除 `--simulator`、Harmony `--target` 或 `sim use`。
3. 多开时默认不静默选择，继续返回 `ambiguous_target` 并给出候选与推荐命令。
4. 设计短别名能力，用稳定别名指向 UDID / HDC target，例如 `iphone15`、`harmony-a`。
5. 设计一套 target 过滤器系统，允许单平台单 ready 目标时直接按 `--platform` 自动选择。
6. 明确与未来批量 fan-out 的边界。

### Out of Scope

1. 不实现一个命令同时控制多个模拟器。
2. 不引入远端设备、真机、设备云或 Web/Wails UI。
3. 不改变已发布脚本的参数语义。
4. 不把 iOS embedded runtime target 与 host simulator target 强行合并为同一个执行层。

## 问题定义

当前用户想表达的是“我要控制这个模拟器”，但 CLI 暴露的是工具层差异：

```bash
triton app launch --simulator <ios-udid> --bundle-id <bundle>
triton observe tree --platform harmony --target <hdc-target>
triton ax --target triton:ios-simulator:<ios-udid>
```

对 agent 来说，应优先记住一个目标选择入口，而不是平台工具命名。

## 目标体验

### P0：统一目标选择入口

新增或标准化 `--device <selector>`，作为 host-side 常用命令的精确目标参数：

```bash
triton device list --platform ios --json
triton device alias set iphone15 --platform ios --target <udid> --json
triton device alias set harmony-a --platform harmony --target <hdc-target> --json

triton app launch --device iphone15 --bundle-id com.example.app --json
triton app open-url "example://debug" --device iphone15 --json
triton screenshot --device harmony-a --output /tmp/harmony.jpeg --json
triton observe tree --device harmony-a --json
```

当某个平台只有一个 ready 目标时，允许直接按平台调用，不强制 alias：

```bash
triton app launch --platform ios --bundle-id com.example.app --json
triton app open-url "example://debug" --platform ios --json
triton screenshot --platform ios --output /tmp/ios.png --json

triton app launch --platform harmony --bundle com.example.app --ability EntryAbility --json
triton observe tree --platform harmony --json
triton screenshot --platform harmony --output /tmp/harmony.jpeg --json
```

兼容路径继续可用：

```bash
triton app launch --simulator <udid> --bundle-id com.example.app --json
triton observe tree --platform harmony --target <hdc-target> --json
```

### P1：当前目标上下文

允许保存多个命名 target，并允许选择一个当前目标：

```bash
triton device alias list --json
triton device alias set iphone15 --platform ios --target <udid> --json
triton device use iphone15 --json
triton device current --json
```

`device use` 不再只表达 iOS simulator default；它表达“当前 agent target”。iOS Xcode/workspace default 仍可单独保留，避免破坏现有 Xcode 流程。

### P2：批量能力另开边界

批量 fan-out 不塞进 P0：

```bash
triton batch run --targets iphone15,harmony-a --plan smoke.tritonplan --jsonl
```

这需要 target lock、并发度、失败策略、evidence 聚合和输出顺序约定，应独立设计。

## Selector 规范

`HostDeviceSelector` 不是单一字符串解析，而是“候选集 + 过滤器 + selector + 唯一性门禁”：

```text
device list
  -> filters: --platform / --name / --runtime / --state / --ready / --bundle
  -> selector: --device alias|id|booted|current
  -> exactly one target
  -> execute action
```

推荐 selector 解析顺序：

1. 明确 alias：`iphone15`、`harmony-a`。
2. 完整 target id：`sim:<udid>`、`harmony:<hdc-target>`、`triton:ios-simulator:<udid>`。
3. 原始平台 id：iOS UDID 或 Harmony HDC target。
4. 兼容特殊值：`booted` 仅允许 iOS host-side 命令，且多个 booted 时返回 `ambiguous_target`。

解析结果统一为：

```json
{
  "platform": "ios",
  "target": "<udid>",
  "id": "sim:<udid>",
  "selector": "iphone15",
  "source": "alias|explicit|default",
  "ready": true
}
```

## 过滤器系统

过滤器用于缩小候选集，不能绕过唯一性门禁。只要最终候选不是 1 个，就不执行动作。

### 过滤器参数

- `--device <selector>`：精确 selector，支持 alias、完整 id、原始平台 id、`booted`、`current`。
- `--platform ios|harmony|android`：平台过滤器；P0 实现 iOS / Harmony，Android 预留。
- `--name <name-or-substring>`：设备名过滤器，主要用于 iOS Simulator，例如 `iPhone 15`。
- `--runtime <runtime-or-version>`：runtime / 系统版本过滤器，主要用于 iOS，例如 `iOS 26.5`。
- `--state <state>`：状态过滤器，例如 `booted`、`shutdown`、`connected`、`offline`。
- `--ready`：只保留可操作目标；iOS 对应 Booted，Harmony 对应 Connected + boot completed。
- `--bundle <bundle-id>`：可选后续能力，用已安装 App 反向过滤目标。

### 推荐调用方式

单平台单目标：

```bash
triton app launch --platform ios --bundle-id com.example.app --json
triton observe tree --platform harmony --json
```

平台内多目标时用过滤器继续收窄：

```bash
triton app launch --platform ios --name "iPhone 15" --bundle-id com.example.app --json
triton app launch --platform ios --runtime "iOS 26.5" --bundle-id com.example.app --json
```

高频稳定目标用 alias：

```bash
triton app launch --device iphone15 --bundle-id com.example.app --json
```

一次性精确目标用原始 id：

```bash
triton app launch --device <udid> --bundle-id com.example.app --json
```

### 自动选择规则

1. 如果传了 `--device <selector>`，优先按 selector 精确解析。
2. 如果没传 `--device`，但传了 `--platform ios|harmony`，就在该平台内用其他过滤器缩小候选集。
3. 如果平台内只有一个 ready target，允许自动选择。
4. 如果平台内有 0 个 ready target，返回 `target_not_found` 或 `target_not_ready`。
5. 如果平台内有多个 ready target，返回 `ambiguous_target`，提示使用 `--device <alias-or-id>` 或继续加过滤器。
6. 如果既没传 `--device` 也没传 `--platform`，只有全局唯一 ready target 时才可自动选择；否则返回 `ambiguous_target`。

错误 envelope 示例：

```json
{
  "ok": false,
  "error": {
    "code": "ambiguous_target",
    "message": "Multiple ready devices matched the selector filters.",
    "hint": "Narrow with --device, --platform, --name, --runtime, --state, or --ready."
  },
  "candidates": []
}
```

## BDD 验收

### 场景一：多开 iOS 时 agent 用别名控制指定模拟器

- Given 本机有两个 Booted iOS Simulator
- And 已执行 `triton device alias set iphone15 --platform ios --target <udid-a>`
- When 执行 `triton app launch --device iphone15 --bundle-id com.example.app --json`
- Then 只对 `<udid-a>` 执行 host action
- And 输出包含 `selector=iphone15`、`platform=ios`、`target=<udid-a>`、`sourceCommand`

### 场景二：未指定目标且多候选时不误选

- Given 本机有两个 Booted iOS Simulator
- When 执行 `triton app launch --bundle-id com.example.app --json`
- Then 返回 `error.code=ambiguous_target`
- And 输出 candidates 与推荐 `--device <alias-or-id>` / `--simulator <udid>`

### 场景三：Harmony 目标也复用同一 selector

- Given 已执行 `triton device alias set harmony-a --platform harmony --target 127.0.0.1:10100`
- When 执行 `triton observe tree --device harmony-a --json`
- Then 内部解析为 `--platform harmony --target 127.0.0.1:10100`
- And 输出保留 Harmony source command 与 target envelope

### 场景四：旧命令保持兼容

- Given 旧脚本仍使用 `--simulator <udid>`
- When 执行 `triton app open-url "example://debug" --simulator <udid> --json`
- Then 行为和已发布版本一致
- And schema 标注 `--device` 为推荐入口、`--simulator` 为兼容入口

### 场景五：单平台单 ready 目标可直接按平台调用

- Given 本机只有一个 Booted iOS Simulator
- When 执行 `triton app launch --platform ios --bundle-id com.example.app --json`
- Then 自动选择该 iOS Simulator
- And 输出包含 `selectorSource=platform-filter`、`platform=ios`、`target=<udid>`

### 场景六：平台过滤后仍多目标时必须失败

- Given 本机有两个 Booted iOS Simulator
- When 执行 `triton app launch --platform ios --bundle-id com.example.app --json`
- Then 返回 `error.code=ambiguous_target`
- And 输出 candidates 与推荐 `--device <alias-or-id>`、`--name` 或 `--runtime`

## 命令设计

### 新增 device alias 子命令

```bash
triton device alias list --json
triton device alias set <name> --platform ios|harmony --target <id> --json
triton device alias remove <name> --json
triton device current --json
triton device use <selector> --json
triton device resolve <selector> --json
```

建议 alias 存储在 `.triton/host-targets.json`：

```json
{
  "schemaVersion": 1,
  "current": "iphone15",
  "aliases": {
    "iphone15": {
      "platform": "ios",
      "target": "<udid>"
    },
    "harmony-a": {
      "platform": "harmony",
      "target": "127.0.0.1:10100"
    }
  }
}
```

### 常用命令接受 `--device`

P0 覆盖：

- `triton app list/info/install/uninstall/launch/terminate/open-url`
- `triton screenshot`
- `triton observe current/tree`
- `triton node resolve`
- `triton smoke ios|harmony`

暂不覆盖：

- `triton sim runtime/*`、personalization、runtime install/delete 等 iOS 专属维护命令
- embedded runtime-only 的低层命令，除非 selector 能唯一映射到 runtime target

### 常用命令接受过滤器

P0 对常用 host-side 命令开放：

```bash
--device <selector>
--platform ios|harmony
--name <name-or-substring>
--runtime <runtime-or-version>
--state <state>
--ready
```

`--bundle` 作为 P1/P2 过滤器预留，等 app 安装列表查询成本和缓存策略明确后再接。

## 兼容策略

1. `--device` 与 `--simulator` / `--target` 同时传入时返回参数冲突，不做隐式优先级。
2. 已有 `--simulator booted` 保留；多 booted 时应返回 `ambiguous_target`。
3. `device use <selector>` 设置 agent 当前目标；`sim use <udid>` 继续设置 Xcode/iOS simulator default。
4. `--platform` 作为过滤器，不是强制精确 selector；只有过滤后唯一时才执行。
5. schema examples 优先展示 `--device` 和单平台 `--platform` 调法，旧参数保留在 options。

## 风险与未对齐项

1. `--target` 已在 embedded runtime 命令中有稳定含义，不能直接重命名为 host device target。
2. iOS host target 和 iOS embedded runtime target 是两层对象；`--device iphone15` 只能在需要 runtime 时尝试映射，不可假装 runtime 已连接。
3. alias 文件会引入 workspace state，需要避免污染 release、CI 和外部项目。
4. 批量 fan-out 需要独立 evidence 聚合和并发安全设计，不能用 alias 简化顺手实现。
5. 过滤器越多，错误提示越重要；必须输出候选、命中过滤器、失败原因和推荐下一步，否则 agent 仍会难以恢复。

## 实施切片

1. 先补 `HostDeviceSelector` parser / resolver / filter 单元测试。
2. 新增 `.triton/host-targets.json` DTO 与 alias CRUD 测试。
3. 给 `app` 和 `screenshot` 接 `--device`、`--platform` 和基础过滤器，覆盖最常用路径。
4. 给 `observe` / `node resolve` 接 `--device`、`--platform` 和基础过滤器，对齐 Harmony 与 iOS runtime 映射。
5. 更新 `schema`、README、对外 emulator skill 与真实项目回归 skill。
6. 真实机本地 smoke：两个 iOS Simulator 多开 + 一个 Harmony target alias 解析。

## 当前结论

短期不做“同时多开并发控制”，先把“多开后指定哪个目标”抽象成 `HostDeviceSelector`：过滤器负责缩小候选集，selector 负责精确命中，唯一性门禁负责安全失败。这能减少 agent 命令记忆成本，也能保持多候选安全失败。

## 2026-05-25 实施记录

本轮已落地 P0/P1 的基础闭环：

1. 新增 `.triton/host-targets.json` alias/current DTO：
   - `triton device alias list --json`
   - `triton device alias set <name> --platform ios|harmony --target <id> --json`
   - `triton device alias remove <name> --json`
   - `triton device use <selector> --json`
   - `triton device current --json`
   - `triton device resolve <selector> --json`
2. 新增 `HostDeviceSelectionRequest` / `HostDeviceSelectionResult`：
   - 支持 alias、`sim:<udid>`、`harmony:<target>`、`triton:ios-simulator:<udid>`、原始平台 id、`booted`、`current`；
   - 支持 `--platform`、`--name`、`--runtime`、`--state`、`--ready` 过滤；
   - 多候选返回 `ambiguous_target`，JSON envelope 保留 `candidates`、`nearestCandidates`、`suggestedCommands`、`candidateCount`。
3. 常用 host-side 命令已接入统一 selector：
   - `triton app list --device <selector> ...`
   - `triton app info --device <selector> ...`
   - `triton app install --device <selector> ...`
   - `triton app uninstall --device <selector> ...`
   - `triton app launch --device <selector> ...`
   - `triton app terminate --device <selector> ...`
   - `triton app open-url <url> --device <selector> ...`
   - `triton app container --device <selector> ...`
   - `triton app prefs dump/get/set --device <selector> ...`
   - `triton device wait-ready --device <selector> ...`
   - `triton device screenshot --device <selector> ...`
   - `triton screenshot --device <selector> --output <path> --json`
   - `triton observe current/tree --device <selector> --json`
   - `triton node resolve --device <selector> --text <text> --json`
   - `triton smoke ios --device <selector> ...`
   - `triton smoke harmony --device <selector> ...`
4. 兼容路径保留：
   - `--simulator <udid|booted>` 与 Harmony `--target <hdc-target>` 仍可用；
   - `--device` 与 `--simulator` / host-side `--target` 同时传入时返回 `parameter_conflict`；
   - `sim use <udid>` 继续只表示 iOS/Xcode workspace simulator default，`device use <selector>` 表示当前 agent target。

已验证：

```bash
swift test --package-path CLI --scratch-path .build/cli -c debug --filter DeviceCrossPlatformTests
swift test --package-path CLI --scratch-path .build/cli -c debug
```

第二条覆盖 51 个 CLI 测试用例，全部通过。

未完成 / 后续切片：

1. `--bundle` 反向过滤未实现，仍按原设计留到 P1/P2。
2. 尚未执行真实多开 iOS + Harmony alias smoke，本轮只做 parser/schema/CLI 单元验证。

## 2026-07-11 路线裁决

- 状态：已归档。
- 真实多开 iOS + Harmony alias smoke 已通过：两个 Booted iOS Simulator 在无 selector 时稳定返回 `ambiguous_target`，iOS alias 只启动指定 UDID 上的 Demo，Harmony alias 可在不显式传 `--platform` 时完成 `observe tree`。
- smoke 暴露并修复了 observation 命令把缺省 platform 强制解释为 iOS 的问题；显式 platform 仍作为选择过滤器。
- 验收证据见 [20260711 multi-target alias smoke](evidence/20260711-multi-target-alias-smoke/README.md)。
- `--bundle` 反向过滤收益不足，且会引入跨目标 App 查询和缓存复杂度，明确不在本 space 实现。
- 其他批量 fan-out 或新 selector 能力必须另建 space，不再扩张当前范围。
