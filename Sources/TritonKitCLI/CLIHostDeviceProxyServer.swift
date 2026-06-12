import Darwin
import Foundation

struct NetworkProxyServeConfig {
    let listen: NetworkProxyEndpoint
    let outputDirectory: String
    let maxConnections: Int?
    let mode: String
    let mockRulesPath: String?
    let throttleDelayMs: Int?

    init(listen: NetworkProxyEndpoint, outputDirectory: String, maxConnections: Int? = nil, mode: String = "record", mockRulesPath: String? = nil, throttleDelayMs: Int? = nil) {
        self.listen = listen
        self.outputDirectory = outputDirectory
        self.maxConnections = maxConnections
        self.mode = mode
        self.mockRulesPath = mockRulesPath
        self.throttleDelayMs = throttleDelayMs
    }
}

struct NetworkProxyServeEvent: Codable, Equatable {
    let ok: Bool
    let surface: String
    let event: String
    let schemaVersion: String
    let listen: String
    let capturePath: String
    let captureMode: String?
    let policyAction: String?
    let mockRuleId: String?
    let connectionIndex: Int?
    let method: String?
    let url: String?
    let host: String?
    let port: Int?
    let path: String?
    let tunnel: Bool?
    let headerNames: [String]
    let responseStatus: Int?
    let responseStatusText: String?
    let throttleDelayMs: Int?
    let redaction: String
    let error: String?
}

struct NetworkProxyServeSummary: Encodable, Equatable {
    let ok: Bool
    let surface: String
    let event: String
    let schemaVersion: String
    let action: String
    let listen: String
    let capturePath: String
    let captureMode: String
    let requestCount: Int
    let eventCount: Int
    let failureCount: Int
    let limitations: [String]
}

private struct NetworkProxyHAREnvelope: Encodable {
    let log: NetworkProxyHARLog
}

private struct NetworkProxyHARLog: Encodable {
    let version: String
    let creator: NetworkProxyHARCreator
    let entries: [NetworkProxyHAREntry]
}

private struct NetworkProxyHARCreator: Encodable {
    let name: String
    let version: String
}

private struct NetworkProxyHAREntry: Encodable {
    let startedDateTime: String
    let time: Int
    let request: NetworkProxyHARRequest
    let response: NetworkProxyHARResponse
    let cache: [String: String]
    let timings: NetworkProxyHARTimings
    let comment: String
}

private struct NetworkProxyHARRequest: Encodable {
    let method: String
    let url: String
    let httpVersion: String
    let cookies: [String]
    let headers: [NetworkProxyHARNameValue]
    let queryString: [NetworkProxyHARNameValue]
    let headersSize: Int
    let bodySize: Int
}

private struct NetworkProxyHARResponse: Encodable {
    let status: Int
    let statusText: String
    let httpVersion: String
    let cookies: [String]
    let headers: [NetworkProxyHARNameValue]
    let content: NetworkProxyHARContent
    let redirectURL: String
    let headersSize: Int
    let bodySize: Int
}

private struct NetworkProxyHARContent: Encodable {
    let size: Int
    let mimeType: String
}

private struct NetworkProxyHARTimings: Encodable {
    let send: Int
    let wait: Int
    let receive: Int
}

private struct NetworkProxyHARNameValue: Encodable {
    let name: String
    let value: String
}

private struct ParsedProxyRequest {
    let event: NetworkProxyServeEvent
    let upstreamHost: String
    let upstreamPort: Int
    let upstreamRequest: Data?
    let isTunnel: Bool
    let mockResponse: NetworkProxyMockResponse?
}

private struct NetworkProxyMockRulesFile: Decodable {
    let schemaVersion: String?
    let rules: [NetworkProxyMockRule]
}

private struct NetworkProxyMockRule: Decodable, Equatable {
    let id: String?
    let method: String?
    let host: String?
    let path: String?
    let pathPrefix: String?
    let status: Int?
    let statusText: String?
    let headers: [String: String]?
    let body: String?
}

private struct NetworkProxyMockResponse: Equatable {
    let ruleId: String?
    let status: Int
    let statusText: String
    let headers: [String: String]
    let body: String
}

func runNetworkProxyCaptureServer(
    config: NetworkProxyServeConfig,
    eventWriter: ((NetworkProxyServeEvent) -> Void)? = nil
) throws -> NetworkProxyServeSummary {
    signal(SIGPIPE, SIG_IGN)
    let mode = try normalizeNetworkProxyServeMode(config.mode)
    let throttleDelayMs = try normalizeNetworkProxyThrottleDelayMs(config.throttleDelayMs, mode: mode)
    let mockRules = try config.mockRulesPath.flatMap(loadNetworkProxyMockRules)
    let captureURL = try networkProxyServeCaptureURL(outputDirectory: config.outputDirectory)
    let listenFD = try makeNetworkProxyListenSocket(endpoint: config.listen)
    defer { close(listenFD) }

    let listen = "\(config.listen.host):\(config.listen.port)"
    let readyEvent = NetworkProxyServeEvent(
        ok: true,
        surface: "host.device-proxy-serve",
        event: "proxy.serve.ready",
        schemaVersion: "triton.proxy.capture.v1",
        listen: listen,
        capturePath: captureURL.path,
        captureMode: mode,
        policyAction: nil,
        mockRuleId: nil,
        connectionIndex: nil,
        method: nil,
        url: nil,
        host: nil,
        port: nil,
        path: nil,
        tunnel: nil,
        headerNames: [],
        responseStatus: nil,
        responseStatusText: nil,
        throttleDelayMs: nil,
        redaction: "headers-names-only",
        error: nil
    )
    eventWriter?(readyEvent)

    var accepted = 0
    while config.maxConnections == nil || accepted < (config.maxConnections ?? 0) {
        let clientFD = accept(listenFD, nil, nil)
        if clientFD < 0 {
            if errno == EINTR { continue }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        accepted += 1
        defer { close(clientFD) }
        do {
            _ = try handleNetworkProxyClient(
                clientFD: clientFD,
                captureURL: captureURL,
                listen: listen,
                connectionIndex: accepted,
                mode: mode,
                mockRules: mockRules,
                throttleDelayMs: throttleDelayMs,
                eventWriter: eventWriter
            )
        } catch {
            let event = NetworkProxyServeEvent(
                ok: false,
                surface: "host.device-proxy-serve",
                event: "proxy.serve.connection-failed",
                schemaVersion: "triton.proxy.capture.v1",
                listen: listen,
                capturePath: captureURL.path,
                captureMode: mode,
                policyAction: nil,
                mockRuleId: nil,
                connectionIndex: accepted,
                method: nil,
                url: nil,
                host: nil,
                port: nil,
                path: nil,
                tunnel: nil,
                headerNames: [],
                responseStatus: nil,
                responseStatusText: nil,
                throttleDelayMs: nil,
                redaction: "headers-names-only",
                error: String(describing: error)
            )
            try appendNetworkProxyCaptureEvent(event, captureURL: captureURL)
            eventWriter?(event)
        }
    }

    let captureSummary = summarizeNetworkProxyCaptureArtifactIfPresent(captureURL: captureURL)
    return NetworkProxyServeSummary(
        ok: true,
        surface: "host.device-proxy-serve",
        event: "proxy.serve.summary",
        schemaVersion: "triton.proxy.capture.v1",
        action: "proxy.serve",
        listen: listen,
        capturePath: captureURL.path,
        captureMode: mode,
        requestCount: captureSummary.requestCount,
        eventCount: 1 + captureSummary.eventCount,
        failureCount: captureSummary.failureCount,
        limitations: [
            "proxy_capture_metadata_only:no_tls_decryption",
            "proxy_capture_redaction:headers_names_only",
            "proxy_capture_mode:\(mode)",
            throttleDelayMs.map { "proxy_throttle_delay_ms:\($0)" },
            mockRules == nil ? "proxy_mock_rules:none" : "proxy_mock_rules:loaded",
        ].compactMap { $0 }
    )
}

private func summarizeNetworkProxyCaptureArtifactIfPresent(captureURL: URL) -> NetworkProxyCaptureExportSummary {
    guard FileManager.default.fileExists(atPath: captureURL.path),
          let summary = try? summarizeNetworkProxyCaptureArtifact(sourceURL: captureURL) else {
        return NetworkProxyCaptureExportSummary(
            requestCount: 0,
            eventCount: 0,
            failureCount: 0,
            redaction: "unknown",
            truncation: "none"
        )
    }
    return summary
}

private func normalizeNetworkProxyServeMode(_ mode: String) throws -> String {
    let normalized = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard ["record", "mock", "block", "throttle"].contains(normalized) else {
        throw RuntimeError("device proxy serve --mode currently supports record, mock, block, or throttle.")
    }
    return normalized
}

private func normalizeNetworkProxyThrottleDelayMs(_ delayMs: Int?, mode: String) throws -> Int? {
    guard let delayMs else { return nil }
    guard mode == "throttle" else {
        throw RuntimeError("device proxy serve --throttle-ms can only be used with --mode throttle.")
    }
    guard (0...60_000).contains(delayMs) else {
        throw RuntimeError("device proxy serve --throttle-ms must be between 0 and 60000.")
    }
    return delayMs
}

func networkProxyServeCapturePath(outputDirectory: String) -> String {
    URL(fileURLWithPath: outputDirectory, isDirectory: true).appendingPathComponent("requests.ndjson").path
}

func exportNetworkProxyCaptureArtifact(sourceURL: URL, outputURL: URL) throws -> Int {
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if outputURL.pathExtension.lowercased() == "har" {
        let har = try makeNetworkProxyHAR(sourceURL: sourceURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(har)
        try data.write(to: outputURL)
        return data.count
    }
    let data = try Data(contentsOf: sourceURL)
    try data.write(to: outputURL)
    return data.count
}

func summarizeNetworkProxyCaptureArtifact(sourceURL: URL) throws -> NetworkProxyCaptureExportSummary {
    let data = try Data(contentsOf: sourceURL)
    let lines = String(data: data, encoding: .utf8)?
        .split(whereSeparator: \.isNewline)
        .map(String.init) ?? []
    let decoder = JSONDecoder()
    var eventCount = 0
    var requestCount = 0
    var failureCount = 0
    var redactions: Set<String> = []

    for line in lines {
        guard let lineData = line.data(using: .utf8) else { continue }
        if let event = try? decoder.decode(NetworkProxyServeEvent.self, from: lineData) {
            eventCount += 1
            redactions.insert(event.redaction)
            if event.ok, event.event == "proxy.serve.request" {
                requestCount += 1
            }
            if !event.ok || event.event == "proxy.serve.connection-failed" {
                failureCount += 1
            }
            continue
        }
        if let payload = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
           let redaction = payload["redaction"] as? String,
           !redaction.isEmpty {
            redactions.insert(redaction)
            if let requestCountValue = payload["requestCount"] as? Int {
                requestCount += requestCountValue
            }
            if let eventCountValue = payload["eventCount"] as? Int {
                eventCount += eventCountValue
            }
            if let failureCountValue = payload["failureCount"] as? Int {
                failureCount += failureCountValue
            }
        }
    }

    let redaction = redactions.sorted().joined(separator: ",")
    return NetworkProxyCaptureExportSummary(
        requestCount: requestCount,
        eventCount: eventCount,
        failureCount: failureCount,
        redaction: redaction.isEmpty ? "unknown" : redaction,
        truncation: "none"
    )
}

private func makeNetworkProxyHAR(sourceURL: URL) throws -> NetworkProxyHAREnvelope {
    let data = try Data(contentsOf: sourceURL)
    let lines = String(data: data, encoding: .utf8)?
        .split(whereSeparator: \.isNewline)
        .map(String.init) ?? []
    let decoder = JSONDecoder()
    let entries = lines.compactMap { line -> NetworkProxyHAREntry? in
        guard let lineData = line.data(using: .utf8),
              let event = try? decoder.decode(NetworkProxyServeEvent.self, from: lineData),
              event.ok,
              event.event == "proxy.serve.request",
              let method = event.method else {
            return nil
        }
        return networkProxyHAREntry(from: event, method: method)
    }
    return NetworkProxyHAREnvelope(log: NetworkProxyHARLog(
        version: "1.2",
        creator: NetworkProxyHARCreator(name: "TritonKit device proxy serve", version: "0.1"),
        entries: entries
    ))
}

private func networkProxyHAREntry(from event: NetworkProxyServeEvent, method: String) -> NetworkProxyHAREntry {
    let url = networkProxyHARURL(from: event)
    let response = networkProxyHARResponse(for: event)
    let waitMs = event.throttleDelayMs ?? 0
    return NetworkProxyHAREntry(
        startedDateTime: "1970-01-01T00:00:00Z",
        time: waitMs,
        request: NetworkProxyHARRequest(
            method: method,
            url: url,
            httpVersion: "HTTP/1.1",
            cookies: [],
            headers: event.headerNames.map { NetworkProxyHARNameValue(name: $0, value: "<redacted>") },
            queryString: networkProxyHARQueryItems(url: url),
            headersSize: -1,
            bodySize: 0
        ),
        response: response,
        cache: [:],
        timings: NetworkProxyHARTimings(send: 0, wait: waitMs, receive: 0),
        comment: networkProxyHARComment(for: event)
    )
}

private func networkProxyHARComment(for event: NetworkProxyServeEvent) -> String {
    var parts = [
        "metadata-only capture",
        "captureMode=\(event.captureMode ?? "unknown")",
        "policyAction=\(event.policyAction ?? "unknown")",
    ]
    if let mockRuleId = event.mockRuleId, !mockRuleId.isEmpty {
        parts.append("mockRuleId=\(mockRuleId)")
    }
    if let throttleDelayMs = event.throttleDelayMs {
        parts.append("throttleDelayMs=\(throttleDelayMs)")
    }
    parts.append("header values, bodies, TLS contents, and response payloads are not stored")
    return parts.joined(separator: "; ")
}

private func networkProxyHARResponse(for event: NetworkProxyServeEvent) -> NetworkProxyHARResponse {
    let status: Int
    let statusText: String
    let mimeType: String
    switch event.policyAction {
    case "mocked":
        status = event.responseStatus ?? 200
        statusText = event.responseStatusText ?? "TritonKit Proxy Mock"
        mimeType = "application/json"
    case "blocked":
        status = event.responseStatus ?? 502
        statusText = event.responseStatusText ?? "TritonKit Proxy Blocked"
        mimeType = "text/plain"
    case "throttled":
        status = event.responseStatus ?? 429
        statusText = event.responseStatusText ?? "TritonKit Proxy Throttled"
        mimeType = "text/plain"
    default:
        status = 0
        statusText = "not captured"
        mimeType = "x-unknown"
    }
    return NetworkProxyHARResponse(
        status: status,
        statusText: statusText,
        httpVersion: "HTTP/1.1",
        cookies: [],
        headers: [],
        content: NetworkProxyHARContent(size: 0, mimeType: mimeType),
        redirectURL: "",
        headersSize: -1,
        bodySize: -1
    )
}

private func networkProxyHARURL(from event: NetworkProxyServeEvent) -> String {
    if let url = event.url, url.contains("://") {
        return url
    }
    if event.tunnel == true, let host = event.host {
        return "https://\(host):\(event.port ?? 443)/"
    }
    if let host = event.host {
        return "http://\(host)\(event.path ?? "/")"
    }
    return event.url ?? ""
}

private func networkProxyHARQueryItems(url: String) -> [NetworkProxyHARNameValue] {
    guard let components = URLComponents(string: url) else { return [] }
    return (components.queryItems ?? []).map {
        NetworkProxyHARNameValue(name: $0.name, value: $0.value ?? "")
    }
}

func parseNetworkProxyHTTPHeader(
    _ data: Data,
    listen: String,
    capturePath: String,
    connectionIndex: Int,
    captureMode: String = "record",
    policyAction: String = "forwarded",
    throttleDelayMs: Int? = nil
) throws -> NetworkProxyServeEvent {
    try parseNetworkProxyRequest(
        data: data,
        listen: listen,
        capturePath: capturePath,
        connectionIndex: connectionIndex,
        captureMode: captureMode,
        policyAction: policyAction,
        mockRules: nil,
        throttleDelayMs: throttleDelayMs
    ).event
}

private func handleNetworkProxyClient(
    clientFD: Int32,
    captureURL: URL,
    listen: String,
    connectionIndex: Int,
    mode: String,
    mockRules: [NetworkProxyMockRule]?,
    throttleDelayMs: Int?,
    eventWriter: ((NetworkProxyServeEvent) -> Void)?
) throws -> NetworkProxyServeEvent {
    let requestData = try readNetworkProxyRequestHeader(clientFD: clientFD)
    let parsed = try parseNetworkProxyRequest(
        data: requestData,
        listen: listen,
        capturePath: captureURL.path,
        connectionIndex: connectionIndex,
        captureMode: mode,
        policyAction: networkProxyPolicyAction(for: mode),
        mockRules: mockRules,
        throttleDelayMs: mode == "throttle" ? throttleDelayMs : nil
    )
    try appendNetworkProxyCaptureEvent(parsed.event, captureURL: captureURL)
    eventWriter?(parsed.event)

    if mode == "block" {
        writeNetworkProxyBlockedResponse(clientFD: clientFD)
        return parsed.event
    }
    if mode == "mock" {
        writeNetworkProxyMockResponse(clientFD: clientFD, response: parsed.mockResponse)
        return parsed.event
    }
    if mode == "throttle" {
        writeNetworkProxyThrottledResponse(clientFD: clientFD, delayMs: throttleDelayMs)
        return parsed.event
    }

    let upstreamFD = try connectNetworkProxyUpstream(host: parsed.upstreamHost, port: parsed.upstreamPort)
    defer { close(upstreamFD) }

    if parsed.isTunnel {
        _ = writeAll(fd: clientFD, data: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8))
        relayNetworkProxyTunnel(clientFD: clientFD, upstreamFD: upstreamFD)
    } else if let upstreamRequest = parsed.upstreamRequest {
        _ = writeAll(fd: upstreamFD, data: upstreamRequest)
        relayNetworkProxyResponse(upstreamFD: upstreamFD, clientFD: clientFD)
    }
    return parsed.event
}

private func networkProxyPolicyAction(for mode: String) -> String {
    switch mode {
    case "block":
        return "blocked"
    case "mock":
        return "mocked"
    case "throttle":
        return "throttled"
    default:
        return "forwarded"
    }
}

private func networkProxyPolicyResponse(for action: String) -> (status: Int?, statusText: String?) {
    switch action {
    case "mocked":
        return (200, "TritonKit Proxy Mock")
    case "blocked":
        return (502, "TritonKit Proxy Blocked")
    case "throttled":
        return (429, "TritonKit Proxy Throttled")
    default:
        return (nil, nil)
    }
}

private func parseNetworkProxyRequest(
    data: Data,
    listen: String,
    capturePath: String,
    connectionIndex: Int,
    captureMode: String,
    policyAction: String,
    mockRules: [NetworkProxyMockRule]?,
    throttleDelayMs: Int?
) throws -> ParsedProxyRequest {
    guard let header = String(data: data, encoding: .utf8) else {
        throw RuntimeError("Proxy request header is not UTF-8.")
    }
    let lines = header.components(separatedBy: "\r\n")
    guard let requestLine = lines.first, !requestLine.isEmpty else {
        throw RuntimeError("Proxy request is missing request line.")
    }
    let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
    guard parts.count >= 2 else {
        throw RuntimeError("Proxy request line is invalid: \(requestLine)")
    }
    let method = parts[0]
    let rawURL = parts[1]
    let headers = parseProxyHeaderLines(Array(lines.dropFirst()))
    let headerNames = headers.map(\.name).sorted()

    let target: (host: String, port: Int, path: String, tunnel: Bool)
    if method.uppercased() == "CONNECT" {
        target = try parseConnectTarget(rawURL)
    } else {
        target = try parseHTTPProxyTarget(rawURL: rawURL, headers: headers)
    }

    let mockResponse = policyAction == "mocked" ? matchNetworkProxyMockResponse(rules: mockRules, method: method, host: target.host, path: target.path) : nil
    let policyResponse = mockResponse.map { (status: $0.status, statusText: $0.statusText) } ?? networkProxyPolicyResponse(for: policyAction)
    let event = NetworkProxyServeEvent(
        ok: true,
        surface: "host.device-proxy-serve",
        event: "proxy.serve.request",
        schemaVersion: "triton.proxy.capture.v1",
        listen: listen,
        capturePath: capturePath,
        captureMode: captureMode,
        policyAction: policyAction,
        mockRuleId: mockResponse?.ruleId,
        connectionIndex: connectionIndex,
        method: method,
        url: rawURL,
        host: target.host,
        port: target.port,
        path: target.path,
        tunnel: target.tunnel,
        headerNames: headerNames,
        responseStatus: policyResponse.status,
        responseStatusText: policyResponse.statusText,
        throttleDelayMs: throttleDelayMs,
        redaction: "headers-names-only",
        error: nil
    )

    return ParsedProxyRequest(
        event: event,
        upstreamHost: target.host,
        upstreamPort: target.port,
        upstreamRequest: target.tunnel ? nil : rewriteHTTPProxyRequest(data: data, path: target.path, requestLine: requestLine),
        isTunnel: target.tunnel,
        mockResponse: mockResponse
    )
}

private func writeNetworkProxyBlockedResponse(clientFD: Int32) {
    let body = "TritonKit proxy block mode denied this request.\n"
    let response = (
        "HTTP/1.1 502 TritonKit Proxy Blocked\r\n" +
        "Content-Type: text/plain; charset=utf-8\r\n" +
        "Content-Length: \(body.utf8.count)\r\n" +
        "Connection: close\r\n" +
        "\r\n" +
        body
    )
    _ = writeAll(fd: clientFD, data: Data(response.utf8))
}

private func writeNetworkProxyMockResponse(clientFD: Int32, response: NetworkProxyMockResponse?) {
    let body = response?.body ?? (#"{"ok":true,"mocked":true,"source":"triton.device.proxy.serve"}"# + "\n")
    let status = response?.status ?? 200
    let statusText = response?.statusText ?? "TritonKit Proxy Mock"
    let headers = response?.headers ?? ["Content-Type": "application/json; charset=utf-8"]
    let response = (
        "HTTP/1.1 \(status) \(statusText)\r\n" +
        headers.map { "\($0.key): \($0.value)\r\n" }.sorted().joined() +
        "Content-Length: \(body.utf8.count)\r\n" +
        "Connection: close\r\n" +
        "\r\n" +
        body
    )
    _ = writeAll(fd: clientFD, data: Data(response.utf8))
}

private func loadNetworkProxyMockRules(path: String) throws -> [NetworkProxyMockRule] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    let file = try JSONDecoder().decode(NetworkProxyMockRulesFile.self, from: data)
    guard file.schemaVersion == nil || file.schemaVersion == "triton.proxy.mock-rules.v1" else {
        throw RuntimeError("Unsupported proxy mock rules schemaVersion: \(file.schemaVersion ?? "<missing>").")
    }
    try file.rules.forEach(validateNetworkProxyMockRule)
    return file.rules
}

private func validateNetworkProxyMockRule(_ rule: NetworkProxyMockRule) throws {
    if let status = rule.status, !(100...599).contains(status) {
        throw RuntimeError("Proxy mock rule status must be between 100 and 599.")
    }
    if let statusText = rule.statusText {
        try validateNetworkProxyHTTPTokenValue(statusText, field: "statusText")
    }
    for (name, value) in rule.headers ?? [:] {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuntimeError("Proxy mock rule header names must be non-empty.")
        }
        try validateNetworkProxyHTTPTokenValue(name, field: "header name")
        try validateNetworkProxyHTTPTokenValue(value, field: "header value")
    }
}

private func validateNetworkProxyHTTPTokenValue(_ value: String, field: String) throws {
    if value.contains("\r") || value.contains("\n") {
        throw RuntimeError("Proxy mock rule \(field) must not contain CR or LF.")
    }
}

private func matchNetworkProxyMockResponse(rules: [NetworkProxyMockRule]?, method: String, host: String, path: String) -> NetworkProxyMockResponse? {
    guard let rule = rules?.first(where: { networkProxyMockRule($0, matchesMethod: method, host: host, path: path) }) else {
        return nil
    }
    return NetworkProxyMockResponse(
        ruleId: rule.id,
        status: rule.status ?? 200,
        statusText: rule.statusText ?? "TritonKit Proxy Mock",
        headers: rule.headers ?? ["Content-Type": "application/json; charset=utf-8"],
        body: rule.body ?? (#"{"ok":true,"mocked":true,"source":"triton.device.proxy.serve"}"# + "\n")
    )
}

private func networkProxyMockRule(_ rule: NetworkProxyMockRule, matchesMethod method: String, host: String, path: String) -> Bool {
    if let ruleMethod = rule.method, ruleMethod.uppercased() != method.uppercased() {
        return false
    }
    if let ruleHost = rule.host, ruleHost.lowercased() != host.lowercased() {
        return false
    }
    if let rulePath = rule.path, rulePath != path {
        return false
    }
    if let rulePathPrefix = rule.pathPrefix, !path.hasPrefix(rulePathPrefix) {
        return false
    }
    return true
}

private func writeNetworkProxyThrottledResponse(clientFD: Int32, delayMs: Int?) {
    if let delayMs, delayMs > 0 {
        usleep(useconds_t(delayMs * 1000))
    }
    let body = "TritonKit proxy throttle mode rate-limited this request.\n"
    let response = (
        "HTTP/1.1 429 TritonKit Proxy Throttled\r\n" +
        "Content-Type: text/plain; charset=utf-8\r\n" +
        "Content-Length: \(body.utf8.count)\r\n" +
        "Retry-After: 1\r\n" +
        "Connection: close\r\n" +
        "\r\n" +
        body
    )
    _ = writeAll(fd: clientFD, data: Data(response.utf8))
}

private func parseProxyHeaderLines(_ lines: [String]) -> [(name: String, value: String)] {
    lines.compactMap { line in
        guard !line.isEmpty else { return nil }
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private func parseConnectTarget(_ rawTarget: String) throws -> (host: String, port: Int, path: String, tunnel: Bool) {
    let parts = rawTarget.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2, let port = Int(parts[1]), !parts[0].isEmpty else {
        throw RuntimeError("CONNECT target must be host:port.")
    }
    return (parts[0], port, rawTarget, true)
}

private func parseHTTPProxyTarget(rawURL: String, headers: [(name: String, value: String)]) throws -> (host: String, port: Int, path: String, tunnel: Bool) {
    if let components = URLComponents(string: rawURL), let host = components.host {
        let scheme = components.scheme?.lowercased()
        let port = components.port ?? (scheme == "https" ? 443 : 80)
        var path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery, !query.isEmpty {
            path += "?\(query)"
        }
        return (host, port, path, false)
    }
    guard let hostHeader = headers.first(where: { $0.name.lowercased() == "host" })?.value else {
        throw RuntimeError("HTTP proxy request is missing Host header.")
    }
    let hostParts = hostHeader.split(separator: ":", maxSplits: 1).map(String.init)
    let host = hostParts[0]
    let port = hostParts.count == 2 ? (Int(hostParts[1]) ?? 80) : 80
    return (host, port, rawURL.isEmpty ? "/" : rawURL, false)
}

private func rewriteHTTPProxyRequest(data: Data, path: String, requestLine: String) -> Data {
    guard let header = String(data: data, encoding: .utf8),
          let firstLineRange = header.range(of: requestLine) else {
        return data
    }
    let method = requestLine.split(separator: " ", maxSplits: 2).first.map(String.init) ?? "GET"
    let version = requestLine.split(separator: " ").last.map(String.init) ?? "HTTP/1.1"
    var rewritten = header
    rewritten.replaceSubrange(firstLineRange, with: "\(method) \(path) \(version)")
    rewritten = rewritten
        .components(separatedBy: "\r\n")
        .filter { !$0.lowercased().hasPrefix("proxy-connection:") }
        .joined(separator: "\r\n")
    return Data(rewritten.utf8)
}

private func readNetworkProxyRequestHeader(clientFD: Int32) throws -> Data {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while data.count < 65_536 {
        let readCount = read(clientFD, &buffer, buffer.count)
        if readCount < 0 {
            if errno == EINTR { continue }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        if readCount == 0 { break }
        data.append(buffer, count: readCount)
        if data.range(of: Data("\r\n\r\n".utf8)) != nil { return data }
    }
    throw RuntimeError("Proxy request header exceeded 64 KiB or ended before headers completed.")
}

private func appendNetworkProxyCaptureEvent(_ event: NetworkProxyServeEvent, captureURL: URL) throws {
    try FileManager.default.createDirectory(at: captureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let line = try encodeCompactJSON(event) + "\n"
    if FileManager.default.fileExists(atPath: captureURL.path) {
        let handle = try FileHandle(forWritingTo: captureURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
    } else {
        try Data(line.utf8).write(to: captureURL)
    }
}

private func networkProxyServeCaptureURL(outputDirectory: String) throws -> URL {
    guard !outputDirectory.isEmpty else {
        throw RuntimeError("device proxy serve requires --output <dir>.")
    }
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    return outputURL.appendingPathComponent("requests.ndjson")
}

private func makeNetworkProxyListenSocket(endpoint: NetworkProxyEndpoint) throws -> Int32 {
    var hints = addrinfo(
        ai_flags: AI_PASSIVE,
        ai_family: AF_UNSPEC,
        ai_socktype: SOCK_STREAM,
        ai_protocol: IPPROTO_TCP,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )
    var result: UnsafeMutablePointer<addrinfo>?
    let status = getaddrinfo(endpoint.host, String(endpoint.port), &hints, &result)
    guard status == 0, let result else {
        throw RuntimeError("Unable to resolve proxy listen endpoint \(endpoint.host):\(endpoint.port).")
    }
    defer { freeaddrinfo(result) }

    var cursor: UnsafeMutablePointer<addrinfo>? = result
    while let current = cursor {
        let fd = socket(current.pointee.ai_family, current.pointee.ai_socktype, current.pointee.ai_protocol)
        if fd >= 0 {
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            if bind(fd, current.pointee.ai_addr, current.pointee.ai_addrlen) == 0, listen(fd, SOMAXCONN) == 0 {
                return fd
            }
            close(fd)
        }
        cursor = current.pointee.ai_next
    }
    throw RuntimeError("Unable to bind proxy listener \(endpoint.host):\(endpoint.port).")
}

private func connectNetworkProxyUpstream(host: String, port: Int) throws -> Int32 {
    var hints = addrinfo(
        ai_flags: 0,
        ai_family: AF_UNSPEC,
        ai_socktype: SOCK_STREAM,
        ai_protocol: IPPROTO_TCP,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )
    var result: UnsafeMutablePointer<addrinfo>?
    let status = getaddrinfo(host, String(port), &hints, &result)
    guard status == 0, let result else {
        throw RuntimeError("Unable to resolve upstream \(host):\(port).")
    }
    defer { freeaddrinfo(result) }

    var cursor: UnsafeMutablePointer<addrinfo>? = result
    while let current = cursor {
        let fd = socket(current.pointee.ai_family, current.pointee.ai_socktype, current.pointee.ai_protocol)
        if fd >= 0 {
            if connect(fd, current.pointee.ai_addr, current.pointee.ai_addrlen) == 0 {
                return fd
            }
            close(fd)
        }
        cursor = current.pointee.ai_next
    }
    throw RuntimeError("Unable to connect upstream \(host):\(port).")
}

private func relayNetworkProxyResponse(upstreamFD: Int32, clientFD: Int32) {
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
        let readCount = read(upstreamFD, &buffer, buffer.count)
        if readCount <= 0 { return }
        if writeAll(fd: clientFD, data: Data(buffer[0..<readCount])) == false { return }
    }
}

private func relayNetworkProxyTunnel(clientFD: Int32, upstreamFD: Int32) {
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async {
        copySocketData(from: clientFD, to: upstreamFD)
        shutdown(upstreamFD, SHUT_WR)
        group.leave()
    }
    group.enter()
    DispatchQueue.global().async {
        copySocketData(from: upstreamFD, to: clientFD)
        shutdown(clientFD, SHUT_WR)
        group.leave()
    }
    group.wait()
}

private func copySocketData(from sourceFD: Int32, to destinationFD: Int32) {
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
        let readCount = read(sourceFD, &buffer, buffer.count)
        if readCount <= 0 { return }
        if writeAll(fd: destinationFD, data: Data(buffer[0..<readCount])) == false { return }
    }
}

@discardableResult
private func writeAll(fd: Int32, data: Data) -> Bool {
    data.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return true }
        var sent = 0
        while sent < data.count {
            let written = write(fd, base.advanced(by: sent), data.count - sent)
            if written <= 0 {
                if errno == EINTR { continue }
                return false
            }
            sent += written
        }
        return true
    }
}
