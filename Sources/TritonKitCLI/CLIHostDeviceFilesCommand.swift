import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceFiles: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "files", abstract: "List shallow Device Hub file metadata without copying file contents")
    @Option(help: "Currently ios only") var platform: HostDevicePlatform = .ios
    @Option(help: "Explicit or workspace device selector") var device: String?
    @Option(help: "simulator|real|all") var scope: HostDeviceScope?
    @Option(help: "appDataContainer|appGroupDataContainer|systemCrashLogs; temporary requires explicit possible-creation policy") var domainType: String
    @Option(help: "App bundle/group identifier; omitted for crash logs") var domainIdentifier: String?
    @Option(help: "Domain-relative directory; omitted or dot selects root") var subdirectory: String?
    @Option(help: "Device username when required by the domain") var username: String?
    @Option(help: "Positive finite timeout for the readonly files query") var timeout: Double?
    @Option(help: "Local JSON acceptance bytes, 1...16777216; not a remote disk limit") var maxJSONBytes: Int = 1_048_576
    @Option(help: "Local entry acceptance count, 1...10000; rejects rather than truncates") var maxEntries: Int = 1000
    @Flag(help: "Include private filename/relative-path metadata; never file contents or raw device IDs") var includeSensitive = false
    @Flag(help: "Explicitly authorize possible temporary domain creation") var allowDomainCreation = false
    @Flag(help: "Confirm temporary query side effects") var confirm = false
    @Flag(help: "Execute the explicitly authorized temporary query") var executeRunner = false
    @Option(help: "Required durable audit reference for temporary query") var auditRecord: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            guard platform == .ios, scope != .emulator else { throw HostDeviceFilesError.unsupportedPlatform }
            let hasPolicy = allowDomainCreation || confirm || executeRunner || auditRecord != nil
            let policy = HostTemporaryDomainPolicy(allowDomainCreation: allowDomainCreation, confirm: confirm, executeRunner: executeRunner, auditRecord: auditRecord)
            if domainType == "temporary" { try policy.validate() }
            else if hasPolicy { throw HostDeviceSelectionError.parameterConflict("Creation policy is only valid with temporary.") }
            let request = try TKDevicectlFilesRequest(domain: domainType, domainIdentifier: domainIdentifier, subdirectory: subdirectory, username: username, allowTemporaryCreation: domainType == "temporary")
            try validateDeviceFilesLimits(timeout: timeout, maximumJSONBytes: maxJSONBytes, maximumEntries: maxEntries)
            let selection = try resolveHostDeviceSelection(request: HostDeviceSelectionRequest(device: device, platform: platform, scope: scope), hdc: "hdc", adb: "adb")
            let output = try makeIOSDeviceFilesOutput(selection: selection, request: request, includeSensitive: includeSensitive, timeout: timeout, maximumJSONBytes: maxJSONBytes, maximumEntries: maxEntries, temporaryPolicy: domainType == "temporary" ? policy : nil)
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text:
                print("\(output.target.target)\t\(output.domain)\t\(output.count) shallow entries")
                for entry in output.entries { print("\(entry.token)\t\(entry.kind)\t\(entry.sizeBytes.map(String.init) ?? "unknown")\t\(entry.relativePath ?? "[private]")") }
            }
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
