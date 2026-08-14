import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

func renderAXTree(_ nodes: [TKAXNode]) -> String {
    axTreeLines(nodes, indent: 0).joined(separator: "\n")
}

func renderAXHierarchyMap(_ response: TKAXHierarchyMapResponse) -> String {
    var lines = [
        "AX nodes: \(response.axNodeCount)",
        "Hierarchy nodes: \(response.hierarchyNodeCount)",
        "Mapped: \(response.mappedCount)",
        "Unmatched: \(response.unmatchedCount)",
    ]
    for node in response.nodes {
        let prefix = String(repeating: "  ", count: node.depth)
        var line = "\(prefix)\(node.role)"
        if let label = node.label, !label.isEmpty { line += " \"\(label)\"" }
        if let identifier = node.identifier, !identifier.isEmpty { line += " #\(identifier)" }
        if let oid = node.viewOID ?? node.targetOID { line += " oid:\(oid)" }
        if let className = node.className { line += " \(className)" }
        line += " \(formatRect(node.frame))"
        if let hierarchy = node.hierarchy {
            line += " -> view:\(hierarchy.viewOID)"
            if let layerOID = hierarchy.layerOID { line += " layer:\(layerOID)" }
            if let hierarchyClass = hierarchy.className, hierarchyClass != node.className {
                line += " \(hierarchyClass)"
            }
        } else {
            line += " -> [unmatched]"
        }
        lines.append(line)
    }
    return lines.joined(separator: "\n")
}

func axTreeLines(_ nodes: [TKAXNode], indent: Int) -> [String] {
    var lines: [String] = []
    for (index, node) in nodes.enumerated() {
        let isLast = index == nodes.count - 1
        let prefix: String
        if indent == 0 {
            prefix = ""
        } else {
            prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "└─ " : "├─ ")
        }
        var line = "\(prefix)\(node.role)"
        if let label = node.label, !label.isEmpty { line += " \"\(label)\"" }
        if let identifier = node.identifier, !identifier.isEmpty { line += " #\(identifier)" }
        if let oid = node.targetOID { line += " oid:\(oid)" }
        if let className = node.className { line += " \(className)" }
        line += " \(formatRect(node.frame))"
        if node.hidden { line += " [hidden]" }
        if !node.enabled { line += " [disabled]" }
        lines.append(line)
        lines.append(contentsOf: axTreeLines(node.children, indent: indent + 1))
    }
    return lines
}

func selectAXNode(_ nodes: [TKAXNode], oid: UInt?, label: String?) -> TKAXNode? {
    let flattened = TKFlattenAXNodes(nodes).map(\.node)
    if let oid {
        return flattened.first { $0.viewOID == oid || $0.targetOID == oid }
    }
    guard let label else { return nil }
    return flattened
        .filter { $0.label == label }
        .sorted { lhs, rhs in
            axTapPriority(lhs) > axTapPriority(rhs)
        }
        .first
}

struct TapTargetCandidate: Codable {
    let index: Int
    let query: String
    let source: String
    let strategy: String
    let role: String?
    let label: String?
    let value: String?
    let identifier: String?
    let className: String?
    let viewOID: UInt?
    let targetOID: UInt?
    let layerOID: UInt?
    let frame: TKRect?
    let request: TKInputRequest
}

struct TapTargetResolution: Codable {
    let query: String
    let source: String
    let strategy: String
    let role: String?
    let label: String?
    let value: String?
    let identifier: String?
    let className: String?
    let viewOID: UInt?
    let targetOID: UInt?
    let layerOID: UInt?
    let frame: TKRect?
    let request: TKInputRequest
    let matchIndex: Int
    let matchCount: Int
    let candidates: [TapTargetCandidate]?

    init(selected: TapTargetCandidate, candidates: [TapTargetCandidate], includeCandidates: Bool) {
        self.query = selected.query
        self.source = selected.source
        self.strategy = selected.strategy
        self.role = selected.role
        self.label = selected.label
        self.value = selected.value
        self.identifier = selected.identifier
        self.className = selected.className
        self.viewOID = selected.viewOID
        self.targetOID = selected.targetOID
        self.layerOID = selected.layerOID
        self.frame = selected.frame
        self.request = selected.request
        self.matchIndex = selected.index
        self.matchCount = candidates.count
        self.candidates = includeCandidates ? candidates : nil
    }
}

struct TKTapTargetResolutionFailure: Error, CustomStringConvertible {
    let query: String
    let message: String
    let candidateCount: Int
    let nearestCandidates: [String]
    let suggestedCommands: [String]

    var description: String { message }
}

func resolveTapTarget(
    _ query: String,
    client: TritonKitHTTPClient,
    width: Double?,
    height: Double?,
    duration: Double?,
    activationStrategy: TKTapActivationStrategy = .smart,
    index: Int? = nil,
    within: TKRect? = nil,
    at: (x: Double, y: Double)? = nil,
    includeCandidates: Bool = false
) async throws -> TapTargetResolution {
    if let index, index <= 0 {
        throw RuntimeError("--index must be greater than 0")
    }
    let candidates = try await tapTargetCandidates(
        query,
        client: client,
        width: width,
        height: height,
        duration: duration,
        activationStrategy: activationStrategy,
        within: within,
        at: at
    )
    guard !candidates.isEmpty else {
        throw TKTapTargetResolutionFailure(
            query: query,
            message: "No tappable UI target matched query: \(query)",
            candidateCount: 0,
            nearestCandidates: [],
            suggestedCommands: tapTargetSuggestedCommands(query: query)
        )
    }
    let selectedIndex = index ?? 1
    guard selectedIndex <= candidates.count else {
        throw TKTapTargetResolutionFailure(
            query: query,
            message: "Only \(candidates.count) tappable UI target(s) matched query: \(query); cannot select --index \(selectedIndex)",
            candidateCount: candidates.count,
            nearestCandidates: tapTargetNearestCandidates(candidates),
            suggestedCommands: tapTargetSuggestedCommands(query: query, candidates: candidates)
        )
    }
    return TapTargetResolution(
        selected: candidates[selectedIndex - 1],
        candidates: candidates,
        includeCandidates: includeCandidates
    )
}

/// Resolve a `find` query against a Harmony host uitest layout, producing the same
/// `TapTargetResolution` contract as the embedded path so `act find` output stays
/// uniform across `--platform harmony` and the iOS embedded runtime.
///
/// Matching mirrors `act tap --platform harmony`: a node matches when its
/// `attributes.text` equals the query and it has parseable bounds. The resolution
/// request is a coordinate tap at the matched node center, which is exactly the
/// request `act tap --platform harmony` would execute.
func resolveHostHarmonyFind(
    _ query: String,
    selected: TKHarmonyTarget,
    hdc: String,
    index: Int? = nil,
    within: TKRect? = nil,
    at: (x: Double, y: Double)? = nil,
    includeCandidates: Bool = false,
    captureLayout: (TKHarmonyTarget, String) throws -> HarmonyLayoutCapture = { selected, hdc in
        try dumpHarmonyLayout(selected: selected, hdc: hdc, output: nil)
    }
) throws -> TapTargetResolution {
    if let index, index <= 0 {
        throw RuntimeError("--index must be greater than 0")
    }
    let layout = try captureLayout(selected, hdc)
    let summaries = try TKHarmonyLayoutParser.nodeSummaries(in: layout.data)
    let matches = summaries
        .filter { $0.text == query && $0.bounds != nil }
        .filter { candidate in
            guard let within, let frame = candidate.bounds else { return true }
            return TKRectIntersects(frame, within)
        }
        .filter { candidate in
            guard let at, let frame = candidate.bounds else { return true }
            return frame.contains(x: at.x, y: at.y)
        }
        .sorted { lhs, rhs in
            let lhsFrame = lhs.bounds ?? TKRect(x: 0, y: 0, width: 0, height: 0)
            let rhsFrame = rhs.bounds ?? TKRect(x: 0, y: 0, width: 0, height: 0)
            if lhs.depth != rhs.depth { return lhs.depth < rhs.depth }
            if lhsFrame.y != rhsFrame.y { return lhsFrame.y < rhsFrame.y }
            if lhsFrame.x != rhsFrame.x { return lhsFrame.x < rhsFrame.x }
            return lhs.nodeID < rhs.nodeID
        }
    let candidates = matches.enumerated().map { offset, node in
        let frame = node.bounds ?? TKRect(x: 0, y: 0, width: 0, height: 0)
        return TapTargetCandidate(
            index: offset + 1,
            query: query,
            source: "host-harmony-layout",
            strategy: "coordinate",
            role: node.type,
            label: node.text,
            value: node.originalText != node.text ? node.originalText : nil,
            identifier: node.identifier,
            className: node.type,
            viewOID: nil,
            targetOID: nil,
            layerOID: nil,
            frame: frame,
            request: TKInputRequest.tap(x: frame.centerX, y: frame.centerY)
        )
    }
    guard !candidates.isEmpty else {
        throw TKTapTargetResolutionFailure(
            query: query,
            message: "No Harmony layout node matched query: \(query)",
            candidateCount: 0,
            nearestCandidates: [],
            suggestedCommands: [
                "triton act find \(shellQuoted(query)) --platform harmony --device <harmony-target> --all --json",
                "triton debug ax --platform harmony --output <path> --json",
            ]
        )
    }
    let selectedIndex = index ?? 1
    guard selectedIndex <= candidates.count else {
        throw TKTapTargetResolutionFailure(
            query: query,
            message: "Only \(candidates.count) Harmony layout node(s) matched query: \(query); cannot select --index \(selectedIndex)",
            candidateCount: candidates.count,
            nearestCandidates: tapTargetNearestCandidates(candidates),
            suggestedCommands: [
                "triton act find \(shellQuoted(query)) --platform harmony --device <harmony-target> --all --json",
                "triton debug ax --platform harmony --output <path> --json",
            ]
        )
    }
    return TapTargetResolution(
        selected: candidates[selectedIndex - 1],
        candidates: candidates,
        includeCandidates: includeCandidates
    )
}

func tapTargetCandidates(
    _ query: String,
    client: TritonKitHTTPClient,
    width: Double?,
    height: Double?,
    duration: Double?,
    activationStrategy: TKTapActivationStrategy,
    within: TKRect?,
    at: (x: Double, y: Double)?
) async throws -> [TapTargetCandidate] {
    let accessibilityData = try await client.request(type: "accessibility")
    let axNodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    let directAXCandidates = selectAXNodesByQuery(axNodes, query: query, includeValue: false)
        .map { axNode in
            let request = tapRequest(
                for: axNode,
                width: width,
                height: height,
                duration: duration,
                activationStrategy: activationStrategy
            )
            return TapTargetCandidate(
                index: 0,
                query: query,
                source: "ax",
                strategy: tapCandidateStrategy(for: axNode, activationStrategy: activationStrategy),
                role: axNode.role,
                label: axNode.label,
                value: axNode.value,
                identifier: axNode.identifier,
                className: axNode.className,
                viewOID: axNode.viewOID,
                targetOID: axNode.targetOID,
                layerOID: axNode.layerOID,
                frame: axNode.frame,
                request: request
            )
        }

    let hierarchyData = try await client.request(type: "hierarchy")
    let hierarchyCandidates = try await selectHierarchyTextCandidates(
        query,
        hierarchyData: hierarchyData,
        client: client
    ).map { candidate in
        let request: TKInputRequest
        if activationStrategy == .exact {
            request = TKInputRequest.tap(
                x: candidate.frame.centerX,
                y: candidate.frame.centerY,
                width: width,
                height: height,
                duration: duration
            )
        } else {
            request = TKInputRequest.tap(
                targetOID: candidate.viewOID,
                width: width,
                height: height,
                duration: duration,
                matchedOID: candidate.viewOID,
                matchedClassName: candidate.className,
                activationStrategy: activationStrategy
            )
        }
        return TapTargetCandidate(
            index: 0,
            query: query,
            source: "hierarchy-text",
            strategy: activationStrategy == .exact ? "coordinate" : activationStrategy.rawValue,
            role: nil,
            label: query,
            value: nil,
            identifier: nil,
            className: candidate.className,
            viewOID: candidate.viewOID,
            targetOID: nil,
            layerOID: candidate.layerOID,
            frame: candidate.frame,
            request: request
        )
    }

    let valueAXCandidates = selectAXNodesByQuery(axNodes, query: query, includeValue: true)
        .filter { node in
            !TKAXNodeMatchesText(node, query: query, includeValue: false)
        }
        .map { axNode in
            let request = tapRequest(
                for: axNode,
                width: width,
                height: height,
                duration: duration,
                activationStrategy: activationStrategy
            )
            return TapTargetCandidate(
                index: 0,
                query: query,
                source: "ax-value",
                strategy: tapCandidateStrategy(for: axNode, activationStrategy: activationStrategy),
                role: axNode.role,
                label: axNode.label,
                value: axNode.value,
                identifier: axNode.identifier,
                className: axNode.className,
                viewOID: axNode.viewOID,
                targetOID: axNode.targetOID,
                layerOID: axNode.layerOID,
                frame: axNode.frame,
                request: request
            )
        }

    let candidates = (directAXCandidates + hierarchyCandidates + valueAXCandidates)
        .filter { candidate in
            guard let within else { return true }
            guard let frame = candidate.frame else { return false }
            return TKRectIntersects(frame, within)
        }
        .filter { candidate in
            guard let at else { return true }
            guard let frame = candidate.frame else { return false }
            return frame.contains(x: at.x, y: at.y)
        }

    return candidates.enumerated().map { offset, candidate in
        TapTargetCandidate(
            index: offset + 1,
            query: candidate.query,
            source: candidate.source,
            strategy: candidate.strategy,
            role: candidate.role,
            label: candidate.label,
            value: candidate.value,
            identifier: candidate.identifier,
            className: candidate.className,
            viewOID: candidate.viewOID,
            targetOID: candidate.targetOID,
            layerOID: candidate.layerOID,
            frame: candidate.frame,
            request: candidate.request
        )
    }
}

func selectAXNodesByQuery(
    _ nodes: [TKAXNode],
    query: String,
    includeValue: Bool = true,
    match: TKTextMatchMode = .substring
) -> [TKAXNode] {
    TKFlattenAXNodes(nodes)
        .map(\.node)
        .filter { node in
            // Shared visibility rule with `wait --text`: hidden nodes are not
            // query targets; `observe` remains the authoritative view that still
            // lists them with `hidden` metadata.
            !node.hidden && TKAXNodeMatchesText(node, query: query, mode: match, includeValue: includeValue)
        }
        .sorted { lhs, rhs in
            if axTapPriority(lhs) != axTapPriority(rhs) {
                return axTapPriority(lhs) > axTapPriority(rhs)
            }
            if lhs.frame.y != rhs.frame.y {
                return lhs.frame.y < rhs.frame.y
            }
            if lhs.frame.x != rhs.frame.x {
                return lhs.frame.x < rhs.frame.x
            }
            return (lhs.targetOID ?? lhs.viewOID ?? 0) < (rhs.targetOID ?? rhs.viewOID ?? 0)
        }
}

func tapRequest(
    for node: TKAXNode,
    width: Double?,
    height: Double?,
    duration: Double?,
    activationStrategy: TKTapActivationStrategy = .exact
) -> TKInputRequest {
    let resolvedMatchedOID = node.viewOID ?? node.targetOID

    if activationStrategy != .exact, let matchedOID = resolvedMatchedOID {
        return TKInputRequest.tap(
            targetOID: matchedOID,
            width: width,
            height: height,
            duration: duration,
            matchedOID: matchedOID,
            matchedClassName: node.className,
            activationStrategy: activationStrategy
        )
    }

    if axTapShouldUseCoordinate(node) {
        return TKInputRequest.tap(
            x: node.frame.centerX,
            y: node.frame.centerY,
            width: width,
            height: height,
            duration: duration,
            matchedOID: resolvedMatchedOID,
            matchedClassName: node.className,
            activationStrategy: .exact
        )
    }
    return TKInputRequest.tap(
        targetOID: node.targetOID ?? node.viewOID,
        width: width,
        height: height,
        duration: duration,
        matchedOID: resolvedMatchedOID,
        matchedClassName: node.className,
        activationStrategy: .exact
    )
}

func tapCandidateStrategy(for node: TKAXNode, activationStrategy: TKTapActivationStrategy) -> String {
    if activationStrategy != .exact {
        return activationStrategy.rawValue
    }
    return axTapShouldUseCoordinate(node) ? "coordinate" : "oid"
}

func tapTargetNearestCandidates(_ candidates: [TapTargetCandidate], limit: Int = 5) -> [String] {
    candidates.prefix(limit).map { candidate in
        var parts: [String] = ["[\(candidate.index)]", candidate.source, candidate.strategy]
        if let label = candidate.label { parts.append("label=\(label)") }
        if let value = candidate.value { parts.append("value=\(value)") }
        if let identifier = candidate.identifier { parts.append("identifier=\(identifier)") }
        if let className = candidate.className { parts.append("class=\(className)") }
        if let frame = candidate.frame { parts.append("frame=\(frame.x),\(frame.y),\(frame.width),\(frame.height)") }
        return parts.joined(separator: " ")
    }
}

func tapTargetSuggestedCommands(query: String, candidates: [TapTargetCandidate] = []) -> [String] {
    var commands = ["triton act find \(shellQuoted(query)) --all --json", "triton screenshot --json"]
    if !candidates.isEmpty {
        commands.insert("triton act tap \(shellQuoted(query)) --index 1 --json", at: 1)
    }
    return commands
}

private func shellQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func axTapShouldUseCoordinate(_ node: TKAXNode) -> Bool {
    if node.targetOID == nil && node.viewOID == nil {
        return true
    }
    return ["text", "image", "textField", "textView"].contains(node.role)
}

struct HierarchyTextCandidate {
    let viewOID: UInt
    let layerOID: UInt
    let className: String
    let frame: TKRect
    let depth: Int
}

func selectHierarchyTextCandidates(
    _ query: String,
    hierarchyData: Data,
    client: TritonKitHTTPClient
) async throws -> [HierarchyTextCandidate] {
    let candidates = try hierarchyTextCandidates(hierarchyData)
        .sorted { lhs, rhs in
            if hierarchyTextCandidatePriority(lhs) != hierarchyTextCandidatePriority(rhs) {
                return hierarchyTextCandidatePriority(lhs) > hierarchyTextCandidatePriority(rhs)
            }
            if lhs.frame.y != rhs.frame.y {
                return lhs.frame.y < rhs.frame.y
            }
            if lhs.frame.x != rhs.frame.x {
                return lhs.frame.x < rhs.frame.x
            }
            return lhs.viewOID < rhs.viewOID
        }

    var matches: [HierarchyTextCandidate] = []
    for candidate in candidates {
        let payload = try JSONEncoder().encode(candidate.layerOID)
        let data = try await client.request(type: "allAttrGroups", payload: payload)
        let groups = try JSONDecoder().decode([TKAttributesGroup].self, from: data)
        if attributeGroups(groups, containText: query) {
            matches.append(candidate)
        }
    }
    return matches
}

func hierarchyTextCandidates(_ data: Data) throws -> [HierarchyTextCandidate] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }
    return flattenHierarchyTextCandidates(items, depth: 0, ancestorVisible: true)
}

func flattenHierarchyTextCandidates(
    _ items: [[String: Any]],
    depth: Int,
    ancestorVisible: Bool
) -> [HierarchyTextCandidate] {
    var candidates: [HierarchyTextCandidate] = []
    for item in items {
        let viewObj = item["viewObject"] as? [String: Any]
        let layerObj = item["layerObject"] as? [String: Any]
        let viewOid = viewObj?["oid"] as? UInt ?? uintValue(viewObj?["oid"])
        let layerOid = layerObj?["oid"] as? UInt ?? uintValue(layerObj?["oid"])
        let className = (viewObj?["classChainList"] as? [String])?.first
            ?? (layerObj?["classChainList"] as? [String])?.first
            ?? ""
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = doubleValue(item["alpha"]) ?? 1
        let visible = ancestorVisible && !hidden && alpha > 0.01
        if let viewOid,
           let layerOid,
           let frame = rectValue(item["frame"]),
           visible,
           frame.width > 0,
           frame.height > 0,
           isHierarchyTextCandidateClass(className) {
            candidates.append(HierarchyTextCandidate(
                viewOID: viewOid,
                layerOID: layerOid,
                className: className,
                frame: frame,
                depth: depth
            ))
        }
        if let subitems = item["subitems"] as? [[String: Any]] {
            candidates.append(contentsOf: flattenHierarchyTextCandidates(
                subitems,
                depth: depth + 1,
                ancestorVisible: visible
            ))
        }
    }
    return candidates
}

func isHierarchyTextCandidateClass(_ className: String) -> Bool {
    className == "UILabel"
        || className == "UISegmentLabel"
        || className == "UIButtonLabel"
        || className == "UITextFieldLabel"
        || className.hasSuffix("Label")
}

func hierarchyTextCandidatePriority(_ candidate: HierarchyTextCandidate) -> Int {
    var priority = 0
    if candidate.className == "UISegmentLabel" { priority += 30 }
    if candidate.className == "UIButtonLabel" { priority += 20 }
    if candidate.className == "UILabel" { priority += 10 }
    priority -= candidate.depth
    return priority
}

func attributeGroups(_ groups: [TKAttributesGroup], containText query: String) -> Bool {
    for group in groups {
        for section in group.attrSections {
            for attribute in section.attributes where isTextAttribute(attribute) {
                if attributeValueString(attribute.value) == query {
                    return true
                }
            }
        }
    }
    return false
}

func isTextAttribute(_ attribute: TKAttribute) -> Bool {
    attribute.identifier == "text" || attribute.displayTitle == "Text" || attribute.displayTitle == "Title"
}

func attributeValueString(_ value: TKAttributeValue?) -> String? {
    guard let value else { return nil }
    switch value {
    case .string(let string):
        return string
    case .number(let number):
        return "\(number)"
    case .bool(let bool):
        return bool ? "true" : "false"
    case .stringArray(let strings):
        return strings.joined(separator: ",")
    case .numberArray(let numbers):
        return numbers.map { "\($0)" }.joined(separator: ",")
    case .null:
        return nil
    }
}

func axTapPriority(_ node: TKAXNode) -> Int {
    var priority = 0
    if !node.hidden { priority += 10 }
    if node.enabled { priority += 10 }
    if ["button", "segmentedControl", "switch", "slider", "stepper", "textField", "textView", "control"].contains(node.role) {
        priority += 20
    }
    if node.role == "text" {
        priority -= 10
    }
    if node.targetOID != nil || node.viewOID != nil {
        priority += 5
    }
    return priority
}

func formatRect(_ rect: TKRect) -> String {
    String(format: "(%.0f,%.0f %.0fx%.0f)", rect.x, rect.y, rect.width, rect.height)
}

func resolveExportFormat(_ format: ExportOutputFormat, output: String) throws -> ExportOutputFormat {
    switch format {
    case .json, .archive:
        return format
    case .auto:
        let pathExtension = URL(fileURLWithPath: output).pathExtension.lowercased()
        switch pathExtension {
        case "", "json":
            return .json
        case "triton", "tritonkit", "archive", "lookinside":
            return .archive
        default:
            throw RuntimeError("Unsupported export extension: .\(pathExtension)")
        }
    }
}

// Flush-printing to stderr for immediate output in piped environments
