import Foundation

public enum TKHarmonyCollectorRuntimeMode: String, Codable, Equatable {
    case debug
    case release
}

public enum TKHarmonyCollectorCapability: String, Codable, CaseIterable, Equatable {
    case appInfo = "app-info"
    case viewSnapshot = "view-snapshot"
    case accessibility
    case geometry
    case screenshotMetadata = "screenshot-metadata"
}

public struct TKHarmonyCollectorManifest: Codable, Equatable {
    public let schemaVersion: Int
    public let platform: String
    public let transport: String
    public let runtimeMode: TKHarmonyCollectorRuntimeMode
    public let enabled: Bool
    public let capabilities: [TKHarmonyCollectorCapability]
    public let endpointPath: String

    public init(
        schemaVersion: Int = 1,
        platform: String = "harmony",
        transport: String = "embedded-websocket",
        runtimeMode: TKHarmonyCollectorRuntimeMode,
        enabled: Bool,
        capabilities: [TKHarmonyCollectorCapability],
        endpointPath: String = "/tritonkit/collector"
    ) {
        self.schemaVersion = schemaVersion
        self.platform = platform
        self.transport = transport
        self.runtimeMode = runtimeMode
        self.enabled = enabled
        self.capabilities = capabilities
        self.endpointPath = endpointPath
    }

    public static func debugDefault(endpointPath: String = "/tritonkit/collector") -> TKHarmonyCollectorManifest {
        TKHarmonyCollectorManifest(
            runtimeMode: .debug,
            enabled: true,
            capabilities: TKHarmonyCollectorCapability.allCases,
            endpointPath: endpointPath
        )
    }

    public static func releaseDisabled(endpointPath: String = "/tritonkit/collector") -> TKHarmonyCollectorManifest {
        TKHarmonyCollectorManifest(
            runtimeMode: .release,
            enabled: false,
            capabilities: [],
            endpointPath: endpointPath
        )
    }
}

public struct TKHarmonyCollectorConfiguration: Codable, Equatable {
    public let enabled: Bool
    public let runtimeMode: TKHarmonyCollectorRuntimeMode
    public let endpointPath: String
    public let redactionPolicy: String
    public let allowScreenshots: Bool
    public let includesScreenshotData: Bool

    public init(
        enabled: Bool,
        runtimeMode: TKHarmonyCollectorRuntimeMode,
        endpointPath: String = "/tritonkit/collector",
        redactionPolicy: String = "summary",
        allowScreenshots: Bool = true,
        includesScreenshotData: Bool = false
    ) {
        self.enabled = enabled
        self.runtimeMode = runtimeMode
        self.endpointPath = endpointPath
        self.redactionPolicy = redactionPolicy
        self.allowScreenshots = allowScreenshots
        self.includesScreenshotData = includesScreenshotData
    }

    public static func debugDefault(endpointPath: String = "/tritonkit/collector") -> TKHarmonyCollectorConfiguration {
        TKHarmonyCollectorConfiguration(
            enabled: true,
            runtimeMode: .debug,
            endpointPath: endpointPath
        )
    }

    public static func releaseDisabled(endpointPath: String = "/tritonkit/collector") -> TKHarmonyCollectorConfiguration {
        TKHarmonyCollectorConfiguration(
            enabled: false,
            runtimeMode: .release,
            endpointPath: endpointPath,
            allowScreenshots: false,
            includesScreenshotData: false
        )
    }
}

public struct TKHarmonyCollectorAppInfo: Codable, Equatable {
    public let bundleName: String
    public let appName: String?
    public let version: String?
    public let build: String?
    public let processID: Int?

    public init(
        bundleName: String,
        appName: String? = nil,
        version: String? = nil,
        build: String? = nil,
        processID: Int? = nil
    ) {
        self.bundleName = bundleName
        self.appName = appName
        self.version = version
        self.build = build
        self.processID = processID
    }
}

public struct TKHarmonyCollectorPageState: Codable, Equatable {
    public let abilityName: String?
    public let pageName: String?
    public let route: String?
    public let state: [String: TKJSONValue]

    public init(
        abilityName: String? = nil,
        pageName: String? = nil,
        route: String? = nil,
        state: [String: TKJSONValue] = [:]
    ) {
        self.abilityName = abilityName
        self.pageName = pageName
        self.route = route
        self.state = state
    }
}

public struct TKHarmonyCollectorScreenshotMetadata: Codable, Equatable {
    public let format: String
    public let width: Double
    public let height: Double
    public let scale: Double
    public let dataRef: String?

    public init(
        format: String,
        width: Double,
        height: Double,
        scale: Double,
        dataRef: String? = nil
    ) {
        self.format = format
        self.width = width
        self.height = height
        self.scale = scale
        self.dataRef = dataRef
    }
}

public struct TKHarmonyCollectorRedactionStatus: Codable, Equatable {
    public let policy: String
    public let status: String
    public let redactedFields: [String]
    public let notes: [String]

    public init(
        policy: String,
        status: String,
        redactedFields: [String] = [],
        notes: [String] = []
    ) {
        self.policy = policy
        self.status = status
        self.redactedFields = redactedFields
        self.notes = notes
    }
}

public struct TKHarmonyCollectorSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let platform: String
    public let capturedAt: String
    public let app: TKHarmonyCollectorAppInfo
    public let page: TKHarmonyCollectorPageState
    public let geometry: TKGeometryResponse?
    public let accessibility: [TKAXNode]
    public let screenshot: TKHarmonyCollectorScreenshotMetadata?
    public let redactionStatus: TKHarmonyCollectorRedactionStatus
    public let extras: [String: TKJSONValue]

    public init(
        schemaVersion: Int = 1,
        platform: String = "harmony",
        capturedAt: String,
        app: TKHarmonyCollectorAppInfo,
        page: TKHarmonyCollectorPageState,
        geometry: TKGeometryResponse? = nil,
        accessibility: [TKAXNode] = [],
        screenshot: TKHarmonyCollectorScreenshotMetadata? = nil,
        redactionStatus: TKHarmonyCollectorRedactionStatus,
        extras: [String: TKJSONValue] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.platform = platform
        self.capturedAt = capturedAt
        self.app = app
        self.page = page
        self.geometry = geometry
        self.accessibility = accessibility
        self.screenshot = screenshot
        self.redactionStatus = redactionStatus
        self.extras = extras
    }
}
