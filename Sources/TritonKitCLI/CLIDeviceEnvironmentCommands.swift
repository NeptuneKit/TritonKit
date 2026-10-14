import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceEnvironmentOptions: ParsableArguments {
    @Option(help: "Explicit device selector or alias") var device: String
    @Option(help: "Platform adapter: ios|android|harmony") var platform: HostDevicePlatform?
    @Option(help: "Device scope: simulator|emulator|real|all") var scope: HostDeviceScope?
    @Option(help: "ADB executable") var adb: String = "adb"
    @Option(help: "HDC executable") var hdc: String = "hdc"
    @Option(help: "Private iOS Runner session root") var sessionRoot: String?
    @Option(help: "Operation timeout in seconds, 1...120") var timeout: Double = 30
    @Flag(help: "Emit JSON") var json = false
    @Option(help: "Output format: text|json") var format: ClientOutputFormat = .json
    mutating func validate() throws {
        guard !device.isEmpty, timeout.isFinite, (1...120).contains(timeout) else { throw ValidationError("Select an explicit device and timeout 1...120") }
    }
    func execute(_ operation: DeviceEnvironmentOperation, value: String? = nil, angle: Double? = nil) async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: platform, scope: scope, ready: true), hdc: hdc, adb: adb)
            if selection.platform == .ios && [.orientationGet, .orientationSet, .foreground].contains(operation) {
                // Public XCTest environment route. Never wrap its machine envelope a second time.
                let runnerOperation = operation == .foreground ? "foreground" : "orientation"
                var body: [String: Any] = ["operation": runnerOperation]
                if operation == .orientationSet { body["orientation"] = value }
                let runnerDevice = selection.target.scope == "simulator" ? "sim:\(selection.target.rawTarget)" : selection.target.id
                var payload: [String: Any] = ["device": runnerDevice, "timeout": timeout, "route": "/environment", "body": body]
                if let sessionRoot { payload["sessionRoot"] = sessionRoot }
                let data = try await Task.detached { try IOSRunnerService().execute(operation: "request", payload: JSONSerialization.data(withJSONObject: payload)) }.value
                print(String(decoding: data, as: UTF8.self))
                guard (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["ok"] as? Bool == true else { throw ExitCode.failure }
                return
            }
            let output = try makeDeviceEnvironmentOutput(target: selection.target, operation: operation, value: value, angle: angle, adb: adb, hdc: hdc)
            if outputFormat == .json { print(try encodeJSON(output)) }
            else { print("\(output.action): \(output.ok ? "ok" : output.error?.message ?? "failed")"); if let observed = output.observed { print(observed) } }
            if !output.ok { throw ExitCode.failure }
        } catch let exit as ExitCode { throw exit }
        catch {
            if outputFormat == .json {
                let failure = (error as? DeviceEnvironmentFailure) ?? DeviceEnvironmentFailure(code: "device_environment_failed", message: "Device environment operation failed; inspect device readiness and adapter diagnostics.")
                print(try encodeJSON(DeviceEnvironmentErrorEnvelope(ok: false, error: failure)))
            } else { print("Device environment operation failed: \(error)") }
            throw ExitCode.failure
        }
    }
}
private struct DeviceEnvironmentErrorEnvelope: Encodable { let ok: Bool; let error: DeviceEnvironmentFailure }
struct DeviceOrientation: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "orientation", abstract: "Read or configure device orientation", subcommands: [DeviceOrientationGet.self, DeviceOrientationSet.self])
}
struct DeviceOrientationGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get")
    @OptionGroup var options: DeviceEnvironmentOptions
    func run() async throws { try await options.execute(.orientationGet) }
}
struct DeviceOrientationSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set")
    @Argument var orientation: DeviceOrientationValue
    @OptionGroup var options: DeviceEnvironmentOptions
    func run() async throws { try await options.execute(.orientationSet, value: orientation.rawValue) }
}
struct DeviceFold: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "fold", abstract: "Set supported Android Emulator fold posture and hinge angle")
    @Argument var posture: DeviceFoldValue
    @Option(help: "Hinge angle in degrees, 0...180; defaults to posture angle") var angle: Double?
    @OptionGroup var options: DeviceEnvironmentOptions
    mutating func validate() throws { if let angle { guard angle.isFinite, (0...180).contains(angle) else { throw ValidationError("--angle must be 0...180") } } }
    func run() async throws { try await options.execute(.fold, value: posture.rawValue, angle: angle) }
}
struct DeviceLocation: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "location", abstract: "Configure simulated GPS without claiming App consumption", subcommands: [DeviceLocationSet.self, DeviceLocationClear.self])
}
struct DeviceLocationSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set")
    @Argument(help: "Latitude,longitude") var coordinate: String
    @OptionGroup var options: DeviceEnvironmentOptions
    mutating func validate() throws { guard isValidEnvironmentCoordinate(coordinate) else { throw ValidationError("Coordinate must be latitude,longitude in valid bounds") } }
    func run() async throws { try await options.execute(.locationSet, value: coordinate) }
}
struct DeviceLocationClear: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clear")
    @OptionGroup var options: DeviceEnvironmentOptions
    func run() async throws { try await options.execute(.locationClear) }
}
struct DeviceClipboard: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard", abstract: "Read or stage system clipboard; staging does not type or paste", subcommands: [DeviceClipboardGet.self, DeviceClipboardSet.self])
}
struct DeviceClipboardGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get")
    @OptionGroup var options: DeviceEnvironmentOptions
    func run() async throws { try await options.execute(.clipboardGet) }
}
struct DeviceClipboardSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set")
    @Argument(help: "Text to stage, max 64KiB") var text: String
    @OptionGroup var options: DeviceEnvironmentOptions
    mutating func validate() throws { guard text.utf8.count <= 65536 else { throw ValidationError("Clipboard text exceeds 64KiB") } }
    func run() async throws { try await options.execute(.clipboardSet, value: text) }
}
struct DeviceForeground: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "foreground", abstract: "Observe current foreground App identity with platform scope")
    @OptionGroup var options: DeviceEnvironmentOptions
    func run() async throws { try await options.execute(.foreground) }
}
