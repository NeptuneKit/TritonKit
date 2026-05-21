# 20260521 iOS Embedded SDK Expansion Implementation Plan

## 推荐方案

采用“公开 UIKit API + 显式 opt-in provider”的分层方案。

原因：P0 能快速扩大 agent 可观察/可控制范围，并保持 DEBUG-only 和 App 内边界；P2 的网络、日志、业务状态、UserDefaults 等能力通过业务显式注册 provider 才启用，避免 SDK 默认变成高风险采集器。

## 备选方案

### 方案 A：只扩展公开 API 采集与语义命令

- 工作量：中。
- 风险：低。
- 复用：现有 `ax/hierarchy/attrs/input/find/wait/assert/evidence`。
- 缺点：无法解决网络、登录态、feature flag 等业务语义问题。

### 方案 B：公开 API + opt-in provider

- 工作量：中高。
- 风险：中。
- 复用：P0 复用现有 runtime，P2 provider 只新增只读注册点和 DTO。
- 优点：既能推进通用能力，又给真实项目留出业务语义扩展口。
- 建议采用。

### 方案 C：默认自动 hook 网络、日志和存储

- 工作量：高。
- 风险：高。
- 复用：少。
- 不建议：容易破坏业务 App 行为，也难以保证 Release/隐私边界。

## 攻击面检查

1. 依赖失败：如果 App 未接入 provider，P0 仍能通过 UIKit 公开 API 工作；provider 缺失只在 capability 中显示 unsupported。
2. 规模放大：复杂页面树可能超过 payload budget；snapshot 必须支持 include、limits、truncation 和 skipped reason。
3. 回滚成本：每个能力独立挂到 manifest/capabilities，错误实现可以按 capability 关闭，不影响基础 `ax/hierarchy/input`。
4. 前提坍塌：如果真实项目大量 SwiftUI 私有树无法解释，P0 仍保留 route/controller/AX 线索，业务语义转向 opt-in provider。

## 实施步骤

1. 契约红灯：在 `TritonKitShared` 新增 iOS runtime manifest、snapshot、state、attrs v2、ledger、semantic action DTO 的 Swift Testing 测试，先确认失败。
2. CLI schema 红灯：为 `runtime manifest`、`snapshot`、`state`、`ledger` 和语义命令补 schema 测试，先确认命令未暴露。
3. Runtime P0 采集：实现 manifest、app/scene/route/responder/control attrs、ledger ring buffer。
4. Snapshot 聚合：组合现有 hierarchy、ax、geometry、screenshot metadata 和新增 state，加入 payload limits、freshness、redaction。
5. 语义动作：在底层 input 之上实现 focus/setText/submit/selectSegment/setSwitch/setSlider/stepper/scroll/scrollToVisible/waitIdle，并统一返回 strategy、target、elapsedMs。
6. Evidence 集成：capture/evidence 增加 snapshot/state/ledger artifact，unsupported 或超限进入 manifest.skipped。
7. Harness 验收：扩展 ComplexHarness，加入导航/表单/列表/弹窗/重复文本场景，更新可复跑脚本。
8. 文档同步：更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、public skills 与 memory。

## 最小验收切片

第一期不要一次性实现全部命令。建议先完成：

1. `runtime manifest`
2. `state app|scene|route|responder`
3. `attrs --groups accessibility,responder,control,text,scroll`
4. `snapshot --include app,scene,route,ax,geometry`
5. `focus`
6. `set-text`
7. `select-segment`
8. `set-switch`
9. `ledger --limit`

这组能力能显著改善 agent 在真实表单页中的“看、解释、填、验证、复盘”闭环，同时不触碰高风险 P2。

## 验证命令

文档规划阶段：

```bash
docs-linhay/scripts/check-docs.sh
```

实现阶段本地门禁：

```bash
swift test
docs-linhay/scripts/verify-complex-harness.sh
docs-linhay/scripts/verify.sh --local
```

若只实现 shared DTO 或 CLI schema，至少运行：

```bash
swift test --filter TritonKitSharedTests
```
