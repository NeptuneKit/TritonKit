import Foundation

public let TKLocalTargetID = "triton:local"

public struct TKStatusResponse: Codable, Equatable {
    public let connected: Bool
    public let latestHierarchyAvailable: Bool
    public let targetCount: Int
    public let activeHierarchyAvailable: Bool?
    public let hierarchyCacheState: String?
    public let targetConnectionState: String?

    public init(
        connected: Bool,
        latestHierarchyAvailable: Bool,
        targetCount: Int,
        activeHierarchyAvailable: Bool? = nil,
        hierarchyCacheState: String? = nil,
        targetConnectionState: String? = nil
    ) {
        self.connected = connected
        self.latestHierarchyAvailable = latestHierarchyAvailable
        self.targetCount = targetCount
        self.activeHierarchyAvailable = activeHierarchyAvailable ?? (connected && latestHierarchyAvailable)
        self.hierarchyCacheState = hierarchyCacheState ?? {
            if connected && latestHierarchyAvailable { return "active" }
            if latestHierarchyAvailable { return "stale" }
            return "unavailable"
        }()
        self.targetConnectionState = targetConnectionState ?? (connected ? "connected" : "disconnected")
    }
}

public struct TKCLIStatusEnvelope: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let latestHierarchyAvailable: Bool
    public let targetCount: Int
    public let runtime: String
    public let surface: String
    public let activeHierarchyAvailable: Bool?
    public let hierarchyCacheState: String?
    public let targetConnectionState: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case serverReachable
        case connected
        case latestHierarchyAvailable
        case targetCount
        case runtime
        case surface
        case activeHierarchyAvailable
        case hierarchyCacheState
        case targetConnectionState
    }

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        latestHierarchyAvailable: Bool,
        targetCount: Int,
        runtime: String,
        surface: String = "status",
        activeHierarchyAvailable: Bool? = nil,
        hierarchyCacheState: String? = nil,
        targetConnectionState: String? = nil
    ) {
        self.ok = ok
        self.serverReachable = serverReachable
        self.connected = connected
        self.latestHierarchyAvailable = latestHierarchyAvailable
        self.targetCount = targetCount
        self.runtime = runtime
        self.surface = surface
        self.activeHierarchyAvailable = activeHierarchyAvailable ?? (connected && latestHierarchyAvailable)
        self.hierarchyCacheState = hierarchyCacheState ?? {
            if connected && latestHierarchyAvailable { return "active" }
            if latestHierarchyAvailable { return "stale" }
            return "unavailable"
        }()
        self.targetConnectionState = targetConnectionState ?? (connected ? "connected" : "disconnected")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.serverReachable = try container.decode(Bool.self, forKey: .serverReachable)
        self.connected = try container.decode(Bool.self, forKey: .connected)
        self.latestHierarchyAvailable = try container.decode(Bool.self, forKey: .latestHierarchyAvailable)
        self.targetCount = try container.decode(Int.self, forKey: .targetCount)
        self.runtime = try container.decode(String.self, forKey: .runtime)
        self.surface = try container.decodeIfPresent(String.self, forKey: .surface) ?? "status"
        let defaultHierarchyCacheState =
            if connected && latestHierarchyAvailable {
                "active"
            } else if latestHierarchyAvailable {
                "stale"
            } else {
                "unavailable"
            }
        self.activeHierarchyAvailable = try container.decodeIfPresent(Bool.self, forKey: .activeHierarchyAvailable)
            ?? (connected && latestHierarchyAvailable)
        self.hierarchyCacheState = try container.decodeIfPresent(String.self, forKey: .hierarchyCacheState)
            ?? defaultHierarchyCacheState
        self.targetConnectionState = try container.decodeIfPresent(String.self, forKey: .targetConnectionState)
            ?? (connected ? "connected" : "disconnected")
    }
}

public struct TKTargetSummary: Codable, Equatable {
    public let id: String
    public let transport: String
    public let platform: String
    public let connected: Bool
    public let latestHierarchyAvailable: Bool
    public let appName: String?
    public let bundleIdentifier: String?
    public let deviceDescription: String?
    public let osDescription: String?
    public let simulatorUDID: String?
    public let activeHierarchyAvailable: Bool?
    public let cachedHierarchyAvailable: Bool?
    public let hierarchyCacheState: String?
    public let identityState: String?

    public init(
        id: String = TKLocalTargetID,
        transport: String = "local-websocket",
        connected: Bool,
        latestHierarchyAvailable: Bool,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        deviceDescription: String? = nil,
        osDescription: String? = nil,
        simulatorUDID: String? = nil,
        activeHierarchyAvailable: Bool? = nil,
        cachedHierarchyAvailable: Bool? = nil,
        hierarchyCacheState: String? = nil,
        identityState: String? = nil,
        platform: String? = nil
    ) {
        self.id = id
        self.transport = transport
        self.platform = TKInferTargetPlatform(
            platform: platform,
            id: id,
            transport: transport,
            simulatorUDID: simulatorUDID,
            deviceDescription: deviceDescription,
            osDescription: osDescription
        )
        self.connected = connected
        self.latestHierarchyAvailable = latestHierarchyAvailable
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.deviceDescription = deviceDescription
        self.osDescription = osDescription
        self.simulatorUDID = simulatorUDID
        self.activeHierarchyAvailable = activeHierarchyAvailable ?? (connected && latestHierarchyAvailable)
        self.cachedHierarchyAvailable = cachedHierarchyAvailable ?? latestHierarchyAvailable
        self.hierarchyCacheState = hierarchyCacheState ?? {
            if connected && latestHierarchyAvailable { return "active" }
            if latestHierarchyAvailable { return "stale" }
            return "unavailable"
        }()
        self.identityState = identityState ?? ((appName != nil || bundleIdentifier != nil) ? "current" : "unknown")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case transport
        case platform
        case connected
        case latestHierarchyAvailable
        case appName
        case bundleIdentifier
        case deviceDescription
        case osDescription
        case simulatorUDID
        case activeHierarchyAvailable
        case cachedHierarchyAvailable
        case hierarchyCacheState
        case identityState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(String.self, forKey: .id) ?? TKLocalTargetID
        let transport = try container.decodeIfPresent(String.self, forKey: .transport) ?? "local-websocket"
        let simulatorUDID = try container.decodeIfPresent(String.self, forKey: .simulatorUDID)
        let deviceDescription = try container.decodeIfPresent(String.self, forKey: .deviceDescription)
        let osDescription = try container.decodeIfPresent(String.self, forKey: .osDescription)
        let platform = try container.decodeIfPresent(String.self, forKey: .platform)

        self.init(
            id: id,
            transport: transport,
            connected: try container.decode(Bool.self, forKey: .connected),
            latestHierarchyAvailable: try container.decode(Bool.self, forKey: .latestHierarchyAvailable),
            appName: try container.decodeIfPresent(String.self, forKey: .appName),
            bundleIdentifier: try container.decodeIfPresent(String.self, forKey: .bundleIdentifier),
            deviceDescription: deviceDescription,
            osDescription: osDescription,
            simulatorUDID: simulatorUDID,
            activeHierarchyAvailable: try container.decodeIfPresent(Bool.self, forKey: .activeHierarchyAvailable),
            cachedHierarchyAvailable: try container.decodeIfPresent(Bool.self, forKey: .cachedHierarchyAvailable),
            hierarchyCacheState: try container.decodeIfPresent(String.self, forKey: .hierarchyCacheState),
            identityState: try container.decodeIfPresent(String.self, forKey: .identityState),
            platform: platform
        )
    }
}

public func TKInferTargetPlatform(
    platform: String?,
    id: String,
    transport: String,
    simulatorUDID: String?,
    deviceDescription: String?,
    osDescription: String?
) -> String {
    if let normalized = platform?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
       !normalized.isEmpty {
        return normalized
    }
    let haystack = [id, transport, simulatorUDID, deviceDescription, osDescription]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
    if haystack.contains("harmony") || haystack.contains("openharmony") || haystack.contains("deveco") {
        return "harmony"
    }
    if haystack.contains("android") || haystack.contains("adb") || haystack.contains("emulator-") {
        return "android"
    }
    return "ios"
}

public struct TKTargetsResponse: Codable, Equatable {
    public let targets: [TKTargetSummary]

    public init(targets: [TKTargetSummary]) {
        self.targets = targets
    }
}

public enum TKTargetResolutionError: Error, Equatable, CustomStringConvertible {
    case notFound(String)
    case ambiguous(requested: String, available: [String])

    public var description: String {
        switch self {
        case .notFound(let requested):
            return "Target not found: \(requested)"
        case .ambiguous(let requested, let available):
            return "Target is ambiguous: \(requested). Available targets: \(available.joined(separator: ", ")). Pass --target <id>."
        }
    }
}

public func TKNormalizeTargetID(_ target: String) -> String {
    target == "local" ? TKLocalTargetID : target
}

public func TKResolveTargetSummary(_ target: String, in targets: [TKTargetSummary]) throws -> TKTargetSummary {
    let normalized = TKNormalizeTargetID(target)
    if let summary = targets.first(where: { $0.id == normalized }) {
        return summary
    }
    if let simulator = targets.first(where: { $0.simulatorUDID == target }) {
        return simulator
    }
    if normalized == TKLocalTargetID, targets.count == 1, let only = targets.first {
        return only
    }
    if normalized == TKLocalTargetID, targets.count > 1 {
        throw TKTargetResolutionError.ambiguous(requested: target, available: targets.map(\.id))
    }
    throw TKTargetResolutionError.notFound(target)
}

public let TKDefaultHiddenHierarchyTreeClassNames: Set<String> = [
    "UITransitionView",
    "UIDropShadowView",
]

public func TKIsDefaultHiddenHierarchyTreeClass(_ className: String) -> Bool {
    TKDefaultHiddenHierarchyTreeClassNames.contains(className)
}

public struct TKCLICommandRequest: Codable, Equatable {
    public let type: String
    public let payload: Data?
    public let target: String?

    public init(type: String, payload: Data? = nil, target: String? = nil) {
        self.type = type
        self.payload = payload
        self.target = target
    }

    public var requestType: TKRequestType? {
        switch type.lowercased() {
        case "ping": .ping
        case "appinfo": .appInfo
        case "runtimemanifest", "manifest": .runtimeManifest
        case "stateapp", "state.app", "app": .stateApp
        case "statescene", "state.scene", "scene": .stateScene
        case "stateroute", "state.route", "route": .stateRoute
        case "stateresponder", "state.responder", "responder": .stateResponder
        case "runtimesnapshot", "snapshot": .runtimeSnapshot
        case "webviewlist", "webview.list": .webViewList
        case "webviewcurrent", "webview.current": .webViewCurrent
        case "webviewsnapshot", "webview.snapshot": .webViewSnapshot
        case "webviewbridgecall", "webview.bridgecall", "webview.bridge-call", "webview.call": .webViewBridgeCall
        case "webviewbridgepost", "webview.bridgepost", "webview.bridge-post", "webview.post": .webViewBridgePost
        case "webviewwait", "webview.wait": .webViewWait
        case "webviewevents", "webview.events": .webViewEvents
        case "webviewledger", "webview.ledger": .webViewLedger
        case "semanticaction", "semantic.action": .semanticAction
        case "runtimeledger", "ledger": .runtimeLedger
        case "hierarchy": .hierarchy
        case "allattrgroups": .allAttrGroups
        case "fetchobject": .fetchObject
        case "hierarchydetails": .hierarchyDetails
        case "input": .input
        case "accessibility", "ax": .accessibility
        case "hittest", "hit": .hitTest
        case "screenshot": .screenshot
        case "geometry": .geometry
        default: nil
        }
    }
}

public struct TKCLICommandResponse: Codable, Equatable {
    public let id: Int
    public let type: String

    public init(id: Int, type: String) {
        self.id = id
        self.type = type
    }
}

public struct TKCLIErrorDetail: Codable, Equatable {
    public let code: String
    public let message: String
    public let endpoint: String?
    public let hint: String?
    public let nextAction: TKCLINextAction?
    public let nearestCandidates: [String]?
    public let suggestedCommands: [String]?
    public let candidateCount: Int?

    public init(
        code: String,
        message: String,
        endpoint: String? = nil,
        hint: String? = nil,
        nextAction: TKCLINextAction? = nil,
        nearestCandidates: [String]? = nil,
        suggestedCommands: [String]? = nil,
        candidateCount: Int? = nil
    ) {
        self.code = code
        self.message = message
        self.endpoint = endpoint
        self.hint = hint
        self.nextAction = nextAction
        self.nearestCandidates = nearestCandidates
        self.suggestedCommands = suggestedCommands
        self.candidateCount = candidateCount
    }
}

public struct TKCLIErrorResponse: Codable, Equatable {
    public let ok: Bool
    public let surface: String?
    public let error: TKCLIErrorDetail

    public init(error: TKCLIErrorDetail, surface: String? = nil) {
        self.ok = false
        self.surface = surface
        self.error = error
    }
}

public func TKCLIRuntimeTimeoutErrorDetail(requestType: String, endpoint: String) -> TKCLIErrorDetail {
    let normalized = requestType.lowercased()
    let uiMainActorRequestTypes: Set<String> = [
        "input",
        "accessibility",
        "ax",
        "geometry",
        "hittest",
        "hit",
        "screenshot",
        "hierarchy",
    ]

    if uiMainActorRequestTypes.contains(normalized) {
        return TKCLIErrorDetail(
            code: "runtime_ui_interrupted",
            message: "Timed out waiting for runtime UI response; a system alert may be blocking the app",
            endpoint: endpoint,
            hint: "Dismiss the iOS system alert, then retry. TritonKit embedded runtime cannot inspect or tap SpringBoard/CoreSimulatorBridge alerts."
        )
    }

    return TKCLIErrorDetail(
        code: "request_timeout",
        message: "Timed out waiting for response",
        endpoint: endpoint,
        hint: "Check the connected runtime logs and retry"
    )
}

public struct TKCLIVersionResponse: Codable, Equatable {
    public let ok: Bool
    public let version: String
    public let schemaVersion: Int
    public let defaultHost: String
    public let defaultPort: Int
    public let language: String
    public let supportedLanguages: [String]

    public init(
        ok: Bool = true,
        version: String,
        schemaVersion: Int = 1,
        defaultHost: String = "127.0.0.1",
        defaultPort: Int = 19421,
        language: String = "en",
        supportedLanguages: [String] = ["en", "zh"]
    ) {
        self.ok = ok
        self.version = version
        self.schemaVersion = schemaVersion
        self.defaultHost = defaultHost
        self.defaultPort = defaultPort
        self.language = language
        self.supportedLanguages = supportedLanguages
    }
}

public struct TKInputBatchSummaryResponse: Codable, Equatable {
    public let ok: Bool
    public let actionCount: Int
    public let failedCount: Int

    public init(ok: Bool, actionCount: Int, failedCount: Int) {
        self.ok = ok
        self.actionCount = actionCount
        self.failedCount = failedCount
    }
}
