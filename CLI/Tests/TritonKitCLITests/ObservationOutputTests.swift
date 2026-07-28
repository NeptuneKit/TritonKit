import CoreGraphics
import Foundation
import ImageIO
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct ObservationOutputTests {
    @Test("runtime screenshot artifact requires PNG extension metadata and magic bytes")
    func runtimeScreenshotArtifactRequiresConsistentPNGContract() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])

        #expect(try validateRuntimeScreenshotArtifact(
            png,
            declaredFormat: "png",
            outputPath: "/tmp/runtime-shot.png"
        ) == "png")

        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        #expect(throws: RuntimeScreenshotArtifactError.self) {
            try validateRuntimeScreenshotArtifact(
                jpeg,
                declaredFormat: "jpeg",
                outputPath: "/tmp/runtime-shot.png"
            )
        }
        #expect(throws: RuntimeScreenshotArtifactError.self) {
            try validateRuntimeScreenshotArtifact(
                png,
                declaredFormat: "jpeg",
                outputPath: "/tmp/runtime-shot.png"
            )
        }
        #expect(throws: RuntimeScreenshotArtifactError.self) {
            try validateRuntimeScreenshotArtifact(
                png,
                declaredFormat: "png",
                outputPath: "/tmp/runtime-shot.jpeg"
            )
        }
        #expect(try normalizeRuntimeScreenshotToPNG(
            png,
            declaredFormat: "png",
            outputPath: "/tmp/runtime-shot.png"
        ) == png)
    }

    @Test("legacy JPEG runtime screenshots normalize to a real PNG artifact")
    func legacyJPEGRuntimeScreenshotNormalizesToPNG() throws {
        let jpeg = try makeValidJPEGFixture()

        let normalized = try normalizeRuntimeScreenshotToPNG(
            jpeg,
            declaredFormat: "jpeg",
            outputPath: "/tmp/runtime-shot.png"
        )

        #expect(normalized.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        #expect(try validateRuntimeScreenshotArtifact(
            normalized,
            declaredFormat: "png",
            outputPath: "/tmp/runtime-shot.png"
        ) == "png")
        #expect(throws: RuntimeScreenshotArtifactError.self) {
            try normalizeRuntimeScreenshotToPNG(
                jpeg,
                declaredFormat: "jpeg",
                outputPath: "/tmp/runtime-shot.jpeg"
            )
        }
    }

    @Test("runtime screenshot normalizer rejects malformed JPEG bytes without an artifact")
    func runtimeScreenshotNormalizerRejectsMalformedJPEG() {
        let malformedJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])

        #expect(throws: RuntimeScreenshotNormalizationError.self) {
            try normalizeRuntimeScreenshotToPNG(
                malformedJPEG,
                declaredFormat: "jpeg",
                outputPath: "/tmp/runtime-shot.png"
            )
        }
    }

    @Test("runtime screenshot mismatch maps to stable artifact failure")
    func runtimeScreenshotMismatchMapsToArtifactFailure() {
        let detail = cliErrorDetail(
            for: RuntimeScreenshotArtifactError(
                declaredFormat: "jpeg",
                detectedFormat: "jpeg",
                outputExtension: "png"
            ),
            endpoint: "/request",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(detail.code == "artifact_write_failed")
        #expect(detail.message.contains("JPEG"))
        #expect(detail.hint?.contains("embedded runtime") == true)
    }

    @Test("runtime screenshot decode failure maps to stable artifact failure")
    func runtimeScreenshotDecodeFailureMapsToArtifactFailure() {
        let detail = cliErrorDetail(
            for: RuntimeScreenshotNormalizationError(
                sourceFormat: "jpeg",
                reason: "the payload could not be decoded"
            ),
            endpoint: "/request",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(detail.code == "artifact_write_failed")
        #expect(detail.message.contains("JPEG"))
        #expect(detail.hint?.contains("no artifact was published") == true)
    }

    @Test("serve screenshot preserves screenshot normalization failure diagnostics")
    func serveScreenshotPreservesNormalizationFailureDiagnostics() {
        let artifactDetail = serveScreenshotPayloadErrorDetail(
            for: RuntimeScreenshotArtifactError(
                declaredFormat: "jpeg",
                detectedFormat: "png",
                outputExtension: "png"
            ),
            endpoint: "/screenshot",
            host: "127.0.0.1",
            port: 19421
        )
        let decodeDetail = serveScreenshotPayloadErrorDetail(
            for: RuntimeScreenshotNormalizationError(
                sourceFormat: "jpeg",
                reason: "the payload could not be decoded"
            ),
            endpoint: "/screenshot",
            host: "127.0.0.1",
            port: 19421
        )
        let invalidPayloadDetail = serveScreenshotPayloadErrorDetail(
            for: RuntimeError("Invalid screenshot image data"),
            endpoint: "/screenshot",
            host: "127.0.0.1",
            port: 19421
        )

        #expect(artifactDetail.code == "artifact_write_failed")
        #expect(decodeDetail.code == "artifact_write_failed")
        #expect(artifactDetail.endpoint == "http://127.0.0.1:19421/screenshot")
        #expect(decodeDetail.hint?.contains("no artifact was published") == true)
        #expect(invalidPayloadDetail.code == "invalid_payload")
    }

    @Test("observe output prioritizes runtime tree as primary source")
    func observeOutputPrioritizesRuntimeTree() {
        let output = ObserveOutput(
            ok: true,
            action: "observe.current",
            platform: "ios",
            capturedAt: "2026-05-31T00:00:00Z",
            partial: true,
            target: "triton:ios-simulator:demo",
            sources: [
                ObserveSourceOutput(name: "host-layout", available: false, reason: "unsupported", artifact: nil, sourceCommands: []),
                ObserveSourceOutput(name: "runtime-tree", available: true, reason: nil, artifact: nil, sourceCommands: ["triton runtimeSnapshot request"]),
                ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
            ],
            nodes: [],
            artifacts: [],
            sourceCommands: ["triton runtimeSnapshot request"],
            note: "runtime-first"
        )

        #expect(output.primarySource?.name == "runtime-tree")
        #expect(output.primarySource?.available == true)
    }

    @Test("observe output falls back to host layout when runtime tree is unavailable")
    func observeOutputFallsBackToHostLayout() {
        let output = ObserveOutput(
            ok: true,
            action: "observe.current",
            platform: "harmony",
            capturedAt: "2026-05-31T00:00:00Z",
            partial: true,
            target: "harmony:127.0.0.1:10100",
            sources: [
                ObserveSourceOutput(name: "host-layout", available: true, reason: nil, artifact: "/tmp/layout.json", sourceCommands: ["hdc dumpLayout"]),
                ObserveSourceOutput(name: "runtime-tree", available: false, reason: "runtime-base-url not provided", artifact: nil, sourceCommands: []),
                ObserveSourceOutput(name: "webview-provider", available: false, reason: "provider not registered", artifact: nil, sourceCommands: []),
            ],
            nodes: [],
            artifacts: ["/tmp/layout.json"],
            sourceCommands: ["hdc dumpLayout"],
            note: "host-layout-only"
        )

        #expect(output.primarySource?.name == "host-layout")
        #expect(output.primarySource?.artifact == "/tmp/layout.json")
    }

    @Test("observe output preserves explicit primary source override")
    func observeOutputPreservesExplicitPrimarySource() {
        let primary = ObserveSourceOutput(
            name: "webview-provider",
            available: true,
            reason: nil,
            artifact: nil,
            sourceCommands: ["triton webview current --json"]
        )
        let output = ObserveOutput(
            ok: true,
            action: "observe.current",
            platform: "ios",
            capturedAt: "2026-05-31T00:00:00Z",
            partial: false,
            target: "triton:ios-simulator:demo",
            primarySource: primary,
            sources: [
                ObserveSourceOutput(name: "host-layout", available: false, reason: "unsupported", artifact: nil, sourceCommands: []),
                ObserveSourceOutput(name: "runtime-tree", available: true, reason: nil, artifact: nil, sourceCommands: ["triton runtimeSnapshot request"]),
                primary,
            ],
            nodes: [],
            artifacts: [],
            sourceCommands: ["triton runtimeSnapshot request"],
            note: "explicit"
        )

        #expect(output.primarySource?.name == "webview-provider")
        #expect(output.primarySource?.sourceCommands == ["triton webview current --json"])
    }

    @Test("iOS host AX observe output uses simulator AX as host layout source")
    func iosHostAXObserveOutputUsesHostLayoutSource() {
        let root = TKAXNode(
            role: "AXWindow",
            label: "Main",
            value: nil,
            identifier: nil,
            title: nil,
            frame: TKRect(x: 0, y: 0, width: 393, height: 852),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: nil,
            className: nil,
            children: [
                TKAXNode(
                    role: "AXButton",
                    label: "Login",
                    value: nil,
                    identifier: "login-button",
                    title: nil,
                    frame: TKRect(x: 24, y: 120, width: 180, height: 44),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: nil,
                    className: nil,
                    children: []
                ),
            ]
        )

        let output = observeIOSHostAXOutput(
            action: "observe.tree",
            target: "ABC-123",
            root: root,
            maxNodes: nil,
            capturedAt: "2026-07-06T00:00:00Z"
        )

        #expect(output.ok)
        #expect(output.platform == "ios")
        #expect(output.target == "sim:ABC-123")
        #expect(output.primarySource?.name == "host-layout")
        #expect(output.primarySource?.sourceCommands == ["triton sim ax --device ABC-123 --json"])
        #expect(output.sources.first { $0.name == "runtime-tree" }?.available == false)
        #expect(output.nodes.count == 2)
        #expect(output.nodes[0].nodeID == "ios-host:1")
        #expect(output.nodes[1].source == "host-layout")
        #expect(output.nodes[1].text == "Login")
        #expect(output.nodes[1].identifier == "login-button")
        #expect(output.nodes[1].capabilities.contains("tap"))
    }

    @Test("iOS host AX observe output respects max nodes")
    func iosHostAXObserveOutputRespectsMaxNodes() {
        let root = TKAXNode(
            role: "AXWindow",
            label: nil,
            value: nil,
            identifier: nil,
            title: nil,
            frame: TKRect(x: 0, y: 0, width: 393, height: 852),
            enabled: true,
            focused: false,
            hidden: false,
            targetOID: nil,
            className: nil,
            children: [
                TKAXNode(
                    role: "AXStaticText",
                    label: "Child",
                    value: nil,
                    identifier: nil,
                    title: nil,
                    frame: TKRect(x: 10, y: 10, width: 80, height: 20),
                    enabled: true,
                    focused: false,
                    hidden: false,
                    targetOID: nil,
                    className: nil,
                    children: []
                ),
            ]
        )

        let output = observeIOSHostAXOutput(
            action: "observe.current",
            target: "ABC-123",
            root: root,
            maxNodes: 1,
            capturedAt: "2026-07-06T00:00:00Z"
        )

        #expect(output.nodes.count == 1)
        #expect(output.nodes[0].role == "AXWindow")
    }

    @Test("iOS host AX is enabled only for simulator host targets")
    func iosHostAXIsEnabledOnlyForSimulatorHostTargets() {
        let simulator = HostDeviceTarget(
            platform: "ios",
            id: "sim:ABC-123",
            target: "ABC-123",
            state: "Booted",
            ready: true,
            source: "simctl",
            name: "iPhone",
            runtime: "iOS 26.0",
            transport: nil,
            scope: "simulator",
            kind: "simulator"
        )
        let realDevice = HostDeviceTarget(
            platform: "ios",
            id: "ios-device:ABC-123",
            target: "ABC-123",
            state: "available",
            ready: true,
            source: "devicectl",
            name: "iPhone",
            runtime: "iOS 26.0",
            transport: nil,
            scope: "real",
            kind: "device"
        )

        #expect(usesIOSHostSimulatorAX(simulator))
        #expect(!usesIOSHostSimulatorAX(realDevice))
        #expect(!usesIOSHostSimulatorAX(nil))
    }

    @Test("android observe tree decodes UIAutomator XML into host layout nodes")
    func androidObserveTreeDecodesUIAutomatorXML() async throws {
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel_8",
            runtime: "sdk_gphone64_arm64",
            transport: "1"
        )
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("android-observe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let artifactPath = temp.appendingPathComponent("window.xml").path

        let output = try observeAndroid(
            action: "observe.tree",
            selected: target,
            output: artifactPath,
            runner: { command in
                let fixture = try TKAndroidADBFakeRunner(fixtures: [
                    .uiautomatorDump(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml"),
                    .readFileXML(serial: "emulator-5554", remotePath: "/sdcard/window_dump.xml")
                ]).run(command)
                return HostProcessResult(
                    stdoutData: fixture.stdout,
                    stderrData: fixture.stderr,
                    exitCode: fixture.exitCode,
                    sourceCommand: hostSourceCommand(command),
                    stdoutTruncated: false,
                    stderrTruncated: false,
                    stdoutLogPath: nil,
                    stderrLogPath: nil,
                    stdoutBytes: fixture.stdout.count,
                    stderrBytes: fixture.stderr.count
                )
            }
        )

        #expect(output.ok)
        #expect(output.platform == "android")
        #expect(output.primarySource?.name == "host-layout")
        #expect(output.sources.first?.artifact == artifactPath)
        #expect(output.artifacts == [artifactPath])
        #expect(output.nodes.count == 2)
        #expect(output.nodes[1].text == "Login")
        #expect(output.nodes[1].identifier == "com.example.demo:id/login")
        #expect(output.nodes[1].role == "android.widget.Button")
        #expect(output.nodes[1].capabilities.contains("tap"))
        #expect(FileManager.default.fileExists(atPath: artifactPath))
    }

    @Test("android observe tree prefers bridge tree when available")
    func androidObserveTreePrefersBridgeTreeWhenAvailable() throws {
        let target = HostDeviceTarget(
            platform: "android",
            id: "android:emulator-5554",
            target: "emulator-5554",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel_8",
            runtime: "sdk_gphone64_arm64",
            transport: "1"
        )
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("android-bridge-observe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let artifactPath = temp.appendingPathComponent("bridge-tree.json").path
        let tree = """
        {"status":"success","result":{"resourceId":"android:id/content","uniqueId":"root","package":"com.example.demo","className":"android.widget.FrameLayout","text":"","contentDescription":"","boundsInScreen":{"left":0,"top":0,"right":240,"bottom":320},"clickable":false,"scrollable":false,"focused":false,"enabled":true,"visibleToUser":true,"children":[{"resourceId":"com.example.demo:id/login","uniqueId":"login","package":"com.example.demo","className":"android.widget.Button","text":"Login","contentDescription":"Login button","boundsInScreen":{"left":24,"top":120,"right":216,"bottom":192},"clickable":true,"scrollable":false,"focused":false,"enabled":true,"visibleToUser":true,"children":[]}]}}
        """

        let output = try observeAndroid(
            action: "observe.tree",
            selected: target,
            output: artifactPath,
            runner: { command in
                if command.arguments.contains(where: { $0.contains("auth_token") }) {
                    return successfulObservationHostProcessResult(command, stdout: "Row: 0 result={\"status\":\"success\",\"result\":\"token-123\"}\n")
                }
                if command.executable == "/usr/bin/curl" {
                    return successfulObservationHostProcessResult(command, stdout: tree)
                }
                throw RuntimeError("unexpected command: \(hostSourceCommand(command))")
            }
        )

        #expect(output.ok)
        #expect(output.primarySource?.name == "android-bridge")
        #expect(output.nodes.count == 2)
        #expect(output.nodes[1].source == "android-bridge")
        #expect(output.nodes[1].text == "Login")
        #expect(output.nodes[1].identifier == "com.example.demo:id/login")
        #expect(output.nodes[1].frame == TKRect(x: 24, y: 120, width: 192, height: 72))
        #expect(output.nodes[1].capabilities.contains("tap"))
        #expect(output.sourceCommands.contains { $0.contains("Bearer <redacted>") })
        #expect(FileManager.default.fileExists(atPath: artifactPath))
    }

    @Test("observe outline assigns deterministic aliases to actionable visible nodes")
    func observeOutlineAssignsDeterministicAliases() {
        let nodes = [
            observationNode(nodeID: "root", role: "AXWindow", text: nil, identifier: nil, hidden: false, capabilities: []),
            observationNode(nodeID: "settings", role: "AXButton", text: "Settings", identifier: "settings-button", hidden: false, capabilities: ["tap"]),
            observationNode(nodeID: "hidden", role: "AXButton", text: "Hidden", identifier: nil, hidden: true, capabilities: ["tap"]),
            observationNode(nodeID: "about", role: "AXStaticText", text: nil, identifier: "about-row", hidden: false, capabilities: []),
        ]

        let outline = makeObserveNodeOutline(from: nodes)

        #expect(outline.map(\.alias) == ["@1", "@2"])
        #expect(outline.map(\.nodeID) == ["settings", "about"])
        #expect(outline[0].text == "Settings")
        #expect(outline[0].capabilities == ["tap"])
        #expect(outline[1].identifier == "about-row")
    }

    @Test("node alias cache resolves matching target and rejects stale target")
    func nodeAliasCacheResolvesAndRejectsStaleTarget() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-node-alias-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = ObserveOutput(
            ok: true,
            action: "observe.tree",
            platform: "ios",
            capturedAt: "2026-07-06T00:00:00Z",
            partial: true,
            target: "sim:ABC",
            sources: [
                ObserveSourceOutput(name: "host-layout", available: true, reason: nil, artifact: nil, sourceCommands: ["triton sim ax --device ABC --json"])
            ],
            nodes: [
                observationNode(nodeID: "settings", role: "AXButton", text: "Settings", identifier: "settings-button", hidden: false, capabilities: ["tap"])
            ],
            artifacts: [],
            sourceCommands: ["triton sim ax --device ABC --json"],
            note: "host AX"
        )
        let cache = makeNodeAliasCache(from: source, outline: makeObserveNodeOutline(from: source.nodes))
        let path = try saveNodeAliasCache(cache, workspace: temp.path)

        let resolved = try resolveNodeAlias("@1", platform: "ios", target: "sim:ABC", workspace: temp.path)

        #expect(path.hasSuffix(".triton/node-aliases.json"))
        #expect(resolved.ok)
        #expect(resolved.query == "@1")
        #expect(resolved.node.nodeID == "settings")
        #expect(resolved.sourceCommands == ["triton sim ax --device ABC --json"])
        #expect(throws: NodeAliasResolutionError.self) {
            _ = try resolveNodeAlias("@1", platform: "ios", target: "sim:DEF", workspace: temp.path)
        }
    }
}

private func makeValidJPEGFixture() throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw RuntimeError("Unable to construct JPEG test bitmap")
    }
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    guard let image = context.makeImage() else {
        throw RuntimeError("Unable to construct JPEG test image")
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData,
        "public.jpeg" as CFString,
        1,
        nil
    ) else {
        throw RuntimeError("Unable to construct JPEG test encoder")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw RuntimeError("Unable to encode JPEG test image")
    }
    return data as Data
}

private func successfulObservationHostProcessResult(_ command: TKHostCommand, stdout: String = "") -> HostProcessResult {
    let stdoutData = Data(stdout.utf8)
    return HostProcessResult(
        stdoutData: stdoutData,
        stderrData: Data(),
        exitCode: 0,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: false,
        stderrTruncated: false,
        stdoutLogPath: nil,
        stderrLogPath: nil,
        stdoutBytes: stdoutData.count,
        stderrBytes: 0
    )
}

private func observationNode(
    nodeID: String,
    role: String?,
    text: String?,
    identifier: String?,
    hidden: Bool?,
    capabilities: [String]
) -> ObserveNodeOutput {
    ObserveNodeOutput(
        nodeID: nodeID,
        source: "host-layout",
        role: role,
        text: text,
        identifier: identifier,
        frame: nil,
        enabled: true,
        focused: false,
        hidden: hidden,
        candidateOnly: false,
        confidence: 1,
        capabilities: capabilities,
        missingCapabilities: []
    )
}
