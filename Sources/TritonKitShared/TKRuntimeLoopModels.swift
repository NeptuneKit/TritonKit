import Foundation

public struct TKRuntimeSnapshotRequest: Codable, Equatable {
    public let include: [String]
    public let maxAXNodes: Int?

    public init(include: [String] = ["app", "scene", "route", "ax", "geometry"], maxAXNodes: Int? = nil) {
        self.include = include
        self.maxAXNodes = maxAXNodes
    }
}

public struct TKRuntimeSnapshotResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let include: [String]
    public let app: TKRuntimeAppState?
    public let scene: TKRuntimeSceneStateResponse?
    public let route: TKRuntimeRouteStateResponse?
    public let responder: TKRuntimeResponderStateResponse?
    public let media: TKRuntimeMediaStateResponse?
    public let geometry: TKGeometryResponse?
    public let ax: [TKAXNode]?
    public let screenshot: TKRuntimeScreenshotMetadata?
    public let artifacts: [TKRuntimeSnapshotArtifact]
    public let skipped: [TKRuntimeSnapshotSkipped]
    public let truncation: TKRuntimeSnapshotTruncation

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        include: [String],
        app: TKRuntimeAppState? = nil,
        scene: TKRuntimeSceneStateResponse? = nil,
        route: TKRuntimeRouteStateResponse? = nil,
        responder: TKRuntimeResponderStateResponse? = nil,
        media: TKRuntimeMediaStateResponse? = nil,
        geometry: TKGeometryResponse? = nil,
        ax: [TKAXNode]? = nil,
        screenshot: TKRuntimeScreenshotMetadata? = nil,
        artifacts: [TKRuntimeSnapshotArtifact] = [],
        skipped: [TKRuntimeSnapshotSkipped] = [],
        truncation: TKRuntimeSnapshotTruncation = TKRuntimeSnapshotTruncation()
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.include = include
        self.app = app
        self.scene = scene
        self.route = route
        self.responder = responder
        self.media = media
        self.geometry = geometry
        self.ax = ax
        self.screenshot = screenshot
        self.artifacts = artifacts
        self.skipped = skipped
        self.truncation = truncation
    }
}

public struct TKRuntimeScreenshotMetadata: Codable, Equatable {
    public let format: String
    public let width: Double
    public let height: Double
    public let scale: Double
    public let dataIncluded: Bool

    public init(format: String, width: Double, height: Double, scale: Double, dataIncluded: Bool = false) {
        self.format = format
        self.width = width
        self.height = height
        self.scale = scale
        self.dataIncluded = dataIncluded
    }
}

public struct TKRuntimeSnapshotArtifact: Codable, Equatable {
    public let name: String
    public let capturedAt: String
    public let freshness: String

    public init(name: String, capturedAt: String, freshness: String) {
        self.name = name
        self.capturedAt = capturedAt
        self.freshness = freshness
    }
}

public struct TKRuntimeSnapshotSkipped: Codable, Equatable {
    public let name: String
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }
}

public struct TKRuntimeSnapshotTruncation: Codable, Equatable {
    public let truncated: Bool
    public let reason: String?
    public let originalCount: Int?
    public let returnedCount: Int?

    public init(truncated: Bool = false, reason: String? = nil, originalCount: Int? = nil, returnedCount: Int? = nil) {
        self.truncated = truncated
        self.reason = reason
        self.originalCount = originalCount
        self.returnedCount = returnedCount
    }
}

public enum TKSemanticActionType: String, Codable, CaseIterable {
    case focus
    case setText
    case selectSegment
    case setSwitch
}

public struct TKSemanticActionRequest: Codable, Equatable {
    public let action: TKSemanticActionType
    public let selector: String?
    public let sourceCommand: String?
    public let strategy: String?
    public let targetOID: UInt?
    public let x: Double?
    public let y: Double?
    public let text: String?
    public let secure: Bool?
    public let segmentTitle: String?
    public let segmentIndex: Int?
    public let switchValue: String?

    public init(
        action: TKSemanticActionType,
        selector: String? = nil,
        sourceCommand: String? = nil,
        strategy: String? = nil,
        targetOID: UInt? = nil,
        x: Double? = nil,
        y: Double? = nil,
        text: String? = nil,
        secure: Bool? = nil,
        segmentTitle: String? = nil,
        segmentIndex: Int? = nil,
        switchValue: String? = nil
    ) {
        self.action = action
        self.selector = selector
        self.sourceCommand = sourceCommand
        self.strategy = strategy
        self.targetOID = targetOID
        self.x = x
        self.y = y
        self.text = text
        self.secure = secure
        self.segmentTitle = segmentTitle
        self.segmentIndex = segmentIndex
        self.switchValue = switchValue
    }
}

public struct TKSemanticActionResponse: Codable, Equatable {
    public let ok: Bool
    public let action: TKSemanticActionType
    public let strategy: String
    public let targetOID: UInt?
    public let targetClassName: String?
    public let elapsedMs: Int
    public let message: String?
    public let error: TKCLIErrorDetail?
    public let redaction: TKSemanticActionRedaction?

    public init(
        ok: Bool,
        action: TKSemanticActionType,
        strategy: String,
        targetOID: UInt? = nil,
        targetClassName: String? = nil,
        elapsedMs: Int,
        message: String? = nil,
        error: TKCLIErrorDetail? = nil,
        redaction: TKSemanticActionRedaction? = nil
    ) {
        self.ok = ok
        self.action = action
        self.strategy = strategy
        self.targetOID = targetOID
        self.targetClassName = targetClassName
        self.elapsedMs = elapsedMs
        self.message = message
        self.error = error
        self.redaction = redaction
    }
}

public struct TKSemanticActionRedaction: Codable, Equatable {
    public let secure: Bool
    public let text: String
    public let insertedLength: Int?

    public init(secure: Bool = false, text: String = "not-collected", insertedLength: Int? = nil) {
        self.secure = secure
        self.text = text
        self.insertedLength = insertedLength
    }
}

public struct TKRuntimeLedgerRequest: Codable, Equatable {
    public let limit: Int

    public init(limit: Int = 50) {
        self.limit = limit
    }
}

public struct TKRuntimeLedgerResponse: Codable, Equatable {
    public let ok: Bool
    public let entries: [TKRuntimeLedgerEntry]
    public let limit: Int
    public let count: Int
    public let maxEntries: Int

    public init(ok: Bool = true, entries: [TKRuntimeLedgerEntry], limit: Int, maxEntries: Int) {
        self.ok = ok
        self.entries = entries
        self.limit = limit
        self.count = entries.count
        self.maxEntries = maxEntries
    }
}

public struct TKRuntimeLedgerEntry: Codable, Equatable {
    public let id: Int
    public let timestamp: String
    public let source: String
    public let requestType: String
    public let action: String?
    public let ok: Bool
    public let elapsedMs: Int
    public let errorCode: String?
    public let message: String?
    public let redaction: TKSemanticActionRedaction?

    public init(
        id: Int,
        timestamp: String,
        source: String,
        requestType: String,
        action: String? = nil,
        ok: Bool,
        elapsedMs: Int,
        errorCode: String? = nil,
        message: String? = nil,
        redaction: TKSemanticActionRedaction? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.requestType = requestType
        self.action = action
        self.ok = ok
        self.elapsedMs = elapsedMs
        self.errorCode = errorCode
        self.message = message
        self.redaction = redaction
    }
}
