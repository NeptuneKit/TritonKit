import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "info", abstract: "Read Device Hub device properties and optionally probe passcode state")

    @Option(help: "Platform adapter, currently ios only") var platform: HostDevicePlatform = .ios
    @Option(help: "Device selector: alias, sim:<udid>, ios-real:<hash>, raw id, booted, or current") var device: String?
    @Option(help: "Discovery scope: simulator|real|all; omitted infers scope from a typed selector") var scope: HostDeviceScope?
    @Flag(help: "Also execute the readonly lockState query; does not unlock the device") var lockState = false
    @Option(help: "Positive finite timeout for each readonly query in seconds") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .ios, scope != .emulator else { throw HostDeviceInfoError.unsupportedPlatform }
            if let timeout, !timeout.isFinite || timeout <= 0 {
                throw HostDeviceSelectionError.parameterConflict("Device info timeout must be finite and greater than zero.")
            }
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: platform, scope: scope), hdc: "hdc", adb: "adb")
            let output = try makeIOSDeviceInfoOutput(selection: selection, includeLockState: lockState, timeout: timeout)
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text:
                print("\(output.target.target)\t\(output.target.state)\t\(output.target.runtime ?? "unknown")\t\(output.hardware.marketingName ?? output.target.name ?? "unknown")")
                if lockState {
                    print("passcodeRequired=\(output.lockState.passcodeRequired.map(String.init) ?? "unknown") unlockedSinceBoot=\(output.lockState.unlockedSinceBoot.map(String.init) ?? "unknown")")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
