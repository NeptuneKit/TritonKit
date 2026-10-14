import Testing
@testable import TritonKit

#if canImport(UIKit)
import UIKit

/// UIWindow is process-wide state. Serializing each child suite independently
/// still lets another suite replace its key window while an async test yields.
@Suite(.serialized)
struct TKUIKitWindowTests {}

/// Every window fixture already hides its window in defer. End editing before
/// that public teardown so first responders cannot retain keyboard state into
/// the next test; this does not alter action eligibility while a test runs.
@MainActor
private final class RuntimeTestWindow: UIWindow {
    override var isHidden: Bool {
        willSet { if newValue { endEditing(true) } }
    }
}

@MainActor
func makeRuntimeTestWindow(frame: CGRect) throws -> UIWindow {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window: UIWindow
    if scenes.isEmpty {
        // SwiftPM's hostless XCTest runner can use UIKit without a scene. The
        // runtime already supports real visible windows in its object registry.
        window = RuntimeTestWindow(frame: frame)
    } else {
        let scene = try #require(
            scenes.first { $0.activationState == .foregroundActive },
            Comment(rawValue: "An app-hosted test runner must supply an actual foregroundActive UIWindowScene; inactive/background scenes are not action fixtures. " + runtimeTestWindowEnvironment())
        )
        window = RuntimeTestWindow(windowScene: scene)
        window.frame = frame
    }
    var ready = false
    defer { if !ready { window.isHidden = true } }
    window.rootViewController = UIViewController()
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    _ = TKObjectRegistry.shared.register(window)
    try #require(!window.isHidden && window.alpha > 0, "Fixture must be a real visible UIWindow")
    try #require(
        keyWindows().first === window,
        Comment(rawValue: "Fixture window must be the runtime's coordinate window before dispatch; no safety check is bypassed. " + runtimeTestWindowEnvironment(window: window))
    )
    ready = true
    return window
}

/// Failure diagnostics describe real UIKit state without private identifiers,
/// activation overrides, test-only action roots, or weakening runtime policy.
@MainActor
private func runtimeTestWindowEnvironment(window: UIWindow? = nil) -> String {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let sceneFacts = scenes.map { scene in
        "state=\(scene.activationState.rawValue),windows=\(scene.windows.count),visible=\(scene.windows.filter { !$0.isHidden && $0.alpha > 0.01 }.count)"
    }.sorted().joined(separator: ";")
    let windowFacts = window.map {
        "fixtureScene=\($0.windowScene.map { String($0.activationState.rawValue) } ?? "none"),hidden=\($0.isHidden),alpha=\($0.alpha),interaction=\($0.isUserInteractionEnabled),key=\($0.isKeyWindow),level=\($0.windowLevel.rawValue)"
    } ?? "fixture=not-created"
    let actionWindowFacts = keyWindows().enumerated().map { index, candidate in
        let canBecomeKey = { if #available(iOS 15.0, *) { return String(candidate.canBecomeKey) }; return "unavailable" }()
        let rootClass = candidate.rootViewController.map { String(describing: type(of: $0)) } ?? "none"
        return "order=\(index),class=\(String(describing: type(of: candidate))),root=\(rootClass),level=\(candidate.windowLevel.rawValue),key=\(candidate.isKeyWindow),hidden=\(candidate.isHidden),interaction=\(candidate.isUserInteractionEnabled),canBecomeKey=\(canBecomeKey),fixture=\(candidate === window)"
    }.joined(separator: ";")
    return "UIKit environment: appState=\(UIApplication.shared.applicationState.rawValue),scenes=\(scenes.count)[\(sceneFacts)],\(windowFacts),actionWindows=\(keyWindows().count)[\(actionWindowFacts)]."
}
#endif
