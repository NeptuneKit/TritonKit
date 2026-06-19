import Foundation

public struct TKHierarchyViewport: Codable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct TKHierarchyLayerNode: Codable, Equatable {
    public let id: String
    public let parentId: String?
    public let type: String
    public let name: String
    public let frame: TKRect
    public let depth: Int
    public let visible: Bool
    public let interactive: Bool
    public let color: String?
    public let source: String?

    public init(
        id: String,
        parentId: String?,
        type: String,
        name: String,
        frame: TKRect,
        depth: Int,
        visible: Bool,
        interactive: Bool,
        color: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.parentId = parentId
        self.type = type
        self.name = name
        self.frame = frame
        self.depth = depth
        self.visible = visible
        self.interactive = interactive
        self.color = color
        self.source = source
    }
}

public struct TKHierarchyScene: Codable, Equatable {
    public let platform: String
    public let rootId: String
    public let viewport: TKHierarchyViewport
    public let nodes: [TKHierarchyLayerNode]

    public init(platform: String, rootId: String, viewport: TKHierarchyViewport, nodes: [TKHierarchyLayerNode]) {
        self.platform = platform
        self.rootId = rootId
        self.viewport = viewport
        self.nodes = nodes
    }
}

public struct TKHierarchySourceInfo: Codable, Equatable {
    public let command: String
    public let runtimeScope: String
    public let readonly: Bool

    public init(command: String, runtimeScope: String, readonly: Bool) {
        self.command = command
        self.runtimeScope = runtimeScope
        self.readonly = readonly
    }
}

public struct TKHostHierarchyResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let source: TKHierarchySourceInfo
    public let scene: TKHierarchyScene

    public init(ok: Bool, capturedAt: String, source: TKHierarchySourceInfo, scene: TKHierarchyScene) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.source = source
        self.scene = scene
    }
}
