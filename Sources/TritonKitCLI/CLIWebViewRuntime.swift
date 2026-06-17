import ArgumentParser
import Foundation
import TritonKitShared

func runWebViewList(
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    output: String?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let response = try await webViewCandidates(action: "webview.list", platform: platform, target: target, hdc: hdc, host: host, port: port, runtimeBaseURL: runtimeBaseURL, output: output)
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("platform: \(response.platform)")
            print("target: \(response.target)")
            print("candidates: \(response.candidates.count)")
            for candidate in response.candidates {
                print(renderWebViewCandidate(candidate))
            }
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func runWebViewCurrent(
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    webViewID: String?,
    output: String?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    var resolvedTarget = target
    do {
        let list = try await webViewCandidates(action: "webview.current", platform: platform, target: target, hdc: hdc, host: host, port: port, runtimeBaseURL: runtimeBaseURL, output: output)
        resolvedTarget = list.target
        let selected = try TKSelectCurrentWebView(from: list.candidates, webViewID: webViewID)
        let response = TKWebViewCurrentResponse(ok: true, action: "webview.current", platform: list.platform, capturedAt: list.capturedAt, target: list.target, webView: selected, sources: list.sources, sourceCommands: list.sourceCommands, note: list.note)
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print(renderWebViewCandidate(selected))
        }
    } catch {
        if error is ExitCode { throw error }
        if let selectionError = error as? TKWebViewSelectionError {
            try failWebViewCommand(selectionError, action: "webview.current", platform: platform, target: resolvedTarget, runtimeBaseURL: runtimeBaseURL, outputFormat: outputFormat)
        }
        if platform == .harmony {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func runWebViewCurrentURL(
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    webViewID: String?,
    output: String?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    var resolvedTarget = target
    do {
        let list = try await webViewCandidates(action: "webview.current-url", platform: platform, target: target, hdc: hdc, host: host, port: port, runtimeBaseURL: runtimeBaseURL, output: output)
        resolvedTarget = list.target
        let summary = try makeWebViewCurrentURLSummary(from: list, webViewID: webViewID)
        switch outputFormat {
        case .json:
            print(try encodeJSON(summary))
        case .text:
            print(summary.url)
        }
    } catch {
        if error is ExitCode { throw error }
        if let selectionError = error as? TKWebViewSelectionError {
            try failWebViewCommand(selectionError, action: "webview.current-url", platform: platform, target: resolvedTarget, runtimeBaseURL: runtimeBaseURL, outputFormat: outputFormat)
        }
        if platform == .harmony {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func runRouteAssertCurrentURL(
    expectedURL: String,
    ignoreQuery: Bool,
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    webViewID: String?,
    output: String?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    var resolvedTarget = target
    do {
        let list = try await webViewCandidates(action: "route.assert-current-url", platform: platform, target: target, hdc: hdc, host: host, port: port, runtimeBaseURL: runtimeBaseURL, output: output)
        resolvedTarget = list.target
        let current = try makeWebViewCurrentURLSummary(from: list, webViewID: webViewID)
        let summary = makeRouteCurrentURLAssertion(expectedURL: expectedURL, current: current, ignoreQuery: ignoreQuery)
        switch outputFormat {
        case .json:
            print(try encodeJSON(summary))
        case .text:
            print(summary.matched ? "pass" : "fail")
            print("expected: \(summary.expectedURL)")
            print("actual: \(summary.actualURL)")
        }
        if !summary.ok {
            throw ExitCode.failure
        }
    } catch {
        if error is ExitCode { throw error }
        if let selectionError = error as? TKWebViewSelectionError {
            try failWebViewCommand(selectionError, action: "route.assert-current-url", platform: platform, target: resolvedTarget, runtimeBaseURL: runtimeBaseURL, outputFormat: outputFormat)
        }
        if platform == .harmony {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func makeWebViewCurrentURLSummary(from list: TKWebViewListResponse, webViewID: String?) throws -> WebViewCurrentURLSummary {
    let selected = try TKSelectCurrentWebView(from: list.candidates, webViewID: webViewID)
    guard let url = selected.url, !url.isEmpty else {
        throw TKWebViewSelectionError(detail: TKWebViewError(
            code: .webViewProviderUnavailable,
            message: "Current WebView URL is unavailable because no WebView provider metadata is available.",
            hint: "Use an app DEBUG build with an opt-in WebView provider, or keep this smoke at the native route/layout boundary.",
            webViewID: selected.webViewID,
            candidates: list.candidates
        ))
    }
    return WebViewCurrentURLSummary(
        ok: true,
        action: "webview.current-url",
        platform: list.platform,
        capturedAt: list.capturedAt,
        target: list.target,
        webViewID: selected.webViewID,
        url: url,
        title: selected.title,
        pageSessionID: selected.pageSessionID,
        providerStatus: selected.providerStatus,
        bridgeStatus: selected.bridgeStatus,
        providerCapabilities: selected.providerCapabilities,
        sourceCommands: list.sourceCommands
    )
}

func makeRouteCurrentURLAssertion(
    expectedURL: String,
    current: WebViewCurrentURLSummary,
    ignoreQuery: Bool
) -> RouteCurrentURLAssertionSummary {
    let matched = routeURLsMatch(actual: current.url, expected: expectedURL, ignoreQuery: ignoreQuery)
    return RouteCurrentURLAssertionSummary(
        ok: matched,
        action: "route.assert-current-url",
        status: matched ? .pass : .fail,
        expectedURL: expectedURL,
        actualURL: current.url,
        matched: matched,
        ignoreQuery: ignoreQuery,
        platform: current.platform,
        target: current.target,
        webViewID: current.webViewID,
        title: current.title,
        pageSessionID: current.pageSessionID,
        hint: matched ? nil : "Run `triton webview current-url --json` to inspect the current provider URL."
    )
}

func routeURLsMatch(actual: String, expected: String, ignoreQuery: Bool) -> Bool {
    guard ignoreQuery else {
        return actual == expected
    }
    return normalizedRouteURL(actual, ignoreQuery: true) == normalizedRouteURL(expected, ignoreQuery: true)
}

private func normalizedRouteURL(_ value: String, ignoreQuery: Bool) -> String {
    guard ignoreQuery,
          var components = URLComponents(string: value) else {
        return value
    }
    components.query = nil
    components.percentEncodedQuery = nil
    return components.string ?? value
}

func runWebViewSnapshot(
    platform: ObservationPlatform,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    webViewID: String?,
    pageSessionID: String?,
    include: String,
    maxDOMNodes: Int?,
    maxTextBytes: Int?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let request = makeWebViewSnapshotRequest(
            webViewID: webViewID,
            pageSessionID: pageSessionID,
            include: include,
            maxDOMNodes: maxDOMNodes,
            maxTextBytes: maxTextBytes
        )
        let payload = try JSONEncoder().encode(request)
        let data: Data
        switch platform {
        case .ios:
            if let runtimeBaseURL {
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewSnapshot, body: payload)
            } else {
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                data = try await client.request(type: "webViewSnapshot", payload: payload)
            }
        case .android:
            try failHostValidation(
                code: "unsupported_capability",
                message: "Android WebView snapshot is not implemented yet.",
                hint: "Use Android host observe/screenshot evidence first; add a WebView provider before requesting DOM or bridge data.",
                outputFormat: outputFormat
            )
        case .harmony:
            guard let runtimeBaseURL else {
                throw RuntimeError("Harmony WebView snapshot requires --runtime-base-url from `triton device runtime-url --platform harmony --probe-manifest --json`.")
            }
            data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewSnapshot, body: payload)
        }
        switch try decodeWebViewSnapshotRuntimeResult(data) {
        case .snapshot(let response):
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("webViewID: \(response.webView.webViewID)")
                print("text: \(response.text.count)")
                print("dom: \(response.dom.count)")
                print("forms: \(response.forms.count)")
                print("links: \(response.links.count)")
                if response.truncation.truncated {
                    print("truncated: \(response.truncation.reason ?? "true")")
                }
            }
            if !response.ok {
                throw ExitCode.failure
            }
        case .error(let response):
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("\(response.error.code): \(response.error.message)")
            }
            throw ExitCode.failure
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony, runtimeBaseURL == nil {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

enum WebViewSnapshotRuntimeResult {
    case snapshot(TKWebViewSnapshotResponse)
    case error(TKWebViewErrorResponse)
}

func decodeWebViewSnapshotRuntimeResult(_ data: Data) throws -> WebViewSnapshotRuntimeResult {
    let decoder = JSONDecoder()
    if let response = try? decoder.decode(TKWebViewSnapshotResponse.self, from: data) {
        return .snapshot(response)
    }
    if let response = try? decoder.decode(TKWebViewErrorResponse.self, from: data) {
        return .error(response)
    }
    return .snapshot(try decoder.decode(TKWebViewSnapshotResponse.self, from: data))
}

func makeWebViewSnapshotRequest(
    webViewID: String?,
    pageSessionID: String?,
    include: String,
    maxDOMNodes: Int?,
    maxTextBytes: Int?
) -> TKWebViewSnapshotRequest {
    let includeItems = include
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return TKWebViewSnapshotRequest(
        webViewID: webViewID,
        pageSessionID: pageSessionID,
        include: includeItems.isEmpty ? ["metadata", "dom", "text", "forms", "links"] : includeItems,
        maxDOMNodes: maxDOMNodes,
        maxTextBytes: maxTextBytes
    )
}

func makeWebViewWaitRequest(
    text: String?,
    selector: String?,
    event: String?,
    webViewID: String?,
    pageSessionID: String?,
    timeoutSeconds: Double,
    intervalSeconds: Double
) throws -> TKWebViewWaitRequest {
    let candidates: [(TKWebViewWaitCondition, String)] = [
        (.text, text ?? ""),
        (.selector, selector ?? ""),
        (.event, event ?? ""),
    ].compactMap { condition, value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : (condition, trimmed)
    }

    guard candidates.count == 1, let selected = candidates.first else {
        throw RuntimeError("Pass exactly one of --text, --selector, or --event.")
    }
    guard timeoutSeconds > 0 else {
        throw RuntimeError("--timeout must be greater than 0 seconds.")
    }
    guard intervalSeconds > 0 else {
        throw RuntimeError("--interval must be greater than 0 seconds.")
    }

    return TKWebViewWaitRequest(
        webViewID: webViewID,
        pageSessionID: pageSessionID,
        condition: selected.0,
        query: selected.1,
        timeoutSeconds: timeoutSeconds,
        intervalSeconds: intervalSeconds,
        sourceCommand: "triton webview wait --\(selected.0.rawValue) \(selected.1)"
    )
}

func runWebViewWait(
    text: String?,
    selector: String?,
    event: String?,
    platform: ObservationPlatform,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    webViewID: String?,
    pageSessionID: String?,
    timeoutSeconds: Double,
    intervalSeconds: Double,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let request = try makeWebViewWaitRequest(
            text: text,
            selector: selector,
            event: event,
            webViewID: webViewID,
            pageSessionID: pageSessionID,
            timeoutSeconds: timeoutSeconds,
            intervalSeconds: intervalSeconds
        )
        let payload = try JSONEncoder().encode(request)
        let data: Data
        switch platform {
        case .ios:
            if let runtimeBaseURL {
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewWait, body: payload)
            } else {
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                data = try await client.request(type: "webViewWait", payload: payload)
            }
        case .android:
            try failHostValidation(
                code: "unsupported_capability",
                message: "Android WebView wait is not implemented yet.",
                hint: "Use Android host wait/observe once UIAutomator observe is available, or add a WebView provider before DOM waits.",
                outputFormat: outputFormat
            )
        case .harmony:
            guard let runtimeBaseURL else {
                throw RuntimeError("Harmony WebView wait requires --runtime-base-url from `triton device runtime-url --platform harmony --probe-manifest --json`.")
            }
            data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewWait, body: payload)
        }

        switch try decodeWebViewWaitRuntimeResult(data) {
        case .wait(let response):
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("matched: \(response.matched)")
                print("condition: \(response.condition)")
                print("query: \(response.query)")
                print("polls: \(response.pollCount)")
                if let match = response.match {
                    print("match: \(renderWebViewWaitMatch(match))")
                }
                if let error = response.error {
                    print("\(error.code.rawValue): \(error.message)")
                }
            }
            if !response.ok {
                throw ExitCode.failure
            }
        case .error(let response):
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("\(response.error.code): \(response.error.message)")
            }
            throw ExitCode.failure
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony, runtimeBaseURL == nil {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

enum WebViewWaitRuntimeResult {
    case wait(TKWebViewWaitResponse)
    case error(TKWebViewErrorResponse)
}

func decodeWebViewWaitRuntimeResult(_ data: Data) throws -> WebViewWaitRuntimeResult {
    let decoder = JSONDecoder()
    if let response = try? decoder.decode(TKWebViewWaitResponse.self, from: data) {
        return .wait(response)
    }
    if let response = try? decoder.decode(TKWebViewErrorResponse.self, from: data) {
        return .error(response)
    }
    return .wait(try decoder.decode(TKWebViewWaitResponse.self, from: data))
}

func runWebViewCall(
    method: String,
    args: [String],
    platform: ObservationPlatform,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    webViewID: String?,
    pageSessionID: String?,
    timeoutMs: Int?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let request = TKWebViewBridgeCallRequest(
            webViewID: webViewID,
            pageSessionID: pageSessionID,
            method: method,
            arguments: try parseWebViewBridgeArgs(args),
            timeoutMs: timeoutMs,
            sourceCommand: "triton webview call \(method)"
        )
        let payload = try JSONEncoder().encode(request)
        let data: Data
        switch platform {
        case .ios:
            if let runtimeBaseURL {
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewBridgeCall, body: payload)
            } else {
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                data = try await client.request(type: "webViewBridgeCall", payload: payload)
            }
        case .android:
            try failHostValidation(
                code: "unsupported_capability",
                message: "Android WebView bridge calls are not implemented yet.",
                hint: "Add an Android WebView provider before requesting DOM bridge calls.",
                outputFormat: outputFormat
            )
        case .harmony:
            guard let runtimeBaseURL else {
                throw RuntimeError("Harmony WebView bridge calls require --runtime-base-url from `triton device runtime-url --platform harmony --probe-manifest --json`.")
            }
            data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewBridgeCall, body: payload)
        }
        let response = try JSONDecoder().decode(TKWebViewBridgeCallResponse.self, from: data)
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            if response.ok {
                print("ok: true")
                print("method: \(response.method)")
                if let result = response.result { print("result: \(result)") }
            } else {
                print("\(response.error?.code.rawValue ?? "webview_bridge_call_failed"): \(response.error?.message ?? "Bridge call failed")")
            }
        }
        if !response.ok {
            throw ExitCode.failure
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony, runtimeBaseURL == nil {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func runWebViewEvents(
    platform: ObservationPlatform,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    limit: Int,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        let data: Data
        switch platform {
        case .ios:
            if let runtimeBaseURL {
                data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewEvents, queryItems: queryItems)
            } else {
                let payload = try JSONEncoder().encode(["limit": limit])
                let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
                data = try await client.request(type: "webViewEvents", payload: payload)
            }
        case .android:
            try failHostValidation(
                code: "unsupported_capability",
                message: "Android WebView events are not implemented yet.",
                hint: "Add an Android WebView provider before requesting WebView event history.",
                outputFormat: outputFormat
            )
        case .harmony:
            guard let runtimeBaseURL else {
                throw RuntimeError("Harmony WebView events require --runtime-base-url from `triton device runtime-url --platform harmony --probe-manifest --json`.")
            }
            data = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewEvents, queryItems: queryItems)
        }
        let response = try JSONDecoder().decode(TKWebViewEventsResponse.self, from: data)
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("events: \(response.events.count)")
            for event in response.events {
                print("\(event.timestamp) \(event.name) webViewID=\(event.webViewID)")
            }
        }
        if !response.ok {
            throw ExitCode.failure
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony, runtimeBaseURL == nil {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

private func webViewCandidates(
    action: String,
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    output: String?
) async throws -> TKWebViewListResponse {
    switch platform {
    case .ios:
        return try await iOSWebViewCandidates(action: action, target: target, host: host, port: port, runtimeBaseURL: runtimeBaseURL)
    case .android:
        throw RuntimeError("Android WebView candidates are not implemented yet.")
    case .harmony:
        return try harmonyWebViewCandidates(action: action, target: target, hdc: hdc, runtimeBaseURL: runtimeBaseURL, output: output)
    }
}

private func parseWebViewBridgeArgs(_ args: [String]) throws -> [String: TKJSONValue] {
    var parsed: [String: TKJSONValue] = [:]
    for arg in args {
        guard let separator = arg.firstIndex(of: "="), separator > arg.startIndex else {
            throw RuntimeError("Invalid --arg \(arg). Expected key=value.")
        }
        let key = String(arg[..<separator])
        let value = String(arg[arg.index(after: separator)...])
        parsed[key] = parseWebViewBridgeArgValue(value)
    }
    return parsed
}

private func parseWebViewBridgeArgValue(_ value: String) -> TKJSONValue {
    if value == "true" { return .bool(true) }
    if value == "false" { return .bool(false) }
    if value == "null" { return .null }
    if let intValue = Int(value) { return .int(intValue) }
    if let doubleValue = Double(value) { return .double(doubleValue) }
    return .string(value)
}

private func iOSWebViewCandidates(action: String, target: String, host: String, port: Int, runtimeBaseURL: String?) async throws -> TKWebViewListResponse {
    let snapshotData: Data
    let targetID: String
    let sourceCommands: [String]
    if let runtimeBaseURL {
        if let provider = try? await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.webViewList),
           let response = try? JSONDecoder().decode(TKWebViewListResponse.self, from: provider) {
            return normalizeProviderWebViewList(response, action: action, target: runtimeBaseURL)
        }
        snapshotData = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeSnapshot, queryItems: [URLQueryItem(name: "include", value: "ax")])
        targetID = runtimeBaseURL
        sourceCommands = ["GET \(runtimeBaseURL)/snapshot"]
    } else {
        let (summary, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
        targetID = summary.id
        if let provider = try? await client.request(type: "webViewList"),
           let response = try? JSONDecoder().decode(TKWebViewListResponse.self, from: provider) {
            return normalizeProviderWebViewList(response, action: action, target: targetID)
        }
        let payload = try JSONEncoder().encode(TKRuntimeSnapshotRequest(include: ["ax"]))
        snapshotData = try await client.request(type: "runtimeSnapshot", payload: payload)
        sourceCommands = ["triton runtimeSnapshot request"]
    }
    let snapshot = try JSONDecoder().decode(TKRuntimeSnapshotResponse.self, from: snapshotData)
    let candidates = webViewDescriptors(fromAX: snapshot.ax ?? [], platform: "ios")
    return TKWebViewListResponse(
        ok: true,
        action: action,
        platform: "ios",
        capturedAt: snapshot.capturedAt,
        target: targetID,
        current: try? TKSelectCurrentWebView(from: candidates, webViewID: nil),
        candidates: candidates,
        sources: [
            TKWebViewSource(name: "runtime-tree", available: true, sourceCommands: sourceCommands),
            TKWebViewSource(name: "webview-provider", available: false, reason: "provider not registered"),
        ],
        sourceCommands: sourceCommands,
        note: "iOS WebView candidates come from DEBUG runtime AX. URL, DOM, JavaScript, bridge calls, and DOM input require a WebView provider."
    )
}

private func normalizeProviderWebViewList(_ response: TKWebViewListResponse, action: String, target: String) -> TKWebViewListResponse {
    TKWebViewListResponse(
        ok: response.ok,
        action: action,
        platform: response.platform,
        capturedAt: response.capturedAt,
        target: target,
        current: try? TKSelectCurrentWebView(from: response.candidates),
        candidates: response.candidates,
        sources: response.sources,
        sourceCommands: response.sourceCommands,
        note: response.note
    )
}

private func harmonyWebViewCandidates(action: String, target: String, hdc: String, runtimeBaseURL: String?, output: String?) throws -> TKWebViewListResponse {
    let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
    let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: output)
    let candidates = webViewDescriptors(fromHarmony: try TKHarmonyLayoutParser.nodeSummaries(in: layout.data))
    return TKWebViewListResponse(
        ok: true,
        action: action,
        platform: "harmony",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        target: selected.target,
        current: try? TKSelectCurrentWebView(from: candidates, webViewID: nil),
        candidates: candidates,
        sources: [
            TKWebViewSource(name: "host-layout", available: true, sourceCommands: layout.sourceCommands),
            TKWebViewSource(name: "runtime-tree", available: runtimeBaseURL != nil, reason: runtimeBaseURL == nil ? "runtime-base-url not provided" : "runtime fusion not implemented for webview command", sourceCommands: runtimeBaseURL.map { ["GET \($0)/snapshot"] } ?? []),
            TKWebViewSource(name: "webview-provider", available: false, reason: "provider not registered"),
        ],
        sourceCommands: layout.sourceCommands,
        note: "Harmony host layout can expose visible Web candidates only. DOM, URL, JavaScript, and bridge calls require an embedded WebView provider."
    )
}

private func webViewDescriptors(fromAX nodes: [TKAXNode], platform: String) -> [TKWebViewDescriptor] {
    TKFlattenAXNodes(nodes).compactMap { flattened in
        let node = flattened.node
        guard !node.hidden else { return nil }
        guard let score = webViewCandidateScore(role: node.role, className: node.className, identifier: node.identifier, text: node.label ?? node.title ?? node.value) else {
            return nil
        }
        let nodeID = "ios-runtime:\(node.targetOID ?? node.viewOID ?? UInt(flattened.depth + 1))"
        return TKWebViewDescriptor(
            webViewID: nodeID,
            platform: platform,
            source: "runtime-tree",
            nodeID: nodeID,
            role: node.role,
            text: node.label ?? node.title ?? node.value,
            identifier: node.identifier,
            frame: node.frame,
            visibleRatio: 1,
            confidence: score,
            capabilities: ["visible"] + ((node.targetOID != nil || node.viewOID != nil) ? ["runtime-oid"] : []),
            missingCapabilities: ["webview.url", "webview.dom", "webview.bridge-call", "webview.tap", "webview.type"]
        )
    }
    .sorted(by: webViewDescriptorSort)
}

private func webViewDescriptors(fromHarmony nodes: [TKHarmonyLayoutNodeSummary]) -> [TKWebViewDescriptor] {
    nodes.compactMap { node in
        guard node.visible != false else { return nil }
        guard let score = webViewCandidateScore(role: node.type, className: nil, identifier: node.identifier ?? node.key ?? node.accessibilityID, text: node.text ?? node.originalText) else {
            return nil
        }
        let webViewID = "harmony:host:\(node.nodeID)"
        var capabilities = ["visible"]
        if node.bounds != nil { capabilities.append("host-coordinate-tap") }
        if node.scrollable == true { capabilities.append("host-scroll") }
        return TKWebViewDescriptor(
            webViewID: webViewID,
            platform: "harmony",
            source: "host-layout",
            nodeID: webViewID,
            role: node.type,
            text: node.text ?? node.originalText,
            identifier: node.identifier ?? node.key ?? node.accessibilityID,
            frame: node.bounds,
            visibleRatio: node.visible == false ? 0 : 1,
            confidence: score,
            capabilities: capabilities,
            missingCapabilities: ["webview.url", "webview.dom", "webview.bridge-call", "semantic-action"]
        )
    }
    .sorted(by: webViewDescriptorSort)
}

func webViewCandidateScore(role: String?, className: String?, identifier: String?, text: String?) -> Double? {
    let roleValue = role?.lowercased() ?? ""
    let classValue = className?.lowercased() ?? ""
    let identifierValue = identifier?.lowercased() ?? ""
    let textValue = text?.lowercased() ?? ""
    if classValue.contains("wkwebview") { return 0.94 }
    if classValue.contains("wkcontentview") || roleValue.contains("wkcontentview") { return 0.84 }
    if classValue.contains("wkscrollview") || roleValue.contains("wkscrollview") { return 0.8 }
    if roleValue == "web" || roleValue == "webview" || roleValue.contains("webview") || roleValue.contains("web") { return 0.76 }
    if identifierValue.contains("webview") && (roleValue.contains("scroll") || roleValue.contains("view")) { return 0.72 }
    if textValue.contains("webview") && (roleValue.contains("scroll") || roleValue.contains("view")) { return 0.68 }
    return nil
}

private func webViewDescriptorSort(_ lhs: TKWebViewDescriptor, _ rhs: TKWebViewDescriptor) -> Bool {
    TKWebViewDescriptorSort(lhs, rhs)
}

private func renderWebViewCandidate(_ candidate: TKWebViewDescriptor) -> String {
    let frame = candidate.frame.map { " frame=\(formatRect($0))" } ?? ""
    let identifier = candidate.identifier.map { " identifier=\($0)" } ?? ""
    let text = candidate.text.map { " text=\"\($0)\"" } ?? ""
    return "\(candidate.webViewID) source=\(candidate.source) candidateOnly=\(candidate.candidateOnly) confidence=\(candidate.confidence)\(identifier)\(text)\(frame)"
}

private func renderWebViewWaitMatch(_ match: TKWebViewWaitMatch) -> String {
    if let text = match.text {
        return "text=\"\(text)\" source=\(match.source)"
    }
    if let selector = match.selector {
        let node = match.nodeID.map { " nodeID=\($0)" } ?? ""
        return "selector=\(selector)\(node) source=\(match.source)"
    }
    if let event = match.event {
        return "event=\(event) source=\(match.source)"
    }
    return "source=\(match.source)"
}

private func failWebViewCommand(
    _ error: TKWebViewSelectionError,
    action: String,
    platform: ObservationPlatform,
    target: String,
    runtimeBaseURL: String?,
    outputFormat: ClientOutputFormat
) throws -> Never {
    let nextArgs: [String]
    if let runtimeBaseURL {
        nextArgs = ["list", "--platform", platform.rawValue, "--runtime-base-url", runtimeBaseURL, "--json"]
    } else {
        nextArgs = ["list", "--platform", platform.rawValue, "--target", target, "--json"]
    }
    let detail = TKCLIErrorDetail(
        code: error.detail.code.rawValue,
        message: error.detail.message,
        hint: error.detail.hint,
        nextAction: TKCLINextAction(command: "webview", args: nextArgs)
    )
    switch outputFormat {
    case .json:
        print(try encodeJSON(TKWebViewErrorResponse(
            action: action,
            platform: platform.rawValue,
            target: target,
            error: detail,
            candidates: error.detail.candidates
        )))
    case .text:
        print("\(detail.code): \(detail.message)")
        if let hint = detail.hint { print("hint: \(hint)") }
    }
    throw ExitCode.failure
}
