import Foundation

public enum TKRuntimeCapabilityName: String, Codable, CaseIterable {
    case runtimeManifest = "runtime.manifest"
    case stateApp = "state.app"
    case stateScene = "state.scene"
    case stateRoute = "state.route"
    case stateResponder = "state.responder"
    case snapshot
    case mediaPlayback = "media.playback"
    case semanticState = "app.semantic_state"
    case semanticActionProvider = "app.semantic_action"
    case webViewList = "webview.list"
    case webViewCurrent = "webview.current"
    case webViewSnapshot = "webview.snapshot"
    case webViewBridgeCall = "webview.bridge-call"
    case webViewBridgePost = "webview.bridge-post"
    case webViewTap = "webview.tap"
    case webViewWait = "webview.wait"
    case webViewFocus = "webview.focus"
    case webViewFormInput = "webview.form-input"
    case webViewEvents = "webview.events"
    case webViewEval = "webview.eval"
    case semanticFocus = "semantic.focus"
    case semanticSetText = "semantic.set-text"
    case semanticSelectSegment = "semantic.select-segment"
    case semanticSetSwitch = "semantic.set-switch"
    case ledger
    case appInfo = "app.info"
    case hierarchy
    case accessibility
    case geometry
    case hitTest = "hit-test"
    case screenshot
    case inputTap = "input.tap"
    case inputSwipe = "input.swipe"
    case inputType = "input.type"
    case inputPaste = "input.paste"
    case inputClear = "input.clear"
    case press
    case systemAlerts = "system-alerts"
    case networkBreadcrumbs = "network-breadcrumbs"
}

public enum TKRuntimeCapabilityScope: String, Codable {
    case embedded
    case hostSide = "host-side"
    case optInProvider = "opt-in-provider"
}

public enum TKRuntimeCapabilityBoundary: String, Codable {
    case appProcess = "app-process"
    case simulatorHost = "simulator-host"
    case businessOptIn = "business-opt-in"
}

public struct TKRuntimeCapabilityDetail: Codable, Equatable {
    public let name: String
    public let supported: Bool
    public let enabled: Bool
    public let scope: String
    public let boundary: String
    public let reason: String?
    public let nextAction: TKCLINextAction?

    public init(
        name: String,
        supported: Bool,
        enabled: Bool? = nil,
        scope: String,
        boundary: String,
        reason: String? = nil,
        nextAction: TKCLINextAction? = nil
    ) {
        self.name = name
        self.supported = supported
        self.enabled = enabled ?? supported
        self.scope = scope
        self.boundary = boundary
        self.reason = reason
        self.nextAction = nextAction
    }

    public init(
        name: TKRuntimeCapabilityName,
        supported: Bool,
        enabled: Bool? = nil,
        scope: TKRuntimeCapabilityScope,
        boundary: TKRuntimeCapabilityBoundary,
        reason: String? = nil,
        nextAction: TKCLINextAction? = nil
    ) {
        self.init(
            name: name.rawValue,
            supported: supported,
            enabled: enabled,
            scope: scope.rawValue,
            boundary: boundary.rawValue,
            reason: reason,
            nextAction: nextAction
        )
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case supported
        case enabled
        case scope
        case boundary
        case reason
        case nextAction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        supported = try container.decode(Bool.self, forKey: .supported)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? supported
        scope = try container.decode(String.self, forKey: .scope)
        boundary = try container.decode(String.self, forKey: .boundary)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        nextAction = try container.decodeIfPresent(TKCLINextAction.self, forKey: .nextAction)
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
    public let semanticDomains: [TKRuntimeSemanticDomainManifest]
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
        semanticDomains: [TKRuntimeSemanticDomainManifest] = [],
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
        self.semanticDomains = semanticDomains
        self.limits = limits
        self.redaction = redaction
    }

    public static func debugDefault(
        sdkVersion: String,
        capabilities: [TKRuntimeCapabilityDetail] = TKRuntimeManifestResponse.defaultDebugCapabilities,
        semanticDomains: [TKRuntimeSemanticDomainManifest] = []
    ) -> TKRuntimeManifestResponse {
        TKRuntimeManifestResponse(
            enabled: true,
            sdkVersion: sdkVersion,
            buildConfiguration: "debug",
            capabilities: capabilities,
            semanticDomains: semanticDomains
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
        TKRuntimeCapabilityDetail(name: .runtimeManifest, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .stateApp, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .stateScene, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .stateRoute, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .stateResponder, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .snapshot, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .mediaPlayback, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(
            name: .semanticState,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "Semantic state requires an app-registered runtime provider",
            nextAction: TKCLINextAction(command: "snapshot", args: ["--include", "semantic,app,scene", "--json"])
        ),
        TKRuntimeCapabilityDetail(
            name: .semanticActionProvider,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "Action descriptors require an app-registered semantic provider; generic provider action execution is not implemented yet",
            nextAction: TKCLINextAction(command: "snapshot", args: ["--include", "semantic", "--json"])
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewList,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView provider is not registered"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewCurrent,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView provider is not registered"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewSnapshot,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView provider is not registered"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewBridgeCall,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView bridge requires an opt-in allowlist provider"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewBridgePost,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView bridge requires an opt-in allowlist provider"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewTap,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView tap requires an iOS DEBUG WKWebView provider"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewWait,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView wait requires provider events or DOM snapshot support"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewFocus,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView focus requires an opt-in page form-control marker and an iOS DEBUG WKWebView provider"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewFormInput,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView form input requires an opt-in page form-control marker and an iOS DEBUG WKWebView provider"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewEvents,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "WebView events require page bridge or provider event buffering"
        ),
        TKRuntimeCapabilityDetail(
            name: .webViewEval,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "Unsafe JavaScript eval requires explicit DEBUG config and CLI --unsafe-eval"
        ),
        TKRuntimeCapabilityDetail(name: .semanticFocus, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .semanticSetText, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .semanticSelectSegment, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .semanticSetSwitch, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .ledger, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .appInfo, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .hierarchy, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .accessibility, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .geometry, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .hitTest, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .screenshot, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .inputTap, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .inputSwipe, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .inputType, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .inputPaste, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(name: .inputClear, supported: true, scope: .embedded, boundary: .appProcess),
        TKRuntimeCapabilityDetail(
            name: .press,
            supported: false,
            scope: .hostSide,
            boundary: .simulatorHost,
            reason: "Host-side HID is not available in the embedded runtime"
        ),
        TKRuntimeCapabilityDetail(
            name: .systemAlerts,
            supported: false,
            scope: .hostSide,
            boundary: .simulatorHost,
            reason: "SpringBoard and CoreSimulatorBridge UI are outside the embedded app process"
        ),
        TKRuntimeCapabilityDetail(
            name: .networkBreadcrumbs,
            supported: false,
            scope: .optInProvider,
            boundary: .businessOptIn,
            reason: "Network breadcrumbs require explicit app integration and redaction"
        ),
    ]
}
