import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct EvidenceBundleTests {
    @Test("evidence capture propagates explicit target to nested runtime artifact requests")
    func evidenceCapturePropagatesExplicitTargetToNestedRuntimeArtifactRequests() async throws {
        let expectedTarget = "triton:ios-simulator:SIM-2"
        let fakeServer = EvidenceTargetPropagationFakeServer(expectedTarget: expectedTarget)
        defer { fakeServer.stop() }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("evidence-target-propagation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["list", "hierarchy", "ax", "screenshot", "geometry", "archive"],
            name: "target-propagation",
            note: nil,
            target: expectedTarget,
            host: fakeServer.host,
            port: fakeServer.port,
            refresh: true
        )

        #expect(manifest.target?.id == expectedTarget)
        #expect(manifest.skipped.isEmpty)
        #expect(manifest.artifacts.map(\.kind).contains("hierarchy"))
        #expect(manifest.artifacts.map(\.kind).contains("ax"))
        #expect(manifest.artifacts.map(\.kind).contains("screenshot"))
        #expect(manifest.artifacts.map(\.kind).contains("geometry"))
        #expect(manifest.artifacts.map(\.kind).contains("archive"))
        #expect(fakeServer.requestTargets.allSatisfy { $0 == expectedTarget })
        #expect(fakeServer.requestTypes.contains("hierarchy"))
        #expect(fakeServer.requestTypes.contains("accessibility"))
        #expect(fakeServer.requestTypes.contains("screenshot"))
        #expect(fakeServer.requestTypes.contains("geometry"))
    }

    @Test("schema exposes explicit xcode summary evidence import option")
    func schemaExposesExplicitXcodeSummaryEvidenceImportOption() throws {
        let evidence = try #require(commandSchemas().first { $0.name == "evidence" })
        let capture = try #require(commandSchemas().first { $0.name == "capture" })

        #expect(evidence.options.map { $0.name }.contains("--xcode-summary"))
        #expect(capture.options.map { $0.name }.contains("--xcode-summary"))
        #expect(evidence.examples.contains { $0.contains("--xcode-summary") })
    }

    @Test("evidence capture writes host and xcode read-only artifacts without runtime")
    func captureWritesHostAndXcodeReadOnlyArtifactsWithoutRuntime() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-host-xcode-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try parseEvidenceIncludes("host,xcode") == ["host", "xcode"])

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: {
                TKHostWorkspaceDefaults(
                    defaultSimulatorUDID: "SIM-1",
                    xcode: TKXcodeWorkspaceDefaults(
                        workspace: "App.xcworkspace",
                        project: nil,
                        scheme: "App",
                        configuration: "Debug",
                        sdk: "iphonesimulator",
                        destination: "platform=iOS Simulator,id=SIM-1",
                        derivedDataPath: ".triton/DerivedData"
                    )
                )
            },
            simulatorList: {
                EvidenceArtifactPayload(
                    data: Data(#"{"devices":{}}"#.utf8),
                    sourceCommand: "xcrun simctl list devices available --json"
                )
            },
            xcodeStatus: {
                EvidenceArtifactPayload(
                    data: try prettyEncodedData(XcodeProcessStatusOutput(
                        ok: true,
                        active: false,
                        workspaceFilter: nil,
                        processes: [],
                        summary: XcodeProcessStatusSummary(
                            xcodebuildCount: 0,
                            buildServiceCount: 0,
                            xctestCount: 0,
                            matchingWorkspaceCount: 0
                        ),
                        sourceCommand: "pgrep -f xcodebuild"
                    )),
                    sourceCommand: "pgrep -f xcodebuild"
                )
            },
            xcodeDiscovery: {
                EvidenceArtifactPayload(
                    data: Data(#"{"ok":true,"workspaces":[],"projects":[],"packages":[]}"#.utf8),
                    sourceCommand: "triton xcode discover --path . --json"
                )
            }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["host", "xcode"],
            name: "host-xcode-contract",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            hostXcodeProviders: providers
        )

        #expect(manifest.artifacts.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.defaults",
            "xcode.status",
            "xcode.discovery",
        ])
        #expect(manifest.primaryArtifacts.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.status",
            "xcode.discovery",
            "xcode.defaults",
        ])
        #expect(manifest.artifacts.allSatisfy { !$0.path.hasPrefix("/") && !$0.path.contains("..") })
        #expect(manifest.artifacts.allSatisfy { $0.riskLevel == "readonly" })
        #expect(manifest.artifacts.allSatisfy { $0.policy == "read-only-small-artifact" })
        #expect(manifest.artifacts.allSatisfy { $0.redactionStatus == "sensitive" })
        #expect(manifest.skipped.isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/host/defaults.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/status.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/discovery.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))

        let summary = try summarizeEvidenceBundle(input: root.path)
        #expect(summary.sensitiveArtifactCount == 5)
        #expect(summary.primaryArtifacts.map(\.kind) == manifest.primaryArtifacts.map(\.kind))
    }

    @Test("evidence capture records skipped host and xcode sources when unavailable")
    func captureRecordsSkippedHostAndXcodeSourcesWhenUnavailable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-host-xcode-skipped-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: { nil },
            simulatorList: { throw RuntimeError("simulator list unavailable") },
            xcodeStatus: { throw RuntimeError("xcode status unavailable") },
            xcodeDiscovery: { throw RuntimeError("xcode discovery unavailable") }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["host", "xcode"],
            name: "host-xcode-skipped",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            hostXcodeProviders: providers
        )

        #expect(manifest.artifacts.isEmpty)
        #expect(manifest.skipped.map(\.kind) == [
            "host.defaults",
            "host.simulators",
            "xcode.defaults",
            "xcode.status",
            "xcode.discovery",
        ])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))
    }

    @Test("evidence capture imports explicit xcode action summary without copying logs")
    func captureImportsExplicitXcodeActionSummaryWithoutCopyingLogs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-xcode-summary-\(UUID().uuidString)", isDirectory: true)
        let summaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("xcode-action-summary-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: summaryURL)
        }

        let actionSummary = TKXcodeActionSummary(
            ok: false,
            action: "xcode.test",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            resultBundlePath: "/tmp/App.xcresult",
            simulatorUDID: "SIM-1",
            durationMs: 42,
            sourceCommand: "xcodebuild test -workspace App.xcworkspace",
            exitCode: 65,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/stderr.log",
            stdoutBytes: 123,
            stderrBytes: 456,
            note: "Test failed."
        )
        try prettyEncodedData(actionSummary).write(to: summaryURL, options: .atomic)

        let providers = EvidenceHostXcodeArtifactProviders(
            loadDefaults: { nil },
            simulatorList: { throw RuntimeError("not used") },
            xcodeStatus: { throw RuntimeError("not available") },
            xcodeDiscovery: { throw RuntimeError("not available") }
        )

        let manifest = try await captureEvidenceBundle(
            output: root.path,
            includes: ["xcode"],
            name: "xcode-summary-import",
            note: nil,
            target: "triton:local",
            host: "127.0.0.1",
            port: 1,
            refresh: false,
            xcodeSummaryPath: summaryURL.path,
            hostXcodeProviders: providers
        )

        let artifact = try #require(manifest.artifacts.first { $0.kind == "xcode.action-summary" })
        #expect(artifact.path == "artifacts/xcode/action-summary.json")
        #expect(artifact.riskLevel == "readonly")
        #expect(artifact.policy == "explicit-xcode-summary")
        #expect(artifact.redactionStatus == "sensitive")
        #expect(artifact.sourceCommand == "read --xcode-summary")
        #expect(manifest.artifacts.count == 1)
        #expect(manifest.primaryArtifacts.map(\.kind) == ["xcode.action-summary"])
        #expect(manifest.skipped.map { $0.kind } == ["xcode.defaults", "xcode.status", "xcode.discovery"])
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/action-summary.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/stdout.log").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/xcode/stderr.log").path))

        let importedData = try Data(contentsOf: root.appendingPathComponent("artifacts/xcode/action-summary.json"))
        let imported = try JSONDecoder().decode(TKXcodeActionSummary.self, from: importedData)
        #expect(imported.stdoutLogPath == "/tmp/triton-xcode-artifacts/stdout.log")
        #expect(try summarizeEvidenceBundle(input: root.path).sensitiveArtifactCount == 1)
    }

    @Test("evidence summary and redact exclude sensitive artifacts")
    func summaryAndRedactExcludeSensitiveArtifacts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-\(UUID().uuidString)", isDirectory: true)
        let redacted = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-redacted-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: redacted)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"{"ok":true}"#.utf8).write(to: root.appendingPathComponent("status.json"), options: .atomic)
        try Data("private screenshot".utf8).write(to: root.appendingPathComponent("screenshot.png"), options: .atomic)

        let manifest = TKEvidenceManifest(
            ok: true,
            name: "case",
            note: "note",
            createdAt: "2026-05-23T00:00:00Z",
            output: root.path,
            artifacts: [
                TKEvidenceArtifact(kind: "status", path: "status.json", contentType: "application/json", bytes: 11),
                TKEvidenceArtifact(
                    kind: "screenshot",
                    path: "screenshot.png",
                    contentType: "image/png",
                    bytes: 18,
                    sourceCommand: "xcrun simctl io /Users/private/App screenshot"
                ),
            ],
            target: TKEvidenceTarget(
                connected: true,
                appName: "App",
                bundleIdentifier: "com.example.app",
                deviceDescription: "sim",
                osDescription: "iOS",
                identityState: "debug"
            ),
            cli: TKEvidenceCLI(version: "test"),
            run: TKEvidenceRunManifest(
                eventsPath: "run/events.jsonl",
                metaPath: "run/meta.json",
                screenshotPaths: ["screenshot.png"],
                eventCount: 2,
                status: .completed,
                summary: TKEvidenceRunSummary(
                    runID: "run-1",
                    verdict: .success,
                    frictionCount: 0,
                    stepCount: 1
                )
            )
        )
        try prettyEncodedData(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        let summary = try summarizeEvidenceBundle(input: root.path)

        #expect(summary.artifactCount == 2)
        #expect(summary.sensitiveArtifactCount == 1)
        #expect(summary.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(summary.primaryArtifacts.map(\.kind) == ["screenshot", "status"])
        #expect(summary.suggestedCommands.count == 1)

        let output = try redactEvidenceBundle(input: root.path, output: redacted.path, profile: "ios-private")

        #expect(output.redactedArtifactCount == 1)
        #expect(output.keptArtifactCount == 1)
        #expect(output.manifest.artifacts.map(\.kind) == ["status", "screenshot"])
        #expect(output.manifest.artifacts.first { $0.kind == "status" }?.redactionStatus == "included")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.redactionStatus == "redacted")
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.sourceCommand == nil)
        #expect(output.manifest.artifacts.first { $0.kind == "screenshot" }?.path.hasPrefix("redacted/") == true)
        #expect(output.primaryArtifacts.map(\.kind) == ["screenshot", "status"])
        #expect(output.suggestedCommands.contains("triton evidence inspect '\(redacted.path)' --json"))
        #expect(output.manifest.run?.eventsPath == "run/events.jsonl")
        #expect(output.manifest.run?.metaPath == "run/meta.json")
        #expect(output.manifest.run?.summary?.verdict == .success)
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: redacted.appendingPathComponent("summary.json").path))
    }
}

private final class EvidenceTargetPropagationFakeServer {
    let host = "127.0.0.1"
    let port: Int

    private let server: URLProtocol.Type

    init(expectedTarget: String) {
        self.port = Int.random(in: 20_000...40_000)
        self.server = EvidenceTargetPropagationURLProtocol.self
        EvidenceTargetPropagationURLProtocol.configure(port: port, expectedTarget: expectedTarget)
        URLProtocol.registerClass(server)
    }

    func stop() {
        URLProtocol.unregisterClass(server)
        EvidenceTargetPropagationURLProtocol.reset()
    }

    var requestTargets: [String?] {
        EvidenceTargetPropagationURLProtocol.requestTargets
    }

    var requestTypes: [String] {
        EvidenceTargetPropagationURLProtocol.requestTypes
    }
}

private final class EvidenceTargetPropagationURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var configuredPort: Int?
    private static var configuredExpectedTarget: String?
    private static var recordedTargets: [String?] = []
    private static var recordedTypes: [String] = []

    static var requestTargets: [String?] {
        lock.withEvidenceLock { recordedTargets }
    }

    static var requestTypes: [String] {
        lock.withEvidenceLock { recordedTypes }
    }

    static func configure(port: Int, expectedTarget: String) {
        lock.withEvidenceLock {
            configuredPort = port
            configuredExpectedTarget = expectedTarget
            recordedTargets = []
            recordedTypes = []
        }
    }

    static func reset() {
        lock.withEvidenceLock {
            configuredPort = nil
            configuredExpectedTarget = nil
            recordedTargets = []
            recordedTypes = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return lock.withEvidenceLock {
            url.scheme == "http"
                && url.host == "127.0.0.1"
                && url.port == configuredPort
        }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let response = try Self.response(for: request)
            client?.urlProtocol(
                self,
                didReceive: HTTPURLResponse(
                    url: request.url!,
                    statusCode: response.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": response.contentType]
                )!,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func response(for request: URLRequest) throws -> (statusCode: Int, contentType: String, data: Data) {
        guard let url = request.url else {
            throw RuntimeError("Missing fake server URL")
        }
        switch (request.httpMethod ?? "GET", url.path) {
        case ("GET", "/status"):
            return try json(TKStatusResponse(connected: true, latestHierarchyAvailable: true, targetCount: 2))
        case ("GET", "/targets"):
            let targets = [
                TKTargetSummary(id: "triton:ios-simulator:SIM-1", connected: true, latestHierarchyAvailable: true, simulatorUDID: "SIM-1"),
                TKTargetSummary(id: configuredExpectedTarget ?? "triton:ios-simulator:SIM-2", connected: true, latestHierarchyAvailable: true, simulatorUDID: "SIM-2"),
            ]
            return try json(TKTargetsResponse(targets: targets))
        case ("POST", "/request"):
            let body = request.httpBodyStream.map(readBodyStream) ?? request.httpBody ?? Data()
            let command = try JSONDecoder().decode(TKCLICommandRequest.self, from: body)
            let expectedTarget = lock.withEvidenceLock { configuredExpectedTarget }
            lock.withEvidenceLock {
                recordedTargets.append(command.target)
                recordedTypes.append(command.type)
            }
            guard command.target == expectedTarget else {
                return try json(
                    TKCLIErrorResponse(error: TKCLIErrorDetail(
                        code: "ambiguous_target",
                        message: "Target is ambiguous: \(command.target ?? TKLocalTargetID). Pass --target <id>."
                    )),
                    statusCode: 409
                )
            }
            return try runtimeResponse(for: command.type)
        default:
            return (404, "text/plain", Data("not found".utf8))
        }
    }

    private static func runtimeResponse(for type: String) throws -> (statusCode: Int, contentType: String, data: Data) {
        switch type {
        case "hierarchy":
            return try json([
                "displayItems": [],
                "appInfo": [
                    "appName": "Demo",
                    "deviceDescription": "iPhone",
                    "osDescription": "iOS 26",
                ],
            ] as [String: Any])
        case "accessibility":
            return try json([TKAXNode]())
        case "geometry":
            return try json(TKGeometryResponse(
                bounds: TKRect(x: 0, y: 0, width: 390, height: 844),
                safeArea: TKInsets(top: 59, left: 0, bottom: 34, right: 0),
                scale: 3,
                orientation: "portrait"
            ))
        case "screenshot":
            return try json(TKScreenshotResponse(
                format: "png",
                width: 1,
                height: 1,
                scale: 1,
                dataBase64: Data("png".utf8).base64EncodedString()
            ))
        default:
            return (400, "text/plain", Data("unsupported request".utf8))
        }
    }

    private static func json<T: Encodable>(
        _ value: T,
        statusCode: Int = 200
    ) throws -> (statusCode: Int, contentType: String, data: Data) {
        (statusCode, "application/json", try JSONEncoder().encode(value))
    }

    private static func json(
        _ object: Any,
        statusCode: Int = 200
    ) throws -> (statusCode: Int, contentType: String, data: Data) {
        (statusCode, "application/json", try JSONSerialization.data(withJSONObject: object))
    }

    private static func readBodyStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private extension NSLock {
    func withEvidenceLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
