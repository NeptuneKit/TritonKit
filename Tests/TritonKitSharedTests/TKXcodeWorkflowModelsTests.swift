import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKXcodeWorkflowModelsTests {
    @Test("xcode workspace defaults round trip without losing simulator default")
    func xcodeDefaultsRoundTrip() throws {
        let defaults = TKHostWorkspaceDefaults(
            defaultSimulatorUDID: "SIM-1",
            xcode: TKXcodeWorkspaceDefaults(
                workspace: "App.xcworkspace",
                project: nil,
                scheme: "App",
                configuration: "Debug",
                sdk: "iphonesimulator",
                destination: "platform=iOS Simulator,id=SIM-1",
                derivedDataPath: ".triton/DerivedData/App"
            )
        )

        let decoded = try JSONDecoder().decode(TKHostWorkspaceDefaults.self, from: JSONEncoder().encode(defaults))

        #expect(decoded.defaultSimulatorUDID == "SIM-1")
        #expect(decoded.xcode?.workspace == "App.xcworkspace")
        #expect(decoded.xcode?.scheme == "App")
        #expect(decoded.xcode?.destination == "platform=iOS Simulator,id=SIM-1")
    }

    @Test("xcodebuild command builder emits stable argv")
    func xcodebuildCommandBuilder() {
        let build = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData/App"
        )

        #expect(TKXcodebuildCommand.listSchemes(workspace: "App.xcworkspace", project: nil).executable == "xcodebuild")
        #expect(TKXcodebuildCommand.listSchemes(workspace: "App.xcworkspace", project: nil).argv == ["-workspace", "App.xcworkspace", "-list", "-json"])
        let settings = TKXcodebuildCommand.showBuildSettings(workspace: "App.xcworkspace", project: nil, scheme: "App", configuration: "Debug", sdk: "iphonesimulator", destination: "platform=iOS Simulator,id=SIM-1", derivedDataPath: ".triton/DerivedData/App")
        #expect(settings.argv.contains("-showBuildSettings"))
        #expect(settings.defaultTimeoutSeconds == 300)
        #expect(settings.withTimeout(1_800).defaultTimeoutSeconds == 1_800)
        #expect(build.argv == [
            "-workspace", "App.xcworkspace",
            "-scheme", "App",
            "-configuration", "Debug",
            "-sdk", "iphonesimulator",
            "-destination", "platform=iOS Simulator,id=SIM-1",
            "-derivedDataPath", ".triton/DerivedData/App",
            "build",
        ])
    }

    @Test("xctrace and coverage command builders emit stable argv")
    func xctraceAndCoverageCommandBuilders() {
        let trace = TKXctraceCommand.record(
            template: "Time Profiler",
            output: "/tmp/App.trace",
            device: "SIM-1",
            timeLimit: "5s",
            allProcesses: true,
            attach: nil,
            launchCommand: []
        )
        #expect(trace.executable == "xcrun")
        #expect(trace.argv == [
            "xctrace", "record",
            "--template", "Time Profiler",
            "--output", "/tmp/App.trace",
            "--device", "SIM-1",
            "--time-limit", "5s",
            "--all-processes",
            "--no-prompt",
        ])
        #expect(trace.capturesArtifacts)

        let coverage = TKXccovCommand.viewReport(
            xcresult: "/tmp/App.xcresult",
            mode: .filesForTarget("App"),
            json: true
        )
        #expect(coverage.executable == "xcrun")
        #expect(coverage.argv == [
            "xccov", "view",
            "--report",
            "--files-for-target", "App",
            "--json",
            "/tmp/App.xcresult",
        ])
    }

    @Test("xcode action progress and summary preserve streaming artifacts")
    func xcodeStreamingArtifactsRoundTrip() throws {
        let event = TKXcodeProgressEvent(
            event: "xcode.build.heartbeat",
            message: "running",
            sourceCommand: "xcodebuild build",
            elapsedMs: 12_000,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/case/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/case/stderr.log",
            stdoutBytes: 1_024,
            stderrBytes: 128
        )
        let decodedEvent = try JSONDecoder().decode(TKXcodeProgressEvent.self, from: JSONEncoder().encode(event))

        #expect(decodedEvent.stdoutLogPath == "/tmp/triton-xcode-artifacts/case/stdout.log")
        #expect(decodedEvent.stderrLogPath == "/tmp/triton-xcode-artifacts/case/stderr.log")
        #expect(decodedEvent.stdoutBytes == 1_024)
        #expect(decodedEvent.stderrBytes == 128)

        let summary = TKXcodeActionSummary(
            ok: true,
            action: "xcode.build",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: "/tmp/DerivedData",
            durationMs: 25_000,
            sourceCommand: "xcodebuild build",
            exitCode: 0,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/case/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/case/stderr.log",
            stdoutBytes: 2_048,
            stderrBytes: 512
        )
        let decodedSummary = try JSONDecoder().decode(TKXcodeActionSummary.self, from: JSONEncoder().encode(summary))

        #expect(decodedSummary.stdoutLogPath == "/tmp/triton-xcode-artifacts/case/stdout.log")
        #expect(decodedSummary.stderrLogPath == "/tmp/triton-xcode-artifacts/case/stderr.log")
        #expect(decodedSummary.stdoutBytes == 2_048)
        #expect(decodedSummary.stderrBytes == 512)
    }

    @Test("xcodebuild list json parser returns schemes")
    func xcodebuildListParser() throws {
        let json = """
        {
          "workspace": {
            "name": "App",
            "schemes": ["App", "AppTests"]
          }
        }
        """

        let output = try TKXcodebuildListParser.parseSchemes(Data(json.utf8))

        #expect(output.containerName == "App")
        #expect(output.schemes == ["App", "AppTests"])
    }

    @Test("xcodebuild build settings parser resolves app product and bundle id")
    func xcodebuildBuildSettingsParser() throws {
        let json = """
        [
          {
            "target": "App",
            "buildSettings": {
              "BUILT_PRODUCTS_DIR": "/tmp/DerivedData/Build/Products/Debug-iphonesimulator",
              "FULL_PRODUCT_NAME": "App.app",
              "PRODUCT_BUNDLE_IDENTIFIER": "com.example.App"
            }
          }
        ]
        """

        let product = try TKXcodeBuildSettingsParser.resolveBuiltApp(Data(json.utf8))

        #expect(product.target == "App")
        #expect(product.appPath == "/tmp/DerivedData/Build/Products/Debug-iphonesimulator/App.app")
        #expect(product.bundleID == "com.example.App")
    }

    @Test("xcode discovery finds workspace project and package without nested build noise")
    func xcodeDiscovery() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("triton-xcode-discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Demo.xcworkspace"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Demo.xcodeproj"), withIntermediateDirectories: true)
        try "swift-tools-version: 6.0".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try TKXcodeProjectDiscovery.discover(path: root.path, maxDepth: 2)

        #expect(result.ok)
        #expect(result.workspaces.map(\.name) == ["Demo.xcworkspace"])
        #expect(result.projects.map(\.name) == ["Demo.xcodeproj"])
        #expect(result.packages.map(\.name) == ["Package.swift"])
        #expect(result.recommendedContainer?.path.hasSuffix("Demo.xcworkspace") == true)
    }
}
