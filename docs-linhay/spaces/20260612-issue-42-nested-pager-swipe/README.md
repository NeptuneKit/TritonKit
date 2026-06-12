# Issue 42: Nested Pager Swipe Targeting

## 背景

GitHub issue #42 反馈：真实 iOS 页面里，外层是横向 pager，内层页面包含纵向列表时，`triton swipe` 起点落在列表内容上会命中最近的内层 `UIScrollView`，导致横向滑动无法驱动外层 pager。

## 范围

本期只处理 embedded TritonKit runtime 的本机 iOS swipe 目标选择，不引入 Web/Wails 控制面、真机能力、远端 agent 或私有 HID 注入。

## BDD 场景

1. Given 横向 swipe 起点落在内层纵向 `UIScrollView` 内，When 同一祖先链上存在可横向滚动的外层 `UIScrollView`，Then runtime 选择外层 pager 并移动其 `contentOffset.x`。
2. Given 纵向 swipe 起点落在嵌套滚动区域内，When 最近祖先可纵向滚动，Then runtime 仍选择最近的纵向 scroll view。
3. Given 祖先链没有匹配手势主轴的 scroll view，When 起点仍位于 scroll view 内，Then runtime 回退最近 scroll view 并在结果中输出可解释 strategy。

## 验收

- `TKInputResult.targetOID` / `targetClassName` 指向实际被滚动的 `UIScrollView`。
- `TKInputResult.strategy` 输出 `axis-matched-scroll-ancestor` 或 `nearest-scroll-ancestor`，便于 agent 判断目标选择路径。
- macOS SwiftPM 门禁通过；UIKit 嵌套 pager 用例作为 iOS/Catalyst 测试资产保留。
