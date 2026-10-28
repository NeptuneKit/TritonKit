# SP-239 · Runner 观察几何可用性

当前状态：已随PR #233合入远端main（`40850dde`），issue #230已completed关闭；现场复验范围见[远端处置](https://github.com/NeptuneKit/TritonKit/issues/230#issuecomment-6460625401)。 本批次未发布；[合并归档报告](../SP-241-open-issues-validation/plans/20261028-merge-closeout.md)为当前事实源。
- Issue：[#230](https://github.com/NeptuneKit/TritonKit/issues/230)
- 影响层：随 CLI 打包的 iOS XCTest Runner、CLI/HTTP schema/使用文档。
- 范围：修复 observation 被 coordinate geometry 校验连带拒绝。保持前台、允许列表、有限正值 App frame 和坐标时效门禁，不猜测方向、不修改设备方向、不自动处理权限弹窗。

## 发现

变更前，`IOSRunnerUI.liveGeometry` 使用 `XCUIApplication.frame` 与 `XCUIDevice.orientation`，随后调用面向坐标请求的 `RunnerGeometry`。inspect 与 screenshot 都无条件依赖它，因此未知 direction 或空 frame 会以调用者参数错误 `coordinate_geometry` 拒绝整个观察。报告现场具体哪个字段失败尚未证明，不能宣称已复现其物理设备根因。

## BDD

1. Given ready 并 activate 到允许的前台 App，且 app frame有效但 device orientation未知，When inspect/screenshot，Then 返回实际层级/PNG，`partial=true` 且 `coordinateActionsAvailable=false`，没有 geometry/observationID，并给出固定错误字段和恢复指引。
2. Given 已有有效坐标观察，随后方向未知，When 再观察，Then 原坐标 ID 失效，任何旧坐标动作拒绝；不按宽高猜测方向。
3. Given App 不在前台或 app frame 非有限正值，Then 分别 typed refusal，不生成可操作观察。
4. Given 几何完整，Then 保留当前点坐标契约与有效期，动作仍需最新观察。

## 消费方审计

- Runner coordinate request 唯一消费 `observationID` + geometry 的执行路径在同一 `IOSRunnerUI`；增加 observedGeometry/ID 非空门禁，liveGeometry仍严格重查。
- CLI/HTTP service 不构造点坐标，透明保留 result 元数据；截图导出只接受真实 PNG并删除 inline图片，新增 lifecycle fixture验证此路径。
- device recording 消费 PNG与观察时间，不从缺失geometry推断坐标。
- 最新inspect的语义selector独立绑定App/时间/元素，方向未知不制造坐标权限。
- `appAlertPresent` 仅是 app alerts 当前查询，`systemAlertDetection=not-probed` 明确不覆盖系统弹窗；不宣称全部中断已探测。

## 验收与证据

- [验证记录](plans/20261028-validation.md)。协议测直接使用 shipped source；实际XCTest fixture已在SP-241 iOS27.0 Simulator运行通过。
- 本轮没有修改设备方向、授权、签名或运行真机；完整CLI通过，真实物理设备acceptance仍未执行。
