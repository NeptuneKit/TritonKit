import Foundation
import Testing
@testable import TritonKitCLI

@Suite("SP-180 Baguette Xcode framework environment")
struct BaguetteFrameworkEnvironmentTests {
    private let developer = "/Applications/Selected Xcode.app/Contents/Developer"
    private let shared = "/Applications/Selected Xcode.app/Contents/SharedFrameworks"

    @Test func sharedFrameworkIsScopedToBaguette() {
        let input = ["PATH": "/usr/bin"]
        let output = baguetteFrameworkEnvironment(executable: "/opt/homebrew/bin/baguette", environment: input, developerDirectory: developer, fileExists: { $0 == shared + "/SimulatorKit.framework/Versions/A/SimulatorKit" })
        #expect(output["DYLD_FRAMEWORK_PATH"] == shared)
        #expect(output["PATH"] == input["PATH"])
        #expect(input["DYLD_FRAMEWORK_PATH"] == nil)
    }

    @Test func preservesPriorityAndAvoidsDuplicateDirectories() {
        let env = ["DYLD_FRAMEWORK_PATH": "/custom:" + shared]
        let output = baguetteFrameworkEnvironment(executable: "baguette", environment: env, developerDirectory: developer, fileExists: { _ in true })
        #expect(output == env)
        let appended = baguetteFrameworkEnvironment(executable: "baguette", environment: ["DYLD_FRAMEWORK_PATH": "/custom"], developerDirectory: developer, fileExists: { _ in true })
        #expect(appended["DYLD_FRAMEWORK_PATH"] == "/custom:" + shared)
    }

    @Test func unrelatedCommandsAreUntouched() {
        let env = ["PATH": "/usr/bin"]
        #expect(baguetteFrameworkEnvironment(executable: "xcrun", environment: env, developerDirectory: developer, fileExists: { _ in true }) == env)
    }

    @Test func customAdapterAndAppDeveloperDirectoryAreRespected() {
        let env = ["TRITONKIT_BAGUETTE_BIN": "/tools/custom-adapter"]
        let output = baguetteFrameworkEnvironment(executable: "/tools/custom-adapter", environment: env, developerDirectory: "/Applications/Selected Xcode.app", fileExists: { $0 == shared + "/SimulatorKit.framework/SimulatorKit" })
        #expect(output["DYLD_FRAMEWORK_PATH"] == shared)
    }

    @Test func supportedSelectionQueryReplacesPrivateSymlinkAssumption() {
        let selected = baguetteDeveloperDirectory(environment: [:], querySelectedDeveloperDirectory: { developer })
        #expect(selected == developer)
    }

    @Test func explicitDeveloperEnvironmentDoesNotQueryOtherSDKs() {
        var queried = false
        let selected = baguetteDeveloperDirectory(environment: ["DEVELOPER_DIR": developer], querySelectedDeveloperDirectory: { queried = true; return "/other" })
        #expect(selected == developer)
        #expect(!queried)
    }

    @Test func failedSelectionQueryDoesNotGuessAnXcode() {
        #expect(baguetteDeveloperDirectory(environment: [:], querySelectedDeveloperDirectory: { nil }) == nil)
    }

    @Test func missingFrameworkOrSelectionDoesNotInject() {
        let env = ["PATH": "/usr/bin"]
        #expect(baguetteFrameworkEnvironment(executable: "baguette", environment: env, developerDirectory: developer, fileExists: { _ in false }) == env)
        #expect(baguetteFrameworkEnvironment(executable: "baguette", environment: env, developerDirectory: nil, fileExists: { _ in true }) == env)
        #expect(baguetteFrameworkEnvironment(executable: "baguette", environment: env, developerDirectory: "relative/Developer", fileExists: { _ in true }) == env)
    }
}
