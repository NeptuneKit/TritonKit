import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Apple command compatibility")
struct AppleCommandCompatibilityTests {
    @Test("older toolchain without CoreDevice still supports simulator-only doctor")
    func simulatorIsolation() {
        var names: [String] = []
        let result = iosHostDeviceDoctor(scope: .simulator) { name, command in
            names.append(name)
            return tool(name, command: command, available: name != "devicectl")
        }
        #expect(result.ok)
        #expect(!names.contains("devicectl"))
    }

    @Test("all scope requires CoreDevice while real scope avoids simulator queries")
    func requiredBackends() {
        let all = iosHostDeviceDoctor(scope: .all) { name, command in
            tool(name, command: command, available: name != "devicectl")
        }
        #expect(!all.ok)
        var names: [String] = []
        let real = iosHostDeviceDoctor(scope: .real) { name, command in
            names.append(name)
            return tool(name, command: command)
        }
        #expect(real.ok)
        #expect(!names.contains("simctl"))
    }

    @Test("version probe uses selected xcrun rather than a PATH-shadowed xcodebuild")
    func versionSelection() {
        var captured: TKHostCommand?
        _ = iosHostDeviceDoctor(scope: .simulator) { name, command in
            if name == "xcodebuild" { captured = command }
            return tool(name, command: command)
        }
        #expect(captured?.executable == "xcrun")
        #expect(captured?.arguments == ["xcodebuild", "-version"])
    }

    @Test("command environment preserves DEVELOPER_DIR without changing process-global selection", arguments: ["/fixture/Xcode26.app/Contents/Developer", "/fixture/Xcode27.app/Contents/Developer"])
    func explicitDeveloperDirectory(directory: String) {
        let previous = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
        let process = Process()
        configureHostProcessExecutable(process, command: TKHostCommand(arguments: ["devicectl", "list", "devices"], environment: ["DEVELOPER_DIR": directory, "COMPAT_TEST": "yes"]))
        #expect(process.executableURL?.path == "/usr/bin/xcrun")
        #expect(process.arguments == ["devicectl", "list", "devices"])
        #expect(process.environment?["DEVELOPER_DIR"] == directory)
        #expect(ProcessInfo.processInfo.environment["DEVELOPER_DIR"] == previous)
    }

    @Test("shared argv retains file JSON and avoids new-only/deleted options")
    func commonArguments() {
        let list = TKDevicectlCommand.listDevices(jsonOutput: "/fixture/result.json", logOutput: "/fixture/result.log")
        #expect(list.arguments == ["devicectl", "list", "devices", "--json-output", "/fixture/result.json", "--log-output", "/fixture/result.log"])
        let details = TKDevicectlCommand.deviceInfoDetails(identifier: "FIXTURE", jsonOutput: "result.json", logOutput: "result.log")
        #expect(!details.arguments.contains("--show"))
        #expect(!list.arguments.contains("--omit-deprecated-fields-in-json"))
        #expect(!list.arguments.contains("-"))
        #expect(TKSimctlCommand.listAvailableDevices().arguments == ["simctl", "list", "devices", "available", "--json"])
        let install = TKDevicectlCommand.installApp(identifier: "FIXTURE", appPath: "Fixture.app", jsonOutput: "result.json", logOutput: "result.log")
        #expect(Array(install.arguments.prefix(7)) == ["devicectl", "device", "install", "app", "--device", "FIXTURE", "Fixture.app"])
        let launch = TKDevicectlCommand.launchApp(identifier: "FIXTURE", bundleID: "fixture.app", jsonOutput: "result.json", logOutput: "result.log")
        #expect(launch.arguments == ["devicectl", "device", "process", "launch", "--device", "FIXTURE", "--json-output", "result.json", "--log-output", "result.log", "fixture.app"])
        #expect(launch.riskLevel == .automation)
    }

    @Test("old and new help profiles support the same required discovery options", arguments: ["legacy-contract", "modern-contract"])
    func helpProfiles(profile: String) {
        // Contract fixtures, not captures from a second installed Xcode.
        for specification in AppleHostCommandSpecification.forScope(.all) {
            let result = probeAppleHostCommand(specification) { arguments in
                #expect(arguments.contains("help") || arguments.contains("--help"))
                let extras = profile == "modern-contract" ? " --omit-deprecated-fields-in-json --new-option" : ""
                return "USAGE: " + specification.requiredOptions.joined(separator: " ") + extras
            }
            #expect(result.supported)
            #expect(result.missingOptions.isEmpty)
            #expect(result.verification == "help-advertised-only")
        }
    }

    @Test("missing options and help failures are unsupported without executing or retrying")
    func unsupportedHelp() {
        let specification = AppleHostCommandSpecification.forScope(.real)[0]
        var calls = 0
        let missing = probeAppleHostCommand(specification) { _ in
            calls += 1
            return "USAGE: --json-output-extra --log-output"
        }
        #expect(!missing.supported)
        #expect(missing.missingOptions == ["--json-output"])
        #expect(calls == 1)
        let failed = probeAppleHostCommand(specification) { _ in
            calls += 1
            throw CocoaError(.fileNoSuchFile)
        }
        #expect(!failed.supported)
        #expect(failed.error == "command_help_unavailable")
        #expect(calls == 2)
    }

    @Test("doctor publishes command support and rejects missing required discovery options")
    func doctorCommandContract() throws {
        let result = iosHostDeviceDoctor(scope: .all, commandProbe: { specification in
            probeAppleHostCommand(specification) { _ in
                specification.name == "devicectl.list-devices" ? "--json-output" : specification.requiredOptions.joined(separator: " ")
            }
        }) { name, command in tool(name, command: command) }
        #expect(!result.ok)
        let commands = try #require(result.commandSupport)
        #expect(commands.first { $0.name == "devicectl.list-devices" }?.missingOptions == ["--log-output"])
        let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        #expect(encoded.contains("commandSupport"))
        #expect(encoded.contains("help-advertised-only"))
    }

    @Test("unavailable tool does not trigger nested probes or alternate dispatch")
    func unavailableToolSkipsHelp() throws {
        var names: [String] = []
        let result = iosHostDeviceDoctor(scope: .real, commandProbe: { specification in
            names.append(specification.name)
            return probeAppleHostCommand(specification) { _ in specification.requiredOptions.joined(separator: " ") }
        }) { name, command in tool(name, command: command, available: name != "devicectl") }
        #expect(!result.ok)
        #expect(names.isEmpty)
        #expect(try #require(result.commandSupport).allSatisfy { !$0.supported && $0.error == "tool_unavailable" })
    }

    private func tool(_ name: String, command: TKHostCommand, available: Bool = true) -> HostToolProbeOutput {
        HostToolProbeOutput(name: name, path: command.executable, available: available, versionSummary: nil, error: available ? nil : "fixture tool unavailable", sourceCommand: hostSourceCommand(command))
    }
}
