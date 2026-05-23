import ArgumentParser
import TritonKitShared

// MARK: - Simulator Device Maintenance Commands

struct SimPair: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pair", abstract: "Create a watch and phone simulator pair")

    @Argument(help: "Watch simulator UDID") var watchDevice: String
    @Argument(help: "Phone simulator UDID") var phoneDevice: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.pair",
            target: "sim-pair:\(watchDevice)+\(phoneDevice)",
            command: TKSimctlCommand.pair(watchDevice: watchDevice, phoneDevice: phoneDevice),
            outputFormat: effectiveFormat(format, json: json),
            note: "Watch and phone simulator pair creation was requested."
        )
    }
}

struct SimUnpair: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unpair", abstract: "Unpair a watch and phone simulator pair")

    @Argument(help: "Device pair UUID") var pairUUID: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.unpair",
            target: "sim-pair:\(pairUUID)",
            command: TKSimctlCommand.unpair(pairUUID: pairUUID),
            outputFormat: effectiveFormat(format, json: json),
            note: "Watch and phone simulator pair removal was requested."
        )
    }
}

struct SimClone: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clone", abstract: "Clone an existing simulator device")

    @Argument(help: "Source simulator UDID") var device: String
    @Argument(help: "New simulator name") var newName: String
    @Argument(help: "Destination device set path") var destinationDeviceSet: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.clone",
            target: "sim:\(device)",
            command: TKSimctlCommand.clone(device: device, newName: newName, destinationDeviceSet: destinationDeviceSet),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator clone was requested."
        )
    }
}

struct SimErase: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "erase", abstract: "Erase a simulator's contents and settings")

    @Argument(help: "Simulator UDID or booted") var simulator: String
    @Flag(help: "Required break-glass acknowledgement for erasing simulator contents") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireConfirmation(
            confirm,
            action: "sim erase",
            hint: "Erase deletes simulator contents and settings. Re-run with --confirm only for an intentional reset.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.erase",
            target: "sim:\(simulator)",
            command: TKSimctlCommand.erase(udid: simulator),
            outputFormat: outputFormat,
            note: "Simulator erase was requested."
        )
    }
}

struct SimUpgrade: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "upgrade", abstract: "Upgrade a simulator to a newer runtime")

    @Argument(help: "Simulator UDID") var device: String
    @Argument(help: "Runtime identifier") var runtimeIdentifier: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.upgrade",
            target: "sim:\(device)/runtime:\(runtimeIdentifier)",
            command: TKSimctlCommand.upgrade(device: device, runtimeIdentifier: runtimeIdentifier),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator runtime upgrade was requested."
        )
    }
}

// MARK: - Simulator Runtime Maintenance Commands

struct SimRuntime: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runtime",
        abstract: "Inspect simulator runtime maintenance state",
        subcommands: [
            SimRuntimeList.self,
            SimRuntimeVerify.self,
            SimRuntimeAdd.self,
            SimRuntimeDelete.self,
            SimRuntimeUnmount.self,
            SimRuntimeScanAndMount.self,
            SimRuntimeMatch.self,
            SimRuntimeDyldCache.self,
        ]
    )
}

struct SimRuntimeList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List installed simulator runtimes")

    @Flag(help: "Include verbose runtime details") var verbose = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try runHostCommand(TKSimctlCommand.runtimeList(verbose: verbose))
            let runtimes = try TKSimctlRuntimeListParser.parse(result.stdoutData)
            let output = HostSimulatorRuntimeListOutput(
                ok: true,
                runtimes: runtimes,
                count: runtimes.count,
                verbose: verbose,
                sourceCommand: result.sourceCommand
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for runtime in runtimes {
                    print("\(runtime.identifier)\t\(runtime.state)\t\(runtime.version)\t\(runtime.kind)")
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimRuntimeVerify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Verify a simulator runtime signature")

    @Argument(help: "Runtime identifier") var identifier: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.runtime.verify",
            target: "runtime:\(identifier)",
            command: TKSimctlCommand.runtimeVerify(identifier: identifier),
            outputFormat: effectiveFormat(format, json: json),
            note: "Runtime signature verification was requested."
        )
    }
}

struct SimRuntimeAdd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a simulator runtime disk image")

    @Argument(help: "Runtime disk image path") var path: String
    @Flag(help: "Remove the source file if add succeeds") var move = false
    @Flag(name: .customLong("async"), help: "Print the new image UUID then exit without waiting") var asyncMode = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.runtime.add",
            target: "runtime-image:\(path)",
            command: TKSimctlCommand.runtimeAdd(path: path, move: move, async: asyncMode),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator runtime add was requested."
        )
    }
}

struct SimRuntimeDelete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete simulator runtime images")

    @Argument(help: "Runtime identifier or all") var identifier: String?
    @Option(name: .customLong("not-used-since-days"), help: "Delete runtimes not used within this many days") var notUsedSinceDays: Int?
    @Flag(help: "Print runtimes that would be deleted without deleting them") var dryRun = false
    @Flag(help: "Keep the associated mobile asset") var keepAsset = false
    @Flag(help: "Required acknowledgement for deleting runtimes") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireExactlyOneSelector(
            selected: [identifier != nil, notUsedSinceDays != nil].filter { $0 }.count,
            code: "runtime_delete_selector_required",
            message: "runtime delete requires exactly one selector.",
            hint: "Pass a runtime identifier, all, or --not-used-since-days <days>.",
            outputFormat: outputFormat
        )
        if !dryRun {
            try requireConfirmation(
                confirm,
                action: "sim runtime delete",
                hint: "Run with --dry-run first. Re-run with --confirm only when deletion is intentional.",
                outputFormat: outputFormat
            )
        }
        try runSimpleHostCommand(
            action: "sim.runtime.delete",
            target: identifier.map { "runtime:\($0)" } ?? "runtime:not-used-since-days:\(notUsedSinceDays ?? 0)",
            command: TKSimctlCommand.runtimeDelete(identifier: identifier, notUsedSinceDays: notUsedSinceDays, dryRun: dryRun, keepAsset: keepAsset),
            outputFormat: outputFormat,
            note: dryRun ? "Simulator runtime delete dry run was requested." : "Simulator runtime delete was requested."
        )
    }
}

struct SimRuntimeUnmount: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unmount", abstract: "Unmount a simulator runtime disk image")

    @Argument(help: "Runtime identifier") var identifier: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.runtime.unmount",
            target: "runtime:\(identifier)",
            command: TKSimctlCommand.runtimeUnmount(identifier: identifier),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator runtime unmount was requested."
        )
    }
}

struct SimRuntimeScanAndMount: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scan-and-mount", abstract: "Scan runtime storage and mount orphaned runtimes")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.runtime.scan-and-mount",
            target: "runtime:storage",
            command: TKSimctlCommand.runtimeScanAndMount(),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator runtime scan-and-mount was requested."
        )
    }
}

struct SimRuntimeMatch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "match",
        abstract: "Read or override SDK-to-runtime build matching",
        subcommands: [SimRuntimeMatchList.self, SimRuntimeMatchSet.self]
    )
}

struct SimRuntimeMatchList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List SDK-to-runtime build matching rules")

    @Flag(help: "Include verbose matching details") var verbose = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.runtime.match.list",
            target: "runtime-match:all",
            command: TKSimctlCommand.runtimeMatchList(verbose: verbose),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator runtime match rules were read."
        )
    }
}

struct SimRuntimeMatchSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Override SDK-to-runtime build matching")

    @Argument(help: "SDK canonical name") var sdkName: String
    @Argument(help: "Runtime build to prefer") var runtimeBuild: String?
    @Flag(name: .customLong("default"), help: "Clear the override and revert to default matching") var useDefault = false
    @Option(name: .customLong("sdk-build"), help: "SDK build for an Xcode other than the selected Xcode") var sdkBuild: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireExactlyOneSelector(
            selected: [runtimeBuild != nil, useDefault].filter { $0 }.count,
            code: "runtime_match_selector_required",
            message: "runtime match set requires either a runtime build or --default.",
            hint: "Pass `triton sim runtime match set <sdk> <runtime-build>` or `triton sim runtime match set <sdk> --default`.",
            outputFormat: outputFormat
        )
        let command = useDefault
            ? TKSimctlCommand.runtimeMatchSetDefault(sdkName: sdkName, sdkBuild: sdkBuild)
            : TKSimctlCommand.runtimeMatchSet(sdkName: sdkName, runtimeBuild: runtimeBuild ?? "", sdkBuild: sdkBuild)
        try runSimpleHostCommand(
            action: useDefault ? "sim.runtime.match.default" : "sim.runtime.match.set",
            target: "runtime-match:\(sdkName)",
            command: command,
            outputFormat: outputFormat,
            note: "Simulator runtime match override was requested."
        )
    }
}

struct SimRuntimeDyldCache: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dyld-cache",
        abstract: "Update or remove simulator runtime dyld shared caches",
        subcommands: [SimRuntimeDyldCacheUpdate.self, SimRuntimeDyldCacheRemove.self]
    )
}

struct SimRuntimeDyldCacheUpdate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "update", abstract: "Update simulator runtime dyld shared cache")

    @Argument(help: "Runtime identifier") var runtime: String?
    @Flag(help: "Update all runtime dyld shared caches") var all = false
    @Flag(help: "Force re-creation if the cache exists") var force = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireExactlyOneSelector(
            selected: [runtime != nil, all].filter { $0 }.count,
            code: "runtime_dyld_cache_selector_required",
            message: "dyld-cache update requires a runtime identifier or --all.",
            hint: "Pass `triton sim runtime dyld-cache update <runtime>` or `--all`.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.runtime.dyld-cache.update",
            target: all ? "runtime:all" : "runtime:\(runtime ?? "")",
            command: TKSimctlCommand.runtimeDyldSharedCacheUpdate(runtime: runtime, all: all, force: force),
            outputFormat: outputFormat,
            note: "Simulator runtime dyld shared cache update was requested."
        )
    }
}

struct SimRuntimeDyldCacheRemove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove simulator runtime dyld shared cache")

    @Argument(help: "Runtime identifier") var runtime: String?
    @Flag(help: "Remove all runtime dyld shared caches") var all = false
    @Flag(help: "Required acknowledgement for removing dyld shared caches") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireExactlyOneSelector(
            selected: [runtime != nil, all].filter { $0 }.count,
            code: "runtime_dyld_cache_selector_required",
            message: "dyld-cache remove requires a runtime identifier or --all.",
            hint: "Pass `triton sim runtime dyld-cache remove <runtime>` or `--all`.",
            outputFormat: outputFormat
        )
        try requireConfirmation(
            confirm,
            action: "sim runtime dyld-cache remove",
            hint: "Re-run with --confirm only when dyld shared cache removal is intentional.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.runtime.dyld-cache.remove",
            target: all ? "runtime:all" : "runtime:\(runtime ?? "")",
            command: TKSimctlCommand.runtimeDyldSharedCacheRemove(runtime: runtime, all: all),
            outputFormat: outputFormat,
            note: "Simulator runtime dyld shared cache removal was requested."
        )
    }
}

// MARK: - Simulator Personalization Commands

struct SimPersonalization: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "personalization",
        abstract: "Manage simulator runtime personalization manifests",
        subcommands: [
            SimPersonalizationPersonalize.self,
            SimPersonalizationRemoveManifest.self,
            SimPersonalizationRemoveAllManifests.self,
            SimPersonalizationRemovePersonalization.self,
            SimPersonalizationRevokeManifests.self,
            SimPersonalizationScanAndPersonalize.self,
        ]
    )
}

struct SimPersonalizationPersonalize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "personalize", abstract: "Generate a new personalization manifest for a runtime")

    @Argument(help: "Runtime identifier") var identifier: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.personalization.personalize",
            target: "runtime:\(identifier)",
            command: TKSimctlCommand.personalization(action: "personalize", arguments: [identifier], riskLevel: .automation),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator runtime personalization was requested."
        )
    }
}

struct SimPersonalizationRemoveManifest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove-manifest", abstract: "Remove a personalization manifest file")

    @Argument(help: "Manifest filename") var filename: String
    @Flag(help: "Required acknowledgement for removing a manifest") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireConfirmation(
            confirm,
            action: "sim personalization remove-manifest",
            hint: "Re-run with --confirm only when removing this personalization manifest is intentional.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.personalization.remove-manifest",
            target: "personalization-manifest:\(filename)",
            command: TKSimctlCommand.personalization(action: "remove-manifest", arguments: [filename], riskLevel: .breakGlass),
            outputFormat: outputFormat,
            note: "Simulator personalization manifest removal was requested."
        )
    }
}

struct SimPersonalizationRemoveAllManifests: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove-all-manifests", abstract: "Remove all personalization manifests")

    @Flag(help: "Required acknowledgement for removing all manifests") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireConfirmation(
            confirm,
            action: "sim personalization remove-all-manifests",
            hint: "Re-run with --confirm only when removing all personalization manifests is intentional.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.personalization.remove-all-manifests",
            target: "personalization-manifest:all",
            command: TKSimctlCommand.personalization(action: "remove-all-manifests", riskLevel: .breakGlass),
            outputFormat: outputFormat,
            note: "Removal of all simulator personalization manifests was requested."
        )
    }
}

struct SimPersonalizationRemovePersonalization: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove-personalization", abstract: "Remove runtime personalization and remount it")

    @Argument(help: "Personalization identifier") var identifier: String
    @Flag(help: "Required acknowledgement for removing personalization") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireConfirmation(
            confirm,
            action: "sim personalization remove-personalization",
            hint: "Re-run with --confirm only when removing runtime personalization is intentional.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.personalization.remove-personalization",
            target: "personalization:\(identifier)",
            command: TKSimctlCommand.personalization(action: "remove-personalization", arguments: [identifier], riskLevel: .breakGlass),
            outputFormat: outputFormat,
            note: "Simulator runtime personalization removal was requested."
        )
    }
}

struct SimPersonalizationRevokeManifests: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "revoke-manifests", abstract: "Revoke personalization manifests")

    @Flag(help: "Required acknowledgement for revoking manifests") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        try requireConfirmation(
            confirm,
            action: "sim personalization revoke-manifests",
            hint: "Re-run with --confirm only when forcing all runtime cryptex mounts to be re-personalized is intentional.",
            outputFormat: outputFormat
        )
        try runSimpleHostCommand(
            action: "sim.personalization.revoke-manifests",
            target: "personalization-manifest:all",
            command: TKSimctlCommand.personalization(action: "revoke-manifests", riskLevel: .breakGlass),
            outputFormat: outputFormat,
            note: "Simulator personalization manifest revocation was requested."
        )
    }
}

struct SimPersonalizationScanAndPersonalize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scan-and-personalize", abstract: "Scan runtimes and update personalization manifests")

    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runSimpleHostCommand(
            action: "sim.personalization.scan-and-personalize",
            target: "runtime:storage",
            command: TKSimctlCommand.personalization(action: "scan-and-personalize", riskLevel: .automation),
            outputFormat: effectiveFormat(format, json: json),
            note: "Simulator personalization scan-and-personalize was requested."
        )
    }
}
