import Foundation
import TritonKitShared

extension CLISimulatorResourceRuntime {
    /// Callers resolve and validate the exact Simulator before invoking this reader.
    func readOverrides(udid: String) throws -> SimulatorResourceOverrideState {
        guard UUID(uuidString: udid) != nil else {
            throw SimulatorResourceMutationError.missingUDID
        }
        let command = TKHostCommand(executable: "xcrun", arguments: [
            "simctl", "spawn", udid, "launchctl", "print-disabled", "system",
        ])
        let result = try runner.run(command)
        guard result.exitCode == 0, !result.stdoutTruncated else {
            throw SimulatorResourceMutationError.commandFailed
        }
        return try SimulatorResourceOverrideState.parse(result.stdout)
    }
}

/// Keeps explicit `false` entries: absence and an enabled override are different
/// restore states, even though both permit a service to launch.
struct SimulatorResourceOverrideState: Equatable {
    let overrides: [String: Bool]

    enum ParseError: Error, Equatable {
        case malformedOutput
        case duplicateLabel(String)
    }

    static func parse(_ output: String) throws -> Self {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.contains("{"), text.hasSuffix("}") else {
            throw ParseError.malformedOutput
        }
        let pattern = #"^\s*"([^"]+)"\s*=>\s*(disabled|enabled|true|false)\s*[,;]?\s*$"#
        let expression = try NSRegularExpression(pattern: pattern)
        var result: [String: Bool] = [:]
        for line in text.components(separatedBy: .newlines) {
            guard line.contains("=>") || line.contains("\"") else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = expression.firstMatch(in: line, range: range),
                  let labelRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line) else {
                throw ParseError.malformedOutput
            }
            let label = String(line[labelRange])
            guard result[label] == nil else { throw ParseError.duplicateLabel(label) }
            let value = line[valueRange]
            result[label] = value == "disabled" || value == "true"
        }
        return Self(overrides: result)
    }
}
