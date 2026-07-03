# UIKit Public API Technical Research v01

## 背景

本调研对应 S1 状态理解：让 AI 通过 `triton state app|scene|route|responder --json` 读取 App 进程内上下文，而不是只依赖截图或 AX 文案猜测页面位置。实现必须只使用公开 UIKit/Foundation API，保持 DEBUG-only、App 内、机器可读、可脱敏。

## 现有代码入口

1. `Sources/TritonKitShared/TKMessage.swift`
   - 当前已有 `runtimeManifest/appInfo/hierarchy/accessibility/geometry/hitTest/screenshot/input`。
   - S1 需要新增 state request type，避免复用 `appInfo` 后无法区分 app、scene、route、responder 粒度。
2. `Sources/TritonKit/TritonKitRequestHandler.swift`
   - 已有 `keyWindows()`、`currentGeometry()`、`findFirstResponder(in:)`、`oid(for:)`，可复用到 scene/window/responder state。
   - route state 需要新增公开 UIViewController 遍历逻辑。
3. `Sources/TritonKitCLI/main.swift`
   - `RuntimeManifest` 已证明 CLI 可通过 `/request` 同步读取 embedded SDK payload。
   - S1 可新增 `triton state app|scene|route|responder --json`，共用 target resolve、HTTP client、error envelope。
4. `Sources/TritonKitShared/TKCLITransportModels.swift`
   - `TKCLICommandRequest.requestType` 需要映射 `stateApp/stateScene/stateRoute/stateResponder`。
   - `TKCommandSchema` 可暴露 state 命令的 runtime scope 与 success shape。

## Apple 文档依据

本地 Apple Developer 文档镜像确认的公开 API：

1. `UIApplication.connectedScenes`：公开返回当前已连接 scene 集合。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIApplication/connectedScenes.md`
2. `UIApplication.preferredContentSizeCategory`：公开读取动态字体分类。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIApplication/preferredContentSizeCategory.md`
3. `UIScene.activationState`：公开读取 scene 激活状态。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIScene/activationState-swift.property.md`
4. `UIWindow.isKeyWindow`、`rootViewController`、`windowLevel`：公开读取 key window、根控制器和窗口层级。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIWindow/isKeyWindow.md`
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIWindow/rootViewController.md`
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIWindow/windowLevel.md`
5. `UIViewController.presentedViewController`、`navigationController`：公开读取 presented 与 navigation 关系。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIViewController/presentedViewController.md`
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UIViewController/navigationController.md`
6. `UINavigationController.viewControllers`：公开读取 navigation stack。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UINavigationController/viewControllers.md`
7. `UITabBarController.selectedIndex`、`viewControllers`：公开读取 tab 结构与选中位置。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UITabBarController.md`
8. `UITextInputTraits.keyboardType`、`isSecureTextEntry`：公开读取输入特征。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UITextInputTraits/keyboardType.md`
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/UIKit/UITextInputTraits/isSecureTextEntry.md`
9. `Locale.current`、`Locale.preferredLanguages`、`ProcessInfo.processInfo.systemUptime`：公开读取区域、语言与进程运行信息。
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/Foundation/Locale.md`
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/Foundation/Locale/preferredLanguages.md`
   - `/Users/linhey/.nolon/skills/apple-docs/references/documentation/Foundation/ProcessInfo/systemUptime.md`

## 可用公开 API 与字段

### `state app`

字段建议：

- `bundleIdentifier`：`Bundle.main.bundleIdentifier`
- `displayName`：`CFBundleDisplayName` / `CFBundleName`
- `version`：`CFBundleShortVersionString`
- `build`：`CFBundleVersion`
- `localeIdentifier`：`Locale.current.identifier`
- `preferredLanguages`：`Locale.preferredLanguages`
- `preferredContentSizeCategory`：`UIApplication.shared.preferredContentSizeCategory.rawValue`
- `userInterfaceStyle`：key window `traitCollection.userInterfaceStyle`
- `processUptimeSeconds`：`ProcessInfo.processInfo.systemUptime`
- `sceneCount` / `windowCount`：公开 scene/window 统计

### `state scene`

字段建议：

- `scenes[]`：每个 `UIWindowScene` 的 `activationState`、`screen.bounds`、`interfaceOrientation`、window count。
- `windows[]`：`isKeyWindow`、`isHidden`、`alpha`、`windowLevel.rawValue`、`bounds`、`safeAreaInsets`、`rootViewControllerClass`。
- `keyWindow`：当前优先 key window 摘要。

### `state route`

字段建议：

- `rootController`：key window root view controller class/title。
- `visibleController`：沿 tab/nav/split/presented 公开关系推导的当前可见 controller。
- `presentedStack`：从 root 或 visible controller 公开 `presentedViewController` 链路。
- `navigationStack`：若存在 `UINavigationController`，输出 stack class/title。
- `tab`：若存在 `UITabBarController`，输出 selected index、selected title、tab titles。
- `swiftUIBoundary`：遇到 `UIHostingController` 只输出 class/title，不反射 SwiftUI 私有 tree。

### `state responder`

字段建议：

- `firstResponder`：class、oid、frame、window index。
- `textInput`：是否 `UIKeyInput`、是否 editable、是否 secure、keyboard type、return key type。
- `redaction`：secure text 不回显文本，只输出 `secureText=length-only` 或 `not-collected`。

## 不可做清单

1. 不反射 SwiftUI 私有 view tree；只报告 `UIHostingController` 边界与 UIKit/AX 可见线索。
2. 不读取系统窗口、SpringBoard、系统键盘全局状态或跨 App 内容。
3. 不 dump responder 文本内容；`UITextField/UITextView` 文本读取进入后续 attrs v2，并按 secure 策略脱敏。
4. 不用私有 selector 寻找 first responder；只递归当前 App window view tree 的 `isFirstResponder`。
5. 不承诺 route 等同业务路由名；默认只输出 controller/container 结构。业务路由名必须 opt-in provider。

## 推荐 DTO / 命令 shape

```bash
triton debug state app --json
triton debug state scene --json
triton debug state route --json
triton debug state responder --json
```

四类响应都包含：

- `ok`
- `capturedAt`
- `runtime`
- `targetConnectionState`
- 对应 state payload
- `unsupported[]` 或 `warnings[]`

首期为降低 CLI/HTTP 复杂度，embedded request type 可以拆成四个：`stateApp`、`stateScene`、`stateRoute`、`stateResponder`。后续 `snapshot` 再按 include 聚合。

## 测试建议

1. Shared DTO encode/decode：
   - app state 包含 bundle、version/build、locale、language、style、uptime。
   - scene state 包含 scene/window/keyWindow。
   - route state 包含 visible controller、navigation stack、tab、presented stack。
   - responder state 对 secure text 只报告 secure 与 redaction，不报告明文。
2. Request mapping：
   - `stateApp/state.app/app` -> `.stateApp`
   - `stateScene/state.scene/scene` -> `.stateScene`
   - `stateRoute/state.route/route` -> `.stateRoute`
   - `stateResponder/state.responder/responder` -> `.stateResponder`
3. CLI schema：
   - `schema --command state --json` 暴露 app/scene/route/responder。
4. Smoke：
   - mock embedded runtime 返回四类 state JSON。
   - `triton state app|scene|route|responder --json` 可通过 mock server 验证。

## 风险

1. route 推导不是业务路由，只是公开 controller/container 拓扑；文档和字段必须避免误导 AI。
2. 多 scene / 多 window 场景下，key window 可能为空；响应必须返回 windows 列表和 selection reason。
3. SwiftUI 页面只能通过 `UIHostingController`、AX 和业务 opt-in provider 补语义，不能靠私有 tree。
4. responder 文本和剪贴板属于敏感数据，首期只报告状态和 traits。

## 结论

S1 可以先实现 `state app|scene|route|responder`，它们都能映射到公开 UIKit/Foundation API。这个切片能显著提升 AI 对当前 App 上下文的判断力，并为后续 `snapshot`、`attrs v2` 和语义动作提供稳定输入。
