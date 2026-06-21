import ArgumentParser
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeCommandTests {
    @Test("streaming xcode host command honors command timeout and returns artifact paths")
    func streamingHostCommandHonorsCommandTimeoutAndReturnsArtifactPaths() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 2"],
            defaultTimeoutSeconds: 0.05
        )

        do {
            _ = try runXcodeHostCommand(command, event: "xcode.build", jsonl: false)
            Issue.record("Expected xcode host command timeout")
        } catch HostCommandRunError.timeout(let timedOutCommand, let timeoutSeconds, let stdoutLogPath, let stderrLogPath) {
            #expect(timedOutCommand.defaultTimeoutSeconds == 0.05)
            #expect(timeoutSeconds == 0.05)
            #expect(stdoutLogPath?.contains("triton-xcode-artifacts") == true)
            #expect(stderrLogPath?.contains("triton-xcode-artifacts") == true)
        }
    }

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

    @Test("xcode run accepts launch env and app arguments")
    func xcodeRunAcceptsLaunchEnvAndAppArguments() throws {
        let run = try XcodeRun.parse([
            "--project", "App.xcodeproj",
            "--scheme", "App",
            "--simulator", "SIM-1",
            "--env", "FEATURE_FLAG=1",
            "--env", "API_KEY=secret",
            "--arg",
            "debug-route",
            "--arg", "demo.home",
            "--jsonl"
        ])

        #expect(run.launchEnvironment == ["FEATURE_FLAG=1", "API_KEY=secret"])
        #expect(run.launchArguments == ["debug-route", "demo.home"])

        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        #expect(xcode.options.contains { $0.name == "--env" && $0.description.contains("SIMCTL_CHILD") })
        #expect(xcode.options.contains { $0.name == "--arg" && $0.description.contains("launch argument") })
        let runSchema = try #require(xcode.subcommands.first { $0.name == "run" })
        #expect(runSchema.optionalOptions.contains("--env"))
        #expect(runSchema.optionalOptions.contains("--arg"))
    }

    @Test("xcode real-device selector resolves iphoneos and generic iOS destination")
    func xcodeDeviceSelectorResolvesRealDeviceBuildTarget() throws {
        let sdk = resolvedXcodeSDK(
            sdk: nil,
            defaultSDK: "iphonesimulator",
            resolvedDestination: nil,
            simulatorUDID: nil,
            device: "ios-real:abc123"
        )
        let destination = resolvedXcodeDestination(
            destination: nil,
            defaultDestination: "platform=iOS Simulator,id=SIM-1",
            simulatorUDID: nil,
            device: "ios-real:abc123"
        )

        #expect(sdk == "iphoneos")
        #expect(destination == "generic/platform=iOS")
    }

    @Test("xcode simulator destination omits inherited default simulator SDK")
    func xcodeSimulatorDestinationOmitsInheritedDefaultSimulatorSDK() throws {
        let sdk = resolvedXcodeSDK(
            sdk: nil,
            defaultSDK: "iphonesimulator",
            resolvedDestination: "platform=iOS Simulator,id=SIM-1",
            simulatorUDID: "SIM-1",
            device: nil
        )

        #expect(sdk == nil)

        let build = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: sdk,
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData/App"
        )
        #expect(build.argv.contains("-destination"))
        #expect(build.argv.contains("platform=iOS Simulator,id=SIM-1"))
        #expect(!build.argv.contains("-sdk"))
        #expect(!build.argv.contains("iphonesimulator"))
    }

    @Test("xcode explicit SDK is preserved for simulator destination")
    func xcodeExplicitSDKIsPreservedForSimulatorDestination() throws {
        let sdk = resolvedXcodeSDK(
            sdk: "iphonesimulator",
            defaultSDK: "iphoneos",
            resolvedDestination: "platform=iOS Simulator,id=SIM-1",
            simulatorUDID: "SIM-1",
            device: nil
        )

        #expect(sdk == "iphonesimulator")

        let build = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: sdk,
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData/App"
        )
        #expect(build.argv.contains("-sdk"))
        #expect(build.argv.contains("iphonesimulator"))
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
