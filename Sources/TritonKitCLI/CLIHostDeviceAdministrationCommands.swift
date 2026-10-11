import ArgumentParser
import Foundation
import TritonKitShared

struct DeviceAdministrationOptions: ParsableArguments {
    @Option(help: "Only ios host adapter currently") var platform: HostDevicePlatform = .ios
    @Option(help: "Explicit fresh-discovered real device selector, no automatic fleet/default") var device: String?
    @Option(help: "Only real scope, distinct from sim pair/unpair/diagnose") var scope: HostDeviceScope = .real
    @Flag(help: "Policy review only; mutually exclusive with execution authorization") var planOnly = false
    @Flag(help: "Explicitly authorize one native administration execution") var executeRunner = false
    @Flag(help: "Confirm trust changes or sensitive device and host diagnostic collection") var confirm = false
    @Option(help: "Required durable local audit correlation id for execution") var auditRecord: String?
    @Option(help: "Maximum accepted diagnostic ZIP bytes, 1...1073741824; not native peak disk budget") var maximumArchiveBytes: Int = 268_435_456
    @Option(help: "diagnose only: private ZIP destination; execution requires existing owner-only parent and refuses overwrite/symlinks") var output: String?
    @Option(help: "Positive finite per-command timeout; timeout may leave partial device effects") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
}
struct DevicePair: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pair", abstract: "Pair real devices with explicit execution policy, or inspect a plan")
    @OptionGroup var options: DeviceAdministrationOptions
    func run() async throws { try emitDeviceAdministration(operation: .pair, options: options) }
}
struct DeviceUnpair: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unpair", abstract: "Unpair manually paired real devices with explicit policy")
    @OptionGroup var options: DeviceAdministrationOptions
    func run() async throws { try emitDeviceAdministration(operation: .unpair, options: options) }
}
struct DeviceDiagnose: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "diagnose", abstract: "Collect sensitive device and host diagnostics with explicit policy")
    @OptionGroup var options: DeviceAdministrationOptions
    func run() async throws { try emitDeviceAdministration(operation: .diagnose, options: options) }
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

func emitDeviceAdministration(operation: DeviceAdministrationOperation, options: DeviceAdministrationOptions) throws {
    let format = effectiveFormat(options.format, json: options.json)
    if options.planOnly {
        guard !options.executeRunner, !options.confirm, options.auditRecord == nil else {
            try failHostValidation(code: "parameter_conflict", message: "Plan-only and execution authorization are mutually exclusive.", hint: "Choose --plan-only or explicit execution policy.", outputFormat: format)
        }
        try emitDeviceAdministrationPlan(operation: operation, options: options); return
    }
    let output: HostDeviceAdministrationExecutionOutput
    do { output = try executeDeviceAdministration(operation: operation, options: options) }
    catch let error as HostDeviceAdministrationError {
        try failHostValidation(code: error.code, message: error.description, hint: "Inspect --plan-only first; execution requires --execute-runner --confirm --audit-record and explicit real target.", outputFormat: format)
    } catch { try failHostCommand(error, outputFormat: format) }
    switch format {
    case .json: print(try encodeJSON(output))
    case .text: print("\(output.action)\t\(output.target)\t\(output.status)\taudit=\(output.auditToken)")
    }
    if !output.ok { throw ExitCode.failure }
}
