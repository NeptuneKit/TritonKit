import Foundation

public enum TKWebTargetMirrorState: String, Codable, Equatable {
    case hostOffline = "host_offline"
    case runtimeNotFound = "runtime_not_found"
    case mirrorUnavailable = "mirror_unavailable"
    case ready
}

public enum TKWebTargetDiagnosisCode: String, Codable, Equatable {
    case runtimeNotFound = "runtime_not_found"
    case iosUSBTunnelUnavailable = "ios_usb_tunnel_unavailable"
    case serverNotReachableFromRealDevice = "server_not_reachable_from_real_device"
    case ambiguousRuntimeTarget = "ambiguous_runtime_target"
    case mirrorCapabilityUnavailable = "mirror_capability_unavailable"
}

public struct TKWebTargetRegistryResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let targets: [TKWebTargetRegistryEntry]

    public init(ok: Bool = true, action: String = "web.target-registry", targets: [TKWebTargetRegistryEntry]) {
        self.ok = ok
        self.action = action
        self.targets = targets
    }
}

public struct TKWebTargetRegistryEntry: Codable, Equatable {
    public let id: String
    public let platform: String
    public let kind: String
    public let host: TKWebTargetHost?
    public let runtime: TKWebTargetRuntime?
    public let mirror: TKWebTargetMirror
    public let diagnosis: TKWebTargetDiagnosis?
    public let nextAction: TKWebTargetNextAction?
    public let transportDiagnostics: [TKWebTargetDiagnosis]

    public init(
        id: String,
        platform: String,
        kind: String,
        host: TKWebTargetHost? = nil,
        runtime: TKWebTargetRuntime? = nil,
        mirror: TKWebTargetMirror,
        diagnosis: TKWebTargetDiagnosis? = nil,
        nextAction: TKWebTargetNextAction? = nil,
        transportDiagnostics: [TKWebTargetDiagnosis] = []
    ) {
        self.id = id
        self.platform = platform
        self.kind = kind
        self.host = host
        self.runtime = runtime
        self.mirror = mirror
        self.diagnosis = diagnosis
        self.nextAction = nextAction
        self.transportDiagnostics = transportDiagnostics
    }
}

public struct TKWebTargetHost: Codable, Equatable {
    public let target: String
    public let name: String?
    public let runtime: String?
    public let scope: String?
    public let kind: String?
    public let source: String
    public let state: String
    public let ready: Bool
    public let transport: String?

    public init(
        target: String = "",
        name: String? = nil,
        runtime: String? = nil,
        scope: String? = nil,
        kind: String? = nil,
        source: String,
        state: String,
        ready: Bool,
        transport: String? = nil
    ) {
        self.target = target
        self.name = name
        self.runtime = runtime
        self.scope = scope
        self.kind = kind
        self.source = source
        self.state = state
        self.ready = ready
        self.transport = transport
    }
}

public struct TKWebTargetRuntime: Codable, Equatable {
    public let id: String
    public let state: String
    public let transport: String
    public let baseURL: String?
    public let appBundleId: String?
    public let capabilities: [String]

    public init(
        id: String,
        state: String,
        transport: String,
        baseURL: String? = nil,
        appBundleId: String? = nil,
        capabilities: [String] = []
    ) {
        self.id = id
        self.state = state
        self.transport = transport
        self.baseURL = baseURL
        self.appBundleId = appBundleId
        self.capabilities = capabilities
    }
}

public struct TKWebTargetMirror: Codable, Equatable {
    public let state: TKWebTargetMirrorState

    public init(state: TKWebTargetMirrorState) {
        self.state = state
    }
}

public struct TKWebTargetDiagnosis: Codable, Equatable {
    public let code: TKWebTargetDiagnosisCode
    public let message: String
    public let severity: String

    public init(code: TKWebTargetDiagnosisCode, message: String, severity: String = "warning") {
        self.code = code
        self.message = message
        self.severity = severity
    }
}

public struct TKWebTargetNextAction: Codable, Equatable {
    public let code: String
    public let title: String
    public let command: String?

    public init(code: String, title: String, command: String? = nil) {
        self.code = code
        self.title = title
        self.command = command
    }
}
