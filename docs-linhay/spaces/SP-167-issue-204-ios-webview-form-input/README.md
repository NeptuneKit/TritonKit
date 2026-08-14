# SP-167：iOS WebView 表单输入 provider 契约

## 边界

- 对应 GitHub issue：#204 `iOS WebView form input needs provider-backed focus switching and typed unsupported`
- 影响层：`TritonKitShared` WebView models、`TritonKit` WKWebView provider（snapshot/focus/form-input DOM 脚本与 handler）、CLI `webview focus/type/set-text` 与 `act focus/set-text/type --webview` glue、agent-facing schema/capability matrix 与 focused tests、文档；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-167-issue-204-ios-webview-form-input/`
- 分支：`feat/SP-167-issue-204-ios-webview-form-input`
- 基线：`origin/main@8cc72765`
- 目标：为私有 iOS `WKWebView` 富文本编辑器提供 provider-backed 表单输入契约：snapshot 可发现多个 `contenteditable`/`textarea` 表单目标并给出稳定脱敏身份；`act focus`（或 `webview focus`）可在一页内多个表单字段间一等公民地切换活动元素；`webview type/set-text`（或 `act type/set-text --webview`）按 secure/redacted 输出写入精确文本；响应携带 input/change dispatch 证据与 value 后置条件；页面未 opt-in 时返回 typed unsupported（`webview_form_input_not_opted_in`）并给出文档化 host-HID fallback，而不是只留下 opaque WebView 容器。

## 非目标

- 不运行真实 Simulator/设备、不连接真实 WebView；全部用 provider 脚本字符串、payload 解码、请求/响应模型、CLI glue helper、schema/capability fixture 与静态 HTML fixture 验证。
- 不做任意 JS eval / CDP / 平台敌意注入；DOM 控制（focus/type/set-text）要求页面显式 opt-in（`<html data-triton-form-input="1">` 或 `window.__tritonFormInput === true`），保持在既有 provider bridge 契约内。
- 不新增 HTTP/Web/Wails 控制面；host-HID fallback 只作为 typed-unsupported 的文档化建议，本轮不实现新的 host 输入表面。
- 不改变 `webview-dom-active-element` 的原生 responder 路径；不扩展到真机、远端设备、Android/Harmony DOM provider 或其它平台。

## BDD 验收

### 场景 1：snapshot 发现 title textarea + body contenteditable 两个表单目标

- Given 页面包含 `textarea#title` 与 `div#body[contenteditable=true]`
- When `webview snapshot --include metadata,text,dom,forms`
- Then `forms[]` 同时列出两个目标，均带 `kind`、稳定 `selector`（`#id`/`[name=...]`/`form-N`）、`nodeID`、`focused`、`contentEditable` 与 `valueRedaction=length-only`/`valueLength` 脱敏后置条件；不输出原始值。

### 场景 2：多个页内表单字段间一等公民切换焦点

- Given 页面已 opt-in，`webview snapshot` 返回 `#title` 与 `#body`
- When `webview focus #title` 后 `webview focus #body`（或 `act focus #body --webview`）
- Then 每个 focus 响应 `focused=true` 且 `element.selector` 是目标稳定身份；`webview type` 无 selector 时落到当前 activeElement，证明焦点已切换。

### 场景 3：type/set-text 写入精确文本并返回 dispatch 证据与后置条件

- Given 已聚焦 `#body`
- When `webview type 'Hello' --selector #body` 或 `webview set-text 'Hello' --selector #body --secure`
- Then 响应 `ok=true`、`eventsDispatched=["input","change"]`、`insertedLength`、`valueLength` 与 `valueRedaction=length-only`；`--secure` 时 `redaction.secureText=length-only` 且 sourceCommand 脱敏为 `<redacted:length=N>`。

### 场景 4：页面未 opt-in 时返回 typed unsupported 并给出 host-HID fallback

- Given 页面未暴露 `data-triton-form-input` 或 `window.__tritonFormInput`
- When `webview focus`/`webview type`/`webview set-text` 或 `act ... --webview`
- Then 返回 `ok=false`、`error.code=webview_form_input_not_opted_in`，hint/note 文档化 host-HID fallback（先 tap 字段再 `triton act type <text> --json`）；不触碰 DOM。

### 场景 5：CLI/schema/capability 契约一致

- Given CLI 新增 `webview focus/type/set-text` 与 `act focus/set-text/type --webview`
- When `triton schema --command webview|act --json` 与 `triton capabilities --json`
- Then schema `providedCapabilities` 含 `webview-focus`/`webview-form-input`，capability matrix 同源且 nextAction/evidence 一致；`webview_form_input_not_opted_in` 作为 unsupported 失败族自动补 `triton plan` 恢复。

## 验收命令

```bash
swift test --disable-sandbox --filter TKRuntimeWebViewFormInputTests
swift test --disable-sandbox --filter TKWebViewActionModelsTests
swift test --disable-sandbox --filter TKRuntimeWebViewSnapshotTests
swift test --package-path CLI --disable-sandbox --filter WebViewFormInputRouteTests
swift test --package-path CLI --disable-sandbox --filter WebViewRouteTests
swift test --package-path CLI --disable-sandbox --filter SchemaFactSourceTests
git diff --check
docs-linhay/scripts/check-docs.sh
```

真实 WebView/Simulator 不作为本次验收前置条件；DOM 行为以脚本字符串契约与 fixture 断言验证，禁止设备状态操作。

## 当前状态

- TDD red：新增 `TKRuntimeWebViewFormInputTests` 首次因 `runtimeWebViewFormFocusScript`/`runtimeWebViewFormInputScript`/`decodeRuntimeWebViewFormTargetPayload` 等尚不存在而编译失败；CLI `WebViewFormInputRouteTests` 与 shared `TKWebViewActionModelsTests` 同样编译失败（makeWebViewFocusRequest 等缺失）。
- TDD green：实现后根包 webview/shared 三 suite 23/23 通过；CLI `WebViewFormInputRouteTests` 6/6、`WebViewRouteTests` 18/18、`SchemaFactSourceTests` 与关联 schema/capability suite 通过（仅保留 5 个既有 Xcode archive/export schema matrix/taxonomy 基线失败，已在 stash 基线验证为 pre-existing）。
- 契约要点：opt-in marker 统一为 `<html data-triton-form-input="1">` 或 `window.__tritonFormInput === true`；稳定身份 `#id` / `[name=...]` / `form-N`（document order，snapshot 与 focus/input 脚本同序）；`form-input` 响应携带 `eventsDispatched`、`insertedLength`、`valueLength`、`valueRedaction` 与 secure redaction。
- CLI glue：`webview focus <selector>`、`webview type <text> [--selector] [--secure]`、`webview set-text <text> [--selector] [--secure]`；`act focus <selector> --webview`、`act set-text <selector> <text> --webview [--secure]`、`act type <text> --webview [--selector <s>] [--secure]`。
- 风险：未连接真实 WKWebView/Simulator；DOM 脚本与 payload 契约为静态验证，真实富文本编辑器的 execCommand/InputEvent 行为需设备 smoke 复验。远端 issue 尚未评论/关闭。
- 共享文件冲突：`docs-linhay/spaces/INDEX.md`/`README.md` 与 SP-164/165/166（以及 SP-168/169）并行登记，`check-docs.sh` 的 SP 编号连续性需在合并期统一解决；`Sources/TritonKitCLI/CLIActionCommands.swift` 与其它 issue 并行修改，需在合并时留意。
