import Foundation

public struct TKRect: Codable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }

    public func contains(x pointX: Double, y pointY: Double) -> Bool {
        pointX >= x && pointY >= y && pointX <= x + width && pointY <= y + height
    }
}

public struct TKInsets: Codable, Equatable {
    public let top: Double
    public let left: Double
    public let bottom: Double
    public let right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

public struct TKAXNode: Codable, Equatable {
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
    public let children: [TKAXNode]

    public init(
        role: String,
        label: String?,
        value: String?,
        identifier: String?,
        title: String?,
        frame: TKRect,
        enabled: Bool,
        focused: Bool,
        hidden: Bool,
        targetOID: UInt?,
        viewOID: UInt? = nil,
        layerOID: UInt? = nil,
        className: String?,
        children: [TKAXNode]
    ) {
        self.role = role
        self.label = label
        self.value = value
        self.identifier = identifier
        self.title = title
        self.frame = frame
        self.enabled = enabled
        self.focused = focused
        self.hidden = hidden
        self.targetOID = targetOID
        self.viewOID = viewOID ?? targetOID
        self.layerOID = layerOID
        self.className = className
        self.children = children
    }
}

public struct TKHitTestRequest: Codable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct TKHitTestResponse: Codable, Equatable {
    public let x: Double
    public let y: Double
    public let node: TKAXNode?
    public let centerX: Double?
    public let centerY: Double?

    public init(x: Double, y: Double, node: TKAXNode?) {
        self.x = x
        self.y = y
        self.node = node
        self.centerX = node?.frame.centerX
        self.centerY = node?.frame.centerY
    }
}

public struct TKGeometryResponse: Codable, Equatable {
    public let bounds: TKRect
    public let safeArea: TKInsets
    public let scale: Double
    public let orientation: String

    public init(bounds: TKRect, safeArea: TKInsets, scale: Double, orientation: String) {
        self.bounds = bounds
        self.safeArea = safeArea
        self.scale = scale
        self.orientation = orientation
    }
}

public struct TKScreenshotResponse: Codable, Equatable {
    public let format: String
    public let width: Double
    public let height: Double
    public let scale: Double
    public let dataBase64: String
    public let dataRef: String?

    public init(
        format: String,
        width: Double,
        height: Double,
        scale: Double,
        dataBase64: String,
        dataRef: String? = nil
    ) {
        self.format = format
        self.width = width
        self.height = height
        self.scale = scale
        self.dataBase64 = dataBase64
        self.dataRef = dataRef
    }
}
