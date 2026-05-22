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
    do {
        let list = try await webViewCandidates(action: "webview.current", platform: platform, target: target, hdc: hdc, host: host, port: port, runtimeBaseURL: runtimeBaseURL, output: output)
        let selected = try selectCurrentWebView(from: list.candidates, webViewID: webViewID)
        let response = TKWebViewCurrentResponse(ok: true, action: "webview.current", platform: list.platform, capturedAt: list.capturedAt, target: list.target, webView: selected, sources: list.sources, sourceCommands: list.sourceCommands, note: list.note)
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print(renderWebViewCandidate(selected))
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony {
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
    case .harmony:
        return try harmonyWebViewCandidates(action: action, target: target, hdc: hdc, runtimeBaseURL: runtimeBaseURL, output: output)
    }
}

private func iOSWebViewCandidates(action: String, target: String, host: String, port: Int, runtimeBaseURL: String?) async throws -> TKWebViewListResponse {
    let snapshotData: Data
    let targetID: String
    let sourceCommands: [String]
    if let runtimeBaseURL {
        snapshotData = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeSnapshot, queryItems: [URLQueryItem(name: "include", value: "ax")])
        targetID = runtimeBaseURL
        sourceCommands = ["GET \(runtimeBaseURL)/snapshot"]
    } else {
        let (summary, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
        targetID = summary.id
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
        current: try? selectCurrentWebView(from: candidates, webViewID: nil),
        candidates: candidates,
        sources: [
            TKWebViewSource(name: "runtime-tree", available: true, sourceCommands: sourceCommands),
            TKWebViewSource(name: "webview-provider", available: false, reason: "provider not registered"),
        ],
        sourceCommands: sourceCommands,
        note: "iOS WebView candidates come from DEBUG runtime AX. URL, DOM, JavaScript, bridge calls, and DOM input require a WebView provider."
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
        current: try? selectCurrentWebView(from: candidates, webViewID: nil),
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

private func selectCurrentWebView(from candidates: [TKWebViewDescriptor], webViewID: String?) throws -> TKWebViewDescriptor {
    if let webViewID {
        guard let selected = candidates.first(where: { $0.webViewID == webViewID || $0.nodeID == webViewID }) else {
            throw RuntimeError("No WebView candidate matched --webview-id \(webViewID)")
        }
        return selected
    }
    guard let first = candidates.first else {
        throw RuntimeError("No visible WebView candidate found")
    }
    if candidates.count > 1, abs(first.confidence - candidates[1].confidence) < 0.05 {
        throw RuntimeError("Multiple visible WebView candidates matched; run `triton webview list --json` and pass --webview-id")
    }
    return first
}

private func webViewDescriptorSort(_ lhs: TKWebViewDescriptor, _ rhs: TKWebViewDescriptor) -> Bool {
    if lhs.confidence != rhs.confidence {
        return lhs.confidence > rhs.confidence
    }
    let leftArea = (lhs.frame?.width ?? 0) * (lhs.frame?.height ?? 0)
    let rightArea = (rhs.frame?.width ?? 0) * (rhs.frame?.height ?? 0)
    return leftArea > rightArea
}

private func renderWebViewCandidate(_ candidate: TKWebViewDescriptor) -> String {
    let frame = candidate.frame.map { " frame=\(formatRect($0))" } ?? ""
    let identifier = candidate.identifier.map { " identifier=\($0)" } ?? ""
    let text = candidate.text.map { " text=\"\($0)\"" } ?? ""
    return "\(candidate.webViewID) source=\(candidate.source) candidateOnly=\(candidate.candidateOnly) confidence=\(candidate.confidence)\(identifier)\(text)\(frame)"
}
