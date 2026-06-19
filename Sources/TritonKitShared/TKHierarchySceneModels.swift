import Foundation

public struct TKHierarchyViewport: Codable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct TKHierarchyNodeStyle: Codable, Equatable {
    public let display: String?
    public let text: String?
    public let backgroundColor: String?
    public let foregroundColor: String?
    public let alpha: Double?
    public let cornerRadius: Double?

    public init(
        display: String? = nil,
        text: String? = nil,
        backgroundColor: String? = nil,
        foregroundColor: String? = nil,
        alpha: Double? = nil,
        cornerRadius: Double? = nil
    ) {
        self.display = display
        self.text = text
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.alpha = alpha
        self.cornerRadius = cornerRadius
    }
}

public struct TKHierarchyNodeSlice: Codable, Equatable {
    public let available: Bool
    public let mode: String?
    public let source: String?
    public let dataRef: String?
    public let dataUrl: String?

    public init(available: Bool, mode: String? = nil, source: String? = nil, dataRef: String? = nil, dataUrl: String? = nil) {
        self.available = available
        self.mode = mode
        self.source = source
        self.dataRef = dataRef
        self.dataUrl = dataUrl
    }
}

public struct TKHierarchyPoint: Codable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct TKHierarchySize: Codable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct TKHierarchyViewMetadata: Codable, Equatable {
    public let className: String?
    public let isHidden: Bool?
    public let alpha: Double?
    public let isUserInteractionEnabled: Bool?
    public let accessibilityIdentifier: String?
    public let accessibilityLabel: String?

    public init(
        className: String? = nil,
        isHidden: Bool? = nil,
        alpha: Double? = nil,
        isUserInteractionEnabled: Bool? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.className = className
        self.isHidden = isHidden
        self.alpha = alpha
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct TKHierarchyLayerMetadata: Codable, Equatable {
    public let bounds: TKRect
    public let position: TKHierarchyPoint
    public let anchorPoint: TKHierarchyPoint
    public let zPosition: Double
    public let transform: [Double]?
    public let sublayerTransform: [Double]?
    public let masksToBounds: Bool
    public let cornerRadius: Double
    public let opacity: Double
    public let isHidden: Bool
    public let contentsScale: Double?
    public let contentsGravity: String?
    public let contentsRect: TKRect?
    public let borderWidth: Double?
    public let borderColor: String?
    public let shadowOpacity: Double?
    public let shadowRadius: Double?
    public let shadowOffset: TKHierarchySize?
    public let shadowColor: String?

    public init(
        bounds: TKRect,
        position: TKHierarchyPoint,
        anchorPoint: TKHierarchyPoint,
        zPosition: Double,
        transform: [Double]? = nil,
        sublayerTransform: [Double]? = nil,
        masksToBounds: Bool,
        cornerRadius: Double,
        opacity: Double,
        isHidden: Bool,
        contentsScale: Double? = nil,
        contentsGravity: String? = nil,
        contentsRect: TKRect? = nil,
        borderWidth: Double? = nil,
        borderColor: String? = nil,
        shadowOpacity: Double? = nil,
        shadowRadius: Double? = nil,
        shadowOffset: TKHierarchySize? = nil,
        shadowColor: String? = nil
    ) {
        self.bounds = bounds
        self.position = position
        self.anchorPoint = anchorPoint
        self.zPosition = zPosition
        self.transform = transform
        self.sublayerTransform = sublayerTransform
        self.masksToBounds = masksToBounds
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.isHidden = isHidden
        self.contentsScale = contentsScale
        self.contentsGravity = contentsGravity
        self.contentsRect = contentsRect
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.shadowColor = shadowColor
    }
}

public struct TKHierarchyVisualSource: Codable, Equatable {
    public let kind: String
    public let dataRef: String?
    public let dataUrl: String?
    public let rect: TKRect?
    public let capturedBy: String?
    public let contentsScale: Double?
    public let contentsGravity: String?
    public let contentsRect: TKRect?
    public let reason: String?

    public init(
        kind: String,
        dataRef: String? = nil,
        dataUrl: String? = nil,
        rect: TKRect? = nil,
        capturedBy: String? = nil,
        contentsScale: Double? = nil,
        contentsGravity: String? = nil,
        contentsRect: TKRect? = nil,
        reason: String? = nil
    ) {
        self.kind = kind
        self.dataRef = dataRef
        self.dataUrl = dataUrl
        self.rect = rect
        self.capturedBy = capturedBy
        self.contentsScale = contentsScale
        self.contentsGravity = contentsGravity
        self.contentsRect = contentsRect
        self.reason = reason
    }
}

public struct TKHierarchyNodeRawInfo: Codable, Equatable {
    public let platform: String
    public let source: String?
    public let role: String?
    public let identifier: String?

    public init(platform: String, source: String? = nil, role: String? = nil, identifier: String? = nil) {
        self.platform = platform
        self.source = source
        self.role = role
        self.identifier = identifier
    }
}

public struct TKHierarchyNodeRenderHints: Codable, Equatable {
    public let preferredMode: String
    public let fallbackMode: String
    public let quality: String

    public init(preferredMode: String, fallbackMode: String, quality: String) {
        self.preferredMode = preferredMode
        self.fallbackMode = fallbackMode
        self.quality = quality
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
    public let style: TKHierarchyNodeStyle?
    public let slice: TKHierarchyNodeSlice?
    public let view: TKHierarchyViewMetadata?
    public let layer: TKHierarchyLayerMetadata?
    public let visualSources: [TKHierarchyVisualSource]?
    public let raw: TKHierarchyNodeRawInfo?
    public let renderHints: TKHierarchyNodeRenderHints?

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
        source: String? = nil,
        style: TKHierarchyNodeStyle? = nil,
        slice: TKHierarchyNodeSlice? = nil,
        view: TKHierarchyViewMetadata? = nil,
        layer: TKHierarchyLayerMetadata? = nil,
        visualSources: [TKHierarchyVisualSource]? = nil,
        raw: TKHierarchyNodeRawInfo? = nil,
        renderHints: TKHierarchyNodeRenderHints? = nil
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
        self.style = style
        self.slice = slice
        self.view = view
        self.layer = layer
        self.visualSources = visualSources
        self.raw = raw
        self.renderHints = renderHints
    }
}

public struct TKHierarchyControllerEntry: Codable, Equatable {
    public let id: String?
    public let oid: UInt?
    public let className: String
    public let name: String
    public let title: String?

    public init(id: String? = nil, oid: UInt? = nil, className: String, name: String, title: String? = nil) {
        self.id = id
        self.oid = oid
        self.className = className
        self.name = name
        self.title = title
    }
}

public struct TKHierarchyControllerContext: Codable, Equatable {
    public let activeControllerId: String?
    public let activeControllerName: String?
    public let activeControllerClassName: String?
    public let stack: [TKHierarchyControllerEntry]
    public let source: String

    public init(
        activeControllerId: String? = nil,
        activeControllerName: String? = nil,
        activeControllerClassName: String? = nil,
        stack: [TKHierarchyControllerEntry] = [],
        source: String
    ) {
        self.activeControllerId = activeControllerId
        self.activeControllerName = activeControllerName
        self.activeControllerClassName = activeControllerClassName
        self.stack = stack
        self.source = source
    }
}

public struct TKHierarchyScene: Codable, Equatable {
    public let platform: String
    public let rootId: String
    public let viewport: TKHierarchyViewport
    public let nodes: [TKHierarchyLayerNode]
    public let controllerContext: TKHierarchyControllerContext?

    public init(
        platform: String,
        rootId: String,
        viewport: TKHierarchyViewport,
        nodes: [TKHierarchyLayerNode],
        controllerContext: TKHierarchyControllerContext? = nil
    ) {
        self.platform = platform
        self.rootId = rootId
        self.viewport = viewport
        self.nodes = nodes
        self.controllerContext = controllerContext
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
