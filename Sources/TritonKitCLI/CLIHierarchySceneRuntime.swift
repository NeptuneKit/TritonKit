import ArgumentParser
import Foundation
import TritonKitShared

func runHierarchyScene(
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    maxNodes: Int?,
    output: String?,
    artifactOutput: String?,
    json: Bool
) async throws {
    let outputFormat: ClientOutputFormat = json ? .json : .text
    do {
        let observation = try await hierarchyObservation(
            platform: platform,
            target: target,
            hdc: hdc,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            maxNodes: maxNodes,
            output: artifactOutput
        )
        let command = hierarchySourceCommand(platform: platform.rawValue, target: target)
        let response = TKHostHierarchyResponse(
            ok: true,
            capturedAt: observation.capturedAt,
            source: TKHierarchySourceInfo(
                command: command,
                runtimeScope: hierarchyRuntimeScope(platform: platform, observation: observation),
                readonly: true
            ),
            scene: makeHierarchyScene(
                platform: platform.rawValue,
                target: target,
                nodes: observation.nodes,
                sourceCommands: observation.sourceCommands
            )
        )
        switch outputFormat {
        case .json:
            try writeOrPrint(try encodeJSON(response), output: output)
        case .text:
            try writeOrPrint(renderHierarchyScene(response.scene), output: output)
        }
    } catch {
        if error is ExitCode { throw error }
        if platform == .harmony || platform == .android {
            try failHostCommand(error, outputFormat: outputFormat)
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: runtimeBaseURL ?? "/request", host: host, port: port)
    }
}

func makeHierarchyScene(
    platform: String,
    target: String,
    nodes: [ObserveNodeOutput],
    sourceCommands: [String]
) -> TKHierarchyScene {
    let layerNodes = nodes
        .enumerated()
        .compactMap { index, node -> TKHierarchyLayerNode? in
            guard let frame = node.frame, frame.width > 0, frame.height > 0 else { return nil }
            let depth = hierarchyDepth(for: node, fallbackIndex: index)
            return TKHierarchyLayerNode(
                id: node.nodeID,
                parentId: index == 0 ? nil : hierarchyParentID(for: nodes, currentIndex: index, currentDepth: depth),
                type: node.role ?? "View",
                name: hierarchyNodeName(node, fallback: "\(platform)-node-\(index + 1)"),
                frame: frame,
                depth: depth,
                visible: node.hidden != true,
                interactive: node.capabilities.contains("tap") || node.capabilities.contains("scroll"),
                color: hierarchyColor(platform: platform, interactive: node.capabilities.contains("tap")),
                source: node.source
            )
        }

    let viewport = hierarchyViewport(from: layerNodes)
    let rootId = layerNodes.first?.id ?? "\(platform):\(target):root"
    return TKHierarchyScene(platform: platform, rootId: rootId, viewport: viewport, nodes: layerNodes)
}

private func hierarchyObservation(
    platform: ObservationPlatform,
    target: String,
    hdc: String,
    host: String,
    port: Int,
    runtimeBaseURL: String?,
    maxNodes: Int?,
    output: String?
) async throws -> ObserveOutput {
    switch platform {
    case .harmony:
        return try await observeHarmony(
            action: "hierarchy",
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
        return try observeAndroid(
            action: "hierarchy",
            selected: selected.target,
            adb: "adb",
            output: output
        )
    case .ios:
        return try await observeIOS(
            action: "hierarchy",
            target: target,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            maxNodes: maxNodes
        )
    }
}

private func hierarchyRuntimeScope(platform: ObservationPlatform, observation: ObserveOutput) -> String {
    if let primary = observation.primarySource?.name {
        return primary
    }
    switch platform {
    case .ios:
        return "embedded"
    case .android:
        return "host-android"
    case .harmony:
        return "host-harmony"
    }
}

private func hierarchySourceCommand(platform: String, target: String) -> String {
    "triton hierarchy --platform \(platform) --target \(target) --json"
}

private func hierarchyDepth(for node: ObserveNodeOutput, fallbackIndex: Int) -> Int {
    let parts = node.nodeID.split(separator: ":")
    if let last = parts.last, let numeric = Int(last) {
        return max(0, min(numeric, 12))
    }
    return max(0, min(fallbackIndex, 12))
}

private func hierarchyParentID(for nodes: [ObserveNodeOutput], currentIndex: Int, currentDepth: Int) -> String? {
    guard currentIndex > 0 else { return nil }
    if currentDepth <= 0 {
        return nodes.first?.nodeID
    }
    let previous = nodes[..<currentIndex].indices.reversed().first { index in
        hierarchyDepth(for: nodes[index], fallbackIndex: index) < currentDepth
    }
    return previous.map { nodes[$0].nodeID } ?? nodes.first?.nodeID
}

private func hierarchyNodeName(_ node: ObserveNodeOutput, fallback: String) -> String {
    [node.text, node.identifier, node.role]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? fallback
}

private func hierarchyViewport(from nodes: [TKHierarchyLayerNode]) -> TKHierarchyViewport {
    let maxX = nodes.map { $0.frame.x + $0.frame.width }.max() ?? 1
    let maxY = nodes.map { $0.frame.y + $0.frame.height }.max() ?? 1
    return TKHierarchyViewport(width: max(1, maxX), height: max(1, maxY))
}

private func hierarchyColor(platform: String, interactive: Bool) -> String {
    if interactive {
        return "#fb7185"
    }
    switch platform {
    case "android":
        return "#34d399"
    case "harmony":
        return "#f472b6"
    default:
        return "#6ea8ff"
    }
}

private func renderHierarchyScene(_ scene: TKHierarchyScene) -> String {
    var lines = [
        "platform: \(scene.platform)",
        "viewport: \(Int(scene.viewport.width))x\(Int(scene.viewport.height))",
        "nodes: \(scene.nodes.count)",
    ]
    for node in scene.nodes.prefix(40) {
        let indent = String(repeating: "  ", count: max(0, node.depth))
        lines.append("\(indent)- \(node.type) \(node.name) \(formatRect(node.frame))")
    }
    return lines.joined(separator: "\n")
}
