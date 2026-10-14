# WebView 受控表单交付

状态：实现、macOS合同与真实应用宿主验收完成；主控Hosted6的56项 / 8 suites全部通过，含真实WKWebView表单5项及Foreground 5项。

影响层：iOS embedded runtime / shared core 的现有 WebView form-input provider。CLI 与 HTTP 继续消费既有响应；不增加公开任意 JavaScript 执行入口。

## BDD 与实现

- Given opted-in 页面中的 input / textarea 被框架安装了实例 value setter，When type / set-text，Then 使用所属 document realm 的原生 prototype setter，派发 input / change，完成真实 blur 后再核验值。
- Given date / number / select 不支持 selectionStart / setSelectionRange，When 接受有效值，Then caret API 的异常不掩盖成功写入。select 的 type 使用给定 option value；普通文本 type 保留选区替换语义。
- Given 原生输入规则拒绝值，或受控表单在 input/change/blur 后同步或排队回滚，When readback，Then 不报告成功。返回既有 `webview_element_not_interactable`、长度及事件证据，不返回文本内容。
- Given disabled / readonly / 非文本 input，When 输入，Then 在值写入前拒绝。
- Given contenteditable，Then 保留原有 execCommand / textContent 行为。

初次 JS 返回值不包含字段内容。生产 provider 在 50 ms 有界等待后消费一次性、不可枚举的页面内 readback 闭包，验证同一 DOM 节点仍连接且精确值保持。闭包立即消费删除，2 秒过期清理作为取消/中断兜底；导航或缺失闭包返回既有 navigation-changed 错误。此结果证明观测时值保持，后续业务持久化仍需既有业务断言。

原 1870 行 provider 拆出 `TKRuntimeWebViewFormScripts.swift`，provider 与脚本文件均低于 1500 行。内部 payload 增加可选 `valueMatched`；公开 shared model / schema 不变。

## 验证

TDD 红测：新增 setter/readback/blur/异常脱敏断言，在原实现上确认 8 个失败点。首次移动源文件与正在进行的编译重叠，导致一次符号缺失编译失败；重新规划构建后取得上述真实行为红测，不将该编译失败记为功能红测。

macOS：

```sh
swift test --scratch-path .build/sp196-webview --no-parallel --filter 'TKRuntimeWebView(FormInput|ControlledInput|Snapshot)Tests'
```

已通过 27 项 / 3 suites。9 项 JavaScriptCore 测试执行实际生成脚本与可控 DOM 合同夹具，验证 setter tracker、同步/blur/二阶段回滚、异常脱敏、date/number/select caret 边界、readonly、选区输入及能力删除。该夹具不替代真实 WebKit 或 React 应用集成验收。

真实 UIKit / WKWebView 套件：`TKRuntimeWebViewControlledInputUIKitTests`，5 项，包括原生 tracker、date/number/select/textarea、异步密码字段回滚、原生拒绝值、contenteditable。调用生产 `evaluateRuntimeWebViewFormInput`，不是复制生产实现。macOS 不运行这一 suite。

主控需先用 Triton schema/schemes 确认当前参数与 scheme，随后在 owned iOS Simulator destination 串行运行：

```sh
triton xcode test --package <worktree> --scheme TritonKit-Package --destination 'platform=iOS Simulator,id=<owned-id>' --only-testing TritonKitTests/TKRuntimeWebViewControlledInputUIKitTests --result-bundle <fresh.xcresult> --json
```

主控已完成真实destination包测试及最终应用宿主复验，结果见下文；未验证完整 React 页面、客户页面或业务提交持久性。没有操作设备/服务，没有提交或推送。


## 前景写入保护

在主控明确授权的 foreground 续做中，6处既有写入口接入 `runtimeForegroundTargetFailure(for:)`：focused text insertion、focused delete backwards、tap/click、focus、formInput、allowlisted bridge。bridge在安装脚本bridge前校验。显式WebViewID不能穿透模态底层或后台scene进行修改；拒绝采用既有 `webview_element_not_interactable` 和静态错误，focused动作采用既有input failure，不暴露页面/字段内容。枚举、current/metadata、snapshot/wait/events等只读入口保持原观察范围，没有新增JS公开入口。

`TKUIKitWindowTests.TKRuntimeForegroundTargetTests` 新增真实WKWebView modal场景：先强制确认 provider candidate可枚举，再实际调用tap/focus/formInput/bridge四条producer并验证拒绝及DOM无副作用；真实dismiss完成后formInput恢复且读回值确认。它与5项生产表单evaluator测试用途不同；两者均已在最终Hosted6真实iOS执行并通过。

最近联合macOS focused回归通过33项 / 5 suites（窗口策略、input目标安全、WebViewFormInput/ControlledInput/Snapshot）。随后授权的 `allRuntimeWindows` 无scene回退与UIKit断言收紧通过diff检查，随后已由主控Hosted6完成真实UIKit编译/执行；本agent没有再启动全量测试。


## 主控真实 iOS 第一轮反馈

主控在专用 `Triton-SP196-Validation` iOS Simulator 27.0（arm64）运行实际包测试：`TKRuntimeWebViewControlledInputUIKitTests` 5项全部通过，覆盖生产evaluator的native setter、caret边界、queued rollback、native拒绝值及contenteditable。证据：`.triton/sp196-validation/ios-runtime-1.jsonl` 与 `ios-runtime-1.xcresult`。这是实际WKWebView验证，不等同完整React客户应用或业务持久性验证。

同轮整体55项中窗口相关43项在夹具初始化处被严格前景策略拒绝（`keyWindows().first`为nil），没有进入modal与四条producer场景。原日志缺少activationState诊断，因此不把hostless进程失败直接归因为某个scene状态。已授权收紧 `TKUIKitWindowTestSupport.swift` 仅选择真实foregroundActive场景，并在失败中输出真实app/scene/window状态；不伪造activation、不放宽生产。主控随后创建独立RuntimeValidation应用宿主以串行复验窗口suite；最终Hosted6已真实通过，详见下文。


Foreground续做的Hosted实测发现真实keyboard产生的UITextEffectsWindow会抢占动作root。现有helper已获主控授权，最窄识别实测的UIKit定义window/root精确组合，未知高层窗口维持保守阻断；不按substring过滤、不放宽后台scene。该修复也服务WebView focused/form mutation的连续业务操作，具体红绿与OS边界见同目录foreground-delivery.md；最终Hosted6已通过，包括actual keyboard窗口出现后的连续业务输入。


## 最终真实验收：Hosted6

主控在worktree同级独立 `.sp196-validation-host/SP196RuntimeHost.xcodeproj` / `RuntimeValidation` scheme中串行运行actual test sources，避免嵌套local package的Xcode graph反馈。专用iPhone17 / iOS27.0 Simulator（arm64）结果：xcodebuild退出0，fresh xcresult解析Passed，56 tests / 8 suites、0失败、0跳过，Swift Testing 12.332秒。证据位于worktree同级 `.sp196-validation-host/ios-hosted-6.jsonl` 与 `ios-hosted-6.xcresult`。

`TKRuntimeWebViewControlledInputUIKitTests` 5项全部通过；Foreground 5项中的真实WebView modal fixture（1.849秒）先证明candidate可枚举，再验证tap/focus/formInput/allowlisted bridge的实际producer拒绝、read-only list保留和DOM无副作用，真实dismiss后formInput及DOM读回恢复。keyboard高层window出现后的连续focus→clear也通过。macOS生成JS合同夹具和真实WKWebView证据仍分别标记，不声称完整React客户页或业务提交持久性已验收。

Hosted1/3编译失败、Hosted4取得诊断后取消、Hosted5调度超时均不计green；最终以Hosted6完整结果验收。前景输入overlay仅豁免实测的UIKit定义精确window/root组合，其OS确认限定本机Xcode27/iOS27，未知组合继续保守阻断。主控负责全局报告/README/memory，本agent最终仅更新两份delivery plans，不再测试、设备或源码操作。
