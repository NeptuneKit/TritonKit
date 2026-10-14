import ArgumentParser
import Foundation

struct DeviceDiagnosticsOptions: ParsableArguments {
    @Option(help: "Unified exact host device selector") var device: String?
    @Option(help: "ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Query/sample timeout in seconds, 0.1...300") var timeout: Double = 10
    @Option(help: "Maximum accepted report/log body bytes, 1...16777216") var maximumBytes: Int = 1_048_576
    @Option(help: "Maximum listed reports, 1...10000") var maximumEntries: Int = 1000
    @Option(help: "adb executable") var adb = "adb"
    @Option(help: "hdc executable") var hdc = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func selection() throws -> HostDeviceSelectionResult {
        try validateDeviceDiagnosticsBudget(timeout: timeout, maximumBytes: maximumBytes, maximumEntries: maximumEntries)
        return try resolveHostDeviceSelection(request: .init(device: device, platform: platform, scope: scope, name: nil, runtime: nil, state: nil, ready: false), hdc: hdc)
    }
    func emit(_ value: DeviceDiagnosticsOutput) throws {
        if effectiveFormat(format, json: json) == .json { print(try encodeJSON(value)) }
        else {
            print("\(value.action): source=\(value.source) partial=\(value.partial)")
            for entry in value.entries { print("\(entry.name)\t\(entry.source)") }
            if let content = value.content { print(content) }
            for artifact in value.artifacts { print("artifact: \(artifact)") }
        }
    }
}
struct DeviceLogs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "logs", abstract: "Capture bounded readonly platform system logs into a private artifact")
    @OptionGroup var options: DeviceDiagnosticsOptions
    @Option(help: "Simulator history window in seconds; other platforms use native buffers/live samples") var lastSeconds = 60
    @Option(help: "Optional libimobiledevice executable for physical iOS system logs") var idevicesyslog = "idevicesyslog"
    @Flag(help: "Include sensitive log content in JSON/text; default private artifact only") var includeContent = false
    func run() async throws {
        do {
            guard (1...86_400).contains(lastSeconds) else { throw DeviceDiagnosticsError.invalidRequest }
            try options.emit(captureDeviceLogs(selection: options.selection(), timeout: options.timeout, maximumBytes: options.maximumBytes, lastSeconds: lastSeconds, includeContent: includeContent, adb: options.adb, hdc: options.hdc, idevicesyslog: idevicesyslog))
        } catch { try failHostCommand(error, outputFormat: effectiveFormat(options.format, json: options.json)) }
    }
}
struct DeviceCrashes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "crashes", abstract: "List target-bound crash reports or fetch their actual sensitive body", subcommands: [DeviceCrashesList.self, DeviceCrashesGet.self])
}
struct DeviceCrashesList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List native crash report metadata; permission gaps are explicitly partial")
    @OptionGroup var options: DeviceDiagnosticsOptions
    func run() async throws {
        do { try options.emit(listDeviceCrashes(selection: options.selection(), timeout: options.timeout, maximumBytes: options.maximumBytes, maximumEntries: options.maximumEntries, adb: options.adb, hdc: options.hdc)) }
        catch { try failHostCommand(error, outputFormat: effectiveFormat(options.format, json: options.json)) }
    }
}
struct DeviceCrashesGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Fetch one report from a fresh target-bound listing into a private artifact")
    @Argument(help: "Exact report name from device crashes list; Android also provides crash-buffer") var name: String
    @OptionGroup var options: DeviceDiagnosticsOptions
    func run() async throws {
        do {
            try validateDeviceCrashName(name)
            try options.emit(getDeviceCrash(selection: options.selection(), name: name, timeout: options.timeout, maximumBytes: options.maximumBytes, adb: options.adb, hdc: options.hdc))
        } catch { try failHostCommand(error, outputFormat: effectiveFormat(options.format, json: options.json)) }
    }
}
