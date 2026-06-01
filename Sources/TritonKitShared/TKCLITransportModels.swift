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
        identityState: String? = nil
    ) {
        self.id = id
        self.transport = transport
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

public struct TKCLINextAction: Codable, Equatable {
    public let command: String
    public let args: [String]
    public let category: String
    public let requiresLongRunningProcess: Bool

    enum CodingKeys: String, CodingKey {
        case command
        case args
        case category
        case requiresLongRunningProcess
    }

    public init(
        command: String,
        args: [String],
        category: String? = nil,
        requiresLongRunningProcess: Bool = false
    ) {
        self.command = command
        self.args = args
        self.category = category ?? TKCommandRecoveryCommand.category(forRootCommand: command) ?? "plan"
        self.requiresLongRunningProcess = requiresLongRunningProcess
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let command = try container.decode(String.self, forKey: .command)
        self.command = command
        self.args = try container.decode([String].self, forKey: .args)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ??
            TKCommandRecoveryCommand.category(forRootCommand: command) ??
            "plan"
        self.requiresLongRunningProcess = try container.decodeIfPresent(Bool.self, forKey: .requiresLongRunningProcess) ?? false
    }

    public static func fromTritonArgv(_ argv: [String]) -> TKCLINextAction? {
        guard argv.count >= 2, argv[0] == "triton" else {
            return nil
        }
        let command = argv[1]
        let args = Array(argv.dropFirst(2))
        let requiresLongRunningProcess = command == "serve"
        return TKCLINextAction(
            command: command,
            args: args,
            requiresLongRunningProcess: requiresLongRunningProcess
        )
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
    public let error: TKCLIErrorDetail

    public init(error: TKCLIErrorDetail) {
        self.ok = false
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

public struct TKRuntimeCapability: Codable, Equatable {
    public let name: String
    public let supported: Bool
    public let reason: String?
    public let group: String?
    public let requiredBy: [String]
    public let nextAction: TKCLINextAction?
    public let evidence: [String]

    public init(
        name: String,
        supported: Bool,
        reason: String? = nil,
        group: String? = nil,
        requiredBy: [String] = [],
        nextAction: TKCLINextAction? = nil,
        evidence: [String] = []
    ) {
        self.name = name
        self.supported = supported
        self.reason = reason
        self.group = group
        self.requiredBy = requiredBy
        self.nextAction = nextAction
        self.evidence = evidence
    }
}

public struct TKCapabilitiesResponse: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let latestHierarchyAvailable: Bool
    public let targetCount: Int
    public let runtime: String
    public let surface: String
    public let capabilities: [TKRuntimeCapability]
    public let primaryCapability: String?
    public let primaryWorkflowCategory: String?
    public let primaryEvidence: String?
    public let primaryNextAction: TKCLINextAction?
    public let primaryNextActionSource: String?
    public let error: TKCLIErrorDetail?
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
        case capabilities
        case primaryCapability
        case primaryWorkflowCategory
        case primaryEvidence
        case primaryNextAction
        case primaryNextActionSource
        case error
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
        surface: String = "capabilities",
        capabilities: [TKRuntimeCapability],
        primaryCapability: String? = nil,
        primaryWorkflowCategory: String? = nil,
        primaryEvidence: String? = nil,
        primaryNextAction: TKCLINextAction? = nil,
        primaryNextActionSource: String? = nil,
        error: TKCLIErrorDetail? = nil,
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
        self.capabilities = capabilities
        let primarySelection = Self.defaultPrimarySelection(
            capabilities: capabilities,
            error: error,
            preferredCapability: primaryCapability,
            preferredAction: primaryNextAction,
            preferredWorkflowCategory: primaryWorkflowCategory,
            preferredEvidence: primaryEvidence,
            preferredSource: primaryNextActionSource
        )
        self.primaryCapability = primarySelection.capability
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryEvidence = primarySelection.evidence
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.error = error
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
        self.surface = try container.decodeIfPresent(String.self, forKey: .surface) ?? "capabilities"
        self.capabilities = try container.decode([TKRuntimeCapability].self, forKey: .capabilities)
        let decodedPrimaryCapability = try container.decodeIfPresent(String.self, forKey: .primaryCapability)
        let decodedPrimaryNextAction = try container.decodeIfPresent(TKCLINextAction.self, forKey: .primaryNextAction)
        let decodedError = try container.decodeIfPresent(TKCLIErrorDetail.self, forKey: .error)
        let primarySelection = Self.defaultPrimarySelection(
            capabilities: capabilities,
            error: decodedError,
            preferredCapability: decodedPrimaryCapability,
            preferredAction: decodedPrimaryNextAction,
            preferredWorkflowCategory: try container.decodeIfPresent(String.self, forKey: .primaryWorkflowCategory),
            preferredEvidence: try container.decodeIfPresent(String.self, forKey: .primaryEvidence),
            preferredSource: try container.decodeIfPresent(String.self, forKey: .primaryNextActionSource)
        )
        self.primaryCapability = primarySelection.capability
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryEvidence = primarySelection.evidence
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.error = decodedError
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

    private static func defaultPrimarySelection(
        capabilities: [TKRuntimeCapability],
        error: TKCLIErrorDetail?,
        preferredCapability: String?,
        preferredAction: TKCLINextAction?,
        preferredWorkflowCategory: String?,
        preferredEvidence: String?,
        preferredSource: String?
    ) -> (capability: String?, workflowCategory: String?, evidence: String?, nextAction: TKCLINextAction?, source: String?) {
        if let preferredAction {
            let capability = preferredCapability ?? capabilityName(for: preferredAction, in: capabilities)
            return (
                capability,
                preferredWorkflowCategory ?? workflowCategory(for: capability, in: capabilities),
                preferredEvidence ?? evidence(for: capability, in: capabilities),
                preferredAction,
                preferredSource ?? "explicit"
            )
        }
        if let errorAction = error?.nextAction {
            let capability = capabilityName(for: errorAction, in: capabilities)
            return (
                capability,
                workflowCategory(for: capability, in: capabilities),
                evidence(for: capability, in: capabilities),
                errorAction,
                "error"
            )
        }
        if let firstUnsupported = capabilities.first(where: { !$0.supported && $0.nextAction != nil }) {
            return (
                firstUnsupported.name,
                workflowCategory(for: firstUnsupported.name, in: capabilities),
                firstUnsupported.evidence.first,
                firstUnsupported.nextAction,
                "unsupported-capability"
            )
        }
        if let planCapability = capabilities.first(where: { $0.name == "plan" && $0.nextAction != nil }) {
            return (
                planCapability.name,
                workflowCategory(for: planCapability.name, in: capabilities),
                planCapability.evidence.first,
                planCapability.nextAction,
                "plan-capability"
            )
        }
        if let firstActionable = capabilities.first(where: { $0.nextAction != nil }) {
            return (
                firstActionable.name,
                workflowCategory(for: firstActionable.name, in: capabilities),
                firstActionable.evidence.first,
                firstActionable.nextAction,
                "actionable-capability"
            )
        }
        return (
            preferredCapability,
            preferredWorkflowCategory,
            preferredEvidence ?? evidence(for: preferredCapability, in: capabilities),
            nil,
            preferredSource
        )
    }

    private static func capabilityName(for action: TKCLINextAction, in capabilities: [TKRuntimeCapability]) -> String? {
        capabilities.first(where: { $0.nextAction == action })?.name
    }

    private static func workflowCategory(for capability: String?, in capabilities: [TKRuntimeCapability]) -> String? {
        guard let capability else { return nil }
        return capabilities.first(where: { $0.name == capability })?.requiredBy.first
    }

    private static func evidence(for capability: String?, in capabilities: [TKRuntimeCapability]) -> String? {
        guard let capability else { return nil }
        return capabilities.first(where: { $0.name == capability })?.evidence.first
    }
}

public struct TKDoctorCheck: Codable, Equatable {
    public let id: String
    public let status: String
    public let code: String
    public let message: String
    public let hint: String?
    public let nextAction: TKCLINextAction?
    public let relatedCapabilities: [String]
    public let workflowCategories: [String]

    public init(
        id: String,
        status: String,
        code: String,
        message: String,
        hint: String? = nil,
        nextAction: TKCLINextAction? = nil,
        relatedCapabilities: [String] = [],
        workflowCategories: [String] = []
    ) {
        self.id = id
        self.status = status
        self.code = code
        self.message = message
        self.hint = hint
        self.nextAction = nextAction
        self.relatedCapabilities = relatedCapabilities
        self.workflowCategories = workflowCategories
    }
}

public struct TKDoctorResponse: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let runtime: String
    public let surface: String
    public let nextStep: String
    public let nextWorkflows: [String]
    public let primaryCapability: String?
    public let primaryWorkflowCategory: String?
    public let primaryNextAction: TKCLINextAction?
    public let primaryNextActionSource: String?
    public let checks: [TKDoctorCheck]
    public let error: TKCLIErrorDetail?

    enum CodingKeys: String, CodingKey {
        case ok
        case serverReachable
        case connected
        case runtime
        case surface
        case nextStep
        case nextWorkflows
        case primaryCapability
        case primaryWorkflowCategory
        case primaryNextAction
        case primaryNextActionSource
        case checks
        case error
    }

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        runtime: String,
        surface: String = "doctor",
        nextStep: String,
        nextWorkflows: [String] = [],
        primaryCapability: String? = nil,
        primaryWorkflowCategory: String? = nil,
        primaryNextAction: TKCLINextAction? = nil,
        primaryNextActionSource: String? = nil,
        checks: [TKDoctorCheck],
        error: TKCLIErrorDetail? = nil
    ) {
        self.ok = ok
        self.serverReachable = serverReachable
        self.connected = connected
        self.runtime = runtime
        self.surface = surface
        self.nextStep = nextStep
        self.nextWorkflows = nextWorkflows
        let primarySelection = Self.defaultPrimarySelection(
            nextStep: nextStep,
            checks: checks,
            error: error,
            preferredCapability: primaryCapability,
            preferredWorkflowCategory: primaryWorkflowCategory,
            preferredAction: primaryNextAction,
            preferredSource: primaryNextActionSource
        )
        self.primaryCapability = primarySelection.capability
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.checks = checks
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.serverReachable = try container.decode(Bool.self, forKey: .serverReachable)
        self.connected = try container.decode(Bool.self, forKey: .connected)
        self.runtime = try container.decode(String.self, forKey: .runtime)
        self.surface = try container.decodeIfPresent(String.self, forKey: .surface) ?? "doctor"
        let decodedNextStep = try container.decode(String.self, forKey: .nextStep)
        self.nextStep = decodedNextStep
        self.nextWorkflows = try container.decodeIfPresent([String].self, forKey: .nextWorkflows) ?? []
        let decodedChecks = try container.decode([TKDoctorCheck].self, forKey: .checks)
        self.checks = decodedChecks
        let decodedError = try container.decodeIfPresent(TKCLIErrorDetail.self, forKey: .error)
        let decodedPrimaryNextAction = try container.decodeIfPresent(TKCLINextAction.self, forKey: .primaryNextAction)
        let primarySelection = Self.defaultPrimarySelection(
            nextStep: decodedNextStep,
            checks: decodedChecks,
            error: decodedError,
            preferredCapability: try container.decodeIfPresent(String.self, forKey: .primaryCapability),
            preferredWorkflowCategory: try container.decodeIfPresent(String.self, forKey: .primaryWorkflowCategory),
            preferredAction: decodedPrimaryNextAction,
            preferredSource: try container.decodeIfPresent(String.self, forKey: .primaryNextActionSource)
        )
        self.primaryCapability = primarySelection.capability
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.error = decodedError
    }

    private static func defaultPrimarySelection(
        nextStep: String,
        checks: [TKDoctorCheck],
        error: TKCLIErrorDetail?,
        preferredCapability: String?,
        preferredWorkflowCategory: String?,
        preferredAction: TKCLINextAction?,
        preferredSource: String?
    ) -> (capability: String?, workflowCategory: String?, nextAction: TKCLINextAction?, source: String?) {
        if let preferredAction {
            return (
                preferredCapability ?? capabilityName(for: preferredAction, in: checks),
                preferredWorkflowCategory ?? workflowCategory(for: preferredAction, in: checks),
                preferredAction,
                preferredSource ?? "explicit"
            )
        }
        if let nextStepCheck = checks.first(where: { $0.id == nextStep }) {
            return (
                nextStepCheck.relatedCapabilities.first,
                primaryWorkflowCategory(for: nextStepCheck.workflowCategories),
                nextStepCheck.nextAction,
                "next-step-check"
            )
        }
        if let actionableCheck = checks.first(where: { $0.status == "fail" || $0.status == "warn" }) {
            return (
                actionableCheck.relatedCapabilities.first,
                primaryWorkflowCategory(for: actionableCheck.workflowCategories),
                actionableCheck.nextAction,
                "actionable-check"
            )
        }
        if let errorAction = error?.nextAction {
            return (
                capabilityName(for: errorAction, in: checks) ?? preferredCapability,
                workflowCategory(for: errorAction, in: checks) ?? preferredWorkflowCategory,
                errorAction,
                "error"
            )
        }
        return (preferredCapability, preferredWorkflowCategory, nil, preferredSource)
    }

    private static func capabilityName(for action: TKCLINextAction, in checks: [TKDoctorCheck]) -> String? {
        checks.first(where: { $0.nextAction == action })?.relatedCapabilities.first
    }

    private static func workflowCategory(for action: TKCLINextAction, in checks: [TKDoctorCheck]) -> String? {
        checks.first(where: { $0.nextAction == action })
            .flatMap { primaryWorkflowCategory(for: $0.workflowCategories) }
    }

    private static func primaryWorkflowCategory(for categories: [String]) -> String? {
        let priority = [
            "app", "target", "runtime", "observe", "action", "assert",
            "evidence", "smoke", "route", "replay", "webview-check",
            "project", "xcode",
        ]
        let categorySet = Set(categories)
        if let preferred = priority.first(where: { categorySet.contains($0) }) {
            return preferred
        }
        return categories.first
    }
}

public struct TKCommandSchemaOption: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let defaultValue: String?
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = false,
        defaultValue: String? = nil,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
        self.description = description
    }
}

public struct TKCommandUsageForm: Codable, Equatable {
    public let form: String
    public let kind: String
    public let description: String

    public init(
        form: String,
        kind: String,
        description: String
    ) {
        self.form = form
        self.kind = kind
        self.description = description
    }
}

public struct TKCommandArgumentForm: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = false,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
    }
}

public struct TKCommandSchemaField: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = true,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
    }
}

public struct TKCommandOutputContract: Codable, Equatable {
    public let selector: String
    public let format: String
    public let kind: String
    public let model: String?
    public let fields: [TKCommandSchemaField]

    public init(
        selector: String,
        format: String,
        kind: String,
        model: String? = nil,
        fields: [TKCommandSchemaField]
    ) {
        self.selector = selector
        self.format = format
        self.kind = kind
        self.model = model
        self.fields = fields
    }
}

public struct TKCommandRecoveryCommand: Codable, Equatable {
    public let command: String
    public let category: String

    public init(command: String, category: String) {
        self.command = command
        self.category = category
    }

    public init?(commandString: String) {
        guard let root = Self.rootCommand(in: commandString),
              let category = Self.category(forRootCommand: root) else {
            return nil
        }
        self.init(command: commandString, category: category)
    }

    public static func rootCommand(in commandString: String) -> String? {
        let tokens = commandString.split(separator: " ").map(String.init)
        guard let tritonIndex = tokens.firstIndex(of: "triton"), tokens.count > tritonIndex + 1 else {
            return nil
        }
        return tokens[tritonIndex + 1]
    }

    public static func category(forRootCommand rootCommand: String) -> String? {
        recoveryCommandRootCategoryMap[rootCommand]
    }

    public static var categoryTaxonomy: Set<String> {
        [
            "act",
            "archive",
            "diagnose",
            "discover",
            "observe",
            "plan",
            "prepare-target",
            "project",
            "replay",
            "smoke",
            "verify",
        ]
    }

    public static var rootCommandTaxonomy: Set<String> {
        Set(recoveryCommandRootCategoryMap.keys)
    }

    public static func recoveryCategories(forFailureCode failureCode: String) -> [String] {
        var categories: [String] = []
        if targetFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("prepare-target")
        }
        if projectFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("project")
        }
        if actionFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("act")
        }
        if destructivePolicyFailureCodesRequiringRecovery.contains(failureCode) || unsupportedFailureCodesRequiringRecovery.contains(failureCode) {
            categories.append("plan")
        }
        if failureCode == "timeout" {
            categories.append("verify")
        }
        if ["request_failed", "server_unavailable", "target_unavailable", "runtime_unavailable"].contains(failureCode) {
            categories.append("diagnose")
        }
        if ["artifact_write_failed", "file_write_failed", "artifact_output_rejected"].contains(failureCode) {
            categories.append("archive")
        }
        return categories
    }

    private static let recoveryCommandRootCategoryMap: [String: String] = [
        "app": "prepare-target",
        "assert": "verify",
        "attrs": "observe",
        "ax": "observe",
        "capabilities": "diagnose",
        "capture": "archive",
        "clear": "act",
        "coverage": "archive",
        "device": "prepare-target",
        "doctor": "diagnose",
        "evidence": "archive",
        "export": "archive",
        "find": "discover",
        "focus": "act",
        "geometry": "observe",
        "hierarchy": "observe",
        "hit": "observe",
        "input": "act",
        "inspect": "discover",
        "ledger": "archive",
        "list": "discover",
        "node": "observe",
        "nodes": "observe",
        "object": "observe",
        "observe": "observe",
        "paste": "act",
        "plan": "plan",
        "press": "act",
        "record": "replay",
        "replay": "replay",
        "route": "verify",
        "runtime": "diagnose",
        "schema": "diagnose",
        "screenshot": "archive",
        "select-segment": "act",
        "serve": "diagnose",
        "set-switch": "act",
        "set-text": "act",
        "sim": "prepare-target",
        "smoke": "smoke",
        "snapshot": "observe",
        "state": "observe",
        "status": "diagnose",
        "swipe": "act",
        "tap": "act",
        "target": "prepare-target",
        "type": "act",
        "wait": "verify",
        "webview": "observe",
        "xcode": "project",
        "xcresult": "archive",
        "xctrace": "archive",
    ]

    private static let targetFailureCodesRequiringRecovery: Set<String> = [
        "ambiguous_target",
        "device_not_ready",
        "simulator_not_found",
        "target_not_found",
        "target_offline",
        "target_unavailable",
    ]

    private static let projectFailureCodesRequiringRecovery: Set<String> = [
        "ambiguous_workspace",
        "invalid_workspace_path",
        "scheme_not_found",
        "workspace_not_found",
        "xcode_not_idle",
    ]

    private static let actionFailureCodesRequiringRecovery: Set<String> = [
        "action_failed",
        "step_failed",
    ]

    private static let destructivePolicyFailureCodesRequiringRecovery: Set<String> = [
        "confirmation_required",
        "destructive_action_requires_policy",
    ]

    private static let unsupportedFailureCodesRequiringRecovery: Set<String> = [
        "action_not_supported",
        "unsupported_capability",
        "unsupported_runtime_scope",
        "webview_method_not_allowed",
        "webview_wait_unsupported",
    ]
}

public struct TKCommandSubcommandSchema: Codable, Equatable {
    public let name: String
    public let summary: String
    public let requiredOptions: [String]
    public let oneOfRequiredOptions: [[String]]
    public let optionalOptions: [String]
    public let defaultProviders: [String]
    public let inheritsDefaultsFrom: [String]
    public let jsonlEvents: [String]
    public let finalEventKind: String?
    public let artifacts: [String]
    public let retryable: Bool
    public let nextCommands: [String]
    public let recoveryCommands: [TKCommandRecoveryCommand]
    public let outputSelectors: [String]
    public let failureCodes: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case summary
        case requiredOptions
        case oneOfRequiredOptions
        case optionalOptions
        case defaultProviders
        case inheritsDefaultsFrom
        case jsonlEvents
        case finalEventKind
        case artifacts
        case retryable
        case nextCommands
        case recoveryCommands
        case outputSelectors
        case failureCodes
    }

    public init(
        name: String,
        summary: String,
        requiredOptions: [String] = [],
        oneOfRequiredOptions: [[String]] = [],
        optionalOptions: [String] = [],
        defaultProviders: [String] = [],
        inheritsDefaultsFrom: [String] = [],
        jsonlEvents: [String] = [],
        finalEventKind: String? = nil,
        artifacts: [String] = [],
        retryable: Bool = false,
        nextCommands: [String] = [],
        recoveryCommands: [TKCommandRecoveryCommand] = [],
        outputSelectors: [String] = [],
        failureCodes: [String] = []
    ) {
        self.name = name
        self.summary = summary
        self.requiredOptions = requiredOptions
        self.oneOfRequiredOptions = oneOfRequiredOptions
        self.optionalOptions = optionalOptions
        self.defaultProviders = defaultProviders
        self.inheritsDefaultsFrom = inheritsDefaultsFrom
        self.jsonlEvents = jsonlEvents
        self.finalEventKind = finalEventKind
        self.artifacts = artifacts
        self.retryable = retryable
        self.nextCommands = nextCommands
        self.recoveryCommands = recoveryCommands.isEmpty ?
            nextCommands.compactMap(TKCommandRecoveryCommand.init(commandString:)) :
            recoveryCommands
        self.outputSelectors = outputSelectors
        self.failureCodes = failureCodes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            summary: try container.decode(String.self, forKey: .summary),
            requiredOptions: try container.decodeIfPresent([String].self, forKey: .requiredOptions) ?? [],
            oneOfRequiredOptions: try container.decodeIfPresent([[String]].self, forKey: .oneOfRequiredOptions) ?? [],
            optionalOptions: try container.decodeIfPresent([String].self, forKey: .optionalOptions) ?? [],
            defaultProviders: try container.decodeIfPresent([String].self, forKey: .defaultProviders) ?? [],
            inheritsDefaultsFrom: try container.decodeIfPresent([String].self, forKey: .inheritsDefaultsFrom) ?? [],
            jsonlEvents: try container.decodeIfPresent([String].self, forKey: .jsonlEvents) ?? [],
            finalEventKind: try container.decodeIfPresent(String.self, forKey: .finalEventKind),
            artifacts: try container.decodeIfPresent([String].self, forKey: .artifacts) ?? [],
            retryable: try container.decodeIfPresent(Bool.self, forKey: .retryable) ?? false,
            nextCommands: try container.decodeIfPresent([String].self, forKey: .nextCommands) ?? [],
            recoveryCommands: try container.decodeIfPresent([TKCommandRecoveryCommand].self, forKey: .recoveryCommands) ?? [],
            outputSelectors: try container.decodeIfPresent([String].self, forKey: .outputSelectors) ?? [],
            failureCodes: try container.decodeIfPresent([String].self, forKey: .failureCodes) ?? []
        )
    }
}

public struct TKCommandSchema: Codable, Equatable {
    private static let defaultFailureShape = "{ ok: false, error: { code, message, endpoint, hint, nextAction?{ command,args,category,requiresLongRunningProcess? } } }"

    public let name: String
    public let summary: String
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let requiresHierarchy: Bool
    public let runtimeScope: String
    public let exitCodeOnFailure: Int
    public let outputFormats: [String]
    public let options: [TKCommandSchemaOption]
    public let usageForms: [TKCommandUsageForm]
    public let argumentForms: [TKCommandArgumentForm]
    public let examples: [String]
    public let successShape: String?
    public let failureShape: String?
    public let outputSemantics: String?
    public let requiredOptions: [String]
    public let inheritsDefaultsFrom: [String]
    public let jsonlEvents: [String]
    public let finalEventKind: String?
    public let artifacts: [String]
    public let retryable: Bool
    public let nextCommands: [String]
    public let recoveryCommands: [TKCommandRecoveryCommand]
    public let outputContracts: [TKCommandOutputContract]
    public let failureCodes: [String]
    public let subcommands: [TKCommandSubcommandSchema]
    public let inputActions: [TKInputActionSchema]?
    public let providedCapabilities: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case summary
        case requiresServer
        case requiresTarget
        case requiresHierarchy
        case runtimeScope
        case exitCodeOnFailure
        case outputFormats
        case options
        case usageForms
        case argumentForms
        case examples
        case successShape
        case failureShape
        case outputSemantics
        case requiredOptions
        case inheritsDefaultsFrom
        case jsonlEvents
        case finalEventKind
        case artifacts
        case retryable
        case nextCommands
        case recoveryCommands
        case outputContracts
        case failureCodes
        case subcommands
        case inputActions
        case providedCapabilities
    }

    public init(
        name: String,
        summary: String,
        requiresServer: Bool,
        requiresTarget: Bool,
        requiresHierarchy: Bool = false,
        runtimeScope: String = "cli",
        exitCodeOnFailure: Int = 1,
        outputFormats: [String],
        options: [TKCommandSchemaOption],
        usageForms: [TKCommandUsageForm] = [],
        argumentForms: [TKCommandArgumentForm] = [],
        examples: [String],
        successShape: String? = nil,
        failureShape: String? = "{ ok: false, error: { code, message, endpoint, hint, nextAction?{ command,args,category,requiresLongRunningProcess? } } }",
        outputSemantics: String? = nil,
        requiredOptions: [String] = [],
        inheritsDefaultsFrom: [String] = [],
        jsonlEvents: [String] = [],
        finalEventKind: String? = nil,
        artifacts: [String] = [],
        retryable: Bool = false,
        nextCommands: [String] = [],
        recoveryCommands: [TKCommandRecoveryCommand] = [],
        outputContracts: [TKCommandOutputContract] = [],
        failureCodes: [String] = [],
        subcommands: [TKCommandSubcommandSchema] = [],
        inputActions: [TKInputActionSchema]? = nil,
        providedCapabilities: [String] = []
    ) {
        self.name = name
        self.summary = summary
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.requiresHierarchy = requiresHierarchy
        self.runtimeScope = runtimeScope
        self.exitCodeOnFailure = exitCodeOnFailure
        self.outputFormats = outputFormats
        self.options = options.filter { !$0.isUsageFormSeed && !$0.isArgumentFormSeed }
        self.usageForms = usageForms + options.compactMap(\.usageFormSeed)
        self.argumentForms = argumentForms + options.compactMap(\.argumentFormSeed)
        self.examples = examples
        self.successShape = successShape
        self.failureShape = TKCommandSchema.normalizedFailureShape(failureShape)
        self.outputSemantics = outputSemantics
        self.requiredOptions = requiredOptions
        self.inheritsDefaultsFrom = inheritsDefaultsFrom
        self.jsonlEvents = jsonlEvents
        self.finalEventKind = finalEventKind
        self.artifacts = artifacts
        self.retryable = retryable
        self.nextCommands = nextCommands
        self.recoveryCommands = recoveryCommands.isEmpty ?
            nextCommands.compactMap(TKCommandRecoveryCommand.init(commandString:)) :
            recoveryCommands
        self.outputContracts = outputContracts
        self.failureCodes = failureCodes
        self.subcommands = subcommands
        self.inputActions = inputActions
        self.providedCapabilities = providedCapabilities
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            summary: try container.decode(String.self, forKey: .summary),
            requiresServer: try container.decode(Bool.self, forKey: .requiresServer),
            requiresTarget: try container.decode(Bool.self, forKey: .requiresTarget),
            requiresHierarchy: try container.decodeIfPresent(Bool.self, forKey: .requiresHierarchy) ?? false,
            runtimeScope: try container.decodeIfPresent(String.self, forKey: .runtimeScope) ?? "cli",
            exitCodeOnFailure: try container.decodeIfPresent(Int.self, forKey: .exitCodeOnFailure) ?? 1,
            outputFormats: try container.decode([String].self, forKey: .outputFormats),
            options: try container.decode([TKCommandSchemaOption].self, forKey: .options),
            usageForms: try container.decodeIfPresent([TKCommandUsageForm].self, forKey: .usageForms) ?? [],
            argumentForms: try container.decodeIfPresent([TKCommandArgumentForm].self, forKey: .argumentForms) ?? [],
            examples: try container.decode([String].self, forKey: .examples),
            successShape: try container.decodeIfPresent(String.self, forKey: .successShape),
            failureShape: try container.decodeIfPresent(String.self, forKey: .failureShape) ?? TKCommandSchema.defaultFailureShape,
            outputSemantics: try container.decodeIfPresent(String.self, forKey: .outputSemantics),
            requiredOptions: try container.decodeIfPresent([String].self, forKey: .requiredOptions) ?? [],
            inheritsDefaultsFrom: try container.decodeIfPresent([String].self, forKey: .inheritsDefaultsFrom) ?? [],
            jsonlEvents: try container.decodeIfPresent([String].self, forKey: .jsonlEvents) ?? [],
            finalEventKind: try container.decodeIfPresent(String.self, forKey: .finalEventKind),
            artifacts: try container.decodeIfPresent([String].self, forKey: .artifacts) ?? [],
            retryable: try container.decodeIfPresent(Bool.self, forKey: .retryable) ?? false,
            nextCommands: try container.decodeIfPresent([String].self, forKey: .nextCommands) ?? [],
            recoveryCommands: try container.decodeIfPresent([TKCommandRecoveryCommand].self, forKey: .recoveryCommands) ?? [],
            outputContracts: try container.decodeIfPresent([TKCommandOutputContract].self, forKey: .outputContracts) ?? [],
            failureCodes: try container.decodeIfPresent([String].self, forKey: .failureCodes) ?? [],
            subcommands: try container.decodeIfPresent([TKCommandSubcommandSchema].self, forKey: .subcommands) ?? [],
            inputActions: try container.decodeIfPresent([TKInputActionSchema].self, forKey: .inputActions),
            providedCapabilities: try container.decodeIfPresent([String].self, forKey: .providedCapabilities) ?? []
        )
    }

    private static func normalizedFailureShape(_ failureShape: String?) -> String? {
        guard let failureShape else {
            return nil
        }
        guard failureShape.contains("nextAction?"),
              !failureShape.contains("nextAction.category"),
              !failureShape.contains("nextAction?{")
        else {
            return failureShape
        }
        return failureShape.replacingOccurrences(
            of: "nextAction?",
            with: "nextAction?{ command,args,category,requiresLongRunningProcess? }"
        )
    }
}

private extension TKCommandSchemaOption {
    var isUsageFormSeed: Bool {
        usageFormSeed != nil
    }

    var isArgumentFormSeed: Bool {
        argumentFormSeed != nil
    }

    var argumentFormSeed: TKCommandArgumentForm? {
        guard name.hasPrefix("<"), name.hasSuffix(">") else {
            return nil
        }
        return TKCommandArgumentForm(
            name: name,
            type: type,
            required: required,
            description: description
        )
    }

    var usageFormSeed: TKCommandUsageForm? {
        switch type {
        case "Subcommand", "Task":
            return TKCommandUsageForm(form: name, kind: type, description: description)
        default:
            return nil
        }
    }
}

public struct TKHTTPManagementEndpointSchema: Codable, Equatable {
    public let method: String
    public let path: String
    public let successShape: String
    public let failureShape: String

    public init(
        method: String,
        path: String,
        successShape: String,
        failureShape: String = "{ ok: false, error: { code, message, endpoint, hint } }"
    ) {
        self.method = method
        self.path = path
        self.successShape = successShape
        self.failureShape = failureShape
    }
}

public struct TKInputActionSchema: Codable, Equatable {
    public let type: String
    public let requiredFields: [String]
    public let optionalFields: [String]
    public let oneOfRequired: [[String]]
    public let coordinateSpace: String?
    public let fields: [TKInputActionFieldSchema]
    public let example: String
    public let resultShape: String

    public init(
        type: String,
        requiredFields: [String],
        optionalFields: [String],
        oneOfRequired: [[String]] = [],
        coordinateSpace: String? = nil,
        fields: [TKInputActionFieldSchema],
        example: String,
        resultShape: String = "{ ok, action, message, targetOID, targetClassName }"
    ) {
        self.type = type
        self.requiredFields = requiredFields
        self.optionalFields = optionalFields
        self.oneOfRequired = oneOfRequired
        self.coordinateSpace = coordinateSpace
        self.fields = fields
        self.example = example
        self.resultShape = resultShape
    }
}

public struct TKInputActionFieldSchema: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let enumValues: [String]?
    public let description: String

    public init(
        name: String,
        type: String,
        required: Bool = false,
        enumValues: [String]? = nil,
        description: String
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.enumValues = enumValues
        self.description = description
    }
}

public struct TKCLISchemaResponse: Codable, Equatable {
    public let schemaVersion: Int
    public let commands: [TKCommandSchema]
    public let httpManagementAPI: [TKHTTPManagementEndpointSchema]

    public init(
        schemaVersion: Int = 1,
        commands: [TKCommandSchema],
        httpManagementAPI: [TKHTTPManagementEndpointSchema] = []
    ) {
        self.schemaVersion = schemaVersion
        self.commands = commands
        self.httpManagementAPI = httpManagementAPI
    }
}

public struct TKWorkflowPlanStep: Codable, Equatable {
    public let id: String
    public let title: String
    public let command: String
    public let argv: [String]
    public let category: String
    public let workflowCategories: [String]
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let when: String
    public let expected: String
    public let requires: [String]
    public let expectedArtifacts: [String]
    public let stopConditions: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case command
        case argv
        case category
        case workflowCategories
        case requiresServer
        case requiresTarget
        case when
        case expected
        case requires
        case expectedArtifacts
        case stopConditions
    }

    public init(
        id: String,
        title: String,
        command: String,
        argv: [String]? = nil,
        category: String? = nil,
        workflowCategories: [String]? = nil,
        requiresServer: Bool,
        requiresTarget: Bool,
        when: String,
        expected: String,
        requires: [String]? = nil,
        expectedArtifacts: [String]? = nil,
        stopConditions: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.argv = argv ?? Self.defaultArgv(for: command)
        self.category = category ?? Self.category(for: command)
        self.workflowCategories = workflowCategories ?? Self.defaultWorkflowCategories(for: command)
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.when = when
        self.expected = expected
        self.requires = requires ?? Self.defaultRequires(requiresServer: requiresServer, requiresTarget: requiresTarget)
        self.expectedArtifacts = expectedArtifacts ?? Self.defaultExpectedArtifacts(for: command)
        self.stopConditions = stopConditions ?? Self.defaultStopConditions(
            for: command,
            requiresServer: requiresServer,
            requiresTarget: requiresTarget
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let command = try container.decode(String.self, forKey: .command)
        let requiresServer = try container.decode(Bool.self, forKey: .requiresServer)
        let requiresTarget = try container.decode(Bool.self, forKey: .requiresTarget)
        self.id = id
        self.title = title
        self.command = command
        self.argv = try container.decodeIfPresent([String].self, forKey: .argv) ?? Self.defaultArgv(for: command)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? Self.category(for: command)
        self.workflowCategories = try container.decodeIfPresent([String].self, forKey: .workflowCategories)
            ?? Self.defaultWorkflowCategories(for: command)
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.when = try container.decode(String.self, forKey: .when)
        self.expected = try container.decode(String.self, forKey: .expected)
        self.requires = try container.decodeIfPresent([String].self, forKey: .requires) ??
            Self.defaultRequires(requiresServer: requiresServer, requiresTarget: requiresTarget)
        self.expectedArtifacts = try container.decodeIfPresent([String].self, forKey: .expectedArtifacts) ??
            Self.defaultExpectedArtifacts(for: command)
        self.stopConditions = try container.decodeIfPresent([String].self, forKey: .stopConditions) ??
            Self.defaultStopConditions(for: command, requiresServer: requiresServer, requiresTarget: requiresTarget)
    }

    private static func category(for command: String) -> String {
        guard let root = TKCommandRecoveryCommand.rootCommand(in: command),
              let category = TKCommandRecoveryCommand.category(forRootCommand: root) else {
            return "plan"
        }
        return category
    }

    private static func defaultArgv(for command: String) -> [String] {
        let tokens = shellTokens(in: command)
        return tokens.isEmpty ? [command] : tokens
    }

    private static func defaultWorkflowCategories(for command: String) -> [String] {
        let taxonomy = [
            "action", "app", "assert", "evidence", "observe", "project",
            "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
        ]

        let tokens = shellTokens(in: command)
        guard let tritonIndex = tokens.firstIndex(of: "triton"), tokens.count > tritonIndex + 1 else {
            return []
        }

        let root = tokens[tritonIndex + 1]
        let subcommand = tokens.count > tritonIndex + 2 ? tokens[tritonIndex + 2] : nil
        let allWorkflows = Set(taxonomy)
        let values: Set<String>

        switch (root, subcommand) {
        case ("serve", _):
            values = ["app", "observe", "action", "assert", "evidence", "replay", "route", "smoke", "webview-check"]
        case ("target", _):
            values = ["target", "app", "runtime", "observe", "action", "assert", "evidence", "smoke"]
        case ("xcode", "run"):
            values = ["project", "xcode", "target", "app", "runtime", "evidence"]
        case ("xcode", _):
            values = ["project", "xcode", "evidence"]
        case ("app", _):
            values = ["target", "app", "assert", "evidence"]
        case ("assert", _):
            values = ["assert", "evidence"]
        case ("runtime", _):
            values = ["app", "runtime", "observe", "action", "assert", "evidence"]
        case ("state", _), ("snapshot", _):
            values = ["app", "runtime", "observe", "action", "assert", "evidence"]
        case ("webview", _):
            values = ["observe", "route", "assert", "evidence", "webview-check"]
        case ("route", _):
            values = ["route", "assert", "evidence", "webview-check"]
        case ("smoke", _):
            values = ["smoke", "target", "app", "assert", "evidence"]
        case ("evidence", _), ("capture", _), ("export", _):
            values = ["evidence", "replay"]
        case ("plan", _):
            values = allWorkflows
        case ("geometry", _), ("ax", _), ("hit", _), ("wait", _), ("screenshot", _), ("list", _), ("inspect", _):
            values = ["observe", "action", "assert", "evidence"]
        case ("input", _), ("tap", _), ("swipe", _), ("type", _), ("paste", _), ("clear", _), ("press", _):
            values = ["action", "assert", "evidence"]
        case ("doctor", _), ("status", _), ("capabilities", _), ("schema", _):
            values = allWorkflows
        default:
            values = []
        }

        return taxonomy.filter { values.contains($0) }
    }

    private static func defaultRequires(requiresServer: Bool, requiresTarget: Bool) -> [String] {
        var values = ["cli.available"]
        if requiresServer {
            values.append("server.reachable")
        }
        if requiresTarget {
            values.append("target.ready")
            values.append("runtime.connected")
        }
        return unique(values)
    }

    fileprivate static func defaultExpectedArtifacts(for command: String) -> [String] {
        let root = TKCommandRecoveryCommand.rootCommand(in: command) ?? "plan"
        var values = ["stdout-json"]

        switch root {
        case "assert":
            values.append("assertion-result")
        case "capture", "evidence", "export":
            values.append("evidence-bundle")
        case "coverage":
            values.append("coverage-report")
        case "route":
            values.append("route-assertion")
        case "replay":
            values.append("replay-summary")
        case "screenshot":
            values.append("screenshot")
        case "smoke":
            values.append("smoke-summary")
            values.append("evidence-bundle")
        case "target":
            values.append("target-resolution")
        case "wait":
            values.append("wait-result")
        case "webview":
            values.append("webview-json")
        case "xcode":
            values.append("xcode-log")
        case "xcresult":
            values.append("xcresult-summary")
        case "xctrace":
            values.append("trace")
        default:
            break
        }

        return unique(values)
    }

    private static func defaultStopConditions(for command: String, requiresServer: Bool, requiresTarget: Bool) -> [String] {
        let root = TKCommandRecoveryCommand.rootCommand(in: command) ?? "plan"
        var values = ["command.failed"]
        if requiresServer {
            values.append("server.unavailable")
        }
        if requiresTarget {
            values.append("target.unavailable")
        }

        switch root {
        case "assert", "route":
            values.append("assertion.failed")
        case "capture", "evidence", "export", "screenshot", "xcresult", "xctrace", "coverage":
            values.append("artifact.write-failed")
        case "replay", "smoke":
            values.append("step.failed")
        case "wait":
            values.append("timeout")
        default:
            break
        }

        return unique(values)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func shellTokens(in command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var iterator = command.makeIterator()

        while let character = iterator.next() {
            if inSingleQuote {
                if character == "'" {
                    inSingleQuote = false
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "'" {
                inSingleQuote = true
                continue
            }

            if character == "\\" {
                if let next = iterator.next() {
                    current.append(next)
                } else {
                    current.append(character)
                }
                continue
            }

            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                }
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

public struct TKWorkflowPlanResponse: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let runtime: String
    public let surface: String
    public let mode: String
    public let goal: String?
    public let nextStep: String
    public let nextWorkflows: [String]
    public let primaryWorkflowCategory: String?
    public let primaryExpectedArtifact: String?
    public let primaryNextAction: TKCLINextAction?
    public let primaryNextActionSource: String?
    public let steps: [TKWorkflowPlanStep]
    public let error: TKCLIErrorDetail?

    enum CodingKeys: String, CodingKey {
        case ok
        case serverReachable
        case connected
        case runtime
        case surface
        case mode
        case goal
        case nextStep
        case nextWorkflows
        case primaryWorkflowCategory
        case primaryExpectedArtifact
        case primaryNextAction
        case primaryNextActionSource
        case steps
        case error
    }

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        runtime: String,
        surface: String = "plan",
        mode: String? = nil,
        goal: String? = nil,
        nextStep: String,
        nextWorkflows: [String]? = nil,
        primaryWorkflowCategory: String? = nil,
        primaryExpectedArtifact: String? = nil,
        primaryNextAction: TKCLINextAction? = nil,
        primaryNextActionSource: String? = nil,
        steps: [TKWorkflowPlanStep],
        error: TKCLIErrorDetail? = nil
    ) {
        self.ok = ok
        self.serverReachable = serverReachable
        self.connected = connected
        self.runtime = runtime
        self.surface = surface
        self.mode = mode ?? Self.defaultMode(for: goal)
        self.goal = goal
        self.nextStep = nextStep
        self.nextWorkflows = nextWorkflows ?? Self.defaultNextWorkflows(for: goal, nextStep: nextStep)
        let primarySelection = Self.defaultPrimarySelection(
            goal: goal,
            nextStep: nextStep,
            steps: steps,
            error: error,
            preferredWorkflowCategory: primaryWorkflowCategory,
            preferredExpectedArtifact: primaryExpectedArtifact,
            preferredAction: primaryNextAction,
            preferredSource: primaryNextActionSource
        )
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryExpectedArtifact = primarySelection.expectedArtifact
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.steps = steps
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.serverReachable = try container.decode(Bool.self, forKey: .serverReachable)
        self.connected = try container.decode(Bool.self, forKey: .connected)
        self.runtime = try container.decode(String.self, forKey: .runtime)
        self.surface = try container.decodeIfPresent(String.self, forKey: .surface) ?? "plan"
        self.goal = try container.decodeIfPresent(String.self, forKey: .goal)
        self.mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? Self.defaultMode(for: goal)
        let decodedNextStep = try container.decode(String.self, forKey: .nextStep)
        self.nextStep = decodedNextStep
        self.nextWorkflows = try container.decodeIfPresent([String].self, forKey: .nextWorkflows)
            ?? Self.defaultNextWorkflows(for: goal, nextStep: decodedNextStep)
        let decodedSteps = try container.decode([TKWorkflowPlanStep].self, forKey: .steps)
        self.steps = decodedSteps
        let decodedError = try container.decodeIfPresent(TKCLIErrorDetail.self, forKey: .error)
        let primarySelection = Self.defaultPrimarySelection(
            goal: self.goal,
            nextStep: decodedNextStep,
            steps: decodedSteps,
            error: decodedError,
            preferredWorkflowCategory: try container.decodeIfPresent(String.self, forKey: .primaryWorkflowCategory),
            preferredExpectedArtifact: try container.decodeIfPresent(String.self, forKey: .primaryExpectedArtifact),
            preferredAction: try container.decodeIfPresent(TKCLINextAction.self, forKey: .primaryNextAction),
            preferredSource: try container.decodeIfPresent(String.self, forKey: .primaryNextActionSource)
        )
        self.primaryWorkflowCategory = primarySelection.workflowCategory
        self.primaryExpectedArtifact = primarySelection.expectedArtifact
        self.primaryNextAction = primarySelection.nextAction
        self.primaryNextActionSource = primarySelection.source
        self.error = decodedError
    }

    private static func defaultMode(for goal: String?) -> String {
        guard let goal, !goal.isEmpty, goal != "general" else {
            return "bootstrap"
        }
        return "task"
    }

    private static func defaultNextWorkflows(for goal: String?, nextStep: String) -> [String] {
        let taxonomy = [
            "action", "app", "assert", "evidence", "observe", "project",
            "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
        ]

        let values: Set<String>
        switch goal {
        case nil, "", "general":
            switch nextStep {
            case "start-server":
                values = ["app", "observe", "action", "assert", "evidence", "replay", "route", "smoke", "webview-check"]
            case "connect-target":
                values = ["target", "app", "runtime", "observe", "action", "assert", "evidence", "smoke", "route", "webview-check"]
            case "geometry", "ax", "wait", "hit", "input", "screenshot", "archive":
                values = ["observe", "action", "assert", "evidence"]
            default:
                values = []
            }
        case "ios-smoke":
            values = ["smoke", "target", "app", "assert", "evidence"]
        case "open-url":
            values = ["target", "app", "assert", "evidence"]
        case "webview-check":
            values = ["observe", "route", "assert", "evidence", "webview-check"]
        default:
            values = []
        }

        return taxonomy.filter { values.contains($0) }
    }

    private static func defaultPrimaryNextAction(for goal: String?, nextStep: String) -> TKCLINextAction? {
        switch nextStep {
        case "start-server":
            return TKCLINextAction(command: "serve", args: [], requiresLongRunningProcess: true)
        case "inspect-schema":
            return TKCLINextAction(command: "schema", args: ["--json"])
        case "connect-target", "target-list":
            return TKCLINextAction(command: "target", args: ["list", "--json"])
        case "target-resolve":
            return TKCLINextAction(command: "target", args: ["resolve", "<selector>", "--json"])
        case "target-use":
            return TKCLINextAction(command: "target", args: ["use", "<selector>", "--json"])
        case "target-wait-ready":
            return TKCLINextAction(command: "target", args: ["wait-ready", "<selector>", "--json"])
        case "geometry":
            return TKCLINextAction(command: "geometry", args: ["--json"])
        case "ax":
            return TKCLINextAction(command: "ax", args: ["--json"])
        case "wait", "wait-text":
            return TKCLINextAction(command: "wait", args: ["--text", "<text>", "--json"])
        case "hit":
            return TKCLINextAction(command: "hit", args: ["--json"])
        case "input":
            return TKCLINextAction(command: "input", args: ["--json", "--summary", "--strict"])
        case "screenshot":
            return TKCLINextAction(command: "screenshot", args: ["--json"])
        case "archive":
            return TKCLINextAction(command: "export", args: ["--format", "archive", "--json"])
        case "app-open-url":
            return TKCLINextAction(command: "app", args: ["open-url", "<url>", "--json"])
        case "webview-current":
            return TKCLINextAction(command: "webview", args: ["current", "--json"])
        case "route-assert-current-url":
            return TKCLINextAction(command: "route", args: ["assert-current-url", "<expected-url>", "--json"])
        case "ios-smoke":
            return TKCLINextAction(command: "smoke", args: ["ios", "--json"])
        default:
            guard goal == "webview-check" else {
                return nil
            }
            return TKCLINextAction(command: "webview", args: ["current", "--json"])
        }
    }

    private static func defaultPrimarySelection(
        goal: String?,
        nextStep: String,
        steps: [TKWorkflowPlanStep],
        error: TKCLIErrorDetail?,
        preferredWorkflowCategory: String?,
        preferredExpectedArtifact: String?,
        preferredAction: TKCLINextAction?,
        preferredSource: String?
    ) -> (workflowCategory: String?, expectedArtifact: String?, nextAction: TKCLINextAction?, source: String?) {
        if let preferredAction {
            return (
                preferredWorkflowCategory ?? workflowCategory(for: preferredAction, in: steps),
                preferredExpectedArtifact ?? expectedArtifact(for: preferredAction, in: steps),
                preferredAction,
                preferredSource ?? "explicit"
            )
        }
        if let nextStepAction = steps.first(where: { $0.id == nextStep }).flatMap({ TKCLINextAction.fromTritonArgv($0.argv) }) {
            return (
                steps.first(where: { $0.id == nextStep }).flatMap { primaryWorkflowCategory(for: $0.workflowCategories) },
                steps.first(where: { $0.id == nextStep })?.expectedArtifacts.first,
                nextStepAction,
                "next-step-step"
            )
        }
        if let firstStepAction = steps.first.flatMap({ TKCLINextAction.fromTritonArgv($0.argv) }) {
            return (
                steps.first.flatMap { primaryWorkflowCategory(for: $0.workflowCategories) },
                steps.first?.expectedArtifacts.first,
                firstStepAction,
                "first-step"
            )
        }
        if let defaultAction = Self.defaultPrimaryNextAction(for: goal, nextStep: nextStep) {
            return (
                preferredWorkflowCategory ?? primaryWorkflowCategory(for: Self.defaultNextWorkflows(for: goal, nextStep: nextStep)),
                preferredExpectedArtifact ?? Self.defaultExpectedArtifacts(for: defaultAction).first,
                defaultAction,
                "default-next-step"
            )
        }
        if let errorAction = error?.nextAction {
            return (
                workflowCategory(for: errorAction, in: steps) ?? preferredWorkflowCategory,
                expectedArtifact(for: errorAction, in: steps) ?? preferredExpectedArtifact,
                errorAction,
                "error"
            )
        }
        return (preferredWorkflowCategory, preferredExpectedArtifact, nil, preferredSource)
    }

    private static func workflowCategory(for action: TKCLINextAction, in steps: [TKWorkflowPlanStep]) -> String? {
        steps.first(where: { TKCLINextAction.fromTritonArgv($0.argv) == action })
            .flatMap { primaryWorkflowCategory(for: $0.workflowCategories) }
    }

    private static func expectedArtifact(for action: TKCLINextAction, in steps: [TKWorkflowPlanStep]) -> String? {
        steps.first(where: { TKCLINextAction.fromTritonArgv($0.argv) == action })?.expectedArtifacts.first
    }

    private static func primaryWorkflowCategory(for categories: [String]) -> String? {
        let priority = [
            "app", "target", "runtime", "observe", "action", "assert",
            "evidence", "smoke", "route", "replay", "webview-check",
            "project", "xcode",
        ]
        let categorySet = Set(categories)
        if let preferred = priority.first(where: { categorySet.contains($0) }) {
            return preferred
        }
        return categories.first
    }

    private static func defaultExpectedArtifacts(for action: TKCLINextAction) -> [String] {
        let command = ([action.command] + action.args).joined(separator: " ")
        return TKWorkflowPlanStep.defaultExpectedArtifacts(for: command)
    }
}
