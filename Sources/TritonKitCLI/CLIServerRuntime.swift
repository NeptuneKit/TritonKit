import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

func log(_ msg: String) {
    fputs("\(msg)\n", stderr)
    fflush(stderr)
}

// MARK: - Extensions

extension WebSocketOutboundWriter {
    func send(_ msg: TKMessage, encoder: JSONEncoder) async throws {
        guard let data = try? encoder.encode(msg) else { return }
        try await write(.binary(ByteBuffer(data: data)))
    }
}

// MARK: - Response Handling

func handleResponse(
    data: Data,
    store: DataStore,
    targetState: TargetState
) {
    guard let msg = try? JSONDecoder().decode(TKMessage.self, from: data) else {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            log("[tritonkit] <- raw:\n\(str)")
        }
        return
    }

    log("[tritonkit] <- \(msg.type.rawValue) [id:\(msg.id)]")

    guard let payload = msg.payload,
          let json = try? JSONSerialization.jsonObject(with: payload) else { return }
    targetState.storeResponse(id: msg.id, payload: payload)

    switch msg.type {
    case .hierarchy:
        targetState.setLatestHierarchy(payload)
        if let dict = json as? [String: Any] {
            if let items = dict["displayItems"] as? [[String: Any]] {
                printHierarchy(items, indent: 0)
            }
            if let info = dict["appInfo"] as? [String: Any] {
                log("── App: \(info["appName"] ?? "?") | \(info["deviceDescription"] ?? "?") | OS \(info["osDescription"] ?? "?")")
            }
        }

    case .appInfo:
        targetState.setLatestAppInfo(payload)
        if let dict = json as? [String: Any] {
            log("── \(dict["appName"] ?? "?") | \(dict["appBundleIdentifier"] ?? "?") | Device: \(dict["deviceDescription"] ?? "?")")
        }

    case .hierarchyDetails:
        checkAndShowImage(json: json, label: "solo", store: store)
        checkAndShowImage(json: json, label: "group", store: store)

    case .ping: log("  Pong!")
    default:
        if let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) { log(str) }
    }
}

func checkAndShowImage(json: Any, label: String, store: DataStore) {
    guard let dict = json as? [String: Any],
          let ref = dict["\(label)ScreenshotRef"] as? String,
          let id = UUID(uuidString: ref),
          let imgData = store.get(id) else { return }
    let size = ByteCountFormatter.string(fromByteCount: Int64(imgData.count), countStyle: .file)
    log("  [\(label) screenshot: \(size)]")
}

func renderHierarchyTree(_ data: Data, hideNoise: Bool = true) throws -> String {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }

    var lines: [String] = []
    if let info = json["appInfo"] as? [String: Any] {
        let appName = info["appName"] as? String ?? "?"
        let device = info["deviceDescription"] as? String ?? "?"
        let os = info["osDescription"] as? String ?? "?"
        lines.append("App: \(appName) | \(device) | OS \(os)")
    }
    lines.append(contentsOf: hierarchyTreeLines(items, indent: 0, hideNoise: hideNoise))
    return lines.joined(separator: "\n")
}

func hierarchyNodeSummaries(_ data: Data) throws -> [[String: Any]] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }
    return flattenNodeSummaries(items, depth: 0)
}

func flattenNodeSummaries(_ items: [[String: Any]], depth: Int) -> [[String: Any]] {
    var nodes: [[String: Any]] = []
    for item in items {
        let viewObj = item["viewObject"] as? [String: Any]
        let layerObj = item["layerObject"] as? [String: Any]
        let viewOid = viewObj?["oid"] as? UInt ?? uintValue(viewObj?["oid"])
        let layerOid = layerObj?["oid"] as? UInt ?? uintValue(layerObj?["oid"])
        let oid = viewOid ?? layerOid ?? 0
        let className = (viewObj?["classChainList"] as? [String])?.first
            ?? (layerObj?["classChainList"] as? [String])?.first
            ?? "?"
        var node: [String: Any] = [
            "oid": oid,
            "className": className,
            "depth": depth,
            "hidden": item["isHidden"] as? Bool ?? false,
            "alpha": doubleValue(item["alpha"]) ?? 1,
            "frame": frameDescription(item["frame"]) ?? "",
        ]
        if let viewOid { node["viewOid"] = viewOid }
        if let layerOid { node["layerOid"] = layerOid }
        if let title = item["customDisplayTitle"] as? String { node["title"] = title }
        nodes.append(node)
        if let subitems = item["subitems"] as? [[String: Any]] {
            nodes.append(contentsOf: flattenNodeSummaries(subitems, depth: depth + 1))
        }
    }
    return nodes
}

func uintValue(_ value: Any?) -> UInt? {
    if let value = value as? UInt { return value }
    if let value = value as? Int { return UInt(value) }
    if let value = value as? NSNumber { return value.uintValue }
    return nil
}

func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Float { return Double(value) }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    return nil
}

func rectValue(_ frame: Any?) -> TKRect? {
    if let dict = frame as? [String: Any] {
        return TKRect(
            x: doubleValue(dict["x"]) ?? 0,
            y: doubleValue(dict["y"]) ?? 0,
            width: doubleValue(dict["width"]) ?? 0,
            height: doubleValue(dict["height"]) ?? 0
        )
    }
    guard let array = frame as? [[Double]], array.count >= 2 else {
        return nil
    }
    let origin = array[0]
    let size = array[1]
    guard origin.count >= 2, size.count >= 2 else {
        return nil
    }
    return TKRect(x: origin[0], y: origin[1], width: size[0], height: size[1])
}

func nodeMatches(_ node: [String: Any], oid: UInt) -> Bool {
    uintValue(node["oid"]) == oid || uintValue(node["viewOid"]) == oid || uintValue(node["layerOid"]) == oid
}

func renderNodeLine(_ node: [String: Any]) -> String {
    [
        "\(node["oid"] ?? "-")",
        "\(node["layerOid"] ?? "-")",
        "\(node["depth"] ?? "-")",
        "\(node["className"] ?? "-")",
        "\(node["frame"] ?? "-")",
    ].joined(separator: "\t")
}

func renderAttributeGroups(_ groups: [TKAttributesGroup]) -> String {
    guard !groups.isEmpty else { return "No attributes" }
    var lines: [String] = []
    for group in groups {
        lines.append("[\(group.title)]")
        for section in group.attrSections {
            lines.append("  \(section.identifier)")
            for attribute in section.attributes {
                lines.append("    \(attribute.displayTitle ?? attribute.identifier): \(describeAttributeValue(attribute.value))")
            }
        }
    }
    return lines.joined(separator: "\n")
}

func describeAttributeValue(_ value: TKAttributeValue?) -> String {
    guard let value else { return "-" }
    switch value {
    case .null: return "null"
    case .string(let value): return value
    case .number(let value): return "\(value)"
    case .bool(let value): return "\(value)"
    case .stringArray(let value): return value.joined(separator: ",")
    case .numberArray(let value): return value.map { "\($0)" }.joined(separator: ",")
    }
}

func printHierarchy(_ items: [[String: Any]], indent: Int) {
    for line in hierarchyTreeLines(items, indent: indent, hideNoise: true) {
        log(line)
    }
}

func hierarchyTreeLines(_ items: [[String: Any]], indent: Int, hideNoise: Bool = true) -> [String] {
    var lines: [String] = []
    let renderedItems = hierarchyTreeRenderableItems(items, hideNoise: hideNoise)
    for (i, item) in renderedItems.enumerated() {
        let isLast = i == renderedItems.count - 1
        let prefix: String
        if indent == 0 { prefix = "  " }
        else { prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "  └─ " : "  ├─ ") }

        let viewObj = item["viewObject"] as? [String: Any]
        let className = (viewObj?["classChainList"] as? [String])?.first ?? "?"
        let frame = item["frame"]
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = item["alpha"] as? Float ?? 1.0
        let title = item["customDisplayTitle"] as? String
        let screenshotRef = item["screenshotRef"] as? String

        var line = "\(prefix)\(className)"
        if let t = title { line += " \"\(t)\"" }
        if let frame = frameDescription(frame) {
            line += " \(frame)"
        }
        if hidden { line += " [H]" }
        if alpha < 1 { line += String(format: " α:%.2f", alpha) }
        if screenshotRef != nil { line += " [image]" }
        lines.append(line)

        if let subitems = item["subitems"] as? [[String: Any]] {
            lines.append(contentsOf: hierarchyTreeLines(subitems, indent: indent + 1, hideNoise: hideNoise))
        }
    }
    return lines
}

func hierarchyTreeRenderableItems(_ items: [[String: Any]], hideNoise: Bool) -> [[String: Any]] {
    guard hideNoise else { return items }
    return items.flatMap { item -> [[String: Any]] in
        guard let className = hierarchyTreeClassName(item),
              TKIsDefaultHiddenHierarchyTreeClass(className),
              let subitems = item["subitems"] as? [[String: Any]]
        else {
            return [item]
        }
        return hierarchyTreeRenderableItems(subitems, hideNoise: hideNoise)
    }
}

func hierarchyTreeClassName(_ item: [String: Any]) -> String? {
    let viewObj = item["viewObject"] as? [String: Any]
    if let className = (viewObj?["classChainList"] as? [String])?.first {
        return className
    }
    let layerObj = item["layerObject"] as? [String: Any]
    return (layerObj?["classChainList"] as? [String])?.first
}

func frameDescription(_ frame: Any?) -> String? {
    if let dict = frame as? [String: Any] {
        return String(format: "(%.0f,%.0f %.0fx%.0f)",
            dict["x"] as? Double ?? 0, dict["y"] as? Double ?? 0,
            dict["width"] as? Double ?? 0, dict["height"] as? Double ?? 0)
    }
    guard let array = frame as? [[Double]], array.count >= 2 else {
        return nil
    }
    let origin = array[0]
    let size = array[1]
    guard origin.count >= 2, size.count >= 2 else {
        return nil
    }
    return String(format: "(%.0f,%.0f %.0fx%.0f)", origin[0], origin[1], size[0], size[1])
}
