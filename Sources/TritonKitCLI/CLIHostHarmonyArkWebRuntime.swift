import Foundation
import TritonKitShared

// MARK: - SP-173 / GitHub #207: Harmony host-side ArkWeb bridge-call adapter
//
// The host adapter reaches a visible ArkWeb instance through the DevTools CDP
// endpoint (`webview_devtools_remote_<pid>`): HDC fport forwards the discovered Unix
// socket, `/json/list` discovers pages, and a CDP WebSocket session evaluates an
// explicitly named allowlisted page bridge method (`window.__tritonBridge.methods`)
// and polls for the asynchronous callback result. The CDP channel is an
// implementation detail: the product surface stays `triton webview bridge-call`
// with an explicit method and JSON params, never arbitrary JS eval.

/// One page reported by the ArkWeb DevTools `/json/list` endpoint.
struct HarmonyArkWebPage: Codable, Equatable {
    let id: String
    let type: String?
    let title: String?
    let url: String?
    let attached: Bool?
}

/// The resolved HDC forward for one ArkWeb DevTools endpoint.
struct HarmonyArkWebCDPEndpoint: Equatable {
    let socketName: String
    let remoteNode: String
    let localPort: Int
    let forwardSourceCommand: String
    let socketSourceCommand: String
}

/// Host-side CDP session used to evaluate bridge scripts on one ArkWeb page.
protocol HarmonyArkWebCDPSession {
    func evaluate(expression: String, timeoutSeconds: Double) async throws -> String?
    func close() async
}

/// Injectable seams so the discovery → invoke → callback chain stays offline-testable.
struct HarmonyArkWebCDPEnvironment {
    var runner: HostDeviceCommandRunner
    var pageListLoader: (URL) async throws -> Data
    var sessionFactory: (URL) -> HarmonyArkWebCDPSession
    var localPortProvider: () -> Int
    var pollIntervalSeconds: Double
    var now: () -> Date

    static func live(pollIntervalSeconds: Double = 0.1) -> HarmonyArkWebCDPEnvironment {
        HarmonyArkWebCDPEnvironment(
            runner: { command in try runHostCommand(command) },
            pageListLoader: { url in
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw HarmonyArkWebBridgeCallError.providerMissing("DevTools page list returned a non-200 response")
                }
                return data
            },
            sessionFactory: { url in HarmonyArkWebURLSessionCDPSession(url: url) },
            localPortProvider: { Int.random(in: 20000...59999) },
            pollIntervalSeconds: pollIntervalSeconds,
            now: { Date() }
        )
    }
}

/// Typed failure family for the Harmony host bridge-call adapter.
enum HarmonyArkWebBridgeCallError: Error, Equatable {
    /// No ArkWeb DevTools socket, fport failure, or CDP endpoint unreachable.
    case providerMissing(String)
    /// CDP endpoint exposed no visible page target.
    case webviewNotFound
    /// `--webview-id` matched no CDP page while multiple pages were visible.
    case webviewIDNotFound(String, [HarmonyArkWebPage])
    /// Multiple CDP pages are visible and no `--webview-id` disambiguated them.
    case ambiguousWebView([HarmonyArkWebPage])
    /// Method is not exposed through `window.__tritonBridge.methods`.
    case methodNotAllowed(String)
    /// The page bridge never produced a callback before the deadline.
    case bridgeTimeout(String)
    /// The page bridge threw synchronously or the callback rejected.
    case javascriptError(String)

    var code: TKWebViewErrorCode {
        switch self {
        case .providerMissing: return .webViewProviderUnavailable
        case .webviewNotFound: return .webviewNotFound
        case .webviewIDNotFound: return .webViewIDNotFound
        case .ambiguousWebView: return .ambiguousWebView
        case .methodNotAllowed: return .webViewMethodNotAllowed
        case .bridgeTimeout: return .webViewBridgeTimeout
        case .javascriptError: return .javascriptError
        }
    }

    var message: String {
        switch self {
        case .providerMissing(let reason):
            return "Harmony ArkWeb bridge-call provider is unavailable: \(reason)"
        case .webviewNotFound:
            return "No visible ArkWeb page was reported by the DevTools endpoint."
        case .webviewIDNotFound(let webviewID, _):
            return "No ArkWeb DevTools page matched --webview-id \(webviewID)."
        case .ambiguousWebView:
            return "Multiple visible ArkWeb pages matched; pass --webview-id with one arkweb-cdp candidate."
        case .methodNotAllowed(let message):
            return message
        case .bridgeTimeout(let message):
            return message
        case .javascriptError(let message):
            return message
        }
    }

    var hint: String? {
        switch self {
        case .providerMissing:
            return "Open the target page in a DevEco Emulator ArkWeb instance with the DevTools socket reachable, verify --devtools-port, and rerun `triton webview bridge-call --platform harmony --json`."
        case .webviewNotFound:
            return "Run `triton webview list --platform harmony --json` to confirm a visible ArkWeb candidate before calling bridge methods."
        case .webviewIDNotFound:
            return "Run `triton webview list --platform harmony --json` and pass one of the arkweb-cdp:<pageID> candidates."
        case .ambiguousWebView:
            return "Run `triton webview list --platform harmony --json` and pass --webview-id with the intended arkweb-cdp:<pageID> candidate."
        case .methodNotAllowed:
            return "Expose the method through window.__tritonBridge.methods or use `triton webview snapshot --include metadata,text,dom,forms --json` for linked validation."
        case .bridgeTimeout:
            return "Verify the page bridge calls back for this method, or retry with a larger --timeout-ms."
        case .javascriptError:
            return "Inspect the page bridge handler; Triton only forwards the call and reports the page error."
        }
    }

    /// WebView candidates attached to selection failures for machine-readable triage.
    func candidates() -> [TKWebViewDescriptor] {
        switch self {
        case .webviewIDNotFound(_, let pages), .ambiguousWebView(let pages):
            return pages.map { harmonyArkWebPageDescriptor($0) }
        default:
            return []
        }
    }
}

/// Error plus the source commands already executed, so typed failures keep audit trails.
struct HarmonyArkWebBridgeCallFailure: Error {
    let error: HarmonyArkWebBridgeCallError
    let sourceCommands: [String]
}

// MARK: - Discovery

/// Parses `webview_devtools_remote_<pid>` socket names from `/proc/net/unix` output.
func harmonyArkWebSocketNames(fromProcNetUnix output: String) -> [String] {
    let names = output.split(whereSeparator: \.isNewline).compactMap { line -> String? in
        guard let range = line.range(of: "webview_devtools_remote_") else { return nil }
        let name = String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
    return Array(Set(names)).sorted()
}

func harmonyArkWebProcNetUnixCommand(target: String, hdc: String) -> TKHostCommand {
    TKHostCommand(
        executable: hdc,
        arguments: ["-t", target, "shell", "cat", "/proc/net/unix"],
        riskLevel: .readonly,
        requiredConfig: [.target, .timeout],
        defaultTimeoutSeconds: 10
    )
}

func harmonyArkWebRemoveForwardCommand(target: String, localPort: Int, remoteNode: String, hdc: String) -> TKHostCommand {
    TKHostCommand(
        executable: hdc,
        arguments: ["-t", target, "fport", "rm", "tcp:\(localPort)", remoteNode],
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord],
        defaultTimeoutSeconds: 10
    )
}

func harmonyArkWebPageListURL(localPort: Int) -> URL {
    URL(string: "http://127.0.0.1:\(localPort)/json/list")!
}

func harmonyArkWebSocketURL(endpoint: HarmonyArkWebCDPEndpoint, pageID: String) -> URL {
    let escapedID = pageID.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~")))!
    return URL(string: "ws://127.0.0.1:\(endpoint.localPort)/devtools/page/\(escapedID)")!
}

/// Decodes the ArkWeb DevTools `/json/list` payload into visible page targets.
func decodeHarmonyArkWebPageList(_ data: Data) throws -> [HarmonyArkWebPage] {
    let decoder = JSONDecoder()
    let pages = try decoder.decode([HarmonyArkWebPage].self, from: data)
    return pages.filter { $0.type == nil || $0.type == "page" }
}

/// Runs `body` with a live HDC forward to the ArkWeb DevTools endpoint and tears
/// the forward down afterwards, even when `body` fails.
func harmonyArkWebWithForward<T>(
    selected: TKHarmonyTarget,
    hdc: String,
    devtoolsPort: Int?,
    localPort: Int?,
    environment: HarmonyArkWebCDPEnvironment,
    body: (HarmonyArkWebCDPEndpoint) async throws -> T
) async throws -> T {
    let socketCommand = harmonyArkWebProcNetUnixCommand(target: selected.target, hdc: hdc)
    let socketResult: HostProcessResult
    do {
        socketResult = try environment.runner(socketCommand)
    } catch {
        throw HarmonyArkWebBridgeCallFailure(
            error: .providerMissing("hdc /proc/net/unix probe failed: \(error)"),
            sourceCommands: [hostSourceCommand(socketCommand)]
        )
    }
    let socketNames = harmonyArkWebSocketNames(fromProcNetUnix: socketResult.stdout)
    guard devtoolsPort != nil || socketNames.count == 1 else {
        throw HarmonyArkWebBridgeCallFailure(
            error: .providerMissing(socketNames.isEmpty
                ? "no webview_devtools_remote_<pid> socket in /proc/net/unix"
                : "Multiple ArkWeb DevTools sockets found; close unrelated debug apps or explicitly select an already configured endpoint with --devtools-port. No socket was selected."),
            sourceCommands: [socketResult.sourceCommand]
        )
    }
    let socketName = socketNames.first ?? "tcp-override"
    let remoteNode = devtoolsPort.map { "tcp:\($0)" } ?? "localabstract:\(socketName)"
    let resolvedLocalPort = localPort ?? environment.localPortProvider()
    let forwardCommand = TKHostCommand(
        executable: hdc,
        arguments: ["-t", selected.target, "fport", "tcp:\(resolvedLocalPort)", remoteNode],
        riskLevel: .automation,
        requiredConfig: [.target, .timeout, .auditRecord],
        defaultTimeoutSeconds: 10
    )
    let forwardResult: HostProcessResult
    do {
        forwardResult = try environment.runner(forwardCommand)
        if forwardResult.exitCode != 0 || (forwardResult.stdout + forwardResult.stderr).contains("[Fail]") {
            throw HarmonyArkWebBridgeCallError.providerMissing("HDC reported a failed forward creation")
        }
    } catch {
        throw HarmonyArkWebBridgeCallFailure(
            error: .providerMissing("hdc fport tcp:\(resolvedLocalPort) \(remoteNode) failed: \(error)"),
            sourceCommands: [socketResult.sourceCommand, hostSourceCommand(forwardCommand)]
        )
    }
    let endpoint = HarmonyArkWebCDPEndpoint(
        socketName: socketName,
        remoteNode: remoteNode,
        localPort: resolvedLocalPort,
        forwardSourceCommand: forwardResult.sourceCommand,
        socketSourceCommand: socketResult.sourceCommand
    )
    let outcome: Result<T, Error>
    do { outcome = .success(try await body(endpoint)) }
    catch { outcome = .failure(error) }
    let removeCommand = harmonyArkWebRemoveForwardCommand(target: selected.target, localPort: resolvedLocalPort, remoteNode: remoteNode, hdc: hdc)
    do {
        let removed = try environment.runner(removeCommand)
        if removed.exitCode != 0 || (removed.stdout + removed.stderr).contains("[Fail]") {
            throw HarmonyArkWebBridgeCallError.providerMissing("HDC reported a failed forward removal")
        }
    } catch {
        // Preserve a primary failure. A successful invocation with failed teardown
        // must not silently claim clean delivery or invite an automatic retry.
        if case .success = outcome {
            throw HarmonyArkWebBridgeCallFailure(
                error: .providerMissing("HDC forward cleanup failed; the bridge may already have executed. Remove the recorded forward before retrying. \(error)"),
                sourceCommands: [socketResult.sourceCommand, forwardResult.sourceCommand, hostSourceCommand(removeCommand)]
            )
        }
    }
    return try outcome.get()
}

/// Discovery-only helper used by `webview list` to attach ArkWeb provider state.
func harmonyArkWebCDPDiscoverPages(
    selected: TKHarmonyTarget,
    hdc: String,
    devtoolsPort: Int?,
    localPort: Int? = nil,
    environment: HarmonyArkWebCDPEnvironment
) async throws -> (pages: [HarmonyArkWebPage], sourceCommands: [String]) {
    try await harmonyArkWebWithForward(
        selected: selected,
        hdc: hdc,
        devtoolsPort: devtoolsPort,
        localPort: localPort,
        environment: environment
    ) { endpoint in
        var sourceCommands = [endpoint.socketSourceCommand, endpoint.forwardSourceCommand]
        let url = harmonyArkWebPageListURL(localPort: endpoint.localPort)
        let data: Data
        do {
            data = try await environment.pageListLoader(url)
        } catch {
            throw HarmonyArkWebBridgeCallFailure(
                error: .providerMissing("ArkWeb DevTools page list request failed: \(error)"),
                sourceCommands: sourceCommands + ["GET \(url.absoluteString)"]
            )
        }
        let pages: [HarmonyArkWebPage]
        do {
            pages = try decodeHarmonyArkWebPageList(data)
        } catch {
            throw HarmonyArkWebBridgeCallFailure(
                error: .providerMissing("ArkWeb DevTools page list payload was not a JSON page array: \(error)"),
                sourceCommands: sourceCommands + ["GET \(url.absoluteString)"]
            )
        }
        sourceCommands.append("GET \(url.absoluteString)")
        return (pages, sourceCommands)
    }
}

// MARK: - Page selection

/// Selection rules: an explicit `--webview-id` matches `arkweb-cdp:<pageID>` or the
/// raw page id; an explicit mismatch always fails closed. Without an id a
/// single page is selected and multiple pages are ambiguous.
func harmonyArkWebSelectPage(_ pages: [HarmonyArkWebPage], webviewID: String?) throws -> HarmonyArkWebPage {
    if pages.isEmpty {
        throw HarmonyArkWebBridgeCallError.webviewNotFound
    }
    if let webviewID, !webviewID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let matched = pages.first { page in
            page.id == webviewID || harmonyArkWebPageDescriptorID(page) == webviewID
        }
        if let matched {
            return matched
        }
        throw HarmonyArkWebBridgeCallError.webviewIDNotFound(webviewID, pages)
    }
    guard pages.count == 1, let only = pages.first else {
        throw HarmonyArkWebBridgeCallError.ambiguousWebView(pages)
    }
    return only
}

func harmonyArkWebPageDescriptorID(_ page: HarmonyArkWebPage) -> String {
    "arkweb-cdp:\(page.id)"
}

/// CDP-backed WebView candidate surfaced by `triton webview list --platform harmony`.
func harmonyArkWebPageDescriptor(_ page: HarmonyArkWebPage) -> TKWebViewDescriptor {
    TKWebViewDescriptor(
        webViewID: harmonyArkWebPageDescriptorID(page),
        platform: "harmony",
        source: "arkweb-cdp",
        nodeID: harmonyArkWebPageDescriptorID(page),
        role: page.type ?? "page",
        text: page.title,
        identifier: page.id,
        candidateOnly: true,
        confidence: 0.96,
        url: page.url,
        title: page.title,
        pageSessionID: page.id,
        providerStatus: "available",
        bridgeStatus: "page-bridge-required",
        capabilities: ["webview.url", "webview.bridge-call"],
        missingCapabilities: ["webview.dom", "semantic-action"]
    )
}

// MARK: - Bridge scripts

/// Host-side invoke script: validates the allowlist, invokes the named method, and
/// stores the asynchronous callback envelope under a host-generated call id.
func harmonyArkWebBridgeInvokeScript(callID: String, method: String, arguments: [String: TKJSONValue], timeoutMs: Int = 10_000) throws -> String {
    let encoder = JSONEncoder()
    let callIDData = try encoder.encode(callID)
    let methodData = try encoder.encode(method)
    let argumentsData = try encoder.encode(arguments)
    guard let callIDLiteral = String(data: callIDData, encoding: .utf8),
          let methodLiteral = String(data: methodData, encoding: .utf8),
          let argumentsLiteral = String(data: argumentsData, encoding: .utf8) else {
        throw HarmonyArkWebBridgeCallError.javascriptError("Unable to encode Harmony bridge call script.")
    }
    return """
    (function() {
      var callID = \(callIDLiteral);
      var method = \(methodLiteral);
      var args = \(argumentsLiteral);
      var store = (window.__tritonHostBridgeCalls = window.__tritonHostBridgeCalls || Object.create(null));
      var bridge = window.__tritonBridge;
      var descriptor = bridge && bridge.methods && Object.getOwnPropertyDescriptor(bridge.methods, method);
      if (!descriptor || typeof descriptor.value !== "function") {
        return JSON.stringify({ ok: false, error: { code: "webview_method_not_allowed", message: "Method is not allowlisted: " + method, hint: "Register an own function on window.__tritonBridge.methods." } });
      }
      if (typeof document !== "undefined" && document.visibilityState === "hidden") {
        return JSON.stringify({ ok: false, error: { code: "webview_not_found", message: "Selected ArkWeb page is hidden." } });
      }
      store[callID] = null;
      if (typeof setTimeout === "function") {
        setTimeout(function() { delete store[callID]; }, \(max(1, min(timeoutMs, 300_000)) + 1000));
      }
      var settled = false;
      function reject(error) {
        if (settled || !Object.prototype.hasOwnProperty.call(store, callID)) return;
        settled = true;
        store[callID] = JSON.stringify({ ok: false, error: { code: "javascript_error", message: String(error && error.message ? error.message : error) } });
      }
      function complete(value) {
        if (settled || !Object.prototype.hasOwnProperty.call(store, callID)) return;
        try {
          var encoded = JSON.stringify({ ok: true, result: value === undefined ? null : value });
          settled = true;
          store[callID] = encoded;
        } catch (error) { reject(error); }
      }
      try {
        var returned = descriptor.value.call(bridge.methods, args, complete, reject);
        if (returned !== undefined) Promise.resolve(returned).then(complete, reject);
        return JSON.stringify({ ok: true, pending: true, callID: callID });
      } catch (error) {
        var syncError = JSON.stringify({ ok: false, error: { code: "javascript_error", message: String(error && error.message ? error.message : error) } });
        delete store[callID];
        return syncError;
      }
    })()
    """
}

/// Host-side poll script: returns and clears the stored callback envelope.
func harmonyArkWebBridgePollScript(callID: String) throws -> String {
    let callIDData = try JSONEncoder().encode(callID)
    guard let callIDLiteral = String(data: callIDData, encoding: .utf8) else {
        throw HarmonyArkWebBridgeCallError.javascriptError("Unable to encode Harmony bridge poll script.")
    }
    return """
    (function() {
      var store = window.__tritonHostBridgeCalls || {};
      var value = store[\(callIDLiteral)];
      if (typeof value === "string") { delete store[\(callIDLiteral)]; return value; }
      return "";
    })()
    """
}

struct HarmonyArkWebBridgeEnvelopeError: Decodable, Equatable {
    let code: String
    let message: String
    let hint: String?
}

struct HarmonyArkWebBridgeEnvelope: Decodable, Equatable {
    let ok: Bool
    let pending: Bool?
    let callID: String?
    let result: TKJSONValue?
    let error: HarmonyArkWebBridgeEnvelopeError?
}

func decodeHarmonyArkWebBridgeEnvelope(_ value: String?) throws -> HarmonyArkWebBridgeEnvelope? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    guard let data = value.data(using: .utf8) else {
        throw HarmonyArkWebBridgeCallError.javascriptError("ArkWeb bridge envelope was not valid UTF-8.")
    }
    return try JSONDecoder().decode(HarmonyArkWebBridgeEnvelope.self, from: data)
}

func harmonyArkWebBridgeCallError(fromEnvelopeError envelopeError: HarmonyArkWebBridgeEnvelopeError) -> HarmonyArkWebBridgeCallError {
    switch envelopeError.code {
    case "webview_not_found":
        return .webviewNotFound
    case "webview_method_not_allowed":
        return .methodNotAllowed(envelopeError.message)
    case "javascript_error":
        return .javascriptError(envelopeError.message)
    default:
        return .javascriptError("\(envelopeError.code): \(envelopeError.message)")
    }
}

// MARK: - Bridge call

func harmonyArkWebBridgeCallSummary(
    ok: Bool,
    platform: String = "harmony",
    target: String,
    webViewID: String,
    pageSessionID: String?,
    method: String,
    params: [String: TKJSONValue],
    result: TKJSONValue?,
    error: TKWebViewError?,
    startedAt: Date,
    source: String,
    sourceCommands: [String],
    now: Date = Date()
) -> WebViewBridgeCallSummary {
    WebViewBridgeCallSummary(
        ok: ok,
        platform: platform,
        capturedAt: ISO8601DateFormatter().string(from: now),
        target: target,
        webViewID: webViewID,
        pageSessionID: pageSessionID,
        method: method,
        params: params,
        result: result,
        error: error,
        elapsedMs: max(0, Int(now.timeIntervalSince(startedAt) * 1000)),
        source: source,
        sourceCommands: sourceCommands
    )
}

/// Full host-side Harmony ArkWeb bridge-call: discovery → invoke → async callback.
func harmonyArkWebBridgeCall(
    selected: TKHarmonyTarget,
    hdc: String,
    webviewID: String?,
    method: String,
    params: [String: TKJSONValue],
    timeoutMs: Int?,
    devtoolsPort: Int?,
    cdpLocalPort: Int?,
    environment: HarmonyArkWebCDPEnvironment
) async throws -> WebViewBridgeCallSummary {
    let startedAt = environment.now()
    let timeoutSeconds = max(0.001, Double(timeoutMs ?? 10_000) / 1000)
    do {
        return try await harmonyArkWebWithForward(
            selected: selected,
            hdc: hdc,
            devtoolsPort: devtoolsPort,
            localPort: cdpLocalPort,
            environment: environment
        ) { endpoint in
            var sourceCommands = [endpoint.socketSourceCommand, endpoint.forwardSourceCommand]
            let listURL = harmonyArkWebPageListURL(localPort: endpoint.localPort)
            let pages: [HarmonyArkWebPage]
            do {
                let data = try await environment.pageListLoader(listURL)
                pages = try decodeHarmonyArkWebPageList(data)
                sourceCommands.append("GET \(listURL.absoluteString)")
            } catch let failure as HarmonyArkWebBridgeCallFailure {
                throw HarmonyArkWebBridgeCallFailure(error: failure.error, sourceCommands: sourceCommands + failure.sourceCommands)
            } catch {
                throw HarmonyArkWebBridgeCallFailure(
                    error: .providerMissing("ArkWeb DevTools page list request failed: \(error)"),
                    sourceCommands: sourceCommands + ["GET \(listURL.absoluteString)"]
                )
            }
            let page: HarmonyArkWebPage
            do {
                page = try harmonyArkWebSelectPage(pages, webviewID: webviewID)
            } catch let selectionError as HarmonyArkWebBridgeCallError {
                throw HarmonyArkWebBridgeCallFailure(error: selectionError, sourceCommands: sourceCommands)
            }
            let session = environment.sessionFactory(harmonyArkWebSocketURL(endpoint: endpoint, pageID: page.id))
            sourceCommands.append("WS \(harmonyArkWebSocketURL(endpoint: endpoint, pageID: page.id).absoluteString) Runtime.evaluate")
            let callID = "triton-harmony-bridge-\(UUID().uuidString)"
            let invocationStartedAt = environment.now()

            func runSessionInteraction() async throws -> WebViewBridgeCallSummary {
                let invokeScript = try harmonyArkWebBridgeInvokeScript(callID: callID, method: method, arguments: params, timeoutMs: Int(timeoutSeconds * 1000))
                let ack = try await session.evaluate(expression: invokeScript, timeoutSeconds: timeoutSeconds)
                if let ackEnvelope = try decodeHarmonyArkWebBridgeEnvelope(ack), !ackEnvelope.ok {
                    let bridgeError = ackEnvelope.error.map(harmonyArkWebBridgeCallError(fromEnvelopeError:))
                        ?? HarmonyArkWebBridgeCallError.javascriptError("ArkWeb bridge call failed without an error envelope.")
                    throw HarmonyArkWebBridgeCallFailure(error: bridgeError, sourceCommands: [])
                }
                let pollScript = try harmonyArkWebBridgePollScript(callID: callID)
                while true {
                    let elapsed = environment.now().timeIntervalSince(invocationStartedAt)
                    guard elapsed < timeoutSeconds else {
                        throw HarmonyArkWebBridgeCallFailure(
                            error: .bridgeTimeout("ArkWeb page bridge did not call back for method \(method) within \(Int(timeoutSeconds * 1000)) ms."),
                            sourceCommands: []
                        )
                    }
                    let pollValue = try await session.evaluate(
                        expression: pollScript,
                        timeoutSeconds: max(0.001, timeoutSeconds - environment.now().timeIntervalSince(invocationStartedAt))
                    )
                    if let envelope = try decodeHarmonyArkWebBridgeEnvelope(pollValue) {
                        if envelope.ok {
                            return harmonyArkWebBridgeCallSummary(
                                ok: true,
                                target: selected.target,
                                webViewID: harmonyArkWebPageDescriptorID(page),
                                pageSessionID: page.id,
                                method: method,
                                params: params,
                                result: envelope.result,
                                error: nil,
                                startedAt: startedAt,
                                source: "arkweb-cdp",
                                sourceCommands: sourceCommands,
                                now: environment.now()
                            )
                        }
                        let bridgeError = envelope.error.map(harmonyArkWebBridgeCallError(fromEnvelopeError:))
                            ?? HarmonyArkWebBridgeCallError.javascriptError("ArkWeb bridge call failed without an error envelope.")
                        throw HarmonyArkWebBridgeCallFailure(error: bridgeError, sourceCommands: [])
                    }
                    let remaining = timeoutSeconds - environment.now().timeIntervalSince(invocationStartedAt)
                    try await Task.sleep(nanoseconds: UInt64(max(0, min(environment.pollIntervalSeconds, remaining)) * 1_000_000_000))
                }
            }

            // The CDP session must be closed on every exit path before the summary
            // (or failure) escapes, so teardown ordering stays observable.
            let summary: WebViewBridgeCallSummary
            do {
                summary = try await runSessionInteraction()
            } catch {
                let literal = String(data: try JSONEncoder().encode(callID), encoding: .utf8)!
                _ = try? await session.evaluate(expression: "delete (window.__tritonHostBridgeCalls || {})[\(literal)]", timeoutSeconds: 0.2)
                await session.close()
                switch error {
                case let failure as HarmonyArkWebBridgeCallFailure:
                    throw HarmonyArkWebBridgeCallFailure(error: failure.error, sourceCommands: sourceCommands + failure.sourceCommands)
                case let bridgeError as HarmonyArkWebBridgeCallError:
                    throw HarmonyArkWebBridgeCallFailure(error: bridgeError, sourceCommands: sourceCommands)
                default:
                    throw HarmonyArkWebBridgeCallFailure(
                        error: .javascriptError("ArkWeb bridge call failed: \(error)"),
                        sourceCommands: sourceCommands
                    )
                }
            }
            await session.close()
            return summary
        }
    }
}

/// WebView summary shape for a typed Harmony bridge-call failure.
func harmonyArkWebBridgeCallFailureSummary(
    _ failure: HarmonyArkWebBridgeCallFailure,
    target: String,
    method: String,
    params: [String: TKJSONValue],
    startedAt: Date,
    now: Date = Date()
) -> WebViewBridgeCallSummary {
    harmonyArkWebBridgeCallSummary(
        ok: false,
        target: target,
        webViewID: failure.error.candidates().first?.webViewID ?? "arkweb-cdp:unresolved",
        pageSessionID: nil,
        method: method,
        params: params,
        result: nil,
        error: TKWebViewError(
            code: failure.error.code,
            message: failure.error.message,
            hint: failure.error.hint,
            candidates: failure.error.candidates().isEmpty ? nil : failure.error.candidates()
        ),
        startedAt: startedAt,
        source: "arkweb-cdp",
        sourceCommands: failure.sourceCommands,
        now: now
    )
}
