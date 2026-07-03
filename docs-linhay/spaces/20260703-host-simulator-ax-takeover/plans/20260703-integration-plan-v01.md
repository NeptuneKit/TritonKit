# Plan: 20260703 Host Simulator AX Integration Plan (v01)

## 任务拆分与路线图 (Milestones)

### Milestone 1: 移植 AX 核心驱动 (AX Core Porting)
* **任务 1.1**：在 `Sources/TritonKit/Host/` 线下新建 `iOS/AX/` 目录结构。
* **任务 1.2**：拷贝并移植 baguette 参考项目的核心底层文件：
  * `Accessibility.swift` (定义接口协议)
  * `AXElementReader.swift` (反射读取属性)
  * `AXFrameTransform.swift` (坐标缩放折算)
  * `AXNode.swift` (树数据模型)
  * `AXPTranslatorAccessibility.swift` (主调度与 Token XPC 通讯)
* **任务 1.3**：重构重命名与模型转换：
  * 替换 `import Baguette` 为 `import TritonKitShared`。
  * 将 `log`、`logErr` 替换为 TritonKit 内置的 `TKLogger`。
  * 将 `Point`、`Rect` 适配转换为 TritonKit 的 `TKPoint` 和 `TKRect`。

### Milestone 2: 宿主适配器注册与分发 (Host Adapter Registration)
* **任务 2.1**：在 `Sources/TritonKit/Host/` 的 Simulator 控制管理器中，引入 `AXPTranslatorAccessibility` 实例的创建与注入。
* **任务 2.2**：将 `SimDevice` 实例获取接口（通过 `CoreSimulator`）接入到 `TokenDispatcher.resolveDevice()` 中。

### Milestone 3: 命令行子命令对接 (CLI Routing & Subcommands)
* **任务 3.1**：修改 `Sources/TritonKitCLI/CLIHostModels.swift` 中的 `HostPlatform`，追加 `ios` 支持。
* **任务 3.2**：在 `CLIActionCommands.swift` 的 `AccessibilityTree` 结构体中，当 `platform == .ios` 时，直接路由至宿主端 `AXPTranslatorAccessibility` 的 `describeAll()` 执行流程，而不是通过 websocket 获取。
* **任务 3.3**：在 `triton debug hierarchy --platform ios` 中支持 `--host-only` 参数，绕过 websocket 直连模拟器获取系统级 AX 树。

### Milestone 4: 测试与验证 (Validation Gate)
* **任务 4.1**：在 `Tests/TritonKitTests/` 中加入 `TKHostAXTests.swift`，测试 `TokenDispatcher` 回调与 XPC 模拟分发流程。
* **任务 4.2**：运行全量编译门禁：
  ```bash
  swift build --package-path CLI -c debug
  docs-linhay/scripts/check-docs.sh
  ```
