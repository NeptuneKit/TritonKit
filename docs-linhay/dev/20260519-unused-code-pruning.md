# Unused code pruning

## 背景

删除旧 Objective-C core 后，再次检查当前 Swift runtime 中是否仍保留未参与构建行为、CLI 契约或公开接入指南的残留代码。

## 验收场景

### 场景 1：删除未引用模型与 enum

- Given `TKAutoLayoutConstraint`、`TKConstraintItemType`、`TKAttributesSectionStyle` 没有被 runtime、CLI、测试或文档引用
- When 删除这些类型
- Then `swift test`、release CLI build 和 CocoaPods lint 仍通过

### 场景 2：删除未使用 helper

- Given `tk_topmostHostView`、`tk_memoryAddress`、`captureAndUpload(view:)` 与 `captureScreenshot(view:)` 没有调用方
- When 删除这些 helper
- Then hierarchy、screenshot 与 data upload 的正式路径仍由现有 runtime handler 覆盖

## 保留边界

以下内容本轮不删除：

1. `TKDisplayItem` 中的 Lookin 风格 wire 字段，因为 hierarchy JSON 和 CLI 渲染仍依赖该结构作为稳定外部契约。
2. `TKDisplayItemDetail` 与 `hierarchyDetails` 请求类型，因为 raw request / shared transport 仍暴露对应请求类型，删除会收缩协议面。
3. `TKEventHandler` 与 `TKStringTwoTuple`，因为它们是 `TKDisplayItem.eventHandlers` 的序列化字段类型，属于 hierarchy wire shape。
