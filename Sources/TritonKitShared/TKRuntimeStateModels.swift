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
