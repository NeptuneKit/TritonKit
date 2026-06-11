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
        #expect(html.contains("fetchJSON(`/web/input?target=${encodeURIComponent(target.id)}`"))
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

    @Test("iOS web host input falls back to embedded runtime on same simulator")
    func iOSWebHostInputFallsBackToEmbeddedRuntimeOnSameSimulator() {
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
