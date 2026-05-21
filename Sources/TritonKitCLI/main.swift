import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

enum TritonKitBuildInfo {
    static let cliVersion = "0.1.0-dev"
}

// MARK: - Entry Point

@main
struct TritonKitEntry {
    static func main() async {
        if shouldPrintChineseHelp() {
            printChineseHelp()
            return
        }
        await TritonKitCLI.main()
    }
}

struct TritonKitCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "triton",
        abstract: "TritonKit macOS CLI - WebSocket control + HTTP data server for iOS view debugging",
        version: TritonKitBuildInfo.cliVersion,
        subcommands: [
            Serve.self,
            Version.self,
            Status.self,
            Doctor.self,
            Capabilities.self,
            Schema.self,
            Runtime.self,
            State.self,
            Plan.self,
            List.self,
            Inspect.self,
            Hierarchy.self,
            Nodes.self,
            Node.self,
            Attrs.self,
            ObjectInfo.self,
            Export.self,
            Evidence.self,
            Capture.self,
            UIAssert.self,
            Record.self,
            Replay.self,
            Find.self,
            Wait.self,
            Tap.self,
            Swipe.self,
            TypeText.self,
            PasteText.self,
            ClearText.self,
            Press.self,
            Geometry.self,
            AccessibilityTree.self,
            Hit.self,
            Screenshot.self,
            Input.self,
            Device.self,
            Sim.self,
            HostApp.self,
        ],
        defaultSubcommand: List.self
    )
}

// MARK: - Host-Side Simulator Commands

struct Sim: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sim",
        abstract: "Control iOS simulators through host-side Apple tools",
        subcommands: [SimList.self, SimUse.self, SimBoot.self, SimShutdown.self, SimScreenshot.self]
    )
}

struct SimList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List available simulators")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
            let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostSimulatorListOutput(ok: true, simulators: simulators)))
            case .text:
                for simulator in simulators {
                    print("\(simulator.udid)\t\(simulator.state)\t\(simulator.runtime)\t\(simulator.name)")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Set the workspace default simulator")

    @Argument(help: "Simulator UDID") var udid: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
            let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
            guard let simulator = simulators.first(where: { $0.udid == udid || $0.id == udid }) else {
                throw HostSimulatorRunError.simulatorNotFound(udid)
            }
            let defaults = TKHostWorkspaceDefaults(defaultSimulatorUDID: simulator.udid)
            let path = try saveHostWorkspaceDefaults(defaults)
            let output = HostSimulatorUseOutput(
                ok: true,
                action: "sim.use",
                simulator: simulator,
                defaultsPath: path
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(simulator.udid)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimBoot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "boot", abstract: "Boot a simulator")

    @Argument(help: "Simulator UDID") var udid: String
    @Flag(help: "Wait until the simulator reports Booted") var wait = false
    @Flag(help: "Emit compact JSON lines while waiting") var jsonl = false
    @Option(help: "Timeout in seconds when --wait is set") var timeout: Double = 60
    @Option(help: "Polling interval in seconds when --wait is set") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard wait else {
            try runSimpleHostCommand(
                action: "sim.boot",
                target: "sim:\(udid)",
                command: TKSimctlCommand.boot(udid: udid),
                outputFormat: outputFormat,
                note: "Simulator boot was requested."
            )
            return
        }

        do {
            do {
                _ = try runHostCommand(TKSimctlCommand.boot(udid: udid))
            } catch {
                if !(try simulatorIsBooted(udid: udid)) {
                    throw error
                }
            }
            try await waitForSimulatorBoot(
                udid: udid,
                timeout: timeout,
                interval: interval,
                outputFormat: outputFormat,
                jsonl: jsonl
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimShutdown: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "shutdown", abstract: "Shutdown a simulator")

    @Argument(help: "Simulator UDID or booted") var udid: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.shutdown",
            target: "sim:\(udid)",
            command: TKSimctlCommand.shutdown(udid: udid),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator shutdown was requested."
        )
    }
}

struct SimScreenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Capture a host-side simulator framebuffer screenshot")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Output PNG path") var output: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.screenshot",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.screenshot(udid: simulator, output: output),
            outputFormat: effectiveFormat(format, json: json),
            artifacts: [output],
            note: "Host-side simulator screenshot was written."
        )
    }
}

// MARK: - Host-Side App Commands

enum HostAppPlatform: String, ExpressibleByArgument {
    case ios
    case harmony
}

struct HostApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Control simulator apps through host-side Apple tools",
        subcommands: [
            HostAppList.self,
            HostAppInfo.self,
            HostAppInspect.self,
            HostAppInstall.self,
            HostAppUninstall.self,
            HostAppLaunch.self,
            HostAppTerminate.self,
            HostAppOpenURL.self,
            HostAppContainer.self,
            HostAppPrefs.self,
        ]
    )
}

struct HostAppList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List installed simulator apps")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Only include User apps") var userOnly = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.listApps(udid: simulator))
            var apps = try TKSimctlAppInfoParser.parseList(result.stdoutData)
            if userOnly {
                apps = apps.filter { $0.applicationType == "User" }
            }
            let output = HostAppListOutput(
                ok: true,
                action: "app.list",
                simulatorUDID: simulator,
                userOnly: userOnly,
                count: apps.count,
                apps: apps
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for app in apps {
                    print("\(app.bundleID)\t\(app.applicationType ?? "-")\t\(app.displayName ?? app.name ?? "-")\t\(app.path ?? "-")")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Show installed simulator app information")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.appInfo(udid: simulator, bundleID: bundleID))
            let app = try TKSimctlAppInfoParser.parseAppInfo(result.stdoutData, bundleID: bundleID)
            let output = HostAppInfoOutput(
                ok: true,
                action: "app.info",
                simulatorUDID: simulator,
                bundleID: bundleID,
                app: app
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print("\(app.bundleID)\t\(app.applicationType ?? "-")\t\(app.displayName ?? app.name ?? "-")\t\(app.path ?? "-")")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a platform app with host tools")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Harmony bundle name") var bundle: String
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
            try runSimpleHostCommand(
                action: "app.inspect",
                runtimeScope: "host-harmony",
                target: "harmony:\(selected.target)/app:\(bundle)",
                command: TKHarmonyHDCCommand.appInspect(target: selected.target, bundleName: bundle, executable: hdc),
                outputFormat: outputFormat,
                note: "Harmony app metadata was inspected with bm dump."
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install an .app bundle into a simulator")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Path to .app bundle") var app: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "app.install",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.installApp(udid: simulator, appPath: app),
            outputFormat: effectiveFormat(format, json: json),
            artifacts: [app],
            note: "App install was requested; verify with `triton app list --user-only --json` or `triton app info --bundle-id <id> --json`."
        )
    }
}

struct HostAppUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall", abstract: "Uninstall an app from a simulator")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Confirm uninstalling the app from the simulator") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard confirm else {
            try failHostValidation(
                code: "destructive_action_requires_policy",
                message: "App uninstall requires --confirm.",
                hint: "Rerun with `--confirm` after verifying the simulator and bundle id.",
                outputFormat: outputFormat
            )
        }
        try runSimpleHostCommand(
            action: "app.uninstall",
            target: "sim:\(simulator)/app:\(bundleID)",
            command: TKSimctlCommand.uninstallApp(udid: simulator, bundleID: bundleID),
            outputFormat: outputFormat,
            note: "App uninstall was requested; verify with `triton app info --bundle-id <id> --json` or `triton app list --user-only --json`."
        )
    }
}

struct HostAppLaunch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "launch", abstract: "Launch an installed simulator app")

    @Option(help: "Platform adapter: ios or harmony") var platform: HostAppPlatform = .ios
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "iOS app bundle identifier") var bundleID: String?
    @Option(help: "Harmony bundle name") var bundle: String?
    @Option(help: "Harmony ability name") var ability: String?
    @Option(help: "Harmony target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        switch platform {
        case .ios:
            guard let bundleID else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "iOS app launch requires --bundle-id.",
                    hint: "Pass `--bundle-id <id>` or use `--platform harmony --bundle <bundle> --ability <ability>`.",
                    outputFormat: outputFormat
                )
            }
            try runSimpleHostCommand(
                action: "app.launch",
                target: "sim:\(simulator)/app:\(bundleID)",
                command: TKSimctlCommand.launchApp(udid: simulator, bundleID: bundleID),
                outputFormat: outputFormat,
                note: "App launch was requested; verify readiness with `triton status`, `triton wait`, or `triton app prefs get`."
            )
        case .harmony:
            guard let bundle, let ability else {
                try failHostValidation(
                    code: "validation_failed",
                    message: "Harmony app launch requires --bundle and --ability.",
                    hint: "Pass `--platform harmony --bundle <bundle> --ability <ability>`.",
                    outputFormat: outputFormat
                )
            }
            do {
                let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
                try runSimpleHostCommand(
                    action: "app.launch",
                    runtimeScope: "host-harmony",
                    target: "harmony:\(selected.target)/app:\(bundle)",
                    command: TKHarmonyHDCCommand.appLaunch(target: selected.target, bundleName: bundle, abilityName: ability, executable: hdc),
                    outputFormat: outputFormat,
                    note: "Harmony app launch was requested; verify readiness with `triton ax --platform harmony`, screenshot, or logs."
                )
            } catch {
                try failHostCommand(error, outputFormat: outputFormat)
            }
        }
    }
}

struct HostAppTerminate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "terminate", abstract: "Terminate a running simulator app")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "app.terminate",
            target: "sim:\(simulator)/app:\(bundleID)",
            command: TKSimctlCommand.terminateApp(udid: simulator, bundleID: bundleID),
            outputFormat: effectiveFormat(format, json: json),
            note: "App terminate was requested."
        )
    }
}

struct HostAppOpenURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "open-url", abstract: "Open a URL in a simulator")

    @Argument(help: "URL to open") var url: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "app.open-url",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.openURL(udid: simulator, url: url),
            outputFormat: effectiveFormat(format, json: json),
            note: "URL was submitted to the simulator; verify in-app completion with `triton wait`, `triton find`, or `triton assert`."
        )
    }
}

struct HostAppContainer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "container", abstract: "Print a simulator app container path")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Option(help: "Container kind: app, data, or groups") var kind: TKHostAppContainerKind = .data
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.appContainer(udid: simulator, bundleID: bundleID, kind: kind))
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = HostAppContainerOutput(
                ok: true,
                action: "app.container",
                simulatorUDID: simulator,
                bundleID: bundleID,
                kind: kind.rawValue,
                path: path
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print(path)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostAppPrefs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prefs",
        abstract: "Read simulator app preferences as JSON",
        subcommands: [HostAppPrefsDump.self, HostAppPrefsGet.self]
    )
}

struct HostAppPrefsDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "dump", abstract: "Dump app preferences")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printPreferences(simulator: simulator, bundleID: bundleID, key: nil, outputFormat: effectiveFormat(format, json: json))
    }
}

struct HostAppPrefsGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read one app preference value")

    @Argument(help: "Preference key") var key: String
    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try printPreferences(simulator: simulator, bundleID: bundleID, key: key, outputFormat: effectiveFormat(format, json: json))
    }
}

extension TKHostAppContainerKind: ExpressibleByArgument {}

// MARK: - Cross-Platform Host Device Commands

enum HostPlatform: String, ExpressibleByArgument {
    case harmony
}

struct Device: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Discover and inspect host-side devices and emulators",
        subcommands: [DeviceDoctor.self, DeviceList.self, DeviceUse.self, DeviceWaitReady.self]
    )
}

struct DeviceDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Probe platform host tools")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Optional path to DevEco Emulator executable") var emulator: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let hdcProbe = probeHostTool(name: "hdc", command: TKHarmonyHDCCommand.version(executable: hdc))
        let emulatorProbe = emulator.map { path in
            probeHostTool(name: "emulator", command: TKHostCommand(executable: path, arguments: ["-version"]))
        }
        let output = HostDeviceDoctorOutput(
            ok: hdcProbe.available,
            platform: platform.rawValue,
            tools: [hdcProbe] + Array(emulatorProbe.map { [$0] } ?? []),
            capabilities: ["device.list", "device.wait-ready", "harmony.hdc-targets"],
            artifactsSaved: false
        )
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

struct DeviceList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List platform targets")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc))
            let targets = TKHdcTargetListParser.parse(result.stdout)
            let output = HostDeviceListOutput(
                ok: true,
                platform: platform.rawValue,
                targets: targets,
                defaultTarget: TKHdcTargetListParser.defaultTarget(from: targets),
                sourceCommand: result.sourceCommand
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for target in targets {
                    print("\(target.target)\t\(target.state)\t\(target.transport)")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Resolve one platform target")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceUseOutput(ok: true, platform: platform.rawValue, target: selected)))
            case .text:
                print(selected.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct DeviceWaitReady: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "wait-ready", abstract: "Wait until a platform target is ready")

    @Option(help: "Platform adapter: harmony") var platform: HostPlatform = .harmony
    @Option(help: "Target id, for example 127.0.0.1:10100") var target: String?
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Timeout in seconds") var timeout: Double = 30
    @Option(help: "Polling interval in seconds") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHarmonyTarget(target: target, hdc: hdc)
            let deadline = Date().addingTimeInterval(timeout)
            var attempt = 0
            while Date() <= deadline {
                attempt += 1
                let command = TKHarmonyHDCCommand.bootCompleted(target: selected.target, executable: hdc)
                let result = try runHostCommand(command)
                let ready = TKHarmonyBootCompletedParser.isReady(result.stdout)
                let event = HostDeviceReadyEvent(
                    ok: ready,
                    platform: platform.rawValue,
                    target: selected,
                    ready: ready,
                    attempt: attempt,
                    sourceCommand: result.sourceCommand,
                    error: nil
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(event))
                case .text:
                    print("\(selected.target)\tready=\(ready)")
                }
                if ready { return }
                try await Task.sleep(nanoseconds: UInt64(max(0.1, interval) * 1_000_000_000))
            }
            try failHostCommand(HostCommandRunError.deviceNotReady(target: selected.target, timeoutSeconds: timeout), outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct HostToolProbeOutput: Encodable {
    let name: String
    let path: String
    let available: Bool
    let versionSummary: String?
    let error: String?
    let sourceCommand: String
}

struct HostDeviceDoctorOutput: Encodable {
    let ok: Bool
    let platform: String
    let tools: [HostToolProbeOutput]
    let capabilities: [String]
    let artifactsSaved: Bool
}

struct HostDeviceListOutput: Encodable {
    let ok: Bool
    let platform: String
    let targets: [TKHarmonyTarget]
    let defaultTarget: TKHarmonyTarget?
    let sourceCommand: String
}

struct HostDeviceUseOutput: Encodable {
    let ok: Bool
    let platform: String
    let target: TKHarmonyTarget
}

struct HostDeviceReadyEvent: Encodable {
    let ok: Bool
    let platform: String
    let target: TKHarmonyTarget
    let ready: Bool
    let attempt: Int
    let sourceCommand: String
    let error: TKCLIErrorDetail?
}

enum HostSimulatorRunError: Error, CustomStringConvertible {
    case simulatorNotFound(String)

    var description: String {
        switch self {
        case .simulatorNotFound(let udid):
            "Simulator was not found: \(udid)"
        }
    }
}

enum HostDeviceRunError: Error, CustomStringConvertible {
    case ambiguousTarget([TKHarmonyTarget])
    case targetOffline(String)
    case targetNotFound(String)

    var description: String {
        switch self {
        case .ambiguousTarget(let targets):
            "Multiple connected Harmony targets found: \(targets.map(\.target).joined(separator: ", "))"
        case .targetOffline(let target):
            "Harmony target is offline: \(target)"
        case .targetNotFound(let target):
            "Harmony target was not found: \(target)"
        }
    }
}

struct HostProcessResult {
    let stdoutData: Data
    let stderrData: Data
    let exitCode: Int32
    let sourceCommand: String
    let stdoutTruncated: Bool
    let stderrTruncated: Bool

    var stdout: String {
        String(data: stdoutData, encoding: .utf8) ?? ""
    }

    var stderr: String {
        String(data: stderrData, encoding: .utf8) ?? ""
    }
}

enum HostCommandRunError: Error, CustomStringConvertible {
    case launchFailed(String)
    case timeout(command: TKHostCommand, timeoutSeconds: Double)
    case nonZeroExit(command: TKHostCommand, result: HostProcessResult)
    case deviceNotReady(target: String, timeoutSeconds: Double)
    case missingPreferences(path: String)
    case preferenceKeyNotFound(String)

    var description: String {
        switch self {
        case .launchFailed(let message):
            message
        case .timeout(let command, let timeoutSeconds):
            "Host command timed out after \(timeoutSeconds)s: \(hostSourceCommand(command))"
        case .deviceNotReady(let target, let timeoutSeconds):
            "Harmony target \(target) was not ready after \(timeoutSeconds)s"
        case .nonZeroExit(_, let result):
            result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Host command exited \(result.exitCode)" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        case .missingPreferences(let path):
            "Preferences plist not found: \(path)"
        case .preferenceKeyNotFound(let key):
            "Preference key not found: \(key)"
        }
    }
}

struct HostSimulatorListOutput: Encodable {
    let ok: Bool
    let simulators: [TKHostSimulatorTarget]
}

struct HostSimulatorUseOutput: Encodable {
    let ok: Bool
    let action: String
    let simulator: TKHostSimulatorTarget
    let defaultsPath: String
}

struct HostSimulatorReadyEvent: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let state: String?
    let ready: Bool
    let attempt: Int
    let elapsedMs: Int
    let sourceCommand: String?
}

struct HostActionOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let tool: String
    let exitCode: Int32
    let riskLevel: String
    let sourceCommand: String
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let stdout: String?
    let stderr: String?
    let artifacts: [String]
    let note: String?
}

struct HostAppContainerOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let kind: String
    let path: String
}

struct HostAppListOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let userOnly: Bool
    let count: Int
    let apps: [TKHostInstalledApp]
}

struct HostAppInfoOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let app: TKHostInstalledApp
}

struct HostPreferencesOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let plistPath: String
    let key: String?
    let value: TKHostPreferenceValue?
    let preferences: [String: TKHostPreferenceValue]?
}

func runSimpleHostCommand(
    action: String,
    runtimeScope: String = "host-simulator",
    target: String,
    command: TKHostCommand,
    outputFormat: ClientOutputFormat,
    artifacts: [String] = [],
    note: String? = nil
) throws {
    do {
        let result = try runHostCommand(command)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = HostActionOutput(
            ok: true,
            action: action,
            runtimeScope: runtimeScope,
            target: target,
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: result.sourceCommand,
            stdoutTruncated: result.stdoutTruncated,
            stderrTruncated: result.stderrTruncated,
            stdout: stdout.isEmpty ? nil : stdout,
            stderr: stderr.isEmpty ? nil : stderr,
            artifacts: artifacts,
            note: note
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            if let note { print(note) }
            if !stdout.isEmpty { print(stdout) }
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func saveHostWorkspaceDefaults(_ defaults: TKHostWorkspaceDefaults) throws -> String {
    let path = TKHostWorkspaceDefaults.filePath(workspace: FileManager.default.currentDirectoryPath)
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(defaults)
    try data.write(to: url, options: [.atomic])
    return path
}

func simulatorIsBooted(udid: String) throws -> Bool {
    let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
    let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
    guard let simulator = simulators.first(where: { $0.udid == udid || $0.id == udid }) else {
        throw HostSimulatorRunError.simulatorNotFound(udid)
    }
    return simulator.isBooted
}

func waitForSimulatorBoot(
    udid: String,
    timeout: Double,
    interval: Double,
    outputFormat: ClientOutputFormat,
    jsonl: Bool
) async throws {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var attempt = 0
    var lastEvent: HostSimulatorReadyEvent?
    while Date() <= deadline {
        attempt += 1
        let result = try runHostCommand(TKSimctlCommand.listAvailableDevices())
        let simulators = try TKSimctlDeviceListParser.parse(result.stdoutData)
        guard let simulator = simulators.first(where: { $0.udid == udid || $0.id == udid }) else {
            throw HostSimulatorRunError.simulatorNotFound(udid)
        }
        let event = HostSimulatorReadyEvent(
            ok: simulator.isBooted,
            action: "sim.boot.wait",
            simulatorUDID: simulator.udid,
            state: simulator.state,
            ready: simulator.isBooted,
            attempt: attempt,
            elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
            sourceCommand: result.sourceCommand
        )
        lastEvent = event
        if jsonl {
            print(try encodeCompactJSON(event))
        } else if outputFormat == .text {
            print("\(simulator.udid)\tstate=\(simulator.state)\tready=\(simulator.isBooted)")
        }
        if simulator.isBooted {
            if !jsonl, outputFormat == .json {
                print(try encodeJSON(event))
            }
            return
        }
        try await Task.sleep(nanoseconds: UInt64(max(0.1, interval) * 1_000_000_000))
    }
    if let lastEvent, jsonl {
        print(try encodeCompactJSON(lastEvent))
    }
    throw HostCommandRunError.timeout(command: TKSimctlCommand.boot(udid: udid), timeoutSeconds: timeout)
}

func probeHostTool(name: String, command: TKHostCommand) -> HostToolProbeOutput {
    do {
        let result = try runHostCommand(command)
        let summary = result.stdout
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
        return HostToolProbeOutput(
            name: name,
            path: command.executable,
            available: true,
            versionSummary: summary,
            error: nil,
            sourceCommand: result.sourceCommand
        )
    } catch {
        return HostToolProbeOutput(
            name: name,
            path: command.executable,
            available: false,
            versionSummary: nil,
            error: "\(error)",
            sourceCommand: hostSourceCommand(command)
        )
    }
}

func resolveHarmonyTarget(target: String?, hdc: String) throws -> TKHarmonyTarget {
    let result = try runHostCommand(TKHarmonyHDCCommand.listTargets(executable: hdc))
    let targets = TKHdcTargetListParser.parse(result.stdout)
    if let target {
        guard let selected = targets.first(where: { $0.target == target || $0.id == target }) else {
            throw HostDeviceRunError.targetNotFound(target)
        }
        guard selected.isConnected else {
            throw HostDeviceRunError.targetOffline(selected.target)
        }
        return selected
    }
    if let selected = TKHdcTargetListParser.defaultTarget(from: targets) {
        return selected
    }
    throw HostDeviceRunError.ambiguousTarget(targets.filter(\.isConnected))
}

func printPreferences(
    simulator: String,
    bundleID: String,
    key: String?,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let containerResult = try runHostCommand(TKSimctlCommand.appContainer(udid: simulator, bundleID: bundleID, kind: .data))
        let container = containerResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let plistPath = TKHostPreferencesSnapshot.plistPath(dataContainer: container, bundleID: bundleID)
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw HostCommandRunError.missingPreferences(path: plistPath)
        }
        let snapshot = try TKHostPreferencesSnapshot(bundleID: bundleID, plistPath: plistPath, data: Data(contentsOf: URL(fileURLWithPath: plistPath)))
        let value = key.flatMap { snapshot.value(forKey: $0) }
        if let key, value == nil {
            throw HostCommandRunError.preferenceKeyNotFound(key)
        }
        let output = HostPreferencesOutput(
            ok: true,
            action: key == nil ? "app.prefs.dump" : "app.prefs.get",
            simulatorUDID: simulator,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            value: value,
            preferences: key == nil ? snapshot.preferences : nil
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            if let key {
                print("\(key)=\(value.map(renderPreferenceValue) ?? "")")
            } else {
                for (key, value) in snapshot.preferences.sorted(by: { $0.key < $1.key }) {
                    print("\(key)=\(renderPreferenceValue(value))")
                }
            }
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func runHostCommand(_ command: TKHostCommand) throws -> HostProcessResult {
    let timeoutSeconds = command.defaultTimeoutSeconds
    let process = Process()
    if command.executable.contains("/") {
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.processArguments
    } else if command.executable == "xcrun" {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = command.processArguments
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.processArguments
    }

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
    } catch {
        throw HostCommandRunError.launchFailed(error.localizedDescription)
    }
    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .utility).async {
        process.waitUntilExit()
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
        process.terminate()
        throw HostCommandRunError.timeout(command: command, timeoutSeconds: timeoutSeconds)
    }

    let stdoutRead = truncatedData(stdout.fileHandleForReading.readDataToEndOfFile())
    let stderrRead = truncatedData(stderr.fileHandleForReading.readDataToEndOfFile())
    let result = HostProcessResult(
        stdoutData: stdoutRead.data,
        stderrData: stderrRead.data,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: stdoutRead.truncated,
        stderrTruncated: stderrRead.truncated
    )
    if result.exitCode != 0 {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

func truncatedData(_ data: Data, maximumBytes: Int = 1_048_576) -> (data: Data, truncated: Bool) {
    guard data.count > maximumBytes else {
        return (data, false)
    }
    return (data.prefix(maximumBytes), true)
}

func hostSourceCommand(_ command: TKHostCommand) -> String {
    ([command.executable] + command.arguments).map(shellEscaped).joined(separator: " ")
}

func shellEscaped(_ value: String) -> String {
    guard !value.isEmpty else { return "''" }
    if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: #"'\"$`"#))) == nil {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func renderPreferenceValue(_ value: TKHostPreferenceValue) -> String {
    switch value {
    case .string(let value):
        value
    case .bool(let value):
        value ? "true" : "false"
    case .int(let value):
        "\(value)"
    case .double(let value):
        "\(value)"
    case .array(let values):
        "[" + values.map(renderPreferenceValue).joined(separator: ",") + "]"
    case .dictionary(let values):
        "{" + values.keys.sorted().map { "\($0):\(renderPreferenceValue(values[$0]!))" }.joined(separator: ",") + "}"
    case .data(let value):
        value
    }
}

func failHostCommand(_ error: Error, outputFormat: ClientOutputFormat) throws -> Never {
    let detail: TKCLIErrorDetail
    switch error {
    case HostSimulatorRunError.simulatorNotFound:
        detail = TKCLIErrorDetail(
            code: "simulator_not_found",
            message: "\(error)",
            hint: "Run `triton sim list --json` to inspect available simulator UDIDs."
        )
    case HostDeviceRunError.ambiguousTarget(let targets):
        detail = TKCLIErrorDetail(
            code: "ambiguous_target",
            message: "\(error)",
            hint: "Pass --target with one of: \(targets.map(\.target).joined(separator: ", "))."
        )
    case HostDeviceRunError.targetOffline:
        detail = TKCLIErrorDetail(
            code: "target_offline",
            message: "\(error)",
            hint: "Start the target and wait until hdc reports Connected."
        )
    case HostDeviceRunError.targetNotFound:
        detail = TKCLIErrorDetail(
            code: "target_not_found",
            message: "\(error)",
            hint: "Run `triton device list --platform harmony --json` to inspect available targets."
        )
    case HostCommandRunError.deviceNotReady:
        detail = TKCLIErrorDetail(
            code: "device_not_ready",
            message: "\(error)",
            hint: "Check emulator boot state, increase --timeout, or inspect hdc shell param output."
        )
    case HostCommandRunError.timeout:
        detail = TKCLIErrorDetail(
            code: "host_command_timeout",
            message: "\(error)",
            hint: "Retry with a smaller target set or a command-specific timeout when supported."
        )
    case HostCommandRunError.missingPreferences:
        detail = TKCLIErrorDetail(
            code: "plist_not_found",
            message: "\(error)",
            hint: "Launch the app once or verify the bundle id and simulator data container."
        )
    case HostCommandRunError.preferenceKeyNotFound:
        detail = TKCLIErrorDetail(
            code: "preference_key_not_found",
            message: "\(error)",
            hint: "Run `triton app prefs dump --bundle-id <id> --json` to inspect available keys."
        )
    case TKSimctlAppInfoParserError.emptyInfo:
        detail = TKCLIErrorDetail(
            code: "app_info_not_available",
            message: "Installed app information is not available.",
            hint: "Verify the simulator is booted and the bundle id is installed."
        )
    case HostCommandRunError.nonZeroExit(let command, _):
        let code: String
        let hint: String
        if command.arguments.contains("get_app_container") {
            code = "app_container_not_found"
            hint = "Verify the simulator is booted, the app is installed, and the bundle id is correct."
        } else if command.arguments.contains("appinfo") || command.arguments.contains("listapps") {
            code = "app_info_not_available"
            hint = "Verify the simulator is booted, the app is installed, and the bundle id is correct."
        } else if command.arguments.contains("install") {
            code = "app_install_failed"
            hint = "Verify the simulator is booted and the .app path points to a simulator build."
        } else if command.arguments.contains("launch") {
            code = "app_launch_failed"
            hint = "Verify the simulator is booted and the bundle id is installed."
        } else if command.arguments.contains("terminate") {
            code = "app_terminate_failed"
            hint = "Verify the simulator is booted and the bundle id is running or installed."
        } else if command.arguments.contains("openurl") {
            code = "host_open_url_failed"
            hint = "Verify the simulator is booted and the URL scheme is valid."
        } else {
            code = "host_action_failed"
            hint = "Check the simulator UDID, bundle id, Xcode selection, and underlying simctl availability."
        }
        detail = TKCLIErrorDetail(
            code: code,
            message: "\(error)",
            hint: hint
        )
    default:
        detail = TKCLIErrorDetail(
            code: "host_action_failed",
            message: "\(error)",
            hint: "Check Xcode command line tools and retry with explicit simulator parameters."
        )
    }

    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        print(detail.message)
        if let hint = detail.hint { print("hint: \(hint)") }
    }
    throw ExitCode.failure
}

func failHostValidation(code: String, message: String, hint: String, outputFormat: ClientOutputFormat) throws -> Never {
    let detail = TKCLIErrorDetail(code: code, message: message, hint: hint)
    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        print(message)
        print("hint: \(hint)")
    }
    throw ExitCode.failure
}

// MARK: - Serve Command

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Start server")

    @Option(name: .shortAndLong, help: "Port to listen on") var port: Int = 19421
    @Option(name: .shortAndLong, help: "Host to bind to") var host: String = "0.0.0.0"

    func run() async throws {
        let store = DataStore()
        let state = ConnectionState()
        let targetState = TargetState()
        let encoder = JSONEncoder()
        let counter = MessageCounter()

        let router = Router(context: BasicWebSocketRequestContext.self)

        // ---- HTTP Data Endpoints ----

        router.post("/data") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard !bodyData.isEmpty else {
                return Response(status: .badRequest, body: .init(byteBuffer: ByteBuffer(string: "Empty body")))
            }
            let id = store.put(bodyData)
            let resp = try JSONEncoder().encode(["id": id])
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: resp)))
        }

        router.get("/data/:id") { request, _ -> Response in
            guard let idStr = request.uri.path.split(separator: "/").last,
                  let id = UUID(uuidString: String(idStr)),
                  let data = store.get(id) else {
                return Response(status: .notFound)
            }
            return Response(status: .ok, headers: [.contentType: "application/octet-stream"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/health") { _, _ -> HTTPResponse.Status in .ok }

        router.get("/hierarchy/latest") { _, _ -> Response in
            guard let data = targetState.latestHierarchy else {
                return jsonError(
                    code: "hierarchy_unavailable",
                    message: "No hierarchy received yet",
                    endpoint: "/hierarchy/latest",
                    hint: "Connect an app that embeds TritonKit, then request `triton hierarchy --json`",
                    status: .notFound
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        router.get("/status") { _, _ -> Response in
            let cacheStatus = targetState.cacheStatus(connected: state.isConnected)
            return jsonResponse(TKStatusResponse(
                connected: state.isConnected,
                latestHierarchyAvailable: targetState.latestHierarchy != nil,
                targetCount: state.isConnected ? 1 : 0,
                activeHierarchyAvailable: cacheStatus.activeHierarchyAvailable,
                hierarchyCacheState: cacheStatus.hierarchyCacheState,
                targetConnectionState: state.isConnected ? "connected" : "disconnected"
            ))
        }

        router.get("/targets") { _, _ -> Response in
            let targets = targetState.summary(connected: state.isConnected).map { [$0] } ?? []
            return jsonResponse(TKTargetsResponse(targets: targets))
        }

        router.get("/geometry") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .geometry,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/geometry"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/geometry",
                    hint: "Connect an app that embeds TritonKit before requesting geometry",
                    status: .conflict
                )
            }
        }

        router.get("/accessibility") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .accessibility,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/accessibility"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/accessibility",
                    hint: "Connect an app that embeds TritonKit before requesting accessibility",
                    status: .conflict
                )
            }
        }

        router.post("/hit") { request, _ -> Response in
            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }
            guard let hit = try? JSONDecoder().decode(TKHitTestRequest.self, from: bodyData),
                  let hitPayload = try? JSONEncoder().encode(hit) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported hit payload",
                    endpoint: "/hit",
                    hint: "Send JSON with numeric x and y fields",
                    status: .badRequest
                )
            }
            do {
                let payload = try await requestPayload(
                    type: .hitTest,
                    payload: hitPayload,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                return Response(status: .ok, headers: [.contentType: "application/json"],
                                body: .init(byteBuffer: ByteBuffer(data: payload)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/hit"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/hit",
                    hint: "Connect an app that embeds TritonKit before hit testing",
                    status: .conflict
                )
            }
        }

        router.get("/screenshot") { _, _ -> Response in
            do {
                let payload = try await requestPayload(
                    type: .screenshot,
                    state: state,
                    targetState: targetState,
                    counter: counter,
                    encoder: encoder
                )
                guard let screenshot = try? JSONDecoder().decode(TKScreenshotResponse.self, from: payload),
                      let imageData = try? await screenshotImageData(screenshot, client: TritonKitHTTPClient(host: host, port: port)) else {
                    return jsonError(
                        code: "invalid_payload",
                        message: "Invalid screenshot payload",
                        endpoint: "/screenshot",
                        hint: "Retry after the connected runtime responds to screenshot",
                        status: .internalServerError
                    )
                }
                return Response(status: .ok, headers: [.contentType: "image/png"],
                                body: .init(byteBuffer: ByteBuffer(data: imageData)))
            } catch {
                if let timeout = error as? RuntimeRequestTimeoutError {
                    return jsonError(
                        detail: TKCLIRuntimeTimeoutErrorDetail(requestType: timeout.requestType, endpoint: "/screenshot"),
                        status: .requestTimeout
                    )
                }
                return jsonError(
                    code: "target_unavailable",
                    message: "\(error)",
                    endpoint: "/screenshot",
                    hint: "Connect an app that embeds TritonKit before requesting screenshot",
                    status: .conflict
                )
            }
        }

        router.post("/command") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/command",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard
                let command = try? JSONDecoder().decode(TKCLICommandRequest.self, from: bodyData),
                let type = command.requestType
            else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported command",
                    endpoint: "/command",
                    hint: "Send JSON with a supported type such as ping, appInfo, or hierarchy",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            return jsonResponse(TKCLICommandResponse(id: id, type: type.rawValue))
        }

        router.post("/request") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/request",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard
                let command = try? JSONDecoder().decode(TKCLICommandRequest.self, from: bodyData),
                let type = command.requestType
            else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported command",
                    endpoint: "/request",
                    hint: "Send JSON with a supported type and optional payload",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: type, payload: command.payload), encoder: encoder)
            guard let payload = await targetState.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: type.rawValue, endpoint: "/request"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: payload)))
        }

        router.post("/input") { request, _ -> Response in
            guard let ws = state.outbound else {
                return jsonError(
                    code: "target_unavailable",
                    message: "No iOS device connected",
                    endpoint: "/input",
                    hint: "Launch an app that embeds TritonKit and connect it to this server",
                    status: .conflict
                )
            }

            var bodyData = Data()
            for try await chunk in request.body {
                bodyData.append(Data(buffer: chunk))
            }

            guard let input = try? JSONDecoder().decode(TKInputRequest.self, from: bodyData),
                  let payload = try? JSONEncoder().encode(input) else {
                return jsonError(
                    code: "invalid_payload",
                    message: "Unsupported input payload",
                    endpoint: "/input",
                    hint: "Send one TKInputRequest JSON object such as {\"type\":\"tap\",\"x\":1,\"y\":1}",
                    status: .badRequest
                )
            }

            let id = counter.next()
            log("[tritonkit] -> input [id:\(id)]")
            try await ws.send(TKMessage(id: id, type: .input, payload: payload), encoder: encoder)
            guard let responsePayload = await targetState.waitForResponse(id: id) else {
                return jsonError(
                    detail: TKCLIRuntimeTimeoutErrorDetail(requestType: "input", endpoint: "/input"),
                    status: .requestTimeout
                )
            }
            return Response(status: .ok, headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(data: responsePayload)))
        }

        // ---- WebSocket Control Channel ----

        router.ws("/") { inbound, outbound, _ in
            log("[tritonkit] iOS device connected (ws)")
            let connectionID = state.connect(outbound)
            targetState.beginConnection()

            // Test ping first to verify bidirectional communication
            let pingId = counter.next()
            log("[tritonkit] -> ping [id:\(pingId)]")
            try await outbound.send(TKMessage(id: pingId, type: .ping), encoder: encoder)

            // Then request hierarchy
            let id = counter.next()
            log("[tritonkit] -> hierarchy [id:\(id)]")
            try await outbound.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)

            do {
                for try await frame in inbound {
                    let data: Data
                    switch frame.opcode {
                    case .binary: data = Data(frame.data.readableBytesView)
                    case .text: data = Data(String(buffer: frame.data).utf8)
                    default: continue
                    }
                    handleResponse(
                        data: data,
                        store: store,
                        targetState: targetState
                    )
                }
            } catch {
                log("[tritonkit] Connection error: \(error)")
            }

            log("[tritonkit] iOS device disconnected")
            if state.disconnect(connectionID: connectionID) {
                targetState.endConnection()
            }
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(
                webSocketRouter: router,
                configuration: .init(maxFrameSize: tritonWebSocketMaxFrameSize, extensions: [])
            ),
            configuration: .init(address: .hostname(host, port: port))
        )

        log("[tritonkit] Control: ws://\(host):\(port)/")
        log("[tritonkit] Data:   http://\(host):\(port)/data")
        log("[tritonkit] Status: http://\(host):\(port)/status")
        log("[tritonkit] Command: POST http://\(host):\(port)/command")
        log("[tritonkit] Commands: h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")

        // Stdin
        Task {
            while let line = readLine() {
                switch line.trimmingCharacters(in: .whitespaces).lowercased() {
                case "q", "quit", "exit": log("[tritonkit] Shut down."); Darwin.exit(0)
                case "h", "hierarchy":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> hierarchy [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .hierarchy), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "a", "appinfo":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> appInfo [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .appInfo), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "p", "ping":
                    if let ws = state.outbound {
                        let id = counter.next()
                        log("[tritonkit] -> ping [id:\(id)]")
                        try? await ws.send(TKMessage(id: id, type: .ping), encoder: encoder)
                    } else { log("[tritonkit] No iOS device connected") }
                case "help", "?": log("[tritonkit] h[ierarchy] | a[ppinfo] | p[ing] | q[uit]")
                case "": break
                default: log("[tritonkit] Unknown: \(line)")
                }
            }
        }

        signal(SIGINT, SIG_IGN)
        let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sig.setEventHandler { log("\n[tritonkit] Interrupted."); Darwin.exit(0) }
        sig.resume()

        do { try await app.run() } catch { log("[tritonkit] Error: \(error)"); throw error }
    }
}

// MARK: - Client Commands

enum ClientOutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

enum HierarchyOutputFormat: String, ExpressibleByArgument {
    case tree
    case json
}

enum ExportOutputFormat: String, ExpressibleByArgument {
    case auto
    case json
    case archive
}

enum CLILanguage: String, CaseIterable, ExpressibleByArgument {
    case en
    case zh
}

struct LocalizationOptions: ParsableArguments {
    @Option(name: [.customLong("language"), .customLong("lang")], help: "Human-readable output language: en or zh")
    var language: CLILanguage?
}

let tritonWebSocketMaxFrameSize = 16_777_216

func effectiveFormat(_ format: ClientOutputFormat, json: Bool) -> ClientOutputFormat {
    json ? .json : format
}

func effectiveFormat(_ format: HierarchyOutputFormat, json: Bool) -> HierarchyOutputFormat {
    json ? .json : format
}

func effectiveFormat(_ format: ExportOutputFormat, json: Bool) -> ExportOutputFormat {
    json ? .json : format
}

func effectiveLanguage(_ option: CLILanguage?) -> CLILanguage {
    option ?? environmentLanguage() ?? .en
}

func environmentLanguage() -> CLILanguage? {
    let environment = ProcessInfo.processInfo.environment
    guard let raw = environment["TRITON_LANGUAGE"] ?? environment["TRITON_LANG"] else {
        return nil
    }
    return normalizeLanguage(raw)
}

func normalizeLanguage(_ raw: String) -> CLILanguage? {
    let normalized = raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "-")
        .lowercased()
    if normalized == "en" || normalized.hasPrefix("en-") {
        return .en
    }
    if normalized == "zh" || normalized.hasPrefix("zh-") {
        return .zh
    }
    return nil
}

func shouldPrintChineseHelp(arguments: [String] = Array(ProcessInfo.processInfo.arguments.dropFirst())) -> Bool {
    guard effectiveHelpLanguage(arguments: arguments) == .zh else {
        return false
    }
    return helpRequest(arguments: arguments) != nil
}

func effectiveHelpLanguage(arguments: [String]) -> CLILanguage {
    if let index = arguments.firstIndex(where: { $0 == "--language" || $0 == "--lang" }),
       arguments.indices.contains(arguments.index(after: index)),
       let language = normalizeLanguage(arguments[arguments.index(after: index)]) {
        return language
    }
    for argument in arguments {
        if argument.hasPrefix("--language="),
           let language = normalizeLanguage(String(argument.dropFirst("--language=".count))) {
            return language
        }
        if argument.hasPrefix("--lang="),
           let language = normalizeLanguage(String(argument.dropFirst("--lang=".count))) {
            return language
        }
    }
    return environmentLanguage() ?? .en
}

enum HelpRequest {
    case root
    case command(String)
}

func helpRequest(arguments: [String]) -> HelpRequest? {
    let filtered = stripLanguageArguments(arguments)
    if filtered.isEmpty {
        return nil
    }
    if filtered.contains("-h") || filtered.contains("--help") {
        if let command = filtered.first(where: { !$0.hasPrefix("-") && $0 != "help" }) {
            return .command(command)
        }
        return .root
    }
    if filtered.first == "help" {
        if filtered.count > 1 {
            return .command(filtered[1])
        }
        return .root
    }
    return nil
}

func stripLanguageArguments(_ arguments: [String]) -> [String] {
    var result: [String] = []
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
        if argument == "--language" || argument == "--lang" {
            _ = iterator.next()
            continue
        }
        if argument.hasPrefix("--language=") || argument.hasPrefix("--lang=") {
            continue
        }
        result.append(argument)
    }
    return result
}

func printChineseHelp(arguments: [String] = Array(ProcessInfo.processInfo.arguments.dropFirst())) {
    switch helpRequest(arguments: arguments) {
    case .command(let command):
        print(chineseCommandHelp(command))
    case .root, .none:
        print(chineseRootHelp())
    }
}

struct ChineseCommandHelp {
    let name: String
    let overview: String
    let usage: String
    let options: [(String, String)]
}

func chineseRootHelp() -> String {
    let commands: [(String, String)] = [
        ("serve", "启动本地 WebSocket 与 HTTP 控制服务"),
        ("version", "输出 Triton CLI 版本和启动默认值"),
        ("status", "读取本地 TritonKit 服务状态"),
        ("doctor", "诊断服务、目标和运行时能力"),
        ("capabilities", "输出 Triton 运行时能力矩阵"),
        ("schema", "输出机器可读命令 schema 和示例"),
        ("runtime", "读取 embedded runtime manifest 和能力边界"),
        ("plan", "根据当前状态输出推荐下一步"),
        ("list (默认)", "列出已连接的 TritonKit 目标"),
        ("inspect", "查看单个 TritonKit 目标摘要"),
        ("hierarchy", "读取目标最新视图层级"),
        ("nodes", "列出最新层级中的节点摘要"),
        ("node", "查看单个层级节点"),
        ("attrs", "读取节点 layer oid 的实时属性组"),
        ("object", "读取 view 或 layer oid 的对象元数据"),
        ("export", "导出可复用层级快照或 archive"),
        ("evidence", "导出 agent 回归证据包"),
        ("capture", "一站式采集回归证据包"),
        ("assert", "执行 agent 友好的 UI 文本断言"),
        ("record", "生成可编辑 replay plan 模板"),
        ("replay", "复跑 .tritonplan smoke 流程"),
        ("find", "解析一个可见文本或意图目标"),
        ("wait", "等待文本、消失、空闲或谓词条件"),
        ("tap", "点击文本、坐标、view oid 或 AX 节点"),
        ("swipe", "在 App 内按 window points 执行滑动"),
        ("type", "向已聚焦或 oid 指定的 UIKeyInput 输入文本"),
        ("paste", "向已聚焦、坐标或 oid 指定的输入框精确粘贴文本"),
        ("clear", "清空已聚焦、坐标或 oid 指定的输入框"),
        ("press", "在当前运行时支持时按设备按钮"),
        ("geometry", "读取当前 window 几何信息"),
        ("ax", "读取 App 内安全可操作控件索引"),
        ("hit", "对当前 App window 中一点做命中测试"),
        ("screenshot", "捕获当前 App PNG 截图"),
        ("input", "从 stdin 读取 NDJSON 输入动作"),
        ("device", "发现和检查 host-side 设备与模拟器"),
    ]
    var lines = [
        "概览: TritonKit macOS CLI - iOS 视图调试的 WebSocket 控制与 HTTP 数据服务",
        "",
        "用法: triton <子命令>",
        "",
        "选项:",
        "  --language, --lang <language>  人读输出语言：en 或 zh",
        "  --version                      显示版本。",
        "  -h, --help                     显示帮助信息。",
        "",
        "子命令:",
    ]
    lines.append(contentsOf: commands.map { "  \($0.0.padding(toLength: 22, withPad: " ", startingAt: 0))\($0.1)" })
    lines.append("")
    lines.append("  使用 `triton --language zh help <子命令>` 查看子命令帮助。")
    return lines.joined(separator: "\n")
}

func chineseCommandHelp(_ command: String) -> String {
    let help = chineseCommandHelps()[command] ?? ChineseCommandHelp(
        name: command,
        overview: "暂无该子命令的中文帮助。",
        usage: "triton \(command) [选项]",
        options: []
    )
    var lines = [
        "概览: \(help.overview)",
        "",
        "用法: \(help.usage)",
    ]
    if !help.options.isEmpty {
        lines.append("")
        lines.append("选项:")
        lines.append(contentsOf: help.options.map { "  \($0.0.padding(toLength: 34, withPad: " ", startingAt: 0))\($0.1)" })
    }
    lines.append("")
    lines.append("  --language, --lang <language>     人读输出语言：en 或 zh")
    lines.append("  --version                         显示版本。")
    lines.append("  -h, --help                        显示帮助信息。")
    return lines.joined(separator: "\n")
}

func chineseCommandHelps() -> [String: ChineseCommandHelp] {
    let hostPort = [
        ("--host <host>", "服务 host，默认 127.0.0.1"),
        ("--port <port>", "服务端口，默认 19421"),
    ]
    let target = [("--target <target>", "目标 id，来自 `triton list`；只有一个目标时可省略")]
    let formatTextJSON = [("--format <format>", "输出格式：text 或 json"), ("--json", "等价于 --format json")]
    return [
        "serve": ChineseCommandHelp(name: "serve", overview: "启动本地控制服务。", usage: "triton serve [--host <host>] [--port <port>]", options: [
            ("--host <host>", "监听 host，默认 0.0.0.0"),
            ("--port <port>", "监听端口，默认 19421"),
        ]),
        "version": ChineseCommandHelp(name: "version", overview: "输出 Triton CLI 版本和启动默认值。", usage: "triton version [--format <format>] [--json]", options: formatTextJSON),
        "status": ChineseCommandHelp(name: "status", overview: "读取本地 TritonKit 服务状态。", usage: "triton status [选项]", options: hostPort + formatTextJSON),
        "doctor": ChineseCommandHelp(name: "doctor", overview: "诊断服务、目标和运行时能力。", usage: "triton doctor [选项]", options: hostPort + formatTextJSON),
        "capabilities": ChineseCommandHelp(name: "capabilities", overview: "输出运行时能力矩阵。", usage: "triton capabilities [选项]", options: hostPort + formatTextJSON),
        "schema": ChineseCommandHelp(name: "schema", overview: "输出机器可读命令 schema 和示例。", usage: "triton schema [--command <command>] [--format <format>] [--json]", options: [
            ("--command <command>", "筛选单个命令，例如 input 或 tap"),
        ] + formatTextJSON),
        "runtime": ChineseCommandHelp(name: "runtime", overview: "读取 embedded runtime manifest、能力边界、限制和脱敏策略。", usage: "triton runtime manifest [选项]", options: target + hostPort + formatTextJSON),
        "device": ChineseCommandHelp(name: "device", overview: "发现和检查 host-side 平台设备。", usage: "triton device <doctor|list|use|wait-ready> --platform harmony [选项]", options: formatTextJSON + [
            ("--platform <platform>", "平台适配器，目前支持 harmony"),
            ("--hdc <path>", "HDC 可执行文件路径，默认 hdc"),
            ("--target <target>", "Harmony target，例如 127.0.0.1:10100"),
            ("--timeout <seconds>", "wait-ready 超时时间，默认 30"),
        ]),
        "plan": ChineseCommandHelp(name: "plan", overview: "根据当前服务和目标状态输出推荐下一步；inspect 子动作可离线查看 .tritonplan 摘要。", usage: "triton plan [inspect <path>] [选项]", options: hostPort + formatTextJSON),
        "list": ChineseCommandHelp(name: "list", overview: "列出已连接的 TritonKit 目标。", usage: "triton list [选项]", options: hostPort + formatTextJSON + [
            ("--name-contains <text>", "按 App 名称片段过滤"),
            ("--bundle-id <id>", "按 bundle id 过滤"),
            ("--ids-only", "只输出 target id"),
        ]),
        "inspect": ChineseCommandHelp(name: "inspect", overview: "查看单个 TritonKit 目标摘要。", usage: "triton inspect [选项]", options: target + hostPort + formatTextJSON),
        "hierarchy": ChineseCommandHelp(name: "hierarchy", overview: "读取目标最新视图层级。", usage: "triton hierarchy [选项]", options: target + hostPort + [
            ("--format <format>", "输出格式：tree 或 json"),
            ("--json", "等价于 --format json"),
            ("--output <path>", "写入文件"),
            ("--refresh/--no-refresh", "读取前是否刷新层级"),
            ("--hide-noise/--no-hide-noise", "tree 输出是否隐藏无效 UIKit 包装视图"),
        ]),
        "ax": ChineseCommandHelp(name: "ax", overview: "读取 App 内安全可操作控件索引。", usage: "triton ax [选项]", options: target + hostPort + formatTextJSON + [
            ("--with-hierarchy", "把 AX 节点按 viewOID 映射到 hierarchy 节点"),
            ("--refresh/--no-refresh", "映射 hierarchy 前是否刷新层级"),
            ("--output <path>", "写入文件"),
        ]),
        "evidence": ChineseCommandHelp(name: "evidence", overview: "导出 agent 回归证据包，包含 manifest 与截图、AX、层级、状态等 artifact。", usage: "triton evidence [inspect <path>] [选项]", options: target + hostPort + formatTextJSON + [
            ("--output <path>", "证据包目录路径，建议使用 .tritonevidence 后缀"),
            ("--include <list>", "逗号分隔 artifact：screenshot,ax,hierarchy,status,list,version,geometry,archive,logs"),
            ("--name <name>", "场景名，写入 manifest"),
            ("--note <note>", "备注，写入 manifest"),
            ("--refresh/--no-refresh", "导出 hierarchy/archive 前是否请求新层级"),
        ]),
        "capture": ChineseCommandHelp(name: "capture", overview: "一站式采集 agent 回归证据包。", usage: "triton capture --case <name> --output <path> [选项]", options: target + hostPort + formatTextJSON + [
            ("--case <name>", "回归场景名，写入 manifest"),
            ("--output <path>", "证据包目录路径，建议使用 .tritonevidence 后缀"),
            ("--include <list>", "逗号分隔 artifact，默认包含 status,list,version,hierarchy,ax,screenshot,geometry,archive"),
            ("--note <note>", "备注，写入 manifest"),
        ]),
        "assert": ChineseCommandHelp(name: "assert", overview: "断言 UI 可见文本存在或不存在。", usage: "triton assert <text-exists|text-not-exists> <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("--role <role>", "限制 AX role"),
            ("--count <n>", "要求匹配数量等于 n"),
            ("--min-count <n>", "要求匹配数量至少为 n"),
            ("--max-count <n>", "要求匹配数量最多为 n"),
            ("--within <x,y,w,h>", "只检查指定 window bounds 内的文本"),
        ]),
        "record": ChineseCommandHelp(name: "record", overview: "生成可编辑 .tritonplan 模板；首期不是交互式真实录制。", usage: "triton record --output <path> [选项]", options: formatTextJSON + [
            ("--output <path>", "写入 .tritonplan 文件"),
            ("--name <name>", "计划名称，默认来自输出文件名"),
        ]),
        "replay": ChineseCommandHelp(name: "replay", overview: "复跑 .tritonplan smoke 流程。", usage: "triton replay <path> [选项]", options: target + hostPort + formatTextJSON + [
            ("<path>", ".tritonplan 文件路径"),
            ("--dry-run", "只校验与展示步骤，不连接 runtime"),
            ("--var <key=value>", "提供变量值，可重复"),
            ("--var <key-env=ENV>", "从环境变量读取变量值，可重复"),
        ]),
        "find": ChineseCommandHelp(name: "find", overview: "把可见文本、label、identifier 或选项标题解析为可操作目标。", usage: "triton find <文本> [选项]", options: target + hostPort + formatTextJSON + [
            ("<文本>", "要解析的用户意图，例如 HTTP"),
            ("--all", "输出全部候选及 1 起始序号"),
            ("--index <n>", "选择第 n 个候选"),
            ("--within <x,y,w,h>", "只在指定 window bounds 内匹配"),
            ("--at <x,y>", "只匹配包含该 window 点位的候选"),
        ]),
        "wait": ChineseCommandHelp(name: "wait", overview: "等待文本出现、文本消失、目标空闲、层级变化或安全谓词成立。", usage: "triton wait [条件] [选项]", options: target + hostPort + formatTextJSON + [
            ("--text <text>", "等待可见文本出现"),
            ("--gone <text>", "等待可见文本消失"),
            ("--exists <text>", "等待可见文本出现，可配合 --role"),
            ("--role <role>", "限制 AX role，例如 button"),
            ("--idle", "等待当前 target 已连接且 hierarchy 连续稳定"),
            ("--hierarchy-change", "等待 hierarchy 快照变化"),
            ("--since <value>", "hierarchy-change 基线，目前支持 latest"),
            ("--predicate <expr>", "安全谓词，例如 text.exists(\"console\") && !text.exists(\"登录\")"),
            ("--timeout <seconds>", "超时时间，默认 10"),
            ("--interval <seconds>", "轮询间隔，默认 0.5"),
        ]),
        "tap": ChineseCommandHelp(name: "tap", overview: "点击文本、坐标、view oid 或 AX 节点。", usage: "triton tap [文本] [选项]", options: target + hostPort + formatTextJSON + [
            ("<文本>", "要点击的可见文本、label、identifier 或选项标题，例如 HTTP"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--oid <oid>", "hierarchy view oid"),
            ("--ax-oid <oid>", "`triton ax` 输出的 targetOID/viewOID"),
            ("--ax-label <label>", "`triton ax` 输出的精确 label，优先按 AX oid 点击"),
            ("--duration <seconds>", "按住时长"),
            ("--index <n>", "按 `find --all` 的 1 起始序号选择候选"),
            ("--within <x,y,w,h>", "只在指定 window bounds 内匹配文本候选"),
            ("--at <x,y>", "无文本时按坐标点击；有文本时只匹配包含该点位的候选"),
        ]),
        "input": ChineseCommandHelp(name: "input", overview: "从 stdin 读取 NDJSON 输入动作。", usage: "triton input [选项] < gestures.ndjson", options: target + hostPort + formatTextJSON + [
            ("--fail-fast", "首个失败动作后停止"),
            ("--summary", "输出最终批次 summary"),
            ("--strict", "任一动作失败时以非 0 退出"),
        ]),
        "paste": ChineseCommandHelp(name: "paste", overview: "向当前焦点或指定输入框精确粘贴文本。", usage: "triton paste <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("<text>", "要插入的文本"),
            ("--secure", "敏感文本，输出只回显长度和 redaction 状态"),
            ("--oid <oid>", "可选 responder oid"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--at <x,y>", "聚焦该 window 点位后粘贴"),
        ]),
        "type": ChineseCommandHelp(name: "type", overview: "向已聚焦或 oid 指定的 UIKeyInput 输入文本。", usage: "triton type <text> [选项]", options: target + hostPort + formatTextJSON + [
            ("<text>", "要插入的文本"),
            ("--text <text>", "兼容入口；与位置参数二选一"),
            ("--secure", "敏感文本，输出只回显长度和 redaction 状态"),
            ("--oid <oid>", "可选 responder oid"),
            ("--exact", "保留兼容选项，当前 embedded runtime 使用直接插入"),
        ]),
        "clear": ChineseCommandHelp(name: "clear", overview: "清空当前焦点或指定输入框。", usage: "triton clear [选项]", options: target + hostPort + formatTextJSON + [
            ("--oid <oid>", "可选 responder oid"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
            ("--at <x,y>", "聚焦该 window 点位后清空"),
        ]),
        "press": ChineseCommandHelp(name: "press", overview: "按下运行时支持的设备按钮。", usage: "triton press <button> [选项]", options: target + hostPort + formatTextJSON + [
            ("<button>", "按钮名，例如 home"),
            ("--button <button>", "兼容入口；与位置参数二选一"),
            ("--duration <seconds>", "按住时长"),
        ]),
        "hit": ChineseCommandHelp(name: "hit", overview: "对当前 App window 点位做 hit-test。", usage: "triton hit --at <x,y> [选项]", options: target + hostPort + formatTextJSON + [
            ("--at <x,y>", "window 点位"),
            ("--x <x>", "window x 坐标，需与 --y 同时使用"),
            ("--y <y>", "window y 坐标，需与 --x 同时使用"),
        ]),
    ]
}


struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print Triton CLI version and bootstrap defaults")

    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() throws {
        let language = effectiveLanguage(localization.language)
        let response = TKCLIVersionResponse(version: TritonKitBuildInfo.cliVersion, language: language.rawValue)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            switch language {
            case .en:
                print(response.version)
            case .zh:
                print("版本: \(response.version)")
            }
        }
    }
}

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read local TritonKit server status")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let client = TritonKitHTTPClient(host: host, port: port)
        let outputFormat = effectiveFormat(format, json: json)
        let language = effectiveLanguage(localization.language)
        do {
            let status: TKStatusResponse = try await client.getJSON("/status")
            switch outputFormat {
            case .json:
                print(try encodeJSON(TKCLIStatusEnvelope(
                    ok: true,
                    serverReachable: true,
                    connected: status.connected,
                    latestHierarchyAvailable: status.latestHierarchyAvailable,
                    targetCount: status.targetCount,
                    runtime: status.connected ? "embedded" : "none",
                    activeHierarchyAvailable: status.activeHierarchyAvailable,
                    hierarchyCacheState: status.hierarchyCacheState,
                    targetConnectionState: status.targetConnectionState
                )))
            case .text:
                switch language {
                case .en:
                    print("connected: \(status.connected)")
                    print("latestHierarchyAvailable: \(status.latestHierarchyAvailable)")
                    print("activeHierarchyAvailable: \(status.activeHierarchyAvailable ?? (status.connected && status.latestHierarchyAvailable))")
                    print("hierarchyCacheState: \(status.hierarchyCacheState ?? "unknown")")
                    print("targetConnectionState: \(status.targetConnectionState ?? (status.connected ? "connected" : "disconnected"))")
                    print("targetCount: \(status.targetCount)")
                case .zh:
                    print("已连接: \(status.connected)")
                    print("已有最新层级: \(status.latestHierarchyAvailable)")
                    print("当前连接已有层级: \(status.activeHierarchyAvailable ?? (status.connected && status.latestHierarchyAvailable))")
                    print("层级缓存状态: \(status.hierarchyCacheState ?? "unknown")")
                    print("目标连接状态: \(status.targetConnectionState ?? (status.connected ? "connected" : "disconnected"))")
                    print("目标数量: \(status.targetCount)")
                }
            }
        } catch {
            if outputFormat == .json {
                try printCLIError(error, endpoint: "/status", host: host, port: port)
                throw ExitCode.failure
            }
            printCLIErrorText(error, endpoint: "/status", host: host, port: port, language: language)
            throw ExitCode.failure
        }
    }
}

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Diagnose server, target, and runtime capabilities")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let response = await buildCapabilities(host: host, port: port)
        try printCapabilities(response, format: effectiveFormat(format, json: json), language: effectiveLanguage(localization.language))
    }
}

struct Capabilities: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print machine-readable Triton runtime capabilities")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let response = await buildCapabilities(host: host, port: port)
        try printCapabilities(response, format: effectiveFormat(format, json: json), language: effectiveLanguage(localization.language))
    }
}

struct Schema: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print machine-readable command schemas and examples")

    @Option(help: "Command name to filter, for example tap or export") var command: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let commands = commandSchemas()
        let filtered: [TKCommandSchema]
        if let command {
            filtered = commands.filter { $0.name == command }
            guard !filtered.isEmpty else {
                throw RuntimeError("Unknown command schema: \(command)")
            }
        } else {
            filtered = commands
        }
        let response = TKCLISchemaResponse(commands: filtered)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            print(renderSchema(response, language: effectiveLanguage(localization.language)))
        }
    }
}

struct Runtime: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runtime",
        abstract: "Inspect embedded runtime capabilities and boundaries",
        subcommands: [RuntimeManifest.self]
    )
}

struct RuntimeManifest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "manifest",
        abstract: "Read the embedded runtime manifest"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let data = try await client.request(type: "runtimeManifest")
            let manifest = try JSONDecoder().decode(TKRuntimeManifestResponse.self, from: data)
            switch outputFormat {
            case .json:
                print(try encodeJSON(manifest))
            case .text:
                print("ok: \(manifest.ok)")
                print("platform: \(manifest.platform)")
                print("runtime: \(manifest.runtime)")
                print("transport: \(manifest.transport)")
                print("enabled: \(manifest.enabled)")
                print("sdkVersion: \(manifest.sdkVersion)")
                print("buildConfiguration: \(manifest.buildConfiguration)")
                print("capabilities:")
                for capability in manifest.capabilities {
                    let status = capability.supported ? "supported" : "unsupported"
                    let reason = capability.reason.map { " reason=\($0)" } ?? ""
                    print("  - \(capability.name): \(status) scope=\(capability.scope) boundary=\(capability.boundary)\(reason)")
                }
                print("limits: maxSnapshotBytes=\(manifest.limits.maxSnapshotBytes) maxAXNodes=\(manifest.limits.maxAXNodes) maxLedgerEntries=\(manifest.limits.maxLedgerEntries)")
                print("redaction: secureText=\(manifest.redaction.secureText) clipboard=\(manifest.redaction.clipboard) network=\(manifest.redaction.network) logs=\(manifest.redaction.logs)")
            }
        } catch {
            if let exitCode = error as? ExitCode {
                throw exitCode
            }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct State: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "state",
        abstract: "Read embedded app runtime state",
        subcommands: [StateApp.self, StateScene.self, StateRoute.self, StateResponder.self]
    )
}

struct StateApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "app", abstract: "Read app identity and environment state")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateApp", target: target, host: host, port: port, format: format, json: json)
    }
}

struct StateScene: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scene", abstract: "Read scene and window state")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateScene", target: target, host: host, port: port, format: format, json: json)
    }
}

struct StateRoute: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "route", abstract: "Read controller route and container state")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateRoute", target: target, host: host, port: port, format: format, json: json)
    }
}

struct StateResponder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "responder", abstract: "Read first responder and text input traits")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runStateRequest(type: "stateResponder", target: target, host: host, port: port, format: format, json: json)
    }
}

func runStateRequest(
    type: String,
    target: String,
    host: String,
    port: Int,
    format: ClientOutputFormat,
    json: Bool
) async throws {
    let outputFormat = effectiveFormat(format, json: json)
    do {
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        let data = try await client.request(type: type)
        switch outputFormat {
        case .json:
            print(String(data: data, encoding: .utf8) ?? "{}")
        case .text:
            if let object = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: pretty, encoding: .utf8) {
                print(text)
            } else {
                print(String(data: data, encoding: .utf8) ?? "")
            }
        }
    } catch {
        if let exitCode = error as? ExitCode {
            throw exitCode
        }
        try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
    }
}

struct Plan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print recommended next CLI steps or inspect a replay plan")

    @Argument(help: "Optional action. Use `inspect` to summarize a .tritonplan without connecting to runtime.") var action: String?
    @Argument(help: "Replay plan path for `inspect`.") var input: String?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        if let action {
            let outputFormat = effectiveFormat(format, json: json)
            guard action == "inspect" else {
                try failReplayValidation("Unsupported plan action: \(action)", outputFormat: outputFormat)
            }
            guard let input else {
                try failReplayValidation("`triton plan inspect` requires a .tritonplan path", outputFormat: outputFormat)
            }
            do {
                let plan = try readReplayPlan(from: input)
                let summary = TKReplayPlanSummary(ok: true, path: input, plan: plan)
                switch outputFormat {
                case .json:
                    print(try encodeJSON(summary))
                case .text:
                    print("ok: true")
                    print("path: \(summary.path)")
                    print("schemaVersion: \(summary.schemaVersion)")
                    if let name = summary.name { print("name: \(name)") }
                    print("stepCount: \(summary.stepCount)")
                    print("actions: \(summary.actions.joined(separator: ","))")
                }
            } catch {
                if error is ExitCode { throw error }
                try failReplayValidation("\(error)", outputFormat: outputFormat)
            }
            return
        }
        guard input == nil else {
            try failReplayValidation("Unexpected plan argument: \(input ?? "")", outputFormat: effectiveFormat(format, json: json))
        }
        let capabilities = await buildCapabilities(host: host, port: port)
        let plan = buildWorkflowPlan(capabilities: capabilities, host: host, port: port)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(plan))
        case .text:
            print(renderWorkflowPlan(plan, language: effectiveLanguage(localization.language)))
        }
    }
}

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List connected TritonKit targets")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Filter by app name substring") var nameContains: String?
    @Option(help: "Filter by bundle identifier") var bundleID: String?
    @Flag(help: "Print only target ids") var idsOnly = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let client = TritonKitHTTPClient(host: host, port: port)
        let language = effectiveLanguage(localization.language)
        let response: TKTargetsResponse
        do {
            response = try await client.getJSON("/targets")
        } catch {
            let outputFormat = effectiveFormat(format, json: json)
            if outputFormat == .json {
                try printCLIError(error, endpoint: "/targets", host: host, port: port)
                throw ExitCode.failure
            }
            printCLIErrorText(error, endpoint: "/targets", host: host, port: port, language: language)
            throw ExitCode.failure
        }
        let targets = filter(response.targets)

        if idsOnly {
            for target in targets {
                print(target.id)
            }
            return
        }

        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(TKTargetsResponse(targets: targets)))
        case .text:
            if targets.isEmpty {
                switch language {
                case .en:
                    print("No connected TritonKit targets")
                case .zh:
                    print("没有已连接的 TritonKit 目标")
                }
            } else {
                for target in targets {
                    print(renderTargetLine(target))
                }
            }
        }
    }

    private func filter(_ targets: [TKTargetSummary]) -> [TKTargetSummary] {
        targets.filter { target in
            if let nameContains,
               target.appName?.range(of: nameContains, options: .caseInsensitive) == nil {
                return false
            }
            if let bundleID, target.bundleIdentifier != bundleID {
                return false
            }
            return true
        }
    }
}

struct Inspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect one TritonKit target")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let summary = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        switch outputFormat {
        case .json:
            print(try encodeJSON(summary))
        case .text:
            print("id: \(summary.id)")
            print("transport: \(summary.transport)")
            print("connected: \(summary.connected)")
            print("latestHierarchyAvailable: \(summary.latestHierarchyAvailable)")
            print("appName: \(summary.appName ?? "-")")
            print("bundleIdentifier: \(summary.bundleIdentifier ?? "-")")
            print("device: \(summary.deviceDescription ?? "-")")
            print("os: \(summary.osDescription ?? "-")")
        }
    }
}

struct Hierarchy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch the latest hierarchy from a TritonKit target")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: tree or json") var format: HierarchyOutputFormat = .tree
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Write output to a file instead of stdout") var output: String?
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before reading the latest snapshot")
    var refresh = true
    @Flag(inversion: .prefixedNo, help: "Hide low-signal UIKit wrapper views in tree output")
    var hideNoise = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let data = try await waitForHierarchy(client: client)
        let rendered: String
        switch outputFormat {
        case .json:
            rendered = try prettyJSON(data)
        case .tree:
            rendered = try renderHierarchyTree(data, hideNoise: hideNoise)
        }
        try writeOrPrint(rendered, output: output)
    }
}

struct Nodes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List nodes from the latest hierarchy snapshot")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before listing nodes")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let data = try await waitForHierarchy(client: client)
        let nodes = try hierarchyNodeSummaries(data)
        switch outputFormat {
        case .json:
            print(try encodeJSONObject(["nodes": nodes]))
        case .text:
            for node in nodes {
                print(renderNodeLine(node))
            }
        }
    }
}

struct Node: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect one hierarchy node from the latest snapshot")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "View or layer oid from `triton nodes`") var oid: UInt
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before reading the node")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let data = try await waitForHierarchy(client: client)
        guard let node = try hierarchyNodeSummaries(data).first(where: { nodeMatches($0, oid: oid) }) else {
            throw RuntimeError("Node not found: \(oid)")
        }
        switch outputFormat {
        case .json:
            print(try encodeJSONObject(node))
        case .text:
            print("oid: \(node["oid"] ?? "-")")
            print("viewOid: \(node["viewOid"] ?? "-")")
            print("layerOid: \(node["layerOid"] ?? "-")")
            print("className: \(node["className"] ?? "-")")
            print("depth: \(node["depth"] ?? "-")")
            print("frame: \(node["frame"] ?? "-")")
            print("hidden: \(node["hidden"] ?? "-")")
            print("alpha: \(node["alpha"] ?? "-")")
        }
    }
}

struct Attrs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Fetch live attribute groups for a node layer oid")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Layer oid from `triton nodes`") var oid: UInt
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        let payload = try JSONEncoder().encode(oid)
        let data = try await client.request(type: "allAttrGroups", payload: payload)
        switch outputFormat {
        case .json:
            print(try prettyJSON(data))
        case .text:
            let groups = try JSONDecoder().decode([TKAttributesGroup].self, from: data)
            print(renderAttributeGroups(groups))
        }
    }
}

struct ObjectInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "object",
        abstract: "Fetch live object metadata for a view or layer oid"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Object oid from `triton nodes`") var oid: UInt
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        let payload = try JSONEncoder().encode(oid)
        let data = try await client.request(type: "fetchObject", payload: payload)
        switch outputFormat {
        case .json:
            print(try prettyJSON(data))
        case .text:
            let object = try JSONDecoder().decode(TKObject.self, from: data)
            print("oid: \(object.oid)")
            print("address: \(object.memoryAddress)")
            print("class: \(object.rawClassName)")
            print("classChain: \(object.classChainList.joined(separator: " -> "))")
        }
    }
}

struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export a reusable hierarchy snapshot or archive")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output file path") var output: String
    @Option(help: "Export format: auto, json, or archive") var format: ExportOutputFormat = .auto
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before exporting")
    var refresh = true

    func run() async throws {
        let resolvedFormat = try resolveExportFormat(effectiveFormat(format, json: json), output: output)
        let targetSummary = try await resolveTarget(
            target,
            host: host,
            port: port,
            jsonError: json || resolvedFormat == .json
        )
        let client = TritonKitHTTPClient(host: host, port: port)
        if refresh {
            try await client.sendCommand("hierarchy")
        }
        let hierarchyData = try await waitForHierarchy(client: client)
        let data: Data
        switch resolvedFormat {
        case .json, .auto:
            data = hierarchyData
        case .archive:
            let archive = try await buildExportArchive(
                target: targetSummary,
                hierarchyData: hierarchyData,
                client: client
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            data = try encoder.encode(archive)
        }
        try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        print(output)
    }
}

struct Evidence: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture or inspect an agent-friendly regression evidence bundle"
    )

    @Argument(help: "Optional action. Use `inspect` to read an existing bundle manifest.") var action: String?
    @Argument(help: "Evidence bundle path for `inspect`.") var input: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Evidence bundle directory path") var output: String?
    @Option(help: "Comma-separated artifacts: screenshot,ax,hierarchy,status,list,version,geometry,archive,logs")
    var include: String = "status,list,version,hierarchy,ax,screenshot"
    @Option(help: "Scenario name stored in manifest") var name: String?
    @Option(help: "Human note stored in manifest") var note: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before capturing hierarchy/archive")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        if let action {
            guard action == "inspect" else {
                try failEvidenceValidation("Unsupported evidence action: \(action)", outputFormat: outputFormat)
            }
            guard let input else {
                try failEvidenceValidation("`triton evidence inspect` requires a bundle path", outputFormat: outputFormat)
            }
            let manifest = try readEvidenceManifest(from: input)
            try printEvidenceManifest(manifest, format: outputFormat)
            return
        }

        guard input == nil else {
            try failEvidenceValidation("Unexpected evidence argument: \(input ?? "")", outputFormat: outputFormat)
        }
        guard let output else {
            try failEvidenceValidation("`triton evidence` requires --output <path>", outputFormat: outputFormat)
        }

        let includes: [String]
        do {
            includes = try parseEvidenceIncludes(include)
        } catch {
            try failEvidenceValidation("\(error)", outputFormat: outputFormat)
        }
        do {
            let manifest = try await captureEvidenceBundle(
                output: output,
                includes: includes,
                name: name,
                note: note,
                target: target,
                host: host,
                port: port,
                refresh: refresh
            )
            try printEvidenceManifest(manifest, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/evidence", host: host, port: port)
        }
    }
}

struct Capture: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture an agent-friendly regression evidence bundle"
    )

    @Option(name: .customLong("case"), help: "Regression case name stored in manifest") var caseName: String?
    @Option(help: "Evidence bundle directory path") var output: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Comma-separated artifacts")
    var include: String = "status,list,version,hierarchy,ax,screenshot,geometry,archive"
    @Option(help: "Human note stored in manifest") var note: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before capturing hierarchy/archive")
    var refresh = true

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let includes: [String]
        do {
            includes = try parseEvidenceIncludes(include)
        } catch {
            try failRegressionValidation("\(error)", command: "capture", outputFormat: outputFormat)
        }
        do {
            let manifest = try await captureEvidenceBundle(
                output: output,
                includes: includes,
                name: caseName,
                note: note,
                target: target,
                host: host,
                port: port,
                refresh: refresh
            )
            try printEvidenceManifest(manifest, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/capture", host: host, port: port)
        }
    }
}

struct UIAssert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assert",
        abstract: "Assert visible UI text state for agent-driven regression"
    )

    @Argument(help: "Assertion condition: text-exists or text-not-exists") var condition: String
    @Argument(help: "Visible text, AX label, identifier, title, or value to assert") var query: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Optional AX role filter") var role: String?
    @Option(help: "Require exact match count") var count: Int?
    @Option(name: .customLong("min-count"), help: "Require at least this many matches") var minCount: Int?
    @Option(name: .customLong("max-count"), help: "Require at most this many matches") var maxCount: Int?
    @Option(help: "Restrict assertion to bounds: x,y,width,height") var within: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard let assertionCondition = TKUIAssertCondition(rawValue: condition) else {
                try failRegressionValidation("Unsupported assert condition: \(condition)", command: "assert", outputFormat: outputFormat)
            }
            let exactCountProvided = count != nil
            if exactCountProvided && (minCount != nil || maxCount != nil) {
                try failRegressionValidation("--count cannot be combined with --min-count or --max-count", command: "assert", outputFormat: outputFormat)
            }
            if let count, count < 0 {
                try failRegressionValidation("--count must be non-negative", command: "assert", outputFormat: outputFormat)
            }
            if let minCount, minCount < 0 {
                try failRegressionValidation("--min-count must be non-negative", command: "assert", outputFormat: outputFormat)
            }
            if let maxCount, maxCount < 0 {
                try failRegressionValidation("--max-count must be non-negative", command: "assert", outputFormat: outputFormat)
            }
            if let minCount, let maxCount, minCount > maxCount {
                try failRegressionValidation("--min-count cannot be greater than --max-count", command: "assert", outputFormat: outputFormat)
            }
            let bounds: TKRect?
            do {
                bounds = try within.map(parseAssertBounds)
            } catch {
                try failRegressionValidation("\(error)", command: "assert", outputFormat: outputFormat)
            }
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let status: TKStatusResponse = try await client.getJSON("/status")
            let accessibilityData = try await client.request(type: "accessibility")
            let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
            let request = TKUIAssertRequest(
                condition: assertionCondition,
                query: query,
                role: role,
                count: count,
                minCount: minCount,
                maxCount: maxCount,
                within: bounds
            )
            let result = TKUIAssertEvaluate(
                request,
                nodes: nodes,
                targetConnectionState: status.targetConnectionState,
                hierarchyCacheState: status.hierarchyCacheState
            )
            try printAssertResult(result, format: outputFormat)
            if !result.ok {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/assert", host: host, port: port)
        }
    }
}

struct Record: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create an editable replay plan template. This is not interactive recording yet."
    )

    @Option(help: "Output .tritonplan file path") var output: String
    @Option(help: "Plan name. Defaults to the output file basename.") var name: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        let outputFormat = effectiveFormat(format, json: json)
        let outputURL = URL(fileURLWithPath: output)
        let planName = name ?? outputURL.deletingPathExtension().lastPathComponent
        let plan = TKReplayPlan.template(name: planName.isEmpty ? "smoke-flow" : planName)
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try prettyEncodedData(plan).write(to: outputURL, options: .atomic)
            let response = TKRecordPlanResponse(
                ok: true,
                output: outputURL.path,
                templateOnly: true,
                message: "Created editable Triton replay plan template; interactive recording is not implemented yet",
                plan: plan
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print(outputURL.path)
                print("templateOnly: true")
            }
        } catch {
            if error is ExitCode { throw error }
            try failReplayValidation("\(error)", outputFormat: outputFormat)
        }
    }
}

struct Replay: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Replay a .tritonplan smoke-test flow")

    @Argument(help: "Replay plan path") var input: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Validate and print commands without connecting to runtime") var dryRun = false
    @Option(name: .customLong("var"), help: "Variable assignment: key=value or key-env=ENV_NAME")
    var variables: [String] = []

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let plan = try readReplayPlan(from: input)
            let resolvedVariables = try parseReplayVariables(variables)
            let result = try await runReplayPlan(
                plan,
                variables: resolvedVariables,
                dryRun: dryRun,
                target: plan.target?.id ?? target,
                host: host,
                port: port
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(result))
            case .text:
                print("ok: \(result.ok)")
                if let planName = result.planName { print("plan: \(planName)") }
                print("dryRun: \(result.dryRun)")
                print("executed: \(result.executedCount)/\(result.stepCount)")
                if let failedStepIndex = result.failedStepIndex {
                    print("failedStepIndex: \(failedStepIndex)")
                }
                for step in result.steps {
                    print("[\(step.index)] \(step.action) ok=\(step.ok) \(step.command.joined(separator: " "))")
                }
            }
            if !result.ok {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failReplayValidation("\(error)", outputFormat: outputFormat)
        }
    }
}

struct Find: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Resolve a UI target by visible text, label, identifier, or option title")

    @Argument(help: "Text, label, identifier, or visible option title to resolve") var query: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Include all matching candidates with stable 1-based indexes") var all = false
    @Option(help: "Select one matching candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            if within != nil && at != nil {
                if outputFormat == .json {
                    try printValidationError("--within and --at cannot be used together")
                    throw ExitCode.failure
                }
                throw RuntimeError("--within and --at cannot be used together")
            }
            let bounds = try within.map(parseBounds)
            let point = try at.map(parsePoint)
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let resolution = try await resolveTapTarget(
                query,
                client: client,
                width: nil,
                height: nil,
                duration: nil,
                index: index,
                within: bounds,
                at: point,
                includeCandidates: all
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(resolution))
            case .text:
                print("query: \(resolution.query)")
                print("source: \(resolution.source)")
                print("strategy: \(resolution.strategy)")
                if let label = resolution.label { print("label: \(label)") }
                if let value = resolution.value { print("value: \(value)") }
                if let identifier = resolution.identifier { print("identifier: \(identifier)") }
                if let className = resolution.className { print("className: \(className)") }
                if let targetOID = resolution.targetOID { print("targetOID: \(targetOID)") }
                if let viewOID = resolution.viewOID { print("viewOID: \(viewOID)") }
                if let layerOID = resolution.layerOID { print("layerOID: \(layerOID)") }
                if let frame = resolution.frame { print("frame: \(formatRect(frame))") }
                print("matchIndex: \(resolution.matchIndex)")
                print("matchCount: \(resolution.matchCount)")
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Wait: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Wait for text, disappearance, idle state, hierarchy change, or a safe predicate"
    )

    @Option(name: .customLong("text"), help: "Visible text, AX label, identifier, title, or value to wait for") var text: String?
    @Option(name: .customLong("gone"), help: "Visible text, AX label, identifier, title, or value to wait to disappear") var gone: String?
    @Option(name: .customLong("exists"), help: "Alias for --text; can be combined with --role") var exists: String?
    @Flag(name: .customLong("idle"), help: "Wait until the target is connected and hierarchy is stable across two polls") var idle = false
    @Flag(name: .customLong("hierarchy-change"), help: "Wait until the hierarchy snapshot changes") var hierarchyChange = false
    @Option(name: .customLong("since"), help: "Hierarchy change baseline; currently supports latest") var since: String = "latest"
    @Option(name: .customLong("predicate"), help: "Safe predicate using text.exists/gone with &&, ||, !") var predicate: String?
    @Option(name: .customLong("role"), help: "Optional AX role filter for --text or --exists") var role: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Timeout in seconds") var timeout: Double = 10
    @Option(help: "Polling interval in seconds") var interval: Double = 0.5

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selectorCount = [
                text != nil,
                gone != nil,
                exists != nil,
                idle,
                hierarchyChange,
                predicate != nil,
            ].filter { $0 }.count
            guard selectorCount == 1 else {
                if outputFormat == .json {
                    try printValidationError("Provide exactly one wait condition: --text, --gone, --exists, --idle, --hierarchy-change, or --predicate")
                    throw ExitCode.failure
                }
                throw RuntimeError("Provide exactly one wait condition")
            }
            guard timeout > 0 else {
                if outputFormat == .json {
                    try printValidationError("--timeout must be greater than 0")
                    throw ExitCode.failure
                }
                throw RuntimeError("--timeout must be greater than 0")
            }
            guard interval > 0 else {
                if outputFormat == .json {
                    try printValidationError("--interval must be greater than 0")
                    throw ExitCode.failure
                }
                throw RuntimeError("--interval must be greater than 0")
            }
            if hierarchyChange && since != "latest" {
                if outputFormat == .json {
                    try printValidationError("--since currently supports only latest")
                    throw ExitCode.failure
                }
                throw RuntimeError("--since currently supports only latest")
            }

            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let request = WaitRequest(
                condition: waitCondition(),
                query: text ?? gone ?? exists,
                predicate: predicate,
                role: role,
                timeout: timeout,
                interval: interval
            )
            let result = try await performWait(request, client: client)
            try printWaitResult(result, format: outputFormat)
            if !result.ok {
                throw ExitCode.failure
            }
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }

    private func waitCondition() -> TKWaitCondition {
        if text != nil { return .text }
        if gone != nil { return .gone }
        if exists != nil { return .exists }
        if idle { return .idle }
        if hierarchyChange { return .hierarchyChange }
        return .predicate
    }
}

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tap a UI target by text, coordinate, oid, or AX node")

    @Argument(help: "Text, label, identifier, or visible option title to tap") var query: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Window x coordinate in points") var x: Double?
    @Option(help: "Window y coordinate in points") var y: Double?
    @Option(help: "View oid from `triton nodes`") var oid: UInt?
    @Option(name: .customLong("ax-oid"), help: "AX target/view oid from `triton ax`") var axOID: UInt?
    @Option(name: .customLong("ax-label"), help: "Exact AX label to tap by AX target/view oid") var axLabel: String?
    @Option(help: "Optional screen/window width in points") var width: Double?
    @Option(help: "Optional screen/window height in points") var height: Double?
    @Option(help: "Hold duration in seconds") var duration: Double?
    @Option(help: "Select one matching query candidate by 1-based index") var index: Int?
    @Option(help: "Restrict query matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Coordinate selector or query disambiguation point: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let selectorCount = [
            query != nil,
            oid != nil,
            x != nil || y != nil,
            query == nil && at != nil,
            axOID != nil,
            axLabel != nil,
        ].filter { $0 }.count
        guard selectorCount == 1 else {
            if effectiveFormat(format, json: json) == .json {
                try printValidationError("Provide exactly one target selector: <query>, --oid, --x/--y, --at, --ax-oid, or --ax-label")
                throw ExitCode.failure
            }
            throw RuntimeError("Provide exactly one target selector: <query>, --oid, --x/--y, --at, --ax-oid, or --ax-label")
        }
        if (index != nil || within != nil) && query == nil {
            if outputFormat == .json {
                try printValidationError("--index and --within can only be used with <query>")
                throw ExitCode.failure
            }
            throw RuntimeError("--index and --within can only be used with <query>")
        }
        if within != nil && at != nil {
            if outputFormat == .json {
                try printValidationError("--within and --at cannot be used together")
                throw ExitCode.failure
            }
            throw RuntimeError("--within and --at cannot be used together")
        }
        if at != nil && (x != nil || y != nil) {
            if outputFormat == .json {
                try printValidationError("--at cannot be combined with --x/--y")
                throw ExitCode.failure
            }
            throw RuntimeError("--at cannot be combined with --x/--y")
        }
        if (x == nil) != (y == nil) {
            if outputFormat == .json {
                try printValidationError("--x and --y must be provided together")
                throw ExitCode.failure
            }
            throw RuntimeError("--x and --y must be provided together")
        }

        do {
            let point = try at.map(parsePoint)
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            if let query {
                let client = TritonKitHTTPClient(host: host, port: port)
                let bounds = try within.map(parseBounds)
                let resolution = try await resolveTapTarget(
                    query,
                    client: client,
                    width: width,
                    height: height,
                    duration: duration,
                    index: index,
                    within: bounds,
                    at: point
                )
                try await runInputRequest(resolution.request, host: host, port: port, format: outputFormat)
                return
            }

            if axOID != nil || axLabel != nil {
                let client = TritonKitHTTPClient(host: host, port: port)
                let data = try await client.request(type: "accessibility")
                let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
                guard let node = selectAXNode(nodes, oid: axOID, label: axLabel) else {
                    let message = axOID.map { "AX node not found for oid \($0)" } ?? "AX node not found for label \(axLabel ?? "")"
                    if outputFormat == .json {
                        try printValidationError(message)
                        throw ExitCode.failure
                    }
                    throw RuntimeError(message)
            }
            let request = tapRequest(for: node, width: width, height: height, duration: duration)
            try await runInputRequest(request, host: host, port: port, format: outputFormat)
            return
        }

            let request = TKInputRequest.tap(
                x: point?.x ?? x,
                y: point?.y ?? y,
                targetOID: oid,
                width: width,
                height: height,
                duration: duration
            )
            try await runInputRequest(request, host: host, port: port, format: outputFormat)
        } catch {
            if error is ExitCode { throw error }
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Swipe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Swipe inside the app using window-point coordinates")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(name: .customLong("start-x"), help: "Start x coordinate in points") var startX: Double
    @Option(name: .customLong("start-y"), help: "Start y coordinate in points") var startY: Double
    @Option(name: .customLong("end-x"), help: "End x coordinate in points") var endX: Double
    @Option(name: .customLong("end-y"), help: "End y coordinate in points") var endY: Double
    @Option(help: "Optional screen/window width in points") var width: Double?
    @Option(help: "Optional screen/window height in points") var height: Double?
    @Option(help: "Gesture duration in seconds") var duration: Double?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let request = TKInputRequest.swipe(
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                width: width,
                height: height,
                duration: duration
            )
            try await runInputRequest(request, host: host, port: port, format: outputFormat)
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct TypeText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text into a focused or oid-targeted UIKeyInput"
    )

    @Argument(help: "Text to insert") var textArgument: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Text to insert; kept for compatibility with older scripts") var text: String?
    @Option(help: "Optional responder oid from `triton nodes`") var oid: UInt?
    @Flag(name: .customLong("secure"), help: "Redact inserted text details in command output") var secure = false
    @Flag(name: .customLong("exact"), help: "Use direct UIKeyInput insertion without keyboard autocorrect") var exact = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selectorCount = [textArgument != nil, text != nil].filter { $0 }.count
            guard selectorCount == 1 else {
                if outputFormat == .json {
                    try printValidationError("Provide exactly one text value: <text> or --text")
                    throw ExitCode.failure
                }
                throw RuntimeError("Provide exactly one text value: <text> or --text")
            }
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest(type: .typeText, targetOID: oid, text: textArgument ?? text, secure: secure),
                host: host,
                port: port,
                format: outputFormat
            )
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct PasteText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paste",
        abstract: "Paste exact text into a focused, coordinate-targeted, or oid-targeted input"
    )

    @Argument(help: "Text to paste") var text: String
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(name: .customLong("secure"), help: "Redact inserted text details in command output") var secure = false
    @Option(help: "Optional responder oid from `triton nodes`, `triton ax`, or `triton hit`") var oid: UInt?
    @Option(help: "Window x coordinate to focus before paste") var x: Double?
    @Option(help: "Window y coordinate to focus before paste") var y: Double?
    @Option(help: "Window point to focus before paste: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let point = try inputFocusPoint(at: at, x: x, y: y, outputFormat: outputFormat)
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.paste(text, targetOID: oid, x: point?.x ?? x, y: point?.y ?? y, secure: secure),
                host: host,
                port: port,
                format: outputFormat
            )
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct ClearText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Clear a focused, coordinate-targeted, or oid-targeted input"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Optional responder oid from `triton nodes`, `triton ax`, or `triton hit`") var oid: UInt?
    @Option(help: "Window x coordinate to focus before clear") var x: Double?
    @Option(help: "Window y coordinate to focus before clear") var y: Double?
    @Option(help: "Window point to focus before clear: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let point = try inputFocusPoint(at: at, x: x, y: y, outputFormat: outputFormat)
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.clear(targetOID: oid, x: point?.x ?? x, y: point?.y ?? y),
                host: host,
                port: port,
                format: outputFormat
            )
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Press: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Press a device button when supported by the active runtime")

    @Argument(help: "Button name, for example home, lock, power, volume-up") var buttonArgument: String?
    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Button name, for example home, lock, power, volume-up; kept for compatibility") var button: String?
    @Option(help: "Hold duration in seconds") var duration: Double?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selectorCount = [buttonArgument != nil, button != nil].filter { $0 }.count
            guard selectorCount == 1 else {
                if outputFormat == .json {
                    try printValidationError("Provide exactly one button value: <button> or --button")
                    throw ExitCode.failure
                }
                throw RuntimeError("Provide exactly one button value: <button> or --button")
            }
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            try await runInputRequest(
                TKInputRequest.press(button: buttonArgument ?? button ?? "", duration: duration),
                host: host,
                port: port,
                format: outputFormat
            )
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Geometry: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read current window geometry")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let data = try await client.request(type: "geometry")
            let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: data)
            switch outputFormat {
            case .json:
                print(try encodeJSON(geometry))
            case .text:
                print("bounds: \(formatRect(geometry.bounds))")
                print("safeArea: top=\(geometry.safeArea.top) left=\(geometry.safeArea.left) bottom=\(geometry.safeArea.bottom) right=\(geometry.safeArea.right)")
                print("scale: \(geometry.scale)")
                print("orientation: \(geometry.orientation)")
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct AccessibilityTree: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ax",
        abstract: "Read current in-app safe actionable control index"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(name: .customLong("with-hierarchy"), help: "Join AX nodes to latest hierarchy by view oid") var withHierarchy = false
    @Flag(inversion: .prefixedNo, help: "Request a fresh hierarchy before joining with --with-hierarchy") var refresh = true
    @Option(help: "Write output to a file instead of stdout") var output: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let data = try await client.request(type: "accessibility")
            let rendered: String
            switch outputFormat {
            case .json:
                if withHierarchy {
                    let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
                    let hierarchyData = refresh
                        ? try await client.request(type: "hierarchy")
                        : try await waitForHierarchy(client: client)
                    let response = try TKBuildAXHierarchyMap(axNodes: nodes, hierarchyData: hierarchyData)
                    rendered = try encodeJSON(response)
                } else {
                    rendered = try prettyJSON(data)
                }
            case .text:
                let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
                if withHierarchy {
                    let hierarchyData = refresh
                        ? try await client.request(type: "hierarchy")
                        : try await waitForHierarchy(client: client)
                    let response = try TKBuildAXHierarchyMap(axNodes: nodes, hierarchyData: hierarchyData)
                    rendered = renderAXHierarchyMap(response)
                } else {
                    rendered = renderAXTree(nodes)
                }
            }
            try writeOrPrint(rendered, output: output)
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Hit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Hit-test one point in the current app window")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Option(help: "Window x coordinate in points") var x: Double?
    @Option(help: "Window y coordinate in points") var y: Double?
    @Option(help: "Window point to hit-test: x,y") var at: String?

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let point = try requiredPoint(at: at, x: x, y: y, outputFormat: outputFormat)
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let payload = try JSONEncoder().encode(TKHitTestRequest(x: point.x, y: point.y))
            let data = try await client.request(type: "hitTest", payload: payload)
            let response = try JSONDecoder().decode(TKHitTestResponse.self, from: data)
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("x: \(response.x)")
                print("y: \(response.y)")
                print("center: \(response.centerX.map(String.init(describing:)) ?? "-"),\(response.centerY.map(String.init(describing:)) ?? "-")")
                if let node = response.node {
                    print("role: \(node.role)")
                    print("label: \(node.label ?? "-")")
                    print("identifier: \(node.identifier ?? "-")")
                    print("targetOID: \(node.targetOID.map(String.init(describing:)) ?? "-")")
                    print("className: \(node.className ?? "-")")
                    print("frame: \(formatRect(node.frame))")
                } else {
                    print("node: -")
                }
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Screenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Capture current app screenshot as PNG")

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output PNG file path") var output: String
    @Flag(help: "Print screenshot metadata as JSON after writing the file") var metadata = false
    @Flag(name: .customLong("json"), help: "Alias for --metadata") var json = false

    func run() async throws {
        let outputFormat: ClientOutputFormat = metadata || json ? .json : .text
        do {
            _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
            let client = TritonKitHTTPClient(host: host, port: port)
            let data = try await client.request(type: "screenshot")
            let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)
            let imageData = try await screenshotImageData(screenshot, client: client)
            try imageData.write(to: URL(fileURLWithPath: output), options: .atomic)
            if outputFormat == .json {
                let summary: [String: Any] = [
                    "format": screenshot.format,
                    "width": screenshot.width,
                    "height": screenshot.height,
                    "scale": screenshot.scale,
                    "output": output,
                    "bytes": imageData.count,
                ]
                print(try encodeJSONObject(summary))
            } else {
                print(output)
            }
        } catch {
            try failCommand(error, outputFormat: outputFormat, endpoint: "/request", host: host, port: port)
        }
    }
}

struct Input: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "input",
        abstract: "Read newline-delimited JSON input actions from stdin"
    )

    @Option(help: "Target id from `triton list`") var target: String = TKLocalTargetID
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Stop on the first failed action") var failFast = false
    @Flag(help: "Print a final JSON batch summary") var summary = false
    @Flag(help: "Exit non-zero when any action fails") var strict = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        _ = try await resolveTarget(target, host: host, port: port, jsonError: outputFormat == .json)
        let client = TritonKitHTTPClient(host: host, port: port)
        var hadFailure = false
        var actionCount = 0
        var failedCount = 0

        while let line = readLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            actionCount += 1
            let result: TKInputResult
            do {
                let data = Data(trimmed.utf8)
                let input = try JSONDecoder().decode(TKInputRequest.self, from: data)
                result = try await executeInputRequest(input, client: client)
            } catch {
                result = TKInputResult.failure(action: "input", message: "\(error)")
            }
            try printInputResult(result, format: outputFormat)
            fflush(stdout)
            if !result.ok {
                hadFailure = true
                failedCount += 1
                if failFast { break }
            }
        }

        if summary {
            let response = TKInputBatchSummaryResponse(
                ok: failedCount == 0,
                actionCount: actionCount,
                failedCount: failedCount
            )
            switch outputFormat {
            case .json:
                print(try encodeCompactJSON(response))
            case .text:
                print("summary: ok=\(response.ok) actionCount=\(response.actionCount) failedCount=\(response.failedCount)")
            }
            fflush(stdout)
        }

        if hadFailure && (failFast || strict) {
            throw RuntimeError("Input failed")
        }
    }
}

// MARK: - State

final class ConnectionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _outbound: WebSocketOutboundWriter?
    private var connectionID = 0

    func connect(_ w: WebSocketOutboundWriter) -> Int {
        lock.withLock {
            connectionID += 1
            _outbound = w
            return connectionID
        }
    }

    func disconnect(connectionID id: Int) -> Bool {
        lock.withLock {
            guard connectionID == id else { return false }
            _outbound = nil
            return true
        }
    }

    var outbound: WebSocketOutboundWriter? { lock.withLock { _outbound } }
    var isConnected: Bool { lock.withLock { _outbound != nil } }
}

final class MessageCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

struct TargetMetadata: Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var deviceDescription: String?
    var osDescription: String?
}

final class TargetState: @unchecked Sendable {
    private let lock = NSLock()
    private var _latestHierarchy: Data?
    private var metadata: TargetMetadata?
    private var activeHierarchyAvailable = false
    private var responses: [Int: Data] = [:]

    var latestHierarchy: Data? {
        lock.withLock { _latestHierarchy }
    }

    func beginConnection() {
        lock.withLock {
            metadata = nil
            activeHierarchyAvailable = false
            responses.removeAll()
        }
    }

    func endConnection() {
        lock.withLock {
            metadata = nil
            activeHierarchyAvailable = false
            responses.removeAll()
        }
    }

    func setLatestHierarchy(_ data: Data) {
        let appInfo = extractAppInfo(fromHierarchy: data)
        lock.withLock {
            _latestHierarchy = data
            activeHierarchyAvailable = true
            if let appInfo {
                metadata = appInfo
            }
        }
    }

    func setLatestAppInfo(_ data: Data) {
        guard let appInfo = extractAppInfo(fromAppInfoPayload: data) else { return }
        lock.withLock {
            metadata = appInfo
        }
    }

    func summary(connected: Bool) -> TKTargetSummary? {
        guard connected else { return nil }
        return lock.withLock {
            TKTargetSummary(
                connected: true,
                latestHierarchyAvailable: activeHierarchyAvailable,
                appName: metadata?.appName,
                bundleIdentifier: metadata?.bundleIdentifier,
                deviceDescription: metadata?.deviceDescription,
                osDescription: metadata?.osDescription,
                activeHierarchyAvailable: activeHierarchyAvailable,
                cachedHierarchyAvailable: _latestHierarchy != nil,
                hierarchyCacheState: hierarchyCacheState(connected: true),
                identityState: metadata == nil ? "unknown" : "current"
            )
        }
    }

    func cacheStatus(connected: Bool) -> (activeHierarchyAvailable: Bool, hierarchyCacheState: String) {
        lock.withLock {
            (
                activeHierarchyAvailable,
                hierarchyCacheState(connected: connected)
            )
        }
    }

    func storeResponse(id: Int, payload: Data) {
        lock.withLock {
            responses[id] = payload
        }
    }

    func waitForResponse(id: Int, attempts: Int = 25) async -> Data? {
        for _ in 0..<attempts {
            if let data = lock.withLock({ responses.removeValue(forKey: id) }) {
                return data
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func extractAppInfo(fromHierarchy data: Data) -> TargetMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appInfo = json["appInfo"] as? [String: Any] else {
            return nil
        }
        return extractMetadata(from: appInfo)
    }

    private func extractAppInfo(fromAppInfoPayload data: Data) -> TargetMetadata? {
        guard let appInfo = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractMetadata(from: appInfo)
    }

    private func extractMetadata(from appInfo: [String: Any]) -> TargetMetadata {
        TargetMetadata(
            appName: appInfo["appName"] as? String,
            bundleIdentifier: appInfo["appBundleIdentifier"] as? String,
            deviceDescription: appInfo["deviceDescription"] as? String,
            osDescription: appInfo["osDescription"] as? String
        )
    }

    private func hierarchyCacheState(connected: Bool) -> String {
        if connected && activeHierarchyAvailable { return "active" }
        if _latestHierarchy != nil { return "stale" }
        return "unavailable"
    }
}

/// Thread-safe binary data store keyed by UUID
final class DataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: Data] = [:]

    func put(_ data: Data) -> UUID {
        let id = UUID()
        lock.withLock { storage[id] = data }
        return id
    }

    func get(_ id: UUID) -> Data? {
        lock.withLock { storage[id] }
    }
}

func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) -> Response {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value) else {
        return Response(status: .internalServerError)
    }
    return Response(status: status, headers: [.contentType: "application/json"],
                    body: .init(byteBuffer: ByteBuffer(data: data)))
}

func jsonError(_ message: String, status: HTTPResponse.Status) -> Response {
    jsonError(code: "request_failed", message: message, status: status)
}

func jsonError(
    code: String,
    message: String,
    endpoint: String? = nil,
    hint: String? = nil,
    status: HTTPResponse.Status
) -> Response {
    jsonResponse(
        TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: code,
            message: message,
            endpoint: endpoint,
            hint: hint
        )),
        status: status
    )
}

func jsonError(detail: TKCLIErrorDetail, status: HTTPResponse.Status) -> Response {
    jsonResponse(TKCLIErrorResponse(error: detail), status: status)
}

struct TritonKitHTTPClient {
    let host: String
    let port: Int

    func getData(_ path: String) async throws -> Data {
        try await data(for: URLRequest(url: url(path)))
    }

    func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let data = try await getData(path)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func postJSON<Request: Encodable, Response: Decodable>(_ path: String, body: Request) async throws -> Response {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func sendCommand(_ type: String) async throws {
        let _: TKCLICommandResponse = try await postJSON("/command", body: TKCLICommandRequest(type: type))
    }

    func request(type: String, payload: Data? = nil) async throws -> Data {
        try await postRawJSON("/request", body: TKCLICommandRequest(type: type, payload: payload))
    }

    private func url(_ path: String) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        return components.url!
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RuntimeError("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CLIHTTPError(statusCode: http.statusCode, data: data)
        }
        return data
    }

    private func postRawJSON<Request: Encodable>(_ path: String, body: Request) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await data(for: request)
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

struct CLIHTTPError: Error, CustomStringConvertible {
    let statusCode: Int
    let data: Data
    let response: TKCLIErrorResponse?

    init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
        self.response = try? JSONDecoder().decode(TKCLIErrorResponse.self, from: data)
    }

    var description: String {
        if let response {
            return "HTTP \(statusCode) \(response.error.code): \(response.error.message)"
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return "HTTP \(statusCode) \(body)"
    }
}

struct RuntimeRequestTimeoutError: Error, CustomStringConvertible {
    let requestType: String

    var description: String {
        "Timed out waiting for \(requestType) response"
    }
}

func resolveTarget(_ target: String, host: String, port: Int) async throws -> TKTargetSummary {
    let client = TritonKitHTTPClient(host: host, port: port)
    let response: TKTargetsResponse = try await client.getJSON("/targets")
    return try TKResolveTargetSummary(target, in: response.targets)
}

func resolveTarget(
    _ target: String,
    host: String,
    port: Int,
    jsonError: Bool
) async throws -> TKTargetSummary {
    do {
        return try await resolveTarget(target, host: host, port: port)
    } catch {
        if jsonError {
            try printCLIError(error, endpoint: "/targets", host: host, port: port)
            throw ExitCode.failure
        }
        printCLIErrorText(error, endpoint: "/targets", host: host, port: port, language: effectiveLanguage(nil))
        throw ExitCode.failure
    }
}

func buildCapabilities(host: String, port: Int) async -> TKCapabilitiesResponse {
    let client = TritonKitHTTPClient(host: host, port: port)
    do {
        let status: TKStatusResponse = try await client.getJSON("/status")
        return TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: status.connected,
            latestHierarchyAvailable: status.latestHierarchyAvailable,
            targetCount: status.targetCount,
            runtime: status.connected ? "embedded" : "none",
            capabilities: runtimeCapabilities(connected: status.connected),
            activeHierarchyAvailable: status.activeHierarchyAvailable,
            hierarchyCacheState: status.hierarchyCacheState,
            targetConnectionState: status.targetConnectionState
        )
    } catch {
        let detail = cliErrorDetail(for: error, endpoint: "/status", host: host, port: port)
        return TKCapabilitiesResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "unknown",
            capabilities: runtimeCapabilities(connected: false),
            error: detail
        )
    }
}

func runtimeCapabilities(connected: Bool) -> [TKRuntimeCapability] {
    let requiresRuntime = connected ? nil : "Requires connected embedded TritonKit runtime"
    return [
        TKRuntimeCapability(name: "plan", supported: true),
        TKRuntimeCapability(name: "record", supported: true),
        TKRuntimeCapability(name: "replay-dry-run", supported: true),
        TKRuntimeCapability(name: "schema", supported: true),
        TKRuntimeCapability(name: "runtime-manifest", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-app", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-scene", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-route", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-responder", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "host-device", supported: true),
        TKRuntimeCapability(name: "harmony-device-doctor", supported: true),
        TKRuntimeCapability(name: "harmony-device-list", supported: true),
        TKRuntimeCapability(name: "harmony-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "status", supported: true),
        TKRuntimeCapability(name: "list", supported: true),
        TKRuntimeCapability(name: "inspect", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hierarchy", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "nodes", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "node", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "attrs", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "object", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-json", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-archive", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "geometry", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ax", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hit", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "screenshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "wait", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "capture", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "assert", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "replay", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "tap", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "swipe", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "type", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "paste", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "clear", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "input", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "press", supported: false, reason: "Host-side HID is not available in the embedded runtime"),
    ]
}

func printCapabilities(_ response: TKCapabilitiesResponse, format: ClientOutputFormat, language: CLILanguage = effectiveLanguage(nil)) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        switch language {
        case .en:
            print("ok: \(response.ok)")
            print("serverReachable: \(response.serverReachable)")
            print("connected: \(response.connected)")
            print("latestHierarchyAvailable: \(response.latestHierarchyAvailable)")
            print("activeHierarchyAvailable: \(response.activeHierarchyAvailable ?? (response.connected && response.latestHierarchyAvailable))")
            print("hierarchyCacheState: \(response.hierarchyCacheState ?? "unknown")")
            print("targetConnectionState: \(response.targetConnectionState ?? (response.connected ? "connected" : "disconnected"))")
            print("targetCount: \(response.targetCount)")
            print("runtime: \(response.runtime)")
        case .zh:
            print("正常: \(response.ok)")
            print("服务可达: \(response.serverReachable)")
            print("已连接: \(response.connected)")
            print("已有最新层级: \(response.latestHierarchyAvailable)")
            print("当前连接已有层级: \(response.activeHierarchyAvailable ?? (response.connected && response.latestHierarchyAvailable))")
            print("层级缓存状态: \(response.hierarchyCacheState ?? "unknown")")
            print("目标连接状态: \(response.targetConnectionState ?? (response.connected ? "connected" : "disconnected"))")
            print("目标数量: \(response.targetCount)")
            print("运行时: \(response.runtime)")
        }
        if let error = response.error {
            switch language {
            case .en:
                print("error: \(error.code) \(error.message)")
            case .zh:
                print("错误: \(localizedErrorMessage(error, language: language))")
            }
            if let hint = error.hint {
                switch language {
                case .en:
                    print("hint: \(hint)")
                case .zh:
                    print("提示: \(localizedHint(error, fallback: hint, language: language))")
                }
            }
        }
        print(language == .zh ? "能力:" : "capabilities:")
        for capability in response.capabilities {
            let status = capability.supported
                ? (language == .zh ? "支持" : "supported")
                : (language == .zh ? "不支持" : "unsupported")
            if let reason = capability.reason {
                print("  \(capability.name): \(status) (\(reason))")
            } else {
                print("  \(capability.name): \(status)")
            }
        }
    }
}

func buildWorkflowPlan(
    capabilities: TKCapabilitiesResponse,
    host: String,
    port: Int
) -> TKWorkflowPlanResponse {
    if !capabilities.serverReachable {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: capabilities.runtime,
            nextStep: "start-server",
            steps: [
                TKWorkflowPlanStep(
                    id: "start-server",
                    title: "Start Triton server",
                    command: "triton serve --host \(host) --port \(port)",
                    requiresServer: false,
                    requiresTarget: false,
                    when: "serverReachable == false",
                    expected: "Server listens on \(host):\(port)"
                ),
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "open the iOS app or run the simulator build that embeds TritonKit",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "triton status reports connected: true"
                ),
                TKWorkflowPlanStep(
                    id: "diagnose",
                    title: "Re-check machine-readable runtime state",
                    command: "triton doctor --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after starting server and target",
                    expected: "ok=true, serverReachable=true, connected=true"
                ),
            ],
            error: capabilities.error
        )
    }

    if !capabilities.connected {
        return TKWorkflowPlanResponse(
            ok: false,
            serverReachable: true,
            connected: false,
            runtime: capabilities.runtime,
            nextStep: "connect-target",
            steps: [
                TKWorkflowPlanStep(
                    id: "connect-target",
                    title: "Launch an app with embedded TritonKit runtime",
                    command: "open the iOS app or run the simulator build that embeds TritonKit",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "serverReachable == true && connected == false",
                    expected: "WebSocket target connects to ws://\(host):\(port)/"
                ),
                TKWorkflowPlanStep(
                    id: "list-targets",
                    title: "List connected targets",
                    command: "triton list --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after target launch",
                    expected: "targets contains triton:local"
                ),
                TKWorkflowPlanStep(
                    id: "diagnose",
                    title: "Confirm capability matrix",
                    command: "triton doctor --host \(host) --port \(port) --format json",
                    requiresServer: true,
                    requiresTarget: false,
                    when: "after target connects",
                    expected: "embedded runtime capabilities become supported"
                ),
            ],
            error: TKCLIErrorDetail(
                code: "target_unavailable",
                message: "Triton server is reachable but no embedded runtime is connected",
                endpoint: endpointURL("/status", host: host, port: port),
                hint: "Launch an app that embeds TritonKit, then run `triton doctor --format json`"
            )
        )
    }

    return TKWorkflowPlanResponse(
        ok: true,
        serverReachable: true,
        connected: true,
        runtime: capabilities.runtime,
        nextStep: "observe",
        steps: [
            TKWorkflowPlanStep(
                id: "geometry",
                title: "Read screen and window geometry",
                command: "triton geometry --host \(host) --port \(port) --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "connected == true",
                expected: "JSON geometry response"
            ),
            TKWorkflowPlanStep(
                id: "ax",
                title: "Build actionable accessibility index",
                command: "triton ax --host \(host) --port \(port) --format json --output /tmp/triton-ax.json",
                requiresServer: true,
                requiresTarget: true,
                when: "connected == true",
                expected: "Safe machine-readable controls"
            ),
            TKWorkflowPlanStep(
                id: "wait",
                title: "Wait for asynchronous UI state",
                command: "triton wait --host \(host) --port \(port) --text <text> --timeout 10 --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "after taps, submissions, and navigation",
                expected: "Machine-readable wait result with elapsedMs and timeout state"
            ),
            TKWorkflowPlanStep(
                id: "hit",
                title: "Resolve a coordinate before acting",
                command: "triton hit --host \(host) --port \(port) --x <x> --y <y> --format json",
                requiresServer: true,
                requiresTarget: true,
                when: "before coordinate input",
                expected: "Hit-test node or empty result"
            ),
                TKWorkflowPlanStep(
                    id: "input",
                    title: "Execute NDJSON input actions",
                    command: "triton input --host \(host) --port \(port) --format json --summary --strict < gestures.ndjson",
                    requiresServer: true,
                    requiresTarget: true,
                    when: "after selecting safe actions",
                    expected: "Input results plus a final summary; non-zero exit when any action fails"
                ),
            TKWorkflowPlanStep(
                id: "screenshot",
                title: "Capture visual evidence",
                command: "triton screenshot --host \(host) --port \(port) --output /tmp/triton.png --metadata",
                requiresServer: true,
                requiresTarget: true,
                when: "after state changes",
                expected: "PNG plus metadata JSON"
            ),
            TKWorkflowPlanStep(
                id: "export",
                title: "Export replayable inspection archive",
                command: "triton export --host \(host) --port \(port) --format archive --output /tmp/triton.triton",
                requiresServer: true,
                requiresTarget: true,
                when: "when handing off context",
                expected: "Self-contained .triton archive"
            ),
        ]
    )
}

func renderWorkflowPlan(_ plan: TKWorkflowPlanResponse, language: CLILanguage = effectiveLanguage(nil)) -> String {
    if language == .zh {
        return renderWorkflowPlanZH(plan)
    }
    var lines = [
        "ok: \(plan.ok)",
        "serverReachable: \(plan.serverReachable)",
        "connected: \(plan.connected)",
        "runtime: \(plan.runtime)",
        "nextStep: \(plan.nextStep)",
    ]
    if let error = plan.error {
        lines.append("error: \(error.code) \(error.message)")
        if let hint = error.hint {
            lines.append("hint: \(hint)")
        }
        if let nextAction = error.nextAction {
            let command = ([nextAction.command] + nextAction.args).joined(separator: " ")
            lines.append("nextAction: triton \(command)")
            lines.append("requiresLongRunningProcess: \(nextAction.requiresLongRunningProcess)")
        }
    }
    lines.append("steps:")
    for step in plan.steps {
        lines.append("  \(step.id): \(step.title)")
        lines.append("    command: \(step.command)")
        lines.append("    when: \(step.when)")
        lines.append("    expected: \(step.expected)")
    }
    return lines.joined(separator: "\n")
}

func renderWorkflowPlanZH(_ plan: TKWorkflowPlanResponse) -> String {
    var lines = [
        "正常: \(plan.ok)",
        "服务可达: \(plan.serverReachable)",
        "已连接: \(plan.connected)",
        "运行时: \(plan.runtime)",
        "下一步: \(plan.nextStep)",
    ]
    if let error = plan.error {
        lines.append("错误: \(localizedErrorMessage(error, language: .zh))")
        if let hint = error.hint {
            lines.append("提示: \(localizedHint(error, fallback: hint, language: .zh))")
        }
        if let nextAction = error.nextAction {
            let command = ([nextAction.command] + nextAction.args).joined(separator: " ")
            lines.append("下一步命令: triton \(command)")
            lines.append("需要长驻进程: \(nextAction.requiresLongRunningProcess)")
        }
    }
    lines.append("步骤:")
    for step in plan.steps {
        lines.append("  \(step.id): \(step.title)")
        lines.append("    命令: \(step.command)")
        lines.append("    条件: \(step.when)")
        lines.append("    预期: \(step.expected)")
    }
    return lines.joined(separator: "\n")
}

func printCLIError(_ error: Error, endpoint: String, host: String, port: Int) throws {
    let response = TKCLIErrorResponse(error: cliErrorDetail(
        for: error,
        endpoint: endpoint,
        host: host,
        port: port
    ))
    print(try encodeJSON(response))
}

func printCLIErrorText(_ error: Error, endpoint: String, host: String, port: Int, language: CLILanguage = effectiveLanguage(nil)) {
    let detail = cliErrorDetail(for: error, endpoint: endpoint, host: host, port: port)
    switch language {
    case .en:
        fputs("\(detail.code): \(detail.message)\n", stderr)
    case .zh:
        fputs("\(detail.code): \(localizedErrorMessage(detail, language: language))\n", stderr)
    }
    if let endpoint = detail.endpoint {
        fputs("\(language == .zh ? "端点" : "endpoint"): \(endpoint)\n", stderr)
    }
    if let hint = detail.hint {
        fputs("\(language == .zh ? "提示" : "hint"): \(localizedHint(detail, fallback: hint, language: language))\n", stderr)
    }
    if let nextAction = detail.nextAction {
        let command = (["triton", nextAction.command] + nextAction.args).joined(separator: " ")
        fputs("\(language == .zh ? "下一步" : "next"): \(command)\n", stderr)
    }
}

func failCommand(
    _ error: Error,
    outputFormat: ClientOutputFormat,
    endpoint: String,
    host: String,
    port: Int
) throws -> Never {
    switch outputFormat {
    case .json:
        if let httpError = error as? CLIHTTPError,
           let response = httpError.response {
            print(try encodeJSON(response))
        } else {
            try printCLIError(error, endpoint: endpoint, host: host, port: port)
        }
    case .text:
        printCLIErrorText(error, endpoint: endpoint, host: host, port: port)
    }
    throw ExitCode.failure
}

func localizedErrorMessage(_ detail: TKCLIErrorDetail, language: CLILanguage) -> String {
    guard language == .zh else { return "\(detail.code) \(detail.message)" }
    switch detail.code {
    case "server_unavailable":
        return "服务器不可用：无法连接到本地 Triton 服务。"
    case "request_failed":
        return "请求失败：\(detail.message)"
    case "validation_failed":
        return "参数校验失败：\(detail.message)"
    default:
        return "\(detail.code)：\(detail.message)"
    }
}

func localizedHint(_ detail: TKCLIErrorDetail, fallback: String, language: CLILanguage) -> String {
    guard language == .zh else { return fallback }
    switch detail.code {
    case "server_unavailable":
        return "运行 `triton serve --host 127.0.0.1 --port 19421` 并连接 iOS App"
    default:
        return fallback
    }
}

func printValidationError(_ message: String) throws {
    let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "validation_failed",
        message: message,
        hint: "Run `triton schema --command tap --json` to inspect required fields"
    ))
    print(try encodeJSON(response))
}

func cliErrorDetail(for error: Error, endpoint: String, host: String, port: Int) -> TKCLIErrorDetail {
    let url = endpointURL(endpoint, host: host, port: port)
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return response.error
    }
    if let urlError = error as? URLError {
        return TKCLIErrorDetail(
            code: "server_unavailable",
            message: urlError.localizedDescription,
            endpoint: url,
            hint: "Run `triton serve --host \(host) --port \(port)` and connect the iOS app",
            nextAction: TKCLINextAction(
                command: "serve",
                args: ["--host", host, "--port", "\(port)"],
                requiresLongRunningProcess: true
            )
        )
    }
    if let runtime = error as? RuntimeError {
        return TKCLIErrorDetail(
            code: "request_failed",
            message: runtime.description,
            endpoint: url,
            hint: "Check `triton doctor --format json` for server and target state"
        )
    }
    return TKCLIErrorDetail(
        code: "request_failed",
        message: "\(error)",
        endpoint: url,
        hint: "Check `triton doctor --format json` for server and target state"
    )
}

func endpointURL(_ endpoint: String, host: String, port: Int) -> String {
    "http://\(host):\(port)\(endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)")"
}

func renderTargetLine(_ target: TKTargetSummary) -> String {
    [
        target.id,
        target.transport,
        target.identityState ?? "-",
        target.hierarchyCacheState ?? "-",
        target.appName ?? "-",
        target.bundleIdentifier ?? "-",
        target.deviceDescription ?? "-",
        target.osDescription ?? "-",
    ].joined(separator: "\t")
}

func commandSchemas() -> [TKCommandSchema] {
    let hostPort = [
        TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "127.0.0.1", description: "Triton server host"),
        TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Triton server port"),
    ]
    let target = TKCommandSchemaOption(name: "--target", type: "String", defaultValue: TKLocalTargetID, description: "Target id from `triton list`; commands auto-select the only connected target when omitted")
    let jsonText = ["text", "json"]
    let formatTextJSON = TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format")
    let formatJSONText = TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format")
    let jsonAlias = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --format json")
    let languageOption = TKCommandSchemaOption(name: "--language/--lang", type: "en|zh", defaultValue: "TRITON_LANGUAGE or en", description: "Human-readable output language")
    let metadataJSONAlias = TKCommandSchemaOption(name: "--json", type: "Bool", defaultValue: "false", description: "Alias for --metadata")
    let refreshOption = TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before reading")
    return [
        TKCommandSchema(
            name: "version",
            summary: "Print Triton CLI version and bootstrap defaults",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton version --format json"],
            successShape: "{ ok, version, schemaVersion, defaultHost, defaultPort, language, supportedLanguages }"
        ),
        TKCommandSchema(
            name: "serve",
            summary: "Start the local WebSocket and HTTP control server",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli-long-running",
            exitCodeOnFailure: 1,
            outputFormats: ["logs"],
            options: [
                TKCommandSchemaOption(name: "--host", type: "String", defaultValue: "0.0.0.0", description: "Host to bind to"),
                TKCommandSchemaOption(name: "--port", type: "Int", defaultValue: "19421", description: "Port to listen on"),
            ],
            examples: ["triton serve --host 127.0.0.1 --port 19421"],
            successShape: "Long-running process; exposes /status, /targets, /request, /input, /hierarchy/latest and WebSocket /"
        ),
        TKCommandSchema(
            name: "status",
            summary: "Read local TritonKit server status",
            requiresServer: true,
            requiresTarget: false,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton status --format json"],
            successShape: "{ ok, serverReachable, connected, latestHierarchyAvailable, activeHierarchyAvailable, hierarchyCacheState, targetConnectionState, targetCount, runtime }",
            failureShape: "{ ok: false, error: { code, message, endpoint, hint, nextAction? } }"
        ),
        TKCommandSchema(
            name: "doctor",
            summary: "Diagnose server, target, and runtime capabilities",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton doctor --format json"],
            successShape: "{ ok, serverReachable, connected, latestHierarchyAvailable, activeHierarchyAvailable, hierarchyCacheState, targetConnectionState, runtime, capabilities, error? }"
        ),
        TKCommandSchema(
            name: "plan",
            summary: "Print recommended next CLI steps or inspect a replay plan",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: hostPort + [
                TKCommandSchemaOption(name: "inspect <path>", type: "Subcommand", description: "Read a .tritonplan summary without connecting to runtime"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                languageOption,
            ],
            examples: ["triton plan --format json", "triton plan --format text", "triton plan inspect login-flow.tritonplan --json"],
            successShape: "{ ok, serverReachable, connected, runtime, nextStep, steps[], error? } or { ok, path, schemaVersion, name, variables, stepCount, actions, target? }",
            failureShape: nil,
            providedCapabilities: ["plan"]
        ),
        TKCommandSchema(
            name: "capabilities",
            summary: "Print runtime capability matrix",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 0,
            outputFormats: jsonText,
            options: hostPort + [TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"), jsonAlias, languageOption],
            examples: ["triton capabilities --format json"],
            successShape: "{ ok, serverReachable, connected, runtime, capabilities[] }"
        ),
        TKCommandSchema(
            name: "schema",
            summary: "Print machine-readable command schemas and examples",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            exitCodeOnFailure: 1,
            outputFormats: jsonText,
            options: [
                TKCommandSchemaOption(name: "--command", type: "String", description: "Optional command name to filter"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                languageOption,
            ],
            examples: ["triton schema --json", "triton schema --command input --json"],
            successShape: "{ schemaVersion, commands[] }"
        ),
        TKCommandSchema(
            name: "runtime",
            summary: "Inspect embedded runtime manifest, capabilities, limits, and redaction policy",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            exitCodeOnFailure: 1,
            outputFormats: jsonText,
            options: hostPort + [
                TKCommandSchemaOption(name: "manifest", type: "Subcommand", description: "Read embedded runtime manifest"),
                target,
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                languageOption,
            ],
            examples: ["triton runtime manifest --json"],
            successShape: "{ ok, platform, runtime, transport, enabled, sdkVersion, buildConfiguration, capabilities[], limits, redaction }",
            providedCapabilities: ["runtime-manifest"]
        ),
        TKCommandSchema(
            name: "state",
            summary: "Read embedded app, scene, route, and responder state",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            exitCodeOnFailure: 1,
            outputFormats: jsonText,
            options: hostPort + [
                TKCommandSchemaOption(name: "app", type: "Subcommand", description: "Read app identity, locale, display style, uptime, scene/window counts"),
                TKCommandSchemaOption(name: "scene", type: "Subcommand", description: "Read UIWindowScene and UIWindow summaries"),
                TKCommandSchemaOption(name: "route", type: "Subcommand", description: "Read visible UIViewController, navigation, tab, and presented stack"),
                TKCommandSchemaOption(name: "responder", type: "Subcommand", description: "Read first responder identity and text input traits without text content"),
                target,
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                languageOption,
            ],
            examples: [
                "triton state app --json",
                "triton state scene --json",
                "triton state route --json",
                "triton state responder --json",
            ],
            successShape: "{ ok, capturedAt, runtime, targetConnectionState, app|scenes|route|firstResponder, warnings[], unsupported[] }",
            providedCapabilities: ["state-app", "state-scene", "state-route", "state-responder"]
        ),
        TKCommandSchema(
            name: "device",
            summary: "Discover and inspect host-side platform devices",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "host-device",
            exitCodeOnFailure: 1,
            outputFormats: jsonText + ["jsonl"],
            options: [
                TKCommandSchemaOption(name: "doctor --platform harmony", type: "Subcommand", description: "Probe DevEco Emulator and HDC tool availability"),
                TKCommandSchemaOption(name: "list --platform harmony", type: "Subcommand", description: "List Harmony HDC targets"),
                TKCommandSchemaOption(name: "use --platform harmony --target <target>", type: "Subcommand", description: "Resolve one Connected target"),
                TKCommandSchemaOption(name: "wait-ready --platform harmony --target <target>", type: "Subcommand", description: "Poll bootevent.boot.completed until ready"),
                TKCommandSchemaOption(name: "--platform", type: "harmony", defaultValue: "harmony", description: "Host platform adapter"),
                TKCommandSchemaOption(name: "--hdc", type: "Path", defaultValue: "hdc", description: "HDC executable path"),
                TKCommandSchemaOption(name: "--target", type: "String", description: "Harmony target, for example 127.0.0.1:10100"),
                TKCommandSchemaOption(name: "--timeout", type: "Double", defaultValue: "30", description: "Bounded wait timeout in seconds"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton device doctor --platform harmony --json",
                "triton device list --platform harmony --json",
                "triton device wait-ready --platform harmony --target 127.0.0.1:10100 --json",
            ],
            successShape: "{ ok, platform, tools[]?, targets[]?, defaultTarget?, target?, ready?, sourceCommand? }",
            failureShape: "{ ok:false, error:{ code: ambiguous_target|target_offline|device_not_ready|host_action_failed, message, hint } }",
            providedCapabilities: ["host-device", "harmony-device"]
        ),
        TKCommandSchema(
            name: "sim",
            summary: "Control simulators through host-side Apple tools",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "host-simulator",
            exitCodeOnFailure: 1,
            outputFormats: jsonText + ["jsonl"],
            options: [
                TKCommandSchemaOption(name: "list", type: "Subcommand", description: "List available simulators"),
                TKCommandSchemaOption(name: "use <udid>", type: "Subcommand", description: "Set workspace default simulator in .triton/host-defaults.json"),
                TKCommandSchemaOption(name: "boot <udid>", type: "Subcommand", description: "Boot a simulator"),
                TKCommandSchemaOption(name: "--wait", type: "Bool", defaultValue: "false", description: "Wait until booted"),
                TKCommandSchemaOption(name: "--jsonl", type: "Bool", defaultValue: "false", description: "Emit JSON Lines progress with --wait"),
                TKCommandSchemaOption(name: "shutdown <udid|booted>", type: "Subcommand", description: "Shutdown a simulator"),
                TKCommandSchemaOption(name: "screenshot --output <path>", type: "Subcommand", description: "Capture simulator framebuffer screenshot"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton sim list --json",
                "triton sim use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json",
                "triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json",
                "triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl",
                "triton sim screenshot --simulator booted --output /tmp/sim.png --json",
            ],
            successShape: "{ ok, simulators[] } or { ok, action, simulator?, defaultsPath? } or { ok, action, runtimeScope, target, tool, exitCode, artifacts[], note? } or JSONL { ok, action, state, ready, attempt, elapsedMs }",
            failureShape: "{ ok:false, error:{ code, message, hint, nextAction? } }",
            providedCapabilities: ["host-simulator"]
        ),
        TKCommandSchema(
            name: "app",
            summary: "Control local simulator and emulator apps through host-side tools",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "host-simulator|host-harmony",
            exitCodeOnFailure: 1,
            outputFormats: jsonText,
            options: [
                TKCommandSchemaOption(name: "list", type: "Subcommand", description: "List installed simulator apps"),
                TKCommandSchemaOption(name: "info --bundle-id <id>", type: "Subcommand", description: "Show installed app metadata"),
                TKCommandSchemaOption(name: "inspect --platform harmony --bundle <bundle>", type: "Subcommand", description: "Inspect a Harmony app with bm dump"),
                TKCommandSchemaOption(name: "install --app <path.app>", type: "Subcommand", description: "Install an .app bundle into the simulator"),
                TKCommandSchemaOption(name: "uninstall --bundle-id <id> --confirm", type: "Subcommand", description: "Uninstall an app from the simulator"),
                TKCommandSchemaOption(name: "launch --bundle-id <id>", type: "Subcommand", description: "Launch an installed simulator app"),
                TKCommandSchemaOption(name: "launch --platform harmony --bundle <bundle> --ability <ability>", type: "Subcommand", description: "Launch a Harmony app ability"),
                TKCommandSchemaOption(name: "terminate --bundle-id <id>", type: "Subcommand", description: "Terminate a running simulator app"),
                TKCommandSchemaOption(name: "open-url <url>", type: "Subcommand", description: "Submit a URL to the simulator"),
                TKCommandSchemaOption(name: "container --bundle-id <id>", type: "Subcommand", description: "Print app container path"),
                TKCommandSchemaOption(name: "prefs dump --bundle-id <id>", type: "Subcommand", description: "Dump app preferences plist as JSON"),
                TKCommandSchemaOption(name: "prefs get <key> --bundle-id <id>", type: "Subcommand", description: "Read one app preference"),
                TKCommandSchemaOption(name: "--simulator", type: "String", defaultValue: "booted", description: "Simulator UDID or booted"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton app list --user-only --json",
                "triton app info --bundle-id com.example.app --json",
                "triton app inspect --platform harmony --bundle com.example.app --json",
                "triton app install --app /tmp/Demo.app --json",
                "triton app uninstall --bundle-id com.example.app --confirm --json",
                "triton app launch --bundle-id com.example.app --json",
                "triton app launch --platform harmony --bundle com.example.app --ability EntryAbility --json",
                "triton app terminate --bundle-id com.example.app --json",
                #"triton app open-url "example://debug" --simulator booted --json"#,
                "triton app container --bundle-id com.example.app --kind data --json",
                "triton app prefs get DEBUG-mock --bundle-id com.example.app --json",
            ],
            successShape: "{ ok, action, simulatorUDID?, apps[]?, app?, bundleID?, path?, target?, sourceCommand? } or { ok, action, plistPath, value?, preferences? }",
            failureShape: "{ ok:false, error:{ code, message, hint, nextAction? } }",
            providedCapabilities: ["host-app", "host-preferences", "harmony-app"]
        ),
        TKCommandSchema(
            name: "list",
            summary: "List connected Triton targets",
            requiresServer: true,
            requiresTarget: false,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: hostPort + [
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
                languageOption,
                TKCommandSchemaOption(name: "--ids-only", type: "Bool", defaultValue: "false", description: "Print only target ids"),
            ],
            examples: ["triton list --format json", "triton list --ids-only"],
            successShape: "{ targets: [{ id, transport, connected, latestHierarchyAvailable, activeHierarchyAvailable, cachedHierarchyAvailable, hierarchyCacheState, identityState, appName, bundleIdentifier, deviceDescription, osDescription }] }"
        ),
        TKCommandSchema(
            name: "inspect",
            summary: "Inspect one Triton target summary",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: hostPort + [target, formatTextJSON, jsonAlias],
            examples: ["triton inspect --target triton:local --format json"],
            successShape: "{ id, transport, connected, latestHierarchyAvailable, appName, bundleIdentifier, deviceDescription, osDescription }"
        ),
        TKCommandSchema(
            name: "hierarchy",
            summary: "Read latest hierarchy snapshot",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: ["tree", "json"],
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--format", type: "tree|json", defaultValue: "tree", description: "Output format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Optional output file"),
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before reading"),
                TKCommandSchemaOption(name: "--hide-noise/--no-hide-noise", type: "Bool", defaultValue: "true", description: "Hide low-signal UIKit wrapper views in tree output"),
            ],
            examples: ["triton hierarchy --target triton:local --format json --output /tmp/hierarchy.json"],
            successShape: "TKHierarchyInfo JSON or rendered tree"
        ),
        TKCommandSchema(
            name: "nodes",
            summary: "List node summaries from the latest hierarchy snapshot",
            requiresServer: true,
            requiresTarget: true,
            requiresHierarchy: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [target, formatTextJSON, jsonAlias, refreshOption],
            examples: ["triton nodes --target triton:local --format json"],
            successShape: "{ nodes: [{ oid, viewOid, layerOid, className, depth, frame, hidden, alpha }] }"
        ),
        TKCommandSchema(
            name: "node",
            summary: "Inspect one hierarchy node by view or layer oid",
            requiresServer: true,
            requiresTarget: true,
            requiresHierarchy: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", required: true, description: "View or layer oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
                refreshOption,
            ],
            examples: ["triton node --target triton:local --oid 1 --format json"],
            successShape: "{ oid, viewOid, layerOid, className, depth, frame, hidden, alpha }"
        ),
        TKCommandSchema(
            name: "attrs",
            summary: "Fetch live attribute groups for a node layer oid",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", required: true, description: "Layer oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton attrs --target triton:local --oid 2 --format json"],
            successShape: "[TKAttributesGroup]"
        ),
        TKCommandSchema(
            name: "object",
            summary: "Fetch live object metadata for a view or layer oid",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", required: true, description: "View or layer oid from `triton nodes`"),
                formatTextJSON,
                jsonAlias,
            ],
            examples: ["triton object --target triton:local --oid 1 --format json"],
            successShape: "{ oid, memoryAddress, rawClassName, classChainList }"
        ),
        TKCommandSchema(
            name: "export",
            summary: "Export hierarchy JSON or self-contained archive",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: ["auto", "json", "archive"],
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--output", type: "Path", required: true, description: "Output file path"),
                TKCommandSchemaOption(name: "--format", type: "auto|json|archive", defaultValue: "auto", description: "Export format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before exporting"),
            ],
            examples: [
                "triton export --output /tmp/triton-hierarchy.json",
                "triton export --format archive --output /tmp/triton-smoke.triton",
            ],
            successShape: "File path on stdout; output file contains hierarchy JSON or TKExportArchive JSON"
        ),
        TKCommandSchema(
            name: "evidence",
            summary: "Capture or inspect an agent-friendly regression evidence bundle",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli+embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "inspect <path>", type: "Subcommand", description: "Read an existing bundle manifest without connecting to runtime"),
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Evidence bundle directory path; capture mode requires it"),
                TKCommandSchemaOption(name: "--include", type: "String", defaultValue: "status,list,version,hierarchy,ax,screenshot", description: "Comma-separated artifact kinds"),
                TKCommandSchemaOption(name: "--name", type: "String", description: "Scenario name stored in manifest"),
                TKCommandSchemaOption(name: "--note", type: "String", description: "Human note stored in manifest"),
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before hierarchy/archive capture"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton evidence --output /tmp/login-success.tritonevidence --json",
                "triton evidence --include status,list,version,logs --output /tmp/partial.tritonevidence --json",
                "triton evidence --name v11-login --note \"DEBUG mock disabled\" --output /tmp/login.tritonevidence --json",
                "triton evidence inspect /tmp/login-success.tritonevidence --json",
            ],
            successShape: "TKEvidenceManifest with { ok, formatVersion, output, artifacts[], skipped[], target?, cli }",
            failureShape: "Validation/request failures use { ok:false, error:{ code, message, endpoint, hint, nextAction? } }",
            providedCapabilities: ["evidence"]
        ),
        TKCommandSchema(
            name: "capture",
            summary: "Capture an agent-friendly regression evidence bundle",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "cli+embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--case", type: "String", description: "Regression case name stored in manifest"),
                TKCommandSchemaOption(name: "--output", type: "Path", required: true, description: "Evidence bundle directory path"),
                TKCommandSchemaOption(name: "--include", type: "String", defaultValue: "status,list,version,hierarchy,ax,screenshot,geometry,archive", description: "Comma-separated artifact kinds"),
                TKCommandSchemaOption(name: "--note", type: "String", description: "Human note stored in manifest"),
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before hierarchy/archive capture"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton capture --case job-search-area-filter --output /tmp/job-search-area-filter.tritonevidence --json",
            ],
            successShape: "TKEvidenceManifest with freshness metadata for captured artifacts",
            failureShape: "Validation/request failures use { ok:false, error:{ code, message, endpoint, hint, nextAction? } }",
            providedCapabilities: ["capture", "evidence"]
        ),
        TKCommandSchema(
            name: "assert",
            summary: "Assert visible UI text state for agent-driven regression",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<condition>", type: "text-exists|text-not-exists", required: true, description: "Assertion condition"),
                TKCommandSchemaOption(name: "<text>", type: "String", required: true, description: "Visible text, label, identifier, title, or value"),
                TKCommandSchemaOption(name: "--role", type: "String", description: "Optional AX role filter"),
                TKCommandSchemaOption(name: "--count", type: "Int", description: "Require exact match count"),
                TKCommandSchemaOption(name: "--min-count", type: "Int", description: "Require at least this many matches"),
                TKCommandSchemaOption(name: "--max-count", type: "Int", description: "Require at most this many matches"),
                TKCommandSchemaOption(name: "--within", type: "x,y,width,height", description: "Restrict assertion to window bounds"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                #"triton assert text-exists "Macau" --json"#,
                #"triton assert text-not-exists "Qinghai" --within 180,120,190,500 --json"#,
                #"triton assert text-exists "Macau" --role text --count 1 --json"#,
            ],
            successShape: "{ ok, condition, query, role?, count, expectedCount?, minCount?, maxCount?, within?, matches[], sample[], targetConnectionState?, hierarchyCacheState?, message? }",
            failureShape: "Failed assertions return the same result with ok=false and exit non-zero; validation/request failures use { ok:false, error:{ code, message, endpoint?, hint } }",
            providedCapabilities: ["assert"]
        ),
        TKCommandSchema(
            name: "record",
            summary: "Create an editable .tritonplan template. This is not interactive recording yet.",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli",
            outputFormats: jsonText,
            options: [
                TKCommandSchemaOption(name: "--output", type: "Path", required: true, description: "Output .tritonplan path"),
                TKCommandSchemaOption(name: "--name", type: "String", description: "Plan name; defaults to output basename"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton record --output login-flow.tritonplan --json",
            ],
            successShape: "{ ok, output, templateOnly, message, plan }",
            failureShape: "Validation/file failures use { ok:false, error:{ code, message, hint } }",
            providedCapabilities: ["record"]
        ),
        TKCommandSchema(
            name: "replay",
            summary: "Replay a .tritonplan smoke-test flow",
            requiresServer: false,
            requiresTarget: false,
            runtimeScope: "cli+embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<path>", type: "Path", required: true, description: ".tritonplan file path"),
                TKCommandSchemaOption(name: "--dry-run", type: "Bool", defaultValue: "false", description: "Validate and print commands without connecting to runtime"),
                TKCommandSchemaOption(name: "--var", type: "String", description: "Variable assignment: key=value or key-env=ENV_NAME; repeatable"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                "triton replay login-flow.tritonplan --dry-run --json",
                "triton replay login-flow.tritonplan --var username=alice --var password-env=TRITON_PASSWORD --json",
            ],
            successShape: "{ ok, dryRun, planName, stepCount, executedCount, failedStepIndex?, elapsedMs, steps[] }",
            failureShape: "Validation/request failures use { ok:false, error:{ code, message, hint } }; step failures return ok=false with failedStepIndex",
            providedCapabilities: ["replay"]
        ),
        TKCommandSchema(
            name: "find",
            summary: "Resolve a UI target by visible text, label, identifier, or option title",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<query>", type: "String", required: true, description: "Visible text, AX label, identifier, value, or option title to resolve"),
                TKCommandSchemaOption(name: "--all", type: "Bool", defaultValue: "false", description: "Include all candidates with stable 1-based indexes"),
                TKCommandSchemaOption(name: "--index", type: "Int", description: "Select one candidate by 1-based index"),
                TKCommandSchemaOption(name: "--within", type: "x,y,width,height", description: "Restrict matching to window bounds"),
                TKCommandSchemaOption(name: "--at", type: "x,y", description: "Restrict matching to candidate containing this window point"),
                formatJSONText,
                jsonAlias,
            ],
            examples: [
                #"triton find "HTTP""#,
                #"triton find "hello" --all"#,
                #"triton find "hello" --at 240,580"#,
            ],
            successShape: "TapTargetResolution describing selected target; with --all includes candidates[]"
        ),
        TKCommandSchema(
            name: "wait",
            summary: "Wait for text, disappearance, idle state, hierarchy change, or a safe predicate",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--text", type: "String", description: "Wait for visible text, AX label, identifier, title, or value"),
                TKCommandSchemaOption(name: "--gone", type: "String", description: "Wait for visible text, AX label, identifier, title, or value to disappear"),
                TKCommandSchemaOption(name: "--exists", type: "String", description: "Alias for --text; can be combined with --role"),
                TKCommandSchemaOption(name: "--role", type: "String", description: "Optional AX role filter for --text or --exists"),
                TKCommandSchemaOption(name: "--idle", type: "Bool", defaultValue: "false", description: "Wait until target is connected and hierarchy is stable across two polls"),
                TKCommandSchemaOption(name: "--hierarchy-change", type: "Bool", defaultValue: "false", description: "Wait until hierarchy snapshot changes"),
                TKCommandSchemaOption(name: "--since", type: "latest", defaultValue: "latest", description: "Hierarchy change baseline"),
                TKCommandSchemaOption(name: "--predicate", type: "String", description: #"Safe predicate, e.g. text.exists("console") && !text.exists("登录")"#),
                TKCommandSchemaOption(name: "--timeout", type: "Double", defaultValue: "10", description: "Timeout in seconds"),
                TKCommandSchemaOption(name: "--interval", type: "Double", defaultValue: "0.5", description: "Polling interval in seconds"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
            ],
            examples: [
                #"triton wait --text "console" --timeout 15 --interval 0.5 --json"#,
                #"triton wait --gone "登录" --timeout 15 --json"#,
                #"triton wait --exists "我的" --role button --timeout 10 --json"#,
                "triton wait --idle --timeout 10 --json",
                "triton wait --hierarchy-change --since latest --timeout 10 --json",
                #"triton wait --predicate "text.exists(\"console\") && !text.exists(\"点我登录\")" --timeout 15 --json"#,
            ],
            successShape: "{ ok, matched, condition, query?, predicate?, elapsedMs, pollCount, timedOut, targetConnectionState, hierarchyCacheState, lastObservedNodeCount?, lastObservedTextSample, match? }",
            failureShape: "Timeout: { ok:false, matched:false, timedOut:true, condition, elapsedMs, pollCount, lastObservedTextSample }; validation/request failures use { ok:false, error:{ code, message, endpoint, hint, nextAction? } }",
            providedCapabilities: ["wait"]
        ),
        TKCommandSchema(
            name: "ax",
            summary: "Read safe actionable control index",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--with-hierarchy", type: "Bool", defaultValue: "false", description: "Join AX nodes to hierarchy viewObject.oid and expose layer oid/path/frame"),
                TKCommandSchemaOption(name: "--refresh/--no-refresh", type: "Bool", defaultValue: "true", description: "Request fresh hierarchy before joining with --with-hierarchy"),
                TKCommandSchemaOption(name: "--output", type: "Path", description: "Optional output file"),
            ],
            examples: [
                "triton ax --format json --output /tmp/ax.json",
                "triton ax --with-hierarchy --json",
            ],
            successShape: "[TKAXNode] by default; TKAXHierarchyMapResponse when --with-hierarchy is used"
        ),
        TKCommandSchema(
            name: "geometry",
            summary: "Read current window geometry",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [target, formatTextJSON, jsonAlias],
            examples: ["triton geometry --format json"],
            successShape: "{ bounds, safeArea, scale, orientation }"
        ),
        TKCommandSchema(
            name: "hit",
            summary: "Hit-test one window coordinate",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--at", type: "x,y", description: "Window point in points"),
                TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate in points; compatibility pair with --y"),
                TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate in points; compatibility pair with --x"),
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "text", description: "Output format"),
                jsonAlias,
            ],
            examples: ["triton hit --at 270,300 --format json", "triton hit --x 270 --y 300 --format json"],
            successShape: "{ x, y, centerX?, centerY?, node? }"
        ),
        TKCommandSchema(
            name: "screenshot",
            summary: "Capture current app screenshot",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: ["file", "json-metadata"],
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--output", type: "Path", required: true, description: "Output PNG path"),
                TKCommandSchemaOption(name: "--metadata", type: "Bool", defaultValue: "false", description: "Print JSON metadata after writing"),
                metadataJSONAlias,
            ],
            examples: ["triton screenshot --output /tmp/triton.png --metadata"],
            successShape: "{ format, width, height, scale, output, bytes } when --metadata is used"
        ),
        TKCommandSchema(
            name: "tap",
            summary: "Tap a UI target by text, coordinate, view oid, or AX node",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<query>", type: "String", description: "Visible text, AX label, identifier, value, or option title to tap"),
                TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate"),
                TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate"),
                TKCommandSchemaOption(name: "--at", type: "x,y", description: "Coordinate selector without <query>, or query disambiguation point with <query>"),
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Target view oid"),
                TKCommandSchemaOption(name: "--ax-oid", type: "UInt", description: "AX target/view oid from `triton ax`; taps by runtime oid"),
                TKCommandSchemaOption(name: "--ax-label", type: "String", description: "Exact AX label from `triton ax`; taps by runtime oid"),
                TKCommandSchemaOption(name: "--index", type: "Int", description: "Select one query candidate by 1-based index from `triton find --all`"),
                TKCommandSchemaOption(name: "--within", type: "x,y,width,height", description: "Restrict query matching to window bounds"),
                formatJSONText,
                jsonAlias,
            ],
            examples: [
                #"triton tap "HTTP""#,
                #"triton tap "hello" --index 2"#,
                #"triton tap "hello" --at 240,580"#,
                #"triton tap "hello" --within 180,0,220,500"#,
                "triton tap --at 270,300",
                "triton tap --x 270 --y 300",
                "triton tap --oid 13",
                "triton tap --ax-label Save",
            ],
            successShape: "{ ok, action, message, targetOID, targetClassName }"
        ),
        TKCommandSchema(
            name: "swipe",
            summary: "Swipe inside the app using window-point coordinates",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--start-x", type: "Double", required: true, description: "Start x coordinate in window points"),
                TKCommandSchemaOption(name: "--start-y", type: "Double", required: true, description: "Start y coordinate in window points"),
                TKCommandSchemaOption(name: "--end-x", type: "Double", required: true, description: "End x coordinate in window points"),
                TKCommandSchemaOption(name: "--end-y", type: "Double", required: true, description: "End y coordinate in window points"),
                TKCommandSchemaOption(name: "--width", type: "Double", description: "Optional screen/window width in points"),
                TKCommandSchemaOption(name: "--height", type: "Double", description: "Optional screen/window height in points"),
                TKCommandSchemaOption(name: "--duration", type: "Double", description: "Gesture duration in seconds"),
                formatJSONText,
                jsonAlias,
            ],
            examples: ["triton swipe --start-x 350 --start-y 390 --end-x 100 --end-y 390"],
            successShape: "{ ok, action, message, targetOID, targetClassName }",
            providedCapabilities: ["swipe"]
        ),
        TKCommandSchema(
            name: "type",
            summary: "Type text into a focused or oid-targeted UIKeyInput",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<text>", type: "String", description: "Text to insert"),
                TKCommandSchemaOption(name: "--text", type: "String", description: "Compatibility input; mutually exclusive with <text>"),
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Optional responder oid from `triton nodes`"),
                TKCommandSchemaOption(name: "--secure", type: "Bool", defaultValue: "false", description: "Redact inserted text details in command output"),
                TKCommandSchemaOption(name: "--exact", type: "Bool", defaultValue: "false", description: "Use direct UIKeyInput insertion without keyboard autocorrect"),
                formatJSONText,
                jsonAlias,
            ],
            examples: ["triton type hello --exact", "triton type --text hello"],
            successShape: "{ ok, action, message, targetOID, targetClassName, secure?, redacted?, insertedLength? }",
            providedCapabilities: ["type"]
        ),
        TKCommandSchema(
            name: "paste",
            summary: "Paste exact text into a focused, coordinate-targeted, or oid-targeted input",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<text>", type: "String", required: true, description: "Text to paste"),
                TKCommandSchemaOption(name: "--secure", type: "Bool", defaultValue: "false", description: "Redact inserted text details in command output"),
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Optional responder oid"),
                TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate to focus before paste"),
                TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate to focus before paste"),
                TKCommandSchemaOption(name: "--at", type: "x,y", description: "Window point to focus before paste"),
                formatJSONText,
                jsonAlias,
            ],
            examples: [
                #"triton paste "console""#,
                #"triton paste --secure "aa123654""#,
                #"triton paste "console" --at 180,250"#,
                #"triton paste --x 180 --y 250 "console""#,
            ],
            successShape: "{ ok, action, message, targetOID, targetClassName, secure, redacted, insertedLength }",
            providedCapabilities: ["paste"]
        ),
        TKCommandSchema(
            name: "clear",
            summary: "Clear a focused, coordinate-targeted, or oid-targeted input",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--oid", type: "UInt", description: "Optional responder oid"),
                TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate to focus before clear"),
                TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate to focus before clear"),
                TKCommandSchemaOption(name: "--at", type: "x,y", description: "Window point to focus before clear"),
                formatJSONText,
                jsonAlias,
            ],
            examples: [
                "triton clear",
                "triton clear --at 180,250",
                "triton clear --x 180 --y 250",
            ],
            successShape: "{ ok, action, message, targetOID, targetClassName, insertedLength: 0 }",
            providedCapabilities: ["clear"]
        ),
        TKCommandSchema(
            name: "press",
            summary: "Press a device button when supported by the active runtime",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "<button>", type: "String", description: "Button name, for example home"),
                TKCommandSchemaOption(name: "--button", type: "String", description: "Compatibility input; mutually exclusive with <button>"),
                TKCommandSchemaOption(name: "--duration", type: "Double", description: "Hold duration in seconds"),
                formatJSONText,
                jsonAlias,
            ],
            examples: ["triton press home", "triton press --button home"],
            successShape: "{ ok: false, action, message } in embedded runtime",
            providedCapabilities: ["press"]
        ),
        TKCommandSchema(
            name: "input",
            summary: "Run newline-delimited JSON actions from stdin",
            requiresServer: true,
            requiresTarget: true,
            runtimeScope: "embedded",
            outputFormats: jsonText,
            options: hostPort + [
                target,
                TKCommandSchemaOption(name: "--format", type: "text|json", defaultValue: "json", description: "Output format"),
                jsonAlias,
                TKCommandSchemaOption(name: "--fail-fast", type: "Bool", defaultValue: "false", description: "Stop on first failed action"),
                TKCommandSchemaOption(name: "--summary", type: "Bool", defaultValue: "false", description: "Print a final JSON batch summary"),
                TKCommandSchemaOption(name: "--strict", type: "Bool", defaultValue: "false", description: "Exit non-zero when any action fails"),
            ],
            examples: [
                #"printf '%s\n' '{"type":"tap","x":270,"y":300}' '{"type":"type","text":"hello"}' | triton input --format json --summary --strict"#,
            ],
            successShape: "One TKInputResult JSON object per input line; with --summary, final { ok, actionCount, failedCount }",
            inputActions: inputActionSchemas(),
            providedCapabilities: ["tap", "swipe", "type", "paste", "clear", "press"]
        ),
    ]
}

func inputActionSchemas() -> [TKInputActionSchema] {
    [
        TKInputActionSchema(
            type: "tap",
            requiredFields: ["type"],
            optionalFields: ["x", "y", "targetOID", "width", "height", "duration"],
            oneOfRequired: [["x", "y"], ["targetOID"]],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["tap"], "Action discriminator"),
                inputField("x", "Double", "Window x coordinate in points; required with y unless targetOID is used"),
                inputField("y", "Double", "Window y coordinate in points; required with x unless targetOID is used"),
                inputField("targetOID", "UInt", "View oid from hierarchy/ax/hit; alternative to x/y"),
                inputField("width", "Double", "Optional window width in points for caller bookkeeping"),
                inputField("height", "Double", "Optional window height in points for caller bookkeeping"),
                inputField("duration", "Double", "Optional hold duration in seconds"),
            ],
            example: #"{"type":"tap","x":270,"y":300}"#
        ),
        TKInputActionSchema(
            type: "swipe",
            requiredFields: ["type", "startX", "startY", "endX", "endY"],
            optionalFields: ["width", "height", "duration"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["swipe"], "Action discriminator"),
                inputField("startX", "Double", required: true, "Start x coordinate in window points"),
                inputField("startY", "Double", required: true, "Start y coordinate in window points"),
                inputField("endX", "Double", required: true, "End x coordinate in window points"),
                inputField("endY", "Double", required: true, "End y coordinate in window points"),
                inputField("width", "Double", "Optional window width in points for caller bookkeeping"),
                inputField("height", "Double", "Optional window height in points for caller bookkeeping"),
                inputField("duration", "Double", "Optional gesture duration in seconds"),
            ],
            example: #"{"type":"swipe","startX":350,"startY":390,"endX":100,"endY":390}"#
        ),
        TKInputActionSchema(
            type: "type",
            requiredFields: ["type", "text"],
            optionalFields: ["targetOID", "secure"],
            fields: [
                inputField("type", "String", required: true, enumValues: ["type"], "Action discriminator"),
                inputField("text", "String", required: true, "Text to insert into target or first responder"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
                inputField("secure", "Bool", "Redact inserted text details in command output"),
            ],
            example: #"{"type":"type","text":"hello"}"#
        ),
        TKInputActionSchema(
            type: "paste",
            requiredFields: ["type", "text"],
            optionalFields: ["targetOID", "x", "y", "secure"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["paste"], "Action discriminator"),
                inputField("text", "String", required: true, "Exact text to insert into target or first responder"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
                inputField("x", "Double", "Window x coordinate to focus before paste; required with y"),
                inputField("y", "Double", "Window y coordinate to focus before paste; required with x"),
                inputField("secure", "Bool", "Redact inserted text details in command output"),
            ],
            example: #"{"type":"paste","text":"console","secure":false}"#,
            resultShape: "{ ok, action, message, targetOID, targetClassName, secure, redacted, insertedLength }"
        ),
        TKInputActionSchema(
            type: "clear",
            requiredFields: ["type"],
            optionalFields: ["targetOID", "x", "y"],
            coordinateSpace: "window-points",
            fields: [
                inputField("type", "String", required: true, enumValues: ["clear"], "Action discriminator"),
                inputField("targetOID", "UInt", "Optional UIKeyInput target oid"),
                inputField("x", "Double", "Window x coordinate to focus before clear; required with y"),
                inputField("y", "Double", "Window y coordinate to focus before clear; required with x"),
            ],
            example: #"{"type":"clear"}"#,
            resultShape: "{ ok, action, message, targetOID, targetClassName, insertedLength: 0 }"
        ),
        TKInputActionSchema(
            type: "button",
            requiredFields: ["type", "button"],
            optionalFields: ["duration"],
            fields: [
                inputField("type", "String", required: true, enumValues: ["button"], "Action discriminator"),
                inputField("button", "String", required: true, enumValues: ["home"], "Device button name; embedded runtime returns unsupported"),
                inputField("duration", "Double", "Optional press duration in seconds"),
            ],
            example: #"{"type":"button","button":"home"}"#,
            resultShape: "{ ok: false, action, message } in embedded runtime"
        ),
    ]
}

func inputField(
    _ name: String,
    _ type: String,
    required: Bool = false,
    enumValues: [String]? = nil,
    _ description: String
) -> TKInputActionFieldSchema {
    TKInputActionFieldSchema(
        name: name,
        type: type,
        required: required,
        enumValues: enumValues,
        description: description
    )
}

func renderSchema(_ response: TKCLISchemaResponse, language: CLILanguage = effectiveLanguage(nil)) -> String {
    response.commands.map { command in
        var lines = ["\(command.name): \(command.summary)"]
        lines.append("  \(language == .zh ? "需要服务" : "requiresServer"): \(command.requiresServer)")
        lines.append("  \(language == .zh ? "需要目标" : "requiresTarget"): \(command.requiresTarget)")
        lines.append("  \(language == .zh ? "需要层级" : "requiresHierarchy"): \(command.requiresHierarchy)")
        lines.append("  \(language == .zh ? "运行时范围" : "runtimeScope"): \(command.runtimeScope)")
        lines.append("  \(language == .zh ? "失败退出码" : "exitCodeOnFailure"): \(command.exitCodeOnFailure)")
        lines.append("  \(language == .zh ? "输出格式" : "outputFormats"): \(command.outputFormats.joined(separator: ","))")
        if !command.options.isEmpty {
            lines.append("  \(language == .zh ? "选项" : "options"):")
            for option in command.options {
                let required = option.required ? " required" : ""
                let defaultValue = option.defaultValue.map { " default=\($0)" } ?? ""
                lines.append("    \(option.name): \(option.type)\(required)\(defaultValue) - \(option.description)")
            }
        }
        if !command.examples.isEmpty {
            lines.append("  \(language == .zh ? "示例" : "examples"):")
            lines.append(contentsOf: command.examples.map { "    \($0)" })
        }
        if let inputActions = command.inputActions, !inputActions.isEmpty {
            lines.append("  inputActions:")
            for action in inputActions {
                lines.append("    \(action.type): required=\(action.requiredFields.joined(separator: ",")) optional=\(action.optionalFields.joined(separator: ","))")
                if let coordinateSpace = action.coordinateSpace {
                    lines.append("      coordinateSpace: \(coordinateSpace)")
                }
                if !action.oneOfRequired.isEmpty {
                    let oneOf = action.oneOfRequired.map { $0.joined(separator: "+") }.joined(separator: " | ")
                    lines.append("      oneOfRequired: \(oneOf)")
                }
                lines.append("      fields:")
                for field in action.fields {
                    let required = field.required ? " required" : ""
                    let enumValues = field.enumValues.map { " enum=\($0.joined(separator: "|"))" } ?? ""
                    lines.append("        \(field.name): \(field.type)\(required)\(enumValues) - \(field.description)")
                }
                lines.append("      example: \(action.example)")
            }
        }
        return lines.joined(separator: "\n")
    }.joined(separator: "\n\n")
}

func waitForHierarchy(client: TritonKitHTTPClient) async throws -> Data {
    var lastError: Error?
    for _ in 0..<10 {
        do {
            return try await client.getData("/hierarchy/latest")
        } catch {
            lastError = error
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }
    throw lastError ?? RuntimeError("No hierarchy snapshot available")
}

func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

func encodeCompactJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

func prettyJSON(_ data: Data) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data)
    let pretty = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    return String(data: pretty, encoding: .utf8) ?? "{}"
}

func encodeJSONObject(_ value: Any) throws -> String {
    guard JSONSerialization.isValidJSONObject(value) else {
        throw RuntimeError("Value is not a valid JSON object")
    }
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    return String(data: data, encoding: .utf8) ?? "{}"
}

func writeOrPrint(_ text: String, output: String?) throws {
    if let output {
        try text.data(using: .utf8)?.write(to: URL(fileURLWithPath: output), options: .atomic)
    } else {
        print(text)
    }
}

func requestPayload(
    type: TKRequestType,
    payload: Data? = nil,
    state: ConnectionState,
    targetState: TargetState,
    counter: MessageCounter,
    encoder: JSONEncoder
) async throws -> Data {
    guard let ws = state.outbound else {
        throw RuntimeError("No iOS device connected")
    }
    let id = counter.next()
    log("[tritonkit] -> \(type.rawValue) [id:\(id)]")
    try await ws.send(TKMessage(id: id, type: type, payload: payload), encoder: encoder)
    guard let responsePayload = await targetState.waitForResponse(id: id) else {
        throw RuntimeRequestTimeoutError(requestType: type.rawValue)
    }
    return responsePayload
}

func executeInputRequest(_ request: TKInputRequest, client: TritonKitHTTPClient) async throws -> TKInputResult {
    let payload = try JSONEncoder().encode(request)
    let data = try await client.request(type: "input", payload: payload)
    return try JSONDecoder().decode(TKInputResult.self, from: data)
}

struct WaitRequest {
    let condition: TKWaitCondition
    let query: String?
    let predicate: String?
    let role: String?
    let timeout: Double
    let interval: Double
}

func performWait(_ request: WaitRequest, client: TritonKitHTTPClient) async throws -> TKWaitResult {
    let start = Date()
    let deadline = start.addingTimeInterval(request.timeout)
    var pollCount = 0
    var lastObservation = TKWaitObservation()
    var stableHierarchyHash: String?
    var hierarchyChangeBaseline: String?

    if request.condition == .hierarchyChange {
        hierarchyChangeBaseline = try await latestHierarchyHash(client: client)
    }

    while true {
        pollCount += 1
        let observation = try await waitObservation(for: request.condition, client: client)
        lastObservation = observation

        let evaluation = try evaluateWait(request, observation: observation, stableHierarchyHash: stableHierarchyHash, hierarchyChangeBaseline: hierarchyChangeBaseline)
        if evaluation.matched {
            return waitResult(
                request: request,
                matched: true,
                timedOut: false,
                elapsedMs: elapsedMilliseconds(since: start),
                pollCount: pollCount,
                observation: observation,
                match: evaluation.match
            )
        }

        if request.condition == .idle, let hierarchyHash = observation.hierarchyHash {
            stableHierarchyHash = hierarchyHash
        }
        if request.condition == .hierarchyChange, hierarchyChangeBaseline == nil {
            hierarchyChangeBaseline = observation.hierarchyHash
        }

        if Date() >= deadline {
            return waitResult(
                request: request,
                matched: false,
                timedOut: true,
                elapsedMs: elapsedMilliseconds(since: start),
                pollCount: pollCount,
                observation: lastObservation,
                match: nil
            )
        }

        let remaining = deadline.timeIntervalSinceNow
        let sleepSeconds = max(0.01, min(request.interval, remaining))
        try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
    }
}

private func waitObservation(for condition: TKWaitCondition, client: TritonKitHTTPClient) async throws -> TKWaitObservation {
    let status: TKStatusResponse = try await client.getJSON("/status")
    switch condition {
    case .text, .gone, .predicate, .exists:
        let accessibilityData = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        return TKWaitObservation(
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState
        )
    case .idle:
        let accessibilityData = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
        return TKWaitObservation(
            nodes: nodes,
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState,
            hierarchyHash: stableAXSignatureHash(nodes)
        )
    case .hierarchyChange:
        let hierarchyData = try await client.request(type: "hierarchy")
        return TKWaitObservation(
            targetConnectionState: status.targetConnectionState,
            hierarchyCacheState: status.hierarchyCacheState,
            hierarchyHash: stableDataHash(hierarchyData)
        )
    }
}

private func evaluateWait(
    _ request: WaitRequest,
    observation: TKWaitObservation,
    stableHierarchyHash: String?,
    hierarchyChangeBaseline: String?
) throws -> (matched: Bool, match: TKWaitMatch?) {
    switch request.condition {
    case .text, .exists:
        guard let query = request.query else { return (false, nil) }
        let match = TKWaitFindTextMatch(in: observation.nodes, query: query, role: request.role)
        return (match != nil, match)
    case .gone:
        guard let query = request.query else { return (false, nil) }
        let match = TKWaitFindTextMatch(in: observation.nodes, query: query, role: request.role)
        return (match == nil, nil)
    case .predicate:
        guard let predicate = request.predicate else { return (false, nil) }
        return (try TKWaitEvaluatePredicate(predicate, nodes: observation.nodes), nil)
    case .idle:
        guard observation.targetConnectionState == "connected",
              observation.hierarchyCacheState == "active",
              let hierarchyHash = observation.hierarchyHash,
              let stableHierarchyHash else {
            return (false, nil)
        }
        return (hierarchyHash == stableHierarchyHash, nil)
    case .hierarchyChange:
        guard let hierarchyHash = observation.hierarchyHash,
              let hierarchyChangeBaseline else {
            return (false, nil)
        }
        return (hierarchyHash != hierarchyChangeBaseline, nil)
    }
}

private func waitResult(
    request: WaitRequest,
    matched: Bool,
    timedOut: Bool,
    elapsedMs: Int,
    pollCount: Int,
    observation: TKWaitObservation,
    match: TKWaitMatch?
) -> TKWaitResult {
    TKWaitResult(
        ok: matched && !timedOut,
        matched: matched,
        condition: request.condition.rawValue,
        query: request.query,
        predicate: request.predicate,
        role: request.role,
        timedOut: timedOut,
        elapsedMs: elapsedMs,
        pollCount: pollCount,
        timeoutSeconds: request.timeout,
        intervalSeconds: request.interval,
        targetConnectionState: observation.targetConnectionState,
        hierarchyCacheState: observation.hierarchyCacheState,
        lastObservedNodeCount: observation.nodes.isEmpty ? nil : TKFlattenAXNodes(observation.nodes).count,
        lastObservedTextSample: TKWaitTextSample(from: observation.nodes),
        lastObservedHierarchyHash: observation.hierarchyHash,
        match: match
    )
}

private func latestHierarchyHash(client: TritonKitHTTPClient) async throws -> String? {
    do {
        let data = try await client.getData("/hierarchy/latest")
        return stableDataHash(data)
    } catch {
        return nil
    }
}

private func stableDataHash(_ data: Data) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return String(format: "%016llx", hash)
}

private func stableAXSignatureHash(_ nodes: [TKAXNode]) -> String {
    let signature = TKWaitVisibleTexts(from: nodes)
        .map { match in
            [
                match.source,
                match.role ?? "",
                match.text,
                match.frame.map(formatRect) ?? "",
            ].joined(separator: ":")
        }
        .joined(separator: "\n")
    return stableDataHash(Data(signature.utf8))
}

private func elapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1000))
}

func printWaitResult(_ result: TKWaitResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("matched: \(result.matched)")
        print("condition: \(result.condition)")
        if let query = result.query {
            print("query: \(query)")
        }
        if let predicate = result.predicate {
            print("predicate: \(predicate)")
        }
        if let role = result.role {
            print("role: \(role)")
        }
        print("timedOut: \(result.timedOut)")
        print("elapsedMs: \(result.elapsedMs)")
        print("pollCount: \(result.pollCount)")
        if let targetConnectionState = result.targetConnectionState {
            print("targetConnectionState: \(targetConnectionState)")
        }
        if let hierarchyCacheState = result.hierarchyCacheState {
            print("hierarchyCacheState: \(hierarchyCacheState)")
        }
        if let match = result.match {
            print("match: \(match.text)")
            if let role = match.role { print("matchRole: \(role)") }
            if let frame = match.frame { print("matchFrame: \(formatRect(frame))") }
            if let targetOID = match.targetOID { print("matchTargetOID: \(targetOID)") }
        }
    }
}

func screenshotImageData(_ screenshot: TKScreenshotResponse, client: TritonKitHTTPClient) async throws -> Data {
    if let dataRef = screenshot.dataRef, !dataRef.isEmpty {
        return try await client.getData("/data/\(dataRef)")
    }
    guard let data = Data(base64Encoded: screenshot.dataBase64) else {
        throw RuntimeError("Invalid screenshot image data")
    }
    return data
}

func buildExportArchive(
    target: TKTargetSummary,
    hierarchyData: Data,
    client: TritonKitHTTPClient
) async throws -> TKExportArchive {
    let hierarchyObject = try JSONSerialization.jsonObject(with: hierarchyData)
    let hierarchy = try TKJSONValue.fromJSONObject(hierarchyObject)
    let geometryData = try await client.request(type: "geometry")
    let geometry = try JSONDecoder().decode(TKGeometryResponse.self, from: geometryData)
    let accessibilityData = try await client.request(type: "accessibility")
    let accessibility = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    let screenshotData = try await client.request(type: "screenshot")
    let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
    let imageData = try await screenshotImageData(screenshot, client: client)
    let embeddedScreenshot = TKScreenshotResponse(
        format: screenshot.format,
        width: screenshot.width,
        height: screenshot.height,
        scale: screenshot.scale,
        dataBase64: imageData.base64EncodedString()
    )

    return TKExportArchive(
        exportedAt: ISO8601DateFormatter().string(from: Date()),
        target: target,
        hierarchy: hierarchy,
        geometry: geometry,
        accessibility: accessibility,
        screenshot: embeddedScreenshot
    )
}

struct EvidenceScreenshotMetadata: Codable {
    let format: String
    let width: Double
    let height: Double
    let scale: Double
    let dataRef: String?
    let imagePath: String
    let bytes: Int
}

func parseEvidenceIncludes(_ raw: String) throws -> [String] {
    let aliases = [
        "targets": "list",
        "accessibility": "ax",
        "export": "archive",
    ]
    let allowed: Set<String> = [
        "screenshot",
        "ax",
        "hierarchy",
        "status",
        "list",
        "version",
        "geometry",
        "archive",
        "logs",
    ]
    var result: [String] = []
    var seen = Set<String>()
    for part in raw.split(separator: ",") {
        let normalized = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { continue }
        let kind = aliases[normalized] ?? normalized
        guard allowed.contains(kind) else {
            throw RuntimeError("Unsupported evidence include: \(normalized)")
        }
        if seen.insert(kind).inserted {
            result.append(kind)
        }
    }
    return result.isEmpty ? ["status", "list", "version", "hierarchy", "ax", "screenshot"] : result
}

func failEvidenceValidation(_ message: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command evidence --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func readEvidenceManifest(from path: String) throws -> TKEvidenceManifest {
    let inputURL = URL(fileURLWithPath: path)
    let manifestURL: URL
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
        manifestURL = inputURL.appendingPathComponent("manifest.json")
    } else {
        manifestURL = inputURL.lastPathComponent == "manifest.json"
            ? inputURL
            : inputURL.appendingPathComponent("manifest.json")
    }
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(TKEvidenceManifest.self, from: data)
}

func readReplayPlan(from path: String) throws -> TKReplayPlan {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let plan = try JSONDecoder().decode(TKReplayPlan.self, from: data)
    guard plan.schemaVersion == 1 else {
        throw RuntimeError("Unsupported replay plan schemaVersion: \(plan.schemaVersion)")
    }
    guard !plan.steps.isEmpty else {
        throw RuntimeError("Replay plan must contain at least one step")
    }
    return plan
}

func parseAssertBounds(_ raw: String) throws -> TKRect {
    try parseBounds(raw)
}

func parseBounds(_ raw: String) throws -> TKRect {
    let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard parts.count == 4,
          let x = Double(parts[0]),
          let y = Double(parts[1]),
          let width = Double(parts[2]),
          let height = Double(parts[3]),
          width >= 0,
          height >= 0 else {
        throw RuntimeError("--within must use x,y,width,height with non-negative width and height")
    }
    return TKRect(x: x, y: y, width: width, height: height)
}

func parsePoint(_ raw: String) throws -> (x: Double, y: Double) {
    let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard parts.count == 2,
          let x = Double(parts[0]),
          let y = Double(parts[1]) else {
        throw RuntimeError("--at must use x,y")
    }
    return (x, y)
}

func requiredPoint(
    at: String?,
    x: Double?,
    y: Double?,
    outputFormat: ClientOutputFormat
) throws -> (x: Double, y: Double) {
    if at != nil && (x != nil || y != nil) {
        if outputFormat == .json {
            try printValidationError("--at cannot be combined with --x/--y")
            throw ExitCode.failure
        }
        throw RuntimeError("--at cannot be combined with --x/--y")
    }
    if let at {
        return try parsePoint(at)
    }
    guard let x, let y else {
        if outputFormat == .json {
            try printValidationError("Provide coordinates as --at x,y or --x/--y")
            throw ExitCode.failure
        }
        throw RuntimeError("Provide coordinates as --at x,y or --x/--y")
    }
    return (x, y)
}

func inputFocusPoint(
    at: String?,
    x: Double?,
    y: Double?,
    outputFormat: ClientOutputFormat
) throws -> (x: Double, y: Double)? {
    if at != nil && (x != nil || y != nil) {
        if outputFormat == .json {
            try printValidationError("--at cannot be combined with --x/--y")
            throw ExitCode.failure
        }
        throw RuntimeError("--at cannot be combined with --x/--y")
    }
    if (x == nil) != (y == nil) {
        if outputFormat == .json {
            try printValidationError("--x and --y must be provided together")
            throw ExitCode.failure
        }
        throw RuntimeError("--x and --y must be provided together")
    }
    if let at {
        return try parsePoint(at)
    }
    return nil
}

func printAssertResult(_ result: TKUIAssertResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("condition: \(result.condition)")
        print("query: \(result.query)")
        if let role = result.role { print("role: \(role)") }
        print("count: \(result.count)")
        if let expectedCount = result.expectedCount { print("expectedCount: \(expectedCount)") }
        if let minCount = result.minCount { print("minCount: \(minCount)") }
        if let maxCount = result.maxCount { print("maxCount: \(maxCount)") }
        if let within = result.within { print("within: \(formatRect(within))") }
        if let targetConnectionState = result.targetConnectionState { print("targetConnectionState: \(targetConnectionState)") }
        if let hierarchyCacheState = result.hierarchyCacheState { print("hierarchyCacheState: \(hierarchyCacheState)") }
        if let message = result.message { print("message: \(message)") }
    }
}

func parseReplayVariables(_ assignments: [String]) throws -> [String: String] {
    var result: [String: String] = [:]
    for assignment in assignments {
        guard let equals = assignment.firstIndex(of: "=") else {
            throw RuntimeError("Invalid --var assignment: \(assignment)")
        }
        let key = String(assignment[..<equals])
        let value = String(assignment[assignment.index(after: equals)...])
        guard !key.isEmpty else {
            throw RuntimeError("Invalid --var assignment with empty key")
        }
        if key.hasSuffix("-env") {
            let variableName = String(key.dropLast(4))
            guard !variableName.isEmpty else {
                throw RuntimeError("Invalid --var env assignment with empty key")
            }
            guard let envValue = ProcessInfo.processInfo.environment[value] else {
                throw RuntimeError("Environment variable is not set for replay variable \(variableName): \(value)")
            }
            result[variableName] = envValue
        } else {
            result[key] = value
        }
    }
    return result
}

func runReplayPlan(
    _ plan: TKReplayPlan,
    variables: [String: String],
    dryRun: Bool,
    target: String,
    host: String,
    port: Int
) async throws -> TKReplayResult {
    let start = Date()
    var steps: [TKReplayStepResult] = []
    var failedStepIndex: Int?
    let client = TritonKitHTTPClient(host: host, port: port)
    let commands = try plan.steps.enumerated().map { offset, step in
        try replayCommand(for: step, plan: plan, index: offset + 1, variables: variables)
    }

    if !dryRun {
        _ = try await resolveTarget(target, host: host, port: port, jsonError: true)
    }

    for (offset, step) in plan.steps.enumerated() {
        let index = offset + 1
        let command = commands[offset]
        if dryRun {
            steps.append(TKReplayStepResult(
                index: index,
                action: step.action.rawValue,
                name: step.name ?? step.id,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: command,
                message: "dry-run"
            ))
            continue
        }

        let stepStart = Date()
        do {
            let result = try await executeReplayStep(
                step,
                plan: plan,
                index: index,
                variables: variables,
                target: target,
                host: host,
                port: port,
                client: client,
                command: command,
                startedAt: stepStart
            )
            steps.append(result)
            if !result.ok {
                failedStepIndex = index
                break
            }
        } catch {
            failedStepIndex = index
            steps.append(TKReplayStepResult(
                index: index,
                action: step.action.rawValue,
                name: step.name ?? step.id,
                ok: false,
                dryRun: false,
                elapsedMs: elapsedMilliseconds(since: stepStart),
                command: command,
                message: "\(error)"
            ))
            break
        }
    }

    return TKReplayResult(
        ok: failedStepIndex == nil,
        dryRun: dryRun,
        planName: plan.name,
        stepCount: plan.steps.count,
        executedCount: steps.count,
        failedStepIndex: failedStepIndex,
        elapsedMs: elapsedMilliseconds(since: start),
        steps: steps
    )
}

func executeReplayStep(
    _ step: TKReplayPlanStep,
    plan: TKReplayPlan,
    index: Int,
    variables: [String: String],
    target: String,
    host: String,
    port: Int,
    client: TritonKitHTTPClient,
    command: [String],
    startedAt: Date
) async throws -> TKReplayStepResult {
    switch step.action {
    case .tap:
        let request = try await replayTapRequest(step, variables: variables, client: client)
        let input = try await executeInputRequest(request, client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: input.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: input.message,
            input: input
        )
    case .paste, .type, .clear:
        let (request, redactedValue) = try replayTextInputRequest(step, variables: variables)
        let input = try await executeInputRequest(request, client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: input.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: input.message,
            redactedValue: redactedValue,
            input: input
        )
    case .wait:
        let wait = try await performWait(replayWaitRequest(step, variables: variables), client: client)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: wait.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: wait.ok ? "matched" : "timed out",
            wait: wait
        )
    case .screenshot:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).png",
            variables: variables
        )
        let data = try await client.request(type: "screenshot")
        let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: data)
        let imageData = try await screenshotImageData(screenshot, client: client)
        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try imageData.write(to: outputURL, options: .atomic)
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: true,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: "screenshot captured",
            file: TKReplayFileArtifact(path: outputURL.path, bytes: imageData.count, contentType: "image/png")
        )
    case .evidence:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).tritonevidence",
            variables: variables
        )
        let includes = try parseEvidenceIncludes(step.include ?? "status,list,version,hierarchy,ax,screenshot")
        let manifest = try await captureEvidenceBundle(
            output: output,
            includes: includes,
            name: step.name ?? plan.name,
            note: step.note,
            target: target,
            host: host,
            port: port,
            refresh: step.refresh ?? true
        )
        return TKReplayStepResult(
            index: index,
            action: step.action.rawValue,
            name: step.name ?? step.id,
            ok: manifest.ok,
            dryRun: false,
            elapsedMs: elapsedMilliseconds(since: startedAt),
            command: command,
            message: "evidence captured",
            evidence: manifest
        )
    }
}

func replayTapRequest(
    _ step: TKReplayPlanStep,
    variables: [String: String],
    client: TritonKitHTTPClient
) async throws -> TKInputRequest {
    let selectorCount = [
        step.text != nil,
        step.oid != nil,
        step.x != nil || step.y != nil,
        step.axOID != nil,
        step.axLabel != nil,
    ].filter { $0 }.count
    guard selectorCount == 1 else {
        throw RuntimeError("Replay tap step requires exactly one selector: text, oid, x/y, axOID, or axLabel")
    }
    if (step.x == nil) != (step.y == nil) {
        throw RuntimeError("Replay tap step requires x and y together")
    }
    if let text = step.text {
        let query = try TKReplaySubstituteVariables(text, variables: variables)
        return try await resolveTapTarget(
            query,
            client: client,
            width: step.width,
            height: step.height,
            duration: step.duration
        ).request
    }
    if step.axOID != nil || step.axLabel != nil {
        let data = try await client.request(type: "accessibility")
        let nodes = try JSONDecoder().decode([TKAXNode].self, from: data)
        let label = try step.axLabel.map { try TKReplaySubstituteVariables($0, variables: variables) }
        guard let node = selectAXNode(nodes, oid: step.axOID, label: label) else {
            throw RuntimeError("AX node not found for replay tap step")
        }
        return tapRequest(for: node, width: step.width, height: step.height, duration: step.duration)
    }
    return TKInputRequest.tap(
        x: step.x,
        y: step.y,
        targetOID: step.oid,
        width: step.width,
        height: step.height,
        duration: step.duration
    )
}

func replayTextInputRequest(
    _ step: TKReplayPlanStep,
    variables: [String: String]
) throws -> (request: TKInputRequest, redactedValue: String?) {
    try validateReplayXYPair(step)
    switch step.action {
    case .paste:
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay paste step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        return (
            TKInputRequest.paste(value, targetOID: step.oid, x: step.x, y: step.y, secure: step.secure ?? false),
            step.redactedValue(substitutedValue: value)
        )
    case .type:
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay type step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        return (
            TKInputRequest(type: .typeText, targetOID: step.oid, text: value, secure: step.secure),
            step.redactedValue(substitutedValue: value)
        )
    case .clear:
        return (TKInputRequest.clear(targetOID: step.oid, x: step.x, y: step.y), nil)
    default:
        throw RuntimeError("Replay text input builder received unsupported action: \(step.action.rawValue)")
    }
}

func replayWaitRequest(_ step: TKReplayPlanStep, variables: [String: String]) throws -> WaitRequest {
    let conditionCount = [
        step.text != nil,
        step.gone != nil,
        step.exists != nil,
        step.idle == true,
        step.hierarchyChange == true,
        step.predicate != nil,
    ].filter { $0 }.count
    guard conditionCount == 1 else {
        throw RuntimeError("Replay wait step requires exactly one condition: text, gone, exists, idle, hierarchyChange, or predicate")
    }
    guard let condition = step.waitCondition else {
        throw RuntimeError("Replay wait step requires one condition: text, gone, exists, idle, hierarchyChange, or predicate")
    }
    switch condition {
    case .text:
        return WaitRequest(
            condition: .text,
            query: try step.text.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .gone:
        return WaitRequest(
            condition: .gone,
            query: try step.gone.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .exists:
        return WaitRequest(
            condition: .exists,
            query: try step.exists.map { try TKReplaySubstituteVariables($0, variables: variables) },
            predicate: nil,
            role: step.role,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    case .idle:
        return WaitRequest(condition: .idle, query: nil, predicate: nil, role: nil, timeout: step.timeout ?? 10, interval: step.interval ?? 0.5)
    case .hierarchyChange:
        return WaitRequest(condition: .hierarchyChange, query: nil, predicate: nil, role: nil, timeout: step.timeout ?? 10, interval: step.interval ?? 0.5)
    case .predicate:
        return WaitRequest(
            condition: .predicate,
            query: nil,
            predicate: try step.predicate.map { try TKReplaySubstituteVariables($0, variables: variables) },
            role: nil,
            timeout: step.timeout ?? 10,
            interval: step.interval ?? 0.5
        )
    }
}

func replayCommand(
    for step: TKReplayPlanStep,
    plan: TKReplayPlan,
    index: Int,
    variables: [String: String]
) throws -> [String] {
    switch step.action {
    case .tap:
        var command = ["triton", "tap"]
        if let text = step.text {
            command.append(try TKReplaySubstituteVariables(text, variables: variables))
        } else if let x = step.x, let y = step.y {
            command += ["--x", replayNumber(x), "--y", replayNumber(y)]
        } else if let oid = step.oid {
            command += ["--oid", "\(oid)"]
        } else if let axOID = step.axOID {
            command += ["--ax-oid", "\(axOID)"]
        } else if let axLabel = step.axLabel {
            command += ["--ax-label", try TKReplaySubstituteVariables(axLabel, variables: variables)]
        } else {
            throw RuntimeError("Replay tap step requires a target selector")
        }
        return command + ["--json"]
    case .paste:
        try validateReplayXYPair(step)
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay paste step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        var command = ["triton", "paste"]
        if step.secure == true {
            command += ["--secure", step.redactedValue(substitutedValue: value)]
        } else {
            command.append(value)
        }
        if let x = step.x, let y = step.y {
            command += ["--x", replayNumber(x), "--y", replayNumber(y)]
        }
        if let oid = step.oid {
            command += ["--oid", "\(oid)"]
        }
        return command + ["--json"]
    case .type:
        try validateReplayXYPair(step)
        let rawValue = step.value ?? step.text
        guard let rawValue else {
            throw RuntimeError("Replay type step requires value or text")
        }
        let value = try TKReplaySubstituteVariables(rawValue, variables: variables)
        var command = ["triton", "type", "--text", step.redactedValue(substitutedValue: value)]
        if step.secure == true {
            command.append("--secure")
        }
        if let oid = step.oid {
            command += ["--oid", "\(oid)"]
        }
        return command + ["--json"]
    case .clear:
        try validateReplayXYPair(step)
        var command = ["triton", "clear"]
        if let x = step.x, let y = step.y {
            command += ["--x", replayNumber(x), "--y", replayNumber(y)]
        }
        if let oid = step.oid {
            command += ["--oid", "\(oid)"]
        }
        return command + ["--json"]
    case .wait:
        var command = ["triton", "wait"]
        let request = try replayWaitRequest(step, variables: variables)
        switch TKWaitCondition(rawValue: request.condition.rawValue) ?? request.condition {
        case .text:
            command += ["--text", request.query ?? ""]
        case .gone:
            command += ["--gone", request.query ?? ""]
        case .exists:
            command += ["--exists", request.query ?? ""]
        case .idle:
            command.append("--idle")
        case .hierarchyChange:
            command.append("--hierarchy-change")
        case .predicate:
            command += ["--predicate", request.predicate ?? ""]
        }
        if let role = request.role {
            command += ["--role", role]
        }
        command += ["--timeout", replayNumber(request.timeout), "--interval", replayNumber(request.interval), "--json"]
        return command
    case .screenshot:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).png",
            variables: variables
        )
        return ["triton", "screenshot", "--output", output, "--json"]
    case .evidence:
        let output = try replayOutputPath(
            step.output,
            fallback: "/tmp/\(replayArtifactName(plan: plan, step: step, index: index)).tritonevidence",
            variables: variables
        )
        var command = ["triton", "evidence", "--output", output, "--include", step.include ?? "status,list,version,hierarchy,ax,screenshot"]
        if let name = step.name ?? plan.name {
            command += ["--name", name]
        }
        if let note = step.note {
            command += ["--note", note]
        }
        return command + ["--json"]
    }
}

func validateReplayXYPair(_ step: TKReplayPlanStep) throws {
    if (step.x == nil) != (step.y == nil) {
        throw RuntimeError("Replay \(step.action.rawValue) step requires x and y together")
    }
}

func replayOutputPath(_ raw: String?, fallback: String, variables: [String: String]) throws -> String {
    try TKReplaySubstituteVariables(raw ?? fallback, variables: variables)
}

func replayArtifactName(plan: TKReplayPlan, step: TKReplayPlanStep, index: Int) -> String {
    sanitizedPathComponent(step.name ?? step.id ?? plan.name ?? "triton-replay-step-\(index)")
}

func sanitizedPathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    let scalars = value.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
    return collapsed.isEmpty ? "triton-replay" : collapsed
}

func replayNumber(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(value)
}

func failReplayValidation(_ message: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command replay --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func failRegressionValidation(_ message: String, command: String, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Run `triton schema --command \(command) --json` to inspect required fields"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func printEvidenceManifest(_ manifest: TKEvidenceManifest, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(manifest))
    case .text:
        print("ok: \(manifest.ok)")
        print("output: \(manifest.output)")
        if let name = manifest.name { print("name: \(name)") }
        print("artifacts: \(manifest.artifacts.count)")
        if !manifest.skipped.isEmpty {
            print("skipped: \(manifest.skipped.count)")
            for item in manifest.skipped {
                print("- \(item.kind): \(item.reason)")
            }
        }
    }
}

func captureEvidenceBundle(
    output: String,
    includes: [String],
    name: String?,
    note: String?,
    target: String,
    host: String,
    port: Int,
    refresh: Bool
) async throws -> TKEvidenceManifest {
    let outputURL = URL(fileURLWithPath: output)
    try prepareEvidenceOutputDirectory(outputURL)

    let client = TritonKitHTTPClient(host: host, port: port)
    let startedAt = ISO8601DateFormatter().string(from: Date())
    var artifacts: [TKEvidenceArtifact] = []
    var skipped: [TKEvidenceSkippedArtifact] = []
    var status: TKStatusResponse?
    var targetSummary: TKTargetSummary?

    for kind in includes {
        switch kind {
        case "version":
            do {
                let version = TKCLIVersionResponse(version: TritonKitBuildInfo.cliVersion, language: "en")
                let data = try prettyEncodedData(version)
                try appendEvidenceArtifact(
                    kind: "version",
                    relativePath: "version.json",
                    data: data,
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "cli", status: status),
                    artifacts: &artifacts
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        case "status":
            do {
                let data = try await client.getData("/status")
                status = try JSONDecoder().decode(TKStatusResponse.self, from: data)
                try appendEvidenceArtifact(
                    kind: "status",
                    relativePath: "status.json",
                    data: try prettyJSONData(data),
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "server", status: status),
                    artifacts: &artifacts
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        case "list":
            do {
                let data = try await client.getData("/targets")
                let targets = try JSONDecoder().decode(TKTargetsResponse.self, from: data)
                if targetSummary == nil {
                    targetSummary = try? TKResolveTargetSummary(target, in: targets.targets)
                }
                try appendEvidenceArtifact(
                    kind: "list",
                    relativePath: "targets.json",
                    data: try prettyJSONData(data),
                    contentType: "application/json",
                    directory: outputURL,
                    freshness: evidenceFreshness(source: "server", status: status),
                    artifacts: &artifacts
                )
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        case "logs":
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "unsupported in the current embedded runtime"))
        case "hierarchy", "ax", "geometry", "screenshot", "archive":
            do {
                if targetSummary == nil {
                    targetSummary = try await resolveTarget(target, host: host, port: port)
                }
                switch kind {
                case "hierarchy":
                    let data = try await evidenceHierarchyData(client: client, refresh: refresh)
                    try appendEvidenceArtifact(
                        kind: "hierarchy",
                        relativePath: "hierarchy.json",
                        data: try prettyJSONData(data),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: refresh ? "runtime" : "server-cache", status: status),
                        artifacts: &artifacts
                    )
                case "ax":
                    let data = try await client.request(type: "accessibility")
                    try appendEvidenceArtifact(
                        kind: "ax",
                        relativePath: "ax.json",
                        data: try prettyJSONData(data),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: "runtime", status: status),
                        artifacts: &artifacts
                    )
                case "geometry":
                    let data = try await client.request(type: "geometry")
                    try appendEvidenceArtifact(
                        kind: "geometry",
                        relativePath: "geometry.json",
                        data: try prettyJSONData(data),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: "runtime", status: status),
                        artifacts: &artifacts
                    )
                case "screenshot":
                    try await captureEvidenceScreenshot(
                        client: client,
                        directory: outputURL,
                        status: status,
                        artifacts: &artifacts
                    )
                case "archive":
                    let hierarchyData = try await evidenceHierarchyData(client: client, refresh: refresh)
                    let archive = try await buildExportArchive(
                        target: targetSummary ?? TKTargetSummary(connected: true, latestHierarchyAvailable: true),
                        hierarchyData: hierarchyData,
                        client: client
                    )
                    try appendEvidenceArtifact(
                        kind: "archive",
                        relativePath: "archive.json",
                        data: try prettyEncodedData(archive),
                        contentType: "application/json",
                        directory: outputURL,
                        freshness: evidenceFreshness(source: "runtime", status: status),
                        artifacts: &artifacts
                    )
                default:
                    break
                }
            } catch {
                skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: evidenceSkipReason(error)))
            }
        default:
            skipped.append(TKEvidenceSkippedArtifact(kind: kind, reason: "unsupported"))
        }
    }

    if targetSummary == nil {
        targetSummary = try? await resolveTarget(target, host: host, port: port)
    }

    let manifest = TKEvidenceManifest(
        ok: true,
        name: name,
        note: note,
        createdAt: startedAt,
        output: outputURL.path,
        artifacts: artifacts,
        skipped: skipped,
        target: targetSummary.map { summary in
            TKEvidenceTarget(
                id: summary.id,
                connected: summary.connected,
                appName: summary.appName,
                bundleIdentifier: summary.bundleIdentifier,
                deviceDescription: summary.deviceDescription,
                osDescription: summary.osDescription,
                identityState: summary.identityState ?? "unknown",
                targetConnectionState: status?.targetConnectionState ?? (summary.connected ? "connected" : "disconnected"),
                hierarchyCacheState: summary.hierarchyCacheState ?? status?.hierarchyCacheState
            )
        },
        cli: TKEvidenceCLI(version: TritonKitBuildInfo.cliVersion)
    )
    try prettyEncodedData(manifest).write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
    return manifest
}

func prepareEvidenceOutputDirectory(_ url: URL) throws {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw RuntimeError("Evidence output exists and is not a directory: \(url.path)")
        }
    } else {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}

func appendEvidenceArtifact(
    kind: String,
    relativePath: String,
    data: Data,
    contentType: String,
    directory: URL,
    freshness: TKEvidenceFreshness,
    artifacts: inout [TKEvidenceArtifact]
) throws {
    let fileURL = directory.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: fileURL, options: .atomic)
    artifacts.append(TKEvidenceArtifact(
        kind: kind,
        path: relativePath,
        contentType: contentType,
        bytes: data.count,
        freshness: freshness
    ))
}

func captureEvidenceScreenshot(
    client: TritonKitHTTPClient,
    directory: URL,
    status: TKStatusResponse?,
    artifacts: inout [TKEvidenceArtifact]
) async throws {
    let screenshotData = try await client.request(type: "screenshot")
    let screenshot = try JSONDecoder().decode(TKScreenshotResponse.self, from: screenshotData)
    let imageData = try await screenshotImageData(screenshot, client: client)
    let freshness = evidenceFreshness(source: "runtime", status: status)
    try appendEvidenceArtifact(
        kind: "screenshot",
        relativePath: "screenshot.png",
        data: imageData,
        contentType: "image/png",
        directory: directory,
        freshness: freshness,
        artifacts: &artifacts
    )
    let metadata = EvidenceScreenshotMetadata(
        format: screenshot.format,
        width: screenshot.width,
        height: screenshot.height,
        scale: screenshot.scale,
        dataRef: screenshot.dataRef,
        imagePath: "screenshot.png",
        bytes: imageData.count
    )
    try appendEvidenceArtifact(
        kind: "screenshot-metadata",
        relativePath: "screenshot.json",
        data: try prettyEncodedData(metadata),
        contentType: "application/json",
        directory: directory,
        freshness: freshness,
        artifacts: &artifacts
    )
}

func evidenceHierarchyData(client: TritonKitHTTPClient, refresh: Bool) async throws -> Data {
    if refresh {
        return try await client.request(type: "hierarchy")
    }
    return try await waitForHierarchy(client: client)
}

func evidenceFreshness(source: String, status: TKStatusResponse?) -> TKEvidenceFreshness {
    TKEvidenceFreshness(
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        source: source,
        hierarchyCacheState: status?.hierarchyCacheState,
        targetConnectionState: status?.targetConnectionState
    )
}

func evidenceSkipReason(_ error: Error) -> String {
    if let httpError = error as? CLIHTTPError,
       let response = httpError.response {
        return "\(response.error.code): \(response.error.message)"
    }
    return "\(error)"
}

func prettyEncodedData<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
}

func prettyJSONData(_ data: Data) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: data)
    return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
}

func runInputRequest(
    _ request: TKInputRequest,
    host: String,
    port: Int,
    format: ClientOutputFormat
) async throws {
    let client = TritonKitHTTPClient(host: host, port: port)
    let result = try await executeInputRequest(request, client: client)
    try printInputResult(result, format: format)
    if !result.ok {
        throw RuntimeError(result.message ?? "Input request failed")
    }
}

func printInputResult(_ result: TKInputResult, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeCompactJSON(result))
    case .text:
        print("ok: \(result.ok)")
        print("action: \(result.action)")
        if let message = result.message {
            print("message: \(message)")
        }
        if let targetOID = result.targetOID {
            print("targetOID: \(targetOID)")
        }
        if let targetClassName = result.targetClassName {
            print("targetClassName: \(targetClassName)")
        }
        if let secure = result.secure {
            print("secure: \(secure)")
        }
        if let redacted = result.redacted {
            print("redacted: \(redacted)")
        }
        if let insertedLength = result.insertedLength {
            print("insertedLength: \(insertedLength)")
        }
    }
}

func renderAXTree(_ nodes: [TKAXNode]) -> String {
    axTreeLines(nodes, indent: 0).joined(separator: "\n")
}

func renderAXHierarchyMap(_ response: TKAXHierarchyMapResponse) -> String {
    var lines = [
        "AX nodes: \(response.axNodeCount)",
        "Hierarchy nodes: \(response.hierarchyNodeCount)",
        "Mapped: \(response.mappedCount)",
        "Unmatched: \(response.unmatchedCount)",
    ]
    for node in response.nodes {
        let prefix = String(repeating: "  ", count: node.depth)
        var line = "\(prefix)\(node.role)"
        if let label = node.label, !label.isEmpty { line += " \"\(label)\"" }
        if let identifier = node.identifier, !identifier.isEmpty { line += " #\(identifier)" }
        if let oid = node.viewOID ?? node.targetOID { line += " oid:\(oid)" }
        if let className = node.className { line += " \(className)" }
        line += " \(formatRect(node.frame))"
        if let hierarchy = node.hierarchy {
            line += " -> view:\(hierarchy.viewOID)"
            if let layerOID = hierarchy.layerOID { line += " layer:\(layerOID)" }
            if let hierarchyClass = hierarchy.className, hierarchyClass != node.className {
                line += " \(hierarchyClass)"
            }
        } else {
            line += " -> [unmatched]"
        }
        lines.append(line)
    }
    return lines.joined(separator: "\n")
}

func axTreeLines(_ nodes: [TKAXNode], indent: Int) -> [String] {
    var lines: [String] = []
    for (index, node) in nodes.enumerated() {
        let isLast = index == nodes.count - 1
        let prefix: String
        if indent == 0 {
            prefix = ""
        } else {
            prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "└─ " : "├─ ")
        }
        var line = "\(prefix)\(node.role)"
        if let label = node.label, !label.isEmpty { line += " \"\(label)\"" }
        if let identifier = node.identifier, !identifier.isEmpty { line += " #\(identifier)" }
        if let oid = node.targetOID { line += " oid:\(oid)" }
        if let className = node.className { line += " \(className)" }
        line += " \(formatRect(node.frame))"
        if node.hidden { line += " [hidden]" }
        if !node.enabled { line += " [disabled]" }
        lines.append(line)
        lines.append(contentsOf: axTreeLines(node.children, indent: indent + 1))
    }
    return lines
}

func selectAXNode(_ nodes: [TKAXNode], oid: UInt?, label: String?) -> TKAXNode? {
    let flattened = TKFlattenAXNodes(nodes).map(\.node)
    if let oid {
        return flattened.first { $0.viewOID == oid || $0.targetOID == oid }
    }
    guard let label else { return nil }
    return flattened
        .filter { $0.label == label }
        .sorted { lhs, rhs in
            axTapPriority(lhs) > axTapPriority(rhs)
        }
        .first
}

struct TapTargetCandidate: Codable {
    let index: Int
    let query: String
    let source: String
    let strategy: String
    let role: String?
    let label: String?
    let value: String?
    let identifier: String?
    let className: String?
    let viewOID: UInt?
    let targetOID: UInt?
    let layerOID: UInt?
    let frame: TKRect?
    let request: TKInputRequest
}

struct TapTargetResolution: Codable {
    let query: String
    let source: String
    let strategy: String
    let role: String?
    let label: String?
    let value: String?
    let identifier: String?
    let className: String?
    let viewOID: UInt?
    let targetOID: UInt?
    let layerOID: UInt?
    let frame: TKRect?
    let request: TKInputRequest
    let matchIndex: Int
    let matchCount: Int
    let candidates: [TapTargetCandidate]?

    init(selected: TapTargetCandidate, candidates: [TapTargetCandidate], includeCandidates: Bool) {
        self.query = selected.query
        self.source = selected.source
        self.strategy = selected.strategy
        self.role = selected.role
        self.label = selected.label
        self.value = selected.value
        self.identifier = selected.identifier
        self.className = selected.className
        self.viewOID = selected.viewOID
        self.targetOID = selected.targetOID
        self.layerOID = selected.layerOID
        self.frame = selected.frame
        self.request = selected.request
        self.matchIndex = selected.index
        self.matchCount = candidates.count
        self.candidates = includeCandidates ? candidates : nil
    }
}

func resolveTapTarget(
    _ query: String,
    client: TritonKitHTTPClient,
    width: Double?,
    height: Double?,
    duration: Double?,
    index: Int? = nil,
    within: TKRect? = nil,
    at: (x: Double, y: Double)? = nil,
    includeCandidates: Bool = false
) async throws -> TapTargetResolution {
    if let index, index <= 0 {
        throw RuntimeError("--index must be greater than 0")
    }
    let candidates = try await tapTargetCandidates(
        query,
        client: client,
        width: width,
        height: height,
        duration: duration,
        within: within,
        at: at
    )
    guard !candidates.isEmpty else {
        throw RuntimeError("No tappable UI target matched query: \(query)")
    }
    let selectedIndex = index ?? 1
    guard selectedIndex <= candidates.count else {
        throw RuntimeError("Only \(candidates.count) tappable UI target(s) matched query: \(query); cannot select --index \(selectedIndex)")
    }
    return TapTargetResolution(
        selected: candidates[selectedIndex - 1],
        candidates: candidates,
        includeCandidates: includeCandidates
    )
}

func tapTargetCandidates(
    _ query: String,
    client: TritonKitHTTPClient,
    width: Double?,
    height: Double?,
    duration: Double?,
    within: TKRect?,
    at: (x: Double, y: Double)?
) async throws -> [TapTargetCandidate] {
    let accessibilityData = try await client.request(type: "accessibility")
    let axNodes = try JSONDecoder().decode([TKAXNode].self, from: accessibilityData)
    let directAXCandidates = selectAXNodesByQuery(axNodes, query: query, includeValue: false)
        .map { axNode in
            let request = tapRequest(for: axNode, width: width, height: height, duration: duration)
            return TapTargetCandidate(
                index: 0,
                query: query,
                source: "ax",
                strategy: axTapShouldUseCoordinate(axNode) ? "coordinate" : "oid",
                role: axNode.role,
                label: axNode.label,
                value: axNode.value,
                identifier: axNode.identifier,
                className: axNode.className,
                viewOID: axNode.viewOID,
                targetOID: axNode.targetOID,
                layerOID: axNode.layerOID,
                frame: axNode.frame,
                request: request
            )
        }

    let hierarchyData = try await client.request(type: "hierarchy")
    let hierarchyCandidates = try await selectHierarchyTextCandidates(
        query,
        hierarchyData: hierarchyData,
        client: client
    ).map { candidate in
        let request = TKInputRequest.tap(
            x: candidate.frame.centerX,
            y: candidate.frame.centerY,
            width: width,
            height: height,
            duration: duration
        )
        return TapTargetCandidate(
            index: 0,
            query: query,
            source: "hierarchy-text",
            strategy: "coordinate",
            role: nil,
            label: query,
            value: nil,
            identifier: nil,
            className: candidate.className,
            viewOID: candidate.viewOID,
            targetOID: nil,
            layerOID: candidate.layerOID,
            frame: candidate.frame,
            request: request
        )
    }

    let valueAXCandidates = selectAXNodesByQuery(axNodes, query: query, includeValue: true)
        .filter { node in
            !(node.label == query || node.identifier == query || node.title == query)
        }
        .map { axNode in
            let request = tapRequest(for: axNode, width: width, height: height, duration: duration)
            return TapTargetCandidate(
                index: 0,
                query: query,
                source: "ax-value",
                strategy: axTapShouldUseCoordinate(axNode) ? "coordinate" : "oid",
                role: axNode.role,
                label: axNode.label,
                value: axNode.value,
                identifier: axNode.identifier,
                className: axNode.className,
                viewOID: axNode.viewOID,
                targetOID: axNode.targetOID,
                layerOID: axNode.layerOID,
                frame: axNode.frame,
                request: request
            )
        }

    let candidates = (directAXCandidates + hierarchyCandidates + valueAXCandidates)
        .filter { candidate in
            guard let within else { return true }
            guard let frame = candidate.frame else { return false }
            return TKRectIntersects(frame, within)
        }
        .filter { candidate in
            guard let at else { return true }
            guard let frame = candidate.frame else { return false }
            return frame.contains(x: at.x, y: at.y)
        }

    return candidates.enumerated().map { offset, candidate in
        TapTargetCandidate(
            index: offset + 1,
            query: candidate.query,
            source: candidate.source,
            strategy: candidate.strategy,
            role: candidate.role,
            label: candidate.label,
            value: candidate.value,
            identifier: candidate.identifier,
            className: candidate.className,
            viewOID: candidate.viewOID,
            targetOID: candidate.targetOID,
            layerOID: candidate.layerOID,
            frame: candidate.frame,
            request: candidate.request
        )
    }
}

func selectAXNodesByQuery(_ nodes: [TKAXNode], query: String, includeValue: Bool = true) -> [TKAXNode] {
    TKFlattenAXNodes(nodes)
        .map(\.node)
        .filter { node in
            node.label == query
                || node.identifier == query
                || node.title == query
                || (includeValue && node.value == query)
        }
        .sorted { lhs, rhs in
            if axTapPriority(lhs) != axTapPriority(rhs) {
                return axTapPriority(lhs) > axTapPriority(rhs)
            }
            if lhs.frame.y != rhs.frame.y {
                return lhs.frame.y < rhs.frame.y
            }
            if lhs.frame.x != rhs.frame.x {
                return lhs.frame.x < rhs.frame.x
            }
            return (lhs.targetOID ?? lhs.viewOID ?? 0) < (rhs.targetOID ?? rhs.viewOID ?? 0)
        }
}

func tapRequest(
    for node: TKAXNode,
    width: Double?,
    height: Double?,
    duration: Double?
) -> TKInputRequest {
    if axTapShouldUseCoordinate(node) {
        return TKInputRequest.tap(
            x: node.frame.centerX,
            y: node.frame.centerY,
            width: width,
            height: height,
            duration: duration
        )
    }
    return TKInputRequest.tap(
        targetOID: node.targetOID ?? node.viewOID,
        width: width,
        height: height,
        duration: duration
    )
}

func axTapShouldUseCoordinate(_ node: TKAXNode) -> Bool {
    if node.targetOID == nil && node.viewOID == nil {
        return true
    }
    return ["text", "image", "textField", "textView"].contains(node.role)
}

struct HierarchyTextCandidate {
    let viewOID: UInt
    let layerOID: UInt
    let className: String
    let frame: TKRect
    let depth: Int
}

func selectHierarchyTextCandidates(
    _ query: String,
    hierarchyData: Data,
    client: TritonKitHTTPClient
) async throws -> [HierarchyTextCandidate] {
    let candidates = try hierarchyTextCandidates(hierarchyData)
        .sorted { lhs, rhs in
            if hierarchyTextCandidatePriority(lhs) != hierarchyTextCandidatePriority(rhs) {
                return hierarchyTextCandidatePriority(lhs) > hierarchyTextCandidatePriority(rhs)
            }
            if lhs.frame.y != rhs.frame.y {
                return lhs.frame.y < rhs.frame.y
            }
            if lhs.frame.x != rhs.frame.x {
                return lhs.frame.x < rhs.frame.x
            }
            return lhs.viewOID < rhs.viewOID
        }

    var matches: [HierarchyTextCandidate] = []
    for candidate in candidates {
        let payload = try JSONEncoder().encode(candidate.layerOID)
        let data = try await client.request(type: "allAttrGroups", payload: payload)
        let groups = try JSONDecoder().decode([TKAttributesGroup].self, from: data)
        if attributeGroups(groups, containText: query) {
            matches.append(candidate)
        }
    }
    return matches
}

func hierarchyTextCandidates(_ data: Data) throws -> [HierarchyTextCandidate] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }
    return flattenHierarchyTextCandidates(items, depth: 0, ancestorVisible: true)
}

func flattenHierarchyTextCandidates(
    _ items: [[String: Any]],
    depth: Int,
    ancestorVisible: Bool
) -> [HierarchyTextCandidate] {
    var candidates: [HierarchyTextCandidate] = []
    for item in items {
        let viewObj = item["viewObject"] as? [String: Any]
        let layerObj = item["layerObject"] as? [String: Any]
        let viewOid = viewObj?["oid"] as? UInt ?? uintValue(viewObj?["oid"])
        let layerOid = layerObj?["oid"] as? UInt ?? uintValue(layerObj?["oid"])
        let className = (viewObj?["classChainList"] as? [String])?.first
            ?? (layerObj?["classChainList"] as? [String])?.first
            ?? ""
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = doubleValue(item["alpha"]) ?? 1
        let visible = ancestorVisible && !hidden && alpha > 0.01
        if let viewOid,
           let layerOid,
           let frame = rectValue(item["frame"]),
           visible,
           frame.width > 0,
           frame.height > 0,
           isHierarchyTextCandidateClass(className) {
            candidates.append(HierarchyTextCandidate(
                viewOID: viewOid,
                layerOID: layerOid,
                className: className,
                frame: frame,
                depth: depth
            ))
        }
        if let subitems = item["subitems"] as? [[String: Any]] {
            candidates.append(contentsOf: flattenHierarchyTextCandidates(
                subitems,
                depth: depth + 1,
                ancestorVisible: visible
            ))
        }
    }
    return candidates
}

func isHierarchyTextCandidateClass(_ className: String) -> Bool {
    className == "UILabel"
        || className == "UISegmentLabel"
        || className == "UIButtonLabel"
        || className == "UITextFieldLabel"
        || className.hasSuffix("Label")
}

func hierarchyTextCandidatePriority(_ candidate: HierarchyTextCandidate) -> Int {
    var priority = 0
    if candidate.className == "UISegmentLabel" { priority += 30 }
    if candidate.className == "UIButtonLabel" { priority += 20 }
    if candidate.className == "UILabel" { priority += 10 }
    priority -= candidate.depth
    return priority
}

func attributeGroups(_ groups: [TKAttributesGroup], containText query: String) -> Bool {
    for group in groups {
        for section in group.attrSections {
            for attribute in section.attributes where isTextAttribute(attribute) {
                if attributeValueString(attribute.value) == query {
                    return true
                }
            }
        }
    }
    return false
}

func isTextAttribute(_ attribute: TKAttribute) -> Bool {
    attribute.identifier == "text" || attribute.displayTitle == "Text" || attribute.displayTitle == "Title"
}

func attributeValueString(_ value: TKAttributeValue?) -> String? {
    guard let value else { return nil }
    switch value {
    case .string(let string):
        return string
    case .number(let number):
        return "\(number)"
    case .bool(let bool):
        return bool ? "true" : "false"
    case .stringArray(let strings):
        return strings.joined(separator: ",")
    case .numberArray(let numbers):
        return numbers.map { "\($0)" }.joined(separator: ",")
    case .null:
        return nil
    }
}

func axTapPriority(_ node: TKAXNode) -> Int {
    var priority = 0
    if !node.hidden { priority += 10 }
    if node.enabled { priority += 10 }
    if ["button", "segmentedControl", "switch", "slider", "stepper", "textField", "textView", "control"].contains(node.role) {
        priority += 20
    }
    if node.role == "text" {
        priority -= 10
    }
    if node.targetOID != nil || node.viewOID != nil {
        priority += 5
    }
    return priority
}

func formatRect(_ rect: TKRect) -> String {
    String(format: "(%.0f,%.0f %.0fx%.0f)", rect.x, rect.y, rect.width, rect.height)
}

func resolveExportFormat(_ format: ExportOutputFormat, output: String) throws -> ExportOutputFormat {
    switch format {
    case .json, .archive:
        return format
    case .auto:
        let pathExtension = URL(fileURLWithPath: output).pathExtension.lowercased()
        switch pathExtension {
        case "", "json":
            return .json
        case "triton", "tritonkit", "archive", "lookinside":
            return .archive
        default:
            throw RuntimeError("Unsupported export extension: .\(pathExtension)")
        }
    }
}

// Flush-printing to stderr for immediate output in piped environments
func log(_ msg: String) {
    fputs("\(msg)\n", stderr)
    fflush(stderr)
}

// MARK: - Extensions

extension WebSocketOutboundWriter {
    func send(_ msg: TKMessage, encoder: JSONEncoder) async throws {
        guard let data = try? encoder.encode(msg) else { return }
        try await write(.binary(ByteBuffer(data: data)))
    }
}

// MARK: - Response Handling

func handleResponse(
    data: Data,
    store: DataStore,
    targetState: TargetState
) {
    guard let msg = try? JSONDecoder().decode(TKMessage.self, from: data) else {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            log("[tritonkit] <- raw:\n\(str)")
        }
        return
    }

    log("[tritonkit] <- \(msg.type.rawValue) [id:\(msg.id)]")

    guard let payload = msg.payload,
          let json = try? JSONSerialization.jsonObject(with: payload) else { return }
    targetState.storeResponse(id: msg.id, payload: payload)

    switch msg.type {
    case .hierarchy:
        targetState.setLatestHierarchy(payload)
        if let dict = json as? [String: Any] {
            if let items = dict["displayItems"] as? [[String: Any]] {
                printHierarchy(items, indent: 0)
            }
            if let info = dict["appInfo"] as? [String: Any] {
                log("── App: \(info["appName"] ?? "?") | \(info["deviceDescription"] ?? "?") | OS \(info["osDescription"] ?? "?")")
            }
        }

    case .appInfo:
        targetState.setLatestAppInfo(payload)
        if let dict = json as? [String: Any] {
            log("── \(dict["appName"] ?? "?") | \(dict["appBundleIdentifier"] ?? "?") | Device: \(dict["deviceDescription"] ?? "?")")
        }

    case .hierarchyDetails:
        checkAndShowImage(json: json, label: "solo", store: store)
        checkAndShowImage(json: json, label: "group", store: store)

    case .ping: log("  Pong!")
    default:
        if let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) { log(str) }
    }
}

func checkAndShowImage(json: Any, label: String, store: DataStore) {
    guard let dict = json as? [String: Any],
          let ref = dict["\(label)ScreenshotRef"] as? String,
          let id = UUID(uuidString: ref),
          let imgData = store.get(id) else { return }
    let size = ByteCountFormatter.string(fromByteCount: Int64(imgData.count), countStyle: .file)
    log("  [\(label) screenshot: \(size)]")
}

func renderHierarchyTree(_ data: Data, hideNoise: Bool = true) throws -> String {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }

    var lines: [String] = []
    if let info = json["appInfo"] as? [String: Any] {
        let appName = info["appName"] as? String ?? "?"
        let device = info["deviceDescription"] as? String ?? "?"
        let os = info["osDescription"] as? String ?? "?"
        lines.append("App: \(appName) | \(device) | OS \(os)")
    }
    lines.append(contentsOf: hierarchyTreeLines(items, indent: 0, hideNoise: hideNoise))
    return lines.joined(separator: "\n")
}

func hierarchyNodeSummaries(_ data: Data) throws -> [[String: Any]] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["displayItems"] as? [[String: Any]] else {
        throw RuntimeError("Hierarchy payload does not contain displayItems")
    }
    return flattenNodeSummaries(items, depth: 0)
}

func flattenNodeSummaries(_ items: [[String: Any]], depth: Int) -> [[String: Any]] {
    var nodes: [[String: Any]] = []
    for item in items {
        let viewObj = item["viewObject"] as? [String: Any]
        let layerObj = item["layerObject"] as? [String: Any]
        let viewOid = viewObj?["oid"] as? UInt ?? uintValue(viewObj?["oid"])
        let layerOid = layerObj?["oid"] as? UInt ?? uintValue(layerObj?["oid"])
        let oid = viewOid ?? layerOid ?? 0
        let className = (viewObj?["classChainList"] as? [String])?.first
            ?? (layerObj?["classChainList"] as? [String])?.first
            ?? "?"
        var node: [String: Any] = [
            "oid": oid,
            "className": className,
            "depth": depth,
            "hidden": item["isHidden"] as? Bool ?? false,
            "alpha": doubleValue(item["alpha"]) ?? 1,
            "frame": frameDescription(item["frame"]) ?? "",
        ]
        if let viewOid { node["viewOid"] = viewOid }
        if let layerOid { node["layerOid"] = layerOid }
        if let title = item["customDisplayTitle"] as? String { node["title"] = title }
        nodes.append(node)
        if let subitems = item["subitems"] as? [[String: Any]] {
            nodes.append(contentsOf: flattenNodeSummaries(subitems, depth: depth + 1))
        }
    }
    return nodes
}

func uintValue(_ value: Any?) -> UInt? {
    if let value = value as? UInt { return value }
    if let value = value as? Int { return UInt(value) }
    if let value = value as? NSNumber { return value.uintValue }
    return nil
}

func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Float { return Double(value) }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    return nil
}

func rectValue(_ frame: Any?) -> TKRect? {
    if let dict = frame as? [String: Any] {
        return TKRect(
            x: doubleValue(dict["x"]) ?? 0,
            y: doubleValue(dict["y"]) ?? 0,
            width: doubleValue(dict["width"]) ?? 0,
            height: doubleValue(dict["height"]) ?? 0
        )
    }
    guard let array = frame as? [[Double]], array.count >= 2 else {
        return nil
    }
    let origin = array[0]
    let size = array[1]
    guard origin.count >= 2, size.count >= 2 else {
        return nil
    }
    return TKRect(x: origin[0], y: origin[1], width: size[0], height: size[1])
}

func nodeMatches(_ node: [String: Any], oid: UInt) -> Bool {
    uintValue(node["oid"]) == oid || uintValue(node["viewOid"]) == oid || uintValue(node["layerOid"]) == oid
}

func renderNodeLine(_ node: [String: Any]) -> String {
    [
        "\(node["oid"] ?? "-")",
        "\(node["layerOid"] ?? "-")",
        "\(node["depth"] ?? "-")",
        "\(node["className"] ?? "-")",
        "\(node["frame"] ?? "-")",
    ].joined(separator: "\t")
}

func renderAttributeGroups(_ groups: [TKAttributesGroup]) -> String {
    guard !groups.isEmpty else { return "No attributes" }
    var lines: [String] = []
    for group in groups {
        lines.append("[\(group.title)]")
        for section in group.attrSections {
            lines.append("  \(section.identifier)")
            for attribute in section.attributes {
                lines.append("    \(attribute.displayTitle ?? attribute.identifier): \(describeAttributeValue(attribute.value))")
            }
        }
    }
    return lines.joined(separator: "\n")
}

func describeAttributeValue(_ value: TKAttributeValue?) -> String {
    guard let value else { return "-" }
    switch value {
    case .null: return "null"
    case .string(let value): return value
    case .number(let value): return "\(value)"
    case .bool(let value): return "\(value)"
    case .stringArray(let value): return value.joined(separator: ",")
    case .numberArray(let value): return value.map { "\($0)" }.joined(separator: ",")
    }
}

func printHierarchy(_ items: [[String: Any]], indent: Int) {
    for line in hierarchyTreeLines(items, indent: indent, hideNoise: true) {
        log(line)
    }
}

func hierarchyTreeLines(_ items: [[String: Any]], indent: Int, hideNoise: Bool = true) -> [String] {
    var lines: [String] = []
    let renderedItems = hierarchyTreeRenderableItems(items, hideNoise: hideNoise)
    for (i, item) in renderedItems.enumerated() {
        let isLast = i == renderedItems.count - 1
        let prefix: String
        if indent == 0 { prefix = "  " }
        else { prefix = String(repeating: "  ", count: indent - 1) + (isLast ? "  └─ " : "  ├─ ") }

        let viewObj = item["viewObject"] as? [String: Any]
        let className = (viewObj?["classChainList"] as? [String])?.first ?? "?"
        let frame = item["frame"]
        let hidden = item["isHidden"] as? Bool ?? false
        let alpha = item["alpha"] as? Float ?? 1.0
        let title = item["customDisplayTitle"] as? String
        let screenshotRef = item["screenshotRef"] as? String

        var line = "\(prefix)\(className)"
        if let t = title { line += " \"\(t)\"" }
        if let frame = frameDescription(frame) {
            line += " \(frame)"
        }
        if hidden { line += " [H]" }
        if alpha < 1 { line += String(format: " α:%.2f", alpha) }
        if screenshotRef != nil { line += " [image]" }
        lines.append(line)

        if let subitems = item["subitems"] as? [[String: Any]] {
            lines.append(contentsOf: hierarchyTreeLines(subitems, indent: indent + 1, hideNoise: hideNoise))
        }
    }
    return lines
}

func hierarchyTreeRenderableItems(_ items: [[String: Any]], hideNoise: Bool) -> [[String: Any]] {
    guard hideNoise else { return items }
    return items.flatMap { item -> [[String: Any]] in
        guard let className = hierarchyTreeClassName(item),
              TKIsDefaultHiddenHierarchyTreeClass(className),
              let subitems = item["subitems"] as? [[String: Any]]
        else {
            return [item]
        }
        return hierarchyTreeRenderableItems(subitems, hideNoise: hideNoise)
    }
}

func hierarchyTreeClassName(_ item: [String: Any]) -> String? {
    let viewObj = item["viewObject"] as? [String: Any]
    if let className = (viewObj?["classChainList"] as? [String])?.first {
        return className
    }
    let layerObj = item["layerObject"] as? [String: Any]
    return (layerObj?["classChainList"] as? [String])?.first
}

func frameDescription(_ frame: Any?) -> String? {
    if let dict = frame as? [String: Any] {
        return String(format: "(%.0f,%.0f %.0fx%.0f)",
            dict["x"] as? Double ?? 0, dict["y"] as? Double ?? 0,
            dict["width"] as? Double ?? 0, dict["height"] as? Double ?? 0)
    }
    guard let array = frame as? [[Double]], array.count >= 2 else {
        return nil
    }
    let origin = array[0]
    let size = array[1]
    guard origin.count >= 2, size.count >= 2 else {
        return nil
    }
    return String(format: "(%.0f,%.0f %.0fx%.0f)", origin[0], origin[1], size[0], size[1])
}
