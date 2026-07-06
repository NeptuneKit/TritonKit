import ArgumentParser
import Foundation
import TritonKitShared

typealias AndroidObserveHostRunner = (TKHostCommand) throws -> HostProcessResult

private struct AndroidBridgeTreeEnvelope: Decodable {
    let status: String
    let result: AndroidBridgeNode
}

private struct AndroidBridgeNode: Decodable {
    let resourceId: String?
    let uniqueId: String?
    let packageName: String?
    let className: String?
    let text: String?
    let contentDescription: String?
    let boundsInScreen: AndroidBridgeBounds?
    let clickable: Bool?
    let scrollable: Bool?
    let focused: Bool?
    let enabled: Bool?
    let visibleToUser: Bool?
    let children: [AndroidBridgeNode]?

    enum CodingKeys: String, CodingKey {
        case resourceId
        case uniqueId
        case packageName = "package"
        case className
        case text
        case contentDescription
        case boundsInScreen
        case clickable
        case scrollable
        case focused
        case enabled
        case visibleToUser
        case children
    }
}

private struct AndroidBridgeBounds: Decodable {
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double

    var rect: TKRect {
        TKRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }
}

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
    outline: Bool = false,
    format: ClientOutputFormat,
    json: Bool,
    iosHostAX: Bool = false
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        var response: ObserveOutput
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
        case .android:
            let selected = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: target, platform: .android, ready: runtimeBaseURL == nil),
                hdc: hdc
            )
            response = try observeAndroid(
                action: action,
                selected: selected.target,
                adb: "adb",
                output: output
            )
        case .ios:
            response = try await observeIOS(
                action: action,
                target: target,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                maxNodes: maxNodes,
                iosHostAX: iosHostAX
            )
        }
        if outline {
            response = try observeOutputWithNodeOutline(response, workspace: FileManager.default.currentDirectoryPath)
        }
        switch outputFormat {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print("\(response.platform) \(response.action) nodes=\(response.nodes.count) partial=\(response.partial)")
            if let outline = response.outline, !outline.isEmpty {
                for alias in outline {
                    let text = alias.text.map { " \"\($0)\"" } ?? ""
                    let identifier = alias.identifier.map { " #\($0)" } ?? ""
                    let frame = alias.frame.map { " \(formatRect($0))" } ?? ""
                    print("\(alias.alias) \(alias.source) \(alias.role ?? "-")\(text)\(identifier)\(frame)")
                }
                return
            }
            for node in response.nodes.prefix(30) {
                let text = node.text.map { " \"\($0)\"" } ?? ""
                let identifier = node.identifier.map { " #\($0)" } ?? ""
                let frame = node.frame.map { " \(formatRect($0))" } ?? ""
                print("\(node.source) \(node.role ?? "-")\(text)\(identifier)\(frame)")
            }
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony || platform == .android {
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

func observeAndroid(
    action: String,
    selected: HostDeviceTarget,
    adb: String = "adb",
    output: String?,
    runner: AndroidObserveHostRunner = { command in try runHostCommand(command) }
) throws -> ObserveOutput {
    if let bridge = try? observeAndroidBridge(action: action, selected: selected, output: output, runner: runner) {
        return bridge
    }

    let remotePath = "/sdcard/window_dump.xml"
    let dumpCommand = TKAndroidADBCommand.uiautomatorDump(serial: selected.rawTarget, remotePath: remotePath, executable: adb)
    let dumpResult = try runner(dumpCommand)
    guard dumpResult.exitCode == 0 else {
        throw HostCommandRunError.nonZeroExit(command: dumpCommand, result: dumpResult)
    }

    let readCommand = TKAndroidADBCommand.readFile(serial: selected.rawTarget, remotePath: remotePath, executable: adb)
    let readResult = try runner(readCommand)
    guard readResult.exitCode == 0 else {
        throw HostCommandRunError.nonZeroExit(command: readCommand, result: readResult)
    }

    let artifactPath = output ?? defaultAndroidObserveArtifactPath(serial: selected.id)
    try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: artifactPath).deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try readResult.stdoutData.write(to: URL(fileURLWithPath: artifactPath), options: .atomic)

    let nodes = try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: readResult.stdoutData)
        .enumerated()
        .map { offset, node in observeNode(fromAndroid: node, index: offset) }

    let sourceCommands = [dumpResult.sourceCommand, readResult.sourceCommand]
    let source = ObserveSourceOutput(
        name: "host-layout",
        available: true,
        reason: nil,
        artifact: artifactPath,
        sourceCommands: sourceCommands
    )
    return ObserveOutput(
        ok: true,
        action: action,
        platform: "android",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        partial: true,
        target: selected.id,
        sources: [
            source,
            ObserveSourceOutput(
                name: "runtime-tree",
                available: false,
                reason: "Android embedded runtime fusion is not available in P0",
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
        ],
        nodes: nodes,
        artifacts: [artifactPath],
        sourceCommands: sourceCommands,
        note: "Android P0 observe uses host-side UIAutomator XML. WebView DOM, JavaScript, and embedded runtime fusion remain unavailable."
    )
}

private func observeAndroidBridge(
    action: String,
    selected: HostDeviceTarget,
    output: String?,
    runner: AndroidObserveHostRunner
) throws -> ObserveOutput {
    let endpoint = "http://127.0.0.1:19422"
    let tokenCommand = TKHostCommand(executable: "adb", arguments: ["-s", selected.rawTarget, "shell", "content", "query", "--uri", "content://\(androidBridgePackageName)/auth_token"], sensitiveOutput: true)
    let tokenResult = try runner(tokenCommand)
    guard let token = androidBridgeAuthToken(from: tokenResult.stdout) else {
        throw RuntimeError("Android bridge auth token is not available.")
    }
    let treeCommand = TKHostCommand(executable: "/usr/bin/curl", arguments: ["-fsS", "--max-time", "5", "-H", "Authorization: Bearer \(token)", "\(endpoint)/a11y_tree_full?filter=true"], sensitiveOutput: true)
    let treeResult = try runner(treeCommand)
    guard treeResult.exitCode == 0 else {
        throw HostCommandRunError.nonZeroExit(command: treeCommand, result: treeResult)
    }
    let envelope = try JSONDecoder().decode(AndroidBridgeTreeEnvelope.self, from: treeResult.stdoutData)
    guard envelope.status == "success" else {
        throw RuntimeError("Android bridge tree returned status=\(envelope.status).")
    }

    let artifactPath = output ?? defaultAndroidBridgeObserveArtifactPath(serial: selected.id)
    try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: artifactPath).deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try treeResult.stdoutData.write(to: URL(fileURLWithPath: artifactPath), options: .atomic)

    let sourceCommands = [
        tokenResult.sourceCommand,
        "/usr/bin/curl -fsS --max-time 5 -H 'Authorization: Bearer <redacted>' \(endpoint)/a11y_tree_full?filter=true",
    ]
    let source = ObserveSourceOutput(
        name: "android-bridge",
        available: true,
        reason: nil,
        artifact: artifactPath,
        sourceCommands: sourceCommands
    )
    return ObserveOutput(
        ok: true,
        action: action,
        platform: "android",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        partial: true,
        target: selected.id,
        primarySource: source,
        sources: [
            source,
            ObserveSourceOutput(name: "host-layout", available: false, reason: "UIAutomator fallback was not used because Android bridge tree is available", artifact: nil, sourceCommands: []),
            ObserveSourceOutput(name: "runtime-tree", available: false, reason: "Android embedded runtime fusion is not available in P0", artifact: nil, sourceCommands: []),
            ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
        ],
        nodes: observeNodes(fromAndroidBridge: envelope.result),
        artifacts: [artifactPath],
        sourceCommands: sourceCommands,
        note: "Android observe used the TritonKit bridge AccessibilityService tree; WebView DOM and semantic runtime actions still require a provider."
    )
}

func observeIOS(
    action: String,
    target: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    maxNodes: Int?,
    iosHostAX: Bool = false
) async throws -> ObserveOutput {
    if runtimeBaseURL == nil, iosHostAX {
        return try observeIOSHostAX(action: action, target: target, maxNodes: maxNodes)
    }

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

func observeIOSHostAX(action: String, target: String, maxNodes: Int?) throws -> ObserveOutput {
    #if os(macOS)
    guard let tree = try AXPTranslatorAccessibility(udid: target).describeAll() else {
        throw HostSimulatorAXError.treeUnavailable(target)
    }
    return observeIOSHostAXOutput(action: action, target: target, root: tree, maxNodes: maxNodes)
    #else
    throw HostSimulatorAXError.unsupportedPlatform
    #endif
}

func observeIOSHostAXOutput(
    action: String,
    target: String,
    root: TKAXNode,
    maxNodes: Int?,
    capturedAt: String = ISO8601DateFormatter().string(from: Date())
) -> ObserveOutput {
    var nodes = observeNodes(fromAX: [root], source: "host-layout", prefix: "ios-host")
    if let maxNodes {
        nodes = Array(nodes.prefix(maxNodes))
    }
    let sourceCommands = ["triton sim ax --device \(target) --json"]
    let hostSource = ObserveSourceOutput(
        name: "host-layout",
        available: true,
        reason: nil,
        artifact: nil,
        sourceCommands: sourceCommands
    )
    return ObserveOutput(
        ok: true,
        action: action,
        platform: "ios",
        capturedAt: capturedAt,
        partial: true,
        target: "sim:\(target)",
        sources: [
            hostSource,
            ObserveSourceOutput(name: "runtime-tree", available: false, reason: "embedded runtime not used because host simulator target was requested", artifact: nil, sourceCommands: []),
            ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
        ],
        nodes: nodes,
        artifacts: [],
        sourceCommands: sourceCommands,
        note: "iOS host observe uses the Simulator private-framework AX tree. Use embedded runtime AX when connected for runtime OIDs and app-internal state."
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

func observeNode(fromAndroid node: TKAndroidUIAutomatorNodeSummary, index: Int) -> ObserveNodeOutput {
    let role = node.className
    let text = node.text ?? node.contentDescription
    let identifier = node.resourceID
    let webCandidate = isWebCandidate(
        role: role,
        className: node.className,
        identifier: identifier,
        text: text
    )
    var capabilities: [String] = []
    if node.enabled {
        capabilities.append("visible")
    }
    if node.clickable, node.bounds != nil {
        capabilities.append("tap")
    }
    let missing = webCandidate
        ? ["webview.url", "webview.dom", "webview.bridge-call", "semantic-action"]
        : ["semantic-action"]
    return ObserveNodeOutput(
        nodeID: "android:host:\(index)",
        source: "host-layout",
        role: role,
        text: text,
        identifier: identifier,
        frame: node.bounds,
        enabled: node.enabled,
        focused: nil,
        hidden: nil,
        candidateOnly: webCandidate,
        confidence: webCandidate ? 0.7 : 0.83,
        capabilities: capabilities,
        missingCapabilities: missing
    )
}

private func observeNodes(fromAndroidBridge root: AndroidBridgeNode) -> [ObserveNodeOutput] {
    var result: [ObserveNodeOutput] = []

    func visit(_ node: AndroidBridgeNode, path: String) {
        result.append(observeNode(fromAndroidBridge: node, path: path))
        for (offset, child) in (node.children ?? []).enumerated() {
            visit(child, path: "\(path).\(offset)")
        }
    }

    visit(root, path: "0")
    return result
}

private func observeNode(fromAndroidBridge node: AndroidBridgeNode, path: String) -> ObserveNodeOutput {
    let role = node.className
    let text = [node.text, node.contentDescription].compactMap { cleanBridgeString($0) }.first
    let identifier = cleanBridgeString(node.resourceId) ?? cleanBridgeString(node.uniqueId)
    let webCandidate = isWebCandidate(
        role: role,
        className: role,
        identifier: identifier,
        text: text
    )
    var capabilities: [String] = []
    if node.visibleToUser != false && node.enabled != false {
        capabilities.append("visible")
    }
    if node.clickable == true, node.boundsInScreen != nil {
        capabilities.append("tap")
    }
    if node.scrollable == true {
        capabilities.append("scroll")
    }
    let missing = webCandidate
        ? ["webview.url", "webview.dom", "webview.bridge-call", "semantic-action"]
        : ["semantic-action"]
    return ObserveNodeOutput(
        nodeID: "android-bridge:\(node.uniqueId ?? node.resourceId ?? path)",
        source: "android-bridge",
        role: role,
        text: text,
        identifier: identifier,
        frame: node.boundsInScreen?.rect,
        enabled: node.enabled,
        focused: node.focused,
        hidden: node.visibleToUser.map { !$0 },
        candidateOnly: webCandidate,
        confidence: webCandidate ? 0.78 : 0.9,
        capabilities: capabilities,
        missingCapabilities: missing
    )
}

private func cleanBridgeString(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func isWebCandidate(role: String?, className: String?, identifier: String? = nil, text: String? = nil) -> Bool {
    webViewCandidateScore(role: role, className: className, identifier: identifier, text: text) != nil
}

func runNodeResolve(
    platform: ObservationPlatform,
    query: String?,
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
    json: Bool,
    iosHostAX: Bool = false
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
        if query != nil && text != nil {
            if outputFormat == .json {
                try printValidationError("`triton node resolve` accepts either <query> or --text, not both")
                throw ExitCode.failure
            }
            throw RuntimeError("`triton node resolve` accepts either <query> or --text, not both")
        }
        guard let text = query ?? text, !text.isEmpty else {
            if outputFormat == .json {
                try printValidationError("`triton node resolve` requires <query> or --text")
                throw ExitCode.failure
            }
            throw RuntimeError("`triton node resolve` requires <query> or --text")
        }
        let bounds = try within.map(parseBounds)
        let point = try at.map(parsePoint)
        let response: NodeResolveOutput
        if isNodeAliasQuery(text) {
            response = try resolveNodeAlias(
                text,
                platform: platform.rawValue,
                target: target,
                workspace: FileManager.default.currentDirectoryPath
            )
        } else {
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
            case .android:
                response = try resolveAndroidNode(
                    query: text,
                    target: target,
                    index: index,
                    within: bounds,
                    at: point
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
                    includeCandidates: all,
                    iosHostAX: iosHostAX
                )
            }
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
        if platform == .harmony || platform == .android {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func resolveAndroidNode(
    query: String,
    target: String,
    index: Int?,
    within: TKRect?,
    at: (x: Double, y: Double)?,
    includeCandidates: Bool = false
) throws -> NodeResolveOutput {
    let selection = try resolveHostDeviceSelection(
        request: HostDeviceSelectionRequest(device: target, platform: .android, ready: true),
        hdc: "hdc"
    )
    let output = try observeAndroid(action: "observe.tree", selected: selection.target, output: nil)
    let candidates = output.nodes
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
        platform: "android",
        query: query,
        candidates: candidates,
        index: index,
        includeCandidates: includeCandidates,
        sourceCommands: output.sourceCommands
    )
}

private func defaultAndroidObserveArtifactPath(serial: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-android-\(serial)-window.xml")
        .path
}

private func defaultAndroidBridgeObserveArtifactPath(serial: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("triton-android-\(serial)-bridge-tree.json")
        .path
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
    includeCandidates: Bool,
    iosHostAX: Bool = false
) async throws -> NodeResolveOutput {
    let nodes: [ObserveNodeOutput]
    let sourceCommands: [String]
    if runtimeBaseURL == nil, iosHostAX {
        let output = try await observeIOS(
            action: "observe.tree",
            target: target,
            host: host,
            port: port,
            runtimeBaseURL: nil,
            maxNodes: nil,
            iosHostAX: true
        )
        nodes = output.nodes
        sourceCommands = output.sourceCommands
    } else if let runtimeBaseURL {
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

func makeObserveNodeOutline(from nodes: [ObserveNodeOutput]) -> [ObserveNodeAliasOutput] {
    nodes
        .filter(isObserveOutlineCandidate)
        .enumerated()
        .map { index, node in ObserveNodeAliasOutput(alias: "@\(index + 1)", node: node) }
}

func makeNodeAliasCache(from output: ObserveOutput, outline: [ObserveNodeAliasOutput]) -> NodeAliasCache {
    NodeAliasCache(
        platform: output.platform,
        target: output.target,
        capturedAt: output.capturedAt,
        primarySourceName: output.primarySource?.name,
        sourceCommands: output.sourceCommands,
        aliases: outline
    )
}

func saveNodeAliasCache(_ cache: NodeAliasCache, workspace: String) throws -> String {
    let path = NodeAliasCache.filePath(workspace: workspace)
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(cache).write(to: url, options: [.atomic])
    return path
}

func loadNodeAliasCache(workspace: String, platform: String, target: String) throws -> NodeAliasCache {
    let path = NodeAliasCache.filePath(workspace: workspace)
    guard FileManager.default.fileExists(atPath: path) else {
        throw NodeAliasResolutionError.cacheMissing(path: path, platform: platform, target: target)
    }
    return try JSONDecoder().decode(NodeAliasCache.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}

func resolveNodeAlias(_ alias: String, platform: String, target: String, workspace: String) throws -> NodeResolveOutput {
    guard isNodeAliasQuery(alias) else {
        throw NodeAliasResolutionError.invalidAlias(alias)
    }
    let cache = try loadNodeAliasCache(workspace: workspace, platform: platform, target: target)
    guard cache.platform == platform, nodeAliasTargetMatches(requested: target, cached: cache.target) else {
        throw NodeAliasResolutionError.staleAlias(
            alias: alias,
            expectedPlatform: platform,
            expectedTarget: target,
            cachedPlatform: cache.platform,
            cachedTarget: cache.target
        )
    }
    guard let entry = cache.aliases.first(where: { $0.alias == alias }) else {
        throw NodeAliasResolutionError.aliasNotFound(
            alias: alias,
            path: NodeAliasCache.filePath(workspace: workspace),
            platform: platform,
            target: target,
            availableAliases: cache.aliases.map(\.alias)
        )
    }
    return NodeResolveOutput(
        ok: true,
        action: "node.resolve",
        platform: platform,
        query: alias,
        matchIndex: Int(alias.dropFirst()) ?? 1,
        matchCount: cache.aliases.count,
        node: entry.node,
        candidates: nil,
        sourceCommands: cache.sourceCommands
    )
}

func isNodeAliasQuery(_ query: String) -> Bool {
    guard query.hasPrefix("@") else { return false }
    return Int(query.dropFirst()).map { $0 > 0 } ?? false
}

private func observeOutputWithNodeOutline(_ output: ObserveOutput, workspace: String) throws -> ObserveOutput {
    let outline = makeObserveNodeOutline(from: output.nodes)
    let cache = makeNodeAliasCache(from: output, outline: outline)
    let path = try saveNodeAliasCache(cache, workspace: workspace)
    return ObserveOutput(
        ok: output.ok,
        action: output.action,
        platform: output.platform,
        capturedAt: output.capturedAt,
        partial: output.partial,
        target: output.target,
        primarySource: output.primarySource,
        sources: output.sources,
        nodes: output.nodes,
        outline: outline,
        aliasCache: ObserveAliasCacheOutput(path: path, aliasCount: outline.count),
        artifacts: output.artifacts,
        sourceCommands: output.sourceCommands,
        note: output.note
    )
}

private func isObserveOutlineCandidate(_ node: ObserveNodeOutput) -> Bool {
    if node.hidden == true || node.candidateOnly {
        return false
    }
    return hasNonEmptyValue(node.text)
        || hasNonEmptyValue(node.identifier)
        || !node.capabilities.isEmpty
}

private func hasNonEmptyValue(_ value: String?) -> Bool {
    guard let value else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func nodeAliasTargetMatches(requested: String, cached: String) -> Bool {
    if requested == cached {
        return true
    }
    let requestedVariants = nodeAliasTargetVariants(requested)
    let cachedVariants = nodeAliasTargetVariants(cached)
    return !requestedVariants.isDisjoint(with: cachedVariants)
}

private func nodeAliasTargetVariants(_ target: String) -> Set<String> {
    var variants: Set<String> = [target]
    for prefix in ["sim:", "android:", "harmony:"] {
        if target.hasPrefix(prefix) {
            variants.insert(String(target.dropFirst(prefix.count)))
        } else {
            variants.insert(prefix + target)
        }
    }
    return variants
}
