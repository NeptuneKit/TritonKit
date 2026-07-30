import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SingleDeviceWebPageTests {
    @Test("single device web page has stable route and page markers")
    func singleDeviceWebPageHasStableRouteAndMarkers() {
        #expect(singleDeviceWebRootRoutePath == "/")
        #expect(singleDeviceWebRoutePath == "/web/device")
        #expect(singleDeviceWebSimulatorRoutePath == "/simulators/:id")

        let html = singleDeviceWebPageHTML()

        #expect(html.contains(#"data-triton-page="single-device-detail""#))
        #expect(html.contains("device-mirror-workbench"))
        #expect(html.contains("Baguette-like device mirror"))
        #expect(html.contains("fetchJSON('/status')"))
        #expect(html.contains("fetchJSON('/web/targets')"))
        #expect(html.contains("fetchJSON(`/web/geometry?target=${encodeURIComponent(target.id)}`"))
        #expect(html.contains("fetchBlob(`/web/screenshot?target=${encodeURIComponent(target.id)}"))
        #expect(!html.contains("fetchJSON(`/web/input?target=${encodeURIComponent(target.id)}`"))
        #expect(!html.contains("function sendInput("))
        #expect(!html.contains("action-control"))
        #expect(html.contains("Web mirror is readonly"))
        #expect(html.contains("readonly-badge"))
        #expect(!html.contains("preview and operate it here"))
        #expect(html.contains("triton act"))
        #expect(html.contains("targetPlatform"))
        #expect(html.contains("window.__TRITON_INITIAL_TARGET__"))
        #expect(html.contains("refreshInFlight"))
        #expect(html.contains("screenshotInFlight"))
        #expect(html.contains("new AbortController()"))
        #expect(html.contains("'Accept': 'image/png,image/jpeg'"))
        #expect(html.contains("runRefresh('poll')"))
    }

    @Test("single device web page renders Baguette style mirror chrome")
    func singleDeviceWebPageRendersBaguetteMirrorChrome() {
        let html = singleDeviceWebPageHTML()

        #expect(html.contains("mirror-toolbar"))
        #expect(html.contains("codec-switch"))
        #expect(html.contains("H.264"))
        #expect(html.contains("MJPEG"))
        #expect(html.contains("phone-shell"))
        #expect(html.contains("phone-screen"))
        #expect(html.contains("bottom-tool left"))
        #expect(html.contains("bottom-tool right"))
        #expect(html.contains("function platformLabel(target)"))
        #expect(html.contains("iOS Simulator"))
        #expect(html.contains("Android Emulator"))
        #expect(html.contains("Harmony / DevEco Emulator"))
    }

    @Test("single device web page selects an active target when multiple are connected")
    func singleDeviceWebPageSelectsActiveTarget() {
        let html = singleDeviceWebPageHTML()

        #expect(html.contains("function chooseTarget(targets)"))
        #expect(html.contains("targets.find(isActiveTarget)"))
        #expect(html.contains("selectTarget(target)"))
        #expect(html.contains("function targetMatchesSelector(target, selector)"))
        #expect(html.contains("state.preferredTargetSelector"))
        #expect(html.contains("if (state.preferredTargetSelector)"))
        #expect(html.contains("if (!preferred)"))
        #expect(html.contains("return null"))
        #expect(html.contains("setControlsEnabled(Boolean(target))"))
        #expect(html.contains("target-strip"))
        #expect(html.contains("target.platform || ''"))
    }

    @Test("single device web page can embed an initial simulator target selector")
    func singleDeviceWebPageEmbedsInitialSimulatorTargetSelector() {
        let html = singleDeviceWebPageHTML(initialTarget: "F4E55B8E-0141-4C46-9965-263CCE782B5F")

        #expect(html.contains(#"window.__TRITON_INITIAL_TARGET__ = "F4E55B8E-0141-4C46-9965-263CCE782B5F""#))
        #expect(html.contains("new URLSearchParams(location.search).get('target')"))
        #expect(html.contains("target.simulatorUDID === normalized"))
        #expect(html.contains("target.id.endsWith(`:${normalized}`)"))
    }

    @Test("web device targets prefer host simulator screenshots and keep runtime app identity")
    func webDeviceTargetsPreferHostSimulatorWithRuntimeIdentity() {
        let runtime = TKTargetSummary(
            id: "triton:ios-simulator:SIM-1",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "丁香园",
            bundleIdentifier: "cn.dxy.iDxyer",
            deviceDescription: "iPhone",
            osDescription: "iOS 26.5",
            simulatorUDID: "SIM-1",
            hierarchyCacheState: "active",
            platform: "ios"
        )
        let host = HostDeviceTarget(
            platform: "ios",
            id: "triton:ios-simulator:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone 16",
            runtime: "iOS 26.5",
            transport: nil,
            scope: "simulator",
            kind: "simulator"
        )

        let targets = webDeviceTargets(runtimeTargets: [runtime], hostTargets: [host])

        #expect(targets.count == 1)
        #expect(targets[0].id == "host:ios:SIM-1")
        #expect(targets[0].source == "host")
        #expect(targets[0].platform == "ios")
        #expect(targets[0].appName == "丁香园")
        #expect(targets[0].bundleIdentifier == "cn.dxy.iDxyer")
        #expect(targets[0].deviceDescription == "iPhone 16")
        #expect(targets[0].hierarchyCacheState == "active")
        #expect(targets[0].ready == true)
    }

    @Test("web device targets expose Android and Harmony host emulators")
    func webDeviceTargetsExposeAndroidAndHarmonyHostEmulators() {
        let android = HostDeviceTarget(
            platform: "android",
            id: "android-emulator:emulator-5554",
            target: "emulator-5554",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel_8",
            runtime: "sdk_gphone64_arm64",
            transport: "emulator",
            scope: "emulator",
            kind: "emulator"
        )
        let harmony = HostDeviceTarget(
            platform: "harmony",
            id: "harmony-emulator:127.0.0.1:5555",
            target: "127.0.0.1:5555",
            state: "Connected",
            ready: true,
            source: "hdc",
            name: nil,
            runtime: nil,
            transport: "tcp",
            scope: "emulator",
            kind: "emulator"
        )

        let targets = webDeviceTargets(runtimeTargets: [], hostTargets: [android, harmony])

        #expect(targets.map(\.id).contains("host:android:emulator-5554"))
        #expect(targets.map(\.id).contains("host:harmony:127.0.0.1:5555"))
        #expect(targets.first { $0.platform == "android" }?.scope == "emulator")
        #expect(targets.first { $0.platform == "harmony" }?.source == "host")
    }

    @Test("web target registry includes ready iOS real device without simulator fallback")
    func webTargetRegistryIncludesReadyIOSRealDeviceWithoutSimulatorFallback() throws {
        let simulatorRuntime = TKTargetSummary(
            id: "triton:ios-simulator:SIM-1",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Simulator App",
            simulatorUDID: "SIM-1",
            platform: "ios"
        )
        let realHost = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:73f725dfa795",
            target: "ios-real:73f725dfa795",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "iPhone",
            runtime: "iOS 26.5",
            transport: "wired",
            scope: "real",
            kind: "real-device"
        )

        let registry = makeWebTargetRegistry(
            runtimeTargets: [simulatorRuntime],
            hostTargets: [realHost],
            usbTunnelAdapterAvailable: false
        )
        let target = try #require(registry.targets.first { $0.id == "ios-real:73f725dfa795" })

        #expect(target.host?.target == "ios-real:73f725dfa795")
        #expect(target.host?.name == "iPhone")
        #expect(target.host?.runtime == "iOS 26.5")
        #expect(target.host?.scope == "real")
        #expect(target.host?.transport == "wired")
        #expect(target.runtime == nil)
        #expect(target.mirror.state == .runtimeNotFound)
        #expect(target.diagnosis?.code == .runtimeNotFound)
        #expect(target.nextAction?.code == "start_debug_app")
        #expect(target.transportDiagnostics.map(\.code) == [.iosUSBTunnelUnavailable])
    }

    @Test("web target registry omits USB tunnel diagnostic when adapter exists")
    func webTargetRegistryOmitsUSBTunnelDiagnosticWhenAdapterExists() throws {
        let realHost = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:73f725dfa795",
            target: "ios-real:73f725dfa795",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "iPhone",
            runtime: "iOS 26.5",
            transport: "wired",
            scope: "real",
            kind: "real-device"
        )

        let registry = makeWebTargetRegistry(
            runtimeTargets: [],
            hostTargets: [realHost],
            usbTunnelAdapterAvailable: true
        )
        let target = try #require(registry.targets.first { $0.id == "ios-real:73f725dfa795" })

        #expect(target.transportDiagnostics.isEmpty)
    }

    @Test("web iOS tunnel adapter detection checks PATH for iproxy")
    func webIOSTunnelAdapterDetectionChecksPathForIproxy() {
        #expect(webIOSTunnelAdapterAvailable(path: "/definitely/missing") == false)
    }

    @Test("web target registry keeps ready simulator independent from app runtime")
    func webTargetRegistryKeepsReadySimulatorIndependentFromAppRuntime() throws {
        let host = HostDeviceTarget(
            platform: "ios",
            id: "triton:ios-simulator:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone 17",
            runtime: "iOS 26.5",
            transport: nil,
            scope: "simulator",
            kind: "simulator"
        )

        let registry = makeWebTargetRegistry(runtimeTargets: [], hostTargets: [host])
        let target = try #require(registry.targets.first { $0.id == "host:ios:SIM-1" })

        #expect(target.mirror.state == .ready)
        #expect(target.diagnosis == nil)
        #expect(target.nextAction == nil)
        #expect(target.host?.target == "SIM-1")
    }

    @Test("web target registry exposes unified host input capabilities")
    func webTargetRegistryExposesUnifiedHostInputCapabilities() throws {
        let host = HostDeviceTarget(
            platform: "ios",
            id: "triton:ios-simulator:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone 17",
            runtime: "iOS 26.5",
            transport: "simctl",
            scope: "simulator",
            kind: "simulator"
        )

        let registry = makeWebTargetRegistry(runtimeTargets: [], hostTargets: [host])
        let target = try #require(registry.targets.first { $0.id == "host:ios:SIM-1" })
        let capabilities = target.inputCapabilities

        #expect(capabilities.contains(TKWebInputCapability(action: "tap", source: "host", supported: true)))
        #expect(capabilities.contains(TKWebInputCapability(action: "swipe", source: "host", supported: true)))
        #expect(capabilities.contains(TKWebInputCapability(action: "longPress", source: "host", supported: true)))
        #expect(capabilities.contains { capability in
            capability.action == "pinch" && capability.source == "host" && !capability.supported && capability.reason == "unsupported_capability"
        })
        #expect(capabilities.contains { capability in
            capability.action == "rotate" && capability.source == "host" && !capability.supported && capability.reason == "unsupported_capability"
        })
        #expect(capabilities.contains { capability in
            capability.action == "multiTouchPath" && capability.source == "host" && !capability.supported && capability.reason == "unsupported_capability"
        })
    }

    @Test("web target registry marks real-device runtime ambiguous across multiple ready hosts")
    func webTargetRegistryMarksRealDeviceRuntimeAmbiguousAcrossMultipleReadyHosts() throws {
        let runtime = TKTargetSummary(
            id: "triton:ios-real:session-1",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Real App",
            bundleIdentifier: "cn.example.real",
            platform: "ios"
        )
        let first = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:first",
            target: "ios-real:first",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "iPhone A",
            runtime: "iOS 26.5",
            transport: "wired",
            scope: "real",
            kind: "real-device"
        )
        let second = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:second",
            target: "ios-real:second",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "iPhone B",
            runtime: "iOS 26.5",
            transport: "wired",
            scope: "real",
            kind: "real-device"
        )

        let registry = makeWebTargetRegistry(runtimeTargets: [runtime], hostTargets: [first, second])
        let realHosts = registry.targets.filter { $0.kind == "real-device" }

        #expect(realHosts.count == 2)
        #expect(realHosts.allSatisfy { $0.runtime == nil })
        #expect(realHosts.allSatisfy { $0.diagnosis?.code == .ambiguousRuntimeTarget })
        #expect(realHosts.allSatisfy { $0.nextAction?.code == "select_runtime_target" })
        #expect(registry.targets.contains { $0.id == "triton:ios-real:session-1" && $0.kind == "embedded-runtime" })
    }

    @Test("web host target ids are parseable")
    func webHostTargetIDsAreParseable() throws {
        let parsed = try #require(parseWebHostTargetID("host:android:emulator-5554"))

        #expect(parsed.platform == .android)
        #expect(parsed.selector == "emulator-5554")
        #expect(parseWebHostTargetID("triton:ios-simulator:SIM-1") == nil)
    }

    @Test("iOS web host targets resolve directly from URL selector")
    func iOSWebHostTargetsResolveDirectlyFromURLSelector() throws {
        let resolved = try resolveWebHostDeviceTarget("host:ios:SIM-1", hdc: "/missing/hdc", adb: "/missing/adb")

        #expect(resolved.platform == .ios)
        #expect(resolved.target.target == "SIM-1")
        #expect(resolved.target.ready == true)
        #expect(resolved.target.scope == "simulator")
    }

    @Test("iOS web host input can still locate matching runtime targets when explicitly needed")
    func iOSWebHostInputCanStillLocateMatchingRuntimeTargetsWhenExplicitlyNeeded() {
        let runtime = TKTargetSummary(
            id: "triton:ios-simulator:SIM-1",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "丁香园",
            bundleIdentifier: "cn.dxy.iDxyer",
            simulatorUDID: "SIM-1",
            platform: "ios"
        )
        let disconnected = TKTargetSummary(
            id: "triton:ios-simulator:SIM-2",
            connected: false,
            latestHierarchyAvailable: true,
            appName: "Other",
            simulatorUDID: "SIM-2",
            platform: "ios"
        )

        #expect(webRuntimeInputFallbackTargetID(
            forHostID: "host:ios:SIM-1",
            runtimeTargets: [disconnected, runtime]
        ) == "triton:ios-simulator:SIM-1")
        #expect(webRuntimeInputFallbackTargetID(
            forHostID: "host:ios:SIM-2",
            runtimeTargets: [disconnected, runtime]
        ) == nil)
    }

    @Test("iOS real-device web runtime mirror ignores simulator runtime targets")
    func iOSRealDeviceWebRuntimeMirrorIgnoresSimulatorRuntimeTargets() {
        let simulator = TKTargetSummary(
            id: "triton:ios-simulator:SIM-1",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Simulator App",
            simulatorUDID: "SIM-1",
            platform: "ios"
        )
        let realDevice = TKTargetSummary(
            id: "triton:connection:2",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Overloaded",
            deviceDescription: "iPhone",
            osDescription: "iOS 26.5",
            platform: "ios"
        )

        #expect(webRuntimeInputFallbackTargetID(
            forHostID: "host:ios:ios-real:abc",
            runtimeTargets: [simulator, realDevice]
        ) == "triton:connection:2")
    }

    @Test("iOS web host input normalizes framebuffer coordinates into host HID points")
    func iOSWebHostInputNormalizesFramebufferCoordinatesIntoHostHIDPoints() {
        let normalized = normalizeWebIOSSimulatorInput(
            .tap(
                x: 619,
                y: 2338,
                width: 1206,
                height: 2622
            ),
            screen: WebIOSSimulatorScreenLayout(width: 400, height: 872)
        )

        #expect(normalized.x == 205)
        #expect(normalized.y == 778)
        #expect(normalized.width == 400)
        #expect(normalized.height == 872)
    }

    @Test("iOS web host tap keeps Baguette-compatible host HID argv behind Triton")
    func iOSWebHostTapKeepsBaguetteCompatibleHostHIDArgvBehindTriton() throws {
        let command = try webIOSBaguetteCommand(
            action: .tap(x: 603, y: 1311, width: 1206, height: 2622),
            udid: "SIM-1",
            screen: WebIOSSimulatorScreenLayout(width: 400, height: 872),
            executable: "/opt/homebrew/bin/baguette"
        )

        #expect(command.executable == "/opt/homebrew/bin/baguette")
        #expect(command.arguments == [
            "tap",
            "--udid", "SIM-1",
            "--x", "200",
            "--y", "436",
            "--width", "400",
            "--height", "872"
        ])
    }

    @Test("iOS web host swipe builds a complete touch lifecycle for vertical pagers")
    func iOSWebHostSwipeBuildsCompleteTouchLifecycleForVerticalPagers() throws {
        let lifecycle = try webIOSBaguetteSwipeLifecycle(
            input: .swipe(
                startX: 201,
                startY: 700,
                endX: 201,
                endY: 200,
                width: 402,
                height: 874,
                duration: 0.35
            ),
            udid: "SIM-1",
            screen: WebIOSSimulatorScreenLayout(width: 402, height: 874),
            executable: "/opt/homebrew/bin/baguette"
        )

        #expect(Array(lifecycle.command.arguments.suffix(3)) == ["input", "--udid", "SIM-1"])
        #expect(lifecycle.duration == 0.35)
        #expect(abs(lifecycle.cadence - (0.35 / 11)) < 0.000_001)
        #expect(lifecycle.terminalLinger >= 0.1)
        #expect(lifecycle.events.first == WebIOSBaguetteTouchEvent(type: "touch1-down", x: 201, y: 700, width: 402, height: 874))
        #expect(lifecycle.events.last == WebIOSBaguetteTouchEvent(type: "touch1-up", x: 201, y: 200, width: 402, height: 874))
        #expect(lifecycle.events.dropFirst().dropLast().allSatisfy { $0.type == "touch1-move" })

        var pagerState = "idle"
        for event in lifecycle.events.dropLast() {
            pagerState = event.type == "touch1-down" ? "interactive" : pagerState
        }
        #expect(pagerState == "interactive", "down/move without terminal up reproduces the stuck UIPageViewController state")
        if lifecycle.events.last?.type == "touch1-up" {
            pagerState = "settled"
        }
        #expect(pagerState == "settled")
    }

    @Test("iOS web host swipe runner requires every lifecycle ack including terminal up")
    func iOSWebHostSwipeRunnerRequiresEveryLifecycleAckIncludingTerminalUp() throws {
        let lifecycle = try webIOSBaguetteSwipeLifecycle(
            input: .swipe(
                startX: 200,
                startY: 700,
                endX: 200,
                endY: 180,
                width: 400,
                height: 872,
                duration: 0.35
            ),
            udid: "SIM-1",
            screen: WebIOSSimulatorScreenLayout(width: 400, height: 872),
            executable: "/fake/baguette"
        )
        let missingTerminalAck = Array(repeating: #"{"ok":true}"#, count: lifecycle.events.count - 1)
            .joined(separator: "\n") + "\n"

        #expect(throws: (any Error).self) {
            _ = try runWebIOSBaguetteLifecycle(lifecycle) { fakeLifecycle in
                HostProcessResult(
                    stdoutData: Data(missingTerminalAck.utf8),
                    stderrData: Data(),
                    exitCode: 0,
                    sourceCommand: hostSourceCommand(fakeLifecycle.command),
                    stdoutTruncated: false,
                    stderrTruncated: false,
                    stdoutLogPath: nil,
                    stderrLogPath: nil,
                    stdoutBytes: missingTerminalAck.utf8.count,
                    stderrBytes: 0
                )
            }
        }
    }

    @Test("iOS web host swipe default runner keeps one session alive through terminal flush")
    func iOSWebHostSwipeDefaultRunnerKeepsOneSessionAliveThroughTerminalFlush() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-fake-baguette-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("baguette").path
        let log = directory.appendingPathComponent("events.log").path
        let script = """
        #!/bin/sh
        printf 'pid:%s\\n' "$$" >> "\(log)"
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> "\(log)"
          printf '%s\\n' '{"ok":true}'
        done
        """
        try script.write(toFile: executable, atomically: true, encoding: .utf8)
        chmod(executable, S_IRWXU)

        let lifecycle = try webIOSBaguetteSwipeLifecycle(
            input: .swipe(
                startX: 200,
                startY: 700,
                endX: 200,
                endY: 180,
                width: 400,
                height: 872,
                duration: 0.11
            ),
            udid: "SIM-1",
            screen: WebIOSSimulatorScreenLayout(width: 400, height: 872),
            executable: executable
        )
        let started = Date()
        let result = try runWebIOSBaguetteLifecycle(lifecycle)
        let elapsed = Date().timeIntervalSince(started)
        let lines = try String(contentsOfFile: log, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        let events = try lines.dropFirst().map {
            try JSONDecoder().decode(WebIOSBaguetteTouchEvent.self, from: Data($0.utf8))
        }

        #expect(result.exitCode == 0)
        #expect(lines.filter { $0.hasPrefix("pid:") }.count == 1)
        #expect(events == lifecycle.events)
        #expect(elapsed >= lifecycle.duration + lifecycle.terminalLinger)
    }

    @Test("iOS web host long press uses same-point host HID swipe")
    func iOSWebHostLongPressUsesSamePointHostHIDSwipe() throws {
        let command = try webIOSBaguetteCommand(
            action: .longPress(
                x: 600,
                y: 1200,
                width: 1200,
                height: 2400,
                duration: 0.7
            ),
            udid: "SIM-1",
            screen: WebIOSSimulatorScreenLayout(width: 400, height: 800),
            executable: "/opt/homebrew/bin/baguette"
        )

        #expect(command.executable == "/opt/homebrew/bin/baguette")
        #expect(command.arguments == [
            "swipe",
            "--udid", "SIM-1",
            "--start-x", "200",
            "--start-y", "400",
            "--end-x", "200",
            "--end-y", "400",
            "--width", "400",
            "--height", "800",
            "--duration", "0.7"
        ])
    }

    @Test("non iOS web host input does not use runtime fallback")
    func nonIOSWebHostInputDoesNotUseRuntimeFallback() {
        let androidRuntime = TKTargetSummary(
            id: "triton:android-emulator:emulator-5554",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Android",
            deviceDescription: "emulator-5554",
            platform: "android"
        )

        #expect(webRuntimeInputFallbackTargetID(
            forHostID: "host:android:emulator-5554",
            runtimeTargets: [androidRuntime]
        ) == nil)
        #expect(webRuntimeInputFallbackTargetID(
            forHostID: "host:harmony:127.0.0.1:5555",
            runtimeTargets: []
        ) == nil)
    }

    @Test("Harmony web host long press is submitted as same-point uitest swipe")
    func harmonyWebHostLongPressIsSubmittedAsSamePointUITestSwipe() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-fake-hdc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let hdc = directory.appendingPathComponent("hdc").path
        let log = directory.appendingPathComponent("commands.log").path
        let script = """
        #!/bin/sh
        printf '%s\\n' "$*" >> "\(log)"
        if [ "$1 $2 $3" = "list targets -v" ]; then
          printf '%s\\n' "127.0.0.1:10100        TCP     Connected       localhost"
          exit 0
        fi
        exit 0
        """
        try script.write(toFile: hdc, atomically: true, encoding: .utf8)
        chmod(hdc, S_IRWXU)

        let result = try runWebHostDeviceInput(
            id: "host:harmony:127.0.0.1:10100",
            input: .longPress(x: 120, y: 640, duration: 0.7),
            hdc: hdc,
            adb: "/missing/adb"
        )
        let commands = try String(contentsOfFile: log, encoding: .utf8)

        #expect(result.ok == true)
        #expect(result.action == "longPress")
        #expect(commands.contains("-t 127.0.0.1:10100 shell uitest uiInput swipe 120 640 120 640 200"))
    }

    @Test("web host screenshots expose platform image formats")
    func webHostScreenshotsExposePlatformImageFormats() {
        #expect(webHostDeviceScreenshotFileExtension(for: .ios) == "png")
        #expect(webHostDeviceScreenshotFileExtension(for: .android) == "png")
        #expect(webHostDeviceScreenshotFileExtension(for: .harmony) == "jpeg")

        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        let unknown = Data("not-image".utf8)

        #expect(webHostDeviceImageContentType(png) == "image/png")
        #expect(webHostDeviceImageContentType(jpeg) == "image/jpeg")
        #expect(webHostDeviceImageContentType(unknown) == "application/octet-stream")
    }

    @Test("web host geometry can be built without recapturing screenshots")
    func webHostGeometryCanBeBuiltWithoutRecapturingScreenshots() throws {
        let geometry = try webHostGeometryResponse(width: 1206, height: 2622)

        #expect(geometry.bounds.width == 1206)
        #expect(geometry.bounds.height == 2622)
        #expect(geometry.safeArea.top == 0)
        #expect(geometry.scale == 1)
        #expect(geometry.orientation == "portrait")

        let landscape = try webHostGeometryResponse(width: 2400, height: 1080)
        #expect(landscape.orientation == "landscape")
    }

    @Test("Android wm size parser accepts physical and override sizes")
    func androidWMSizeParserAcceptsPhysicalAndOverrideSizes() throws {
        let physical = try #require(TKAndroidWMSizeParser.parse("Physical size: 1080x2400\n"))
        #expect(physical.width == 1080)
        #expect(physical.height == 2400)

        let override = try #require(TKAndroidWMSizeParser.parse("""
        Override size: 720x1600
        Physical size: 1080x2400
        """))
        #expect(override.width == 720)
        #expect(override.height == 1600)
    }

    @Test("Harmony DevEco profile geometry parses lcd single size")
    func harmonyDevEcoProfileGeometryParsesLCDSingleSize() throws {
        let profile = """
        name=Codex Test Phone
        hw.lcd.single.height=2880
        hw.lcd.single.width=1308
        """

        let geometry = try #require(webHarmonyGeometryFromProfile(profile))

        #expect(geometry.bounds.width == 1308)
        #expect(geometry.bounds.height == 2880)
        #expect(geometry.orientation == "portrait")
    }
}
