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
            capabilities: runtimeCapabilities(connected: status.connected),
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
            capabilities: runtimeCapabilities(connected: false),
            error: detail
        )
    }
}

func runtimeCapabilities(connected: Bool) -> [TKRuntimeCapability] {
    let requiresRuntime = connected ? nil : "Requires connected embedded TritonKit runtime"
    return [
        TKRuntimeCapability(name: "plan", supported: true),
        TKRuntimeCapability(name: "record", supported: true),
        TKRuntimeCapability(name: "replay-dry-run", supported: true),
        TKRuntimeCapability(name: "schema", supported: true),
        TKRuntimeCapability(name: "runtime-manifest", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-app", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-scene", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-route", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-responder", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "snapshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "focus", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "set-text", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "select-segment", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "set-switch", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ledger", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "host-device", supported: true),
        TKRuntimeCapability(name: "harmony-device-doctor", supported: true),
        TKRuntimeCapability(name: "harmony-device-list", supported: true),
        TKRuntimeCapability(name: "harmony-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "harmony-runtime-url", supported: true),
        TKRuntimeCapability(name: "harmony-app-install", supported: true),
        TKRuntimeCapability(name: "harmony-app-open-url", supported: true),
        TKRuntimeCapability(name: "harmony-ax", supported: true),
        TKRuntimeCapability(name: "harmony-wait-text", supported: true),
        TKRuntimeCapability(name: "harmony-tap-text", supported: true),
        TKRuntimeCapability(name: "harmony-screenshot", supported: true),
        TKRuntimeCapability(name: "observe", supported: true),
        TKRuntimeCapability(name: "observe-ios", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "observe-harmony", supported: true),
        TKRuntimeCapability(name: "node-resolve", supported: true),
        TKRuntimeCapability(name: "status", supported: true),
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
        TKRuntimeCapability(name: "tap", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "swipe", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "type", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "paste", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "clear", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "input", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "press", supported: false, reason: "Host-side HID is not available in the embedded runtime"),
    ]
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

func buildWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int
) -> TKWorkflowPlanResponse {
    if !capabilities.serverReachable {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: capabilities.runtime,
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
                    command: "open the iOS app or run the simulator build that embeds TritonKit",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "triton status reports connected: true"
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
            error: capabilities.error
        )
    }

    if !capabilities.connected {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: true,
            connected: false,
            runtime: capabilities.runtime,
            nextStep: "connect-target",
            steps: [
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "open the iOS app or run the simulator build that embeds TritonKit",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "WebSocket target connects to ws://\(host):\(port)/"
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
        nextStep: "observe",
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
                    command: "triton input --host \(host) --port \(port) --format json --summary --strict < gestures.ndjson",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "after selecting safe actions",
                    expected: "Input results plus a final summary; non-zero exit when any action fails"
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
    let response = TKCLIErrorResponse(error: cliErrorDetail(
        for: error,
        endpoint: endpoint,
        host: host,
        port: port
    ))
    print(try encodeJSON(response))
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
        if let httpError = error as? CLIHTTPError,
           let response = httpError.response {
            print(try encodeJSON(response))
        } else {
            try printCLIError(error, endpoint: endpoint, host: host, port: port)
        }
    case .text:
        printCLIErrorText(error, endpoint: endpoint, host: host, port: port)
    }
    throw ExitCode.failure
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
