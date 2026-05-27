# 20260527 Mirroir Host Adapter

## 背景

用户要求将 `jfarcand/mirroir-mcp` 作为参考项目拉入 TritonKit，并评估是否能接入 Triton CLI。

本地参考源码已归档到 `docs-linhay/references/mirroir-mcp/`，当前 clone HEAD 为 `7e97f0c`。

结论：不接 MCP，不引入 MCP JSON-RPC server，不让 agent 面对另一个工具面。TritonKit 只吸收 mirroir 的 host-side 能力模型，将其改造成 Triton 自己的 CLI adapter，并继续通过 `triton schema`、`triton capabilities`、`triton target`、`triton observe`、`triton action` 和 `triton evidence` 暴露机器可读契约。

## 参考对象

优先参考以下 mirroir 模块：

- `Sources/mirroir-mcp/Target.swift`
- `Sources/mirroir-mcp/TargetRegistry.swift`
- `Sources/mirroir-mcp/Protocols.swift`
- `Sources/mirroir-mcp/GenericWindowBridge.swift`
- `Sources/mirroir-mcp/IPhoneMirroringTarget.swift`
- `Sources/mirroir-mcp/ScreenTools.swift`
- `Sources/mirroir-mcp/InputTools.swift`
- `Sources/HelperLib/PermissionPolicy.swift`
- `docs/tools.md`

## 产品目标

为 Triton CLI 增加一个 host-side window automation adapter，使 agent 能在不嵌入 runtime 的情况下，对 iPhone Mirroring 或普通 macOS 窗口完成只读观察、截图和后续受控输入。

目标不是复制 mirroir，也不是新增 MCP 服务，而是把它的能力拆解为 Triton 当前信息架构下的能力：

1. target discovery：发现 iPhone Mirroring / macOS window target。
2. window status：判断窗口是否运行、是否可截图、坐标空间和尺寸。
3. screenshot artifact：生成可审计截图文件和 metadata。
4. observe current：通过 Vision OCR 或轻量元素识别输出文本、frame、tap point。
5. action input：通过 CGEvent 执行 tap、swipe、drag、type、press。
6. destructive policy：输入类动作默认受 `--confirm`、dry-run 和 schema metadata 约束。

## 范围

### In Scope

1. 新增 Triton-owned host window adapter，而不是依赖 mirroir 的 MCP server。
2. 支持 `iphone-mirroring` 与 `mac-window` 两类 host target。
3. 接入现有或即将重排后的 `triton target list/use/current/resolve`。
4. 接入 `triton observe current/tree --platform iphone-mirroring|mac-window --json`。
5. 接入 `triton screenshot --platform iphone-mirroring|mac-window --output <path> --json`。
6. 第二阶段接入 `triton tap/swipe/type/press --platform iphone-mirroring|mac-window`。
7. 所有 agent-facing 输出必须进入 `triton schema --json` 和 `triton capabilities --json`。
8. 证据输出必须能被 `triton evidence` 收集或引用。
9. 复用 Apache-2.0 代码时保留 license / attribution；优先重写适配层而不是整文件复制。

### Out of Scope

1. 不接入 MCP JSON-RPC server、`tools/list`、`tools/call` 或 MCP client 配置。
2. 不引入 npm wrapper。
3. 不接入 embacle / Rust FFI / AI vision，除非后续另建 space。
4. 不实现 mirroir 的 BFS / DFS exploration、skill generator、compiled steps 或 autonomous app exploration。
5. 不把 iPhone Mirroring 当作 embedded runtime 的替代品；它是 host-side opaque window adapter。
6. 不做真机 USB、远端 agent、设备云、Web/Wails UI 或对外 HTTP 产品面。

## 命令面目标

下期实现应尽量落到既有 Triton 命令族，而不是新增平行入口：

```text
triton target list --platform iphone-mirroring --json
triton target use <target-id> --json
triton target current --json
triton target resolve --platform iphone-mirroring --json

triton observe current --platform iphone-mirroring --json
triton observe tree --platform iphone-mirroring --json

triton screenshot --platform iphone-mirroring --output <path> --json

triton tap --platform iphone-mirroring --at x,y --confirm --json
triton swipe --platform iphone-mirroring --from x,y --to x,y --confirm --json
triton type <text> --platform iphone-mirroring --confirm --json
triton press <key> --platform iphone-mirroring --confirm --json
```

如 command surface optimization 已经完成 `target/action/observe` 重排，则使用新入口；否则先在现有 `device` / `observe` / `screenshot` / `tap` 等命令上增量接入。

## BDD 验收

### 场景一：agent 发现 iPhone Mirroring target

- Given macOS 上存在 iPhone Mirroring 窗口
- When 执行 `triton target list --platform iphone-mirroring --json`
- Then 输出单个 JSON object
- And `targets[]` 包含 target id、platform、state、window size、coordinate system、capabilities
- And 不需要启动 MCP server

### 场景二：agent 获取窗口截图

- Given iPhone Mirroring target 可截图
- When 执行 `triton screenshot --platform iphone-mirroring --output <path> --json`
- Then 写出 PNG 文件
- And JSON 输出包含 `ok/output/bytes/width/height/scale/target/source`
- And schema 标注 artifact 类型为 `screenshot`

### 场景三：agent 获取 OCR 可点击元素

- Given target 当前屏幕有可识别文本
- When 执行 `triton observe current --platform iphone-mirroring --json`
- Then 输出 `nodes[]` 或 `elements[]`
- And 每个元素包含 text、frame、tapPoint、confidence、source
- And 输出包含 coordinate system 和截图 artifact 引用

### 场景四：只读能力无需确认

- Given agent 只执行 target list、observe、screenshot
- When 命令运行
- Then 不要求 `--confirm`
- And schema 中 `destructive=false`

### 场景五：输入动作必须显式确认

- Given agent 要执行 `tap/swipe/type/press`
- When 未传 `--confirm`
- Then 命令返回单个 JSON 错误 envelope
- And error code 为 `confirmation_required`
- And `nextAction` 给出带 `--confirm` 的下一步命令

### 场景六：host-side 权限不足时可诊断

- Given macOS 未授予 Screen Recording 或 Accessibility
- When 执行 screenshot、observe 或 input 命令
- Then 命令返回单个 JSON 错误 envelope
- And error code 为 `screen_recording_permission_denied` 或 `accessibility_permission_denied`
- And hint 指向系统权限修复路径

### 场景七：证据链可复查

- Given 已执行 host-side observe 和 screenshot
- When 执行 `triton evidence --output <dir.tritonevidence> --json`
- Then evidence manifest 包含 host target、screenshot artifact、observe JSON artifact 和 source command

## 技术边界

1. CLI 仍由 Swift ArgumentParser 暴露，不引入 MCP server 作为内部控制面。
2. macOS host adapter 可以依赖 AppKit、ApplicationServices、CoreGraphics、Vision；这些依赖只进入 CLI package，不进入根 SwiftPM embedded SDK。
3. 坐标必须明确标注为 host window point，不与 embedded runtime 的 UIKit point 混用。
4. `iphone-mirroring` 的 keyboard shortcut 限制必须写入 schema / docs：iOS app 不能接收 Cmd+[、Cmd+L 等 Mac keyboard shortcuts。
5. 只读观察先落地；输入动作作为第二阶段，必须先有 confirmation 和 JSON failure contract。

## 当前状态

- 参考源码已克隆到 `docs-linhay/references/mirroir-mcp/`。
- 已完成初步评估：推荐只吸收 host-side 能力，不接 MCP。
- 本 space 仅建立下期待做计划；尚未修改 TritonKit CLI 代码。
