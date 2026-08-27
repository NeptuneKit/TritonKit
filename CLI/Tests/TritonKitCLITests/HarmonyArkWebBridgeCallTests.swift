import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

/// SP-173 / GitHub #207: Harmony host-side ArkWeb bridge-call.
/// Offline fixtures cover discovery → invoke → async callback → typed errors
/// with injected hdc results, page lists, and CDP sessions; no real HDC runs.
@Suite("SP-173 Harmony ArkWeb bridge-call")
struct HarmonyArkWebBridgeCallTests {
    private let target = TKHarmonyTarget(target: "127.0.0.1:10100", state: "Connected", transport: "TCP")

    // MARK: - Fixtures

    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var commands: [String] = []
        private var pageListURLs: [String] = []
        private var sessionURLs: [String] = []
        private var expressions: [String] = []
        private var closedSessions = 0

        func append(command argv: [String]) {
            lock.withLock { commands.append(argv.joined(separator: " ")) }
        }

        func append(pageList url: URL) {
            lock.withLock { pageListURLs.append(url.absoluteString) }
        }

        func append(session url: URL) {
            lock.withLock { sessionURLs.append(url.absoluteString) }
        }

        func append(expression: String) {
            lock.withLock { expressions.append(expression) }
        }

        func recordClose() {
            lock.withLock { closedSessions += 1 }
        }

        var commandLog: [String] { lock.withLock { commands } }
        var pageListLog: [String] { lock.withLock { pageListURLs } }
        var sessionLog: [String] { lock.withLock { sessionURLs } }
        var expressionLog: [String] { lock.withLock { expressions } }
        var closeCount: Int { lock.withLock { closedSessions } }

        var fportRemoveCount: Int {
            commandLog.filter { $0.contains("fport rm") }.count
        }
    }

    final class FakeCDPSession: HarmonyArkWebCDPSession {
        private let recorder: Recorder
        private let invokeAck: String
        private let pollResponses: [String]
        private var pollIndex = 0

        init(recorder: Recorder, invokeAck: String, pollResponses: [String]) {
            self.recorder = recorder
            self.invokeAck = invokeAck
            self.pollResponses = pollResponses
        }

        func evaluate(expression: String, timeoutSeconds: Double) async throws -> String? {
            recorder.append(expression: expression)
            if expression.contains("Promise.resolve(bridge.methods[method](args))") {
                return invokeAck
            }
            guard pollIndex < pollResponses.count else {
                return ""
            }
            let response = pollResponses[pollIndex]
            pollIndex += 1
            return response
        }

        func close() async {
            recorder.recordClose()
        }
    }

    private func makeEnvironment(
        recorder: Recorder,
        socketOutput: String,
        fportSucceeds: Bool = true,
        pageListData: Data?,
        sessionFactory: @escaping (URL) -> HarmonyArkWebCDPSession,
        pollIntervalSeconds: Double = 0.001
    ) -> HarmonyArkWebCDPEnvironment {
        HarmonyArkWebCDPEnvironment(
            runner: { command in
                recorder.append(command: command.arguments)
                if command.arguments.contains("cat") {
                    return hostProcessResult(stdout: socketOutput, sourceCommand: hostSourceCommand(command))
                }
                if command.arguments.contains("fport") && command.arguments.contains("rm") {
                    return hostProcessResult(stdout: "Remove forward success", sourceCommand: hostSourceCommand(command))
                }
                if command.arguments.contains("fport") {
                    guard fportSucceeds else {
                        throw HostCommandRunError.nonZeroExit(
                            command: command,
                            result: hostProcessResult(stdout: "", stderr: "fport failed", sourceCommand: hostSourceCommand(command))
                        )
                    }
                    return hostProcessResult(stdout: "Forward port success", sourceCommand: hostSourceCommand(command))
                }
                throw HostCommandRunError.nonZeroExit(
                    command: command,
                    result: hostProcessResult(stdout: "", stderr: "unexpected hdc command", sourceCommand: hostSourceCommand(command))
                )
            },
            pageListLoader: { url in
                recorder.append(pageList: url)
                if let pageListData {
                    return pageListData
                }
                throw RuntimeError("connection refused")
            },
            sessionFactory: sessionFactory,
            localPortProvider: { 41234 },
            pollIntervalSeconds: pollIntervalSeconds,
            now: { Date() }
        )
    }

    private func hostProcessResult(stdout: String, stderr: String = "", sourceCommand: String) -> HostProcessResult {
        HostProcessResult(
            stdoutData: Data(stdout.utf8),
            stderrData: Data(stderr.utf8),
            exitCode: stderr.isEmpty ? 0 : 1,
            sourceCommand: sourceCommand,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: stdout.utf8.count,
            stderrBytes: stderr.utf8.count
        )
    }

    private let devtoolsSocketOutput = """
    Num       RefCount Protocol Flags    Type St Inode Path
    0000000000000001  0000000000000002  0        00010000 0001  12930 webview_devtools_remote_12844
    """

    private func pageListJSON(pages: [String]) -> Data {
        Data("[\(pages.joined(separator: ","))]".utf8)
    }

    private let singlePage = #"{"description":"","id":"page-1","title":"Checkout","type":"page","url":"https://example.invalid/checkout","attached":false}"#
    private let secondPage = #"{"description":"","id":"page-2","title":"Help","type":"page","url":"https://example.invalid/help","attached":false}"#
    private let serviceWorkerPage = #"{"description":"","id":"sw-1","title":"SW","type":"service_worker","url":"https://example.invalid/sw.js","attached":false}"#

    private func callBridge(
        _ environment: HarmonyArkWebCDPEnvironment,
        webviewID: String? = nil,
        method: String = "getRouteState",
        params: [String: TKJSONValue] = ["k": .string("v")],
        timeoutMs: Int? = 2_000,
        devtoolsPort: Int = 9222,
        cdpLocalPort: Int? = nil
    ) async throws -> WebViewBridgeCallSummary {
        try await harmonyArkWebBridgeCall(
            selected: target,
            hdc: "hdc",
            webviewID: webviewID,
            method: method,
            params: params,
            timeoutMs: timeoutMs,
            devtoolsPort: devtoolsPort,
            cdpLocalPort: cdpLocalPort,
            environment: environment
        )
    }

    private func failure(_ error: Error?) -> HarmonyArkWebBridgeCallFailure? {
        error as? HarmonyArkWebBridgeCallFailure
    }

    // MARK: - Discovery parsing

    @Test("proc net unix parsing keeps unique sorted devtools socket names")
    func procNetUnixParsing() {
        let output = """
        Num RefCount Protocol Flags Type St Inode Path
        00000001 00000002 0 00010000 0001 12930 webview_devtools_remote_12844
        00000001 00000002 0 00010000 0001 13000 webview_devtools_remote_12990
        00000001 00000002 0 00010000 0001 13001 webview_devtools_remote_12844
        garbage line
        """
        #expect(harmonyArkWebSocketNames(fromProcNetUnix: output) == [
            "webview_devtools_remote_12844",
            "webview_devtools_remote_12990",
        ])
        #expect(harmonyArkWebSocketNames(fromProcNetUnix: "no sockets here").isEmpty)
    }

    @Test("page list decoding keeps page targets and drops service workers")
    func pageListDecoding() throws {
        let pages = try decodeHarmonyArkWebPageList(pageListJSON(pages: [singlePage, serviceWorkerPage]))
        #expect(pages.map(\.id) == ["page-1"])
        #expect(pages.first?.url == "https://example.invalid/checkout")
    }

    // MARK: - Page selection

    @Test("selection picks the only visible page without a webview id")
    func selectionPicksOnlyPage() throws {
        let page = try harmonyArkWebSelectPage([try decodePage(singlePage)], webviewID: nil)
        #expect(page.id == "page-1")
    }

    @Test("selection without a webview id is ambiguous across pages")
    func selectionWithoutIDIsAmbiguous() {
        let pages = [try! decodePage(singlePage), try! decodePage(secondPage)]
        do {
            _ = try harmonyArkWebSelectPage(pages, webviewID: nil)
            Issue.record("Expected ambiguous selection")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code == .ambiguousWebView)
            #expect(error.candidates().count == 2)
            #expect(error.candidates().allSatisfy { $0.webViewID.hasPrefix("arkweb-cdp:") })
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("selection matches explicit arkweb-cdp and raw page ids")
    func selectionMatchesExplicitIDs() throws {
        let pages = [try decodePage(singlePage), try decodePage(secondPage)]
        #expect(try harmonyArkWebSelectPage(pages, webviewID: "arkweb-cdp:page-2").id == "page-2")
        #expect(try harmonyArkWebSelectPage(pages, webviewID: "page-2").id == "page-2")
    }

    @Test("selection falls back to the only page for host-layout webview ids")
    func selectionFallsBackToOnlyPageForHostLayoutID() throws {
        let page = try harmonyArkWebSelectPage([try decodePage(singlePage)], webviewID: "harmony:host:12844")
        #expect(page.id == "page-1")
    }

    @Test("selection rejects unmatched webview ids across multiple pages")
    func selectionRejectsUnmatchedID() {
        let pages = [try! decodePage(singlePage), try! decodePage(secondPage)]
        do {
            _ = try harmonyArkWebSelectPage(pages, webviewID: "harmony:host:12844")
            Issue.record("Expected webview_id_not_found")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code == .webViewIDNotFound)
            #expect(error.candidates().count == 2)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("selection without pages reports webview_not_found")
    func selectionWithoutPagesReportsNotFound() {
        do {
            _ = try harmonyArkWebSelectPage([], webviewID: nil)
            Issue.record("Expected webview_not_found")
        } catch let error as HarmonyArkWebBridgeCallError {
            #expect(error.code == .webviewNotFound)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func decodePage(_ json: String) throws -> HarmonyArkWebPage {
        let pages = try decodeHarmonyArkWebPageList(pageListJSON(pages: [json]))
        guard let page = pages.first else {
            throw RuntimeError("fixture page missing")
        }
        return page
    }

    // MARK: - Bridge scripts

    @Test("invoke script embeds method and params literals with allowlist guard")
    func invokeScriptShape() throws {
        let script = try harmonyArkWebBridgeInvokeScript(
            callID: "call-1",
            method: "payOrder",
            arguments: ["amount": .int(42), "label": .string("订单")]
        )
        #expect(script.contains("var callID = \"call-1\";"))
        #expect(script.contains("var method = \"payOrder\";"))
        #expect(script.contains("\"amount\""))
        #expect(script.contains("42"))
        #expect(script.contains("订单"))
        #expect(script.contains("typeof bridge.methods[method] !== \"function\""))
        #expect(script.contains("webview_method_not_allowed"))
        #expect(script.contains("Promise.resolve(bridge.methods[method](args))"))
        #expect(script.contains("__tritonHostBridgeCalls"))
    }

    @Test("poll script reads and clears the stored callback envelope")
    func pollScriptShape() throws {
        let script = try harmonyArkWebBridgePollScript(callID: "call-9")
        #expect(script.contains("var value = store[\"call-9\"];"))
        #expect(script.contains("delete store[\"call-9\"]"))
        #expect(script.contains("return \"\";"))
    }

    @Test("envelope errors map to the typed bridge error family")
    func envelopeErrorMapping() throws {
        let methodNotAllowed = try decodeHarmonyArkWebBridgeEnvelope(
            #"{"ok":false,"error":{"code":"webview_method_not_allowed","message":"Method is not allowlisted: nope"}}"#
        )
        #expect(harmonyArkWebBridgeCallError(fromEnvelopeError: methodNotAllowed!.error!).code == .webViewMethodNotAllowed)

        let javascriptError = try decodeHarmonyArkWebBridgeEnvelope(
            #"{"ok":false,"error":{"code":"javascript_error","message":"boom"}}"#
        )
        #expect(harmonyArkWebBridgeCallError(fromEnvelopeError: javascriptError!.error!).code == .javascriptError)

        let unknown = try decodeHarmonyArkWebBridgeEnvelope(
            #"{"ok":false,"error":{"code":"page_custom","message":"custom failure"}}"#
        )
        #expect(harmonyArkWebBridgeCallError(fromEnvelopeError: unknown!.error!).code == .javascriptError)

        #expect(try decodeHarmonyArkWebBridgeEnvelope("") == nil)
        #expect(try decodeHarmonyArkWebBridgeEnvelope(nil) == nil)
    }

    // MARK: - Params parsing

    @Test("params JSON parses objects and rejects non-object payloads")
    func paramsJSONParsing() throws {
        let parsed = try parseWebViewBridgeParamsJSON(#"{"k":"v","n":2,"flag":true,"nested":{"a":[3,2]}}"#)
        #expect(parsed["k"] == .string("v"))
        #expect(parsed["n"] == .int(2))
        #expect(parsed["flag"] == .bool(true))
        #expect(parsed["nested"] == .object(["a": .array([.int(3), .int(2)])]))
        #expect(try parseWebViewBridgeParamsJSON(nil) == [:])
        #expect(try parseWebViewBridgeParamsJSON("  ") == [:])
        #expect(throws: RuntimeError.self) {
            _ = try parseWebViewBridgeParamsJSON("[1,2,3]")
        }
        #expect(throws: RuntimeError.self) {
            _ = try parseWebViewBridgeParamsJSON("not-json")
        }
    }

    // MARK: - Full chain: discovery → invoke → async callback

    @Test("bridge call discovers the page, invokes, and returns the async callback payload")
    func bridgeCallHappyPathWithAsyncCallback() async throws {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage]),
            sessionFactory: { url in
                recorder.append(session: url)
                return FakeCDPSession(
                    recorder: recorder,
                    invokeAck: #"{"ok":true,"pending":true,"callID":"triton-harmony-bridge-1"}"#,
                    pollResponses: ["", #"{"ok":true,"result":{"code":200,"route":"checkout"}}"#]
                )
            }
        )

        let summary = try await callBridge(environment)

        #expect(summary.ok)
        #expect(summary.action == "webview.bridge-call")
        #expect(summary.platform == "harmony")
        #expect(summary.target == "127.0.0.1:10100")
        #expect(summary.webViewID == "arkweb-cdp:page-1")
        #expect(summary.pageSessionID == "page-1")
        #expect(summary.method == "getRouteState")
        #expect(summary.params == ["k": .string("v")])
        #expect(summary.result == .object(["code": .int(200), "route": .string("checkout")]))
        #expect(summary.error == nil)
        #expect(summary.source == "arkweb-cdp")
        #expect(summary.elapsedMs >= 0)

        // Audit trail: socket probe → fport → page list → CDP evaluate → fport rm teardown.
        #expect(recorder.commandLog.filter { $0.contains("cat /proc/net/unix") }.count == 1)
        #expect(recorder.commandLog.contains { $0.contains("fport tcp:41234 tcp:9222") })
        #expect(recorder.pageListLog == ["http://127.0.0.1:41234/json/list"])
        #expect(recorder.sessionLog == ["ws://127.0.0.1:41234/devtools/page/page-1"])
        #expect(recorder.expressionLog.count == 3) // invoke + two polls
        #expect(recorder.expressionLog.first?.contains("getRouteState") == true)
        #expect(recorder.fportRemoveCount == 1)
        #expect(recorder.closeCount == 1)
        #expect(summary.sourceCommands.contains { $0.contains("/proc/net/unix") })
        #expect(summary.sourceCommands.contains { $0.contains("fport tcp:41234 tcp:9222") })
        #expect(summary.sourceCommands.contains { $0.contains("GET http://127.0.0.1:41234/json/list") })
        #expect(summary.sourceCommands.contains { $0.contains("WS ws://127.0.0.1:41234/devtools/page/page-1") })
    }

    @Test("bridge call honors an explicit cdp local port")
    func bridgeCallHonorsExplicitLocalPort() async throws {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage]),
            sessionFactory: { _ in
                FakeCDPSession(recorder: recorder, invokeAck: #"{"ok":true,"pending":true}"#, pollResponses: [#"{"ok":true,"result":null}"#])
            }
        )

        let summary = try await callBridge(environment, webviewID: "arkweb-cdp:page-1", cdpLocalPort: 45678)

        #expect(summary.ok)
        #expect(recorder.commandLog.contains { $0.contains("fport tcp:45678 tcp:9222") })
        #expect(recorder.pageListLog == ["http://127.0.0.1:45678/json/list"])
    }

    @Test("missing devtools socket returns typed provider-missing without fport")
    func bridgeCallWithoutSocketIsProviderMissing() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: "no devtools sockets",
            pageListData: nil,
            sessionFactory: { _ in
                Issue.record("CDP session must not open without a socket")
                return FakeCDPSession(recorder: recorder, invokeAck: "{}", pollResponses: [])
            }
        )

        do {
            _ = try await callBridge(environment)
            Issue.record("Expected provider-missing failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .webViewProviderUnavailable)
            #expect(failure?.error.message.contains("webview_devtools_remote") == true)
            #expect(recorder.commandLog.contains { $0.contains("fport") } == false)
        }
    }

    @Test("failed fport returns typed provider-missing with the probe audit trail")
    func bridgeCallFportFailureIsProviderMissing() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            fportSucceeds: false,
            pageListData: nil,
            sessionFactory: { _ in
                FakeCDPSession(recorder: recorder, invokeAck: "{}", pollResponses: [])
            }
        )

        do {
            _ = try await callBridge(environment)
            Issue.record("Expected provider-missing failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .webViewProviderUnavailable)
            #expect(failure?.error.message.contains("fport") == true)
            #expect(failure?.sourceCommands.count == 2)
        }
    }

    @Test("unreachable page list endpoint returns typed provider-missing")
    func bridgeCallPageListFailureIsProviderMissing() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: nil,
            sessionFactory: { _ in
                FakeCDPSession(recorder: recorder, invokeAck: "{}", pollResponses: [])
            }
        )

        do {
            _ = try await callBridge(environment)
            Issue.record("Expected provider-missing failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .webViewProviderUnavailable)
            #expect(failure?.error.message.contains("page list") == true)
            #expect(recorder.fportRemoveCount == 1) // forward still torn down
        }
    }

    @Test("missing allowlisted method fails fast without polling")
    func bridgeCallMissingMethodIsTypedNotAllowed() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage]),
            sessionFactory: { _ in
                FakeCDPSession(
                    recorder: recorder,
                    invokeAck: #"{"ok":false,"error":{"code":"webview_method_not_allowed","message":"Method is not allowlisted: nope","hint":"Expose the method through window.__tritonBridge.methods"}}"#,
                    pollResponses: []
                )
            }
        )

        do {
            _ = try await callBridge(environment, method: "nope")
            Issue.record("Expected method-not-allowed failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .webViewMethodNotAllowed)
            #expect(failure?.error.message == "Method is not allowlisted: nope")
            #expect(recorder.expressionLog.count == 1) // invoke only, no polls
        }
    }

    @Test("callback that never arrives returns webview_bridge_timeout")
    func bridgeCallCallbackTimeoutIsTyped() async throws {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage]),
            sessionFactory: { _ in
                FakeCDPSession(recorder: recorder, invokeAck: #"{"ok":true,"pending":true}"#, pollResponses: [])
            }
        )
        let startedAt = Date()

        do {
            _ = try await callBridge(environment, timeoutMs: 40)
            Issue.record("Expected bridge timeout failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .webViewBridgeTimeout)
            #expect(failure?.error.message.contains("getRouteState") == true)
            #expect(Date().timeIntervalSince(startedAt) < 2)
            #expect(recorder.expressionLog.count > 1) // polls happened before the deadline
        }
    }

    @Test("rejected callback payload maps to javascript_error")
    func bridgeCallRejectedCallbackIsJavaScriptError() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage]),
            sessionFactory: { _ in
                FakeCDPSession(
                    recorder: recorder,
                    invokeAck: #"{"ok":true,"pending":true}"#,
                    pollResponses: [#"{"ok":false,"error":{"code":"javascript_error","message":"bridge rejected"}}"#]
                )
            }
        )

        do {
            _ = try await callBridge(environment)
            Issue.record("Expected javascript error failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .javascriptError)
            #expect(failure?.error.message == "bridge rejected")
        }
    }

    @Test("multiple pages without a webview id fail as ambiguous with candidates")
    func bridgeCallAmbiguousPagesIsTyped() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage, secondPage]),
            sessionFactory: { _ in
                FakeCDPSession(recorder: recorder, invokeAck: "{}", pollResponses: [])
            }
        )

        do {
            _ = try await callBridge(environment)
            Issue.record("Expected ambiguous failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .ambiguousWebView)
            let candidates = failure?.error.candidates() ?? []
            #expect(candidates.map(\.webViewID) == ["arkweb-cdp:page-1", "arkweb-cdp:page-2"])
            #expect(recorder.sessionLog.isEmpty)
        }
    }

    @Test("unmatched webview id across multiple pages fails as webview_id_not_found")
    func bridgeCallUnmatchedWebviewIDIsTyped() async {
        let recorder = Recorder()
        let environment = makeEnvironment(
            recorder: recorder,
            socketOutput: devtoolsSocketOutput,
            pageListData: pageListJSON(pages: [singlePage, secondPage]),
            sessionFactory: { _ in
                FakeCDPSession(recorder: recorder, invokeAck: "{}", pollResponses: [])
            }
        )

        do {
            _ = try await callBridge(environment, webviewID: "harmony:host:does-not-exist")
            Issue.record("Expected webview_id_not_found failure")
        } catch {
            let failure = failure(error)
            #expect(failure?.error.code == .webViewIDNotFound)
            #expect(recorder.sessionLog.isEmpty)
        }
    }

    @Test("failure summaries keep the params echo and typed webview error")
    func failureSummaryKeepsParamsEcho() {
        let failure = HarmonyArkWebBridgeCallFailure(
            error: .methodNotAllowed("Method is not allowlisted: nope"),
            sourceCommands: ["hdc -t 127.0.0.1:10100 shell cat /proc/net/unix"]
        )
        let summary = harmonyArkWebBridgeCallFailureSummary(
            failure,
            target: "127.0.0.1:10100",
            method: "nope",
            params: ["k": .string("v")],
            startedAt: Date().addingTimeInterval(-0.05)
        )

        #expect(summary.ok == false)
        #expect(summary.action == "webview.bridge-call")
        #expect(summary.method == "nope")
        #expect(summary.params == ["k": .string("v")])
        #expect(summary.error?.code == .webViewMethodNotAllowed)
        #expect(summary.error?.hint != nil)
        #expect(summary.elapsedMs >= 40)
        #expect(summary.sourceCommands == ["hdc -t 127.0.0.1:10100 shell cat /proc/net/unix"])
    }

    // MARK: - webview list integration

    private let layoutJSON = #"{"attributes":{"type":"Web","text":"Home","bounds":"[0,0][720,1280]","visible":"true"}}"#

    private func layoutCapture() -> HarmonyLayoutCapture {
        HarmonyLayoutCapture(
            localPath: "/tmp/sp-173-layout.json",
            remotePath: "/data/local/tmp/sp-173-layout.json",
            sourceCommands: ["hdc shell uitest dumpLayout", "hdc file recv layout.json"],
            data: Data(layoutJSON.utf8)
        )
    }

    @Test("webview list fuses arkweb cdp pages and drops the permanent bridge-call gap")
    func webViewListWithCDPProviderFusion() throws {
        let pages = try decodeHarmonyArkWebPageList(pageListJSON(pages: [singlePage, secondPage]))
        let response = try harmonyWebViewCandidatesWithCDP(
            action: "webview.list",
            selected: target,
            layout: layoutCapture(),
            cdp: (pages, ["hdc shell cat /proc/net/unix", "GET http://127.0.0.1:41234/json/list"]),
            runtimeBaseURL: nil
        )

        #expect(response.ok)
        let hostLayout = response.candidates.filter { $0.source == "host-layout" }
        let cdpCandidates = response.candidates.filter { $0.source == "arkweb-cdp" }
        #expect(hostLayout.count == 1)
        #expect(cdpCandidates.map(\.webViewID) == ["arkweb-cdp:page-1", "arkweb-cdp:page-2"])
        #expect(hostLayout.allSatisfy { !$0.missingCapabilities.contains("webview.bridge-call") })
        #expect(hostLayout.allSatisfy { $0.capabilities.contains("webview.bridge-call") })
        #expect(cdpCandidates.allSatisfy { $0.providerStatus == "available" })
        #expect(cdpCandidates.allSatisfy { $0.capabilities.contains("webview.bridge-call") })
        #expect(response.sources.contains { $0.name == "arkweb-cdp" && $0.available })
        #expect(response.sourceCommands.contains { $0.contains("/json/list") })
        #expect(response.note.contains("ArkWeb DevTools CDP endpoint provides allowlisted bridge calls"))
        // Multiple visible pages of similar confidence stay unresolved until --webview-id is supplied.
        #expect(response.current == nil)
    }

    @Test("webview list without a reachable cdp endpoint keeps the typed gap")
    func webViewListWithoutCDPKeepsMissingCapability() throws {
        let response = try harmonyWebViewCandidatesWithCDP(
            action: "webview.list",
            selected: target,
            layout: layoutCapture(),
            cdp: nil,
            runtimeBaseURL: nil
        )

        #expect(response.candidates.allSatisfy { $0.missingCapabilities.contains("webview.bridge-call") })
        #expect(response.sources.contains { $0.name == "arkweb-cdp" && !$0.available })
        #expect(response.note.contains("reachable ArkWeb DevTools endpoint"))
    }

    // MARK: - Schema alignment

    @Test("webview schema mounts the harmony bridge-call surface and failure codes")
    func webviewSchemaMountsHarmonyBridgeCall() throws {
        let schema = try #require(commandSchemas().first { $0.name == "webview" })
        let optionNames = Set(schema.options.map(\.name))
        let usageForms = Set(schema.usageForms.map(\.form))

        #expect(usageForms.contains("bridge-call"))
        #expect(optionNames.contains("--method"))
        #expect(optionNames.contains("--params"))
        #expect(optionNames.contains("--devtools-port"))
        #expect(optionNames.contains("--cdp-local-port"))
        #expect(optionNames.contains("--webview-id"))
        #expect(schema.providedCapabilities.contains("webview-bridge-call"))
        #expect(schema.failureCodes.contains("webview_bridge_timeout"))
        #expect(schema.failureCodes.contains("webview_method_not_allowed"))
        #expect(schema.failureCodes.contains("webview_provider_unavailable"))
        #expect(schema.failureShape?.contains("webview_bridge_timeout") == true)
        #expect(schema.successShape?.contains("action:webview.bridge-call") == true)
        #expect(schema.outputSemantics?.contains("ArkWeb") == true)
        #expect(schema.examples.contains { $0.contains("webview bridge-call") && $0.contains("--platform harmony") })
        #expect(schema.outputContracts.contains { $0.selector == "webview.bridge-call" })
        let contract = try #require(schema.outputContracts.first { $0.selector == "webview.bridge-call" })
        #expect(contract.model == "WebViewBridgeCallSummary")
        #expect(contract.fields.contains { $0.name == "params" })
        #expect(contract.fields.contains { $0.name == "result" })
        #expect(contract.fields.contains { $0.name == "source" })
    }
}
