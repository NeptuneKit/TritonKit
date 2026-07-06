# Space: 20260706 Web Hierarchy Source Tabs

## 背景

Web mock 的“界面与 AX 审查”当前把同一份 `HierarchyScene.nodes` 同时派生成“视图树”和“AX 树”。这对 iOS runtime / Lookin-style scene 尚可解释，但 Android 与 Harmony 目前并没有独立原生 View tree 与 AX tree 两份事实源：

- Android 优先使用 `android-bridge` AccessibilityService 树，失败时退到 UIAutomator `host-layout`。
- Harmony 使用 HDC `uitest dumpLayout` 的 `host-layout`。

因此 Android / Harmony 下两个 tab 高度一致，会误导用户以为已经有两套独立树。

## 目标

Web mock 按平台和 hierarchy source 诚实展示树来源：

- iOS 保留“视图树 / AX 树”。
- Android / Harmony 不再显示两份等价树，改为单个来源 tab。
- 当没有独立 AX 源时，界面明确说明当前树来自 `android-bridge` 或 `host-layout`。

## BDD 场景

- Given 当前审查目标是 Android 且 hierarchy scene 节点来源为 `android-bridge`
- When 用户打开“界面与 AX 审查”
- Then 只显示“辅助功能树”tab
- And 不显示独立“视图树 / AX 树”两个 tab

- Given 当前审查目标是 Android 且 hierarchy scene 节点来源为 `host-layout`
- When 用户打开“界面与 AX 审查”
- Then 只显示“布局树”tab
- And 提示这是 UIAutomator host layout，不是独立 View/AX 双源

- Given 当前审查目标是 Harmony
- When 用户打开“界面与 AX 审查”
- Then 只显示“布局树”tab
- And 提示这是 HDC dumpLayout host layout，不是独立 View/AX 双源

- Given 当前审查目标是 iOS
- When 用户打开“界面与 AX 审查”
- Then 继续显示“视图树”和“AX 树”

## 边界

- 不新增 Android / Harmony 后端采集能力。
- 不把 Web mock 升级成业务控制入口。
- 不从截图像素反推原生 View 或 AX 事实。

## 验收

- 新增或更新纯模型测试覆盖 platform/source 到 tabs 的映射。
- `cd Web && npm test` 通过。
- `cd Web && npm run build` 通过。
- `docs-linhay/scripts/check-docs.sh` 与 `git diff --check` 通过。

