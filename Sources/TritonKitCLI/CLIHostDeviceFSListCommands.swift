import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceFS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "fs", abstract: "Explicit DeviceFS metadata backend, separate from device files", subcommands: [DeviceFSList.self])
}
struct DeviceFSList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List bound namespace or explicit container-relative directory shallow metadata, never contents")
    @Option(help: "mount-root|app-data-containers|app-group-containers; fixed namespaces, not verified bundle/group identity") var view: DeviceFSView = .mountRoot
    @Option(help: "Private native container directory name: one component, app-data/app-group views only; not a path or verified bundle/group identity") var containerIdentifier: String?
    @Option(help: "Private relative directory inside explicit container only; 1...32 components, <=4096 UTF8 bytes, each 1...255 bytes, no dot/dotdot/empty/slash-empty/control; never normalized or URL-decoded") var subdirectory: String?
    @Option(help: "Currently ios only") var platform: HostDevicePlatform = .ios
    @Option(help: "Explicit or workspace device selector") var device: String?
    @Option(help: "simulator|real|all") var scope: HostDeviceScope?
    @Option(help: "Positive finite mountpoint query timeout; not a FUSE syscall deadline") var timeout: Double?
    @Option(help: "Local mountpoint JSON acceptance bytes, 1...16777216") var maxJSONBytes: Int = 1_048_576
    @Option(help: "Local accepted directory entries, 1...10000; reject rather than truncate") var maxEntries: Int = 1000
    @Flag(help: "Include listed entry names only; never selected scope fields, contents, owner, xattrs or native path") var includeSensitive = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .ios, scope != .emulator else { throw HostDeviceFSError.unsupportedPlatform }
            try validateDeviceFilesLimits(timeout: timeout, maximumJSONBytes: maxJSONBytes, maximumEntries: maxEntries)
            let relative = try deviceFSRelativeDirectory(view: view, containerIdentifier: containerIdentifier, subdirectory: subdirectory)
            try validateDeviceFSSelectionBudget(homeDirectory: NSHomeDirectory(), relativeDirectory: relative)
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: platform, scope: scope), hdc: "hdc", adb: "adb")
            let output = try makeIOSDeviceFSListOutput(selection: selection, view: view, containerIdentifier: containerIdentifier, subdirectory: subdirectory, includeSensitive: includeSensitive, timeout: timeout, maximumJSONBytes: maxJSONBytes, maximumEntries: maxEntries)
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text: print("\(output.target.target)\t\(output.count) \(output.view) metadata entries; contents not read")
            }
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
