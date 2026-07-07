import ArgumentParser
import Foundation

struct Target: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "target",
        abstract: "Discover, resolve, and track the current agent target",
        subcommands: [TargetList.self, TargetUse.self, TargetCurrent.self, TargetResolve.self, TargetWaitReady.self]
    )
}

struct TargetList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List platform targets")

    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform = .harmony
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try hostDeviceTargets(platform: platform, hdc: hdc, adb: adb)
            let output = HostDeviceListOutput(
                ok: true,
                platform: platform.rawValue,
                targets: result.targets,
                defaultTarget: selectHostDeviceTarget(target: nil, candidates: result.targets),
                sourceCommand: result.sourceCommand
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for target in result.targets {
                    switch platform {
                    case .ios:
                        print("\(target.target)\t\(target.state)\t\(target.runtime ?? "-")\t\(target.name ?? "-")")
                    case .android:
                        print("\(target.target)\t\(target.state)\t\(target.name ?? "-")")
                    case .harmony:
                        print("\(target.target)\t\(target.state)\t\(target.transport ?? "-")")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Resolve a target selector and save it as the current agent target")

    @Argument(help: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Target scope filter: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selected = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector, platform: platform, scope: scope, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            var store = try loadHostTargetAliasStore()
            store.current = hostDeviceCurrentSelector(explicitSelector: selector, explicitTarget: nil, selected: selected)
            let defaultsPath = try saveHostTargetAliasStore(store)
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceUseOutput(ok: true, platform: selected.platform.rawValue, target: selected.target, defaultsPath: defaultsPath, selection: selected)))
            case .text:
                print(selected.target.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetCurrent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current", abstract: "Show the current agent target")

    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let store = try loadHostTargetAliasStore()
            let path = HostTargetAliasStore.filePath(workspace: FileManager.default.currentDirectoryPath)
            let selection = try store.current.map {
                try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: $0), hdc: hdc, adb: adb)
            }
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceCurrentOutput(ok: true, current: store.current, selection: selection, path: path)))
            case .text:
                print(selection?.target.target ?? "")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetResolve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "resolve", abstract: "Resolve one target selector without executing an action")

    @Argument(help: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Target scope filter: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector, platform: platform, scope: scope, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(HostDeviceResolveOutput(ok: true, selection: selection)))
            case .text:
                print(selection.target.target)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetWaitReady: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "wait-ready", abstract: "Wait until a platform target is ready")

    @Option(help: "Target selector: alias, sim:<udid>, harmony:<target>, raw id, booted, or current") var selector: String?
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted or connected") var state: String?
    @Flag(help: "Only match ready targets before waiting") var ready = false
    @Option(help: "Path to hdc executable") var hdc: String = "hdc"
    @Option(help: "Path to adb executable") var adb: String = "adb"
    @Option(help: "Timeout in seconds") var timeout: Double = 30
    @Option(help: "Polling interval in seconds") var interval: Double = 1
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(device: selector, platform: platform, name: name, runtime: runtime, state: state, ready: ready),
                hdc: hdc,
                adb: adb
            )
            let event = try await waitForHostDeviceReady(
                platform: selection.platform,
                selected: selection.target,
                hdc: hdc,
                adb: adb,
                timeout: timeout,
                interval: interval
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(event))
            case .text:
                print("\(event.target.target)\tready=\(event.ready)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
