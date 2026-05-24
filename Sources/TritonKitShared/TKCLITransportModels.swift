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
    public let activeHierarchyAvailable: Bool?
    public let hierarchyCacheState: String?
    public let targetConnectionState: String?

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        latestHierarchyAvailable: Bool,
        targetCount: Int,
        runtime: String,
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
        self.activeHierarchyAvailable = activeHierarchyAvailable ?? (connected && latestHierarchyAvailable)
        self.hierarchyCacheState = hierarchyCacheState ?? {
            if connected && latestHierarchyAvailable { return "active" }
            if latestHierarchyAvailable { return "stale" }
            return "unavailable"
        }()
        self.targetConnectionState = targetConnectionState ?? (connected ? "connected" : "disconnected")
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
    public let requiresLongRunningProcess: Bool

    public init(command: String, args: [String], requiresLongRunningProcess: Bool = false) {
        self.command = command
        self.args = args
        self.requiresLongRunningProcess = requiresLongRunningProcess
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

    public init(name: String, supported: Bool, reason: String? = nil) {
        self.name = name
        self.supported = supported
        self.reason = reason
    }
}

public struct TKCapabilitiesResponse: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let latestHierarchyAvailable: Bool
    public let targetCount: Int
    public let runtime: String
    public let capabilities: [TKRuntimeCapability]
    public let error: TKCLIErrorDetail?
    public let activeHierarchyAvailable: Bool?
    public let hierarchyCacheState: String?
    public let targetConnectionState: String?

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        latestHierarchyAvailable: Bool,
        targetCount: Int,
        runtime: String,
        capabilities: [TKRuntimeCapability],
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
        self.capabilities = capabilities
        self.error = error
        self.activeHierarchyAvailable = activeHierarchyAvailable ?? (connected && latestHierarchyAvailable)
        self.hierarchyCacheState = hierarchyCacheState ?? {
            if connected && latestHierarchyAvailable { return "active" }
            if latestHierarchyAvailable { return "stale" }
            return "unavailable"
        }()
        self.targetConnectionState = targetConnectionState ?? (connected ? "connected" : "disconnected")
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
            outputSelectors: try container.decodeIfPresent([String].self, forKey: .outputSelectors) ?? [],
            failureCodes: try container.decodeIfPresent([String].self, forKey: .failureCodes) ?? []
        )
    }
}

public struct TKCommandSchema: Codable, Equatable {
    public let name: String
    public let summary: String
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let requiresHierarchy: Bool
    public let runtimeScope: String
    public let exitCodeOnFailure: Int
    public let outputFormats: [String]
    public let options: [TKCommandSchemaOption]
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
        examples: [String],
        successShape: String? = nil,
        failureShape: String? = "{ ok: false, error: { code, message, endpoint, hint, nextAction? } }",
        outputSemantics: String? = nil,
        requiredOptions: [String] = [],
        inheritsDefaultsFrom: [String] = [],
        jsonlEvents: [String] = [],
        finalEventKind: String? = nil,
        artifacts: [String] = [],
        retryable: Bool = false,
        nextCommands: [String] = [],
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
        self.options = options
        self.examples = examples
        self.successShape = successShape
        self.failureShape = failureShape
        self.outputSemantics = outputSemantics
        self.requiredOptions = requiredOptions
        self.inheritsDefaultsFrom = inheritsDefaultsFrom
        self.jsonlEvents = jsonlEvents
        self.finalEventKind = finalEventKind
        self.artifacts = artifacts
        self.retryable = retryable
        self.nextCommands = nextCommands
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
            examples: try container.decode([String].self, forKey: .examples),
            successShape: try container.decodeIfPresent(String.self, forKey: .successShape),
            failureShape: try container.decodeIfPresent(String.self, forKey: .failureShape) ?? "{ ok: false, error: { code, message, endpoint, hint, nextAction? } }",
            outputSemantics: try container.decodeIfPresent(String.self, forKey: .outputSemantics),
            requiredOptions: try container.decodeIfPresent([String].self, forKey: .requiredOptions) ?? [],
            inheritsDefaultsFrom: try container.decodeIfPresent([String].self, forKey: .inheritsDefaultsFrom) ?? [],
            jsonlEvents: try container.decodeIfPresent([String].self, forKey: .jsonlEvents) ?? [],
            finalEventKind: try container.decodeIfPresent(String.self, forKey: .finalEventKind),
            artifacts: try container.decodeIfPresent([String].self, forKey: .artifacts) ?? [],
            retryable: try container.decodeIfPresent(Bool.self, forKey: .retryable) ?? false,
            nextCommands: try container.decodeIfPresent([String].self, forKey: .nextCommands) ?? [],
            outputContracts: try container.decodeIfPresent([TKCommandOutputContract].self, forKey: .outputContracts) ?? [],
            failureCodes: try container.decodeIfPresent([String].self, forKey: .failureCodes) ?? [],
            subcommands: try container.decodeIfPresent([TKCommandSubcommandSchema].self, forKey: .subcommands) ?? [],
            inputActions: try container.decodeIfPresent([TKInputActionSchema].self, forKey: .inputActions),
            providedCapabilities: try container.decodeIfPresent([String].self, forKey: .providedCapabilities) ?? []
        )
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
    public let requiresServer: Bool
    public let requiresTarget: Bool
    public let when: String
    public let expected: String

    public init(
        id: String,
        title: String,
        command: String,
        requiresServer: Bool,
        requiresTarget: Bool,
        when: String,
        expected: String
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.requiresServer = requiresServer
        self.requiresTarget = requiresTarget
        self.when = when
        self.expected = expected
    }
}

public struct TKWorkflowPlanResponse: Codable, Equatable {
    public let ok: Bool
    public let serverReachable: Bool
    public let connected: Bool
    public let runtime: String
    public let nextStep: String
    public let steps: [TKWorkflowPlanStep]
    public let error: TKCLIErrorDetail?

    public init(
        ok: Bool,
        serverReachable: Bool,
        connected: Bool,
        runtime: String,
        nextStep: String,
        steps: [TKWorkflowPlanStep],
        error: TKCLIErrorDetail? = nil
    ) {
        self.ok = ok
        self.serverReachable = serverReachable
        self.connected = connected
        self.runtime = runtime
        self.nextStep = nextStep
        self.steps = steps
        self.error = error
    }
}
