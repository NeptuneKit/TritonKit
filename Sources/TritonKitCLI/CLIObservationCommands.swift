import ArgumentParser
import TritonKitShared

private func observationPlatform(from platform: HostDevicePlatform) -> ObservationPlatform {
    switch platform {
    case .ios:
        return .ios
    case .android:
        return .android
    case .harmony:
        return .harmony
    }
}

private func hostDevicePlatform(from platform: ObservationPlatform) -> HostDevicePlatform {
    switch platform {
    case .ios:
        return .ios
    case .android:
        return .android
    case .harmony:
        return .harmony
    }
}

func resolveObservationTarget(
    device: String?,
    platform: ObservationPlatform?,
    target: String,
    hdc: String,
    runtimeBaseURL: String?
) throws -> (platform: ObservationPlatform, target: String, hostTarget: HostDeviceTarget?) {
    if device != nil && target != TKLocalTargetID {
        throw HostDeviceSelectionError.parameterConflict("--device cannot be combined with --target.")
    }
    let effectivePlatform = platform ?? .ios
    if device == nil && effectivePlatform == .ios {
        return (platform ?? .ios, target, nil)
    }
    let selection = try resolveHostDeviceSelection(
        request: HostDeviceSelectionRequest(
            device: device ?? (target == TKLocalTargetID ? nil : target),
            platform: hostDevicePlatform(from: effectivePlatform),
            ready: runtimeBaseURL == nil
        ),
        hdc: hdc
    )
    return (observationPlatform(from: selection.platform), selection.target.target, selection.target)
}

func usesIOSHostSimulatorAX(_ target: HostDeviceTarget?) -> Bool {
    guard let target else { return false }
    return target.platform == HostDevicePlatform.ios.rawValue
        && (target.scope == "simulator" || target.kind == "simulator" || target.id.hasPrefix("sim:"))
}

struct Observe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Observe the current app surface from host and runtime sources",
        subcommands: [ObserveCurrent.self, ObserveTree.self]
    )
}

struct NodeWorkflow: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "node",
        abstract: "Resolve current visible UI nodes",
        subcommands: [NodeResolve.self]
    )
}

struct ObserveCurrent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current", abstract: "Read the current visible app snapshot")

    @Option(help: "Observation platform: ios, android, or harmony") var platform: ObservationPlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Runtime target id from `triton list`; when --platform android or harmony, pass the raw host target id") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony host selection") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Maximum nodes to return") var maxNodes: Int?
    @Option(help: "Write host layout artifact to a file for Android or Harmony") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveObservationTarget(device: device, platform: platform, target: target, hdc: hdc, runtimeBaseURL: runtimeBaseURL)
            try await runObserve(
                action: "observe.current",
                platform: resolved.platform,
                target: resolved.target,
                hdc: hdc,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                maxNodes: maxNodes,
                output: output,
                format: format,
                json: json,
                iosHostAX: usesIOSHostSimulatorAX(resolved.hostTarget)
            )
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct ObserveTree: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tree", abstract: "Read the current visible node tree")

    @Option(help: "Observation platform: ios, android, or harmony") var platform: ObservationPlatform?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Runtime target id from `triton list`; when --platform android or harmony, pass the raw host target id") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony host selection") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Maximum nodes to return") var maxNodes: Int?
    @Option(help: "Write host layout artifact to a file for Android or Harmony") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @Flag(help: "Emit deterministic @N node aliases and cache them in .triton/node-aliases.json") var outline = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveObservationTarget(device: device, platform: platform, target: target, hdc: hdc, runtimeBaseURL: runtimeBaseURL)
            try await runObserve(
                action: "observe.tree",
                platform: resolved.platform,
                target: resolved.target,
                hdc: hdc,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                maxNodes: maxNodes,
                output: output,
                outline: outline,
                format: format,
                json: json,
                iosHostAX: usesIOSHostSimulatorAX(resolved.hostTarget)
            )
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct NodeResolve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "resolve", abstract: "Resolve a current UI node by text, id, key, accessibility id, or point")

    @Argument(help: "Visible text/id query or @N alias from `triton observe tree --outline --json`") var query: String?
    @Option(help: "Observation platform: ios, android, or harmony") var platform: ObservationPlatform?
    @Option(name: .customLong("text"), help: "Visible text, label, identifier, title, value, key, or accessibility id") var text: String?
    @Option(help: "Unified host device selector: alias, sim:<udid>, android:<serial>, harmony:<target>, raw id, booted, or current") var device: String?
    @Option(help: "Runtime target id from `triton list`; when --platform android or harmony, pass the raw host target id") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony host selection") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Select one matching candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?
    @Flag(help: "Include all matching candidates") var all = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveObservationTarget(device: device, platform: platform, target: target, hdc: hdc, runtimeBaseURL: runtimeBaseURL)
            try await runNodeResolve(
                platform: resolved.platform,
                query: query,
                text: text,
                target: resolved.target,
                hdc: hdc,
                host: host,
                port: port,
                runtimeBaseURL: runtimeBaseURL,
                index: index,
                within: within,
                at: at,
                all: all,
                format: format,
                json: json,
                iosHostAX: usesIOSHostSimulatorAX(resolved.hostTarget)
            )
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
