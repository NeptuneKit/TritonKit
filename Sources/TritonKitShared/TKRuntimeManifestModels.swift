import Foundation

public struct TKRuntimeCapabilityDetail: Codable, Equatable {
    public let name: String
    public let supported: Bool
    public let scope: String
    public let boundary: String
    public let reason: String?
    public let nextAction: TKCLINextAction?

    public init(
        name: String,
        supported: Bool,
        scope: String,
        boundary: String,
        reason: String? = nil,
        nextAction: TKCLINextAction? = nil
    ) {
        self.name = name
        self.supported = supported
        self.scope = scope
        self.boundary = boundary
        self.reason = reason
        self.nextAction = nextAction
    }
}

public struct TKRuntimeLimits: Codable, Equatable {
    public let maxSnapshotBytes: Int
    public let maxAXNodes: Int
    public let maxLedgerEntries: Int

    public init(maxSnapshotBytes: Int = 1_048_576, maxAXNodes: Int = 800, maxLedgerEntries: Int = 100) {
        self.maxSnapshotBytes = maxSnapshotBytes
        self.maxAXNodes = maxAXNodes
        self.maxLedgerEntries = maxLedgerEntries
    }
}

public struct TKRuntimeRedactionPolicy: Codable, Equatable {
    public let secureText: String
    public let clipboard: String
    public let network: String
    public let logs: String
    public let fileArtifacts: String
    public let policy: String?

    public init(
        secureText: String = "length-only",
        clipboard: String = "not-collected",
        network: String = "opt-in-only",
        logs: String = "opt-in-only",
        fileArtifacts: String = "opt-in-only",
        policy: String? = nil
    ) {
        self.secureText = secureText
        self.clipboard = clipboard
        self.network = network
        self.logs = logs
        self.fileArtifacts = fileArtifacts
        self.policy = policy
    }

    public static let disabledRuntime = TKRuntimeRedactionPolicy(
        secureText: "not-collected",
        clipboard: "not-collected",
        network: "not-collected",
        logs: "not-collected",
        fileArtifacts: "not-collected",
        policy: "disabled-runtime"
    )
}

public struct TKRuntimeManifestResponse: Codable, Equatable {
    public let ok: Bool
    public let platform: String
    public let runtime: String
    public let transport: String
    public let enabled: Bool
    public let sdkVersion: String
    public let buildConfiguration: String
    public let capabilities: [TKRuntimeCapabilityDetail]
    public let limits: TKRuntimeLimits
    public let redaction: TKRuntimeRedactionPolicy

    public init(
        ok: Bool = true,
        platform: String = "ios",
        runtime: String = "embedded",
        transport: String = "embedded-websocket",
        enabled: Bool,
        sdkVersion: String,
        buildConfiguration: String,
        capabilities: [TKRuntimeCapabilityDetail],
        limits: TKRuntimeLimits = TKRuntimeLimits(),
        redaction: TKRuntimeRedactionPolicy = TKRuntimeRedactionPolicy()
    ) {
        self.ok = ok
        self.platform = platform
        self.runtime = runtime
        self.transport = transport
        self.enabled = enabled
        self.sdkVersion = sdkVersion
        self.buildConfiguration = buildConfiguration
        self.capabilities = capabilities
        self.limits = limits
        self.redaction = redaction
    }

    public static func debugDefault(
        sdkVersion: String,
        capabilities: [TKRuntimeCapabilityDetail] = TKRuntimeManifestResponse.defaultDebugCapabilities
    ) -> TKRuntimeManifestResponse {
        TKRuntimeManifestResponse(
            enabled: true,
            sdkVersion: sdkVersion,
            buildConfiguration: "debug",
            capabilities: capabilities
        )
    }

    public static func releaseDisabled(sdkVersion: String) -> TKRuntimeManifestResponse {
        TKRuntimeManifestResponse(
            enabled: false,
            sdkVersion: sdkVersion,
            buildConfiguration: "release",
            capabilities: [],
            limits: TKRuntimeLimits(maxSnapshotBytes: 0, maxAXNodes: 0, maxLedgerEntries: 0),
            redaction: .disabledRuntime
        )
    }

    public static let defaultDebugCapabilities: [TKRuntimeCapabilityDetail] = [
        TKRuntimeCapabilityDetail(name: "runtime.manifest", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "state.app", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "state.scene", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "state.route", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "state.responder", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "app.info", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "hierarchy", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "accessibility", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "geometry", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "hit-test", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "screenshot", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "input.tap", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "input.swipe", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "input.type", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "input.paste", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(name: "input.clear", supported: true, scope: "embedded", boundary: "app-process"),
        TKRuntimeCapabilityDetail(
            name: "press",
            supported: false,
            scope: "host-side",
            boundary: "simulator-host",
            reason: "Host-side HID is not available in the embedded runtime"
        ),
        TKRuntimeCapabilityDetail(
            name: "system-alerts",
            supported: false,
            scope: "host-side",
            boundary: "simulator-host",
            reason: "SpringBoard and CoreSimulatorBridge UI are outside the embedded app process"
        ),
        TKRuntimeCapabilityDetail(
            name: "network-breadcrumbs",
            supported: false,
            scope: "opt-in-provider",
            boundary: "business-opt-in",
            reason: "Network breadcrumbs require explicit app integration and redaction"
        ),
    ]
}
