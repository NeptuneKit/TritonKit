import Foundation

public struct TKNodeFramePropertyChanges: Codable, Equatable {
    public let x: Double?
    public let y: Double?
    public let width: Double?
    public let height: Double?

    public init(x: Double? = nil, y: Double? = nil, width: Double? = nil, height: Double? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool {
        x == nil && y == nil && width == nil && height == nil
    }
}

public struct TKNodeViewPropertyChanges: Codable, Equatable {
    public let isHidden: Bool?
    public let alpha: Double?
    public let isUserInteractionEnabled: Bool?
    public let accessibilityIdentifier: String?
    public let accessibilityLabel: String?

    public init(
        isHidden: Bool? = nil,
        alpha: Double? = nil,
        isUserInteractionEnabled: Bool? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.isHidden = isHidden
        self.alpha = alpha
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
    }

    public var isEmpty: Bool {
        isHidden == nil &&
            alpha == nil &&
            isUserInteractionEnabled == nil &&
            accessibilityIdentifier == nil &&
            accessibilityLabel == nil
    }
}

public struct TKNodeLayerPropertyChanges: Codable, Equatable {
    public let isHidden: Bool?
    public let masksToBounds: Bool?
    public let opacity: Double?
    public let cornerRadius: Double?
    public let zPosition: Double?

    public init(
        isHidden: Bool? = nil,
        masksToBounds: Bool? = nil,
        opacity: Double? = nil,
        cornerRadius: Double? = nil,
        zPosition: Double? = nil
    ) {
        self.isHidden = isHidden
        self.masksToBounds = masksToBounds
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.zPosition = zPosition
    }

    public var isEmpty: Bool {
        isHidden == nil &&
            masksToBounds == nil &&
            opacity == nil &&
            cornerRadius == nil &&
            zPosition == nil
    }
}

public struct TKNodeStylePropertyChanges: Codable, Equatable {
    public let text: String?
    public let backgroundColor: String?
    public let foregroundColor: String?
    public let alpha: Double?
    public let cornerRadius: Double?

    public init(
        text: String? = nil,
        backgroundColor: String? = nil,
        foregroundColor: String? = nil,
        alpha: Double? = nil,
        cornerRadius: Double? = nil
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.alpha = alpha
        self.cornerRadius = cornerRadius
    }

    public var isEmpty: Bool {
        text == nil &&
            backgroundColor == nil &&
            foregroundColor == nil &&
            alpha == nil &&
            cornerRadius == nil
    }
}

public struct TKNodePropertyChanges: Codable, Equatable {
    public let frame: TKNodeFramePropertyChanges?
    public let view: TKNodeViewPropertyChanges?
    public let layer: TKNodeLayerPropertyChanges?
    public let style: TKNodeStylePropertyChanges?

    public init(
        frame: TKNodeFramePropertyChanges? = nil,
        view: TKNodeViewPropertyChanges? = nil,
        layer: TKNodeLayerPropertyChanges? = nil,
        style: TKNodeStylePropertyChanges? = nil
    ) {
        self.frame = frame
        self.view = view
        self.layer = layer
        self.style = style
    }

    public var isEmpty: Bool {
        (frame?.isEmpty ?? true) &&
            (view?.isEmpty ?? true) &&
            (layer?.isEmpty ?? true) &&
            (style?.isEmpty ?? true)
    }
}

public struct TKNodePropertyPatchRequest: Codable, Equatable {
    public let nodeId: String?
    public let oid: UInt?
    public let viewOID: UInt?
    public let layerOID: UInt?
    public let changes: TKNodePropertyChanges

    public init(
        nodeId: String? = nil,
        oid: UInt? = nil,
        viewOID: UInt? = nil,
        layerOID: UInt? = nil,
        changes: TKNodePropertyChanges
    ) {
        self.nodeId = nodeId
        self.oid = oid
        self.viewOID = viewOID
        self.layerOID = layerOID
        self.changes = changes
    }

    public var resolvedOID: UInt? {
        layerOID ?? viewOID ?? oid ?? Self.oid(fromNodeID: nodeId)
    }

    public static func oid(fromNodeID nodeId: String?) -> UInt? {
        guard let nodeId else { return nil }
        let tail = nodeId.split(separator: ":").last.map(String.init) ?? nodeId
        return UInt(tail)
    }
}

public struct TKNodePropertyPatchResponse: Codable, Equatable {
    public let ok: Bool
    public let success: Bool
    public let action: String
    public let nodeId: String?
    public let oid: UInt?
    public let applied: [String]
    public let skipped: [String]
    public let message: String?

    public init(
        ok: Bool,
        success: Bool? = nil,
        action: String = "node.patch",
        nodeId: String? = nil,
        oid: UInt? = nil,
        applied: [String] = [],
        skipped: [String] = [],
        message: String? = nil
    ) {
        self.ok = ok
        self.success = success ?? ok
        self.action = action
        self.nodeId = nodeId
        self.oid = oid
        self.applied = applied
        self.skipped = skipped
        self.message = message
    }
}
