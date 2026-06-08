import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKRuntimeStateModelsTests {
    @Test("app state response is machine readable and privacy bounded")
    func appStateShape() throws {
        let response = TKRuntimeAppStateResponse(
            capturedAt: "2026-05-21T12:00:00Z",
            app: TKRuntimeAppState(
                bundleIdentifier: "com.example.demo",
                displayName: "Demo",
                version: "1.2.3",
                build: "45",
                localeIdentifier: "en_US",
                preferredLanguages: ["en-US", "zh-Hans-US"],
                preferredContentSizeCategory: "UICTContentSizeCategoryM",
                userInterfaceStyle: "dark",
                processUptimeSeconds: 12.5,
                sceneCount: 1,
                windowCount: 2
            )
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeAppStateResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.runtime == "embedded")
        #expect(decoded.app.bundleIdentifier == "com.example.demo")
        #expect(decoded.app.version == "1.2.3")
        #expect(decoded.app.build == "45")
        #expect(decoded.app.preferredLanguages.first == "en-US")
        #expect(decoded.app.userInterfaceStyle == "dark")
        #expect(decoded.warnings.isEmpty)
    }

    @Test("scene state response carries scene window and key window summaries")
    func sceneStateShape() throws {
        let keyWindow = TKRuntimeWindowState(
            id: "window-0",
            isKeyWindow: true,
            isHidden: false,
            alpha: 1,
            windowLevel: 0,
            bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
            safeArea: TKInsets(top: 59, left: 0, bottom: 34, right: 0),
            rootViewControllerClass: "Demo.RootViewController"
        )
        let response = TKRuntimeSceneStateResponse(
            capturedAt: "2026-05-21T12:00:00Z",
            scenes: [
                TKRuntimeSceneState(
                    id: "scene-0",
                    activationState: "foregroundActive",
                    interfaceOrientation: "portrait",
                    screenBounds: TKRect(x: 0, y: 0, width: 390, height: 844),
                    screenScale: 3,
                    windowCount: 1,
                    windows: [keyWindow]
                ),
            ],
            keyWindow: keyWindow
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeSceneStateResponse.self, from: data)

        #expect(decoded.scenes.first?.activationState == "foregroundActive")
        #expect(decoded.scenes.first?.windows.first?.isKeyWindow == true)
        #expect(decoded.keyWindow?.rootViewControllerClass == "Demo.RootViewController")
        #expect(decoded.keyWindow?.safeArea.top == 59)
    }

    @Test("route state response explains controller container context")
    func routeStateShape() throws {
        let login = TKRuntimeControllerState(className: "Demo.LoginViewController", title: "Login", oid: 42)
        let response = TKRuntimeRouteStateResponse(
            capturedAt: "2026-05-21T12:00:00Z",
            rootController: TKRuntimeControllerState(className: "UITabBarController", title: nil, oid: 1),
            visibleController: login,
            presentedStack: [TKRuntimeControllerState(className: "UIAlertController", title: "Confirm", oid: 99)],
            navigationStack: [
                TKRuntimeControllerState(className: "Demo.HomeViewController", title: "Home", oid: 21),
                login,
            ],
            tab: TKRuntimeTabState(selectedIndex: 1, selectedTitle: "Account", tabs: ["Home", "Account"]),
            swiftUIBoundary: false
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeRouteStateResponse.self, from: data)

        #expect(decoded.visibleController?.className == "Demo.LoginViewController")
        #expect(decoded.presentedStack.first?.className == "UIAlertController")
        #expect(decoded.navigationStack.map(\.title) == ["Home", "Login"])
        #expect(decoded.tab?.selectedIndex == 1)
        #expect(decoded.swiftUIBoundary == false)
    }

    @Test("responder state does not expose text content")
    func responderStateShape() throws {
        let response = TKRuntimeResponderStateResponse(
            capturedAt: "2026-05-21T12:00:00Z",
            firstResponder: TKRuntimeResponderState(
                oid: 7,
                className: "UITextField",
                frame: TKRect(x: 20, y: 100, width: 240, height: 44),
                windowIndex: 0,
                isTextInput: true,
                isEditable: true,
                isSecureTextEntry: true,
                keyboardType: "emailAddress",
                returnKeyType: "done"
            ),
            redaction: TKRuntimeStateRedaction(secureText: "length-only", textContent: "not-collected")
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeResponderStateResponse.self, from: data)

        #expect(decoded.firstResponder?.className == "UITextField")
        #expect(decoded.firstResponder?.isTextInput == true)
        #expect(decoded.firstResponder?.isSecureTextEntry == true)
        #expect(decoded.redaction.secureText == "length-only")
        #expect(decoded.redaction.textContent == "not-collected")
    }

}
