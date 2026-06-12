import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct TritonKitHTTPClient {
    let host: String
    let port: Int
    var target: String? = nil

    func getData(_ path: String) async throws -> Data {
        try await data(for: URLRequest(url: url(path)))
    }

    func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let data = try await getData(path)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func latestHierarchyData() async throws -> Data {
        try await data(for: URLRequest(url: url(path: "/hierarchy/latest", queryItems: targetQueryItems())))
    }

    func postJSON<Request: Encodable, Response: Decodable>(_ path: String, body: Request) async throws -> Response {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func sendCommand(_ type: String) async throws {
        let _: TKCLICommandResponse = try await postJSON("/command", body: TKCLICommandRequest(type: type, target: target))
    }

    func request(type: String, payload: Data? = nil, target explicitTarget: String? = nil) async throws -> Data {
        try await postRawJSON("/request", body: TKCLICommandRequest(
            type: type,
            payload: payload,
            target: explicitTarget ?? target
        ))
    }

    private func url(_ path: String) -> URL {
        url(path: path, queryItems: [])
    }

    private func url(path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url!
    }

    private func targetQueryItems() -> [URLQueryItem] {
        target.map { [URLQueryItem(name: "target", value: $0)] } ?? []
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CLIHTTPError(statusCode: http.statusCode, data: data)
        }
        return data
    }

    private func postRawJSON<Request: Encodable>(_ path: String, body: Request) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await data(for: request)
    }
}

struct EmbeddedRuntimeHTTPClient {
    let baseURL: URL

    init(baseURL: String) throws {
        guard let url = URL(string: baseURL), url.scheme != nil, url.host != nil else {
            throw RuntimeError("Invalid embedded runtime base URL: \(baseURL)")
        }
        self.baseURL = url
    }

    func request(_ requestType: TKRequestType, queryItems: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        guard let route = TKEmbeddedRuntimeHTTPRoute.route(for: requestType) else {
            throw RuntimeError("Unsupported embedded runtime HTTP request: \(requestType.rawValue)")
        }

        var request = URLRequest(url: try url(path: route.path, queryItems: queryItems))
        request.httpMethod = route.method.rawValue
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return try await data(for: request)
    }

    private func url(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard let routeURL = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              var components = URLComponents(url: routeURL, resolvingAgainstBaseURL: false) else {
            throw RuntimeError("Invalid embedded runtime route: \(path)")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw RuntimeError("Invalid embedded runtime URL: \(path)")
        }
        return url
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CLIHTTPError(statusCode: http.statusCode, data: data)
        }
        return data
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

struct CLIHTTPError: Error, CustomStringConvertible {
    let statusCode: Int
    let data: Data
    let response: TKCLIErrorResponse?

    init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
        self.response = try? JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
    }

    var description: String {
        if let response {
            return "HTTP \(statusCode) \(response.error.code): \(response.error.message)"
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return "HTTP \(statusCode) \(body)"
    }
}

struct RuntimeRequestTimeoutError: Error, CustomStringConvertible {
    let requestType: String

    var description: String {
        "Timed out waiting for \(requestType) response"
    }
}

func resolveTarget(_ target: String, host: String, port: Int) async throws -> TKTargetSummary {
    let client = TritonKitHTTPClient(host: host, port: port)
    let response: TKTargetsResponse = try await client.getJSON("/targets")
    return try TKResolveTargetSummary(target, in: response.targets)
}

func resolveTarget(
    _ target: String,
    host: String,
    port: Int,
    jsonError: Bool
) async throws -> TKTargetSummary {
    do {
        return try await resolveTarget(target, host: host, port: port)
    } catch {
        if jsonError {
            try printCLIError(error, endpoint: "/targets", host: host, port: port)
            throw ExitCode.failure
        }
        printCLIErrorText(error, endpoint: "/targets", host: host, port: port, language: effectiveLanguage(nil))
        throw ExitCode.failure
    }
}

func resolveRuntimeClient(
    target: String,
    host: String,
    port: Int,
    jsonError: Bool
) async throws -> (summary: TKTargetSummary, client: TritonKitHTTPClient) {
    let summary = try await resolveTarget(target, host: host, port: port, jsonError: jsonError)
    return (summary, TritonKitHTTPClient(host: host, port: port, target: summary.id))
}

func buildCapabilities(host: String, port: Int) async -> TKCapabilitiesResponse {
    let client = TritonKitHTTPClient(host: host, port: port)
    do {
        let status: TKStatusResponse = try await client.getJSON("/status")
        return TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: status.connected,
            latestHierarchyAvailable: status.latestHierarchyAvailable,
            targetCount: status.targetCount,
            runtime: status.connected ? "embedded" : "none",
            capabilities: runtimeCapabilities(host: host, port: port, serverReachable: true, connected: status.connected),
            activeHierarchyAvailable: status.activeHierarchyAvailable,
            hierarchyCacheState: status.hierarchyCacheState,
            targetConnectionState: status.targetConnectionState
        )
    } catch {
        let detail = cliErrorDetail(for: error, endpoint: "/status", host: host, port: port)
        return TKCapabilitiesResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "unknown",
            capabilities: runtimeCapabilities(host: host, port: port, serverReachable: false, connected: false),
            error: detail
        )
    }
}

func runtimeCapabilities(host: String, port: Int, serverReachable: Bool, connected: Bool) -> [TKRuntimeCapability] {
    let requiresRuntime = connected ? nil : "Requires connected embedded TritonKit runtime"
    let requiresWebViewProvider = connected ? nil : "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
    let capabilities: [TKRuntimeCapability] = [
        TKRuntimeCapability(name: "version", supported: true),
        TKRuntimeCapability(name: "plan", supported: true),
        TKRuntimeCapability(name: "plan-inspect", supported: true),
        TKRuntimeCapability(name: "record", supported: true),
        TKRuntimeCapability(name: "replay-dry-run", supported: true),
        TKRuntimeCapability(name: "schema", supported: true),
        TKRuntimeCapability(name: "status", supported: true),
        TKRuntimeCapability(name: "doctor", supported: true),
        TKRuntimeCapability(name: "capabilities", supported: true),
        TKRuntimeCapability(name: "target-list", supported: true),
        TKRuntimeCapability(name: "target-use", supported: true),
        TKRuntimeCapability(name: "target-current", supported: true),
        TKRuntimeCapability(name: "target-resolve", supported: true),
        TKRuntimeCapability(name: "target-wait-ready", supported: true),
        TKRuntimeCapability(name: "runtime-manifest", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-app", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-scene", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-route", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-responder", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "snapshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "media-playback", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "app-semantic-state", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "app-semantic-action", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "focus", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "set-text", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "select-segment", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "set-switch", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "semantic-action", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ledger", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "host-device", supported: true),
        TKRuntimeCapability(name: "host-device-selector", supported: true),
        TKRuntimeCapability(name: "device-alias", supported: true),
        TKRuntimeCapability(name: "device-list", supported: true),
        TKRuntimeCapability(name: "device-use", supported: true),
        TKRuntimeCapability(name: "device-current", supported: true),
        TKRuntimeCapability(name: "device-resolve", supported: true),
        TKRuntimeCapability(name: "device-wait-ready", supported: true),
        TKRuntimeCapability(name: "device-screenshot", supported: true),
        TKRuntimeCapability(name: "host-device-screenshot", supported: true),
        TKRuntimeCapability(name: "ios-device", supported: true),
        TKRuntimeCapability(name: "ios-device-list", supported: true),
        TKRuntimeCapability(name: "ios-device-use", supported: true),
        TKRuntimeCapability(name: "ios-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "ios-device-screenshot", supported: true),
        TKRuntimeCapability(name: "ios-screenshot", supported: true),
        TKRuntimeCapability(name: "android-device", supported: true),
        TKRuntimeCapability(name: "android-device-doctor", supported: true),
        TKRuntimeCapability(name: "android-device-list", supported: true),
        TKRuntimeCapability(name: "android-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "android-device-screenshot", supported: true),
        TKRuntimeCapability(name: "harmony-device", supported: true),
        TKRuntimeCapability(name: "harmony-device-doctor", supported: true),
        TKRuntimeCapability(name: "harmony-device-list", supported: true),
        TKRuntimeCapability(name: "harmony-device-use", supported: true),
        TKRuntimeCapability(name: "harmony-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "harmony-device-screenshot", supported: true),
        TKRuntimeCapability(name: "harmony-device-stop", supported: true),
        TKRuntimeCapability(name: "harmony-runtime-url", supported: true),
        TKRuntimeCapability(name: "harmony-app-install", supported: true),
        TKRuntimeCapability(name: "harmony-app-open-url", supported: true),
        TKRuntimeCapability(name: "harmony-ax", supported: true),
        TKRuntimeCapability(name: "harmony-wait-text", supported: true),
        TKRuntimeCapability(name: "harmony-tap-text", supported: true),
        TKRuntimeCapability(name: "harmony-swipe", supported: true),
        TKRuntimeCapability(name: "harmony-type-text", supported: true),
        TKRuntimeCapability(name: "harmony-paste-text", supported: true),
        TKRuntimeCapability(name: "harmony-clear-text", supported: false, reason: "Host-side Harmony clear is not available in the current adapter"),
        TKRuntimeCapability(name: "harmony-press-key", supported: true),
        TKRuntimeCapability(name: "harmony-screenshot", supported: true),
        TKRuntimeCapability(name: "host-simulator", supported: true),
        TKRuntimeCapability(name: "sim-video", supported: true),
        TKRuntimeCapability(name: "sim-logs", supported: true),
        TKRuntimeCapability(name: "sim-diagnostics", supported: true),
        TKRuntimeCapability(name: "sim-runtime", supported: true),
        TKRuntimeCapability(name: "sim-runtime-maintenance", supported: true),
        TKRuntimeCapability(name: "sim-device-maintenance", supported: true),
        TKRuntimeCapability(name: "sim-personalization", supported: true),
        TKRuntimeCapability(name: "sim-status-bar", supported: true),
        TKRuntimeCapability(name: "sim-privacy", supported: true),
        TKRuntimeCapability(name: "sim-location", supported: true),
        TKRuntimeCapability(name: "sim-ui", supported: true),
        TKRuntimeCapability(name: "sim-pasteboard", supported: true),
        TKRuntimeCapability(name: "sim-push", supported: true),
        TKRuntimeCapability(name: "ios-simulator-host-tap", supported: false, reason: "Host-side iOS Simulator input is not available in the current adapter"),
        TKRuntimeCapability(name: "ios-simulator-host-type", supported: false, reason: "Host-side iOS Simulator input is not available in the current adapter"),
        TKRuntimeCapability(name: "host-app", supported: true),
        TKRuntimeCapability(name: "host-app-open-url-ready", supported: true),
        TKRuntimeCapability(name: "host-app-open-url-snapshot", supported: true),
        TKRuntimeCapability(name: "host-preferences", supported: true),
        TKRuntimeCapability(name: "android-app", supported: true),
        TKRuntimeCapability(name: "android-app-inspect", supported: true),
        TKRuntimeCapability(name: "android-app-install", supported: true),
        TKRuntimeCapability(name: "android-app-launch", supported: true),
        TKRuntimeCapability(name: "android-app-terminate", supported: true),
        TKRuntimeCapability(name: "android-app-open-url", supported: true),
        TKRuntimeCapability(name: "android-ax", supported: true),
        TKRuntimeCapability(name: "harmony-app", supported: true),
        TKRuntimeCapability(name: "xcode-discovery", supported: true),
        TKRuntimeCapability(name: "xcode-defaults", supported: true),
        TKRuntimeCapability(name: "xcode-diagnostics", supported: true),
        TKRuntimeCapability(name: "xcodebuild", supported: true),
        TKRuntimeCapability(name: "xcode-build", supported: true),
        TKRuntimeCapability(name: "xcode-test", supported: true),
        TKRuntimeCapability(name: "xcode-run", supported: true),
        TKRuntimeCapability(name: "xcresult-summary", supported: true),
        TKRuntimeCapability(name: "xcresult-failures", supported: true),
        TKRuntimeCapability(name: "xctrace-record", supported: true),
        TKRuntimeCapability(name: "coverage-report", supported: true),
        TKRuntimeCapability(name: "observe", supported: true),
        TKRuntimeCapability(name: "observe-ios", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "observe-android", supported: true),
        TKRuntimeCapability(name: "observe-harmony", supported: true),
        TKRuntimeCapability(name: "android-wait-text", supported: true),
        TKRuntimeCapability(name: "android-tap-text", supported: true),
        TKRuntimeCapability(name: "android-swipe", supported: true),
        TKRuntimeCapability(name: "android-type-text", supported: true),
        TKRuntimeCapability(name: "android-paste-text", supported: true),
        TKRuntimeCapability(name: "android-press-key", supported: true),
        TKRuntimeCapability(name: "webview-list", supported: true),
        TKRuntimeCapability(name: "webview-current", supported: true),
        TKRuntimeCapability(name: "webview-current-url", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-snapshot", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-bridge-call", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-events", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-wait", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "route-current-url-assert", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "node-resolve", supported: true),
        TKRuntimeCapability(name: "list", supported: true),
        TKRuntimeCapability(name: "inspect", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hierarchy", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "nodes", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "node", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "attrs", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "object", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-json", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-archive", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "geometry", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ax", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hit", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "screenshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "wait", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "capture", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "assert", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "replay", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "evidence", supported: true),
        TKRuntimeCapability(name: "evidence-summary", supported: true),
        TKRuntimeCapability(name: "evidence-redact", supported: true),
        TKRuntimeCapability(name: "smoke-ios", supported: true),
        TKRuntimeCapability(name: "smoke-android", supported: true),
        TKRuntimeCapability(name: "smoke-harmony", supported: true),
        TKRuntimeCapability(name: "tap", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "swipe", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "type", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "paste", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "clear", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "input", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "press", supported: false, reason: "Host-side HID is not available in the embedded runtime"),
    ]
    return capabilities.map { capability in
        enrichRuntimeCapability(capability, host: host, port: port, serverReachable: serverReachable, connected: connected)
    }
}

func enrichRuntimeCapability(
    _ capability: TKRuntimeCapability,
    host: String,
    port: Int,
    serverReachable: Bool,
    connected: Bool
) -> TKRuntimeCapability {
    TKRuntimeCapability(
        name: capability.name,
        supported: capability.supported,
        reason: capability.reason,
        group: capability.group ?? runtimeCapabilityGroup(for: capability.name),
        requiredBy: capability.requiredBy.isEmpty ? runtimeCapabilityRequiredBy(for: capability.name) : capability.requiredBy,
        nextAction: capability.nextAction ?? runtimeCapabilityNextAction(for: capability.name, host: host, port: port, serverReachable: serverReachable, connected: connected),
        evidence: capability.evidence.isEmpty ? runtimeCapabilityEvidence(for: capability.name) : capability.evidence
    )
}

func runtimeCapabilityGroup(for name: String) -> String {
    switch name {
    case "version", "plan", "record", "replay-dry-run", "schema", "status", "doctor", "capabilities":
        return "bootstrap"
    case "target-list", "target-use", "target-current", "target-resolve", "target-wait-ready":
        return "target"
    case "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "focus", "set-text", "select-segment", "set-switch", "semantic-action", "ledger":
        return "runtime"
    case "app-semantic-state", "app-semantic-action":
        return "semantic"
    case "xcode-discovery", "xcode-defaults", "xcode-diagnostics", "xcodebuild", "xcode-build", "xcode-test", "xcode-run", "xcresult-summary", "xcresult-failures", "xctrace-record", "coverage-report":
        return "xcode"
    case "host-device", "host-device-selector", "device-alias", "device-list", "device-use", "device-current", "device-resolve", "device-wait-ready", "device-screenshot", "host-device-screenshot", "ios-device", "ios-device-list", "ios-device-use", "ios-device-wait-ready", "ios-device-screenshot", "ios-screenshot", "android-device", "android-device-doctor", "android-device-list", "android-device-wait-ready", "android-device-screenshot", "harmony-device", "harmony-device-doctor", "harmony-device-list", "harmony-device-use", "harmony-device-wait-ready", "harmony-device-screenshot", "harmony-device-stop", "harmony-runtime-url", "harmony-app-install", "harmony-app-open-url", "harmony-ax", "harmony-screenshot", "host-simulator", "sim-video", "sim-logs", "sim-diagnostics", "sim-runtime", "sim-runtime-maintenance", "sim-device-maintenance", "sim-personalization", "sim-status-bar", "sim-privacy", "sim-location", "sim-ui", "sim-pasteboard", "sim-push", "ios-simulator-host-tap", "ios-simulator-host-type", "host-app", "host-app-open-url-ready", "host-app-open-url-snapshot", "host-preferences", "android-app", "android-app-inspect", "android-app-install", "android-app-launch", "android-app-terminate", "android-app-open-url", "harmony-app":
        return "host"
    case "media-playback", "observe", "observe-ios", "observe-android", "observe-harmony", "android-ax", "node-resolve", "list", "inspect", "hierarchy", "nodes", "node", "attrs", "object", "export-json", "export-archive", "geometry", "ax", "hit", "screenshot", "wait":
        return "observe"
    case "webview-list", "webview-current", "webview-current-url", "webview-snapshot", "webview-bridge-call", "webview-events", "webview-wait":
        return "webview"
    case "route-current-url-assert":
        return "route"
    case "capture", "evidence", "evidence-summary", "evidence-redact":
        return "evidence"
    case "smoke-ios", "smoke-android", "smoke-harmony":
        return "smoke"
    case "assert":
        return "assert"
    case "plan-inspect", "replay":
        return "replay"
    case "tap", "swipe", "type", "paste", "clear", "input", "press", "android-tap-text", "android-wait-text", "android-swipe", "android-type-text", "android-paste-text", "android-press-key", "harmony-tap-text", "harmony-wait-text", "harmony-swipe", "harmony-type-text", "harmony-paste-text", "harmony-press-key", "harmony-clear-text":
        return "action"
    default:
        return "misc"
    }
}

func runtimeCapabilityRequiredBy(for name: String) -> [String] {
    switch name {
    case "target-list", "target-use", "target-current", "target-resolve", "target-wait-ready":
        return ["app", "runtime", "observe", "action", "assert", "evidence", "smoke"]
    case "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "focus", "set-text", "select-segment", "set-switch", "semantic-action", "ledger":
        return ["app", "observe", "action", "assert", "evidence"]
    case "app-semantic-state":
        return ["observe", "assert", "evidence"]
    case "app-semantic-action":
        return ["action", "assert", "evidence"]
    case "xcode-discovery", "xcode-defaults", "xcode-diagnostics", "xcodebuild", "xcode-build", "xcode-test", "xcode-run", "xcresult-summary", "xcresult-failures", "xctrace-record", "coverage-report":
        return ["project", "xcode", "evidence"]
    case "host-device", "host-device-selector", "device-alias", "device-list", "device-use", "device-current", "device-resolve", "device-wait-ready", "device-screenshot", "host-device-screenshot", "ios-device", "ios-device-list", "ios-device-use", "ios-device-wait-ready", "ios-device-screenshot", "ios-screenshot", "android-device", "android-device-doctor", "android-device-list", "android-device-wait-ready", "android-device-screenshot", "harmony-device", "harmony-device-doctor", "harmony-device-list", "harmony-device-use", "harmony-device-wait-ready", "harmony-device-screenshot", "harmony-device-stop", "harmony-runtime-url", "harmony-app-install", "harmony-app-open-url", "harmony-ax", "harmony-screenshot", "host-simulator", "sim-video", "sim-logs", "sim-diagnostics", "sim-runtime", "sim-runtime-maintenance", "sim-device-maintenance", "sim-personalization", "sim-status-bar", "sim-privacy", "sim-location", "sim-ui", "sim-pasteboard", "sim-push", "host-app", "host-app-open-url-ready", "host-app-open-url-snapshot", "host-preferences", "android-app", "android-app-inspect", "android-app-install", "android-app-launch", "android-app-terminate", "android-app-open-url", "harmony-app":
        return ["target", "app", "smoke", "evidence"]
    case "observe", "observe-ios", "observe-android", "observe-harmony", "android-ax", "node-resolve", "list", "inspect", "hierarchy", "nodes", "node", "attrs", "object", "export-json", "export-archive", "geometry", "ax", "hit", "screenshot", "wait":
        return ["action", "assert", "evidence"]
    case "media-playback":
        return ["assert", "evidence", "observe"]
    case "webview-list", "webview-current":
        return ["observe", "route", "assert", "evidence"]
    case "webview-current-url", "webview-snapshot", "webview-bridge-call", "webview-events", "webview-wait":
        return ["route", "assert", "evidence", "webview-check"]
    case "route-current-url-assert":
        return ["assert", "smoke", "evidence", "webview-check"]
    case "capture", "evidence", "evidence-summary", "evidence-redact":
        return ["evidence", "replay"]
    case "plan-inspect":
        return ["replay"]
    case "smoke-ios", "smoke-android", "smoke-harmony":
        return ["smoke", "evidence", "replay"]
    case "ios-simulator-host-tap", "ios-simulator-host-type":
        return ["action", "assert", "evidence", "smoke"]
    case "tap", "swipe", "type", "paste", "clear", "input", "press", "android-tap-text", "android-wait-text", "android-swipe", "android-type-text", "android-paste-text", "android-press-key", "harmony-tap-text", "harmony-wait-text", "harmony-swipe", "harmony-type-text", "harmony-paste-text", "harmony-press-key", "harmony-clear-text":
        return ["action", "assert", "evidence"]
    default:
        return []
    }
}

func runtimeCapabilityNextAction(
    for name: String,
    host: String,
    port: Int,
    serverReachable: Bool,
    connected: Bool
) -> TKCLINextAction? {
    if !serverReachable, runtimeCapabilityRequiresServer(name) {
        return TKCLINextAction(command: "serve", args: ["--host", host, "--port", String(port)], requiresLongRunningProcess: true)
    }
    if !connected, ["runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "media-playback", "app-semantic-state", "app-semantic-action", "focus", "set-text", "select-segment", "set-switch", "ledger", "inspect", "hierarchy", "nodes", "node", "attrs", "object", "export-json", "export-archive", "geometry", "ax", "hit", "screenshot", "wait", "capture", "assert", "replay", "tap", "swipe", "type", "paste", "clear", "input"].contains(name) {
        return TKCLINextAction(command: "status", args: ["--json"])
    }
    switch name {
    case "plan":
        return TKCLINextAction(command: "plan", args: ["--format", "json"])
    case "record":
        return TKCLINextAction(command: "record", args: ["--output", "<file.tritonplan>", "--json"])
    case "replay-dry-run":
        return TKCLINextAction(command: "replay", args: ["<file.tritonplan>", "--dry-run", "--json"])
    case "plan-inspect":
        return TKCLINextAction(command: "plan", args: ["inspect", "<file.tritonplan>", "--json"])
    case "target-list":
        return TKCLINextAction(command: "target", args: ["list", "--json"])
    case "target-use":
        return TKCLINextAction(command: "target", args: ["use", "<selector>", "--json"])
    case "target-current":
        return TKCLINextAction(command: "target", args: ["current", "--json"])
    case "target-resolve":
        return TKCLINextAction(command: "target", args: ["resolve", "<selector>", "--json"])
    case "target-wait-ready":
        return TKCLINextAction(command: "target", args: ["wait-ready", "<selector>", "--json"])
    case "host-device", "host-device-selector", "device-list", "device-resolve":
        return TKCLINextAction(command: "device", args: ["list", "--json"])
    case "device-alias":
        return TKCLINextAction(command: "device", args: ["alias", "list", "--json"])
    case "device-use", "device-current":
        return TKCLINextAction(command: "device", args: ["use", "<selector>", "--json"])
    case "device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--json"])
    case "device-screenshot", "host-device-screenshot", "ios-screenshot", "harmony-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--device", "<selector>", "--output", "<path>", "--json"])
    case "ios-device", "ios-device-list":
        return TKCLINextAction(command: "device", args: ["list", "--platform", "ios", "--json"])
    case "ios-device-use":
        return TKCLINextAction(command: "device", args: ["use", "<selector>", "--platform", "ios", "--json"])
    case "ios-device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--platform", "ios", "--json"])
    case "ios-device-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--platform", "ios", "--device", "<selector>", "--output", "<path>", "--json"])
    case "ios-simulator-host-tap":
        return TKCLINextAction(command: "sim", args: ["tap", "--simulator", "<udid|booted>", "--x", "<x>", "--y", "<y>", "--json"])
    case "ios-simulator-host-type":
        return TKCLINextAction(command: "sim", args: ["type", "--simulator", "<udid|booted>", "--text", "<text>", "--json"])
    case "android-device", "android-device-list":
        return TKCLINextAction(command: "device", args: ["list", "--platform", "android", "--json"])
    case "android-device-doctor":
        return TKCLINextAction(command: "device", args: ["doctor", "--platform", "android", "--json"])
    case "android-device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--platform", "android", "--json"])
    case "android-device-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--platform", "android", "--device", "<selector>", "--output", "<path>", "--json"])
    case "harmony-device", "harmony-device-list":
        return TKCLINextAction(command: "device", args: ["list", "--platform", "harmony", "--json"])
    case "harmony-device-doctor":
        return TKCLINextAction(command: "device", args: ["doctor", "--platform", "harmony", "--json"])
    case "harmony-device-use":
        return TKCLINextAction(command: "device", args: ["use", "<selector>", "--platform", "harmony", "--json"])
    case "harmony-device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--platform", "harmony", "--json"])
    case "harmony-device-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--platform", "harmony", "--device", "<selector>", "--output", "<path>", "--json"])
    case "harmony-device-stop":
        return TKCLINextAction(command: "device", args: ["stop", "--platform", "harmony", "--device", "<selector>", "--confirm", "--json"])
    case "harmony-runtime-url":
        return TKCLINextAction(command: "device", args: ["runtime-url", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "android-app", "android-app-install":
        return TKCLINextAction(command: "app", args: ["install", "--platform", "android", "--device", "<selector>", "--apk", "<path.apk>", "--json"])
    case "android-app-inspect":
        return TKCLINextAction(command: "app", args: ["inspect", "--platform", "android", "--device", "<selector>", "--bundle", "<package>", "--json"])
    case "android-app-launch":
        return TKCLINextAction(command: "app", args: ["launch", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "android-app-terminate":
        return TKCLINextAction(command: "app", args: ["terminate", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "android-app-open-url":
        return TKCLINextAction(command: "app", args: ["open-url", "<url>", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "android-ax":
        return TKCLINextAction(command: "ax", args: ["--platform", "android", "--device", "<selector>", "--output", "<path.xml>", "--json"])
    case "harmony-app", "harmony-app-install":
        return TKCLINextAction(command: "app", args: ["install", "--platform", "harmony", "--device", "<selector>", "--hap", "<path.hap>", "--json"])
    case "harmony-app-open-url":
        return TKCLINextAction(command: "app", args: ["open-url", "<url>", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "host-simulator":
        return TKCLINextAction(command: "sim", args: ["list", "--json"])
    case "sim-video":
        return TKCLINextAction(command: "sim", args: ["record", "--simulator", "<udid|booted>", "--output", "<path.mov>", "--json"])
    case "sim-logs":
        return TKCLINextAction(command: "sim", args: ["logs", "--simulator", "<udid|booted>", "--output", "<path.ndjson>", "--json"])
    case "sim-diagnostics":
        return TKCLINextAction(command: "sim", args: ["diagnose", "--output", "<path>", "--json"])
    case "sim-runtime":
        return TKCLINextAction(command: "sim", args: ["runtime", "list", "--json"])
    case "sim-runtime-maintenance":
        return TKCLINextAction(command: "sim", args: ["runtime", "verify", "--json"])
    case "sim-device-maintenance":
        return TKCLINextAction(command: "sim", args: ["clone", "<udid>", "--json"])
    case "sim-personalization":
        return TKCLINextAction(command: "sim", args: ["personalization", "scan-and-personalize", "--json"])
    case "sim-status-bar":
        return TKCLINextAction(command: "sim", args: ["status-bar", "list", "--simulator", "<udid|booted>", "--json"])
    case "sim-privacy":
        return TKCLINextAction(command: "sim", args: ["privacy", "grant", "<service>", "<bundle-id>", "--simulator", "<udid|booted>", "--json"])
    case "sim-location":
        return TKCLINextAction(command: "sim", args: ["location", "set", "<lat,lon>", "--simulator", "<udid|booted>", "--json"])
    case "sim-ui":
        return TKCLINextAction(command: "sim", args: ["ui", "appearance", "--simulator", "<udid|booted>", "--json"])
    case "sim-pasteboard":
        return TKCLINextAction(command: "sim", args: ["pasteboard", "get", "--simulator", "<udid|booted>", "--json"])
    case "sim-push":
        return TKCLINextAction(command: "sim", args: ["push", "--bundle-id", "<bundle-id>", "--payload", "<path|->", "--simulator", "<udid|booted>", "--json"])
    case "host-app":
        return TKCLINextAction(command: "app", args: ["list", "--device", "<selector>", "--json"])
    case "host-app-open-url-ready":
        return TKCLINextAction(command: "app", args: ["go", "<url>", "--device", "<selector>"])
    case "host-app-open-url-snapshot":
        return TKCLINextAction(command: "app", args: ["go", "<url>", "--device", "<selector>"])
    case "host-preferences":
        return TKCLINextAction(command: "app", args: ["prefs", "get", "<key>", "--device", "<selector>", "--bundle-id", "<bundle-id>", "--json"])
    case "xcode-discovery", "xcode-build", "xcode-test", "xcode-run":
        return TKCLINextAction(command: "xcode", args: ["discover", "--path", ".", "--json"])
    case "xcode-defaults":
        return TKCLINextAction(command: "xcode", args: ["status", "--json"])
    case "xcode-diagnostics":
        return TKCLINextAction(command: "xcode", args: ["status", "--json"])
    case "xcodebuild":
        return TKCLINextAction(command: "xcode", args: ["build", "--jsonl"])
    case "xcresult-summary":
        return TKCLINextAction(command: "xcresult", args: ["summary", "--path", "<path.xcresult>", "--json"])
    case "xcresult-failures":
        return TKCLINextAction(command: "xcresult", args: ["failures", "--path", "<path.xcresult>", "--json"])
    case "xctrace-record":
        return TKCLINextAction(command: "xctrace", args: ["record", "--template", "<name>", "--json"])
    case "coverage-report":
        return TKCLINextAction(command: "coverage", args: ["report", "--xcresult", "<path.xcresult>", "--json"])
    case "capture", "evidence":
        return TKCLINextAction(command: "evidence", args: ["--output", "<dir.tritonevidence>", "--json"])
    case "evidence-summary":
        return TKCLINextAction(command: "evidence", args: ["summary", "<dir.tritonevidence>", "--json"])
    case "evidence-redact":
        return TKCLINextAction(command: "evidence", args: ["redact", "<dir.tritonevidence>", "--output", "<safe.tritonevidence>", "--json"])
    case "smoke-ios":
        return TKCLINextAction(command: "smoke", args: ["ios", "--device", "<device>", "--bundle-id", "<bundle-id>", "--open-url", "<url>", "--wait-text", "<text>", "--json"])
    case "smoke-android":
        return TKCLINextAction(command: "smoke", args: ["android", "--device", "<device>", "--package", "<package>", "--wait-text", "<text>", "--evidence", "<dir.tritonevidence>", "--json"])
    case "smoke-harmony":
        return TKCLINextAction(command: "smoke", args: ["harmony", "--device", "<device>", "--bundle", "<bundle>", "--ability", "<ability>", "--wait-text", "<text>", "--json"])
    case "replay":
        return TKCLINextAction(command: "plan", args: ["inspect", "<file.tritonplan>", "--json"])
    case "runtime-manifest":
        return TKCLINextAction(command: "runtime", args: ["manifest", "--json"])
    case "state-app":
        return TKCLINextAction(command: "state", args: ["app", "--json"])
    case "state-scene":
        return TKCLINextAction(command: "state", args: ["scene", "--json"])
    case "state-route":
        return TKCLINextAction(command: "state", args: ["route", "--json"])
    case "state-responder":
        return TKCLINextAction(command: "state", args: ["responder", "--json"])
    case "snapshot":
        return TKCLINextAction(command: "snapshot", args: ["--json"])
    case "media-playback":
        return TKCLINextAction(command: "snapshot", args: ["--include", "media,ax,screenshot-metadata", "--json"])
    case "app-semantic-state":
        return TKCLINextAction(command: "snapshot", args: ["--include", "semantic,app,scene", "--json"])
    case "app-semantic-action":
        return TKCLINextAction(command: "snapshot", args: ["--include", "semantic", "--json"])
    case "focus":
        return TKCLINextAction(command: "focus", args: ["<selector>", "--json"])
    case "set-text":
        return TKCLINextAction(command: "set-text", args: ["<selector>", "<text>", "--json"])
    case "select-segment":
        return TKCLINextAction(command: "select-segment", args: ["<selector>", "<value>", "--json"])
    case "set-switch":
        return TKCLINextAction(command: "set-switch", args: ["<selector>", "<on|off|toggle>", "--json"])
    case "semantic-action":
        return TKCLINextAction(command: "schema", args: ["--command", "focus", "--json"])
    case "ledger":
        return TKCLINextAction(command: "ledger", args: ["--limit", "50", "--json"])
    case "observe":
        return TKCLINextAction(command: "observe", args: ["current", "--json"])
    case "observe-ios":
        return TKCLINextAction(command: "observe", args: ["current", "--platform", "ios", "--json"])
    case "observe-android":
        return TKCLINextAction(command: "observe", args: ["tree", "--platform", "android", "--device", "<selector>", "--json"])
    case "observe-harmony":
        return TKCLINextAction(command: "observe", args: ["tree", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "android-wait-text":
        return TKCLINextAction(command: "wait", args: ["--platform", "android", "--text", "<text>", "--json"])
    case "android-tap-text":
        return TKCLINextAction(command: "tap", args: ["<text>", "--platform", "android", "--json"])
    case "android-swipe":
        return TKCLINextAction(command: "swipe", args: ["--platform", "android", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
    case "android-type-text":
        return TKCLINextAction(command: "type", args: ["<text>", "--platform", "android", "--json"])
    case "android-paste-text":
        return TKCLINextAction(command: "paste", args: ["<text>", "--platform", "android", "--json"])
    case "android-press-key":
        return TKCLINextAction(command: "press", args: ["<button>", "--platform", "android", "--json"])
    case "node":
        return TKCLINextAction(command: "node", args: ["--oid", "<oid>", "--json"])
    case "node-resolve":
        return TKCLINextAction(command: "node", args: ["resolve", "--text", "<text>", "--json"])
    case "ax":
        return TKCLINextAction(command: "ax", args: ["--json"])
    case "screenshot":
        return TKCLINextAction(command: "screenshot", args: ["--output", "<path.png>", "--metadata"])
    case "wait":
        return TKCLINextAction(command: "wait", args: ["--text", "<text>", "--json"])
    case "assert":
        return TKCLINextAction(command: "assert", args: ["text-exists", "<text>", "--json"])
    case "webview-list":
        return TKCLINextAction(command: "webview", args: ["list", "--json"])
    case "webview-current":
        return TKCLINextAction(command: "webview", args: ["current", "--json"])
    case "webview-current-url":
        return TKCLINextAction(command: "webview", args: ["current-url", "--json"])
    case "webview-snapshot":
        return TKCLINextAction(command: "webview", args: ["snapshot", "--include", "metadata,text,forms", "--json"])
    case "webview-bridge-call":
        return TKCLINextAction(command: "webview", args: ["call", "<method>", "--json"])
    case "webview-events":
        return TKCLINextAction(command: "webview", args: ["events", "--limit", "50", "--json"])
    case "webview-wait":
        return TKCLINextAction(command: "webview", args: ["wait", "--text", "<text>", "--json"])
    case "route-current-url-assert":
        return TKCLINextAction(command: "route", args: ["assert-current-url", "<expected-url>", "--json"])
    case "tap":
        return TKCLINextAction(command: "tap", args: ["<query>", "--json"])
    case "swipe":
        return TKCLINextAction(command: "swipe", args: ["--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
    case "type":
        return TKCLINextAction(command: "type", args: ["<text>", "--json"])
    case "paste":
        return TKCLINextAction(command: "paste", args: ["<text>", "--json"])
    case "harmony-tap-text":
        return TKCLINextAction(command: "tap", args: ["<text>", "--platform", "harmony", "--json"])
    case "harmony-wait-text":
        return TKCLINextAction(command: "wait", args: ["--platform", "harmony", "--text", "<text>", "--json"])
    case "harmony-ax":
        return TKCLINextAction(command: "ax", args: ["--platform", "harmony", "--json"])
    case "harmony-swipe":
        return TKCLINextAction(command: "swipe", args: ["--platform", "harmony", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
    case "harmony-type-text":
        return TKCLINextAction(command: "type", args: ["<text>", "--platform", "harmony", "--json"])
    case "harmony-paste-text":
        return TKCLINextAction(command: "paste", args: ["<text>", "--platform", "harmony", "--json"])
    case "harmony-clear-text":
        return TKCLINextAction(command: "clear", args: ["--platform", "harmony", "--json"])
    case "harmony-press-key":
        return TKCLINextAction(command: "press", args: ["<button>", "--platform", "harmony", "--json"])
    case "clear":
        return TKCLINextAction(command: "clear", args: ["--at", "<x,y>", "--json"])
    case "input":
        return TKCLINextAction(command: "input", args: ["--json", "--summary", "--strict"])
    case "press":
        return TKCLINextAction(command: "schema", args: ["--command", "press", "--json"])
    default:
        return nil
    }
}

func runtimeCapabilityRequiresServer(_ name: String) -> Bool {
    [
        "status",
        "runtime-manifest",
        "state-app",
        "state-scene",
        "state-route",
        "state-responder",
        "snapshot",
        "media-playback",
        "app-semantic-state",
        "app-semantic-action",
        "focus",
        "set-text",
        "select-segment",
        "set-switch",
        "ledger",
        "list",
        "inspect",
        "hierarchy",
        "nodes",
        "node",
        "attrs",
        "object",
        "export-json",
        "export-archive",
        "geometry",
        "ax",
        "hit",
        "screenshot",
        "wait",
        "capture",
        "assert",
        "replay",
        "tap",
        "swipe",
        "type",
        "paste",
        "clear",
        "input",
    ].contains(name)
}

func runtimeCapabilityEvidence(for name: String) -> [String] {
    switch name {
    case "version", "schema", "status", "doctor", "capabilities", "plan":
        return ["stdout-json", "command-schema"]
    case "record", "replay-dry-run", "plan-inspect":
        return ["tritonplan", "stdout-json"]
    case "target-list", "target-use", "target-current", "target-resolve", "target-wait-ready":
        return ["host-targets.json", "status-json"]
    case "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot":
        return ["runtime-manifest", "snapshot-json"]
    case "media-playback":
        return ["runtime-media", "runtime-ax", "screenshot-metadata"]
    case "app-semantic-state":
        return ["runtime-semantic", "provider-state"]
    case "app-semantic-action":
        return ["runtime-semantic", "provider-action-catalog"]
    case "focus", "set-text", "select-segment", "set-switch", "semantic-action":
        return ["runtime-provider", "action-result", "runtime-ledger"]
    case "ledger":
        return ["runtime-ledger"]
    case "ios-simulator-host-tap", "ios-simulator-host-type":
        return ["unsupported-envelope", "command-schema"]
    case "host-device", "host-device-selector", "device-alias", "device-list", "device-use", "device-current", "device-resolve", "device-wait-ready", "device-screenshot", "host-device-screenshot", "ios-device", "ios-device-list", "ios-device-use", "ios-device-wait-ready", "ios-device-screenshot", "ios-screenshot", "android-device", "android-device-doctor", "android-device-list", "android-device-wait-ready", "android-device-screenshot", "harmony-device", "harmony-device-doctor", "harmony-device-list", "harmony-device-use", "harmony-device-wait-ready", "harmony-device-screenshot", "harmony-device-stop", "harmony-runtime-url", "harmony-app-install", "harmony-app-open-url", "harmony-ax", "harmony-screenshot", "host-simulator", "sim-video", "sim-logs", "sim-diagnostics", "sim-runtime", "sim-runtime-maintenance", "sim-device-maintenance", "sim-personalization", "sim-status-bar", "sim-privacy", "sim-location", "sim-ui", "sim-pasteboard", "sim-push", "host-app", "host-app-open-url-ready", "host-app-open-url-snapshot", "host-preferences", "android-app", "android-app-install", "android-app-launch", "android-app-terminate", "android-app-open-url", "harmony-app":
        return ["host-command-json", "host-artifact"]
    case "observe", "observe-ios", "observe-android", "observe-harmony", "android-ax":
        return ["surface-tree", "runtime-ax", "host-layout"]
    case "list":
        return ["status-json", "runtime-manifest"]
    case "inspect", "hierarchy", "nodes":
        return ["surface-tree", "runtime-ax"]
    case "node":
        return ["hierarchy-node", "surface-tree"]
    case "attrs", "object":
        return ["hierarchy-node", "surface-tree"]
    case "node-resolve":
        return ["target.resolution", "surface-tree"]
    case "export-json":
        return ["surface-tree", "host-artifact"]
    case "export-archive":
        return ["host-artifact", "screenshot-metadata"]
    case "geometry":
        return ["snapshot-json"]
    case "hit":
        return ["target.resolution", "surface-tree"]
    case "webview-list", "webview-current":
        return ["webview-candidates", "host-layout", "runtime-ax"]
    case "webview-current-url":
        return ["webview-provider", "provider-url"]
    case "webview-snapshot":
        return ["webview-provider", "webview-snapshot"]
    case "webview-bridge-call":
        return ["webview-provider", "bridge-call-result"]
    case "webview-events":
        return ["webview-provider", "page-events"]
    case "webview-wait":
        return ["webview-provider", "wait-samples"]
    case "route-current-url-assert":
        return ["webview-provider", "route-assertion"]
    case "xcode-discovery", "xcode-defaults", "xcode-diagnostics", "xcodebuild", "xcode-build", "xcode-test", "xcode-run", "xcresult-summary", "xcresult-failures", "xctrace-record", "coverage-report":
        return ["xcodebuild-json", "xcresult", "trace", "coverage"]
    case "capture", "evidence", "evidence-summary", "evidence-redact":
        return ["evidence-bundle"]
    case "smoke-ios", "smoke-android", "smoke-harmony":
        return ["smoke-summary", "evidence-bundle"]
    case "replay":
        return ["tritonplan"]
    case "assert":
        return ["assert.result", "runtime-snapshot"]
    case "ax":
        return ["runtime-ax", "host-layout"]
    case "screenshot":
        return ["screenshot", "screenshot-metadata"]
    case "wait":
        return ["wait.result", "runtime-samples"]
    case "tap", "swipe", "type", "paste", "clear", "input":
        return ["input.result", "runtime-ledger"]
    case "android-tap-text", "android-wait-text", "android-swipe", "android-type-text", "android-paste-text", "android-press-key", "harmony-tap-text", "harmony-wait-text", "harmony-swipe", "harmony-type-text", "harmony-paste-text", "harmony-press-key":
        return ["host-command-json", "host-artifact"]
    case "harmony-clear-text":
        return ["unsupported-envelope", "command-schema"]
    case "press":
        return ["unsupported-envelope", "command-schema"]
    default:
        return []
    }
}

func printCapabilities(_ response: TKCapabilitiesResponse, format: ClientOutputFormat, language: CLILanguage = effectiveLanguage(nil)) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        switch language {
        case .en:
            print("ok: \(response.ok)")
            print("serverReachable: \(response.serverReachable)")
            print("connected: \(response.connected)")
            print("latestHierarchyAvailable: \(response.latestHierarchyAvailable)")
            print("activeHierarchyAvailable: \(response.activeHierarchyAvailable ?? (response.connected && response.latestHierarchyAvailable))")
            print("hierarchyCacheState: \(response.hierarchyCacheState ?? "unknown")")
            print("targetConnectionState: \(response.targetConnectionState ?? (response.connected ? "connected" : "disconnected"))")
            print("targetCount: \(response.targetCount)")
            print("runtime: \(response.runtime)")
        case .zh:
            print("正常: \(response.ok)")
            print("服务可达: \(response.serverReachable)")
            print("已连接: \(response.connected)")
            print("已有最新层级: \(response.latestHierarchyAvailable)")
            print("当前连接已有层级: \(response.activeHierarchyAvailable ?? (response.connected && response.latestHierarchyAvailable))")
            print("层级缓存状态: \(response.hierarchyCacheState ?? "unknown")")
            print("目标连接状态: \(response.targetConnectionState ?? (response.connected ? "connected" : "disconnected"))")
            print("目标数量: \(response.targetCount)")
            print("运行时: \(response.runtime)")
        }
        if let error = response.error {
            switch language {
            case .en:
                print("error: \(error.code) \(error.message)")
            case .zh:
                print("错误: \(localizedErrorMessage(error, language: language))")
            }
            if let hint = error.hint {
                switch language {
                case .en:
                    print("hint: \(hint)")
                case .zh:
                    print("提示: \(localizedHint(error, fallback: hint, language: language))")
                }
            }
        }
        print(language == .zh ? "能力:" : "capabilities:")
        for capability in response.capabilities {
            let status = capability.supported
                ? (language == .zh ? "支持" : "supported")
                : (language == .zh ? "不支持" : "unsupported")
            if let reason = capability.reason {
                print("  \(capability.name): \(status) (\(reason))")
            } else {
                print("  \(capability.name): \(status)")
            }
        }
    }
}

func buildDoctor(host: String, port: Int) async -> TKDoctorResponse {
    buildDoctorResponse(capabilities: await buildCapabilities(host: host, port: port), host: host, port: port)
}

func buildDoctorResponse(capabilities: TKCapabilitiesResponse, host: String, port: Int) -> TKDoctorResponse {
    let checks = doctorChecks(capabilities: capabilities, host: host, port: port)
    let nextCheck = checks.first(where: { $0.status == "fail" || $0.status == "warn" })
    let nextStep = nextCheck?.id ?? "ready"
    return TKDoctorResponse(
        ok: capabilities.ok && checks.allSatisfy { $0.status != "fail" },
        serverReachable: capabilities.serverReachable,
        connected: capabilities.connected,
        runtime: capabilities.runtime,
        nextStep: nextStep,
        nextWorkflows: nextCheck?.workflowCategories ?? [],
        checks: checks,
        error: capabilities.error
    )
}

private func doctorChecks(capabilities: TKCapabilitiesResponse, host: String, port: Int) -> [TKDoctorCheck] {
    if !capabilities.serverReachable {
        let startServerRelatedCapabilities = capabilities.capabilities.filter { $0.nextAction?.command == "serve" }.map(\.name)
        return [
            TKDoctorCheck(
                id: "start-server",
                status: "fail",
                code: "server_unavailable",
                message: "Local Triton server is not reachable",
                hint: "Start the local control server, then rerun doctor.",
                nextAction: TKCLINextAction(command: "serve", args: ["--host", host, "--port", String(port)], requiresLongRunningProcess: true),
                relatedCapabilities: startServerRelatedCapabilities,
                workflowCategories: workflowCategoriesForCapabilities(startServerRelatedCapabilities, in: capabilities.capabilities)
            ),
            TKDoctorCheck(
                id: "inspect-schema",
                status: "pass",
                code: "schema_available",
                message: "CLI schema is available without a running server",
                hint: "Run schema when an agent needs command contracts before server startup.",
                nextAction: TKCLINextAction(command: "schema", args: ["--json"]),
                relatedCapabilities: ["schema", "plan", "capabilities"],
                workflowCategories: workflowCategoriesForCapabilities(["schema", "plan", "capabilities"], in: capabilities.capabilities)
            ),
        ]
    }

    var checks: [TKDoctorCheck] = [
        TKDoctorCheck(
            id: "server",
            status: "pass",
            code: "server_reachable",
            message: "Local Triton server responded",
            nextAction: TKCLINextAction(command: "status", args: ["--json"]),
            relatedCapabilities: ["status", "capabilities"],
            workflowCategories: workflowCategoriesForCapabilities(["status", "capabilities"], in: capabilities.capabilities)
        ),
    ]

    if capabilities.connected {
        let targetRelatedCapabilities = ["target-current", "runtime-manifest", "snapshot"]
        checks.append(TKDoctorCheck(
            id: "target",
            status: "pass",
            code: "target_connected",
            message: "At least one embedded runtime target is connected",
            nextAction: TKCLINextAction(command: "target", args: ["current", "--json"]),
            relatedCapabilities: targetRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(targetRelatedCapabilities, in: capabilities.capabilities)
        ))
        let runtimeRelatedCapabilities = capabilities.capabilities.filter { $0.group == "runtime" && $0.supported }.map(\.name)
        checks.append(TKDoctorCheck(
            id: "runtime",
            status: "pass",
            code: "runtime_available",
            message: "Embedded runtime capabilities are available",
            nextAction: TKCLINextAction(command: "runtime", args: ["manifest", "--json"]),
            relatedCapabilities: runtimeRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(runtimeRelatedCapabilities, in: capabilities.capabilities)
        ))
    } else {
        let connectTargetRelatedCapabilities = capabilities.capabilities
            .filter { $0.reason?.contains("embedded TritonKit runtime") == true }
            .map(\.name)
        checks.append(TKDoctorCheck(
            id: "connect-target",
            status: "fail",
            code: "target_unavailable",
            message: "Triton server is reachable but no embedded runtime target is connected",
            hint: "Launch an app that embeds TritonKit, or run an Xcode/app workflow that starts it.",
            nextAction: TKCLINextAction(command: "target", args: ["list", "--json"]),
            relatedCapabilities: connectTargetRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(connectTargetRelatedCapabilities, in: capabilities.capabilities)
        ))
    }

    let unsupportedActionNames = capabilities.capabilities
        .filter { $0.group == "action" && !$0.supported && !isInformationalHarmonyActionBoundary($0) }
        .map(\.name)
    if !unsupportedActionNames.isEmpty {
        checks.append(TKDoctorCheck(
            id: "action-surface",
            status: unsupportedActionNames == ["press"] ? "warn" : "fail",
            code: "action_capabilities_limited",
            message: "Some action capabilities are unavailable in the current environment",
            hint: "Use capabilities to inspect per-action reason and nextAction.",
            nextAction: TKCLINextAction(command: "capabilities", args: ["--json"]),
            relatedCapabilities: unsupportedActionNames,
            workflowCategories: workflowCategoriesForCapabilities(unsupportedActionNames, in: capabilities.capabilities)
        ))
    }

    let planRelatedCapabilities = ["plan", "target-list", "evidence-summary"]
    checks.append(TKDoctorCheck(
        id: "plan",
        status: "pass",
        code: "plan_available",
        message: "Task planning is available",
        nextAction: TKCLINextAction(command: "plan", args: ["--json"]),
        relatedCapabilities: planRelatedCapabilities,
        workflowCategories: workflowCategoriesForCapabilities(planRelatedCapabilities, in: capabilities.capabilities)
    ))

    return checks
}

private func isInformationalHarmonyActionBoundary(_ capability: TKRuntimeCapability) -> Bool {
    guard capability.name.hasPrefix("harmony-") else {
        return false
    }
    return capability.reason?.contains("not available in the current adapter") == true
}

private func workflowCategoriesForCapabilities(
    _ capabilityNames: [String],
    in capabilities: [TKRuntimeCapability]
) -> [String] {
    let capabilityMap = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.name, $0) })
    let taxonomy = [
        "action", "app", "assert", "evidence", "observe", "project",
        "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
    ]
    let categories = Set(capabilityNames.flatMap { capabilityMap[$0]?.requiredBy ?? [] })
    return taxonomy.filter { categories.contains($0) }
}

func printDoctor(_ response: TKDoctorResponse, format: ClientOutputFormat, language: CLILanguage = effectiveLanguage(nil)) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        switch language {
        case .en:
            print("ok: \(response.ok)")
            print("serverReachable: \(response.serverReachable)")
            print("connected: \(response.connected)")
            print("runtime: \(response.runtime)")
            print("nextStep: \(response.nextStep)")
        case .zh:
            print("正常: \(response.ok)")
            print("服务可达: \(response.serverReachable)")
            print("已连接: \(response.connected)")
            print("运行时: \(response.runtime)")
            print("下一步: \(response.nextStep)")
        }
        for check in response.checks {
            print("- \(check.id): \(check.status) \(check.code)")
            if let hint = check.hint {
                print("  hint: \(hint)")
            }
            if let nextAction = check.nextAction {
                print("  nextAction: triton \(([nextAction.command] + nextAction.args).joined(separator: " "))")
            }
        }
    }
}

struct WorkflowPlanRequest {
    let goal: String
    let platform: String?
    let device: String?
    let bundleID: String?
    let bundle: String?
    let ability: String?
    let hap: String?
    let url: String?
    let text: String?
    let expectedURL: String?
    let evidence: String?

    init(
        goal: String,
        platform: String? = nil,
        device: String? = nil,
        bundleID: String? = nil,
        bundle: String? = nil,
        ability: String? = nil,
        hap: String? = nil,
        url: String? = nil,
        text: String? = nil,
        expectedURL: String? = nil,
        evidence: String? = nil
    ) {
        self.goal = goal
        self.platform = platform
        self.device = device
        self.bundleID = bundleID
        self.bundle = bundle
        self.ability = ability
        self.hap = hap
        self.url = url
        self.text = text
        self.expectedURL = expectedURL
        self.evidence = evidence
    }

    static let general = WorkflowPlanRequest(
        goal: "general"
    )
}

func buildWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int,
    request: WorkflowPlanRequest = .general
) -> TKWorkflowPlanResponse {
    if !capabilities.serverReachable {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: capabilities.runtime,
            mode: "bootstrap",
            goal: request.goal,
            nextStep: "start-server",
            steps: [
                TKWorkflowPlanStep(
                    id: "start-server",
                    title: "Start Triton server",
                    command: "triton serve --host \(host) --port \(port)",
                    requiresServer: false,
                    requiresTarget: false,
                    when: "serverReachable == false",
                    expected: "Server listens on \(host):\(port)"
                ),
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "triton xcode run --json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "App launches with embedded TritonKit runtime and triton status reports connected: true"
                ),
                TKWorkflowPlanStep(
                    id: "diagnose",
                    title: "Re-check machine-readable runtime state",
                    command: "triton doctor --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after starting server and target",
                    expected: "ok=true, serverReachable=true, connected=true"
                ),
            ],
            afterRecoverySteps: taskWorkflowSteps(for: request, host: host, port: port),
            error: capabilities.error
        )
    }

    if request.goal != "general" {
        return buildTaskWorkflowPlan(
            capabilities: capabilities,
            host: host,
            port: port,
            request: request
        )
    }

    if !capabilities.connected {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: true,
            connected: false,
            runtime: capabilities.runtime,
            mode: "bootstrap",
            goal: request.goal,
            nextStep: "connect-target",
            steps: [
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "triton xcode run --json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "App launches and WebSocket target connects to ws://\(host):\(port)/"
                ),
                TKWorkflowPlanStep(
                    id: "list-targets",
                    title: "List connected targets",
                    command: "triton list --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after target launch",
                    expected: "targets contains triton:local"
                ),
                TKWorkflowPlanStep(
                    id: "diagnose",
                    title: "Confirm capability matrix",
                    command: "triton doctor --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after target connects",
                    expected: "embedded runtime capabilities become supported"
                ),
            ],
            error: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Triton server is reachable but no embedded runtime is connected",
                endpoint: endpointURL("/status", host: host, port: port),
                hint: "Launch an app that embeds TritonKit, then run `triton doctor --format json`"
            )
        )
    }

    return TKWorkflowPlanResponse(
        ok: true,
        serverReachable: true,
        connected: true,
        runtime: capabilities.runtime,
        mode: "bootstrap",
        goal: request.goal,
        nextStep: "geometry",
        steps: [
            TKWorkflowPlanStep(
                id: "geometry",
                title: "Read screen and window geometry",
                command: "triton geometry --host \(host) --port \(port) --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "connected == true",
                expected: "JSON geometry response"
            ),
            TKWorkflowPlanStep(
                id: "ax",
                title: "Build actionable accessibility index",
                command: "triton ax --host \(host) --port \(port) --format json --output /tmp/triton-ax.json",
                requiresServer: true,
                requiresTarget: true,
                when: "connected == true",
                expected: "Safe machine-readable controls"
            ),
            TKWorkflowPlanStep(
                id: "wait",
                title: "Wait for asynchronous UI state",
                command: "triton wait --host \(host) --port \(port) --text <text> --timeout 10 --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "after taps, submissions, and navigation",
                expected: "Machine-readable wait result with elapsedMs and timeout state"
            ),
            TKWorkflowPlanStep(
                id: "hit",
                title: "Resolve a coordinate before acting",
                command: "triton hit --host \(host) --port \(port) --x <x> --y <y> --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "before coordinate input",
                expected: "Hit-test node or empty result"
            ),
                TKWorkflowPlanStep(
                    id: "input",
                    title: "Execute NDJSON input actions",
                    command: "triton input --host \(host) --port \(port) --format json --summary --strict",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "after selecting safe actions",
                    expected: "Read NDJSON actions from stdin; emit input results plus a final summary; non-zero exit when any action fails"
                ),
            TKWorkflowPlanStep(
                id: "screenshot",
                title: "Capture visual evidence",
                command: "triton screenshot --host \(host) --port \(port) --output /tmp/triton.png --metadata",
                requiresServer: true,
                requiresTarget: true,
                when: "after state changes",
                expected: "PNG plus metadata JSON"
            ),
            TKWorkflowPlanStep(
                id: "export",
                title: "Export replayable inspection archive",
                command: "triton export --host \(host) --port \(port) --format archive --output /tmp/triton.triton",
                requiresServer: true,
                requiresTarget: true,
                when: "when handing off context",
                expected: "Self-contained .triton archive"
            ),
        ]
    )
}

func buildTaskWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int,
    request: WorkflowPlanRequest
) -> TKWorkflowPlanResponse {
    switch request.goal {
    case "ios-smoke":
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "target-list",
            steps: iosSmokePlanSteps(request: request, host: host, port: port)
        )
    case "open-url":
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "target-resolve",
            steps: openURLPlanSteps(request: request, host: host, port: port)
        )
    case "webview-check":
        return taskWorkflowPlan(
            capabilities: capabilities,
            goal: request.goal,
            nextStep: "webview-current",
            steps: [
                TKWorkflowPlanStep(
                    id: "webview-current",
                    title: "Read current WebView metadata",
                    command: "triton webview current --host \(shellEscaped(host)) --port \(port) --json",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "hybrid page may be visible",
                    expected: "Provider metadata includes WebView id, title, URL, and page session when available"
                ),
                TKWorkflowPlanStep(
                    id: "route-assert-current-url",
                    title: "Assert current WebView URL",
                    command: [
                        "triton", "route", "assert-current-url",
                        planValue(request.expectedURL ?? request.url, "<expected-url>"),
                        "--host", host,
                        "--port", String(port),
                        "--json",
                    ].map(shellEscaped).joined(separator: " "),
                    requiresServer: true,
                    requiresTarget: true,
                    when: "expected URL is known",
                    expected: "Route assertion returns status=pass or a machine-readable mismatch"
                ),
                TKWorkflowPlanStep(
                    id: "webview-wait",
                    title: "Wait for WebView text",
                    command: [
                        "triton", "webview", "wait",
                        "--text", planValue(request.text, "<text>"),
                        "--host", host,
                        "--port", String(port),
                        "--json",
                    ].map(shellEscaped).joined(separator: " "),
                    requiresServer: true,
                    requiresTarget: true,
                    when: "page text or event is the readiness signal",
                    expected: "WebView wait result includes match, timeout state, and last observed sample"
                ),
                evidenceCapturePlanStep(evidence: request.evidence),
            ]
        )
    default:
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: capabilities.serverReachable,
            connected: capabilities.connected,
            runtime: capabilities.runtime,
            mode: "task",
            goal: request.goal,
            nextStep: "inspect-schema",
            steps: [
                TKWorkflowPlanStep(
                    id: "inspect-schema",
                    title: "Inspect plan command schema",
                    command: "triton schema --command plan --json",
                    requiresServer: false,
                    requiresTarget: false,
                    when: "plan goal is unknown",
                    expected: "Schema lists supported task goals"
                ),
            ],
            error: TKCLIErrorDetail(
                code: "validation_failed",
                message: "Unsupported plan goal: \(request.goal)",
                hint: "Use one of: ios-smoke, open-url, webview-check, inspect"
            )
        )
    }
}

private func taskWorkflowSteps(for request: WorkflowPlanRequest, host: String, port: Int) -> [TKWorkflowPlanStep] {
    switch request.goal {
    case "ios-smoke":
        return iosSmokePlanSteps(request: request, host: host, port: port)
    case "open-url":
        return openURLPlanSteps(request: request, host: host, port: port)
    case "webview-check":
        return webviewCheckPlanSteps(request: request, host: host, port: port)
    default:
        return []
    }
}

private func iosSmokePlanSteps(request: WorkflowPlanRequest, host: String, port: Int) -> [TKWorkflowPlanStep] {
    [
        targetListPlanStep(host: host, port: port),
        targetResolvePlanStep(device: request.device, host: host, port: port),
        targetUsePlanStep(device: request.device, host: host, port: port),
        targetWaitReadyPlanStep(device: request.device, host: host, port: port),
        TKWorkflowPlanStep(
            id: "ios-host-input-unsupported",
            title: "Check host-side simulator input blocker",
            command: [
                "triton", "schema",
                "--command", "sim",
                "--json",
            ].map(shellEscaped).joined(separator: " "),
            category: "diagnose",
            workflowCategories: ["action", "assert", "evidence", "smoke", "target"],
            requiresServer: false,
            requiresTarget: false,
            when: "embedded runtime action is unavailable and host-side iOS Simulator input would be the fallback",
            expected: "Schema and capabilities report ios-simulator-host-tap/type as unsupported until a stable public simctl primitive is available"
        ),
        TKWorkflowPlanStep(
            id: "ios-smoke",
            title: "Run iOS smoke workflow",
            command: [
                "triton", "smoke", "ios",
                "--device", planValue(request.device, "<device>"),
                "--bundle-id", planValue(request.bundleID, "<bundle-id>"),
                "--open-url", planValue(request.url, "<url>"),
                "--wait-text", planValue(request.text, "<text>"),
                "--assert-text", planValue(request.text, "<text>"),
                "--evidence", planValue(request.evidence, "<dir.tritonevidence>"),
                "--json",
            ].map(shellEscaped).joined(separator: " "),
            requiresServer: true,
            requiresTarget: true,
            when: "target is resolved and host app can be launched",
            expected: "Smoke summary proves host action, runtime readiness, assertion, screenshot, and evidence"
        ),
        evidenceSummaryPlanStep(evidence: request.evidence),
    ]
}

private func openURLPlanSteps(request: WorkflowPlanRequest, host: String, port: Int) -> [TKWorkflowPlanStep] {
    if request.platform == "harmony" {
        return harmonyOpenURLPlanSteps(request: request, host: host, port: port)
    }

    return [
        targetResolvePlanStep(device: request.device, host: host, port: port),
        TKWorkflowPlanStep(
            id: "app-open-url",
            title: "Open app URL and capture runtime readiness",
            command: [
                "triton", "app", "go",
                planValue(request.url, "<url>"),
                "--device", planValue(request.device, "<device>"),
            ].map(shellEscaped).joined(separator: " "),
            requiresServer: true,
            requiresTarget: true,
            when: "target is ready and URL/deep link is known",
            expected: "Host action succeeds and optional runtime snapshot summarizes app state"
        ),
        waitTextPlanStep(text: request.text, host: host, port: port),
        assertTextPlanStep(text: request.text, host: host, port: port),
        evidenceCapturePlanStep(evidence: request.evidence),
        evidenceSummaryPlanStep(evidence: request.evidence),
    ]
}

private func harmonyOpenURLPlanSteps(request: WorkflowPlanRequest, host: String, port: Int) -> [TKWorkflowPlanStep] {
    var steps = [targetResolvePlanStep(device: request.device, host: host, port: port)]
    if let hap = request.hap, !hap.isEmpty {
        steps.append(harmonyInstallPlanStep(device: request.device, hap: hap))
    }
    steps.append(harmonyOpenURLPlanStep(request: request))
    steps.append(harmonyWaitTextPlanStep(device: request.device, text: request.text))
    steps.append(harmonyScreenshotPlanStep(device: request.device, evidence: request.evidence))
    steps.append(evidenceSummaryPlanStep(evidence: request.evidence))
    return steps
}

private func webviewCheckPlanSteps(request: WorkflowPlanRequest, host: String, port: Int) -> [TKWorkflowPlanStep] {
    [
        TKWorkflowPlanStep(
            id: "webview-current",
            title: "Read current WebView metadata",
            command: "triton webview current --host \(shellEscaped(host)) --port \(port) --json",
            requiresServer: true,
            requiresTarget: true,
            when: "hybrid page may be visible",
            expected: "Provider metadata includes WebView id, title, URL, and page session when available"
        ),
        TKWorkflowPlanStep(
            id: "route-assert-current-url",
            title: "Assert current WebView URL",
            command: [
                "triton", "route", "assert-current-url",
                planValue(request.expectedURL ?? request.url, "<expected-url>"),
                "--host", host,
                "--port", String(port),
                "--json",
            ].map(shellEscaped).joined(separator: " "),
            requiresServer: true,
            requiresTarget: true,
            when: "expected URL is known",
            expected: "Route assertion returns status=pass or a machine-readable mismatch"
        ),
        TKWorkflowPlanStep(
            id: "webview-wait",
            title: "Wait for WebView text",
            command: [
                "triton", "webview", "wait",
                "--text", planValue(request.text, "<text>"),
                "--host", host,
                "--port", String(port),
                "--json",
            ].map(shellEscaped).joined(separator: " "),
            requiresServer: true,
            requiresTarget: true,
            when: "page text or event is the readiness signal",
            expected: "WebView wait result includes match, timeout state, and last observed sample"
        ),
        evidenceCapturePlanStep(evidence: request.evidence),
    ]
}

private func taskWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    goal: String,
    nextStep: String,
    steps: [TKWorkflowPlanStep]
) -> TKWorkflowPlanResponse {
    TKWorkflowPlanResponse(
        ok: capabilities.serverReachable,
        serverReachable: capabilities.serverReachable,
        connected: capabilities.connected,
        runtime: capabilities.runtime,
        mode: "task",
        goal: goal,
        nextStep: nextStep,
        steps: steps,
        error: capabilities.error
    )
}

private func planValue(_ value: String?, _ placeholder: String) -> String {
    guard let value, !value.isEmpty else { return placeholder }
    return value
}

private func targetListPlanStep(host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-list",
        title: "List available host targets",
        command: "triton target list --host \(shellEscaped(host)) --port \(port) --json",
        requiresServer: false,
        requiresTarget: false,
        when: "before selecting a device or emulator",
        expected: "Targets include platform, readiness, and default candidate"
    )
}

private func targetResolvePlanStep(device: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-resolve",
        title: "Resolve target selector",
        command: [
            "triton", "target", "resolve",
            planValue(device, "<device>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "after target list returns candidates",
        expected: "A single target is selected or ambiguity is explained"
    )
}

private func targetUsePlanStep(device: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-use",
        title: "Persist current target",
        command: [
            "triton", "target", "use",
            planValue(device, "<device>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "the resolved target will be reused by later commands",
        expected: "Workspace defaults contain the selected target"
    )
}

private func targetWaitReadyPlanStep(device: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "target-wait-ready",
        title: "Wait for target readiness",
        command: [
            "triton", "target", "wait-ready",
            planValue(device, "<device>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "before launching or opening app URLs",
        expected: "Target reports ready or returns device_not_ready with source command"
    )
}

private func harmonyInstallPlanStep(device: String?, hap: String) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "install-app",
        title: "Install Harmony HAP",
        command: [
            "triton", "app", "install",
            "--device", planValue(device, "<device>"),
            "--platform", "harmony",
            "--hap", hap,
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "before opening a Harmony URL when a HAP path is provided",
        expected: "Harmony HAP install command returns host action JSON"
    )
}

private func harmonyOpenURLPlanStep(request: WorkflowPlanRequest) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "app-open-url",
        title: "Open Harmony app URL",
        command: [
            "triton", "app", "open-url",
            planValue(request.url, "<url>"),
            "--device", planValue(request.device, "<device>"),
            "--platform", "harmony",
            "--bundle", planValue(request.bundle, "<bundle>"),
            "--ability", planValue(request.ability, "<ability>"),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "target is ready and Harmony bundle, ability, and deep link are known",
        expected: "HDC aa start -U host action submits the URL; business completion still requires wait/assert/evidence"
    )
}

private func harmonyWaitTextPlanStep(device: String?, text: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "wait-text",
        title: "Wait for Harmony text",
        command: [
            "triton", "wait",
            "--platform", "harmony",
            "--target", planValue(device, "<device>"),
            "--text", planValue(text, "<text>"),
            "--timeout", "15",
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "after Harmony URL submission",
        expected: "Host-side Harmony wait result proves readiness or returns timeout diagnostics"
    )
}

private func harmonyScreenshotPlanStep(device: String?, evidence: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "capture-screenshot",
        title: "Capture Harmony screenshot",
        command: [
            "triton", "screenshot",
            "--device", planValue(device, "<device>"),
            "--platform", "harmony",
            "--output", harmonyScreenshotPath(evidence: evidence),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "after wait/assert or when preserving failure evidence",
        expected: "Screenshot metadata and image path are available for evidence review"
    )
}

private func waitTextPlanStep(text: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "wait-text",
        title: "Wait for expected text",
        command: [
            "triton", "wait",
            "--text", planValue(text, "<text>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: true,
        requiresTarget: true,
        when: "after navigation or async loading",
        expected: "Wait result proves readiness or returns timeout diagnostics"
    )
}

private func assertTextPlanStep(text: String?, host: String, port: Int) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "assert-text",
        title: "Assert expected text",
        command: [
            "triton", "assert", "text-exists",
            planValue(text, "<text>"),
            "--host", host,
            "--port", String(port),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: true,
        requiresTarget: true,
        when: "after wait succeeds",
        expected: "Assertion result is the pass/fail gate"
    )
}

private func evidenceCapturePlanStep(evidence: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "evidence",
        title: "Capture evidence bundle",
        command: [
            "triton", "evidence",
            "--output", planValue(evidence, "<dir.tritonevidence>"),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: true,
        requiresTarget: true,
        when: "after the workflow reaches a pass/fail state",
        expected: "Evidence manifest lists artifacts, skipped sources, target, CLI, and run metadata"
    )
}

private func evidenceSummaryPlanStep(evidence: String?) -> TKWorkflowPlanStep {
    TKWorkflowPlanStep(
        id: "evidence-summary",
        title: "Summarize evidence bundle",
        command: [
            "triton", "evidence", "summary",
            planValue(evidence, "<dir.tritonevidence>"),
            "--json",
        ].map(shellEscaped).joined(separator: " "),
        requiresServer: false,
        requiresTarget: false,
        when: "before handoff or issue filing",
        expected: "Summary identifies the key artifacts and redaction state"
    )
}

private func harmonyScreenshotPath(evidence: String?) -> String {
    guard let evidence, !evidence.isEmpty, evidence != "<dir.tritonevidence>" else {
        return "<path.png>"
    }
    if evidence.hasSuffix(".tritonevidence") {
        return String(evidence.dropLast(".tritonevidence".count)) + ".png"
    }
    return evidence + ".png"
}

func renderWorkflowPlan(_ plan: TKWorkflowPlanResponse, language: CLILanguage = effectiveLanguage(nil)) -> String {
    if language == .zh {
        return renderWorkflowPlanZH(plan)
    }
    var lines = [
        "ok: \(plan.ok)",
        "serverReachable: \(plan.serverReachable)",
        "connected: \(plan.connected)",
        "runtime: \(plan.runtime)",
        "nextStep: \(plan.nextStep)",
        "nextWorkflows: \(plan.nextWorkflows.joined(separator: ","))",
    ]
    if let error = plan.error {
        lines.append("error: \(error.code) \(error.message)")
        if let hint = error.hint {
            lines.append("hint: \(hint)")
        }
        if let nextAction = error.nextAction {
            let command = ([nextAction.command] + nextAction.args).joined(separator: " ")
            lines.append("nextAction: triton \(command)")
            lines.append("requiresLongRunningProcess: \(nextAction.requiresLongRunningProcess)")
        }
    }
    lines.append("steps:")
    for step in plan.steps {
        lines.append("  \(step.id): \(step.title)")
        lines.append("    command: \(step.command)")
        lines.append("    when: \(step.when)")
        lines.append("    expected: \(step.expected)")
    }
    return lines.joined(separator: "\n")
}

func renderWorkflowPlanZH(_ plan: TKWorkflowPlanResponse) -> String {
    var lines = [
        "正常: \(plan.ok)",
        "服务可达: \(plan.serverReachable)",
        "已连接: \(plan.connected)",
        "运行时: \(plan.runtime)",
        "下一步: \(plan.nextStep)",
        "下一步工作流: \(plan.nextWorkflows.joined(separator: ","))",
    ]
    if let error = plan.error {
        lines.append("错误: \(localizedErrorMessage(error, language: .zh))")
        if let hint = error.hint {
            lines.append("提示: \(localizedHint(error, fallback: hint, language: .zh))")
        }
        if let nextAction = error.nextAction {
            let command = ([nextAction.command] + nextAction.args).joined(separator: " ")
            lines.append("下一步命令: triton \(command)")
            lines.append("需要长驻进程: \(nextAction.requiresLongRunningProcess)")
        }
    }
    lines.append("步骤:")
    for step in plan.steps {
        lines.append("  \(step.id): \(step.title)")
        lines.append("    命令: \(step.command)")
        lines.append("    条件: \(step.when)")
        lines.append("    预期: \(step.expected)")
    }
    return lines.joined(separator: "\n")
}

func printCLIError(_ error: Error, endpoint: String, host: String, port: Int) throws {
    print(try encodeJSON(cliErrorResponse(for: error, endpoint: endpoint, host: host, port: port)))
}

func printCLIErrorText(_ error: Error, endpoint: String, host: String, port: Int, language: CLILanguage = effectiveLanguage(nil)) {
    let detail = cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port)
    switch language {
    case .en:
        fputs("\(detail.code): \(detail.message)\n", stderr)
    case .zh:
        fputs("\(detail.code): \(localizedErrorMessage(detail, language: language))\n", stderr)
    }
    if let endpoint = detail.endpoint {
        fputs("\(language == .zh ? "端点" : "endpoint"): \(endpoint)\n", stderr)
    }
    if let hint = detail.hint {
        fputs("\(language == .zh ? "提示" : "hint"): \(localizedHint(detail, fallback: hint, language: language))\n", stderr)
    }
    if let nextAction = detail.nextAction {
        let command = (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
        fputs("\(language == .zh ? "下一步" : "next"): \(command)\n", stderr)
    }
    if let nearestCandidates = detail.nearestCandidates, !nearestCandidates.isEmpty {
        fputs("\(language == .zh ? "邻近候选" : "nearest"): \(nearestCandidates.joined(separator: " | "))\n", stderr)
    }
    if let suggestedCommands = detail.suggestedCommands, !suggestedCommands.isEmpty {
        fputs("\(language == .zh ? "建议命令" : "suggested"): \(suggestedCommands.joined(separator: " | "))\n", stderr)
    }
    if let candidateCount = detail.candidateCount {
        fputs("\(language == .zh ? "候选数" : "candidateCount"): \(candidateCount)\n", stderr)
    }
}

func failCommand(
    _ error: Error,
    outputFormat: ClientOutputFormat,
    endpoint: String,
    host: String,
    port: Int
) throws -> Never {
    switch outputFormat {
    case .json:
        print(try encodeJSON(cliErrorResponse(for: error, endpoint: endpoint, host: host, port: port)))
    case .text:
        printCLIErrorText(error, endpoint: endpoint, host: host, port: port)
    }
    throw ExitCode.failure
}

func cliErrorResponse(for error: Error, endpoint: String, host: String, port: Int) -> TKCLIErrorResponse {
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response
    }
    return TKCLIErrorResponse(error: cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port))
}

func localizedErrorMessage(_ detail: TKCLIErrorDetail, language: CLILanguage) -> String {
    guard language == .zh else { return "\(detail.code) \(detail.message)" }
    switch detail.code {
    case "server_unavailable":
        return "服务器不可用：无法连接到本地 Triton 服务。"
    case "request_failed":
        return "请求失败：\(detail.message)"
    case "validation_failed":
        return "参数校验失败：\(detail.message)"
    default:
        return "\(detail.code)：\(detail.message)"
    }
}

func localizedHint(_ detail: TKCLIErrorDetail, fallback: String, language: CLILanguage) -> String {
    guard language == .zh else { return fallback }
    switch detail.code {
    case "server_unavailable":
        return "运行 `triton serve --host 127.0.0.1 --port 19421` 并连接 iOS App"
    default:
        return fallback
    }
}

func printValidationError(_ message: String) throws {
    let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "validation_failed",
        message: message,
        hint: "Run `triton schema --command tap --json` to inspect required fields"
    ))
    print(try encodeJSON(response))
}

func cliErrorDetail(for error: Error, endpoint: String, host: String, port: Int) -> TKCLIErrorDetail {
    let url = endpointURL(endpoint, host: host, port: port)
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response.error
    }
    if let urlError = error as? URLError {
        return TKCLIErrorDetail(
            code: "server_unavailable",
            message: urlError.localizedDescription,
            endpoint: url,
            hint: "Run `triton serve --host \(host) --port \(port)` and connect the iOS app",
            nextAction: TKCLINextAction(
                command: "serve",
                args: ["--host", host, "--port", "\(port)"],
                requiresLongRunningProcess: true
            )
        )
    }
    if let runtime = error as? RuntimeError {
        return TKCLIErrorDetail(
            code: "request_failed",
            message: runtime.description,
            endpoint: url,
            hint: "Check `triton doctor --format json` for server and target state"
        )
    }
    if let targetError = error as? TKTargetResolutionError {
        let code: String
        switch targetError {
        case .ambiguous:
            code = "ambiguous_target"
        case .notFound:
            code = "target_not_found"
        }
        return TKCLIErrorDetail(
            code: code,
            message: targetError.description,
            endpoint: url,
            hint: "Run `triton list --json` and pass the exact --target id, or the simulator UDID for an iOS simulator runtime."
        )
    }
    if let tapError = error as? TKTapTargetResolutionFailure {
        return TKCLIErrorDetail(
            code: "text_not_found",
            message: tapError.message,
            endpoint: url,
            hint: "Run `triton find \(tapError.query.isEmpty ? "''" : "'" + tapError.query.replacingOccurrences(of: "'", with: "'\\''") + "'") --all --json` and `triton screenshot --json` to inspect the current UI.",
            nearestCandidates: tapError.nearestCandidates,
            suggestedCommands: tapError.suggestedCommands,
            candidateCount: tapError.candidateCount
        )
    }
    return TKCLIErrorDetail(
        code: "request_failed",
        message: "\(error)",
        endpoint: url,
        hint: "Check `triton doctor --format json` for server and target state"
    )
}

func endpointURL(_ endpoint: String, host: String, port: Int) -> String {
    "http://\(host):\(port)\(endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)")"
}

func renderTargetLine(_ target: TKTargetSummary) -> String {
    [
        target.id,
        target.transport,
        target.identityState ?? "-",
        target.hierarchyCacheState ?? "-",
        target.appName ?? "-",
        target.bundleIdentifier ?? "-",
        target.deviceDescription ?? "-",
        target.osDescription ?? "-",
    ].joined(separator: "\t")
}
