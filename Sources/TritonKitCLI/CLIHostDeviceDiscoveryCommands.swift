import ArgumentParser
import Foundation
import TritonKitShared

func iosHostDeviceDoctor(
    scope: HostDeviceScope,
    commandProbe: ((AppleHostCommandSpecification) -> HostAppleCommandSupport)? = nil,
    probe: (String, TKHostCommand) -> HostToolProbeOutput = probeHostTool
) -> HostDeviceDoctorOutput {
    var tools: [HostToolProbeOutput] = []
    if scope != .real {
        tools.append(probe("simctl", TKHostCommand(arguments: ["simctl", "help"])))
    }
    if scope == .real || scope == .all {
        tools.append(probe("devicectl", TKHostCommand(arguments: ["devicectl", "--help"])))
    }
    tools.append(probe("xcodebuild", TKHostCommand(arguments: ["xcodebuild", "-version"])))
    let idb = probe("idb", TKHostCommand(executable: "idb", arguments: ["--version"]))
    let specifications = AppleHostCommandSpecification.forScope(scope)
    let commands = commandProbe.map { probe in
        specifications.map { specification in
            let toolName = String(specification.name.split(separator: ".")[0])
            guard tools.contains(where: { $0.name == toolName && $0.available }) else {
                return HostAppleCommandSupport(name: specification.name, supported: false, requiredOptions: specification.requiredOptions, missingOptions: specification.requiredOptions, sourceCommand: hostSourceCommand(TKHostCommand(arguments: specification.helpArguments)), error: "tool_unavailable")
            }
            return probe(specification)
        }
    }
    let requiredNames = Set(specifications.filter(\.requiredForDiscovery).map(\.name))
    let discoverySupported = commands?.filter { requiredNames.contains($0.name) }.allSatisfy(\.supported) ?? true
    return HostDeviceDoctorOutput(ok: tools.allSatisfy(\.available) && discoverySupported, platform: "ios", tools: tools, capabilities: iosHostDeviceDoctorCapabilities(scope: scope), strongControl: iosStrongControlProbes(idbProbe: idb), artifactsSaved: false, commandSupport: commands)
}

func iosHostDeviceDoctorCapabilities(scope: HostDeviceScope) -> [String] {
    var capabilities = [
        "device.list",
        "device.use",
        "device.wait-ready",
        "ios.real-device",
        "ios.devicectl",
        "ios-host-ax",
        "ios-host-hid",
    ]
    if scope != .real {
        capabilities += ["ios.simctl-targets", "ios.simulator-screenshot", "device.screenshot"]
    }
    return capabilities
}

struct DeviceDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe platform host tools")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Optional path to DevEco Emulator executable") var emulator: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let output: HostDeviceDoctorOutput
        switch platform {
        case .ios:
            output = iosHostDeviceDoctor(scope: scope, commandProbe: { probeAppleHostCommand($0) })
        case .harmony:
            let hdcProbe = probeHostTool(name: "hdc", command: TKHarmonyHDCCommand.version(executable: hdc))
            let emulatorProbe = emulator.map { path in
                probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
            }
            output = HostDeviceDoctorOutput(
                ok: hdcProbe.available && (emulatorProbe?.available ?? true),
                platform: platform.rawValue,
                tools: [hdcProbe] + Array(emulatorProbe.map { [$0] } ?? []),
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.runtime-url", "device.screenshot", "harmony.hdc-targets"],
                strongControl: [],
                artifactsSaved: false
            )
        case .android:
            let adbProbe = probeHostTool(name: "adb", command: TKHostCommand(executable: adb, arguments: ["version"]))
            let emulatorProbe = emulator.map { path in
                probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
            }
            output = HostDeviceDoctorOutput(
                ok: adbProbe.available && (emulatorProbe?.available ?? true),
                platform: platform.rawValue,
                tools: [adbProbe] + Array(emulatorProbe.map { [$0] } ?? []),
                capabilities: ["device.list", "device.use", "device.wait-ready", "device.screenshot", "android.adb-targets", "android.real-device", "android.emulator-scope"],
                strongControl: [],
                artifactsSaved: false
            )
        }
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            for tool in output.tools {
                print("\(tool.name)\t\(tool.available ? "available" : "unavailable")\t\(tool.path)")
            }
        }
    }
}

func iosStrongControlProbes(idbProbe: HostToolProbeOutput) -> [TKHostStrongControlCapability] {
    ["ios-host-ax", "ios-host-hid"].map { name in
        TKHostStrongControlCapability(
            name: name,
            platform: "ios",
            runtimeScope: "host-simulator",
            available: idbProbe.available,
            reason: idbProbe.available ? nil : "idb_not_available",
            dependency: "idb/FBSimulatorControl",
            limitations: ["private_framework_dependency", "simulator_only", "xcode_version_coupled"],
            fallbackCapability: "embedded-runtime-or-public-simctl",
            sourceCommand: idbProbe.sourceCommand,
            nextAction: idbProbe.available ? nil : TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--json"], category: "diagnose")
        )
    }
}

struct DeviceList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List platform targets")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope = .all
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try hostDeviceTargets(platform: platform, scope: scope, hdc: hdc, adb: adb)
            let output = HostDeviceListOutput(
                ok: true,
                platform: platform.rawValue,
                targets: result.targets,
                defaultTarget: selectHostDeviceTarget(target: nil, candidates: result.targets),
                sourceCommand: result.sourceCommand,
                nextAction: result.targets.isEmpty ? hostDeviceEmptyListNextAction(platform: platform) : nil
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for target in result.targets {
                    switch platform {
                    case .ios:
                        print("\(target.target)\t\(target.state)\t\(target.runtime ?? "-")\t\(target.name ?? "-")")
                    case .harmony:
                        print("\(target.target)\t\(target.state)\t\(target.transport ?? "-")")
                    case .android:
                        print("\(target.target)\t\(target.state)\t\(target.name ?? "-")")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
