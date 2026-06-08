import Foundation
import TritonKitShared
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@MainActor
func currentAppState() -> TKRuntimeAppStateResponse {
    let windows = allRuntimeWindows()
    let info = Bundle.main.infoDictionary ?? [:]
    let displayName = info["CFBundleDisplayName"] as? String
        ?? info["CFBundleName"] as? String
        ?? ""
    let style = windows.first.map { userInterfaceStyleName($0.traitCollection.userInterfaceStyle) } ?? "unknown"
    return TKRuntimeAppStateResponse(
        capturedAt: currentStateTimestamp(),
        app: TKRuntimeAppState(
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
            displayName: displayName,
            version: info["CFBundleShortVersionString"] as? String,
            build: info["CFBundleVersion"] as? String,
            localeIdentifier: Locale.current.identifier,
            preferredLanguages: Locale.preferredLanguages,
            preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory.rawValue,
            userInterfaceStyle: style,
            processUptimeSeconds: ProcessInfo.processInfo.systemUptime,
            sceneCount: UIApplication.shared.connectedScenes.count,
            windowCount: windows.count
        )
    )
}

@MainActor
func currentSceneState() -> TKRuntimeSceneStateResponse {
    let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .enumerated()
        .map { sceneIndex, scene in
            let windows = scene.windows.enumerated().map { windowIndex, window in
                runtimeWindowState(window, id: "scene-\(sceneIndex)-window-\(windowIndex)")
            }
            return TKRuntimeSceneState(
                id: "scene-\(sceneIndex)",
                activationState: activationStateName(scene.activationState),
                interfaceOrientation: interfaceOrientationName(scene.interfaceOrientation),
                screenBounds: tkRect(scene.screen.bounds),
                screenScale: Double(scene.screen.scale),
                windowCount: scene.windows.count,
                windows: windows
            )
        }
    return TKRuntimeSceneStateResponse(
        capturedAt: currentStateTimestamp(),
        scenes: scenes,
        keyWindow: allRuntimeWindows().enumerated().first(where: { $0.element.isKeyWindow }).map {
            runtimeWindowState($0.element, id: "window-\($0.offset)")
        },
        warnings: scenes.isEmpty ? ["No UIWindowScene is connected"] : []
    )
}

@MainActor
func currentRouteState() -> TKRuntimeRouteStateResponse {
    guard let root = keyWindows().first?.rootViewController else {
        return TKRuntimeRouteStateResponse(
            capturedAt: currentStateTimestamp(),
            warnings: ["No key window root view controller"]
        )
    }
    let visible = visibleController(from: root)
    let navigationController = (visible as? UINavigationController) ?? visible?.navigationController ?? (root as? UINavigationController)
    let tabController = (visible as? UITabBarController) ?? visible?.tabBarController ?? (root as? UITabBarController)
    let navigationStack = navigationController?.viewControllers.map(controllerState) ?? []
    let presentedStack = presentedControllerStack(from: root)
    let tabState = tabController.map(runtimeTabState)
    let controllers = [root, visible].compactMap { $0 } + navigationStack.compactMap { controller in
        TKObjectRegistry.shared.object(for: controller.oid ?? 0) as? UIViewController
    } + presentedStack.compactMap { controller in
        TKObjectRegistry.shared.object(for: controller.oid ?? 0) as? UIViewController
    }
    let hasSwiftUIBoundary = controllers.contains { NSStringFromClass(type(of: $0)).contains("UIHostingController") }

    return TKRuntimeRouteStateResponse(
        capturedAt: currentStateTimestamp(),
        rootController: controllerState(root),
        visibleController: visible.map(controllerState),
        presentedStack: presentedStack,
        navigationStack: navigationStack,
        tab: tabState,
        swiftUIBoundary: hasSwiftUIBoundary,
        warnings: hasSwiftUIBoundary ? ["SwiftUI private view tree is not reflected; only UIHostingController boundary is reported"] : []
    )
}

@MainActor
func currentResponderState() -> TKRuntimeResponderStateResponse {
    let windows = keyWindows()
    for (windowIndex, window) in windows.enumerated() {
        guard let responder = findFirstResponder(in: window) else { continue }
        let view = responder as? UIView
        let frame = view.map { tkRect(window.convert($0.bounds, from: $0)) }
        let traits = responder as? UITextInputTraits
        return TKRuntimeResponderStateResponse(
            capturedAt: currentStateTimestamp(),
            firstResponder: TKRuntimeResponderState(
                oid: oid(for: responder),
                className: NSStringFromClass(type(of: responder)),
                frame: frame,
                windowIndex: windowIndex,
                isTextInput: responder is UIKeyInput,
                isEditable: textInputEditable(responder),
                isSecureTextEntry: traits?.isSecureTextEntry,
                keyboardType: traits.flatMap { $0.keyboardType.map(keyboardTypeName) },
                returnKeyType: traits.flatMap { $0.returnKeyType.map(returnKeyTypeName) }
            ),
            redaction: TKRuntimeStateRedaction()
        )
    }
    return TKRuntimeResponderStateResponse(
        capturedAt: currentStateTimestamp(),
        warnings: ["No first responder found in key windows"]
    )
}

@MainActor
func allRuntimeWindows() -> [UIWindow] {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
}

func runtimeWindowState(_ window: UIWindow, id: String) -> TKRuntimeWindowState {
    TKRuntimeWindowState(
        id: id,
        isKeyWindow: window.isKeyWindow,
        isHidden: window.isHidden,
        alpha: Double(window.alpha),
        windowLevel: Double(window.windowLevel.rawValue),
        bounds: tkRect(window.bounds),
        safeArea: TKInsets(
            top: Double(window.safeAreaInsets.top),
            left: Double(window.safeAreaInsets.left),
            bottom: Double(window.safeAreaInsets.bottom),
            right: Double(window.safeAreaInsets.right)
        ),
        rootViewControllerClass: window.rootViewController.map { NSStringFromClass(type(of: $0)) }
    )
}

@MainActor
func currentRuntimeSnapshot(_ request: TKRuntimeSnapshotRequest) -> TKRuntimeSnapshotResponse {
    let capturedAt = currentStateTimestamp()
    let include = request.include.isEmpty ? ["app", "scene", "route", "ax", "geometry"] : request.include
    let requested = Set(include.map { $0.lowercased() })
    var artifacts: [TKRuntimeSnapshotArtifact] = []
    var skipped: [TKRuntimeSnapshotSkipped] = []
    var truncation = TKRuntimeSnapshotTruncation()

    func includes(_ name: String) -> Bool {
        requested.contains(name) || requested.contains("ui") && ["ax", "hierarchy"].contains(name)
    }
    func artifact(_ name: String) {
        artifacts.append(TKRuntimeSnapshotArtifact(name: name, capturedAt: capturedAt, freshness: "fresh"))
    }

    let app: TKRuntimeAppState?
    if includes("app") {
        app = currentAppState().app
        artifact("app")
    } else {
        app = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "app", reason: "not requested"))
    }

    let scene: TKRuntimeSceneStateResponse?
    if includes("scene") {
        scene = currentSceneState()
        artifact("scene")
    } else {
        scene = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "scene", reason: "not requested"))
    }

    let route: TKRuntimeRouteStateResponse?
    if includes("route") {
        route = currentRouteState()
        artifact("route")
    } else {
        route = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "route", reason: "not requested"))
    }

    let responder: TKRuntimeResponderStateResponse?
    if includes("responder") {
        responder = currentResponderState()
        artifact("responder")
    } else {
        responder = nil
    }

    let geometry: TKGeometryResponse?
    if includes("geometry") {
        geometry = currentGeometry()
        artifact("geometry")
    } else {
        geometry = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "geometry", reason: "not requested"))
    }

    let ax: [TKAXNode]?
    let axForMedia: [TKAXNode]?
    let shouldBuildAX = includes("ax") || includes("accessibility") || includes("media")
    if shouldBuildAX {
        let maxNodes = max(1, request.maxAXNodes ?? 800)
        var context = AXBuildContext(maxNodes: maxNodes)
        let nodes = keyWindows().map { window in
            buildAXWindowNode(for: window, context: &context)
        }
        axForMedia = nodes
        ax = (includes("ax") || includes("accessibility")) ? nodes : nil
        if context.remaining == 0 {
            truncation = TKRuntimeSnapshotTruncation(
                truncated: true,
                reason: "maxAXNodes reached",
                originalCount: nil,
                returnedCount: maxNodes
            )
        }
        if includes("ax") || includes("accessibility") {
            artifact("ax")
        }
    } else {
        ax = nil
        axForMedia = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "ax", reason: "not requested"))
    }

    let media: TKRuntimeMediaStateResponse?
    if includes("media") {
        media = currentMediaState(axNodes: axForMedia)
        artifact("media")
    } else {
        media = nil
        skipped.append(TKRuntimeSnapshotSkipped(name: "media", reason: "not requested"))
    }

    let screenshot: TKRuntimeScreenshotMetadata?
    if includes("screenshot-metadata") || includes("screenshot") {
        if let window = keyWindows().first {
            screenshot = TKRuntimeScreenshotMetadata(
                format: "png",
                width: Double(window.bounds.width),
                height: Double(window.bounds.height),
                scale: Double(window.screen.scale)
            )
            artifact("screenshot-metadata")
        } else {
            screenshot = nil
            skipped.append(TKRuntimeSnapshotSkipped(name: "screenshot-metadata", reason: "no key window"))
        }
    } else {
        screenshot = nil
    }

    return TKRuntimeSnapshotResponse(
        capturedAt: capturedAt,
        include: include,
        app: app,
        scene: scene,
        route: route,
        responder: responder,
        media: media,
        geometry: geometry,
        ax: ax,
        screenshot: screenshot,
        artifacts: artifacts,
        skipped: skipped,
        truncation: truncation
    )
}

func nearestSuperview<T: UIView>(of view: UIView, matching type: T.Type) -> T? {
    var current: UIView? = view
    while let view = current {
        if let match = view as? T {
            return match
        }
        current = view.superview
    }
    return nil
}

func controllerState(_ controller: UIViewController) -> TKRuntimeControllerState {
    TKRuntimeControllerState(
        className: NSStringFromClass(type(of: controller)),
        title: nonEmptyText(controller.title)
            ?? nonEmptyText(controller.navigationItem.title)
            ?? nonEmptyText(controller.tabBarItem.title),
        oid: oid(for: controller)
    )
}

func visibleController(from controller: UIViewController?) -> UIViewController? {
    guard let controller else { return nil }
    if let presented = controller.presentedViewController {
        return visibleController(from: presented)
    }
    if let tab = controller as? UITabBarController {
        return visibleController(from: tab.selectedViewController) ?? tab
    }
    if let navigation = controller as? UINavigationController {
        return visibleController(from: navigation.topViewController) ?? navigation
    }
    if let split = controller as? UISplitViewController, let last = split.viewControllers.last {
        return visibleController(from: last) ?? split
    }
    if let page = controller as? UIPageViewController, let first = page.viewControllers?.first {
        return visibleController(from: first) ?? page
    }
    return controller
}

func presentedControllerStack(from controller: UIViewController) -> [TKRuntimeControllerState] {
    var stack: [TKRuntimeControllerState] = []
    var current = controller.presentedViewController
    while let controller = current {
        stack.append(controllerState(controller))
        current = controller.presentedViewController
    }
    return stack
}

func runtimeTabState(_ tabController: UITabBarController) -> TKRuntimeTabState {
    let tabs = (tabController.viewControllers ?? []).map { controller in
        nonEmptyText(controller.tabBarItem.title)
            ?? nonEmptyText(controller.title)
            ?? NSStringFromClass(type(of: controller))
    }
    let selectedTitle = tabController.selectedViewController.flatMap {
        nonEmptyText($0.tabBarItem.title) ?? nonEmptyText($0.title)
    }
    return TKRuntimeTabState(
        selectedIndex: tabController.selectedIndex,
        selectedTitle: selectedTitle,
        tabs: tabs
    )
}

func findFirstResponder(in view: UIView) -> UIResponder? {
    if view.isFirstResponder {
        return view
    }
    for subview in view.subviews {
        if let responder = findFirstResponder(in: subview) {
            return responder
        }
    }
    return nil
}

func oid(for object: UIResponder) -> UInt? {
    TKObjectRegistry.shared.register(object)
}

func textInputEditable(_ responder: UIResponder) -> Bool? {
    if let textField = responder as? UITextField {
        return textField.isEnabled
    }
    if let textView = responder as? UITextView {
        return textView.isEditable
    }
    if responder is UIKeyInput {
        return true
    }
    return nil
}
#endif
