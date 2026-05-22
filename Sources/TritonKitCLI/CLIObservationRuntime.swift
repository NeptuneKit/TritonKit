import ArgumentParser
import Foundation
import TritonKitShared

func runObserve(
    action: String,
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    maxNodes: Int?,
    output: String?,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        let response: ObserveOutput
        switch platform {
        case .harmony:
            response = try await observeHarmony(
                action: action,
                target: target,
                hdc: hdc,
                runtimeBaseURL: runtimeBaseURL,
                maxNodes: maxNodes,
                output: output
            )
        case .ios:
            response = try await observeIOS(
                action: action,
                target: target,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                maxNodes: maxNodes
            )
        }
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("\(response.platform) \(response.action) nodes=\(response.nodes.count) partial=\(response.partial)")
            for node in response.nodes.prefix(30) {
                let text = node.text.map { " \"\($0)\"" } ?? ""
                let identifier = node.identifier.map { " #\($0)" } ?? ""
                let frame = node.frame.map { " \(formatRect($0))" } ?? ""
                print("\(node.source) \(node.role ?? "-")\(text)\(identifier)\(frame)")
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

func observeHarmony(
    action: String,
    target: String,
    hdc: String,
    runtimeBaseURL: String?,
    maxNodes: Int?,
    output: String?
) async throws -> ObserveOutput {
    let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
    let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: output)
    var nodes = try TKHarmonyLayoutParser.nodeSummaries(in: layout.data).map(observeNode(fromHarmony:))
    if let maxNodes {
        nodes = Array(nodes.prefix(maxNodes))
    }
    var sources = [
        ObserveSourceOutput(
            name: "host-layout",
            available: true,
            reason: nil,
            artifact: layout.localPath,
            sourceCommands: layout.sourceCommands
        ),
        ObserveSourceOutput(
            name: "runtime-tree",
            available: false,
            reason: runtimeBaseURL == nil ? "runtime-base-url not provided" : "runtime fusion not requested",
            artifact: nil,
            sourceCommands: []
        ),
        ObserveSourceOutput(
            name: "webview-provider",
            available: false,
            reason: "provider not registered",
            artifact: nil,
            sourceCommands: []
        ),
    ]
    if let runtimeBaseURL {
        do {
            let runtimeData = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeSnapshot, queryItems: [
                URLQueryItem(name: "include", value: "app,scene,route,ax,geometry")
            ])
            let snapshot = try JSONDecoder().decode(TKRuntimeSnapshotResponse.self, from: runtimeData)
            let runtimeNodes = observeNodes(fromAX: snapshot.ax ?? [], source: "runtime-tree", prefix: "harmony-runtime")
            nodes.append(contentsOf: maxNodes.map { Array(runtimeNodes.prefix(max(0, $0 - nodes.count))) } ?? runtimeNodes)
            sources[1] = ObserveSourceOutput(
                name: "runtime-tree",
                available: true,
                reason: nil,
                artifact: nil,
                sourceCommands: ["GET \(runtimeBaseURL)/snapshot"]
            )
        } catch {
            sources[1] = ObserveSourceOutput(
                name: "runtime-tree",
                available: false,
                reason: "\(error)",
                artifact: nil,
                sourceCommands: ["GET \(runtimeBaseURL)/snapshot"]
            )
        }
    }
    return ObserveOutput(
        ok: true,
        action: action,
        platform: "harmony",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        partial: sources.contains { !$0.available },
        target: selected.target,
        sources: sources,
        nodes: nodes,
        artifacts: [layout.localPath],
        sourceCommands: layout.sourceCommands,
        note: "Host layout proves visible text, bounds, and coordinate actions only; DOM, JavaScript, and WebView bridge remain unavailable without a provider."
    )
}

func observeIOS(
    action: String,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    maxNodes: Int?
) async throws -> ObserveOutput {
    let snapshotData: Data
    let targetID: String
    if let runtimeBaseURL {
        snapshotData = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeSnapshot, queryItems: [
            URLQueryItem(name: "include", value: "app,scene,route,ax,geometry")
        ])
        targetID = runtimeBaseURL
    } else {
        let (summary, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
        targetID = summary.id
        let request = TKRuntimeSnapshotRequest(include: ["app", "scene", "route", "ax", "geometry"], maxAXNodes: maxNodes)
        let payload = try JSONEncoder().encode(request)
        snapshotData = try await client.request(type: "runtimeSnapshot", payload: payload)
    }
    let snapshot = try JSONDecoder().decode(TKRuntimeSnapshotResponse.self, from: snapshotData)
    var nodes = observeNodes(fromAX: snapshot.ax ?? [], source: "runtime-tree", prefix: "ios-runtime")
    if let maxNodes {
        nodes = Array(nodes.prefix(maxNodes))
    }
    return ObserveOutput(
        ok: true,
        action: action,
        platform: "ios",
        capturedAt: snapshot.capturedAt,
        partial: true,
        target: targetID,
        sources: [
            ObserveSourceOutput(name: "host-layout", available: false, reason: "iOS host layout is not available in P0; use embedded runtime AX", artifact: nil, sourceCommands: []),
            ObserveSourceOutput(name: "runtime-tree", available: true, reason: nil, artifact: nil, sourceCommands: runtimeBaseURL.map { ["GET \($0)/snapshot"] } ?? ["triton runtimeSnapshot request"]),
            ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
        ],
        nodes: nodes,
        artifacts: snapshot.artifacts.map(\.name),
        sourceCommands: runtimeBaseURL.map { ["GET \($0)/snapshot"] } ?? ["triton runtimeSnapshot request"],
        note: "iOS P0 observe uses the DEBUG embedded runtime AX tree. WebView DOM, JavaScript, and bridge state require a Web provider."
    )
}

func observeNodes(fromAX nodes: [TKAXNode], source: String, prefix: String) -> [ObserveNodeOutput] {
    TKFlattenAXNodes(nodes).map(\.node).enumerated().map { offset, node in
        observeNode(fromAX: node, source: source, nodeID: "\(prefix):\(node.targetOID ?? node.viewOID ?? UInt(offset + 1))")
    }
}

func observeNode(fromAX node: TKAXNode, source: String, nodeID: String) -> ObserveNodeOutput {
    let webCandidate = isWebCandidate(
        role: node.role,
        className: node.className,
        identifier: node.identifier,
        text: node.label ?? node.title ?? node.value
    )
    var capabilities = ["visible"]
    if node.enabled && !node.hidden && !webCandidate {
        capabilities.append("tap")
    }
    if node.targetOID != nil || node.viewOID != nil {
        capabilities.append("runtime-oid")
    }
    let missing = ["webview.url", "webview.dom", "webview.bridge-call"]
    return ObserveNodeOutput(
        nodeID: nodeID,
        source: source,
        role: node.role,
        text: node.label ?? node.title ?? node.value,
        identifier: node.identifier,
        frame: node.frame,
        enabled: node.enabled,
        focused: node.focused,
        hidden: node.hidden,
        candidateOnly: webCandidate,
        confidence: webCandidate ? 0.78 : 0.9,
        capabilities: capabilities,
        missingCapabilities: missing
    )
}

func observeNode(fromHarmony node: TKHarmonyLayoutNodeSummary) -> ObserveNodeOutput {
    let webCandidate = isWebCandidate(
        role: node.type,
        className: nil,
        identifier: node.identifier ?? node.key ?? node.accessibilityID,
        text: node.text ?? node.originalText
    )
    var capabilities: [String] = []
    if node.visible != false {
        capabilities.append("visible")
    }
    if node.bounds != nil {
        capabilities.append("tap")
    }
    if node.scrollable == true {
        capabilities.append("scroll")
    }
    let missing = webCandidate
        ? ["webview.url", "webview.dom", "webview.bridge-call", "semantic-action"]
        : ["semantic-action"]
    return ObserveNodeOutput(
        nodeID: "harmony:host:\(node.nodeID)",
        source: "host-layout",
        role: node.type,
        text: node.text ?? node.originalText,
        identifier: node.identifier ?? node.key ?? node.accessibilityID,
        frame: node.bounds,
        enabled: node.enabled,
        focused: node.focused,
        hidden: node.visible.map { !$0 },
        candidateOnly: webCandidate,
        confidence: webCandidate ? 0.72 : 0.7,
        capabilities: capabilities,
        missingCapabilities: missing
    )
}

func isWebCandidate(role: String?, className: String?, identifier: String? = nil, text: String? = nil) -> Bool {
    webViewCandidateScore(role: role, className: className, identifier: identifier, text: text) != nil
}

func runNodeResolve(
    platform: ObservationPlatform,
    text: String?,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    index: Int?,
    within: String?,
    at: String?,
    all: Bool,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        if within != nil && at != nil {
            if outputFormat == .json {
                try printValidationError("--within and --at cannot be used together")
                throw ExitCode.failure
            }
            throw RuntimeError("--within and --at cannot be used together")
        }
        guard let text, !text.isEmpty else {
            if outputFormat == .json {
                try printValidationError("`triton node resolve` requires --text")
                throw ExitCode.failure
            }
            throw RuntimeError("`triton node resolve` requires --text")
        }
        let bounds = try within.map(parseBounds)
        let point = try at.map(parsePoint)
        let response: NodeResolveOutput
        switch platform {
        case .harmony:
            response = try resolveHarmonyNode(
                query: text,
                target: target,
                hdc: hdc,
                index: index,
                within: bounds,
                at: point,
                includeCandidates: all
            )
        case .ios:
            response = try await resolveIOSNode(
                query: text,
                target: target,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                index: index,
                within: bounds,
                at: point,
                includeCandidates: all
            )
        }
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("query: \(response.query)")
            print("platform: \(response.platform)")
            print("source: \(response.node.source)")
            print("nodeID: \(response.node.nodeID)")
            if let role = response.node.role { print("role: \(role)") }
            if let text = response.node.text { print("text: \(text)") }
            if let identifier = response.node.identifier { print("identifier: \(identifier)") }
            if let frame = response.node.frame { print("frame: \(formatRect(frame))") }
            print("matchIndex: \(response.matchIndex)")
            print("matchCount: \(response.matchCount)")
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func resolveHarmonyNode(
    query: String,
    target: String,
    hdc: String,
    index: Int?,
    within: TKRect?,
    at: (x: Double, y: Double)?,
    includeCandidates: Bool
) throws -> NodeResolveOutput {
    let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
    let layout = try dumpHarmonyLayout(selected: selected, hdc: hdc, output: nil)
    let candidates = try TKHarmonyLayoutParser.nodeSummaries(in: layout.data)
        .map(observeNode(fromHarmony:))
        .filter { node in
            observeNode(node, matches: query)
        }
        .filter { node in
            guard let within else { return true }
            guard let frame = node.frame else { return false }
            return TKRectIntersects(frame, within)
        }
        .filter { node in
            guard let at else { return true }
            guard let frame = node.frame else { return false }
            return frame.contains(x: at.x, y: at.y)
        }
    return try selectedNodeResolveOutput(
        platform: "harmony",
        query: query,
        candidates: candidates,
        index: index,
        includeCandidates: includeCandidates,
        sourceCommands: layout.sourceCommands
    )
}

func resolveIOSNode(
    query: String,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    index: Int?,
    within: TKRect?,
    at: (x: Double, y: Double)?,
    includeCandidates: Bool
) async throws -> NodeResolveOutput {
    let nodes: [ObserveNodeOutput]
    let sourceCommands: [String]
    if let runtimeBaseURL {
        let runtimeData = try await EmbeddedRuntimeHTTPClient(baseURL: runtimeBaseURL).request(.runtimeSnapshot, queryItems: [
            URLQueryItem(name: "include", value: "ax")
        ])
        let snapshot = try JSONDecoder().decode(TKRuntimeSnapshotResponse.self, from: runtimeData)
        nodes = observeNodes(fromAX: snapshot.ax ?? [], source: "runtime-tree", prefix: "ios-runtime")
        sourceCommands = ["GET \(runtimeBaseURL)/snapshot"]
    } else {
        let (_, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: true)
        let data = try await client.request(type: "accessibility")
        let axNodes = try JSONDecoder().decode([TKAXNode].self, from: data)
        nodes = observeNodes(fromAX: axNodes, source: "runtime-tree", prefix: "ios-runtime")
        sourceCommands = ["triton accessibility request"]
    }
    let candidates = nodes
        .filter { observeNode($0, matches: query) }
        .filter { node in
            guard let within else { return true }
            guard let frame = node.frame else { return false }
            return TKRectIntersects(frame, within)
        }
        .filter { node in
            guard let at else { return true }
            guard let frame = node.frame else { return false }
            return frame.contains(x: at.x, y: at.y)
        }
    return try selectedNodeResolveOutput(
        platform: "ios",
        query: query,
        candidates: candidates,
        index: index,
        includeCandidates: includeCandidates,
        sourceCommands: sourceCommands
    )
}

func selectedNodeResolveOutput(
    platform: String,
    query: String,
    candidates: [ObserveNodeOutput],
    index: Int?,
    includeCandidates: Bool,
    sourceCommands: [String]
) throws -> NodeResolveOutput {
    if let index, index <= 0 {
        throw RuntimeError("--index must be greater than 0")
    }
    guard !candidates.isEmpty else {
        throw RuntimeError("No current UI node matched query: \(query)")
    }
    let selectedIndex = index ?? 1
    guard selectedIndex <= candidates.count else {
        throw RuntimeError("Only \(candidates.count) UI node(s) matched query: \(query); cannot select --index \(selectedIndex)")
    }
    return NodeResolveOutput(
        ok: true,
        action: "node.resolve",
        platform: platform,
        query: query,
        matchIndex: selectedIndex,
        matchCount: candidates.count,
        node: candidates[selectedIndex - 1],
        candidates: includeCandidates ? candidates : nil,
        sourceCommands: sourceCommands
    )
}

func observeNode(_ node: ObserveNodeOutput, matches query: String) -> Bool {
    [node.text, node.identifier, node.role, node.nodeID]
        .compactMap { $0 }
        .contains(query)
}
