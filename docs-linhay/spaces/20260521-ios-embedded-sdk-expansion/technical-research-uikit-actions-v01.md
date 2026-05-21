# Technical Research: UIKit Actions v01

## 背景

S3 的动作必须只依赖公开 UIKit API，并且每个动作都能给出成功/失败原因。首批实现 `focus`、`setText`、`selectSegment`、`setSwitch`，后续再扩展 `submit`、`set-slider`、`stepper`、`scroll-to-visible`。

## 现有代码入口

- `performSemanticAction(_:)`
- `resolveTextInputResponder`
- `resolveControl`
- `performExactTextInsertion`
- `performClear`
- 既有 `performTap` 中的 UISwitch / UISegmentedControl / UIControl target-action 经验

## 可用公开 API

1. `UITextField` / `UITextView`：`becomeFirstResponder()`、`text`、`insertText`、`deleteBackward`、`isSecureTextEntry`。
2. `UISegmentedControl`：`numberOfSegments`、`titleForSegment(at:)`、`selectedSegmentIndex`、`sendActions(for: .valueChanged)`。
3. `UISwitch`：`isOn`、`setOn(_:animated:)`、`sendActions(for: .valueChanged)`。
4. `UIControl` / `UIView`：通过已登记 object id 或 hit-test 坐标解析目标 view。

## 不可做清单

1. 不通过私有 UIKit selector 触发 action。
2. 不反射 SwiftUI 私有 view tree。
3. 不把系统键盘、Home、App Switcher 作为 embedded runtime 能力。
4. 不在 secure text 返回明文。

## 推荐实现边界

1. `focus`：只承诺文本输入控件，成功返回目标 class 与 elapsedMs。
2. `setText`：先聚焦，再清空，再插入精确文本；secure 只返回长度和 redaction 状态。
3. `selectSegment`：按 title 或 zero-based index 设置；未命中 title 或越界返回失败。
4. `setSwitch`：支持 `on/off/toggle`；非法 value 返回失败。

## 测试建议

1. Shared semantic response shape 单测。
2. Mock smoke 验证 CLI request payload 与 redaction。
3. 后续 iOS harness 覆盖真实 UITextField、secure UITextField、UISegmentedControl、UISwitch。
4. 真实项目 smoke 用 `wait/assert/snapshot/ledger` 验证动作后的业务状态。

## 风险

1. `sendActions(for:)` 只表示事件已派发，不等价于业务异步完成。
2. 页面重建会让 object id 失效，CLI 侧必须保留 selector 策略与 source command。
3. 自定义控件可能包装 UIKit 控件，首期不做深层业务语义猜测。
