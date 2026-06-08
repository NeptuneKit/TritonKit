import Foundation

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
