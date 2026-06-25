import ArgumentParser
import CoreGraphics
import Foundation
import TritonKit
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
        if platform == .ios, runtimeBaseURL == nil {
            let (summary, client) = try await resolveRuntimeClient(target: target, host: host, port: port, jsonError: outputFormat == .json)
            let data = try await client.request(type: "hierarchy")
            let hierarchy = try JSONDecoder().decode(LegacyIosHierarchyPayload.self, from: data)
            let scene = makeLegacyIosHierarchyScene(
                target: summary.id,
                displayItems: hierarchy.displayItems,
                viewportOverride: hierarchy.viewport,
                maxNodes: maxNodes,
                controllerContext: hierarchy.controllerContext
            )
            let response = TKHostHierarchyResponse(
                ok: true,
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                source: TKHierarchySourceInfo(
                    command: hierarchySourceCommand(platform: platform.rawValue, target: target),
                    runtimeScope: "runtime-tree",
                    readonly: true
                ),
                scene: scene
            )
            switch outputFormat {
            case .json:
                try writeOrPrint(try encodeJSON(response), output: output)
            case .text:
                try writeOrPrint(renderHierarchyScene(response.scene), output: output)
            }
            return
        }

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

func makeLegacyIosHierarchyScene(
    target: String,
    displayItems: [TKDisplayItem],
    viewportOverride: TKHierarchyViewport? = nil,
    maxNodes: Int? = nil,
    controllerContext: TKHierarchyControllerContext? = nil
) -> TKHierarchyScene {
    let viewport = legacyIosViewport(displayItems: displayItems, viewportOverride: viewportOverride)
    var nodes: [TKHierarchyLayerNode] = []
    for item in displayItems {
        appendLegacyIosHierarchyNode(&nodes, item: item, parentId: nil, viewport: viewport, maxNodes: maxNodes)
    }
    let rootId = nodes.first?.id ?? "ios:(target):root"
    return TKHierarchyScene(
        platform: "ios",
        rootId: rootId,
        viewport: viewport,
        nodes: nodes,
        controllerContext: resolvedLegacyIosControllerContext(controllerContext, nodes: nodes)
    )
}

private struct LegacyIosHierarchyPayload: Decodable {
    let displayItems: [TKDisplayItem]
    let appInfo: LegacyIosAppInfo?
    let controllerContext: TKHierarchyControllerContext?

    var viewport: TKHierarchyViewport? {
        guard let width = appInfo?.screenWidth, let height = appInfo?.screenHeight, width > 0, height > 0 else {
            return nil
        }
        return TKHierarchyViewport(width: width, height: height)
    }
}

private struct LegacyIosAppInfo: Decodable {
    let screenWidth: Double?
    let screenHeight: Double?
}

private func appendLegacyIosHierarchyNode(
    _ nodes: inout [TKHierarchyLayerNode],
    item: TKDisplayItem,
    parentId: String?,
    viewport: TKHierarchyViewport,
    maxNodes: Int?,
    depthOffset: Int = 0,
    currentControllerOID: UInt? = nil
) {
    if let maxNodes, nodes.count >= maxNodes { return }
    guard item.frame.width > 0, item.frame.height > 0 else { return }
    let oid = item.layerObject?.oid ?? item.viewObject?.oid ?? UInt(nodes.count)
    let controllerOID = item.hostViewControllerObject?.oid
    let shouldInsertController = controllerOID != nil && controllerOID != currentControllerOID
    let controllerId = shouldInsertController ? "ios:controller:\(controllerOID ?? 0)" : nil
    if shouldInsertController, let controller = item.hostViewControllerObject, let controllerId {
        nodes.append(TKHierarchyLayerNode(
            id: controllerId,
            parentId: parentId,
            type: controller.classChainList.first ?? "UIViewController",
            name: legacyIosControllerNodeName(controller),
            frame: clampLegacyIosFrame(item.frame, viewport: viewport),
            depth: max(0, item.indentLevel + depthOffset),
            visible: !item.isHidden,
            interactive: false,
            color: "#b48cff",
            source: "runtime-controller",
            style: TKHierarchyNodeStyle(
                display: "controller",
                text: legacyIosControllerNodeName(controller),
                backgroundColor: "#b48cff",
                foregroundColor: nil,
                alpha: Double(item.alpha),
                cornerRadius: nil
            ),
            slice: nil,
            view: nil,
            layer: nil,
            visualSources: [
                TKHierarchyVisualSource(
                    kind: "styledFallback",
                    dataRef: nil,
                    dataUrl: nil,
                    rect: clampLegacyIosFrame(item.frame, viewport: viewport),
                    capturedBy: nil,
                    contentsScale: nil,
                    contentsGravity: nil,
                    contentsRect: nil,
                    reason: "UIViewController host object has no standalone view snapshot"
                )
            ],
            raw: TKHierarchyNodeRawInfo(
                platform: "ios",
                source: "runtime-tree",
                role: "UIViewController",
                identifier: String(controller.oid),
                classHierarchy: controller.classChainList
            ),
            renderHints: TKHierarchyNodeRenderHints(
                preferredMode: "structure",
                fallbackMode: "wireframe",
                quality: "semantic"
            )
        ))
    }
    let type = legacyIosHierarchyClassName(item)
    let id = "ios:runtime:\(oid)"
    let frame = clampLegacyIosFrame(item.frame, viewport: viewport)
    let alpha = Double(item.alpha)
    let visible = !item.isHidden && alpha > 0.01 && frame.width > 0 && frame.height > 0
    let interactive = legacyIosHierarchyNodeIsInteractive(type: type, item: item)
    let color = legacyIosHierarchyNodeColor(item: item, interactive: interactive)
    let slice = legacyIosHierarchyNodeSlice(item)
    let visualSources = legacyIosHierarchyVisualSources(frame: frame, slice: slice)
    nodes.append(TKHierarchyLayerNode(
        id: id,
        parentId: controllerId ?? parentId,
        type: type,
        name: legacyIosHierarchyNodeName(type: type, oid: oid, item: item),
        frame: frame,
        depth: max(0, item.indentLevel + depthOffset + (shouldInsertController ? 1 : 0)),
        visible: visible,
        interactive: interactive,
        color: color,
        source: "runtime-tree",
        style: legacyIosHierarchyNodeStyle(item: item, type: type, color: color, alpha: alpha),
        slice: slice,
        view: legacyIosHierarchyViewMetadata(item: item, type: type),
        layer: legacyIosHierarchyLayerMetadata(item: item),
        visualSources: visualSources,
        raw: TKHierarchyNodeRawInfo(
            platform: "ios",
            source: "runtime-tree",
            role: type,
            identifier: item.screenshotRef,
            classHierarchy: legacyIosHierarchyClassChain(item)
        ),
        renderHints: legacyIosHierarchyRenderHints(type: type, frame: frame, viewport: viewport, slice: slice)
    ))
    let childDepthOffset = depthOffset + (shouldInsertController ? 1 : 0)
    let nextControllerOID = controllerOID ?? currentControllerOID
    for child in item.subitems {
        appendLegacyIosHierarchyNode(
            &nodes,
            item: child,
            parentId: id,
            viewport: viewport,
            maxNodes: maxNodes,
            depthOffset: childDepthOffset,
            currentControllerOID: nextControllerOID
        )
    }
}

private func legacyIosControllerNodeName(_ controller: TKObject) -> String {
    let type = controller.classChainList.first ?? "UIViewController"
    return "\(type.split(separator: ".").last.map(String.init) ?? type)#\(controller.oid)"
}

private func resolvedLegacyIosControllerContext(
    _ context: TKHierarchyControllerContext?,
    nodes: [TKHierarchyLayerNode]
) -> TKHierarchyControllerContext? {
    if let context, context.activeControllerName != nil || !context.stack.isEmpty {
        return context
    }
    let controllerNodes = nodes.filter(isLegacyIosControllerNode)
    guard let active = controllerNodes
        .filter(\.visible)
        .filter({ !isSystemOverlayControllerType($0.type) })
        .sorted(by: { first, second in
            let firstArea = first.frame.width * first.frame.height
            let secondArea = second.frame.width * second.frame.height
            if firstArea != secondArea { return firstArea > secondArea }
            return first.depth > second.depth
        })
        .first ?? controllerNodes.first
    else {
        return nil
    }
    let entry = hierarchyControllerEntry(from: active)
    return TKHierarchyControllerContext(
        activeControllerId: entry.id,
        activeControllerName: entry.name,
        activeControllerClassName: entry.className,
        stack: [entry],
        source: "scene-controller-node-fallback"
    )
}

private func isLegacyIosControllerNode(_ node: TKHierarchyLayerNode) -> Bool {
    node.source == "runtime-controller" ||
        node.raw?.role == "UIViewController" ||
        node.id.hasPrefix("ios:controller:")
}

private func isSystemOverlayControllerType(_ type: String) -> Bool {
    type.contains("UITrackingElementWindowController") ||
        type.contains("UIEditingOverlayViewController")
}

private func hierarchyControllerEntry(from node: TKHierarchyLayerNode) -> TKHierarchyControllerEntry {
    let oid = node.raw?.identifier.flatMap(UInt.init)
    let name = node.name.replacingOccurrences(of: #"#\d+$"#, with: "", options: .regularExpression)
    return TKHierarchyControllerEntry(
        id: node.id,
        oid: oid,
        className: node.type,
        name: name.isEmpty ? node.type : name,
        title: nil
    )
}

private func legacyIosViewport(displayItems: [TKDisplayItem], viewportOverride: TKHierarchyViewport?) -> TKHierarchyViewport {
    if let viewportOverride {
        return viewportOverride
    }
    if let root = displayItems.first, root.frame.width > 0, root.frame.height > 0 {
        return TKHierarchyViewport(width: Double(root.frame.width), height: Double(root.frame.height))
    }
    return TKHierarchyViewport(width: 390, height: 844)
}

private func legacyIosHierarchyClassName(_ item: TKDisplayItem) -> String {
    item.layerObject?.classChainList.first
        ?? item.viewObject?.classChainList.first
        ?? item.hostViewControllerObject?.classChainList.first
        ?? "UIView"
}

private func legacyIosHierarchyClassChain(_ item: TKDisplayItem) -> [String]? {
    item.layerObject?.classChainList
        ?? item.viewObject?.classChainList
        ?? item.hostViewControllerObject?.classChainList
}

private func legacyIosHierarchyNodeName(type: String, oid: UInt, item: TKDisplayItem) -> String {
    if item.representedAsKeyWindow { return "keyWindow" }
    if let title = normalizedLegacyString(item.customDisplayTitle) { return title }
    return "\(type.split(separator: ".").last.map(String.init) ?? type)#\(oid)"
}

private func legacyIosHierarchyNodeIsInteractive(type: String, item: TKDisplayItem) -> Bool {
    let merged = type.lowercased()
    return merged.range(of: "button|control|cell|collection|table|scroll|textfield|textview|switch|slider|segmented", options: .regularExpression) != nil
        || !item.eventHandlers.isEmpty
}

private func legacyIosHierarchyNodeColor(item: TKDisplayItem, interactive: Bool) -> String {
    if let color = item.backgroundColor, color.alpha > 0.03 {
        return rgbFloatToHex(red: Double(color.red), green: Double(color.green), blue: Double(color.blue))
    }
    return interactive ? "#2563eb" : "#94a3b8"
}

private func legacyIosHierarchyNodeStyle(item: TKDisplayItem, type: String, color: String, alpha: Double) -> TKHierarchyNodeStyle {
    TKHierarchyNodeStyle(
        display: legacyIosHierarchyDisplayKind(type),
        text: normalizedLegacyString(item.customDisplayTitle),
        backgroundColor: color,
        foregroundColor: nil,
        alpha: alpha,
        cornerRadius: nil
    )
}

private func legacyIosHierarchyViewMetadata(item: TKDisplayItem, type: String) -> TKHierarchyViewMetadata {
    TKHierarchyViewMetadata(
        className: item.viewObject?.classChainList.first ?? type,
        isHidden: item.isHidden,
        alpha: Double(item.alpha),
        isUserInteractionEnabled: nil,
        accessibilityIdentifier: nil,
        accessibilityLabel: normalizedLegacyString(item.customDisplayTitle)
    )
}

private func legacyIosHierarchyLayerMetadata(item: TKDisplayItem) -> TKHierarchyLayerMetadata {
    TKHierarchyLayerMetadata(
        bounds: tkRect(item.bounds),
        position: TKHierarchyPoint(
            x: Double(item.layerPosition?.x ?? item.frame.midX),
            y: Double(item.layerPosition?.y ?? item.frame.midY)
        ),
        anchorPoint: TKHierarchyPoint(
            x: Double(item.layerAnchorPoint?.x ?? 0.5),
            y: Double(item.layerAnchorPoint?.y ?? 0.5)
        ),
        zPosition: Double(item.layerZPosition ?? 0),
        transform: item.layerTransform,
        sublayerTransform: item.layerSublayerTransform,
        masksToBounds: item.layerMasksToBounds ?? false,
        cornerRadius: Double(item.layerCornerRadius ?? 0),
        opacity: Double(item.layerOpacity ?? item.alpha),
        isHidden: item.layerIsHidden ?? item.isHidden,
        contentsScale: item.layerContentsScale.map(Double.init),
        contentsGravity: item.layerContentsGravity,
        contentsRect: item.layerContentsRect.map(tkRect),
        borderWidth: item.layerBorderWidth.map(Double.init),
        borderColor: item.layerBorderColor.flatMap(tkColorToHex),
        shadowOpacity: item.layerShadowOpacity.map(Double.init),
        shadowRadius: item.layerShadowRadius.map(Double.init),
        shadowOffset: item.layerShadowOffset.map { TKHierarchySize(width: Double($0.width), height: Double($0.height)) },
        shadowColor: item.layerShadowColor.flatMap(tkColorToHex)
    )
}

private func tkColorToHex(_ color: TKColor) -> String? {
    guard color.alpha > 0.01 else { return nil }
    return rgbFloatToHex(red: Double(color.red), green: Double(color.green), blue: Double(color.blue))
}

private func tkRect(_ rect: CGRect) -> TKRect {
    TKRect(
        x: Double(rect.origin.x),
        y: Double(rect.origin.y),
        width: Double(rect.size.width),
        height: Double(rect.size.height)
    )
}

private func legacyIosHierarchyNodeSlice(_ item: TKDisplayItem) -> TKHierarchyNodeSlice {
    guard let ref = normalizedLegacyString(item.screenshotRef) else {
        return TKHierarchyNodeSlice(
            available: false,
            mode: "node-screenshot-ref",
            source: "triton-runtime-data-ref"
        )
    }
    return TKHierarchyNodeSlice(
        available: true,
        mode: "node-screenshot-ref",
        source: "triton-runtime-data-ref",
        dataRef: ref
    )
}

private func legacyIosHierarchyVisualSources(frame: TKRect, slice: TKHierarchyNodeSlice) -> [TKHierarchyVisualSource] {
    guard slice.available, slice.dataRef != nil || slice.dataUrl != nil else {
        return [
            TKHierarchyVisualSource(
                kind: "styledFallback",
                rect: frame,
                reason: "No subtree snapshot dataRef available"
            )
        ]
    }
    return [
        TKHierarchyVisualSource(
            kind: "subtreeSnapshot",
            dataRef: slice.dataRef,
            dataUrl: slice.dataUrl,
            rect: frame,
            capturedBy: "UIView.render"
        )
    ]
}

private func legacyIosHierarchyRenderHints(
    type: String,
    frame: TKRect,
    viewport: TKHierarchyViewport,
    slice: TKHierarchyNodeSlice
) -> TKHierarchyNodeRenderHints {
    if slice.available {
        return TKHierarchyNodeRenderHints(preferredMode: "slice", fallbackMode: "style", quality: "exact")
    }
    let isFullscreen = frame.width >= viewport.width * 0.96 && frame.height >= viewport.height * 0.9
    if isFullscreen && type.range(of: "window|transition|shadow|container|wrapper|root", options: [.regularExpression, .caseInsensitive]) != nil {
        return TKHierarchyNodeRenderHints(preferredMode: "wireframe", fallbackMode: "wireframe", quality: "fallback")
    }
    return TKHierarchyNodeRenderHints(preferredMode: "slice", fallbackMode: "style", quality: "approximate")
}

private func legacyIosHierarchyDisplayKind(_ type: String) -> String {
    let lowered = type.lowercased()
    if lowered.contains("button") || lowered.contains("control") { return "button" }
    if lowered.contains("label") || lowered.contains("text") { return "text" }
    if lowered.contains("cell") || lowered.contains("card") { return "card" }
    if lowered.contains("collection") || lowered.contains("table") || lowered.contains("scroll") || lowered.contains("stack") { return "container" }
    if lowered.contains("tabbar") || lowered.contains("tab bar") { return "tabbar" }
    if lowered.contains("navigation") || lowered.contains("toolbar") || lowered.contains("bar") { return "bar" }
    return "view"
}

private func clampLegacyIosFrame(_ frame: CGRect, viewport: TKHierarchyViewport) -> TKRect {
    TKRect(
        x: max(0, min(viewport.width, Double(frame.origin.x))),
        y: max(0, min(viewport.height, Double(frame.origin.y))),
        width: max(0, min(viewport.width, Double(frame.width))),
        height: max(0, min(viewport.height, Double(frame.height)))
    )
}

private func rgbFloatToHex(red: Double, green: Double, blue: Double) -> String {
    func hex(_ value: Double) -> String {
        String(format: "%02x", max(0, min(255, Int((value * 255).rounded()))))
    }
    return "#\(hex(red))\(hex(green))\(hex(blue))"
}

private func normalizedLegacyString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
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
                source: node.source,
                style: hierarchyNodeStyle(node),
                slice: hierarchyNodeSlice(node),
                visualSources: hierarchyNodeVisualSources(node),
                raw: TKHierarchyNodeRawInfo(
                    platform: platform,
                    source: node.source,
                    role: node.role,
                    identifier: node.identifier
                ),
                renderHints: hierarchyNodeRenderHints(node)
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

private func hierarchyNodeStyle(_ node: ObserveNodeOutput) -> TKHierarchyNodeStyle? {
    let display = hierarchyNodeDisplayKind(node)
    let text = [node.text, node.identifier]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    return TKHierarchyNodeStyle(
        display: display,
        text: text,
        backgroundColor: node.capabilities.contains("tap") ? "#eff6ff" : nil,
        foregroundColor: node.capabilities.contains("tap") ? "#1d4ed8" : nil,
        alpha: node.hidden == true ? 0 : 1,
        cornerRadius: display == "button" || display == "card" ? 12 : nil
    )
}

private func hierarchyNodeSlice(_ node: ObserveNodeOutput) -> TKHierarchyNodeSlice {
    TKHierarchyNodeSlice(
        available: false,
        mode: "node-snapshot",
        source: node.source,
        dataUrl: nil
    )
}

private func hierarchyNodeVisualSources(_ node: ObserveNodeOutput) -> [TKHierarchyVisualSource] {
    [
        TKHierarchyVisualSource(
            kind: "styledFallback",
            rect: node.frame,
            reason: "Host observe node does not expose layer-own contents or runtime subtree snapshot"
        )
    ]
}

private func hierarchyNodeRenderHints(_ node: ObserveNodeOutput) -> TKHierarchyNodeRenderHints {
    let display = hierarchyNodeDisplayKind(node)
    let preferred = display == "view" ? "wireframe" : "style"
    return TKHierarchyNodeRenderHints(
        preferredMode: preferred,
        fallbackMode: "wireframe",
        quality: "approximate"
    )
}

private func hierarchyNodeDisplayKind(_ node: ObserveNodeOutput) -> String {
    let role = (node.role ?? "").lowercased()
    let identifier = (node.identifier ?? "").lowercased()
    let text = (node.text ?? "").lowercased()
    let merged = [role, identifier, text].joined(separator: " ")
    if merged.contains("button") { return "button" }
    if merged.contains("label") || merged.contains("text") || node.text != nil { return "text" }
    if merged.contains("textfield") || merged.contains("input") || merged.contains("search") { return "input" }
    if merged.contains("cell") || merged.contains("card") || merged.contains("row") { return "card" }
    if merged.contains("scroll") || merged.contains("list") || merged.contains("collection") || merged.contains("stack") { return "container" }
    if merged.contains("tabbar") || merged.contains("tab bar") { return "tabbar" }
    if merged.contains("navigation") || merged.contains("toolbar") || merged.contains("bar") { return "bar" }
    return node.capabilities.contains("tap") ? "button" : "view"
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
