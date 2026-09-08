# SP-174 · UILabel 文本属性取证（#211）

- 状态：实现与 macOS 回归完成，独立 worktree 待主控集成及 UIKit 验证。
- Issue：[#211](https://github.com/NeptuneKit/TritonKit/issues/211)
- 影响：embedded UIKit 属性采集与既有 `debug attrs` 读取；无新增控制面。
- 分支：`feat/SP-174-issue-211-label-text-attributes`。

## 边界与 BDD

1. Given hierarchy/debug nodes 提供 UILabel 子类的 UIView oid，When 查询 attrs，Then 返回 class/layout/ui_label；CALayer oid 保持兼容。
2. Given 普通文本或 attributedText，When 查询 attrs，Then 得到 label 默认字体/前景色，以及每个 attributed run 的 UTF-16 location/length、有效字体/颜色。
3. Given 未设置某 run 字体/颜色，Then 从 UILabel 属性回退；动态颜色按 label.traitCollection 解析；不可转换颜色明确报告 unsupported。
4. Given 自定义 attributed keys、链接或附件，Then 新增 run 不输出对象描述、文本内容或未知键值；既有 text 属性保持兼容，正文限制为 4096 UTF-16 单位并标记截断（不截断 surrogate pair）。
5. Given 超长文本/过多 runs，Then 采集最多 16384 UTF-16 单位/256 runs，报告覆盖长度与截断状态；空 attributedText 不产生 run。

## 验收

- Foundation run collector 测试：Unicode 范围、空串、双重边界、白名单回调与 JSON 编码。
- UIKit 测试：UIView/CALayer 请求路径、子类、font/color 回退、动态 trait、混色与隐私。
- 根 SwiftPM 全量测试；UIKit 专属测试需在 iOS Simulator 执行，macOS 通过不作为 UIKit 行为证据。
- [实现与验证计划](plans/20260908-implementation.md)。

## 2026-09-08 主控集成验收

2026-09-08 用户已授权提交、合入 main、推送和关闭 issue；各实现分支已串行合入本地 main，正在等待 push/CI 后远端收口。最终 CLI 全量 977/977、根包 269/269、专用 iOS 26.5 Simulator UIKit 46/46 通过；本地总门禁通过。UIKit 覆盖包含 collection selection、longPress fail-closed、富文本 run 和实际 trait；Harmony 为离线 CDP/HDC fixture，不声称真实 DevEco smoke。详细证据与失败→修补过程见 ../SP-176-open-issues-integration/plans/20260908-issue-audit.md。
