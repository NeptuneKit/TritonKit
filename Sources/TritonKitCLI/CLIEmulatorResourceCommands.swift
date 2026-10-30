import ArgumentParser
import Foundation

extension EmulatorResourcePlatform: ExpressibleByArgument {}

struct DeviceResource: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resource",
        abstract: "Inspect, disable and restore optional Android/Harmony emulator features",
        subcommands: [DeviceResourceProfiles.self, DeviceResourceFeatures.self, DeviceResourceStatus.self,
                      DeviceResourceDoctor.self, DeviceResourcePlan.self, DeviceResourceApply.self,
                      DeviceResourceVerify.self, DeviceResourceRestore.self, DeviceResourceMeasure.self]
    )
}

struct EmulatorResourceCommandOptions: ParsableArguments {
    @Option(help: "Local emulator platform: android|harmony") var platform: EmulatorResourcePlatform
    @Option(help: "ADB executable") var adb = "adb"
    @Option(help: "HDC executable") var hdc = "hdc"
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text|json") var format: ClientOutputFormat = .json
    var outputFormat: ClientOutputFormat { effectiveFormat(format, json: json) }
}

struct EmulatorResourceSelectionOptions: ParsableArguments {
    @Option(help: "Feature profile: stock|ui-minimal|custom") var profile = "ui-minimal"
    @Option(help: "Comma-separated feature IDs to disable in addition to the profile") var disable: String?
    @Option(help: "Comma-separated feature IDs to preserve") var keep: String?
}

/// Emit once, then exit. Keeping the exit outside the catch avoids nested JSON errors.
func runEmulatorResourceCommand(
    _ action: String, options: EmulatorResourceCommandOptions, device: String? = nil,
    selection: EmulatorResourceSelectionOptions? = nil, receipt: String? = nil, confirm: Bool = false
) throws {
    let output: EmulatorResourceOutput
    do {
        output = try EmulatorResourceCLI.execute(
            action: action, platform: options.platform, device: device, adb: options.adb, hdc: options.hdc,
            profile: selection?.profile ?? "ui-minimal", disable: selection?.disable, keep: selection?.keep,
            receipt: receipt, confirm: confirm
        )
    } catch let error as EmulatorResourceError {
        output = .failure(action: action, platform: options.platform, error: error)
    } catch let exit as ExitCode {
        throw exit
    } catch {
        output = .failure(action: action, platform: options.platform,
                          error: EmulatorResourceError("resource_failed", "Resource operation could not complete"))
    }
    try EmulatorResourceCLI.printOutput(output, format: options.outputFormat)
    if !output.ok { throw ExitCode.failure }
}

struct DeviceResourceProfiles: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "profiles", abstract: "List available resource profiles")
    @OptionGroup var options: EmulatorResourceCommandOptions
    func run() async throws { try runEmulatorResourceCommand("profiles", options: options) }
}

struct DeviceResourceFeatures: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "features", abstract: "List feature switches and their functional impact")
    @OptionGroup var options: EmulatorResourceCommandOptions
    func run() async throws { try runEmulatorResourceCommand("features", options: options) }
}

struct DeviceResourceStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Read current managed feature states")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    func run() async throws { try runEmulatorResourceCommand("status", options: options, device: device) }
}

struct DeviceResourceDoctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Check emulator identity and feature-control availability")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    func run() async throws { try runEmulatorResourceCommand("doctor", options: options, device: device) }
}

struct DeviceResourcePlan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "plan", abstract: "Preview feature changes without applying them")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @OptionGroup var selection: EmulatorResourceSelectionOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    func run() async throws { try runEmulatorResourceCommand("plan", options: options, device: device, selection: selection) }
}

struct DeviceResourceApply: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply", abstract: "Apply confirmed feature changes with a durable recovery receipt")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @OptionGroup var selection: EmulatorResourceSelectionOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    @Option(help: "New recovery receipt path in an existing private directory") var receipt: String
    @Flag(help: "Confirm the reviewed feature changes") var confirm = false
    func run() async throws { try runEmulatorResourceCommand("apply", options: options, device: device, selection: selection, receipt: receipt, confirm: confirm) }
}

struct DeviceResourceVerify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Compare current feature states with a receipt")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    @Option(help: "Existing resource recovery receipt") var receipt: String
    func run() async throws { try runEmulatorResourceCommand("verify", options: options, device: device, receipt: receipt) }
}

struct DeviceResourceRestore: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "restore", abstract: "Restore receipt-owned changes while preserving later user changes")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    @Option(help: "Existing resource recovery receipt") var receipt: String
    @Flag(help: "Confirm restoration of receipt-owned feature changes") var confirm = false
    func run() async throws { try runEmulatorResourceCommand("restore", options: options, device: device, receipt: receipt, confirm: confirm) }
}

struct DeviceResourceMeasure: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "measure", abstract: "Measure managed guest process memory; guest PSS is not host savings")
    @OptionGroup var options: EmulatorResourceCommandOptions
    @Option(help: "Explicit local emulator target; aliases are not accepted") var device: String
    func run() async throws { try runEmulatorResourceCommand("measure", options: options, device: device) }
}
