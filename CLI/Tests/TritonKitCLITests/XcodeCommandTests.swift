import ArgumentParser
import Testing
@testable import TritonKitCLI

@Suite
struct XcodeCommandTests {
    @Test("xcode workflow commands accept real-device selector option")
    func xcodeWorkflowCommandsAcceptDeviceOption() throws {
        let settings = try XcodeSettings.parse(["--project", "App.xcodeproj", "--scheme", "App", "--device", "ios-real:abc123", "--json"])
        let build = try XcodeBuild.parse(["--project", "App.xcodeproj", "--scheme", "App", "--device", "ios-real:abc123", "--allow-provisioning-updates", "--jsonl"])
        let test = try XcodeTest.parse(["--project", "App.xcodeproj", "--scheme", "App", "--device", "ios-real:abc123", "--result-bundle", "/tmp/App.xcresult", "--jsonl"])
        let run = try XcodeRun.parse(["--project", "App.xcodeproj", "--scheme", "App", "--device", "ios-real:abc123", "--jsonl"])

        #expect(settings.device == "ios-real:abc123")
        #expect(build.device == "ios-real:abc123")
        #expect(build.allowProvisioningUpdates == true)
        #expect(test.device == "ios-real:abc123")
        #expect(run.device == "ios-real:abc123")
    }

    @Test("xcode real-device selector resolves iphoneos and generic iOS destination")
    func xcodeDeviceSelectorResolvesRealDeviceBuildTarget() throws {
        let sdk = resolvedXcodeSDK(sdk: nil, defaultSDK: "iphonesimulator", device: "ios-real:abc123")
        let destination = resolvedXcodeDestination(
            destination: nil,
            defaultDestination: "platform=iOS Simulator,id=SIM-1",
            simulatorUDID: nil,
            device: "ios-real:abc123"
        )

        #expect(sdk == "iphoneos")
        #expect(destination == "generic/platform=iOS")
    }

    @Test("xcode explicit destination overrides synthesized real-device destination")
    func explicitDestinationOverridesDeviceDestination() throws {
        let destination = resolvedXcodeDestination(
            destination: "platform=iOS,id=RAW-UDID",
            defaultDestination: "platform=iOS Simulator,id=SIM-1",
            simulatorUDID: nil,
            device: "ios-real:abc123"
        )

        #expect(destination == "platform=iOS,id=RAW-UDID")
    }
}
