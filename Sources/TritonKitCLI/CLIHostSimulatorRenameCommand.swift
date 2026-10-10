import ArgumentParser
import Foundation
import TritonKitShared

func makeSimulatorRenameCommand(udid: String, name: String, timeout: Double? = nil) throws -> TKHostCommand {
    guard let identifier = UUID(uuidString: udid) else {
        throw HostDeviceSelectionError.parameterConflict("Simulator rename requires one explicit Simulator UUID; booted/all/physical selectors are not accepted.")
    }
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          name.rangeOfCharacter(from: .controlCharacters) == nil else {
        throw HostDeviceSelectionError.parameterConflict("Simulator name must be nonblank and contain no control characters.")
    }
    if let timeout, !timeout.isFinite || timeout <= 0 {
        throw HostDeviceSelectionError.parameterConflict("Simulator rename timeout must be finite and greater than zero.")
    }
    return TKSimctlCommand.rename(udid: identifier.uuidString, name: name).withTimeout(timeout)
}

struct SimRename: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rename", abstract: "Rename one explicitly identified Simulator without starting or deleting it")

    @Argument(help: "Explicit Simulator UUID (not booted/all)") var udid: String
    @Argument(help: "New nonblank display name; quote names containing spaces") var name: String
    @Option(help: "Positive finite timeout for the rename command") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let command: TKHostCommand
        do { command = try makeSimulatorRenameCommand(udid: udid, name: name, timeout: timeout) }
        catch { try failHostCommand(error, outputFormat: outputFormat); return }
        try runSimpleHostCommand(
            action: "sim.rename",
            target: "sim:\(command.arguments[2])",
            command: command,
            outputFormat: outputFormat,
            note: "Simulator rename was submitted. Verify the observed name with device list; no boot, delete or alternate-backend retry was performed."
        )
    }
}
