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

    @Test("media snapshot summarizes surfaces controls confidence and fallback guidance")
    func mediaStateShape() throws {
        let controls = TKRuntimeMediaControlCandidates(from: [
            TKAXNode(
                role: "button",
                label: "Pause",
                value: nil,
                identifier: "media.pause",
                title: nil,
                frame: TKRect(x: 120, y: 700, width: 44, height: 44),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 10,
                className: "UIButton",
                children: []
            ),
            TKAXNode(
                role: "slider",
                label: "Playback progress",
                value: "42%",
                identifier: "media.progress",
                title: nil,
                frame: TKRect(x: 20, y: 750, width: 350, height: 32),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 11,
                className: "UISlider",
                children: []
            ),
        ])
        let response = TKRuntimeMediaStateResponse(
            capturedAt: "2026-06-08T12:00:00Z",
            surfaces: [
                TKRuntimeMediaSurface(
                    id: "media-surface-1",
                    kind: "avplayer-layer",
                    className: "AVPlayerLayer",
                    frame: TKRect(x: 0, y: 100, width: 390, height: 220),
                    visible: true,
                    playerStatus: "readyToPlay",
                    playbackState: "playing",
                    rate: 1,
                    elapsedTimeSeconds: 12,
                    durationSeconds: 60,
                    progress: 0.2,
                    controllerClassName: "AVPlayerViewController"
                ),
            ],
            controls: controls
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeMediaStateResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.surfaceCount == 1)
        #expect(decoded.controlCount == 2)
        #expect(decoded.automationConfidence == "actionable-controls")
        #expect(decoded.surfaces.first?.playbackState == "playing")
        #expect(decoded.surfaces.first?.progress == 0.2)
        #expect(decoded.controls.map(\.action).contains("pause"))
        #expect(decoded.controls.map(\.action).contains("progress"))
        #expect(decoded.fallbackAdvice.contains { $0.contains("app-owned") })
        #expect(decoded.evidenceCommands.contains("triton snapshot --include media,ax,screenshot-metadata --json"))
    }

    @Test("media snapshot marks visible playback without controls as surface-only")
    func mediaStateSurfaceOnlyGuidance() throws {
        let response = TKRuntimeMediaStateResponse(
            capturedAt: "2026-06-08T12:00:00Z",
            surfaces: [
                TKRuntimeMediaSurface(
                    id: "media-surface-1",
                    kind: "avplayer-layer",
                    className: "AVPlayerLayer",
                    frame: TKRect(x: 0, y: 100, width: 390, height: 220),
                    visible: true
                ),
            ],
            controls: []
        )

        #expect(response.automationConfidence == "surface-only")
        #expect(response.fallbackAdvice.contains { $0.contains("play/pause/seek/progress") })
        #expect(response.evidenceCommands.contains("triton screenshot --json"))
    }

    @Test("semantic snapshot carries provider-backed domain state and action catalog")
    func semanticProviderStateShape() throws {
        let domain = TKRuntimeSemanticDomainState(
            domain: "media-playback",
            displayName: "Media Playback",
            source: "runtime-provider",
            confidence: "provider-backed",
            state: [
                "isReady": .bool(true),
                "elapsed": .double(12.3),
                "routeActiveCount": .int(1),
            ],
            schema: [
                TKRuntimeSemanticStateField(path: "isReady", type: "Bool", description: "Playback item is ready"),
                TKRuntimeSemanticStateField(path: "elapsed", type: "Double", description: "Elapsed playback seconds"),
                TKRuntimeSemanticStateField(path: "routeActiveCount", type: "Int", description: "Active route count"),
            ],
            actions: [
                TKRuntimeSemanticActionDescriptor(
                    name: "pause",
                    description: "Pause playback",
                    arguments: []
                ),
                TKRuntimeSemanticActionDescriptor(
                    name: "seek",
                    description: "Seek to an absolute time",
                    arguments: [
                        TKRuntimeSemanticActionArgument(name: "seconds", type: "Double", required: true, description: "Target time")
                    ]
                ),
            ],
            redaction: TKRuntimeSemanticRedaction(policy: "provider-declared", redactedPaths: ["currentURL"]),
            evidenceCommands: ["triton snapshot --include semantic,app,scene --json"]
        )
        let response = TKRuntimeSemanticStateResponse(
            capturedAt: "2026-06-08T12:00:00Z",
            domains: [domain]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRuntimeSemanticStateResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.domainCount == 1)
        #expect(decoded.domains.first?.capability == "app.semantic_state")
        #expect(decoded.domains.first?.source == "runtime-provider")
        #expect(decoded.domains.first?.confidence == "provider-backed")
        #expect(decoded.domains.first?.state["isReady"] == TKJSONValue.bool(true))
        #expect(decoded.domains.first?.schema.map(\.path).contains("elapsed") == true)
        #expect(decoded.domains.first?.actions.map(\.name) ?? [] == ["pause", "seek"])
        #expect(decoded.domains.first?.redaction.redactedPaths == ["currentURL"])
        #expect(decoded.evidenceCommands.contains("triton snapshot --include semantic,app,scene --json"))
    }

    @Test("semantic snapshot keeps empty provider state explicit")
    func semanticProviderEmptyShape() throws {
        let response = TKRuntimeSemanticStateResponse(
            capturedAt: "2026-06-08T12:00:00Z",
            domains: []
        )

        #expect(response.domainCount == 0)
        #expect(response.warnings.contains { $0.contains("No semantic providers") })
        #expect(response.evidenceCommands.contains("triton runtime manifest --json"))
    }
}
