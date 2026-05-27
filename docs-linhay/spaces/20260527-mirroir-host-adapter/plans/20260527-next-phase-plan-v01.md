# Mirroir Host Adapter 下期执行计划 v01

## 执行原则

1. 不接 MCP，不暴露 `triton mcp`，不引入 mirroir 的 stdio server。
2. 先只读，后输入；先 schema / capabilities，后真实 action。
3. 所有能力必须挂到 Triton 当前 CLI 信息架构：`target`、`observe`、`screenshot`、`action`、`evidence`。
4. 不影响 embedded runtime；host-side opaque window adapter 是独立 platform。
5. 每个切片先补 BDD / 测试或可执行证据，再实现。

## Phase 0：参考代码审计与接口冻结

目标：决定哪些能力重写、哪些能力可局部移植。

任务：

1. 阅读 mirroir 的 window、capture、input、OCR、permission 相关文件。
2. 标注 Apache-2.0 复用边界：直接复制、改写、仅参考。
3. 输出 Triton host window adapter 的 Swift 类型草图。
4. 明确 CLI package 依赖是否需要新增 macOS framework link。

验收：

1. 形成 `docs-linhay/dev/host-window-adapter-design.md`。
2. 设计文档明确 `iphone-mirroring` 与 `mac-window` 的 target model。
3. 明确第一期不接 input action 或只做 dry-run。

## Phase 1：Target Discovery 只读接入

目标：让 agent 能发现 host-side opaque window target。

拟新增或调整文件：

- `Sources/TritonKitCLI/CLIHostWindowModels.swift`
- `Sources/TritonKitCLI/CLIHostWindowRuntime.swift`
- `Sources/TritonKitCLI/CLIHostCommands.swift` 或后续 `CLITargetCommands.swift`
- `CLI/Tests/TritonKitCLITests/HostWindowTargetTests.swift`

目标命令：

```text
triton target list --platform iphone-mirroring --json
triton target list --platform mac-window --json
triton target resolve --platform iphone-mirroring --json
```

测试：

1. unit test 覆盖 target config parsing。
2. unit test 覆盖 window state 到 JSON DTO 的映射。
3. 无真实窗口时返回 `target_not_found`，不是 crash 或空文本。

验收：

1. `triton schema --command target --json` 暴露 host window target contract。
2. `triton capabilities --json` 能体现 host window adapter 可用性或不可用原因。

## Phase 2：Screenshot 只读接入

目标：将 host window screenshot 变成 Triton evidence-compatible artifact。

拟新增或调整文件：

- `Sources/TritonKitCLI/CLIHostWindowCapture.swift`
- `Sources/TritonKitCLI/CLIActionCommands.swift`
- `Sources/TritonKitCLI/CLISchemaRuntime.swift`
- `CLI/Tests/TritonKitCLITests/HostWindowScreenshotTests.swift`

目标命令：

```text
triton screenshot --platform iphone-mirroring --output <path> --json
triton screenshot --platform mac-window --output <path> --json
```

测试：

1. output path validation。
2. metadata JSON contract。
3. permission failure envelope。
4. artifact metadata 可以被 evidence manifest 引用。

验收：

1. 成功输出包含 `ok/output/bytes/width/height/scale/target/sourceCommand`。
2. 失败输出为单个 JSON envelope。
3. schema 标注 `artifacts=["screenshot"]`。

## Phase 3：Observe / OCR 只读接入

目标：给 agent 一个不依赖 embedded runtime 的 `observe current`。

拟新增或调整文件：

- `Sources/TritonKitCLI/CLIHostWindowObservation.swift`
- `Sources/TritonKitCLI/CLIObservationCommands.swift`
- `Sources/TritonKitCLI/CLIObservationModels.swift`
- `CLI/Tests/TritonKitCLITests/HostWindowObserveTests.swift`

目标命令：

```text
triton observe current --platform iphone-mirroring --json
triton observe tree --platform iphone-mirroring --json
```

测试：

1. OCR element DTO contract。
2. coordinate system 必须为 `host-window-points`。
3. no text detected 时仍返回 `ok=true` 和空元素，不作为失败。
4. screenshot 或 Vision 权限失败时返回明确 error code。

验收：

1. 输出元素包含 `text/frame/tapPoint/source/confidence`。
2. 输出包含 target metadata 和 screenshot artifact 引用。
3. schema 暴露 `observe.surface` 的 host-window fields。

## Phase 4：Evidence 集成

目标：host-side screenshot / observe 能进入 `.tritonevidence`。

任务：

1. evidence manifest 增加 host-side target metadata。
2. capture/evidence 支持收集 host window screenshot 和 observe JSON。
3. source command 记录 platform、target、output。

测试：

1. evidence manifest 包含 host target。
2. missing permission 时 skipped artifact 有明确 reason。
3. summary 可以显示 host-side artifact availability。

验收：

1. `triton evidence --output <dir.tritonevidence> --json` 可收集 host-side artifact。
2. 不要求 connected embedded runtime。

## Phase 5：输入动作接入

目标：在确认策略下接入 tap、swipe、type、press。

前置条件：

1. Phase 1-4 完成。
2. schema 已有 destructive metadata。
3. JSON 错误 envelope 已统一。

目标命令：

```text
triton tap --platform iphone-mirroring --at x,y --confirm --json
triton swipe --platform iphone-mirroring --from x,y --to x,y --confirm --json
triton type <text> --platform iphone-mirroring --confirm --json
triton press <key> --platform iphone-mirroring --confirm --json
```

测试：

1. 未传 `--confirm` 返回 `confirmation_required`。
2. 参数解析失败返回 `validation_failed`。
3. permission failure 返回 `accessibility_permission_denied`。
4. dry-run 输出将执行的 action request，不触发 CGEvent。

验收：

1. mutating action 默认不可静默执行。
2. success output 包含 action、target、coordinate system、elapsedMs。
3. evidence ledger 可记录 action source command。

## Phase 6：文档与 public skill 同步

目标：agent 使用入口不依赖阅读参考项目。

任务：

1. 更新 README 的 host-side adapter 能力说明。
2. 更新 `docs-linhay/dev/ai-cli-readable-control.md`。
3. 更新 public skills 中 emulator / real-project 回归流程，说明何时用 embedded runtime，何时用 host window adapter。
4. 更新 schema/capabilities 示例。

验收：

1. 新 agent 只看 `triton schema`、`triton capabilities` 和随包 skill，就能知道 host-side adapter 的能力和限制。
2. 不出现 MCP 配置说明。

## 风险与刹车线

风险：

1. macOS Screen Recording / Accessibility 权限不可在 CI 中稳定验证。
2. iPhone Mirroring 依赖 macOS 15+，测试覆盖需要分层。
3. host-window coordinates 与 UIKit coordinates 容易混淆。
4. CGEvent 输入动作可能误触真实设备，必须保持显式确认。

刹车线：

1. 如果需要引入 MCP server 才能推进，停止并重新评审。
2. 如果需要把 CLI package 的依赖泄漏到根 SwiftPM embedded SDK，停止。
3. 如果无法产出单个 JSON error envelope，先修错误模型。
4. 如果只能靠真实 iPhone Mirroring 才能跑单元测试，改为抽象协议和 mock DTO 测试。

## 建议排期

下期第一刀只做 Phase 0-2：

1. 设计文档。
2. host target discovery DTO 和 schema。
3. host screenshot metadata contract。

暂不做输入动作。原因是只读能力风险低，能先验证 target/capabilities/schema/evidence 的信息架构是否正确。
