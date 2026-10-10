import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceAdministrationOptions: ParsableArguments {
    @Option(help: "Only ios host adapter currently") var platform: HostDevicePlatform = .ios
    @Option(help: "Explicit fresh-discovered real device selector, no automatic fleet/default") var device: String?
    @Option(help: "Only real scope, distinct from sim pair/unpair/diagnose") var scope: HostDeviceScope = .real
    @Flag(help: "Required: policy review only; never executes administration") var planOnly = false
    @Option(help: "diagnose only: private ZIP destination, not inspected/created or overwrite-safe here") var output: String?
    @Option(help: "Positive finite planned action timeout; native action not run") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
}
struct DevicePair: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pair", abstract: "Plan real-device pairing without changing trust")
    @OptionGroup var options: DeviceAdministrationOptions
    func run() async throws { try emitDeviceAdministrationPlan(operation: .pair, options: options) }
}
struct DeviceUnpair: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unpair", abstract: "Plan manually-paired device unpairing; never execute")
    @OptionGroup var options: DeviceAdministrationOptions
    func run() async throws { try emitDeviceAdministrationPlan(operation: .unpair, options: options) }
}
struct DeviceDiagnose: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "diagnose", abstract: "Plan sensitive single-device/local-host diagnostics; never collect")
    @OptionGroup var options: DeviceAdministrationOptions
    func run() async throws { try emitDeviceAdministrationPlan(operation: .diagnose, options: options) }
}
func emitDeviceAdministrationPlan(operation: DeviceAdministrationOperation, options: DeviceAdministrationOptions) throws {
    let format = effectiveFormat(options.format, json: options.json)
    do {
        let output = try makeDeviceAdministrationPlan(operation: operation, options: options)
        switch format {
        case .json: print(try encodeJSON(output))
        case .text: print("\(output.action)\t\(output.target)\tpolicy plan only; executable=false; supported=\(output.commandSupport.supported)")
        }
    } catch { try failHostCommand(error, outputFormat: format) }
}
