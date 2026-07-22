import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct XcodeCommandTests {
    @Test("xcode workflow commands accept Package.swift container")
    func xcodeWorkflowCommandsAcceptPackageOption() throws {
        let use = try XcodeUse.parse(["--package", "/tmp/Demo/Package.swift", "--scheme", "Demo", "--json"])
        let schemes = try XcodeSchemes.parse(["--package", "/tmp/Demo/Package.swift", "--json"])
        let settings = try XcodeSettings.parse(["--package", "/tmp/Demo/Package.swift", "--scheme", "Demo", "--json"])
        let build = try XcodeBuild.parse(["--package", "/tmp/Demo/Package.swift", "--scheme", "Demo", "--jsonl"])
        let test = try XcodeTest.parse(["--package", "/tmp/Demo/Package.swift", "--scheme", "Demo", "--jsonl"])
        let run = try XcodeRun.parse(["--package", "/tmp/Demo/Package.swift", "--scheme", "Demo", "--jsonl"])

        #expect(use.package == "/tmp/Demo/Package.swift")
        #expect(schemes.package == "/tmp/Demo/Package.swift")
        #expect(settings.package == "/tmp/Demo/Package.swift")
        #expect(build.package == "/tmp/Demo/Package.swift")
        #expect(test.package == "/tmp/Demo/Package.swift")
        #expect(run.package == "/tmp/Demo/Package.swift")
    }

    @Test("xcode workflow commands accept repeatable one-off build settings")
    func xcodeWorkflowCommandsAcceptBuildSettings() throws {
        let arguments = [
            "--project", "App.xcodeproj",
            "--scheme", "App",
            "--build-setting", "CLANG_ENABLE_EXPLICIT_MODULES=NO",
            "--build-setting", "OTHER_SWIFT_FLAGS=$(inherited) -D DEMO",
            "--jsonl",
        ]

        let settings = try XcodeSettings.parse(arguments)
        let build = try XcodeBuild.parse(arguments)
        let test = try XcodeTest.parse(arguments)
        let run = try XcodeRun.parse(arguments)

        let expected = ["CLANG_ENABLE_EXPLICIT_MODULES=NO", "OTHER_SWIFT_FLAGS=$(inherited) -D DEMO"]
        #expect(settings.buildSettings == expected)
        #expect(build.buildSettings == expected)
        #expect(test.buildSettings == expected)
        #expect(run.buildSettings == expected)
    }

    @Test("xcode build setting validation preserves values and rejects malformed keys")
    func xcodeBuildSettingValidation() throws {
        let values = [
            "CLANG_ENABLE_EXPLICIT_MODULES=NO",
            "OTHER_SWIFT_FLAGS=$(inherited) -D DEMO",
            "EMPTY=",
        ]

        #expect(try validateXcodeBuildSettings(values) == values)
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeBuildSettings(["NO_SEPARATOR"])
        }
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeBuildSettings(["1INVALID=value"])
        }
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeBuildSettings(["=value"])
        }
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeBuildSettings(["BAD-KEY=value"])
        }

        let command = TKXcodebuildCommand.build(
            workspace: nil,
            project: "App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            sdk: nil,
            destination: nil,
            derivedDataPath: nil,
            buildSettings: values
        )
        #expect(hostSourceCommand(command).contains("CLANG_ENABLE_EXPLICIT_MODULES=NO"))
        #expect(hostSourceCommand(command).contains("'OTHER_SWIFT_FLAGS=$(inherited) -D DEMO'"))
    }

    @Test("xcode schema exposes repeatable build setting on settings build test and run")
    func xcodeSchemaExposesBuildSettings() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let option = try #require(xcode.options.first { $0.name == "--build-setting" })
        #expect(option.type == "KEY=VALUE[]")
        #expect(xcode.examples.contains { $0.contains("--build-setting CLANG_ENABLE_EXPLICIT_MODULES=NO") })
        for name in ["settings", "build", "test", "run"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == name })
            #expect(subcommand.optionalOptions.contains("--build-setting"))
        }
    }

    @Test("xcode package source command records working directory")
    func xcodePackageSourceCommandRecordsWorkingDirectory() {
        let command = TKXcodebuildCommand.build(
            workspace: nil,
            project: nil,
            package: "/tmp/Demo/Package.swift",
            scheme: "Demo",
            configuration: "Debug",
            sdk: nil,
            destination: "generic/platform=iOS Simulator",
            derivedDataPath: "/tmp/Demo/.triton/DerivedData"
        )

        #expect(hostSourceCommand(command).hasPrefix("cd /tmp/Demo && xcodebuild "))
    }

    @Test("streaming xcode runner honors package working directory")
    func streamingXcodeRunnerHonorsWorkingDirectory() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("triton-xcode-cwd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let command = TKHostCommand(
            executable: "/bin/pwd",
            arguments: [],
            workingDirectory: directory.path
        )

        let (result, _) = try runXcodeHostCommand(command, event: "xcode.build", jsonl: false)

        let observedDirectory = URL(
            fileURLWithPath: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        #expect(observedDirectory.lastPathComponent == directory.lastPathComponent)
    }

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
            "--device", "ios-real:abc123",
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
        #expect(xcode.options.contains { $0.name == "--env" && $0.description.contains("SIMCTL_CHILD") && $0.description.contains("--environment-variables") })
        #expect(xcode.options.contains { $0.name == "--arg" && $0.description.contains("launch argument") })
        let runSchema = try #require(xcode.subcommands.first { $0.name == "run" })
        #expect(runSchema.optionalOptions.contains("--env"))
        #expect(runSchema.optionalOptions.contains("--arg"))
    }

    @Test("dotted nested schema selector narrows xcode build contract")
    func dottedNestedSchemaSelectorNarrowsXcodeBuild() throws {
        let response = try buildSchemaResponse(command: "xcode.build")
        let xcode = try #require(response.commands.first)
        let build = try #require(xcode.subcommands.first)

        #expect(response.commands.count == 1)
        #expect(xcode.name == "xcode")
        #expect(xcode.subcommands.count == 1)
        #expect(build.name == "build")
        #expect(build.optionalOptions.contains("--package"))
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

    @Test("xcode explicit simulator UDID overrides stale workspace destination")
    func explicitSimulatorUDIDOverridesStaleDefaultDestination() {
        let udid = "60667794-96F8-40E6-8664-85538EC4663E"
        let destination = resolvedXcodeDestination(
            destination: nil,
            defaultDestination: "platform=iOS Simulator,id=iPhone 17",
            simulatorUDID: udid,
            device: nil
        )

        #expect(destination == "platform=iOS Simulator,id=\(udid)")
    }

    @Test("xcode simulator selector keeps id and name destination keys aligned")
    func simulatorSelectorKeepsDestinationKeyAligned() {
        let udid = "60667794-96F8-40E6-8664-85538EC4663E"

        #expect(xcodeSimulatorDestination(selector: udid) == "platform=iOS Simulator,id=\(udid)")
        #expect(xcodeSimulatorDestination(selector: "sim:\(udid)") == "platform=iOS Simulator,id=\(udid)")
        #expect(xcodeSimulatorDestination(selector: "iPhone 17") == "platform=iOS Simulator,name=iPhone 17")
    }

    @Test("xcode explicit destination remains above simulator selector")
    func explicitDestinationRemainsAboveSimulatorSelector() {
        let destination = resolvedXcodeDestination(
            destination: "platform=iOS Simulator,id=EXPLICIT",
            defaultDestination: "platform=iOS Simulator,id=STALE",
            simulatorUDID: "60667794-96F8-40E6-8664-85538EC4663E",
            device: nil
        )

        #expect(destination == "platform=iOS Simulator,id=EXPLICIT")
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
