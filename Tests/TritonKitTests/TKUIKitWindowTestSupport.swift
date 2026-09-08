import Testing
@testable import TritonKit

#if canImport(UIKit)
import UIKit

/// UIWindow is process-wide state. Serializing each child suite independently
/// still lets another suite replace its key window while an async test yields.
@Suite(.serialized)
struct TKUIKitWindowTests {}

@MainActor
func makeRuntimeTestWindow(frame: CGRect) throws -> UIWindow {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window: UIWindow
    if scenes.isEmpty {
        // SwiftPM's hostless XCTest runner can use UIKit without a scene. The
        // runtime already supports real visible windows in its object registry.
        window = UIWindow(frame: frame)
    } else {
        let scene = try #require(
            scenes.first { $0.activationState == .foregroundActive }
                ?? scenes.first { $0.activationState == .foregroundInactive },
            "The test runner must provide a foreground UIWindowScene; refusing a background scene"
        )
        window = UIWindow(windowScene: scene)
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
        "Fixture window must be the runtime's coordinate window before dispatch; no safety check is bypassed"
    )
    ready = true
    return window
}
#endif
