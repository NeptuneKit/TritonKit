import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeDefaultDerivedDataTests {
    @Test("default Xcode invocation delegates DerivedData to Xcode")
    func defaultInvocationOmitsDerivedDataOverride() throws {
        let invocation = try resolveXcodeInvocation(
            project: "App.xcodeproj",
            scheme: "App",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1"
        )

        #expect(invocation.derivedDataPath == nil)
        #expect(invocation.derivedDataCache.path == defaultXcodeDerivedDataPath)

        let command = TKXcodebuildCommand.build(
            workspace: invocation.workspace,
            project: invocation.project,
            scheme: invocation.scheme,
            configuration: invocation.configuration,
            sdk: invocation.sdk,
            destination: invocation.destination,
            derivedDataPath: invocation.derivedDataPath
        )
        #expect(!command.argv.contains("-derivedDataPath"))
    }

    @Test("explicit DerivedData override remains opt in")
    func explicitInvocationKeepsDerivedDataOverride() throws {
        let path = ".triton/DerivedData/isolated"
        let invocation = try resolveXcodeInvocation(
            project: "App.xcodeproj",
            scheme: "App",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: path
        )

        #expect(invocation.derivedDataPath == path)
        let command = TKXcodebuildCommand.build(
            workspace: invocation.workspace,
            project: invocation.project,
            scheme: invocation.scheme,
            configuration: invocation.configuration,
            sdk: invocation.sdk,
            destination: invocation.destination,
            derivedDataPath: invocation.derivedDataPath
        )
        let index = try #require(command.argv.firstIndex(of: "-derivedDataPath"))
        #expect(command.argv[index + 1] == path)
        #expect(invocation.derivedDataCache.guidance.contains("ask the user whether it should be cleaned"))
        #expect(invocation.derivedDataCache.guidance.contains("derived-data inspect"))
    }

    @Test("legacy repo-local configured default is ignored while explicit configuration survives")
    func legacyConfiguredDefaultIsMigrated() {
        #expect(resolveXcodeDerivedDataOverride(explicit: nil, configured: ".triton/DerivedData", package: nil) == nil)
        #expect(resolveXcodeDerivedDataOverride(explicit: nil, configured: "./.triton/DerivedData", package: nil) == nil)
        #expect(resolveXcodeDerivedDataOverride(explicit: nil, configured: "/tmp/custom-derived-data", package: nil) == "/tmp/custom-derived-data")
        #expect(resolveXcodeDerivedDataOverride(explicit: ".triton/DerivedData", configured: nil, package: nil) == ".triton/DerivedData")
    }

    @Test("workspace defaults omit DerivedData override by default")
    func workspaceDefaultsUseXcodeDefault() {
        let defaults = TKXcodeWorkspaceDefaults(scheme: "App")
        #expect(defaults.derivedDataPath == nil)
    }

    @Test("xcode use and derived-data inspection default to Xcode-managed storage")
    func commandDefaultsUseXcodeStorage() throws {
        let use = try XcodeUse.parse(["--project", "App.xcodeproj", "--scheme", "App"])
        #expect(use.derivedDataPath == nil)
        let inspect = try XcodeDerivedDataInspect.parse([])
        #expect(inspect.root == defaultXcodeDerivedDataPath)
        let cleanup = try XcodeDerivedDataCleanup.parse([])
        #expect(cleanup.root == defaultXcodeDerivedDataPath)
    }

    @Test("legacy DerivedData guidance asks before cleanup")
    func legacyDerivedDataGuidancePromptsBeforeCleanup() {
        let legacy = xcodeDerivedDataGuidance(path: ".triton/DerivedData")
        #expect(legacy.contains("ask the user whether it should be cleaned"))
        #expect(legacy.contains("derived-data inspect"))
        #expect(!xcodeDerivedDataGuidance(path: defaultXcodeDerivedDataPath).contains("ask the user whether it should be cleaned"))
    }
}
