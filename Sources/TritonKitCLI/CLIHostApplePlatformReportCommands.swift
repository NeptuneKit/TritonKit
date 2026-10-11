import ArgumentParser
import Foundation

struct DevicePlatforms: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "platforms", abstract: "Report Apple integration catalog and optional readonly available-Simulator OS-family counts, not control authorization")
    @Option(help: "Catalog filter only: ios|ipados|watchos|tvos|visionos|macos; not a new device control namespace") var applePlatform: HostApplePlatformFamily?
    @Flag(help: "Query available Simulator metadata once; no physical inventory or lifecycle actions. Independent of --include-real-devices; default zero host queries") var inventory = false
    @Flag(help: "Query CoreDevice list file JSON once for explicitly physical hardware metadata across Apple families; no actions") var includeRealDevices = false
    @Option(help: "Exact primary identifier or apple-physical inventory ID; requires --include-real-devices, metadata selection only") var device: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let output = try makeApplePlatformReport(inventory: inventory, family: applePlatform, includeRealDevices: includeRealDevices, device: device)
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text:
                for profile in output.profiles { print("\(profile.family.rawValue)\t\(profile.integrationState)\tcatalog-only; actionsAuthorized=false") }
                for value in output.physicalDevices { print("\(value.id)\t\(value.observation.systemFamily.rawValue)\t\(value.observation.deviceFamily.rawValue)\tmetadata-only") }
                if inventory { for count in output.simulatorCounts { print("available-simulator-metadata\t\(count.family.rawValue)\t\(count.count)") } }
            }
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
