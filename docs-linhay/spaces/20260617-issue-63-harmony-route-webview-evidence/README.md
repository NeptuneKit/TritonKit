# 20260617 Issue 63 Harmony Route WebView Evidence

## 背景

GitHub Issue #63 来自 Harmony App 路由和 WebView init URL 重写问题。当前 host-side Harmony 能发现 target、launch app、dump layout，但没有一个结构化快照说明 native route、WebView initURL/currentURL、是否 initial load、URL 是否被 route rewrite/intercept，以及近期 route/WebView 历史。Agent 只能从空白页面、layout 和日志推断 route loop，诊断成本高。

## 范围

### 目标

1. 为 Harmony WebView host-layout 结果增加机器可读 warning，明确当前只能识别可见 WebView 候选，不能确认 route stack、initURL/currentURL 或 rewrite decision。
2. 为 route-loop 场景暴露稳定 warning code 和 nextAction，提示采集 embedded provider / evidence，而不是让 agent 继续盲查 HDC。
3. 为 future evidence bundle 保留 `harmony.webview-snapshot`、`harmony.route-warning`、`harmony.hdc-recovery-plan` artifact kind 的 Codable 合约。
4. 保持兼容旧 JSON：没有 `warnings` 字段的 WebView list/current/snapshot response 仍可 decode。

### 非目标

1. 本轮不接真实 DevEco / HDC route extractor。
2. 本轮不新增 Web/Wails UI。
3. 本轮不执行真实 proxy 或设备 mutation。
4. 本轮不关闭 issue；合并、推送和关闭由主控 agent 统一处理。

## BDD 验收场景

### 场景一：Harmony WebView list 暴露 route/WebView 诊断 warning

- Given Harmony host layout 只能提供可见 WebView 候选
- When agent 读取 `webview list --platform harmony --json`
- Then JSON response 包含 `warnings[]`
- And warning 使用稳定 code：`harmony_route_webview_snapshot_partial`
- And nextAction 指向可执行的 Triton 命令

### 场景二：route-loop 诊断有明确 provider/evidence 下一步

- Given agent 怀疑 WebView initURL 被 native route interceptor 重写
- When 当前没有 embedded route/WebView provider
- Then JSON response 包含 `harmony_route_loop_detector_provider_required`
- And nextAction 指向 evidence 采集入口

### 场景三：旧 WebView JSON 仍可 decode

- Given 旧版本 WebView list/current/snapshot response 没有 `warnings`
- When 新版本模型 decode
- Then `warnings` 默认为空数组
- And 不破坏现有 provider / host-layout 调用方

## 验证计划

- `swift test --package-path CLI --scratch-path .build/cli-issue63 --filter WebViewRouteTests`
- `swift test --filter TKEvidenceModelsTests`
- `git diff --check`
- `docs-linhay/scripts/check-docs.sh`

## 剩余风险

本轮是 contract slice，只让 agent 先拿到稳定 warning 和 evidence artifact kind；真实 Harmony route stack、WebView initURL/currentURL、intercept decision 和 repeat-window loop detector 还需要后续接 embedded provider 或 host-side extractor。
