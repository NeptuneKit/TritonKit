import ArgumentParser
import Foundation
import TritonKitShared

/// Standalone typed action parsers. Registration into the existing `device`
/// tree is intentionally owned by the integration agent.
struct DeviceActionCommonOptions: ParsableArguments {
    @Option(help: "Explicit target selector") var device: String
    @Option(help: "Target platform: ios, android, or harmony") var platform: String
    @Option(help: "Latest observation geometry width") var width: Double?
    @Option(help: "Latest observation geometry height") var height: Double?
    @Option(help: "Latest observation orientation") var orientation: String?
    @Option(help: "Latest observation identifier") var observationID: String?
    @Option(help: "Idempotency request identifier") var requestID: String = UUID().uuidString
    @Option(help: "Bundle ID for iOS Runner actions") var bundleID: String?
    @Option(help: "Latest observed element identifier") var identifier: String?
    @Option(help: "Latest observed element label") var label: String?
    @Option(help: "ADB executable") var adb: String = "adb"
    @Option(help: "HDC executable") var hdc: String = "hdc"
    @Option(help: "Private iOS Runner session root") var sessionRoot: String?
    @Option(name: .customLong("evidence-dir"), help: "Fresh private action evidence directory; existing paths are refused") var evidenceDir: String?
    @Option(name: .customLong("lease"), help: "Optional target lease token") var leaseID: String?
    @Option(help: "Server host for target lease check") var host: String = "127.0.0.1"
    @Option(help: "Server port for target lease check") var port: Int = 19421
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
}

struct DeviceTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tap")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var x: Double
    @Option var y: Double
    func payload() throws -> DeviceActionPayload { try common.make(.tap, x: x, y: y) }
}
struct DeviceDoubleTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "double-tap")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var x: Double
    @Option var y: Double
    func payload() throws -> DeviceActionPayload { try common.make(.doubleTap, x: x, y: y) }
}
struct DeviceSwipe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "swipe")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var x: Double
    @Option var y: Double
    @Option var endX: Double
    @Option var endY: Double
    @Option var duration: Double
    func payload() throws -> DeviceActionPayload { try common.make(.swipe, x: x, y: y, endX: endX, endY: endY, duration: duration) }
}
struct DevicePress: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "press")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option var button: String
    func payload() throws -> DeviceActionPayload { try common.make(.press, button: button) }
}
struct DeviceType: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type")
    @OptionGroup var common: DeviceActionCommonOptions
    @Option(help: "Private UTF-8 text file") var textFile: String
    func payload() throws -> DeviceActionPayload { try common.make(.type, textFile: textFile) }
}
private extension DeviceActionCommonOptions {
    func make(_ action: DeviceActionKind, x: Double? = nil, y: Double? = nil, endX: Double? = nil, endY: Double? = nil, duration: Double? = nil, button: String? = nil, textFile: String? = nil) throws -> DeviceActionPayload {
        let geometry: DeviceActionGeometry?
        if let width, let height, let orientation { geometry = try DeviceActionGeometry(width: width, height: height, orientation: orientation) } else { geometry = nil }
        return try makeDeviceActionPayload(action: action, device: device, platform: platform, requestID: requestID, geometry: geometry, observationID: observationID, x: x, y: y, endX: endX, endY: endY, duration: duration, button: button, bundleID: bundleID, textFile: textFile, identifier: identifier, label: label)
    }
}

func emitDeviceActionOutput(_ output: Data) throws {
    let object = try JSONSerialization.jsonObject(with: output) as? [String: Any]
    print(String(decoding: output, as: UTF8.self))
    if object?["ok"] as? Bool != true || ["failed", "partial"].contains(object?["evidencePersistence"] as? String ?? "") {
        throw ExitCode.failure
    }
}

private func printDeviceActionResult(_ payload: DeviceActionPayload, common: DeviceActionCommonOptions) async throws {
    do {
        let output = try await executeDeviceAction(payload, common: common)
        try emitDeviceActionOutput(output)
    }
    catch let error as ExitCode { throw error }
    catch let error as DeviceActionError {
        let code: String
        switch error {
        case .generationStale: code = "device_action_generation_stale"
        case .invalidResult: code = "device_action_result_invalid"
        default: code = "device_action_invalid"
        }
        try failHostValidation(code: code, message: "\(error)", hint: "Refresh target/observation and use a supported platform action.", outputFormat: .json)
    }
    catch let error as ActionEvidenceFailure {
        try failHostValidation(code: error.code, message: "Cannot prepare a fresh private action evidence directory.", hint: "Use a new absolute output path under an existing directory.", outputFormat: .json)
    }
    catch { try failHostCommand(error, outputFormat: .json) }
}
extension DeviceTap { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DeviceDoubleTap { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DeviceSwipe { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DevicePress { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
extension DeviceType { mutating func run() async throws { try await printDeviceActionResult(payload(), common: common) } }
