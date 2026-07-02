import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SimulatorAdvancedControlsTests {
    @Test("host command forwards stdin into child process")
    func runHostCommandForwardsStdin() throws {
        let command = TKHostCommand(executable: "/bin/cat", arguments: [], stdinData: Data("hello\n".utf8))

        let result = try runHostCommand(command)

        #expect(result.exitCode == 0)
        #expect(result.stdout == "hello\n")
        #expect(result.sourceCommand == "/bin/cat")
    }

    @Test("host artifact capture writes full stdout without truncating the artifact")
    func hostArtifactCaptureWritesFullStdout() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-large-artifact-\(UUID().uuidString).txt")
            .path
        defer { try? FileManager.default.removeItem(atPath: output) }
        let expectedBytes = 1_048_576 + 128
        let command = TKHostCommand(
            executable: "/usr/bin/perl",
            arguments: ["-e", "print \"a\" x \(expectedBytes)"]
        )

        try runHostCommandCapturingStdoutArtifact(
            action: "test.large-artifact",
            target: "host",
            command: command,
            outputPath: output,
            outputFormat: .text
        )

        let data = try Data(contentsOf: URL(fileURLWithPath: output))
        #expect(data.count == expectedBytes)
        #expect(data.last == Character("a").asciiValue)
    }

    @Test("host artifact capture refuses to overwrite an existing output file")
    func hostArtifactCaptureRefusesExistingOutputFile() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-existing-artifact-\(UUID().uuidString).txt")
        try Data("existing".utf8).write(to: output)
        defer { try? FileManager.default.removeItem(at: output) }
        let command = TKHostCommand(executable: "/bin/echo", arguments: ["new"])

        #expect(throws: (any Error).self) {
            try runHostCommandWritingStdoutArtifact(command, outputPath: output.path)
        }

        #expect(try String(contentsOf: output, encoding: .utf8) == "existing")
    }

    @Test("host artifact capture refuses symlink output paths")
    func hostArtifactCaptureRefusesSymlinkOutputPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-artifact-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("target.txt")
        let symlink = directory.appendingPathComponent("link.txt")
        try Data("target".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)
        let command = TKHostCommand(executable: "/bin/echo", arguments: ["new"])

        #expect(throws: (any Error).self) {
            try runHostCommandWritingStdoutArtifact(command, outputPath: symlink.path)
        }

        #expect(try String(contentsOf: target, encoding: .utf8) == "target")
    }

    @Test("xctrace output path rejects accidental overwrite but allows explicit append")
    func xctraceOutputPathRejectsOverwriteButAllowsExplicitAppend() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-xctrace-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = directory.appendingPathComponent("App.trace")
        let target = directory.appendingPathComponent("target.trace")
        let symlink = directory.appendingPathComponent("link.trace")
        try FileManager.default.createDirectory(at: trace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)

        #expect(throws: HostArtifactOutputError.self) {
            try prepareXctraceArtifactOutputPath(trace.path, appendRun: false)
        }
        #expect(throws: HostArtifactOutputError.self) {
            try prepareXctraceArtifactOutputPath(symlink.path, appendRun: true)
        }
        #expect(throws: HostArtifactOutputError.self) {
            try prepareXctraceArtifactOutputPath(directory.appendingPathComponent("missing.trace").path, appendRun: true)
        }

        try prepareXctraceArtifactOutputPath(trace.path, appendRun: true)
        try prepareXctraceArtifactOutputPath(directory.appendingPathComponent("new.trace").path, appendRun: false)
    }

    @Test("host artifact capture removes partial output when command fails")
    func hostArtifactCaptureRemovesPartialOutputOnFailure() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-partial-artifact-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: output) }
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "printf partial; exit 7"]
        )

        #expect(throws: HostCommandRunError.self) {
            try runHostCommandWritingStdoutArtifact(command, outputPath: output.path)
        }

        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("host command drains large stdout while keeping only a bounded sample")
    func runHostCommandBoundsLargeStdoutSample() throws {
        let expectedBytes = 1_048_576 + 128
        let command = TKHostCommand(
            executable: "/usr/bin/perl",
            arguments: ["-e", "print \"b\" x \(expectedBytes)"]
        )

        let result = try runHostCommand(command)

        #expect(result.stdoutBytes == expectedBytes)
        #expect(result.stdoutData.count == 1_048_576)
        #expect(result.stdoutTruncated)
    }

    @Test("host command treats HDC fail marker on stdout as failure even with zero exit")
    func runHostCommandTreatsHDCFailMarkerOnStdoutAsFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-fake-hdc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fakeHdc = directory.appendingPathComponent("hdc")
        try Data("""
        #!/bin/sh
        printf '[Fail]Not match target founded, check connect-key please\\n'
        exit 0
        """.utf8).write(to: fakeHdc)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeHdc.path)
        let command = TKHarmonyHDCCommand.appLaunch(
            target: "harmony-real:redacted",
            bundleName: "com.example.demo",
            abilityName: "EntryAbility",
            executable: fakeHdc.path
        )

        #expect(throws: HostCommandRunError.self) {
            try runHostCommand(command)
        }
    }

    @Test("host command timeout terminates process and leaves later commands usable")
    func runHostCommandTimeoutCleansUpProcess() throws {
        let command = TKHostCommand(
            executable: "/bin/sh",
            arguments: ["-c", "trap '' TERM; while true; do printf x; sleep 0.01; done"],
            defaultTimeoutSeconds: 0.2
        )

        #expect(throws: HostCommandRunError.self) {
            try runHostCommand(command)
        }

        let result = try runHostCommand(TKHostCommand(executable: "/bin/echo", arguments: ["ok"]))
        #expect(result.stdout == "ok\n")
    }

    @Test("simctl diagnose uses current output and data-container flags")
    func simctlDiagnoseUsesCurrentFlags() {
        let command = TKSimctlCommand.diagnose(
            output: "/tmp/sim-diagnostics",
            timeout: 180,
            noArchive: true,
            allLogs: true,
            dataContainers: true,
            udids: ["SIM-1"]
        )

        #expect(command.arguments == [
            "simctl", "diagnose",
            "--timeout=180.0",
            "--output=/tmp/sim-diagnostics",
            "--no-archive",
            "--all-logs",
            "--data-container",
            "--udid=SIM-1",
        ])
        #expect(command.defaultTimeoutSeconds == 180)
    }

    @Test("sim create builds schema-backed simctl create command")
    func simCreateBuildsSimctlCreateCommand() {
        let command = TKSimctlCommand.createDevice(
            name: "Codex iPhone",
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-0"
        )

        #expect(command.arguments == [
            "simctl", "create",
            "Codex iPhone",
            "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0",
        ])
        #expect(command.riskLevel == .automation)
    }

    @Test("host command timeout override is reusable for install and screenshot")
    func hostCommandTimeoutOverrideIsReusable() {
        let install = TKSimctlCommand.installApp(udid: "SIM-1", appPath: "/tmp/Demo.app").withTimeout(180)
        let screenshot = TKSimctlCommand.screenshot(udid: "SIM-1", output: "/tmp/sim.png").withTimeout(180)

        #expect(install.defaultTimeoutSeconds == 180)
        #expect(screenshot.defaultTimeoutSeconds == 180)
    }

    @Test("shutdown simulator wait-ready error exposes boot next action")
    func shutdownSimulatorWaitReadyErrorExposesBootNextAction() {
        let detail = simulatorNotBootedErrorDetail(
            target: "SIM-1",
            message: "\(HostCommandRunError.simulatorNotBooted(target: "SIM-1", state: "Shutdown"))"
        )

        #expect(detail.code == "simulator_not_booted")
        #expect(detail.nextAction?.command == "sim")
        #expect(detail.nextAction?.args == ["boot", "SIM-1", "--wait", "--jsonl"])
    }

    @Test("sim schema exposes advanced simulator maintenance commands")
    func simSchemaExposesAdvancedCommands() throws {
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        let usageForms = sim.usageForms.map(\.form)
        let optionNames = sim.options.map(\.name)

        #expect(usageForms.contains(where: { $0.hasPrefix("status-bar") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("privacy") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("location") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("ui ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("pasteboard") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("push ") }))
        #expect(usageForms.contains("media seed --manifest <path>"))
        #expect(usageForms.contains(where: { $0.hasPrefix("record") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("logs") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("diagnose") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("logverbose") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("create") }))
        #expect(usageForms.contains("proxy start --simulator <udid|booted> --mode record|mock|block|throttle --output <dir>"))
        #expect(usageForms.contains("proxy start --simulator <udid|booted> --mode record|mock|block|throttle --output <dir> --plan-only"))
        #expect(usageForms.contains("proxy start --simulator <udid|booted> --mode record|mock|block|throttle --output <dir> --confirm --audit-record <id> --execute-runner"))
        #expect(usageForms.contains("proxy status --simulator <udid|booted>"))
        #expect(usageForms.contains("proxy export --simulator <udid|booted> --output <path.har|path.ndjson>"))
        #expect(usageForms.contains("proxy export --simulator <udid|booted> --output <path.har|path.ndjson> --plan-only"))
        #expect(usageForms.contains("proxy stop --simulator <udid|booted> --restore"))
        #expect(usageForms.contains("proxy stop --simulator <udid|booted> --restore --plan-only"))
        #expect(usageForms.contains("proxy stop --simulator <udid|booted> --restore-snapshot <path> --plan-only"))
        #expect(usageForms.contains("proxy stop --simulator <udid|booted> --restore --confirm --audit-record <id> --execute-runner"))
        #expect(usageForms.contains(where: { $0.hasPrefix("runtime ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("pair ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("unpair ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("clone ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("erase ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("upgrade ") }))
        #expect(usageForms.contains(where: { $0.hasPrefix("personalization ") }))
        #expect(optionNames.contains("tap --x <x> --y <y>") == false)
        #expect(sim.subcommands.contains { $0.name == "tap" } == false)
        #expect(optionNames.contains("--display"))
        #expect(optionNames.contains("--device-type"))
        #expect(optionNames.contains("--data-container"))
        #expect(optionNames.contains("--manifest"))
        #expect(sim.providedCapabilities.contains("host-simulator"))
        #expect(sim.providedCapabilities.contains("sim-video"))
        #expect(sim.providedCapabilities.contains("sim-logs"))
        #expect(sim.providedCapabilities.contains("sim-diagnostics"))
        #expect(sim.providedCapabilities.contains("sim-runtime"))
        #expect(sim.providedCapabilities.contains("sim-device-maintenance"))
        #expect(sim.providedCapabilities.contains("sim-runtime-maintenance"))
        #expect(sim.providedCapabilities.contains("sim-personalization"))
        #expect(sim.providedCapabilities.contains("sim-push"))
        #expect(sim.providedCapabilities.contains("sim-media-seed"))
        #expect(sim.providedCapabilities.contains("device-proxy-ios"))
        #expect(sim.providedCapabilities.contains("network-capture-export"))
        #expect(sim.failureCodes.contains("media_seed_manifest_invalid"))
        #expect(sim.outputContracts.contains { $0.selector == "host.simulator-media-seed" })
        #expect(sim.failureCodes.contains("proxy_platform_not_supported"))
        #expect(sim.outputContracts.contains { $0.selector == "host.device-proxy" })
        #expect(sim.examples.contains("triton sim proxy start --simulator booted --mode record --output /tmp/ios-network --plan-only --json"))
        #expect(sim.examples.contains("triton sim proxy start --simulator booted --mode record --output /tmp/ios-network --confirm --audit-record ticket-123 --execute-runner --json"))
        #expect(sim.examples.contains("triton sim proxy stop --simulator booted --restore --plan-only --json"))
        #expect(sim.examples.contains("triton sim media seed --manifest /tmp/gallery/manifest.json --simulator booted --json"))
        #expect(sim.examples.contains("triton sim create 'Codex iPhone' --device-type com.apple.CoreSimulator.SimDeviceType.iPhone-16 --runtime com.apple.CoreSimulator.SimRuntime.iOS-26-0 --json"))
        #expect(sim.subcommands.first { $0.name == "create" }?.requiredOptions == ["<name>", "--device-type", "--runtime"])
    }

    @Test("sim proxy alias reuses the host device proxy output contract")
    func simProxyAliasReusesHostDeviceProxyContract() throws {
        let status = makeNetworkProxyStatusSession(platform: .ios, target: makeSimulatorProxyTarget(simulator: "booted"))
        let start = try makeNetworkProxyStartPlanSession(
            platform: .ios,
            target: makeSimulatorProxyTarget(simulator: "SIM-1"),
            captureMode: "record",
            endpoint: try NetworkProxyEndpoint("127.0.0.1:19431")
        )

        #expect(status.ok)
        #expect(status.surface == "host.device-proxy")
        #expect(status.platform == "ios")
        #expect(status.target?.id == "sim:booted")
        #expect(status.target?.kind == "simulator")
        #expect(status.limitations.contains("proxy_session_not_running"))

        #expect(start.ok)
        #expect(start.platform == "ios")
        #expect(start.target?.target == "SIM-1")
        #expect(start.sourceCommands.contains("/usr/sbin/networksetup -setwebproxy Wi-Fi 127.0.0.1 19431"))
        #expect(start.limitations.contains("proxy_plan_only:not_executed"))
    }

    @Test("iOS proxy override command plan sets HTTP and HTTPS then disables SOCKS")
    func iOSProxyOverrideCommandPlanSetsHTTPAndHTTPS() throws {
        let endpoint = try NetworkProxyEndpoint("127.0.0.1:19431")
        let commands = networkSetupProxyOverrideCommands(service: "Wi-Fi", endpoint: endpoint)

        #expect(commands.map(hostSourceCommand) == [
            "/usr/sbin/networksetup -setwebproxy Wi-Fi 127.0.0.1 19431",
            "/usr/sbin/networksetup -setwebproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 19431",
            "/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi off",
        ])
        #expect(commands.allSatisfy { $0.riskLevel == .breakGlass })
    }

    @Test("iOS proxy restore command plan restores original HTTP HTTPS and SOCKS state")
    func iOSProxyRestoreCommandPlanRestoresOriginalState() {
        let snapshot = HostNetworkProxyServiceSnapshot(
            service: "Wi-Fi",
            httpEnabled: true,
            httpHost: "corp-proxy.local",
            httpPort: 8_080,
            httpsEnabled: true,
            httpsHost: "corp-secure.local",
            httpsPort: 8_443,
            socksEnabled: true,
            socksHost: "corp-socks.local",
            socksPort: 1_080,
            bypassDomains: ["localhost", "*.corp.internal"]
        )

        let commands = networkSetupProxyRestoreCommands(snapshot: snapshot)

        #expect(commands.map(hostSourceCommand) == [
            "/usr/sbin/networksetup -setwebproxystate Wi-Fi off",
            "/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi off",
            "/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi off",
            "/usr/sbin/networksetup -setwebproxy Wi-Fi corp-proxy.local 8080",
            "/usr/sbin/networksetup -setwebproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setsecurewebproxy Wi-Fi corp-secure.local 8443",
            "/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setsocksfirewallproxy Wi-Fi corp-socks.local 1080",
            "/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi on",
            "/usr/sbin/networksetup -setproxybypassdomains Wi-Fi localhost *.corp.internal",
        ])
        #expect(commands.allSatisfy { $0.riskLevel == .breakGlass })
    }

    @Test("iOS proxy snapshot parser captures networksetup original service state")
    func iOSProxySnapshotParserCapturesNetworkSetupState() throws {
        let commands = networkSetupProxySnapshotCommands(service: "Wi-Fi")

        #expect(commands.map(hostSourceCommand) == [
            "/usr/sbin/networksetup -getwebproxy Wi-Fi",
            "/usr/sbin/networksetup -getsecurewebproxy Wi-Fi",
            "/usr/sbin/networksetup -getsocksfirewallproxy Wi-Fi",
            "/usr/sbin/networksetup -getproxybypassdomains Wi-Fi",
        ])
        #expect(commands.allSatisfy { $0.riskLevel == .readonly })

        let snapshot = try parseNetworkSetupServiceSnapshot(
            service: "Wi-Fi",
            httpOutput: """
            Enabled: Yes
            Server: corp-proxy.local
            Port: 8080
            Authenticated Proxy Enabled: 0
            """,
            httpsOutput: """
            Enabled: No
            Server:
            Port: 0
            Authenticated Proxy Enabled: 0
            """,
            socksOutput: """
            Enabled: Yes
            Server: socks.corp.local
            Port: 1080
            Authenticated Proxy Enabled: 0
            """,
            bypassOutput: """
            localhost
            *.corp.internal
            """
        )

        #expect(snapshot.service == "Wi-Fi")
        #expect(snapshot.httpEnabled)
        #expect(snapshot.httpHost == "corp-proxy.local")
        #expect(snapshot.httpPort == 8_080)
        #expect(snapshot.httpsEnabled == false)
        #expect(snapshot.httpsHost == "")
        #expect(snapshot.httpsPort == 0)
        #expect(snapshot.socksEnabled)
        #expect(snapshot.socksHost == "socks.corp.local")
        #expect(snapshot.socksPort == 1_080)
        #expect(snapshot.bypassDomains == ["localhost", "*.corp.internal"])
    }

    @Test("sim screenshot metadata parser preserves CoreSimulator display details")
    func simScreenshotMetadataParserPreservesCoreSimulatorDisplayDetails() throws {
        let stderr = """
        Detected file type from extension: PNG
        Note: No display specified. Defaulting to display: 70A4519E-10D6-4D54-A93A-381327FA385A (screenID: 1, name: LCD)
        Wrote screenshot to: /tmp/jobmd-ipad-mini-current.png
        """

        let metadata = parseSimctlScreenshotDisplayMetadata(stderr: stderr)

        #expect(metadata.rawLine?.contains("Defaulting to display") == true)
        #expect(metadata.displayID == "70A4519E-10D6-4D54-A93A-381327FA385A")
        #expect(metadata.screenID == "1")
        #expect(metadata.name == "LCD")
    }

    @Test("host screenshot artifact metadata exposes bytes dimensions hash and capture time")
    func hostScreenshotArtifactMetadataExposesAuditFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-host-screenshot-metadata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("shot.png")
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lz6ERwAAAABJRU5ErkJggg==")!
        try png.write(to: output)

        let metadata = try makeHostScreenshotArtifactMetadata(outputPath: output.path)

        #expect(metadata.bytes == png.count)
        #expect(metadata.width == 1)
        #expect(metadata.height == 1)
        #expect(metadata.sha256.count == 64)
        #expect(!metadata.capturedAt.isEmpty)
    }

    @Test("sim screenshot schema exposes raw framebuffer orientation metadata")
    func simScreenshotSchemaExposesRawFramebufferOrientationMetadata() throws {
        let sim = try #require(commandSchemas().first { $0.name == "sim" })
        let contract = try #require(sim.outputContracts.first { $0.selector == "host.simulator-screenshot" })
        let fields = Set(contract.fields.map(\.name))

        #expect(contract.model == "HostSimulatorScreenshotOutput")
        #expect(fields.contains("pixelWidth"))
        #expect(fields.contains("pixelHeight"))
        #expect(fields.contains("display"))
        #expect(fields.contains("display.displayID"))
        #expect(fields.contains("display.screenID"))
        #expect(fields.contains("display.name"))
        #expect(fields.contains("orientationPolicy"))
        #expect(fields.contains("orientationNote"))
        #expect(sim.successShape?.contains("orientationPolicy") == true)
    }

    @Test("schema exposes xctrace and coverage artifact commands")
    func schemaExposesXctraceAndCoverageCommands() throws {
        let xcode = try #require(commandSchemas().first { $0.name == "xcode" })
        let xctrace = try #require(commandSchemas().first { $0.name == "xctrace" })
        let coverage = try #require(commandSchemas().first { $0.name == "coverage" })
        let xcresult = try #require(commandSchemas().first { $0.name == "xcresult" })

        #expect(xcode.inheritsDefaultsFrom.contains("triton xcode use"))
        #expect(xcode.jsonlEvents.contains("xcode.<action>.summary"))
        #expect(xcode.outputContracts.map(\.selector).contains("xcode.progress"))
        #expect(xcode.outputContracts.map(\.selector).contains("xcode.final"))
        #expect(xcode.failureCodes.contains("xcodebuild_failed"))
        let xcodeProgress = try #require(xcode.outputContracts.first { $0.selector == "xcode.progress" })
        #expect(xcodeProgress.fields.first { $0.name == "message" }?.required == true)
        #expect(xcodeProgress.fields.first { $0.name == "elapsedMs" }?.type == "Int?")
        let xcodeFinal = try #require(xcode.outputContracts.first { $0.selector == "xcode.final" })
        #expect(xcodeFinal.fields.first { $0.name == "stdoutBytes" }?.type == "Int?")
        let xcodeRun = try #require(xcode.subcommands.first { $0.name == "run" })
        #expect(xcodeRun.inheritsDefaultsFrom.contains("triton xcode use"))
        #expect(xcodeRun.defaultProviders.contains("triton xcode use"))
        #expect(xcodeRun.outputSelectors == ["xcode.progress", "xcode.final"])
        #expect(xcodeRun.nextCommands.contains("triton verify text-exists <text> --json"))
        let xcodeUse = try #require(xcode.subcommands.first { $0.name == "use" })
        #expect(xcodeUse.requiredOptions == ["--scheme"])
        #expect(xcodeUse.oneOfRequiredOptions == [["--workspace"], ["--project"]])
        let xcodeTest = try #require(xcode.subcommands.first { $0.name == "test" })
        #expect(xcodeTest.artifacts.contains("result-bundle"))
        #expect(xcodeTest.nextCommands.contains("triton xcresult failures --path <result.xcresult> --json"))
        #expect(xctrace.usageForms.map(\.form).contains(where: { $0.hasPrefix("record") }))
        #expect(xctrace.providedCapabilities.contains("xctrace-record"))
        #expect(xctrace.outputContracts.map(\.selector).contains("xctrace.record"))
        #expect(xctrace.failureCodes.contains("xctrace_record_failed"))
        #expect(xctrace.failureCodes.contains("artifact_output_rejected"))
        #expect(xctrace.failureShape?.contains("artifact_output_rejected") == true)
        let xctraceRecord = try #require(xctrace.outputContracts.first { $0.selector == "xctrace.record" })
        #expect(xctraceRecord.fields.map(\.name).contains("runtimeScope"))
        #expect(xctraceRecord.fields.map(\.name).contains("artifacts"))
        #expect(xctrace.subcommands.first { $0.name == "record" }?.requiredOptions == ["--template", "--output"])
        #expect(xctrace.subcommands.first { $0.name == "record" }?.failureCodes.contains("artifact_output_rejected") == true)
        #expect(coverage.usageForms.map(\.form).contains(where: { $0.hasPrefix("report") }))
        #expect(coverage.providedCapabilities.contains("coverage-report"))
        #expect(coverage.failureShape?.contains("validation_failed") == true)
        #expect(coverage.failureShape?.contains("artifact_output_rejected") == true)
        #expect(xcresult.usageForms.map(\.form).contains(where: { $0.hasPrefix("summary") }))
        #expect(xcresult.usageForms.map(\.form).contains(where: { $0.hasPrefix("failures") }))
        #expect(xcresult.options.map(\.name).contains("--include-sensitive"))
        #expect(xcresult.successShape?.contains("redaction") == true)
        #expect(xcresult.requiredOptions == [])
        #expect(xcresult.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        #expect(xcresult.outputContracts.map(\.selector).contains("xcresult.summary"))
        #expect(xcresult.outputContracts.map(\.selector).contains("xcresult.failures"))
        #expect(xcresult.failureCodes.contains("xcresult_parse_failed"))
        #expect(xcresult.subcommands.first { $0.name == "summary" }?.requiredOptions == ["--path"])
        #expect(xcresult.subcommands.first { $0.name == "failures" }?.outputSelectors == ["xcresult.failures"])
        #expect(coverage.requiredOptions == [])
        #expect(coverage.artifacts == ["coverage-json"])
        #expect(coverage.outputContracts.map(\.selector).contains("coverage.report"))
        #expect(coverage.failureCodes.contains("artifact_output_rejected"))
        #expect(coverage.subcommands.first { $0.name == "report" }?.requiredOptions == ["--xcresult", "--output"])
        #expect(xcresult.providedCapabilities.contains("xcresult-summary"))
        #expect(xcresult.providedCapabilities.contains("xcresult-failures"))
        #expect(xcresult.failureShape?.contains("xcresult_parse_failed") == true)
        #expect(xcresult.failureShape?.contains("xcresult_output_too_large") == true)
    }
}
