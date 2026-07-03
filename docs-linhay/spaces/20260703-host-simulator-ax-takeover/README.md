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
5. **单元测试与门禁要求 (Validation Gates)**：
   * 补充 `Tests/TritonKitTests/` 中的 XPC 动态加载与分发逻辑 Mock 校验，确保 CI 下不崩溃且能正常打包。

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
