import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct AppOpenURLFlowTests {
    @Test("iOS simulator app launch accepts redacted env and app arguments")
    func iosSimulatorAppLaunchAcceptsRedactedEnvAndArguments() throws {
        let simulator = HostDeviceSelectionResult(
            platform: .ios,
            target: HostDeviceTarget(
                platform: "ios",
                id: "sim:SIM-1",
                target: "SIM-1",
                state: "Booted",
                ready: true,
                source: "simctl",
                name: "iPhone 15",
                runtime: "iOS 26.5",
                transport: nil,
                scope: "simulator",
                kind: "simulator",
                rawTarget: "SIM-1"
            ),
            selector: "SIM-1",
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "SIM-1", platform: .ios, scope: .simulator))
        )

        let plan = try planHostAppLaunch(
            selection: simulator,
            bundleID: "com.example.demo",
            packageName: nil,
            activity: nil,
            bundle: nil,
            ability: nil,
            payloadURL: nil,
            launchEnvironment: try parseLaunchEnvironment([
                "OVERLOADED_OPENAI_COMPATIBLE_API_KEY=secret-value",
                "OVERLOADED_OPENAI_COMPATIBLE_MODEL=mock-llm"
            ]),
            launchArguments: ["--overloaded-debug-route", "photos.search-provider-settings"],
            adb: "adb",
            hdc: "hdc",
            devicectlArtifacts: nil
        )

        #expect(plan.command.argv == [
            "simctl",
            "launch",
            "SIM-1",
            "com.example.demo",
            "--overloaded-debug-route",
            "photos.search-provider-settings"
        ])
        #expect(plan.command.environment["SIMCTL_CHILD_OVERLOADED_OPENAI_COMPATIBLE_API_KEY"] == "secret-value")
        #expect(plan.command.environment["SIMCTL_CHILD_OVERLOADED_OPENAI_COMPATIBLE_MODEL"] == "mock-llm")
        #expect(plan.command.redactedEnvironmentKeys == [
            "SIMCTL_CHILD_OVERLOADED_OPENAI_COMPATIBLE_API_KEY",
            "SIMCTL_CHILD_OVERLOADED_OPENAI_COMPATIBLE_MODEL"
        ])

        let sourceCommand = hostSourceCommand(plan.command)
        #expect(sourceCommand.contains("SIMCTL_CHILD_OVERLOADED_OPENAI_COMPATIBLE_API_KEY=<redacted>"))
        #expect(sourceCommand.contains("SIMCTL_CHILD_OVERLOADED_OPENAI_COMPATIBLE_MODEL=<redacted>"))
        #expect(sourceCommand.contains("secret-value") == false)
        #expect(sourceCommand.contains("mock-llm") == false)
        #expect(sourceCommand.contains("--overloaded-debug-route"))
        #expect(sourceCommand.contains("photos.search-provider-settings"))
    }

    @Test("launch environment rejects invalid keys before host execution")
    func launchEnvironmentRejectsInvalidKeys() throws {
        #expect(throws: ValidationError.self) {
            _ = try parseLaunchEnvironment(["1BAD=value"])
        }
        #expect(try parseLaunchEnvironment(["GOOD_KEY=value"]) == ["GOOD_KEY": "value"])
    }

    @Test("app schema exposes launch env and argument options")
    func appSchemaExposesLaunchEnvAndArgumentOptions() throws {
        let app = try #require(commandSchemas().first { $0.name == "app" })
        #expect(app.options.contains { $0.name == "--env" && $0.description.contains("SIMCTL_CHILD") })
        #expect(app.options.contains { $0.name == "--arg" && $0.description.contains("launch argument") })
        #expect(app.examples.contains("triton app launch --device iphone15 --bundle-id com.example.app --env FEATURE_FLAG=1 --arg debug-route --arg demo.home --json"))
    }

    @Test("app launch parses repeatable env and launch arguments")
    func appLaunchParsesRepeatableEnvAndLaunchArguments() throws {
        let launch = try HostAppLaunch.parse([
            "--simulator", "SIM-1",
            "--bundle-id", "com.example.demo",
            "--env", "FEATURE_FLAG=1",
            "--arg",
            "debug-route",
            "--arg", "demo.home",
            "--json"
        ])

        #expect(launch.launchEnvironment == ["FEATURE_FLAG=1"])
        #expect(launch.launchArguments == ["debug-route", "demo.home"])
    }

    @Test("real-device app lifecycle planner uses raw host ids but public targets stay redacted")
    func realDeviceAppLifecyclePlannerUsesRawHostIDsAndRedactedTargets() throws {
        let ios = HostDeviceSelectionResult(
            platform: .ios,
            target: HostDeviceTarget(
                platform: "ios",
                id: "ios-real:abc123",
                target: "ios-real:abc123",
                state: "connected",
                ready: true,
                source: "devicectl",
                name: "Lin iPhone",
                runtime: "iOS 26.5",
                transport: "usb",
                scope: "real",
                kind: "real-device",
                rawTarget: "00008110-001C195E0A10801E"
            ),
            selector: "ios-real:abc123",
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "ios-real:abc123", platform: .ios, scope: .real))
        )

        let iosLaunch = try planHostAppLaunch(selection: ios, bundleID: "com.example.demo", packageName: nil, activity: nil, bundle: nil, ability: nil, payloadURL: nil, adb: "adb", hdc: "hdc", devicectlArtifacts: ("/tmp/launch.json", "/tmp/launch.log"))
        #expect(iosLaunch.command.argv.contains("00008110-001C195E0A10801E"))
        #expect(iosLaunch.command.argv.contains("ios-real:abc123") == false)
        #expect(iosLaunch.target == "ios-real:abc123/app:com.example.demo")
        #expect(iosLaunch.runtimeScope == "host-ios-real-device")
        #expect(iosLaunch.note.contains("Host action was submitted"))

        let iosOpenURL = try planHostAppOpenURL(selection: ios, url: "demo://ready", bundleID: "com.example.demo", packageName: nil, bundle: nil, ability: nil, adb: "adb", hdc: "hdc", devicectlArtifacts: ("/tmp/open.json", "/tmp/open.log"))
        #expect(iosOpenURL.command.argv.contains("--payload-url"))
        #expect(iosOpenURL.command.argv.contains("demo://ready"))
        #expect(iosOpenURL.command.argv.contains("00008110-001C195E0A10801E"))

        let android = HostDeviceSelectionResult(
            platform: .android,
            target: HostDeviceTarget(
                platform: "android",
                id: "android-real:def456",
                target: "android-real:def456",
                state: "device",
                ready: true,
                source: "adb",
                name: "Pixel",
                runtime: "Android",
                transport: "usb",
                scope: "real",
                kind: "real-device",
                sensitive: true,
                rawTarget: "R58M1234ABC"
            ),
            selector: "android-real:def456",
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "android-real:def456", platform: .android, scope: .real))
        )
        let androidInstall = try planHostAppInstall(selection: android, app: nil, apk: "/tmp/Demo.apk", hap: nil, adb: "adb", hdc: "hdc", devicectlArtifacts: nil)
        #expect(androidInstall.command.argv == ["-s", "R58M1234ABC", "install", "-r", "/tmp/Demo.apk"])
        #expect(androidInstall.target == "android-real:def456")

        let harmony = HostDeviceSelectionResult(
            platform: .harmony,
            target: HostDeviceTarget(
                platform: "harmony",
                id: "harmony-real:fed789",
                target: "harmony-real:fed789",
                state: "Connected",
                ready: true,
                source: "hdc",
                name: nil,
                runtime: nil,
                transport: "USB",
                scope: "real",
                kind: "real-device",
                sensitive: true,
                rawTarget: "HDCREAL001"
            ),
            selector: "harmony-real:fed789",
            source: .explicit,
            filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "harmony-real:fed789", platform: .harmony, scope: .real))
        )
        let harmonyInfo = try planHostAppInfo(selection: harmony, bundleID: "com.example.demo", adb: "adb", hdc: "hdc", devicectlArtifacts: nil)
        #expect(harmonyInfo.command.argv == ["-t", "HDCREAL001", "shell", "bm", "dump", "-n", "com.example.demo"])
        #expect(harmonyInfo.target == "harmony-real:fed789/app:com.example.demo")

        let harmonyLaunch = try planHostAppLaunch(selection: harmony, bundleID: nil, packageName: nil, activity: nil, bundle: "com.example.demo", ability: "EntryAbility", payloadURL: nil, adb: "adb", hdc: "hdc", devicectlArtifacts: nil)
        #expect(harmonyLaunch.command.argv == ["-t", "HDCREAL001", "shell", "aa", "start", "-b", "com.example.demo", "-a", "EntryAbility"])
        #expect(harmonyLaunch.command.argv.contains("harmony-real:fed789") == false)
        #expect(harmonyLaunch.target == "harmony-real:fed789/app:com.example.demo")

        let harmonyOpenURL = try planHostAppOpenURL(selection: harmony, url: "demo://nativejump/index", bundleID: nil, packageName: nil, bundle: "com.example.demo", ability: "EntryAbility", adb: "adb", hdc: "hdc", devicectlArtifacts: nil)
        #expect(harmonyOpenURL.command.argv == ["-t", "HDCREAL001", "shell", "aa", "start", "-a", "EntryAbility", "-b", "com.example.demo", "-U", "demo://nativejump/index"])
        #expect(harmonyOpenURL.command.argv.contains("harmony-real:fed789") == false)
        #expect(harmonyOpenURL.target == "harmony-real:fed789/app:com.example.demo")
    }

    @Test("host app action output marks submission as non-business-ready evidence")
    func hostAppActionOutputMarksSubmissionEvidence() throws {
        let output = HostActionOutput(
            ok: true,
            action: "app.launch",
            runtimeScope: "host-android",
            target: "android-real:def456/app:com.example.demo",
            tool: "adb",
            exitCode: 0,
            riskLevel: "automation",
            sourceCommand: "adb -s '<redacted>' shell am start -n com.example.demo/.MainActivity",
            stdoutTruncated: false,
            stderrTruncated: false,
            stdout: nil,
            stderr: nil,
            artifacts: [],
            note: "submitted"
        )

        #expect(output.hostAction.ok)
        #expect(output.hostAction.proofSource == "host-action")
        #expect(output.hostAction.businessReady == false)
        #expect(output.hostAction.nextAction.command == "smoke")
        #expect(output.hostAction.nextAction.args.contains("--json"))
        #expect(output.suggestedCommands == ["triton smoke <platform> --device <selector> --json"])
    }

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
