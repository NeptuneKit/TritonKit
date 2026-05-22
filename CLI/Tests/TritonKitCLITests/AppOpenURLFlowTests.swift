import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct AppOpenURLFlowTests {
    @Test("app open-url enhanced flow records runtime ready and snapshot summary")
    func enhancedOpenURLFlowRecordsReadyAndSnapshot() async throws {
        let snapshot = TKRuntimeSnapshotResponse(
            capturedAt: "2026-05-22T10:30:00Z",
            include: ["app", "scene", "route", "ax", "geometry"],
            app: TKRuntimeAppState(
                bundleIdentifier: "com.example.app",
                displayName: "Example",
                localeIdentifier: "en_US",
                preferredLanguages: ["en"],
                userInterfaceStyle: "light",
                processUptimeSeconds: 3,
                sceneCount: 1,
                windowCount: 1
            ),
            route: TKRuntimeRouteStateResponse(
                capturedAt: "2026-05-22T10:30:00Z",
                visibleController: TKRuntimeControllerState(className: "HomeViewController", title: "Home"),
                tab: TKRuntimeTabState(selectedIndex: 0, selectedTitle: "Home", tabs: ["Home"])
            ),
            ax: [
                TKAXNode(
                    role: "button",
                    label: "Primary",
                    value: nil,
                    identifier: nil,
                    title: nil,
                    frame: TKRect(x: 1, y: 2, width: 3, height: 4),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: nil,
                    className: nil,
                    children: []
                )
            ],
            artifacts: [
                TKRuntimeSnapshotArtifact(name: "app", capturedAt: "2026-05-22T10:30:00Z", freshness: "fresh")
            ]
        )

        let summary = try await runIOSAppOpenURLFlow(
            options: IOSAppOpenURLFlowOptions(
                simulator: "SIM-1",
                runtimeTarget: "triton:local",
                url: "example://home",
                waitReady: true,
                snapshot: true,
                snapshotInclude: ["app", "scene", "route", "ax", "geometry"],
                maxAXNodes: 50,
                host: "127.0.0.1",
                port: 19421,
                timeout: 1,
                interval: 0.01
            ),
            dependencies: IOSAppOpenURLFlowDependencies(
                openURL: { simulator, url in
                    HostAppOpenURLHostStep(
                        ok: true,
                        target: "sim:\(simulator)",
                        sourceCommand: "xcrun simctl openurl \(simulator) \(url)",
                        elapsedMs: 2
                    )
                },
                status: { _, _ in
                    TKStatusResponse(
                        connected: true,
                        latestHierarchyAvailable: true,
                        targetCount: 1,
                        activeHierarchyAvailable: true,
                        hierarchyCacheState: "active",
                        targetConnectionState: "connected"
                    )
                },
                snapshot: { _, _, _, include, maxAXNodes in
                    #expect(include == ["app", "scene", "route", "ax", "geometry"])
                    #expect(maxAXNodes == 50)
                    return snapshot
                }
            )
        )

        #expect(summary.ok)
        #expect(summary.status == .pass)
        #expect(summary.hostAction.sourceCommand == "xcrun simctl openurl SIM-1 example://home")
        #expect(summary.ready?.ok == true)
        #expect(summary.ready?.pollCount == 1)
        #expect(summary.snapshot?.appName == "Example")
        #expect(summary.snapshot?.bundleIdentifier == "com.example.app")
        #expect(summary.snapshot?.visibleControllerTitle == "Home")
        #expect(summary.snapshot?.selectedTabTitle == "Home")
        #expect(summary.snapshot?.axNodeCount == 1)
        #expect(summary.snapshot?.artifacts == ["app"])
    }
}
