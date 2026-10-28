# #221 验证与交接

## 根因和候选

原 `findFirstResponder` 先检查父视图的 `isFirstResponder` 再递归，包装组件转发子对象焦点时父对象会遮蔽实际输入子对象。改为 descendant 优先，只返回 `isFirstResponder` 的对象，保留显式 targetOID 与 foreground root 限制。不会把未聚焦的 `searchTextField` 当作通用 fallback。

## UIKit 回归

新增 `TKUIKitWindowTests/TKSearchBarInputFocusTests`：转发焦点容器确定性回归、实际 UISearchBar 坐标 tap → 无 OID type、另一编辑器焦点及无焦点负例。其 `forwardedFocusResolvesChild` 对旧父优先实现预期失败；截至交接未在 iOS 执行，不把静态反证写成已运行 red test。

## 官方资料核对

使用本地 Apple 文档 skill 查询 `UISearchBar.searchTextField`（iOS 13+，用户输入查询的文本字段）和 `UIResponder.isFirstResponder`（对象当前第一响应者状态）。本轮不依赖私有类名、KVC 或 responder 注入，也未操作真实设备。

## 需要主控的验证

先保存 Triton status/doctor/capabilities/schema/plan。用现有 package scheme 的 iOS Simulator XCTest 入口执行 `TritonKitTests/TKUIKitWindowTests/TKSearchBarInputFocusTests`，检查 tap 后 type 目标 OID 与 searchTextField 一致、sample 被插入，随后重跑 foreground input/modal 相邻用例。若真实工具链行为不同，保留具体窗口/焦点失败而不弱化前台检查。

`swift test --no-parallel --jobs 2` 根包 macOS 验证因宿主高负载按主控要求在编译阶段停止，未得到测试结果；待主控分配窗口以 `--build-system native --jobs 2` 重新执行。它不覆盖 `#if canImport(UIKit)` 的用例。独立分支 docs gate 因 SP-228～237 位于其他 issue worktree 而存在连续编号缺口；由主控联合登记后再验。

主控已接管联合候选验证，将在现有 App-hosted XCTest 工程引入本测试。候选已冻结，本worktree不再启动编译或设备任务。
