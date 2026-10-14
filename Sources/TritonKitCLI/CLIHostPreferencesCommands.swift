import ArgumentParser
import Foundation
import TritonKitShared

struct HostAppPrefs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prefs",
        abstract: "Read and update simulator app preferences as JSON",
        subcommands: [HostAppPrefsDump.self, HostAppPrefsGet.self, HostAppPrefsSet.self, HostAppPrefsImport.self]
    )
}

struct HostAppPrefsDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "dump", abstract: "Dump app preferences")

    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try printPreferences(simulator: selection.target.target, bundleID: bundleID, key: nil, outputFormat: outputFormat)
        } catch let exit as ExitCode { throw exit }
        catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}

struct HostAppPrefsGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read one app preference value")

    @Argument(help: "Preference key") var key: String
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try printPreferences(simulator: selection.target.target, bundleID: bundleID, key: key, outputFormat: outputFormat)
        } catch let exit as ExitCode { throw exit }
        catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}

struct HostAppPrefsSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set one simulator app preference value")

    @Argument(help: "Preference key") var key: String
    @Argument(help: "JSON value to write when --type json is used") var value: String?
    @Option(help: "Preference value type: json or data") var type: HostPreferenceSetType = .json
    @Option(help: "Base64 payload when --type data is used") var base64: String?
    @Option(help: "Hex payload when --type data is used") var hex: String?
    @Option(help: "Unified host device selector: alias, sim:<udid>, raw id, booted, or current") var device: String?
    @Option(help: "Explicit iOS simulator selector: UDID or booted") var simulator: String?
    @Option(help: "Device name filter, for example iPhone 15") var name: String?
    @Option(help: "Runtime filter, for example iOS 26.5") var runtime: String?
    @Option(help: "Target state filter, for example booted") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Terminate and relaunch after verified disk write") var relaunch = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostAppDeviceSelection(
                device: device,
                platform: .ios,
                defaultPlatform: .ios,
                scope: nil,
                simulator: simulator,
                target: nil,
                name: name,
                runtime: runtime,
                state: state,
                ready: ready,
                hdc: "hdc"
            )
            try setPreference(
                simulator: selection.target.target,
                bundleID: bundleID,
                key: key,
                value: value,
                type: type,
                base64: base64,
                hex: hex,
                relaunch: relaunch,
                outputFormat: outputFormat
            )
        } catch let exit as ExitCode { throw exit }
        catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}


struct HostAppPrefsImport: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "import", abstract: "Merge explicitly selected keys from JSON or plist into bundle app-data preferences")
    @Option(help: "Input JSON or plist file (up to 1MiB)") var input: String
    @Option(help: "Input format: json or plist") var inputFormat: HostPreferencesImportFormat = .json
    @Option(name: .customLong("key"), help: "Explicit key allowlist; repeat for each selected key") var keys: [String] = []
    @Option(help: "Unified host simulator selector") var device: String?
    @Option(help: "Explicit iOS simulator selector") var simulator: String?
    @Option(help: "Device name filter") var name: String?
    @Option(help: "Runtime filter") var runtime: String?
    @Option(help: "Target state filter") var state: String?
    @Flag(help: "Only match ready targets") var ready = false
    @Option(help: "App bundle identifier") var bundleID: String
    @Flag(help: "Terminate and relaunch after verified disk write") var relaunch = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let data = try SimulatorResourceReceiptReader.readData(input)
            // Preflight the complete package before target discovery or writing.
            _ = try parseHostPreferenceImport(data: data, format: inputFormat, keys: keys)
            let selection = try resolveHostAppDeviceSelection(device: device, platform: .ios, defaultPlatform: .ios, scope: nil,
                simulator: simulator, target: nil, name: name, runtime: runtime, state: state, ready: ready, hdc: "hdc")
            let output = try importHostPreferences(simulator: selection.target.target, bundleID: bundleID, inputData: data,
                inputFormat: inputFormat, keys: keys, relaunch: relaunch,
                pathProvider: { try resolveHostPreferencesPath(simulator: selection.target.target, bundleID: bundleID) })
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text: print("Imported \(output.importedKeys.count) keys; relaunch \(output.relaunch.status).")
            }
            if !output.ok { throw ExitCode.failure }
        } catch let exit as ExitCode { throw exit }
        catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
