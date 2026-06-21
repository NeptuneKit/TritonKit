import Foundation

public struct TKRuntimeSemanticStateResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let domains: [TKRuntimeSemanticDomainState]
    public let domainCount: Int
    public let evidenceCommands: [String]
    public let warnings: [String]
    public let unsupported: [TKRuntimeUnsupportedState]

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        domains: [TKRuntimeSemanticDomainState],
        evidenceCommands: [String] = TKRuntimeSemanticDefaultEvidenceCommands,
        warnings: [String]? = nil,
        unsupported: [TKRuntimeUnsupportedState] = []
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.domains = domains
        self.domainCount = domains.count
        self.evidenceCommands = evidenceCommands
        self.warnings = warnings ?? (domains.isEmpty ? TKRuntimeSemanticNoProviderWarnings : [])
        self.unsupported = unsupported
    }
}

public struct TKRuntimeSemanticDomainState: Codable, Equatable {
    public let capability: String
    public let domain: String
    public let displayName: String?
    public let source: String
    public let confidence: String
    public let state: [String: TKJSONValue]
    public let schema: [TKRuntimeSemanticStateField]
    public let actions: [TKRuntimeSemanticActionDescriptor]
    public let redaction: TKRuntimeSemanticRedaction
    public let evidenceCommands: [String]
    public let warnings: [String]

    public init(
        capability: String = "app.semantic_state",
        domain: String,
        displayName: String? = nil,
        source: String = "runtime-provider",
        confidence: String = "provider-backed",
        state: [String: TKJSONValue],
        schema: [TKRuntimeSemanticStateField] = [],
        actions: [TKRuntimeSemanticActionDescriptor] = [],
        redaction: TKRuntimeSemanticRedaction = TKRuntimeSemanticRedaction(),
        evidenceCommands: [String] = TKRuntimeSemanticDefaultEvidenceCommands,
        warnings: [String] = []
    ) {
        self.capability = capability
        self.domain = domain
        self.displayName = displayName
        self.source = source
        self.confidence = confidence
        self.state = state
        self.schema = schema
        self.actions = actions
        self.redaction = redaction
        self.evidenceCommands = evidenceCommands
        self.warnings = warnings
    }
}

public struct TKRuntimeSemanticDomainManifest: Codable, Equatable {
    public let capability: String
    public let actionCapability: String
    public let domain: String
    public let displayName: String?
    public let source: String
    public let confidence: String
    public let schema: [TKRuntimeSemanticStateField]
    public let actions: [TKRuntimeSemanticActionDescriptor]
    public let redaction: TKRuntimeSemanticRedaction
    public let evidenceCommands: [String]

    public init(
        capability: String = "app.semantic_state",
        actionCapability: String = "app.semantic_action",
        domain: String,
        displayName: String? = nil,
        source: String = "runtime-provider",
        confidence: String = "provider-backed",
        schema: [TKRuntimeSemanticStateField] = [],
        actions: [TKRuntimeSemanticActionDescriptor] = [],
        redaction: TKRuntimeSemanticRedaction = TKRuntimeSemanticRedaction(),
        evidenceCommands: [String] = TKRuntimeSemanticDefaultEvidenceCommands
    ) {
        self.capability = capability
        self.actionCapability = actionCapability
        self.domain = domain
        self.displayName = displayName
        self.source = source
        self.confidence = confidence
        self.schema = schema
        self.actions = actions
        self.redaction = redaction
        self.evidenceCommands = evidenceCommands
    }
}

public struct TKRuntimeSemanticStateField: Codable, Equatable {
    public let path: String
    public let type: String
    public let description: String?
    public let redaction: String?

    public init(path: String, type: String, description: String? = nil, redaction: String? = nil) {
        self.path = path
        self.type = type
        self.description = description
        self.redaction = redaction
    }
}

public struct TKRuntimeSemanticActionDescriptor: Codable, Equatable {
    public let name: String
    public let description: String?
    public let arguments: [TKRuntimeSemanticActionArgument]
    public let redaction: TKRuntimeSemanticRedaction?

    public init(
        name: String,
        description: String? = nil,
        arguments: [TKRuntimeSemanticActionArgument] = [],
        redaction: TKRuntimeSemanticRedaction? = nil
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.redaction = redaction
    }
}

public struct TKRuntimeSemanticActionArgument: Codable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String?
    public let redaction: String?

    public init(
        name: String,
        type: String,
        required: Bool = false,
        description: String? = nil,
        redaction: String? = nil
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
        self.redaction = redaction
    }
}

public struct TKRuntimeSemanticRedaction: Codable, Equatable {
    public let policy: String
    public let redactedPaths: [String]

    public init(policy: String = "provider-declared", redactedPaths: [String] = []) {
        self.policy = policy
        self.redactedPaths = redactedPaths
    }
}

public let TKRuntimeSemanticDefaultEvidenceCommands: [String] = [
    "triton debug snapshot --include semantic,app,scene --json",
    "triton debug runtime manifest --json",
    "triton evidence capture --case <case> --output <dir.tritonevidence> --json",
]

public let TKRuntimeSemanticNoProviderWarnings: [String] = [
    "No semantic providers are registered; do not infer business readiness from AX, layout, or screenshots alone.",
]
