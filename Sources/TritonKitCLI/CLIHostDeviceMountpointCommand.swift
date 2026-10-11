import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceMountpoint: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "mountpoint", abstract: "Query a private DeviceFS mountpoint reference without filesystem traversal")
    @Option(help: "Currently ios only") var platform: HostDevicePlatform = .ios
    @Option(help: "Explicit or workspace device selector") var device: String?
    @Option(help: "simulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Positive finite timeout for the information query") var timeout: Double?
    @Flag(help: "Explicitly authorize possible native mount creation") var allowMount = false
    @Flag(help: "Confirm native mount side effects") var confirm = false
    @Flag(help: "Execute the native mountpoint query") var executeRunner = false
    @Option(help: "Required durable audit reference") var auditRecord: String?
    @Option(help: "Local JSON acceptance bytes, 1...16777216; not a remote hard limit") var maxJSONBytes: Int = 1_048_576
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .ios, scope != .emulator else { throw HostDeviceMountpointError.unsupportedPlatform }
            try validateDeviceMountpointLimits(timeout: timeout, maximumJSONBytes: maxJSONBytes)
            let policy = HostDeviceMountPolicy(allowMount: allowMount, confirm: confirm, executeRunner: executeRunner, auditRecord: auditRecord)
            try policy.validate()
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: platform, scope: scope), hdc: "hdc", adb: "adb")
            let output = try withDeviceMountAudit(policy: policy, action: "device.mountpoint", target: selection.target.id) { audit in
                try audit.beforeNativeExecution()
                return try makeIOSDeviceMountpointOutput(selection: selection, mountPolicy: policy, timeout: timeout, maximumJSONBytes: maxJSONBytes)
            }
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text: print("\(output.target.target)\t\(output.mountpointToken)\tpath private; filesystem not inspected")
            }
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
