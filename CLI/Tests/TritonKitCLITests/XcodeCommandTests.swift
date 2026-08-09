import ArgumentParser
import Darwin
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

private func testXcodeDerivedDataCache() -> TKXcodeDerivedDataCacheInfo {
    TKXcodeDerivedDataCacheInfo(
        path: ".triton/DerivedData",
        exists: false,
        cacheState: "empty",
        incrementalExpected: false,
        cleanupPolicy: "preserve-by-default",
        guidance: "preserve"
    )
}

@Suite(.serialized)
struct XcodeCommandTests {
    @Test("xcode archive and export commands expose explicit archive and export options")
    func xcodeArchiveAndExportCommandsExposeExplicitOptions() throws {
        let archive = try XcodeArchive.parse([
            "--project", "App With Space.xcodeproj",
            "--scheme", "App",
            "--configuration", "Release",
            "--sdk", "iphoneos",
            "--archive-path", "artifacts/App With Space.xcarchive",
            "--build-setting", "CODE_SIGN_STYLE=Manual",
            "--build-setting", "OTHER_SWIFT_FLAGS=$(inherited) -D ARCHIVE",
            "--allow-provisioning-updates",
            "--allow-provisioning-device-registration",
            "--jsonl",
        ])
        let export = try XcodeExport.parse([
            "--archive-path", "artifacts/App With Space.xcarchive",
            "--export-options-plist", "configs/Export Options.plist",
            "--export-path", "artifacts/ipa output",
            "--build-setting", "CODE_SIGN_STYLE=Manual",
            "--allow-provisioning-updates",
            "--allow-provisioning-device-registration",
            "--jsonl",
        ])

        #expect(archive.archivePath == "artifacts/App With Space.xcarchive")
        #expect(archive.destination == "generic/platform=iOS")
        #expect(archive.buildSettings == ["CODE_SIGN_STYLE=Manual", "OTHER_SWIFT_FLAGS=$(inherited) -D ARCHIVE"])
        #expect(archive.allowProvisioningUpdates)
        #expect(archive.allowProvisioningDeviceRegistration)
        #expect(export.archivePath == "artifacts/App With Space.xcarchive")
        #expect(export.exportOptionsPlist == "configs/Export Options.plist")
        #expect(export.exportPath == "artifacts/ipa output")
        #expect(export.buildSettings == ["CODE_SIGN_STYLE=Manual"])
        #expect(export.allowProvisioningUpdates)
        #expect(export.allowProvisioningDeviceRegistration)
    }

    @Test("archive requires generic iOS destination and keeps every argv boundary")
    func archiveRequiresGenericIOSDestinationAndKeepsArgvBoundaries() throws {
        #expect(try validateXcodeArchiveDestination("generic/platform=iOS") == "generic/platform=iOS")
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeArchiveDestination("platform=iOS Simulator,id=SIM-1")
        }

        let command = TKXcodebuildCommand.archive(
            workspace: nil,
            project: "App With Space.xcodeproj",
            package: nil,
            scheme: "App",
            configuration: "Release",
            sdk: "iphoneos",
            destination: "generic/platform=iOS",
            derivedDataPath: ".triton/Archive DerivedData",
            archivePath: "artifacts/App With Space.xcarchive",
            buildSettings: [
                "CODE_SIGN_STYLE=Manual",
                "OTHER_SWIFT_FLAGS=$(inherited) -D ARCHIVE",
            ],
            allowProvisioningUpdates: true,
            allowProvisioningDeviceRegistration: true
        )

        #expect(command.executable == "xcodebuild")
        #expect(command.argv.contains("App With Space.xcodeproj"))
        #expect(command.argv.contains("artifacts/App With Space.xcarchive"))
        #expect(command.argv.contains("OTHER_SWIFT_FLAGS=$(inherited) -D ARCHIVE"))
        #expect(command.argv.suffix(5) == [
            "-allowProvisioningUpdates",
            "-allowProvisioningDeviceRegistration",
            "archive",
            "-archivePath",
            "artifacts/App With Space.xcarchive",
        ])
        #expect(hostSourceCommand(command).contains("'App With Space.xcodeproj'"))
        #expect(hostSourceCommand(command).contains("'OTHER_SWIFT_FLAGS=$(inherited) -D ARCHIVE'"))
    }

    @Test("export uses an explicit options plist and discovers IPA artifacts")
    func exportUsesExplicitOptionsPlistAndDiscoversIPAArtifacts() throws {
        let command = TKXcodebuildCommand.exportArchive(
            archivePath: "artifacts/App With Space.xcarchive",
            exportOptionsPlist: "configs/Export Options.plist",
            exportPath: "artifacts/ipa output",
            buildSettings: ["CODE_SIGN_STYLE=Manual"],
            allowProvisioningUpdates: true,
            allowProvisioningDeviceRegistration: true
        )

        #expect(command.argv == [
            "-exportArchive",
            "-archivePath", "artifacts/App With Space.xcarchive",
            "-exportOptionsPlist", "configs/Export Options.plist",
            "-exportPath", "artifacts/ipa output",
            "CODE_SIGN_STYLE=Manual",
            "-allowProvisioningUpdates",
            "-allowProvisioningDeviceRegistration",
        ])
        let sourceCommand = hostSourceCommand(command)
        #expect(sourceCommand.contains("'configs/Export Options.plist'"))
        #expect(sourceCommand.contains("'artifacts/ipa output'"))
        #expect(sourceCommand.contains("CODE_SIGN_STYLE=Manual"))
    }

    @Test("archive and export schema expose bounded progress artifacts and recovery")
    func archiveAndExportSchemaExposeBoundedProgressArtifactsAndRecovery() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        #expect(xcode.providedCapabilities.contains("xcode-archive"))
        #expect(xcode.providedCapabilities.contains("xcode-export"))
        for name in ["archive", "export"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == name })
            #expect(subcommand.optionalOptions.contains("--build-setting"))
            #expect(subcommand.optionalOptions.contains("--allow-provisioning-updates"))
            #expect(subcommand.optionalOptions.contains("--allow-provisioning-device-registration"))
            #expect(subcommand.optionalOptions.contains("--jsonl"))
            #expect(subcommand.jsonlEvents.contains("xcode.\(name).heartbeat"))
            #expect(subcommand.artifacts.contains("archive" ) || subcommand.artifacts.contains("ipa"))
            #expect(subcommand.failureCodes.contains("xcode_signing_failed"))
            #expect(subcommand.failureCodes.contains("provisioning_profile_missing"))
            #expect(subcommand.failureCodes.contains("xcode_\(name)_failed"))
        }

        let archive = try buildSchemaResponse(command: "xcode.archive")
        let export = try buildSchemaResponse(command: "xcode.export")
        #expect(archive.commands.first?.subcommands.map(\.name) == ["archive"])
        #expect(export.commands.first?.subcommands.map(\.name) == ["export"])
        #expect(archive.commands.first?.providedCapabilities.contains("xcode-archive") == true)
        #expect(archive.commands.first?.providedCapabilities.contains("xcode-export") == true)
        #expect(export.commands.first?.providedCapabilities.contains("xcode-archive") == true)
        #expect(export.commands.first?.providedCapabilities.contains("xcode-export") == true)
    }

    @Test("archive and export failures keep one stable recovery envelope")
    func archiveAndExportFailuresKeepOneStableRecoveryEnvelope() throws {
        let archiveDetail = xcodeArchiveExportFailureDetail(
            action: "xcode.archive",
            archivePath: "artifacts/App.xcarchive",
            exportOptionsPlist: nil,
            exportPath: nil,
            stderr: "Code Sign error: No signing certificate found",
            stdout: ""
        )
        #expect(archiveDetail.code == "xcode_signing_failed")
        #expect(archiveDetail.nextAction?.command == "xcode")
        #expect(archiveDetail.nextAction?.args.contains("--allow-provisioning-updates") == true)

        let exportDetail = xcodeArchiveExportFailureDetail(
            action: "xcode.export",
            archivePath: "artifacts/App.xcarchive",
            exportOptionsPlist: "configs/ExportOptions.plist",
            exportPath: "artifacts/ipa",
            stderr: "error: exportArchive failed",
            stdout: ""
        )
        #expect(exportDetail.code == "xcode_export_failed")
        #expect(exportDetail.nextAction?.args.contains("--export-options-plist") == true)
        #expect(exportDetail.message.contains("exportArchive failed"))
    }

    @Test("xcode schemes accepts timeout and package resolution controls")
    func xcodeSchemesAcceptsTimeoutAndPackageResolutionControls() throws {
        let discover = try XcodeDiscover.parse([])
        #expect(discover.maxDepth == 8)

        let schemes = try XcodeSchemes.parse([
            "--project", "apps/ios/App.xcodeproj",
            "--timeout-seconds", "300",
            "--disable-automatic-package-resolution",
            "--json",
        ])

        #expect(schemes.timeoutSeconds == 300)
        #expect(schemes.disableAutomaticPackageResolution)

        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let timeout = try #require(xcode.options.first { $0.name == "--timeout-seconds" })
        #expect(timeout.defaultValue == "300")
        let subcommand = try #require(xcode.subcommands.first { $0.name == "schemes" })
        #expect(subcommand.optionalOptions.contains("--timeout-seconds"))
        #expect(subcommand.optionalOptions.contains("--disable-automatic-package-resolution"))
        #expect(subcommand.failureCodes.contains("xcode_schemes_timeout"))
        #expect(try validateXcodeSchemesTimeout(300) == 300)
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeSchemesTimeout(0)
        }
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeSchemesTimeout(.infinity)
        }
    }
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
            "EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64",
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
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeBuildSettings(["EXCLUDED_ARCHS[sdk=iphonesimulator*=x86_64"])
        }
        #expect(throws: ValidationError.self) {
            _ = try validateXcodeBuildSettings(["EXCLUDED_ARCHS[sdk=[iphonesimulator*]]=x86_64"])
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

    @Test("xcode test preserves repeatable focused XCTest selections as individual argv values")
    func xcodeTestPreservesRepeatableOnlyTestingSelections() throws {
        let selections = [
            "AppTests/LoginTests/testSubmit",
            "AppTests/SettingsTests",
        ]
        let test = try XcodeTest.parse([
            "--project", "App.xcodeproj",
            "--scheme", "App",
            "--only-testing", selections[0],
            "--only-testing", selections[1],
            "--jsonl",
        ])

        #expect(test.onlyTesting == selections)

        let command = TKXcodebuildCommand.test(
            workspace: nil,
            project: "App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            resultBundlePath: nil,
            onlyTesting: selections
        )
        let expectedArguments = ["test"] + selections.map { "-only-testing:\($0)" }

        #expect(command.argv.suffix(expectedArguments.count) == expectedArguments)
        let sourceCommand = hostSourceCommand(command)
        #expect(sourceCommand.contains("-only-testing:AppTests/LoginTests/testSubmit"))
        #expect(sourceCommand.contains("-only-testing:AppTests/SettingsTests"))

        let summary = TKXcodeActionSummary(
            ok: true,
            action: "xcode.test",
            workspace: nil,
            project: "App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData",
            onlyTesting: selections,
            durationMs: 1,
            sourceCommand: sourceCommand,
            exitCode: 0,
            stdoutTruncated: false,
            stderrTruncated: false
        )
        let json = try encodeJSON(summary)
        let jsonl = try encodeCompactJSON(summary)
        #expect(jsonl.split(whereSeparator: { $0.isNewline }).count == 1)
        for publicOutput in [json, jsonl] {
            let decoded = try JSONDecoder().decode(TKXcodeActionSummary.self, from: Data(publicOutput.utf8))
            #expect(decoded.onlyTesting == selections)
            #expect(decoded.sourceCommand.contains("-only-testing:AppTests/LoginTests/testSubmit"))
            #expect(decoded.sourceCommand.contains("-only-testing:AppTests/SettingsTests"))
        }

        let duplicate = try XcodeTest.parse([
            "--project", "App.xcodeproj",
            "--scheme", "App",
            "--only-testing", selections[0],
            "--only-testing", selections[0],
        ])
        #expect(duplicate.onlyTesting == [selections[0], selections[0]])
    }

    @Test("xcode focused XCTest selection is scoped to test in parser and schema")
    func xcodeFocusedXCTestSelectionIsScopedToTest() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let option = try #require(xcode.options.first { $0.name == "--only-testing" })
        #expect(option.type == "String[]")
        #expect(option.description.contains("xcode test"))
        #expect(option.description.contains("sourceCommand"))
        #expect(xcode.examples.contains {
            $0.contains("triton xcode test") && $0.contains("--only-testing")
        })

        let testSchema = try #require(xcode.subcommands.first { $0.name == "test" })
        #expect(testSchema.optionalOptions.contains("--only-testing"))
        for name in ["settings", "build", "run"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == name })
            #expect(!subcommand.optionalOptions.contains("--only-testing"))
        }

        let scoped = try buildSchemaResponse(command: "xcode.test")
        let scopedXcode = try #require(scoped.commands.first)
        #expect(scopedXcode.subcommands.map(\.name) == ["test"])
        #expect(scopedXcode.subcommands.first?.optionalOptions.contains("--only-testing") == true)
        let final = try #require(scopedXcode.outputContracts.first { $0.selector == "xcode.final" })
        #expect(final.fields.first { $0.name == "onlyTesting" }?.required == false)
    }

    @Test("xcode focused XCTest selection rejects unsafe identifiers with one validation envelope")
    func xcodeFocusedXCTestSelectionRejectsUnsafeIdentifiersWithOneValidationEnvelope() throws {
        let unsafeValues = ["", "  \n", " AppTests/LoginTests", "AppTests/LoginTests ", "AppTests/Bad\u{0000}Name", "-skip-testing:AppTests"]
        for value in unsafeValues {
            #expect(throws: ValidationError.self) {
                _ = try validateXcodeOnlyTesting([value])
            }
        }

        let invalidArguments = [
            ["--only-testing", ""],
            ["--only-testing", " AppTests/LoginTests"],
            ["--only-testing", "AppTests/LoginTests "],
            ["--only-testing=-skip-testing:AppTests"],
        ]
        for arguments in invalidArguments {
            let result = try runXcodeTriton(["xcode", "test"] + arguments + ["--json"])

            #expect(result.exitCode != 0)
            #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let response = try JSONDecoder().decode(TKCLIErrorResponse.self, from: Data(result.stdout.utf8))
            #expect(response.ok == false)
            #expect(response.error.code == "validation_failed")
            #expect(response.error.message.contains("--only-testing"))
        }
    }

    @Test("xcode subprocess test fixes triton to its current test-bundle sibling, not older build decoys")
    func xcodeSubprocessTritonCandidateRejectsOlderBuildDecoys() throws {
        let currentBundle = URL(fileURLWithPath: "/private/tmp/sp139/current/arm64-apple-macosx/debug/TritonKitCLIPackageTests.xctest")
        let currentTestExecutable = currentBundle
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("TritonKitCLIPackageTests", isDirectory: false)
        let candidate = try #require(xcodeTritonExecutableCandidate(testBundleURL: currentBundle))
        let executableCandidate = try #require(xcodeTritonExecutableCandidate(testBundleURL: currentTestExecutable))
        let parentDecoy = URL(fileURLWithPath: "/private/tmp/sp139/current/arm64-apple-macosx/triton")
        let staleScratchDecoy = URL(fileURLWithPath: "/private/tmp/sp139/stale/arm64-apple-macosx/debug/triton")

        #expect(candidate.path == "/private/tmp/sp139/current/arm64-apple-macosx/debug/triton")
        #expect(executableCandidate == candidate)
        #expect(candidate != parentDecoy)
        #expect(candidate != staleScratchDecoy)
        #expect(xcodeTritonExecutableCandidate(testBundleURL: URL(fileURLWithPath: "/private/tmp/sp139/current/unknown-test-runner")) == nil)
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

    @Test("xcode real-device selector resolves iphoneos without a generic fallback destination")
    func xcodeDeviceSelectorDefersRealDeviceDestinationUntilPreflight() throws {
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
        #expect(destination == nil)
    }

    @Test("xcode real-device preflight uses raw target only for argv and redacts public invocation")
    func xcodeRealDevicePreflightUsesRawTargetOnlyForExecution() throws {
        let rawTarget = "00008110-RAW-DEVICE-ID"
        let otherPhysicalName = "Other - Private Phone"
        let publicTarget = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:public-id",
            target: "ios-real:public-target",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "Public Device Name",
            runtime: "iOS 26.5",
            transport: "usb",
            scope: "real",
            kind: "real-device",
            rawTarget: rawTarget,
            rawTargetAliases: ["PUBLIC-ALTERNATE-ID"]
        )
        let selection = HostDeviceSelectionResult(
            platform: .ios,
            target: publicTarget,
            selector: "team-phone",
            source: .alias,
            filters: HostDeviceSelectionFilters(
                request: HostDeviceSelectionRequest(
                    device: "team-phone",
                    platform: .ios,
                    scope: .real,
                    ready: true
                )
            )
        )
        let invocation = ResolvedXcodeInvocation(
            workspace: "App.xcworkspace",
            project: nil,
            package: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: nil,
            derivedDataPath: ".triton/DerivedData",
            buildSettings: [],
            derivedDataCache: testXcodeDerivedDataCache(),
            simulatorUDID: nil,
            device: "team-phone"
        )

        let prepared = try prepareXcodeRealDeviceInvocation(
            invocation: invocation,
            resolveSelection: { selection }
        )
        let command = TKXcodebuildCommand.build(
            workspace: prepared.invocation.workspace,
            project: prepared.invocation.project,
            package: prepared.invocation.package,
            scheme: prepared.invocation.scheme,
            configuration: prepared.invocation.configuration,
            sdk: prepared.invocation.sdk,
            destination: prepared.invocation.xcodebuildDestination,
            derivedDataPath: prepared.invocation.derivedDataPath,
            buildSettings: prepared.invocation.buildSettings,
            redactDestination: prepared.invocation.redactsXcodebuildDestination
        )
        let encodedInvocation = String(
            decoding: try JSONEncoder().encode(prepared.invocation),
            as: UTF8.self
        )
        let sourceCommand = hostSourceCommand(command)
        let diagnosticsResult = HostProcessResult(
            stdoutData: Data("Stale file '/tmp/\(rawTarget)/.triton/DerivedData/App' is located outside of the allowed root paths".utf8),
            stderrData: Data(),
            exitCode: 1,
            sourceCommand: sourceCommand,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: 0,
            stderrBytes: 0
        )
        let diagnostics = try #require(xcodeBuildOutputDiagnostics(diagnosticsResult, redacting: command))
        let encodedDiagnostics = String(
            decoding: try JSONEncoder().encode(diagnostics),
            as: UTF8.self
        )
        let redactedFailureResult = redactedXcodePublicProcessResult(diagnosticsResult, command: command)
        let redactedFailureMessage = String(describing: HostCommandRunError.nonZeroExit(
            command: command,
            result: redactedFailureResult
        ))
        let streamSample = streamingSample(
            stream: "stderr",
            data: Data("target=\(rawTarget)".utf8),
            redacting: command
        )
        let postActionStatus = redactedXcodePostActionProcessStatus(
            TKXcodePostActionProcessStatus(
                active: true,
                processes: [
                    TKXcodeActiveProcessSummary(
                        pid: 1,
                        name: "xcodebuild",
                        commandLine: "xcodebuild -destination platform=iOS,id=\(rawTarget)",
                        destination: "platform=iOS,id=\(rawTarget)",
                        confidence: "medium"
                    ),
                    TKXcodeActiveProcessSummary(
                        pid: 2,
                        name: "xcodebuild",
                        commandLine: "xcodebuild -destination platform=iOS,name=\(otherPhysicalName) test",
                        destination: "platform=iOS,name=\(otherPhysicalName)",
                        confidence: "medium"
                    )
                ],
                sourceCommand: "ps xcodebuild \(rawTarget) \(otherPhysicalName)"
            ),
            command: command
        )
        let encodedPostActionStatus = String(
            decoding: try JSONEncoder().encode(postActionStatus),
            as: UTF8.self
        )

        #expect(command.argv.contains("platform=iOS,id=\(rawTarget)"))
        #expect(!command.argv.contains("generic/platform=iOS"))
        #expect(prepared.invocation.destination == "platform=iOS,id=<redacted>")
        #expect(prepared.invocation.device == "<redacted>")
        for forbidden in [rawTarget, otherPhysicalName, "- Private Phone", publicTarget.id, publicTarget.target, publicTarget.name!, publicTarget.rawTargetAliases[0]] {
            #expect(!encodedInvocation.contains(forbidden))
            #expect(!sourceCommand.contains(forbidden))
            #expect(!encodedDiagnostics.contains(forbidden))
            #expect(!redactedFailureMessage.contains(forbidden))
            #expect(!streamSample.contains(forbidden))
            #expect(!encodedPostActionStatus.contains(forbidden))
        }
    }

    @Test("xcode real-device preflight blocks settings build test and run closures before xcodebuild")
    func xcodeRealDevicePreflightBlocksEveryXcodeActionBeforeBuild() throws {
        let request = HostDeviceSelectionRequest(
            device: "missing-alias",
            platform: .ios,
            scope: .real,
            ready: true
        )

        for action in ["settings", "build", "test", "run"] {
            var xcodebuildCalled = false
            do {
                _ = try runXcodeRealDevicePreflightThenBuild(
                    resolveSelection: {
                        try resolveHostDeviceSelection(
                            request: request,
                            candidates: [.ios: []],
                            aliases: .empty
                        )
                    },
                    build: {
                        xcodebuildCalled = true
                        return action
                    }
                )
                Issue.record("Expected \(action) real-device preflight to reject the missing selector")
            } catch HostDeviceSelectionError.targetNotFound(let selector) {
                #expect(selector == "missing-alias")
            } catch {
                Issue.record("Unexpected \(action) preflight error: \(error)")
            }
            #expect(!xcodebuildCalled)
        }
    }

    @Test("xcode process status redacts every physical destination before public encoding")
    func xcodeProcessStatusRedactsAllRealDeviceDestinations() throws {
        let primaryRawTarget = "00008110-PRIMARY-RAW-TARGET"
        let otherPhysicalName = "Other - Private Phone"
        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: """
          101 /usr/bin/xcodebuild 00:30 xcodebuild -workspace App.xcworkspace -destination platform=iOS,id=\(primaryRawTarget) build
          102 /usr/bin/xcodebuild 00:30 xcodebuild -workspace App.xcworkspace -destination platform=iOS,name=\(otherPhysicalName) test
        """)
        let encoded = String(decoding: try JSONEncoder().encode(status), as: UTF8.self)

        #expect(status.processes.map(\.destination) == [
            "platform=iOS,id=<redacted>",
            "platform=iOS,id=<redacted>",
        ])
        #expect(!encoded.contains(primaryRawTarget))
        #expect(!encoded.contains(otherPhysicalName))
        #expect(!encoded.contains("- Private Phone"))
    }

    @Test("xcode parsed unquoted physical name stays redacted in post-action status")
    func xcodeUnquotedPhysicalNameStaysRedactedInPostActionStatus() throws {
        let rawTarget = "00008110-POST-ACTION-RAW-TARGET"
        let otherPhysicalName = "Other - Private Phone"
        let command = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            package: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: "platform=iOS,id=\(rawTarget)",
            derivedDataPath: ".triton/DerivedData",
            buildSettings: [],
            redactDestination: true
        )
        let status = try XcodeProcessDiagnosticsParser.parse(psOutput: """
          102 /usr/bin/xcodebuild 00:30 xcodebuild -workspace App.xcworkspace -destination platform=iOS,name=\(otherPhysicalName) test
        """)
        let postActionStatus = redactedXcodePostActionProcessStatus(
            status.sharedPostActionStatus(),
            command: command
        )
        let encoded = String(
            decoding: try JSONEncoder().encode(postActionStatus),
            as: UTF8.self
        )

        #expect(!encoded.contains(otherPhysicalName))
        #expect(!encoded.contains("- Private Phone"))
    }

    @Test("xcode real-device devicectl discovery nonzero output is redacted in public JSON and JSONL envelopes")
    func xcodeRealDeviceDevicectlDiscoveryFailureRedactsPublicOutput() throws {
        let rawTarget = "00008110-DEVICectl-RAW-TARGET"
        let selector = "private-team-phone"
        let command = TKDevicectlCommand.listDevices(
            jsonOutput: "/tmp/triton-devicectl-list.json",
            logOutput: "/tmp/triton-devicectl-list.log"
        )
        let result = HostProcessResult(
            stdoutData: Data("{\"identifier\":\"\(rawTarget)\"}".utf8),
            stderrData: Data("devicectl failed for \(rawTarget) selector=\(selector)".utf8),
            exitCode: 1,
            sourceCommand: hostSourceCommand(command),
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: 0,
            stderrBytes: 0
        )

        #expect(command.executable == "xcrun")
        let captured = captureXcodeCommandOutputAllowingFailure {
            try failXcodeCommand(
                HostCommandRunError.nonZeroExit(command: command, result: result),
                device: selector,
                outputFormat: .json
            )
        }
        #expect(captured.error is ExitCode)

        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: Data(captured.output.utf8)
        )
        let jsonl = try encodeCompactJSON(response)
        #expect(jsonl.split(whereSeparator: { $0.isNewline }).count == 1)
        for publicOutput in [captured.output, jsonl] {
            #expect(publicOutput.contains("<redacted devicectl discovery output>"))
            #expect(!publicOutput.contains(rawTarget))
            #expect(!publicOutput.contains(selector))
        }
    }

    @Test("xcode nonzero output redacts an unquoted physical name in public JSON and JSONL envelopes")
    func xcodeNonzeroFailureRedactsUnquotedPhysicalName() throws {
        let rawTarget = "00008110-NONZERO-RAW-TARGET"
        let otherPhysicalName = "P1 - Private Phone Tail"
        let command = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            package: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: "platform=iOS,id=\(rawTarget)",
            derivedDataPath: ".triton/DerivedData",
            buildSettings: [],
            redactDestination: true
        )
        let result = HostProcessResult(
            stdoutData: Data("xcodebuild -destination platform=iOS,name=\(otherPhysicalName) build".utf8),
            stderrData: Data("failed destination platform=iOS,name=\(otherPhysicalName) test".utf8),
            exitCode: 1,
            sourceCommand: hostSourceCommand(command),
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: nil,
            stderrLogPath: nil,
            stdoutBytes: 0,
            stderrBytes: 0
        )

        let captured = captureXcodeCommandOutputAllowingFailure {
            try failXcodeCommand(
                HostCommandRunError.nonZeroExit(command: command, result: result),
                device: "private-team-phone",
                outputFormat: .json
            )
        }
        #expect(captured.error is ExitCode)

        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: Data(captured.output.utf8)
        )
        let jsonl = try encodeCompactJSON(response)
        for publicOutput in [captured.output, jsonl] {
            #expect(publicOutput.contains("platform=iOS,id=<redacted>"))
            #expect(!publicOutput.contains(otherPhysicalName))
            #expect(!publicOutput.contains("- Private Phone Tail"))
        }
    }

    @Test("xcode public destination redaction preserves Simulator name form")
    func xcodePublicDestinationRedactionPreservesSimulatorName() {
        let simulatorDestination = "platform=iOS Simulator,name=Private Simulator Name"
        let publicText = redactedXcodePublicText(
            "xcodebuild -destination \(simulatorDestination) test",
            command: TKHostCommand(arguments: ["xcodebuild"])
        )

        #expect(publicText.contains(simulatorDestination))
    }

    @Test("xcode public name redaction never changes the execution argv")
    func xcodePublicNameRedactionNeverChangesExecutionArguments() {
        let rawTarget = "00008110-EXECUTION-RAW-TARGET"
        let executionDestination = "platform=iOS,id=\(rawTarget)"
        let physicalName = "P1 - Private Phone Tail"
        let command = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            package: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: executionDestination,
            derivedDataPath: ".triton/DerivedData",
            buildSettings: [],
            redactDestination: true
        )
        let publicText = redactedXcodePublicText(
            "xcodebuild -destination platform=iOS,name=\(physicalName) test",
            command: command
        )

        #expect(command.argv.contains(executionDestination))
        #expect(!publicText.contains(physicalName))
        #expect(!publicText.contains("- Private Phone Tail"))
    }

    @Test("xcode public name redaction handles apostrophes without leaking a tail")
    func xcodePublicNameRedactionHandlesApostrophes() {
        let physicalName = "Alice's - Private Phone"
        let publicText = redactedXcodePublicText(
            "couldn't resolve destination platform=iOS,name=\(physicalName) test",
            command: TKHostCommand(arguments: ["xcodebuild"])
        )

        #expect(!publicText.contains(physicalName))
        #expect(!publicText.contains("s - Private Phone"))
    }

    @Test("xcode test inline xcresult details redact the execution-only device target")
    func xcodeTestInlineXcresultDetailsRedactRawTarget() throws {
        let rawTarget = "00008110-XCRESULT-RAW-TARGET"
        let command = TKXcodebuildCommand.test(
            workspace: "App.xcworkspace",
            project: nil,
            package: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: "platform=iOS,id=\(rawTarget)",
            derivedDataPath: ".triton/DerivedData",
            resultBundlePath: nil,
            buildSettings: [],
            redactDestination: true
        )
        let summary = """
        {
          "title": "AppTests",
          "startTime": 10.0,
          "finishTime": 12.5,
          "environmentDescription": "iPhone target=\(rawTarget)",
          "topInsights": [],
          "result": "Failed",
          "totalTestCount": 1,
          "passedTests": 0,
          "failedTests": 1,
          "skippedTests": 0,
          "expectedFailures": 0,
          "statistics": []
        }
        """
        let tests = """
        {
          "testPlanConfigurations": [],
          "devices": [],
          "testNodes": [
            {
              "nodeIdentifier": "bundle-1",
              "nodeType": "Unit test bundle",
              "name": "AppTests",
              "children": [
                {
                  "nodeIdentifier": "case-1",
                  "nodeType": "Test Case",
                  "name": "testLogin()",
                  "children": [
                    {
                      "nodeIdentifier": "run-1",
                      "nodeType": "Test Case Run",
                      "name": "testLogin()",
                      "result": "Failed",
                      "children": [
                        {
                          "nodeIdentifier": "failure-1",
                          "nodeType": "Failure Message",
                          "name": "XCTAssertEqual failed",
                          "details": "target=\(rawTarget)"
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """
        func result(_ stdout: String) -> HostProcessResult {
            let data = Data(stdout.utf8)
            return HostProcessResult(
                stdoutData: data,
                stderrData: Data(),
                exitCode: 0,
                sourceCommand: "xcrun xcresulttool \(rawTarget)",
                stdoutTruncated: false,
                stderrTruncated: false,
                stdoutLogPath: nil,
                stderrLogPath: nil,
                stdoutBytes: data.count,
                stderrBytes: 0
            )
        }

        let details = xcodeTestResultBundleDetails(
            resultBundlePath: "/tmp/App.xcresult",
            redacting: command
        ) { xcresultCommand in
            result(xcresultCommand.arguments.contains("summary") ? summary : tests)
        }
        let publicDetails = [
            details.summary?.environmentDescription,
            details.topFailures?.first?.message,
            details.note,
        ].compactMap { $0 }.joined(separator: "\n")
        #expect(!publicDetails.contains(rawTarget))
        #expect(details.summary?.environmentDescription.contains("<redacted>") == true)
        #expect(details.topFailures?.first?.message.contains("<redacted>") == true)

        let failedDetails = xcodeTestResultBundleDetails(
            resultBundlePath: "/tmp/App.xcresult",
            redacting: command
        ) { _ in
            throw XcodeWorkflowError.bundleIDUnresolved(rawTarget)
        }
        #expect(failedDetails.note?.contains(rawTarget) == false)
        #expect(failedDetails.note?.contains("<redacted>") == true)
    }

    @Test("xcode real-device preflight rejects a missing selector before build")
    func xcodeRealDevicePreflightRejectsMissingSelectorBeforeBuild() throws {
        let request = HostDeviceSelectionRequest(
            device: "missing-alias",
            platform: .ios,
            scope: .real,
            ready: true
        )
        var buildCalled = false

        do {
            _ = try runXcodeRealDevicePreflightThenBuild(
                resolveSelection: {
                    try resolveHostDeviceSelection(
                        request: request,
                        candidates: [.ios: []],
                        aliases: .empty
                    )
                },
                build: {
                    buildCalled = true
                    return "build-called"
                }
            )
            Issue.record("Expected target preflight to reject the missing selector")
        } catch HostDeviceSelectionError.targetNotFound(let selector) {
            #expect(selector == "missing-alias")
        } catch {
            Issue.record("Unexpected target preflight error: \(error)")
        }

        #expect(!buildCalled)
    }

    @Test("xcode real-device selection failure emits contextual target recovery")
    func xcodeRealDeviceSelectionFailureEmitsContextualTargetRecovery() throws {
        let rawSelector = "00008110-RAW-SELECTOR"
        let detail = xcodeRealDeviceSelectionErrorDetail(
            .targetNotFound(rawSelector),
            selector: rawSelector
        )

        #expect(detail.code == "target_not_found")
        #expect(detail.nextAction?.command == "target")
        #expect(detail.nextAction?.args == [
            "resolve", "<selector>", "--platform", "ios", "--scope", "real", "--ready", "--json",
        ])
        #expect(detail.nextAction?.category == "prepare-target")

        let response = try JSONDecoder().decode(
            TKCLIErrorResponse.self,
            from: JSONEncoder().encode(TKCLIErrorResponse(error: detail))
        )
        #expect(response.ok == false)
        #expect(response.error == detail)
        let encoded = String(decoding: try JSONEncoder().encode(response), as: UTF8.self)
        #expect(!encoded.contains(rawSelector))
    }

    @Test("xcode real-device preflight maps every target failure to contextual recovery")
    func xcodeRealDevicePreflightFailureFamilyUsesContextualRecovery() {
        let candidate = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:public-id",
            target: "ios-real:public-target",
            state: "connected",
            ready: false,
            source: "devicectl",
            name: "Public Device Name",
            runtime: "iOS 26.5",
            transport: "usb",
            scope: "real",
            kind: "real-device",
            rawTarget: "00008110-PRIVATE"
        )
        let failures: [(error: Error, code: String)] = [
            (HostDeviceSelectionError.targetNotFound("team-phone"), "target_not_found"),
            (HostDeviceSelectionError.ambiguousTargets([candidate]), "ambiguous_target"),
            (HostDeviceSelectionError.platformMismatch(selector: "team-phone", expected: .ios, actual: .android), "target_platform_mismatch"),
            (HostCommandRunError.deviceNotReady(target: candidate.target, timeoutSeconds: 0), "device_not_ready"),
        ]

        for failure in failures {
            let detail = xcodeRealDevicePreflightErrorDetail(failure.error, selector: "team-phone")
            let encoded = String(
                decoding: try! JSONEncoder().encode(TKCLIErrorResponse(error: detail)),
                as: UTF8.self
            )
            #expect(detail.code == failure.code)
            #expect(detail.nextAction?.command == "target")
            #expect(detail.nextAction?.args == [
                "resolve", "<selector>", "--platform", "ios", "--scope", "real", "--ready", "--json",
            ])
            #expect(detail.nextAction?.category == "prepare-target")
            #expect(!encoded.contains(candidate.rawTarget))
            #expect(!encoded.contains("\"candidates\""))
        }
    }

    @Test("xcode real-device argument conflicts do not suggest target resolution")
    func xcodeRealDeviceArgumentConflictKeepsParameterRecoveryLocal() {
        let detail = xcodeRealDevicePreflightErrorDetail(
            HostDeviceSelectionError.parameterConflict("--device conflicts with --destination"),
            selector: "team-phone"
        )

        #expect(detail.code == "parameter_conflict")
        #expect(detail.nextAction == nil)
    }

    @Test("xcode real-device arguments reject destination simulator and non-iphoneos SDK")
    func xcodeRealDeviceArgumentsRejectConflictingTargetsAndSDK() throws {
        func assertParameterConflict(
            destination: String? = nil,
            simulator: String? = nil
        ) {
            do {
                _ = try resolveXcodeInvocation(
                    workspace: "App.xcworkspace",
                    scheme: "App",
                    destination: destination,
                    simulator: simulator,
                    device: "team-phone"
                )
                Issue.record("Expected real-device target parameter conflict")
            } catch let error as HostDeviceSelectionError {
                guard case .parameterConflict = error else {
                    Issue.record("Expected parameter_conflict, got \(error)")
                    return
                }
            } catch {
                Issue.record("Unexpected target parameter error: \(error)")
            }
        }

        assertParameterConflict(destination: "platform=iOS,id=EXPLICIT")
        assertParameterConflict(simulator: "SIM-1")

        #expect(throws: ValidationError.self) {
            _ = try resolveXcodeInvocation(
                workspace: "App.xcworkspace",
                scheme: "App",
                sdk: "iphonesimulator",
                device: "team-phone"
            )
        }
        #expect(throws: ValidationError.self) {
            _ = try resolveXcodeInvocation(
                workspace: "App.xcworkspace",
                scheme: "App",
                sdk: "iphoneos",
                destination: "platform=iOS,id=00008110-RAW-BYPASS"
            )
        }
        #expect(throws: ValidationError.self) {
            _ = try resolveXcodeInvocation(
                workspace: "App.xcworkspace",
                scheme: "App",
                sdk: "iphoneos"
            )
        }
        #expect(throws: ValidationError.self) {
            _ = try resolveXcodeInvocation(
                workspace: "App.xcworkspace",
                scheme: "App",
                sdk: "iphoneos18.0"
            )
        }
        let valid = try resolveXcodeInvocation(
            workspace: "App.xcworkspace",
            scheme: "App",
            sdk: "iPhoneOS18.0",
            device: "team-phone"
        )
        #expect(valid.sdk == "iphoneos")
        #expect(valid.destination == nil)
    }

    @Test("xcode real-device preflight never falls back to public identity or generic destination")
    func xcodeRealDevicePreflightUsesOnlyRawTargetForDestination() throws {
        let rawTarget = "00008110-UNIQUE-RAW-TARGET"
        let target = HostDeviceTarget(
            platform: "ios",
            id: "ios-real:abc123",
            target: "ios-real:abc123",
            state: "connected",
            ready: true,
            source: "devicectl",
            name: "Lin iPhone",
            runtime: "iOS 26.5",
            transport: "usb",
            scope: "real",
            kind: "real-device",
            rawTarget: rawTarget,
            rawTargetAliases: ["ALTERNATE-RAW-TARGET"]
        )
        let request = HostDeviceSelectionRequest(
            device: "iphone15",
            platform: .ios,
            scope: .real,
            ready: true
        )
        let aliases = HostTargetAliasStore(
            aliases: [
                "iphone15": HostTargetAlias(platform: .ios, target: "ios-real:abc123")
            ]
        )
        let invocation = ResolvedXcodeInvocation(
            workspace: "App.xcworkspace",
            project: nil,
            package: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: nil,
            derivedDataPath: ".triton/DerivedData",
            buildSettings: [],
            derivedDataCache: testXcodeDerivedDataCache(),
            simulatorUDID: nil,
            device: "iphone15"
        )
        let selection = try resolveHostDeviceSelection(
            request: request,
            candidates: [.ios: [target]],
            aliases: aliases
        )
        let prepared = try prepareXcodeRealDeviceInvocation(
            invocation: invocation,
            resolveSelection: {
                selection
            }
        )
        let build = TKXcodebuildCommand.build(
            workspace: prepared.invocation.workspace,
            project: prepared.invocation.project,
            package: prepared.invocation.package,
            scheme: prepared.invocation.scheme,
            configuration: prepared.invocation.configuration,
            sdk: prepared.invocation.sdk,
            destination: prepared.invocation.xcodebuildDestination,
            derivedDataPath: prepared.invocation.derivedDataPath,
            buildSettings: prepared.invocation.buildSettings,
            redactDestination: prepared.invocation.redactsXcodebuildDestination
        )

        #expect(prepared.selection.source == .alias)
        #expect(prepared.selection.target == target)
        #expect(build.argv.contains("platform=iOS,id=\(rawTarget)"))
        #expect(!build.argv.contains("generic/platform=iOS"))
        #expect(!build.argv.contains(target.id))
        #expect(!build.argv.contains(target.target))
        #expect(!build.argv.contains(target.name!))
        #expect(!build.argv.contains(target.rawTargetAliases[0]))
    }

    @Test("xcode schemas declare target selection failures and recovery")
    func xcodeSchemasDeclareTargetSelectionFailuresAndRecovery() throws {
        let schemas = commandSchemas()
        let xcode = try #require(schemas.first { $0.name == "xcode" })
        let target = try #require(schemas.first { $0.name == "target" })
        let genericRecovery = "triton target resolve <selector> --json"
        let realDeviceRecovery = "triton target resolve <selector> --platform ios --scope real --ready --json"

        for code in ["target_not_found", "ambiguous_target", "target_platform_mismatch", "device_not_ready", "parameter_conflict"] {
            #expect(xcode.failureCodes.contains(code))
        }
        #expect(xcode.nextCommands.contains(realDeviceRecovery))
        #expect(xcode.nextCommands.contains(genericRecovery) == false)
        #expect(xcode.recoveryCommands.map(\.command).contains(realDeviceRecovery))
        for action in ["settings", "build", "test", "run"] {
            let subcommand = try #require(xcode.subcommands.first { $0.name == action })
            for code in ["target_not_found", "ambiguous_target", "target_platform_mismatch", "device_not_ready", "parameter_conflict"] {
                #expect(subcommand.failureCodes.contains(code))
            }
            #expect(subcommand.nextCommands.contains(realDeviceRecovery))
            #expect(subcommand.nextCommands.contains(genericRecovery) == false)
            #expect(subcommand.recoveryCommands.map(\.command).contains(realDeviceRecovery))
        }
        #expect(target.nextCommands.contains(genericRecovery))
        #expect(target.recoveryCommands.map(\.command).contains(genericRecovery))
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

    @Test("xcode run explicit simulator destination replaces stale default lifecycle target")
    func xcodeRunExplicitDestinationReplacesStaleDefaultLifecycleTarget() throws {
        let fileManager = FileManager.default
        let originalDirectory = fileManager.currentDirectoryPath
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("triton-xcode-run-target-binding-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            _ = fileManager.changeCurrentDirectoryPath(originalDirectory)
            try? fileManager.removeItem(at: temporaryDirectory)
        }
        #expect(fileManager.changeCurrentDirectoryPath(temporaryDirectory.path))

        let requestedSimulator = "60667794-96F8-40E6-8664-85538EC4663E"
        let staleSimulator = "E7E55388-E507-4021-A4E4-78C81F420533"
        _ = try saveHostWorkspaceDefaults(
            TKHostWorkspaceDefaults(
                defaultSimulatorUDID: staleSimulator,
                xcode: TKXcodeWorkspaceDefaults(
                    workspace: "App.xcworkspace",
                    scheme: "App",
                    destination: "platform=iOS Simulator,id=\(staleSimulator)"
                )
            )
        )

        let invocation = try resolveXcodeInvocation(
            destination: "platform=iOS Simulator,id=\(requestedSimulator)",
            requireConcreteSimulatorTarget: true
        )

        #expect(invocation.destination == "platform=iOS Simulator,id=\(requestedSimulator)")
        #expect(invocation.simulatorUDID == requestedSimulator)

        let simulatorInvocation = try resolveXcodeInvocation(
            simulator: requestedSimulator,
            requireConcreteSimulatorTarget: true
        )
        #expect(simulatorInvocation.destination == "platform=iOS Simulator,id=\(requestedSimulator)")
        #expect(simulatorInvocation.simulatorUDID == requestedSimulator)

        var buildTargets: [String] = []
        var settingsTargets: [String] = []
        var lifecycleCommands: [(event: String, command: TKHostCommand)] = []
        let summary = try runXcodeBuildInstallLaunch(
            invocation: invocation,
            jsonl: true,
            simulatorBuild: { invocation, _, _ in
                buildTargets.append(try resolvedXcodeRunSimulatorTarget(invocation))
                return TKXcodeActionSummary(
                    ok: true,
                    action: "xcode.build",
                    workspace: invocation.workspace,
                    project: invocation.project,
                    package: invocation.package,
                    scheme: invocation.scheme,
                    configuration: invocation.configuration,
                    sdk: invocation.sdk,
                    destination: invocation.destination,
                    derivedDataPath: invocation.derivedDataPath,
                    simulatorUDID: invocation.simulatorUDID,
                    durationMs: 10,
                    sourceCommand: "xcodebuild -destination 'platform=iOS Simulator,id=\(requestedSimulator)' build",
                    exitCode: 0,
                    stdoutTruncated: false,
                    stderrTruncated: false
                )
            },
            simulatorProduct: { invocation, _, _, event in
                #expect(event == "xcode.run.settings")
                settingsTargets.append(try resolvedXcodeRunSimulatorTarget(invocation))
                return TKXcodeBuiltAppProduct(
                    target: "App",
                    appPath: "/tmp/App.app",
                    bundleID: "com.example.fixture"
                )
            },
            simulatorHostCommand: { command, event, _ in
                lifecycleCommands.append((event: event, command: command))
                let sourceCommand = hostSourceCommand(command)
                return (
                    HostProcessResult(
                        stdoutData: Data(),
                        stderrData: Data(),
                        exitCode: 0,
                        sourceCommand: sourceCommand,
                        stdoutTruncated: false,
                        stderrTruncated: false,
                        stdoutLogPath: nil,
                        stderrLogPath: nil,
                        stdoutBytes: 0,
                        stderrBytes: 0
                    ),
                    5
                )
            }
        )

        #expect(buildTargets == [requestedSimulator])
        #expect(settingsTargets == [requestedSimulator])
        #expect(lifecycleCommands.map(\.event) == ["xcode.run.install", "xcode.run.launch"])
        #expect(lifecycleCommands.allSatisfy { $0.command.arguments.contains(requestedSimulator) })
        #expect(lifecycleCommands.allSatisfy { !$0.command.arguments.contains(staleSimulator) })
        #expect(summary.destination == "platform=iOS Simulator,id=\(requestedSimulator)")
        #expect(summary.simulatorUDID == requestedSimulator)
        #expect(summary.sourceCommand.contains(requestedSimulator))
        #expect(!summary.sourceCommand.contains(staleSimulator))
        #expect(summary.nextActions?.first?.args.contains("\(TKIOSSimulatorRuntimeTargetPrefix)\(requestedSimulator)/app:com.example.fixture") == true)
    }

    @Test("xcode run fails before build when destination has no unique simulator id")
    func xcodeRunRejectsDestinationWithoutUniqueSimulatorID() throws {
        let unsupportedDestinations = [
            "generic/platform=iOS Simulator",
            "platform=iOS Simulator,name=iPhone 17",
            "platform=iOS Simulator,id=SIM-A,id=SIM-B",
            "platform=iOS,id=DEVICE-A",
        ]

        for destination in unsupportedDestinations {
            do {
                _ = try resolveXcodeInvocation(
                    workspace: "App.xcworkspace",
                    scheme: "App",
                    destination: destination,
                    requireConcreteSimulatorTarget: true
                )
                Issue.record("Expected run target preflight to reject \(destination)")
            } catch XcodeWorkflowError.simulatorDestinationTargetUnresolved {
                // Expected before any build runner can be called.
            } catch {
                Issue.record("Unexpected run target preflight error: \(error)")
            }
        }

        #expect(xcodeSimulatorTargetID(from: "platform=iOS Simulator,id=SIM-A") == "SIM-A")
        #expect(xcodeSimulatorTargetID(from: "generic/platform=iOS Simulator,id=SIM-A,OS=latest") == "SIM-A")
        #expect(xcodeSimulatorTargetID(from: unsupportedDestinations[0]) == nil)
        #expect(xcodeSimulatorTargetID(from: unsupportedDestinations[1]) == nil)
        #expect(xcodeSimulatorTargetID(from: unsupportedDestinations[2]) == nil)
        #expect(xcodeSimulatorTargetID(from: unsupportedDestinations[3]) == nil)

        let failure = captureXcodeCommandOutputAllowingFailure {
            try failXcodeCommand(
                XcodeWorkflowError.simulatorDestinationTargetUnresolved,
                device: nil,
                outputFormat: .json
            )
        }
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(failure.output.utf8)) as? [String: Any]
        )
        let error = try #require(object["error"] as? [String: Any])
        #expect(error["code"] as? String == "xcode_run_target_unresolved")
        #expect((error["hint"] as? String)?.contains("--simulator <udid>") == true)

        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let run = try #require(xcode.subcommands.first { $0.name == "run" })
        #expect(xcode.failureCodes.contains("xcode_run_target_unresolved"))
        #expect(run.failureCodes.contains("xcode_run_target_unresolved"))
        #expect(xcode.options.first { $0.name == "--destination" }?.description.contains("build/settings/install/launch/readiness") == true)
    }

    @Test("xcode real-device selector defers an explicit destination to preflight validation")
    func explicitDestinationDoesNotOverrideDevicePreflight() throws {
        let destination = resolvedXcodeDestination(
            destination: "platform=iOS,id=RAW-UDID",
            defaultDestination: "platform=iOS Simulator,id=SIM-1",
            simulatorUDID: nil,
            device: "ios-real:abc123"
        )

        #expect(destination == nil)
    }
}

private func captureXcodeCommandOutputAllowingFailure(
    _ body: () throws -> Void
) -> (output: String, error: Error?) {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    var caughtError: Error?

    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    do {
        try body()
    } catch {
        caughtError = error
    }
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (String(decoding: data, as: UTF8.self), caughtError)
}

private struct XcodeCLIRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func runXcodeTriton(_ arguments: [String]) throws -> XcodeCLIRunResult {
    let process = Process()
    process.executableURL = try xcodeTritonExecutableURL()
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    return XcodeCLIRunResult(
        exitCode: process.terminationStatus,
        stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
        stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func xcodeTritonExecutableURL() throws -> URL {
    guard let testBundleURL = xcodeTestBundleURL() else {
        throw missingXcodeTritonExecutableError()
    }
    guard let candidate = xcodeTritonExecutableCandidate(testBundleURL: testBundleURL),
          FileManager.default.isExecutableFile(atPath: candidate.path) else {
        throw missingXcodeTritonExecutableError()
    }
    return candidate
}

private func xcodeTritonExecutableCandidate(testBundleURL: URL) -> URL? {
    let bundleURL: URL
    if testBundleURL.pathExtension == "xctest" {
        bundleURL = testBundleURL
    } else {
        let macOSDirectory = testBundleURL.deletingLastPathComponent()
        let contentsDirectory = macOSDirectory.deletingLastPathComponent()
        let possibleBundle = contentsDirectory.deletingLastPathComponent()
        guard macOSDirectory.lastPathComponent == "MacOS",
              contentsDirectory.lastPathComponent == "Contents",
              possibleBundle.pathExtension == "xctest" else {
            return nil
        }
        bundleURL = possibleBundle
    }
    return bundleURL
        .deletingLastPathComponent()
        .appendingPathComponent("triton", isDirectory: false)
}

private func missingXcodeTritonExecutableError() -> NSError {
    NSError(
        domain: "TritonKitCLITests.XcodeCommandTests",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing current SwiftPM triton executable for Xcode command test"]
    )
}

private func xcodeTestBundleURL() -> URL? {
    let arguments = CommandLine.arguments
    guard let flagIndex = arguments.firstIndex(of: "--test-bundle-path"),
          arguments.indices.contains(flagIndex + 1) else {
        return nil
    }
    return URL(fileURLWithPath: arguments[flagIndex + 1])
}
