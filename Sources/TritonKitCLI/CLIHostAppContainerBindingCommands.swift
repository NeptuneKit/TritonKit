import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceContainers: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "containers", abstract: "Query SDK explicit app/group container binding; optional native Simulator shallow metadata, no content")
    @Option(help: "Exact private application bundle identifier; never display name or container directory guess") var bundleId: String
    @Option(help: "Exact private App Group ID; requires SDK membership and group path mapping") var groupId: String?
    @Flag(help: "List shallow metadata only for a bound native CoreSimulator container; real-device listing unsupported") var list = false
    @Option(help: "Currently ios only") var platform: HostDevicePlatform = .ios
    @Option(help: "Explicit or workspace device selector") var device: String?
    @Option(help: "simulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Positive finite query timeout; not a filesystem syscall deadline") var timeout: Double?
    @Option(help: "Local file-JSON acceptance bytes, 1...16777216") var maxJSONBytes: Int = 1_048_576
    @Option(help: "Local accepted shallow entries, 1...10000; never truncate") var maxEntries: Int = 1000
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .ios, scope != .emulator else { throw HostAppContainerBindingError.unsupportedPlatform }
            try validateAppContainerBindingRequest(bundleIdentifier: bundleId, groupIdentifier: groupId, timeout: timeout, maximumJSONBytes: maxJSONBytes, maximumEntries: maxEntries)
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: platform, scope: scope), hdc: "hdc", adb: "adb")
            let output = try makeAppContainerBindingOutput(selection: selection, bundleIdentifier: bundleId, groupIdentifier: groupId, list: list, timeout: timeout, maximumJSONBytes: maxJSONBytes, maximumEntries: maxEntries)
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text: print("\(output.bindingStatus)\t\(output.containerKind)\t\(output.count) shallow entries; contents not read")
            }
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
