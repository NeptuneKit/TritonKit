import ArgumentParser
import Foundation
import TritonKitShared

func iosHostDeviceDoctor(
    scope: HostDeviceScope,
    commandProbe: ((AppleHostCommandSpecification) -> HostAppleCommandSupport)? = nil,
    hidProbe: IOSHostHIDProbe? = nil,
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
    return HostDeviceDoctorOutput(ok: tools.allSatisfy(\.available) && discoverySupported, platform: "ios", tools: tools, capabilities: iosHostDeviceDoctorCapabilities(scope: scope), strongControl: iosStrongControlProbes(idbProbe: idb, hidProbe: hidProbe), artifactsSaved: false, commandSupport: commands, hidCompatibility: hidProbe)
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
    @Option(help: "Optional selected iOS Simulator selector for an independent host HID compatibility probe") var device: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Optional path to DevEco Emulator executable") var emulator: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let output: HostDeviceDoctorOutput
        if device != nil && (platform != .ios || scope == .real || scope == .emulator) {
            try failHostValidation(code: "unsupported_scope", message: "Selected-device HID compatibility requires --platform ios with simulator or all scope.", hint: "Use --scope simulator for this readonly compatibility probe; real-device HID is unsupported.", outputFormat: outputFormat)
        }
        switch platform {
        case .ios:
            let hidProbe: IOSHostHIDProbe?
            if let device {
                do {
                    let selected = try resolveHostDeviceSelection(
                        request: HostDeviceSelectionRequest(device: device, platform: .ios, scope: .simulator, ready: true),
                        hdc: hdc,
                        adb: adb
                    ).target
                    hidProbe = probeIOSHostHID(selectedDevice: selected.rawTarget)
                } catch {
                    hidProbe = IOSHostHIDProbe(
                        target: device,
                        compatible: false,
                        code: "ios_host_hid_selected_device_unavailable",
                        message: "The selected simulator could not be resolved for the host HID compatibility probe.",
                        hint: "Resolve one booted simulator explicitly; inventory or layout output alone does not establish touch support.",
                        backend: "SimulatorKit.SimDeviceLegacyHIDClient",
                        frameworkLayout: nil,
                        sourceCommands: ["triton device resolve --platform ios --scope simulator --device \(device) --ready --json"]
                    )
                }
            } else {
                hidProbe = nil
            }
            output = iosHostDeviceDoctor(scope: scope, commandProbe: { probeAppleHostCommand($0) }, hidProbe: hidProbe)
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

func iosStrongControlProbes(idbProbe: HostToolProbeOutput, hidProbe: IOSHostHIDProbe? = nil) -> [TKHostStrongControlCapability] {
    ["ios-host-ax", "ios-host-hid"].map { name in
        let isHID = name == "ios-host-hid"
        return TKHostStrongControlCapability(
            name: name,
            platform: "ios",
            runtimeScope: "host-simulator",
            available: isHID ? false : idbProbe.available,
            reason: isHID ? (hidProbe?.compatible == false ? hidProbe?.code : "ios_host_hid_dispatch_not_probed") : (idbProbe.available ? nil : "idb_not_available"),
            dependency: isHID ? "Baguette/SimulatorKit" : "idb/FBSimulatorControl",
            limitations: ["private_framework_dependency", "simulator_only", "xcode_version_coupled"] + (isHID ? ["input_dispatch_not_probed", "inventory_does_not_prove_hid"] : []),
            fallbackCapability: "embedded-runtime-or-public-simctl",
            sourceCommand: isHID ? hidProbe?.sourceCommands.first : idbProbe.sourceCommand,
            nextAction: isHID ? TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--device", hidProbe?.target ?? "<simulator>", "--json"], category: "diagnose") : (idbProbe.available ? nil : TKCLINextAction(command: "device", args: ["doctor", "--platform", "ios", "--json"], category: "diagnose"))
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
