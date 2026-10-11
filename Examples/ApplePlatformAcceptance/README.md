# Apple 专门平台隔离验收样例

本目录只包含专用验收 App 和 XCTest UI runner，无业务工程依赖。XcodeGen 配置与生成后的 Xcode project 一并保留；修改配置后运行 `xcodegen generate --spec Examples/ApplePlatformAcceptance/project.yml`。

- `TVAcceptance`：3×3 原生焦点网格，初始焦点为中心 `cell-4`。方向键断言对应相邻按钮获得焦点；选择键断言详情页及来源 cell；返回键先在独立样例中建立详情页，再断言 menu 返回网格并恢复焦点。
- `WatchAcceptance`：SwiftUI Crown 值，旋转前读取数值、旋转后等待真实值变化。Action 检测硬件支持，但当前没有配置可隔离且可观测的系统后置条件，因此明确失败且不发送 Action。

## 构建与调用

主控串行执行构建，不与其他 SwiftPM/Xcode 构建争用 scratch：

```sh
xcodebuild -project Examples/ApplePlatformAcceptance/ApplePlatformAcceptance.xcodeproj \
  -scheme TVAcceptance -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath /absolute/private/acceptance-tv build-for-testing
xcodebuild -project Examples/ApplePlatformAcceptance/ApplePlatformAcceptance.xcodeproj \
  -scheme WatchAcceptance -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath /absolute/private/acceptance-watch build-for-testing
```

测试标识分别为 `TVAcceptanceUITests/TVControlTests/testControl` 与 `WatchAcceptanceUITests/WatchControlTests/testControl`。测试请求经 runner 环境变量 `TRITON_PLATFORM_REQUEST` 传入，JSON 包含 `version:1`、`platform`、`action`、`device`、`nonce`；Crown 还要求有限非零 `crownDelta`。runner 用实际进程的 CoreSimulator `SIMULATOR_UDID` 校验请求，未匹配时不得发送事件。

`triton-platform-result` JSON attachment 包含同一版本及请求关联字段、实际 runtime device、`ok`、`eventDelivered`、`postconditionVerified`。只在后置断言满足后写成功；失败时不生成成功附件，由 XCTest failure 与缺少成功附件表达 unknown；不能把未确认后置结果误报为未送达，也不能把 API 返回、build 成功或 SDK 符号存在当作实际动作证据。附件包含 Simulator 标识，保存为私有证据，公开总结需脱敏。

必须经 Triton CLI 的目标绑定、明确授权和审计门禁，在为本验收新建且记账的专用 Simulator 上执行。不得复用业务实例。SDK-only 构建不代表运行验收；无匹配 runtime 时仍是未验收。
