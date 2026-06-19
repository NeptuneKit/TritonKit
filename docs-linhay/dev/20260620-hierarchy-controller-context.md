# Hierarchy Controller Context

## 背景

Web Device Hub 需要在模拟器壳上显示当前 `UIViewController`。这类标签属于运行时语义，不应从截图像素、UIKit wrapper view 名称、App 名称或静态 mock 名称推断。

本轮已将 controller 语义前移到 `HierarchyScene.controllerContext`，由 runtime / CLI 提供机器可读事实，Web 只消费和展示。

## 契约原则

1. Runtime / CLI 是事实源：iOS embedded runtime 负责按 UIKit route 语义解析 root、presented、tab selected、navigation、split、page 和 custom visible child。
2. Web 只读消费：设备壳 badge 优先显示 `controllerContext.activeControllerName`，不会定义新的业务控制能力。
3. 旧 runtime 允许 fallback：如果 payload 没有 `controllerContext`，Web / bridge 可从 `ios:controller:*` 或 `runtime-controller` 节点父链推导，但 UI 必须显示 `fallback` 标记。
4. 选中节点优先：当 view-tree 选中某个子 view 时，壳标注优先显示该节点最近的 controller ancestor；没有选中节点时才显示 scene active controller。
5. 不伪造语义：没有 runtime route context、也没有 controller node 时，显示未暴露状态，不从截图、wrapper view、target 名称或 appName 猜测。

## 实现落点

- Shared DTO：`TKHierarchyScene.controllerContext`
- Runtime payload：`TKHierarchyInfo.controllerContext`
- CLI scene 转换：透传 runtime route context；旧 payload 生成 `scene-controller-node-fallback`
- Web bridge：legacy iOS fallback 同步生成 `controllerContext`
- Web shell：`controller-shell-badge` 展示 `UIViewController · <ClassName>`，fallback 时显示 `fallback`

## 验证门禁

- `swift test --package-path CLI --filter HierarchySceneRuntimeTests`
- Web bridge / DOM focused tests for legacy controller context and shell badge
- `npm --prefix Web run build`
- Browser smoke：当前 simulator 页面 badge 显示 controller 名称，且横向溢出为 `0`

## 复用规则

后续任何 Web mock 可见标签只要依赖 runtime state，都先要求 CLI / HTTP DTO 暴露机器可读字段；Web 可以有降级展示，但必须标注 fallback 来源。
