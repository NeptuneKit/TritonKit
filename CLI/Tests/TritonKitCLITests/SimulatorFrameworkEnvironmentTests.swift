import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Selected Simulator native framework environment")
struct SimulatorFrameworkEnvironmentTests {
    private let developer = "/Applications/Selected Xcode.app/Contents/Developer"
    private let shared = "/Applications/Selected Xcode.app/Contents/SharedFrameworks"

    @Test func explicitNativeFrameworkEnvironmentDoesNotMutateParent() {
        let input = ["PATH": "/usr/bin"]
        let output = selectedSimulatorFrameworkEnvironment(environment: input, developerDirectory: developer, fileExists: { $0 == shared + "/SimulatorKit.framework/Versions/A/SimulatorKit" })
        #expect(output["DYLD_FRAMEWORK_PATH"] == shared)
        #expect(output["PATH"] == input["PATH"])
        #expect(input["DYLD_FRAMEWORK_PATH"] == nil)
    }

    @Test func preservesPriorityAndAvoidsDuplicateDirectories() {
        let env = ["DYLD_FRAMEWORK_PATH": "/custom:" + shared]
        #expect(selectedSimulatorFrameworkEnvironment(environment: env, developerDirectory: developer, fileExists: { _ in true }) == env)
        let appended = selectedSimulatorFrameworkEnvironment(environment: ["DYLD_FRAMEWORK_PATH": "/custom"], developerDirectory: developer, fileExists: { _ in true })
        #expect(appended["DYLD_FRAMEWORK_PATH"] == "/custom:" + shared)
    }

    @Test func appDeveloperDirectoryIsRespected() {
        let output = selectedSimulatorFrameworkEnvironment(environment: [:], developerDirectory: "/Applications/Selected Xcode.app", fileExists: { $0 == shared + "/SimulatorKit.framework/SimulatorKit" })
        #expect(output["DYLD_FRAMEWORK_PATH"] == shared)
    }

    @Test func selectedToolchainIgnoresObsoleteExternalAdapterVariable() {
        let env = ["TRITONKIT_BAGUETTE_BIN": "/tools/custom-adapter"]
        let selected = selectedXcodeDeveloperDirectory(environment: env, querySelectedDeveloperDirectory: { developer })
        #expect(selected == developer)
        #expect(selectedXcodeDeveloperDirectory(environment: env, querySelectedDeveloperDirectory: { nil }) == nil)
    }

    @Test func explicitDeveloperEnvironmentDoesNotQueryOtherSDKs() {
        var queried = false
        let selected = selectedXcodeDeveloperDirectory(environment: ["DEVELOPER_DIR": developer], querySelectedDeveloperDirectory: { queried = true; return "/other" })
        #expect(selected == developer)
        #expect(!queried)
    }

    @Test func failedSelectionQueryDoesNotGuessAnXcode() {
        #expect(selectedXcodeDeveloperDirectory(environment: [:], querySelectedDeveloperDirectory: { nil }) == nil)
    }

    @Test func missingFrameworkOrSelectionDoesNotInject() {
        let env = ["PATH": "/usr/bin"]
        #expect(selectedSimulatorFrameworkEnvironment(environment: env, developerDirectory: developer, fileExists: { _ in false }) == env)
        #expect(selectedSimulatorFrameworkEnvironment(environment: env, developerDirectory: nil, fileExists: { _ in true }) == env)
        #expect(selectedSimulatorFrameworkEnvironment(environment: env, developerDirectory: "relative/Developer", fileExists: { _ in true }) == env)
    }

    @Test func genericCommandsNeverImplicitlyInjectSimulatorFrameworks() throws {
        let contents = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Selected.app/Contents")
        let shared = contents.appendingPathComponent("SharedFrameworks")
        let framework = shared.appendingPathComponent("SimulatorKit.framework")
        try FileManager.default.createDirectory(at: framework, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: contents.deletingLastPathComponent().deletingLastPathComponent()) }
        try Data().write(to: framework.appendingPathComponent("SimulatorKit"))
        for executable in ["baguette", "/fixture/custom-adapter", "/fixture/triton", "xcrun"] {
            let process = Process()
            let command = TKHostCommand(executable: executable, arguments: ["--version"], environment: [
                "DEVELOPER_DIR": contents.appendingPathComponent("Developer").path,
                "DYLD_FRAMEWORK_PATH": "/custom",
                "TRITONKIT_BAGUETTE_BIN": executable,
            ])
            configureHostProcessExecutable(process, command: command)
            #expect(process.environment?["DYLD_FRAMEWORK_PATH"] == "/custom")
        }
        let native = try nativeHIDHelperCommand(target: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", input: .tap(x: 1, y: 2), executable: "/fixture/triton", developerDirectory: contents.appendingPathComponent("Developer").path)
        #expect(native.executable == "/fixture/triton")
        #expect(native.environment["DYLD_FRAMEWORK_PATH"] == shared.path)
        #expect(native.environment["TRITONKIT_BAGUETTE_BIN"] == nil)
    }
}
