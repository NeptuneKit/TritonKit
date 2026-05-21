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
