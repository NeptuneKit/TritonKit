# #238 本地验证记录

## Requested

区分 ArkWeb WebSocket 传输失败与页面 JavaScript 异常，检查 discovery/forward/session 生命周期，修复可复现的传输问题。

## Observed

基线 `30185dc2` 的 `URLSessionWebSocketTask.sendMessage` 使用 `.data(data)`，因此发 binary frame。真实 loopback Network.framework WebSocket 只接受 text CDP；旧实现触发 `NSPOSIXErrorDomain Code=57`，`NSErrorFailingURL` 以 http scheme 表示，wire捕获 opcode=binary。该 http URL 是 Foundation 错误呈现，不能据此推断生产构造了错误 ws URL。

[Chromium官方 websocket encoder](https://github.com/chromium/chromium/blob/main/net/server/web_socket_encoder.cc) 于2026-10-30读取，binary opcode走 FRAME_ERROR；据此选择text-only负例。没有验证本机 ArkWeb 的确切Chromium分支，因此这属于相同故障机制的复现，不认定原报告根因已完全确认。

## Evidence

- `.build/issue238-evidence/wire-red.log`：原生产 session 的独立wire探针（仅用协议/error类型stub满足独立编译），捕获binary并报POSIX57。
- 初次 `.build/issue238-evidence/red.log`：失效。冷构建开始后追加了测试文件，Swift报modified during build；没有将该次编译失败当产品红灯。冻结后重跑，沿用既有“代码冻结后重跑受影响检查”规则，不新增重复治理规则。
- `swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter HarmonyArkWeb`：旧实现 `red-frozen.log` 的45项测试出现11个预期失败；真实socket POSIX57、transport误分类、protocol误分类和schema缺码均被捕获。
- 应用最小实现后同命令 `green.log`：45项/3suite通过，真实text-frame响应及peer断连typed transport均通过。
- `swift test --package-path CLI --build-system native --jobs 2 --no-parallel` → `cli-full.log`：1582 Swift Testing（163 suites）+94 XCTest，exit0；运行测试约66秒。
- `swift test --build-system native --jobs 2 --no-parallel` → `root-full.log`：402项/62suite，exit0，覆盖transport/protocol及既有javascript/bridge-timeout错误码DTO编码解码。
- `CLI/.build/debug/triton schema --command webview --json` → `webview-schema.json`：单一合法JSON，新增failureCodes/shape/semantics已暴露。
- `verify.sh --ci-docs` 与 `check-docs.sh`：本分支均失败于SP248前缺244–247连续编号，不是删除历史资料；主目录其它任务尚未提交，这些space未包含在本基线。主控使用真实联合文档快照验收。
- `git diff --check`：通过。
- 工具链：Apple Swift6.4，arm64-apple-macosx27.0.0；native/jobs2约束实际编译并发。

## Fixes made

只将CDP JSON frame改为text，未替换网络库/代理/握手策略。新增transport/protocol错误族并同步共享Codable模型、CLI schema与恢复分类；invalid JSON/CDP error/missing response形状以及bridge envelope解码失败归protocol，页面exceptionDetails保持javascript。原forward ownership/清理顺序未改，回归确认失败保留sourceCommands并close session和清理自身forward。传输错误消息不拼接原NSError私有URL，明确方法送达未知、不自动重放。

权威经验写回`docs-linhay/dev/ai-cli-readable-control.md`与`docs-linhay/memory/EXPERIENCE.md`。

## Remaining risk

没有启动/占用Harmony emulator，没有调用HDC，没有业务App或真实ArkWeb验收。系统代理、握手与原forward现场没有证明为原因，不增加猜测性绕过。未提交/推送/PR/合并/关闭issue/发布。

SDK分发边界：仅共享enum增加两个字符串case，没有新平台import/依赖；root/CLI macOS编译测试已执行，iOS/CocoaPods lint、Release制品、总门禁`verify.sh --local`和真实ArkWeb未执行，本报告不将Debug/fixture结果升级为分发或设备验收。
