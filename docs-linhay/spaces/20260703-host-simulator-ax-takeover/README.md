# Space: 20260703-host-simulator-ax-takeover

## 背景与目标 (Background & Goals)

TritonKit 原本的 iOS 无障碍（AX）树获取强依赖于嵌入在 App 内部的 Debug SDK 运行时。这使得在测试 App 未启动、闪退、或展示系统级弹窗（如“允许定位”、“相机授权”等 SpringBoard 窗口）时，AI Agent 会由于无法建立 WebSocket 通信而失去对模拟器的感知与控制能力。

虽然参考项目 `baguette` 提供了基于 XPC 和 iOS 模拟器私有框架 `AccessibilityPlatformTranslation` 的进程外 AX 树获取能力，但目前 TritonKit 对其是以外部二进制形式进行间接调用的。

**目标**：在不依赖外部 `baguette` 项目的前提下，**将进程外 XPC AX 树获取与原生控制能力直接复制并重构融合进 TritonKit 共享 Core 与 CLI 模块中**。使 TritonKit 能够物理独立掌控 iOS 模拟器的全部运行状态（包含系统级桌面、系统级弹窗以及未注入 SDK 的第三方 App）。

---

## 需求范围 (Scope & Requirements)

1. **动态框架加载与符号链接 (Dynamic Loading)**：
   * 在 macOS 宿主环境运行时，通过 `dlopen` 动态加载私有框架 `/System/Library/PrivateFrameworks/AccessibilityPlatformTranslation.framework/AccessibilityPlatformTranslation`。
   * 通过 Objective-C Runtime 动态获取并实例化私有类 `AXPTranslator`。
2. **XPC 桥接 Token 调度分发 (Token Dispatcher)**：
   * 在 Swift 中继承 `NSObject` 实现 `TokenDispatcher`。
   * 实现符合 AXPTranslator 接口约定的 Objective-C 回调选择器（Selectors）：
     * `accessibilityTranslationDelegateBridgeCallbackWithToken:`
     * `accessibilityTranslationConvertPlatformFrameToSystem:withToken:`
     * `accessibilityTranslationRootParentWithToken:`
   * 对接 `SimDevice` 的 `sendAccessibilityRequestAsync:completionQueue:completionHandler:` 方法，实现同步阻塞式 XPC 请求等待。
3. **坐标变换与树构建 (Coordinate Transform & Node Construction)**：
   * 实现逻辑屏幕坐标转换（`AXFrameTransform`），将 macOS 宿主物理窗口坐标映射为标准的 iOS 设备逻辑分辨率坐标。
   * 递归解析 `accessibilityChildren` 生成标准跨平台的 `TKAXNode` 树。
4. **命令行接口暴露与平台适配 (CLI Integration)**：
   * 将 `HostPlatform` 扩展支持 `ios`，将 `triton sim ax` 或 `triton hierarchy --platform ios` 路由至本地宿主 XPC 驱动层。
   * `triton sim ax --json` 的失败必须返回 `TKCLIErrorResponse`，覆盖私有框架不可用、模拟器目标不存在、frontmost AX root 不可用、platform element 转换失败和 AX tree 不可用等稳定错误码，不允许只输出人类文本。
5. **单元测试与门禁要求 (Validation Gates)**：
   * 补充 `Tests/TritonKitTests/` 中的 XPC 动态加载与分发逻辑 Mock 校验，确保 CI 下不崩溃且能正常打包。

## Web Mock 验收补充：界面与 AX 审查插槽

### 场景

- Given Web mock 已连接 iOS Simulator 画面流，且被测 Debug App 已连接 embedded TritonKit runtime
- When 用户在布局中打开“界面与 AX 审查”插槽
- Then 插槽必须通过 `/web/host-hierarchy?platform=ios&target=<simulator-udid>&source=runtime` 读取 App runtime hierarchy
- And 当 runtime target 未暴露 `simulatorUDID` 且当前只有一个连接中的 iOS runtime target 时，bridge 可以将该 simulator host target 解析到唯一 runtime target
- And Web target 列表只展示对 Web 当前可用的 iOS Simulator：单纯 CoreSimulator `Booted` 但没有 App runtime 连接证据的 simulator 不得出现在下拉或自动连接列表中
- And 视图树 / AX 树必须显示真实节点，而不是停留在“无数据或未就绪”或“无 AX 节点”
- And 用户选中任意节点后，底部详情区的“查看更多信息”必须打开 modal sheet，展示节点 ID、父节点、层级、来源、状态和原始 DTO
- And Web 展示可见节点时必须按父链计算有效可见性，隐藏父节点下的子节点不得出现在审查树或画面 overlay 中
- And 用户已经选中某个画面 overlay 节点后，再次点击该节点内部区域时，应按点击坐标选中对应的更小子节点

### 边界

- 多个 iOS runtime target 同时连接且缺少可匹配 `simulatorUDID` 时，不做猜测匹配。
- CoreSimulator 后台 `Booted` 不等于 Web 可用 target；iOS Web target 需要 runtime 连接证据。
- Web 仍只读展示 hierarchy / AX DTO，不新增业务控制闭环；modal sheet 只展示现有 DTO 字段，不从截图或像素推断业务事实。
- `visible` / `isHidden` / `alpha` 只作为 hierarchy DTO 字段使用；Web 不从截图像素反推可见性。

### 2026-07-06 Web bridge 文件归类

- `Web/dev/iosSimulatorBridge.mjs` 兼容入口已删除，Vite 与测试直接 import `Web/dev/ios-bridge/index.mjs`。
- host target 映射测试已拆到 `Web/dev/ios-bridge/hostTargets.test.mjs`，`iosSimulatorBridge.test.mjs` 只保留 middleware / route 行为测试。
- iOS App runtime mirror 匹配逻辑已拆到 `Web/dev/ios-bridge/runtimeMirror.mjs`，host hierarchy 抓取与 legacy iOS scene 转换已拆到 `Web/dev/ios-bridge/hierarchy.mjs`。
- `Web/dev/ios-bridge/index.mjs` 已收缩为 middleware / route 分发入口；托管 `triton serve`、JSON/body helper、图片解析、host screenshot、host input 和 iOS/Android/Harmony 流代理分别拆到 `tritonServe.mjs`、`http.mjs`、`image.mjs`、`hostScreenshot.mjs`、`hostInput.mjs`、`streamRoutes.mjs`。
- host logs 的 triton 调用与 ndjson 解析统一放在 `hostLogs.mjs`；host target 的 capture plan、执行和 DTO 映射统一放在 `hostTargets.mjs`。
- bridge route 测试继续归类：hierarchy route 用例拆到 `Web/dev/ios-bridge/hierarchyRoute.test.mjs`，fake triton / fake host server / middleware invoke 支撑函数拆到 `Web/dev/ios-bridge/testSupport.mjs`。
- 旧版 Web UI 的 `appFallbackDom.test.mjs` / `appFallbackDomHarness.mjs`、`HostBridgeNotice`、`hostBridgePresentation` 和 `npm run test:legacy-dom` 已删除；`happy-dom` 依赖已移除。
- `Web/src/App.tsx` 已拆成瘦入口；布局树类型和操作在 `Web/src/layoutModel.ts`，pane / card 渲染在 `Web/src/components/AppCanvas.tsx`。
- 验证：`node --test dev/ios-bridge/hierarchyRoute.test.mjs dev/ios-bridge/hostTargets.test.mjs dev/iosRuntimeMirrorBridge.test.mjs dev/iosSimulatorBridge.test.mjs` 通过 30 项；`cd Web && npm test` 与 `cd Web && npm run build` 通过。

---

## 技术方案设计 (Technical Design)

```
             Triton CLI (triton sim ax)
                        │
                        ▼ (Dynamic Loading)
             AccessibilityPlatformTranslation
                        │
                        ▼ (XPC Dispatching)
         ┌──────────────TokenDispatcher──────────────┐
         │                                           │
         ▼ (Callback)                                ▼ (sendAccessibilityRequestAsync:)
   AXPTranslatorRequest                         SimDevice (CoreSimulator)
```

### 1. 核心类结构
* **`AXPTranslatorAccessibility`**: 实现进程外 `Accessibility` 协议。
* **`TokenDispatcher`**: 注册与分发 XPC 消息。
* **`AXElementReader`**: 用 Objective-C 动态方法读取 AX 属性。
* **`AXNode`**: 递归构建的 AX 层次结构快照。

### 2. 目录落位
* 新增的宿主端 iOS AX 驱动代码放置在 `Sources/TritonKit/Host/` 目录下（或通过 `#if os(macOS)` 包裹的源文件）。
