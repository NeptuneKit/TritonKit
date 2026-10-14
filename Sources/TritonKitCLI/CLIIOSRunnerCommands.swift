import ArgumentParser
import Foundation

struct DeviceRunner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "runner", abstract: "Manage the bundled iOS resident XCTest Runner", subcommands: [IOSRunnerDoctor.self, IOSRunnerPrepare.self, IOSRunnerStart.self, IOSRunnerStatus.self, IOSRunnerStop.self, IOSRunnerRequest.self, IOSRunnerReceipt.self, IOSRunnerActivate.self, IOSRunnerInspect.self, IOSRunnerTap.self, IOSRunnerScroll.self, IOSRunnerType.self, IOSRunnerScreenshot.self])
}

struct IOSRunnerOptions: ParsableArguments {
    @Option(help: "Explicit iOS real-device or Simulator selector") var device: String
    @Option(help: "Private Runner session storage root") var sessionRoot: String?
    @Option(help: "Operation timeout in seconds; defaults depend on the subcommand") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    mutating func validate() throws {
        guard !device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValidationError("--device must be explicit") }
        if let timeout { guard timeout.isFinite, timeout >= 1, timeout <= 3600 else { throw ValidationError("--timeout must be 1...3600 seconds") } }
    }
    func payload(defaultTimeout: Double = 60) -> [String: Any] {
        var result: [String: Any] = ["device": device, "timeout": timeout ?? defaultTimeout]
        if let sessionRoot { result["sessionRoot"] = sessionRoot }
        return result
    }
}

func iosRunnerBoundedFile(_ path: String, maximum: Int = 65536) throws -> Data {
    let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? file.close() }
    let data = try file.read(upToCount: maximum + 1) ?? Data()
    guard data.count <= maximum else { throw ValidationError("Runner input exceeds the allowed byte limit") }
    return data
}

func iosRunnerBodyFile(_ path: String) throws -> [String: Any] {
    let data = try iosRunnerBoundedFile(path)
    guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ValidationError("--body-file must contain a JSON object") }
    return body
}

func iosRunnerErrorEnvelope(code: String, message: String) -> Data {
    (try? JSONSerialization.data(withJSONObject: ["ok": false, "error": ["code": code, "message": message]], options: [.sortedKeys])) ?? Data("{\"ok\":false}".utf8)
}

func iosRunnerExecute(_ operation: String, payload: [String: Any], options: IOSRunnerOptions) async throws {
    let input = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    let output: Data
    do { output = try await Task.detached { try IOSRunnerService().execute(operation: operation, payload: input) }.value }
    catch { output = iosRunnerErrorEnvelope(code: "ios_runner_operation_failed", message: "Runner operation failed; inspect private session diagnostics") }
    guard let envelope = try? JSONSerialization.jsonObject(with: output) as? [String: Any], let ok = envelope["ok"] as? Bool else {
        print(String(decoding: iosRunnerErrorEnvelope(code: "ios_runner_invalid_response", message: "Runner returned an invalid response"), as: UTF8.self))
        throw ExitCode.failure
    }
    // JSON is always a single service envelope, never a second CLI wrapper.
    if effectiveFormat(options.format, json: options.json) == .json { print(String(decoding: output, as: UTF8.self)) }
    else if ok { print(String(decoding: output, as: UTF8.self)) }
    else { print(((envelope["error"] as? [String: Any])?["message"] as? String) ?? "Runner operation failed") }
    if !ok { throw ExitCode.failure }
}

struct IOSRunnerDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Doctor the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    mutating func validate() throws { if let timeout = options.timeout { guard timeout <= 120 else { throw ValidationError("--timeout must not exceed 120 seconds") } } }
    func payload() throws -> [String: Any] {
        let value = options.payload(defaultTimeout: 10)
        return value
    }
    func run() async throws { try await iosRunnerExecute("doctor", payload: payload(), options: options) }
}

struct IOSRunnerPrepare: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "prepare", abstract: "Prepare the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    @Option(help: "Apple development team identifier; omitted selects an unambiguous available team") var team: String?
    @Flag(help: "Allow Xcode provisioning updates") var allowProvisioningUpdates = false
    mutating func validate() throws { if let timeout = options.timeout { guard timeout <= 1800 else { throw ValidationError("--timeout must not exceed 1800 seconds") } } }
    func payload() throws -> [String: Any] {
        var value = options.payload(defaultTimeout: 600)
        value["allowProvisioning"] = allowProvisioningUpdates
        if let team { value["team"] = team }
        return value
    }
    func run() async throws { try await iosRunnerExecute("prepare", payload: payload(), options: options) }
}

struct IOSRunnerStart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    @Option(help: "Session TTL in seconds, 10...3600") var ttl: Double = 600
    @Option(name: .customLong("allow-bundle"), parsing: .singleValue, help: "Explicit target bundle allowlist; repeat for each App") var allowBundles: [String] = []
    mutating func validate() throws {
        guard ttl.isFinite, ttl >= 10, ttl <= 3600 else { throw ValidationError("--ttl must be 10...3600 seconds") }
        if let timeout = options.timeout { guard timeout <= 120 else { throw ValidationError("--timeout must not exceed 120 seconds") } }
    }
    func payload() throws -> [String: Any] {
        var value = options.payload(defaultTimeout: 120)
        value["ttl"] = ttl
        value["allowBundles"] = allowBundles
        return value
    }
    func run() async throws { try await iosRunnerExecute("start", payload: payload(), options: options) }
}

struct IOSRunnerStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Status the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    mutating func validate() throws { if let timeout = options.timeout { guard timeout <= 120 else { throw ValidationError("--timeout must not exceed 120 seconds") } } }
    func payload() throws -> [String: Any] {
        let value = options.payload(defaultTimeout: 10)
        return value
    }
    func run() async throws { try await iosRunnerExecute("status", payload: payload(), options: options) }
}

struct IOSRunnerStop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    mutating func validate() throws { if let timeout = options.timeout { guard timeout <= 120 else { throw ValidationError("--timeout must not exceed 120 seconds") } } }
    func payload() throws -> [String: Any] {
        let value = options.payload(defaultTimeout: 30)
        return value
    }
    func run() async throws { try await iosRunnerExecute("stop", payload: payload(), options: options) }
}

struct IOSRunnerRequest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "request", abstract: "Request the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    @Option(help: "JSON object body file, at most 64KiB") var bodyFile: String
    @Option(help: "Runner route: /crossApp|/probe|/snapshot|/tap|/screenshot|/home|/activateFixture") var route: String = "/crossApp"
    @Option(name: .customLong("request-id"), help: "Idempotency identifier; uncertain outcomes require receipt lookup") var requestID: String?
    mutating func validate() throws {
        guard ["/crossApp", "/probe", "/snapshot", "/tap", "/screenshot", "/home", "/activateFixture", "/environment"].contains(route) else { throw ValidationError("Unsupported Runner --route") }
        if let timeout = options.timeout { guard timeout <= 120 else { throw ValidationError("Runner request --timeout must not exceed 120 seconds") } }
    }
    func payload() throws -> [String: Any] {
        var value = options.payload(defaultTimeout: 18)
        value["body"] = try iosRunnerBodyFile(bodyFile)
        value["route"] = route
        if let requestID { value["requestID"] = requestID }
        return value
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: options) }
}

struct IOSRunnerReceipt: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "receipt", abstract: "Receipt the bundled iOS Runner")
    @OptionGroup var options: IOSRunnerOptions
    @Option(name: .customLong("request-id"), help: "Original action request identifier") var requestID: String
    @Option(help: "Recover an original cached screenshot to a fresh private PNG file") var output: String?
    mutating func validate() throws { if let timeout = options.timeout { guard timeout <= 120 else { throw ValidationError("--timeout must not exceed 120 seconds") } } }
    func payload() throws -> [String: Any] {
        var value = options.payload(defaultTimeout: 18)
        value["requestID"] = requestID
        if let output { value["screenshotOutput"] = output }
        return value
    }
    func run() async throws { try await iosRunnerExecute("receipt", payload: payload(), options: options) }
}

struct IOSRunnerTargetOptions: ParsableArguments {
    @OptionGroup var common: IOSRunnerOptions
    @Option(help: "Exact bundle identifier from the session allowlist") var bundleID: String
    @Option(name: .customLong("request-id"), help: "Idempotency identifier; uncertain outcomes require receipt lookup") var requestID: String?
    mutating func validate() throws {
        guard !bundleID.isEmpty else { throw ValidationError("--bundle-id must not be empty") }
        if let timeout = common.timeout { guard timeout <= 120 else { throw ValidationError("Runner request --timeout must not exceed 120 seconds") } }
    }
    func payload(operation: String, additions: [String: Any] = [:]) -> [String: Any] {
        var value = common.payload(defaultTimeout: 18)
        var body: [String: Any] = ["app": "target", "operation": operation, "expectedBundle": bundleID]
        body.merge(additions) { _, new in new }
        value["route"] = "/crossApp"
        value["body"] = body
        if let requestID { value["requestID"] = requestID }
        return value
    }
}

struct IOSRunnerSelectorOptions: ParsableArguments {
    @Option(help: "Exact identifier from the latest inspect result") var identifier: String?
    @Option(help: "Exact label from the latest inspect result") var label: String?
    mutating func validate() throws {
        guard (identifier == nil) != (label == nil), !(identifier ?? label ?? "").isEmpty else { throw ValidationError("Supply exactly one nonempty --identifier or --label from the latest inspect") }
    }
    var value: [String: String] { ["kind": identifier != nil ? "identifier" : "label", "value": identifier ?? label ?? ""] }
}

struct IOSRunnerActivate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate", abstract: "Activate an allowlisted App using the active Runner session")
    @OptionGroup var target: IOSRunnerTargetOptions
    func payload() throws -> [String: Any] {
        target.payload(operation: "activate", additions: [:])
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: target.common) }
}

struct IOSRunnerInspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect an allowlisted App using the active Runner session")
    @OptionGroup var target: IOSRunnerTargetOptions
    @Option(help: "Returned element budget, 1...40") var limit: Int = 40
    mutating func validate() throws { guard (1...40).contains(limit) else { throw ValidationError("--limit must be 1...40") } }
    func payload() throws -> [String: Any] {
        target.payload(operation: "inspect", additions: ["limit": limit])
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: target.common) }
}

struct IOSRunnerTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tap", abstract: "Tap an allowlisted App using the active Runner session")
    @OptionGroup var target: IOSRunnerTargetOptions
    @OptionGroup var selector: IOSRunnerSelectorOptions
    func payload() throws -> [String: Any] {
        target.payload(operation: "tap", additions: ["selector": selector.value])
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: target.common) }
}

struct IOSRunnerScroll: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scroll", abstract: "Scroll an allowlisted App using the active Runner session")
    @OptionGroup var target: IOSRunnerTargetOptions
    @Option(help: "Scroll direction: up|down|left|right") var direction: String
    mutating func validate() throws { guard ["up", "down", "left", "right"].contains(direction) else { throw ValidationError("Unsupported --direction") } }
    func payload() throws -> [String: Any] {
        target.payload(operation: "scroll", additions: ["direction": direction])
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: target.common) }
}

struct IOSRunnerType: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type", abstract: "Type an allowlisted App using the active Runner session")
    @OptionGroup var target: IOSRunnerTargetOptions
    @OptionGroup var selector: IOSRunnerSelectorOptions
    @Option(help: "UTF-8 text file; no sensitive text in command arguments") var textFile: String
    func payload() throws -> [String: Any] {
        guard let text = String(data: try iosRunnerBoundedFile(textFile, maximum: 4096), encoding: .utf8), !text.isEmpty else { throw ValidationError("--text-file must contain nonempty UTF-8 text, at most 4096 bytes") }
        return target.payload(operation: "typeText", additions: ["selector": selector.value, "text": text])
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: target.common) }
}

struct IOSRunnerScreenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Screenshot an allowlisted App using the active Runner session")
    @OptionGroup var target: IOSRunnerTargetOptions
    @Option(help: "Private PNG output file, must not already exist") var output: String
    func payload() throws -> [String: Any] {
        var value = target.payload(operation: "screenshot", additions: [:])
        value["screenshotOutput"] = output
        return value
    }
    func run() async throws { try await iosRunnerExecute("request", payload: payload(), options: target.common) }
}
