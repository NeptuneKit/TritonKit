import Foundation

public struct TKRuntimeAppStateResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let app: TKRuntimeAppState
    public let warnings: [String]
    public let unsupported: [TKRuntimeUnsupportedState]

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        app: TKRuntimeAppState,
        warnings: [String] = [],
        unsupported: [TKRuntimeUnsupportedState] = []
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.app = app
        self.warnings = warnings
        self.unsupported = unsupported
    }
}

public struct TKRuntimeAppState: Codable, Equatable {
    public let bundleIdentifier: String
    public let displayName: String
    public let version: String?
    public let build: String?
    public let localeIdentifier: String
    public let preferredLanguages: [String]
    public let preferredContentSizeCategory: String?
    public let userInterfaceStyle: String
    public let processUptimeSeconds: Double
    public let sceneCount: Int
    public let windowCount: Int

    public init(
        bundleIdentifier: String,
        displayName: String,
        version: String? = nil,
        build: String? = nil,
        localeIdentifier: String,
        preferredLanguages: [String],
        preferredContentSizeCategory: String? = nil,
        userInterfaceStyle: String,
        processUptimeSeconds: Double,
        sceneCount: Int,
        windowCount: Int
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.version = version
        self.build = build
        self.localeIdentifier = localeIdentifier
        self.preferredLanguages = preferredLanguages
        self.preferredContentSizeCategory = preferredContentSizeCategory
        self.userInterfaceStyle = userInterfaceStyle
        self.processUptimeSeconds = processUptimeSeconds
        self.sceneCount = sceneCount
        self.windowCount = windowCount
    }
}

public struct TKRuntimeSceneStateResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let scenes: [TKRuntimeSceneState]
    public let keyWindow: TKRuntimeWindowState?
    public let warnings: [String]
    public let unsupported: [TKRuntimeUnsupportedState]

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        scenes: [TKRuntimeSceneState],
        keyWindow: TKRuntimeWindowState? = nil,
        warnings: [String] = [],
        unsupported: [TKRuntimeUnsupportedState] = []
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.scenes = scenes
        self.keyWindow = keyWindow
        self.warnings = warnings
        self.unsupported = unsupported
    }
}

public struct TKRuntimeSceneState: Codable, Equatable {
    public let id: String
    public let activationState: String
    public let interfaceOrientation: String
    public let screenBounds: TKRect
    public let screenScale: Double
    public let windowCount: Int
    public let windows: [TKRuntimeWindowState]

    public init(
        id: String,
        activationState: String,
        interfaceOrientation: String,
        screenBounds: TKRect,
        screenScale: Double,
        windowCount: Int,
        windows: [TKRuntimeWindowState]
    ) {
        self.id = id
        self.activationState = activationState
        self.interfaceOrientation = interfaceOrientation
        self.screenBounds = screenBounds
        self.screenScale = screenScale
        self.windowCount = windowCount
        self.windows = windows
    }
}

public struct TKRuntimeWindowState: Codable, Equatable {
    public let id: String
    public let isKeyWindow: Bool
    public let isHidden: Bool
    public let alpha: Double
    public let windowLevel: Double
    public let bounds: TKRect
    public let safeArea: TKInsets
    public let rootViewControllerClass: String?

    public init(
        id: String,
        isKeyWindow: Bool,
        isHidden: Bool,
        alpha: Double,
        windowLevel: Double,
        bounds: TKRect,
        safeArea: TKInsets,
        rootViewControllerClass: String? = nil
    ) {
        self.id = id
        self.isKeyWindow = isKeyWindow
        self.isHidden = isHidden
        self.alpha = alpha
        self.windowLevel = windowLevel
        self.bounds = bounds
        self.safeArea = safeArea
        self.rootViewControllerClass = rootViewControllerClass
    }
}

public struct TKRuntimeRouteStateResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let rootController: TKRuntimeControllerState?
    public let visibleController: TKRuntimeControllerState?
    public let presentedStack: [TKRuntimeControllerState]
    public let navigationStack: [TKRuntimeControllerState]
    public let tab: TKRuntimeTabState?
    public let swiftUIBoundary: Bool
    public let warnings: [String]
    public let unsupported: [TKRuntimeUnsupportedState]

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        rootController: TKRuntimeControllerState? = nil,
        visibleController: TKRuntimeControllerState? = nil,
        presentedStack: [TKRuntimeControllerState] = [],
        navigationStack: [TKRuntimeControllerState] = [],
        tab: TKRuntimeTabState? = nil,
        swiftUIBoundary: Bool = false,
        warnings: [String] = [],
        unsupported: [TKRuntimeUnsupportedState] = []
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.rootController = rootController
        self.visibleController = visibleController
        self.presentedStack = presentedStack
        self.navigationStack = navigationStack
        self.tab = tab
        self.swiftUIBoundary = swiftUIBoundary
        self.warnings = warnings
        self.unsupported = unsupported
    }
}

public struct TKRuntimeControllerState: Codable, Equatable {
    public let className: String
    public let title: String?
    public let oid: UInt?

    public init(className: String, title: String? = nil, oid: UInt? = nil) {
        self.className = className
        self.title = title
        self.oid = oid
    }
}

public struct TKRuntimeTabState: Codable, Equatable {
    public let selectedIndex: Int
    public let selectedTitle: String?
    public let tabs: [String]

    public init(selectedIndex: Int, selectedTitle: String? = nil, tabs: [String]) {
        self.selectedIndex = selectedIndex
        self.selectedTitle = selectedTitle
        self.tabs = tabs
    }
}

public struct TKRuntimeResponderStateResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let firstResponder: TKRuntimeResponderState?
    public let redaction: TKRuntimeStateRedaction
    public let warnings: [String]
    public let unsupported: [TKRuntimeUnsupportedState]

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        firstResponder: TKRuntimeResponderState? = nil,
        redaction: TKRuntimeStateRedaction = TKRuntimeStateRedaction(),
        warnings: [String] = [],
        unsupported: [TKRuntimeUnsupportedState] = []
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.firstResponder = firstResponder
        self.redaction = redaction
        self.warnings = warnings
        self.unsupported = unsupported
    }
}

public struct TKRuntimeResponderState: Codable, Equatable {
    public let oid: UInt?
    public let className: String
    public let frame: TKRect?
    public let windowIndex: Int?
    public let isTextInput: Bool
    public let isEditable: Bool?
    public let isSecureTextEntry: Bool?
    public let keyboardType: String?
    public let returnKeyType: String?

    public init(
        oid: UInt? = nil,
        className: String,
        frame: TKRect? = nil,
        windowIndex: Int? = nil,
        isTextInput: Bool,
        isEditable: Bool? = nil,
        isSecureTextEntry: Bool? = nil,
        keyboardType: String? = nil,
        returnKeyType: String? = nil
    ) {
        self.oid = oid
        self.className = className
        self.frame = frame
        self.windowIndex = windowIndex
        self.isTextInput = isTextInput
        self.isEditable = isEditable
        self.isSecureTextEntry = isSecureTextEntry
        self.keyboardType = keyboardType
        self.returnKeyType = returnKeyType
    }
}

public struct TKRuntimeMediaStateResponse: Codable, Equatable {
    public let ok: Bool
    public let capturedAt: String
    public let runtime: String
    public let targetConnectionState: String?
    public let surfaces: [TKRuntimeMediaSurface]
    public let controls: [TKRuntimeMediaControlCandidate]
    public let surfaceCount: Int
    public let controlCount: Int
    public let automationConfidence: String
    public let fallbackAdvice: [String]
    public let evidenceCommands: [String]
    public let warnings: [String]
    public let unsupported: [TKRuntimeUnsupportedState]

    public init(
        ok: Bool = true,
        capturedAt: String,
        runtime: String = "embedded",
        targetConnectionState: String? = "connected",
        surfaces: [TKRuntimeMediaSurface],
        controls: [TKRuntimeMediaControlCandidate],
        fallbackAdvice: [String] = TKRuntimeMediaDefaultFallbackAdvice,
        evidenceCommands: [String] = TKRuntimeMediaDefaultEvidenceCommands,
        warnings: [String] = [],
        unsupported: [TKRuntimeUnsupportedState] = []
    ) {
        self.ok = ok
        self.capturedAt = capturedAt
        self.runtime = runtime
        self.targetConnectionState = targetConnectionState
        self.surfaces = surfaces
        self.controls = controls
        self.surfaceCount = surfaces.count
        self.controlCount = controls.count
        self.automationConfidence = TKRuntimeMediaAutomationConfidence(surfaces: surfaces, controls: controls)
        self.fallbackAdvice = fallbackAdvice
        self.evidenceCommands = evidenceCommands
        self.warnings = warnings
        self.unsupported = unsupported
    }
}

public struct TKRuntimeMediaSurface: Codable, Equatable {
    public let id: String
    public let kind: String
    public let className: String
    public let frame: TKRect?
    public let visible: Bool
    public let playerStatus: String?
    public let playbackState: String?
    public let rate: Double?
    public let elapsedTimeSeconds: Double?
    public let durationSeconds: Double?
    public let progress: Double?
    public let controllerClassName: String?

    public init(
        id: String,
        kind: String,
        className: String,
        frame: TKRect? = nil,
        visible: Bool,
        playerStatus: String? = nil,
        playbackState: String? = nil,
        rate: Double? = nil,
        elapsedTimeSeconds: Double? = nil,
        durationSeconds: Double? = nil,
        progress: Double? = nil,
        controllerClassName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.className = className
        self.frame = frame
        self.visible = visible
        self.playerStatus = playerStatus
        self.playbackState = playbackState
        self.rate = rate
        self.elapsedTimeSeconds = elapsedTimeSeconds
        self.durationSeconds = durationSeconds
        self.progress = progress
        self.controllerClassName = controllerClassName
    }
}

public struct TKRuntimeMediaControlCandidate: Codable, Equatable {
    public let action: String
    public let role: String
    public let label: String?
    public let value: String?
    public let identifier: String?
    public let frame: TKRect?
    public let enabled: Bool
    public let source: String

    public init(
        action: String,
        role: String,
        label: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        frame: TKRect? = nil,
        enabled: Bool,
        source: String = "runtime-ax"
    ) {
        self.action = action
        self.role = role
        self.label = label
        self.value = value
        self.identifier = identifier
        self.frame = frame
        self.enabled = enabled
        self.source = source
    }
}

public let TKRuntimeMediaDefaultFallbackAdvice: [String] = [
    "System AVPlayerViewController controls are not guaranteed to expose stable actionable AX nodes in every playback route.",
    "For repeatable automation, add app-owned DEBUG overlay controls with stable accessibility identifiers for play/pause/seek/progress/elapsed/duration.",
    "After media actions, verify route cleanup and playback state with app-owned state, visible controls, screenshot, and evidence bundle artifacts.",
]

public let TKRuntimeMediaDefaultEvidenceCommands: [String] = [
    "triton debug snapshot --include media,ax,screenshot-metadata --json",
    "triton screenshot --json",
    "triton evidence capture --case <case> --output <dir.tritonevidence> --json",
]

public func TKRuntimeMediaAutomationConfidence(
    surfaces: [TKRuntimeMediaSurface],
    controls: [TKRuntimeMediaControlCandidate]
) -> String {
    if surfaces.isEmpty {
        return "no-media-surface"
    }
    let actions = Set(controls.map(\.action))
    if actions.contains("play") || actions.contains("pause") || actions.contains("seek-forward") || actions.contains("seek-backward") || actions.contains("progress") {
        return "actionable-controls"
    }
    if !controls.isEmpty {
        return "observable-controls"
    }
    return "surface-only"
}

public func TKRuntimeMediaControlCandidates(from nodes: [TKAXNode]) -> [TKRuntimeMediaControlCandidate] {
    TKRuntimeFlattenAXNodes(nodes).compactMap { node in
        guard let action = TKRuntimeMediaControlAction(for: node) else { return nil }
        return TKRuntimeMediaControlCandidate(
            action: action,
            role: node.role,
            label: node.label,
            value: node.value,
            identifier: node.identifier,
            frame: node.frame,
            enabled: node.enabled
        )
    }
}

private func TKRuntimeFlattenAXNodes(_ nodes: [TKAXNode]) -> [TKAXNode] {
    nodes.flatMap { [$0] + TKRuntimeFlattenAXNodes($0.children) }
}

private func TKRuntimeMediaControlAction(for node: TKAXNode) -> String? {
    let haystack = [
        node.identifier,
        node.label,
        node.title,
        node.value,
        node.role,
    ]
    .compactMap { $0?.lowercased() }
    .joined(separator: " ")

    if haystack.contains("progress") || haystack.contains("scrubber") || node.role.lowercased() == "slider" {
        return "progress"
    }
    if haystack.contains("seek") && (haystack.contains("back") || haystack.contains("rewind") || haystack.contains("previous")) {
        return "seek-backward"
    }
    if haystack.contains("seek") || haystack.contains("forward") || haystack.contains("next") {
        return haystack.contains("media") || haystack.contains("playback") ? "seek-forward" : nil
    }
    if haystack.contains("pause") {
        return "pause"
    }
    if haystack.contains("play") || haystack.contains("resume") {
        return "play"
    }
    if haystack.contains("elapsed") || haystack.contains("current time") {
        return "elapsed-time"
    }
    if haystack.contains("duration") || haystack.contains("remaining") {
        return "duration"
    }
    return nil
}

public struct TKRuntimeStateRedaction: Codable, Equatable {
    public let secureText: String
    public let textContent: String

    public init(secureText: String = "length-only", textContent: String = "not-collected") {
        self.secureText = secureText
        self.textContent = textContent
    }
}

public struct TKRuntimeUnsupportedState: Codable, Equatable {
    public let field: String
    public let reason: String

    public init(field: String, reason: String) {
        self.field = field
        self.reason = reason
    }
}
