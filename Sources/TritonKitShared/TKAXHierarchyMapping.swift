import Foundation

public struct TKHierarchyViewMatch: Codable, Equatable {
    public let viewOID: UInt
    public let layerOID: UInt?
    public let className: String?
    public let frame: TKRect?
    public let hidden: Bool
    public let alpha: Double?
    public let depth: Int
    public let path: [String]

    public init(
        viewOID: UInt,
        layerOID: UInt?,
        className: String?,
        frame: TKRect?,
        hidden: Bool,
        alpha: Double?,
        depth: Int,
        path: [String]
    ) {
        self.viewOID = viewOID
        self.layerOID = layerOID
        self.className = className
        self.frame = frame
        self.hidden = hidden
        self.alpha = alpha
        self.depth = depth
        self.path = path
    }
}

public struct TKAXHierarchyMappedNode: Codable, Equatable {
    public let depth: Int
    public let role: String
    public let label: String?
    public let value: String?
    public let identifier: String?
    public let title: String?
    public let frame: TKRect
    public let enabled: Bool
    public let focused: Bool
    public let hidden: Bool
    public let targetOID: UInt?
    public let viewOID: UInt?
    public let layerOID: UInt?
    public let className: String?
    public let hierarchy: TKHierarchyViewMatch?

    public init(node: TKAXNode, depth: Int, hierarchy: TKHierarchyViewMatch?) {
        self.depth = depth
        self.role = node.role
        self.label = node.label
        self.value = node.value
        self.identifier = node.identifier
        self.title = node.title
        self.frame = node.frame
        self.enabled = node.enabled
        self.focused = node.focused
        self.hidden = node.hidden
        self.targetOID = node.targetOID
        self.viewOID = node.viewOID
        self.layerOID = node.layerOID
        self.className = node.className
        self.hierarchy = hierarchy
    }
}

public struct TKAXHierarchyMapResponse: Codable, Equatable {
    public let schemaVersion: Int
    public let axNodeCount: Int
    public let hierarchyNodeCount: Int
    public let mappedCount: Int
    public let unmatchedCount: Int
    public let nodes: [TKAXHierarchyMappedNode]

    public init(
        schemaVersion: Int = 1,
        axNodeCount: Int,
        hierarchyNodeCount: Int,
        mappedCount: Int,
        unmatchedCount: Int,
        nodes: [TKAXHierarchyMappedNode]
    ) {
        self.schemaVersion = schemaVersion
        self.axNodeCount = axNodeCount
        self.hierarchyNodeCount = hierarchyNodeCount
        self.mappedCount = mappedCount
        self.unmatchedCount = unmatchedCount
        self.nodes = nodes
    }
}

public func TKFlattenAXNodes(_ nodes: [TKAXNode]) -> [(node: TKAXNode, depth: Int)] {
    flattenAXNodes(nodes, depth: 0)
}

public func TKBuildAXHierarchyMap(
    axNodes: [TKAXNode],
    hierarchyData: Data
) throws -> TKAXHierarchyMapResponse {
    let hierarchy = try JSONDecoder().decode(TKJSONValue.self, from: hierarchyData)
    let flattenedHierarchy = flattenHierarchyItems(from: hierarchy)
    var index: [UInt: TKHierarchyViewMatch] = [:]

    for item in flattenedHierarchy {
        guard let viewOID = item.viewOID else { continue }
        if index[viewOID] == nil {
            index[viewOID] = TKHierarchyViewMatch(
                viewOID: viewOID,
                layerOID: item.layerOID,
                className: item.className,
                frame: item.frame,
                hidden: item.hidden,
                alpha: item.alpha,
                depth: item.depth,
                path: item.path
            )
        }
    }

    let flattenedAX = TKFlattenAXNodes(axNodes)
    let mapped = flattenedAX.map { entry -> TKAXHierarchyMappedNode in
        let node = entry.node
        let match = node.viewOID.flatMap { index[$0] } ?? node.targetOID.flatMap { index[$0] }
        return TKAXHierarchyMappedNode(node: node, depth: entry.depth, hierarchy: match)
    }
    let mappedCount = mapped.filter { $0.hierarchy != nil }.count

    return TKAXHierarchyMapResponse(
        axNodeCount: mapped.count,
        hierarchyNodeCount: flattenedHierarchy.count,
        mappedCount: mappedCount,
        unmatchedCount: mapped.count - mappedCount,
        nodes: mapped
    )
}

private struct FlattenedHierarchyItem {
    let viewOID: UInt?
    let layerOID: UInt?
    let className: String?
    let frame: TKRect?
    let hidden: Bool
    let alpha: Double?
    let depth: Int
    let path: [String]
}

private func flattenAXNodes(_ nodes: [TKAXNode], depth: Int) -> [(node: TKAXNode, depth: Int)] {
    nodes.flatMap { node in
        [(node, depth)] + flattenAXNodes(node.children, depth: depth + 1)
    }
}

private func flattenHierarchyItems(from hierarchy: TKJSONValue) -> [FlattenedHierarchyItem] {
    guard
        let root = hierarchy.objectValue,
        let displayItems = root["displayItems"]?.arrayValue
    else {
        return []
    }
    return displayItems.flatMap { flattenHierarchyItem($0, depth: 0, path: []) }
}

private func flattenHierarchyItem(_ item: TKJSONValue, depth: Int, path: [String]) -> [FlattenedHierarchyItem] {
    guard let object = item.objectValue else { return [] }
    let viewObject = object["viewObject"]?.objectValue
    let layerObject = object["layerObject"]?.objectValue
    let className = className(from: viewObject) ?? className(from: layerObject)
    let currentPath = path + [className ?? "?"]
    let current = FlattenedHierarchyItem(
        viewOID: viewObject?["oid"]?.uintValue,
        layerOID: layerObject?["oid"]?.uintValue,
        className: className,
        frame: rect(from: object["frame"]),
        hidden: object["isHidden"]?.boolValue ?? false,
        alpha: object["alpha"]?.doubleValue,
        depth: depth,
        path: currentPath
    )
    let children = object["subitems"]?.arrayValue ?? []
    return [current] + children.flatMap { flattenHierarchyItem($0, depth: depth + 1, path: currentPath) }
}

private func className(from object: [String: TKJSONValue]?) -> String? {
    object?["classChainList"]?.arrayValue?.first?.stringValue
}

private func rect(from value: TKJSONValue?) -> TKRect? {
    if let object = value?.objectValue {
        guard
            let x = object["x"]?.doubleValue,
            let y = object["y"]?.doubleValue,
            let width = object["width"]?.doubleValue,
            let height = object["height"]?.doubleValue
        else {
            return nil
        }
        return TKRect(x: x, y: y, width: width, height: height)
    }
    guard
        let array = value?.arrayValue,
        array.count >= 2,
        let origin = array[0].arrayValue,
        let size = array[1].arrayValue,
        origin.count >= 2,
        size.count >= 2,
        let x = origin[0].doubleValue,
        let y = origin[1].doubleValue,
        let width = size[0].doubleValue,
        let height = size[1].doubleValue
    else {
        return nil
    }
    return TKRect(x: x, y: y, width: width, height: height)
}

private extension TKJSONValue {
    var objectValue: [String: TKJSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    var arrayValue: [TKJSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        default:
            return nil
        }
    }

    var uintValue: UInt? {
        switch self {
        case .int(let value) where value >= 0:
            return UInt(value)
        case .double(let value) where value >= 0:
            return UInt(value)
        default:
            return nil
        }
    }
}
