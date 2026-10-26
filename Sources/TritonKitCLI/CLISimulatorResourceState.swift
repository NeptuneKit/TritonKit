import Foundation
import TritonKitShared

extension CLISimulatorResourceRuntime {
    /// Only this exact, readonly query may be retried; mutation runners stay single-shot.
    /// The injected monotonic clock/pause keep budget and cancellation tests deterministic.
    func readOverrides(
        udid: String,
        now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        pause: (TimeInterval) throws -> Void = simulatorResourceReadRetryPause
    ) throws -> SimulatorResourceOverrideState {
        guard UUID(uuidString: udid) != nil else {
            throw SimulatorResourceMutationError.missingUDID
        }
        let baseCommand = TKHostCommand(executable: "xcrun", arguments: [
            "simctl", "spawn", udid, "launchctl", "print-disabled", "system",
        ])
        let deadline = now() + 30
        var remaining: TimeInterval = 30
        for attempt in 1...3 {
            try Task.checkCancellation()
            let command = baseCommand.withTimeout(remaining)
            let result: HostProcessResult
            let failure: Error
            do {
                result = try runner.run(command)
                failure = SimulatorResourceMutationError.commandFailed
            } catch HostCommandRunError.nonZeroExit(let issued, let output) {
                // A failure from another command/target (or timeout) is not ours to retry.
                guard issued == command, output.exitCode != 0 else {
                    throw HostCommandRunError.nonZeroExit(command: issued, result: output)
                }
                result = output
                failure = HostCommandRunError.nonZeroExit(command: issued, result: output)
            }
            try Task.checkCancellation()
            if result.exitCode == 0 {
                guard !result.stdoutTruncated, !result.stderrTruncated,
                      result.sourceCommand == hostSourceCommand(command), now() <= deadline else {
                    throw failure
                }
                return try SimulatorResourceOverrideState.parse(result.stdout)
            }
            let delay: TimeInterval = attempt == 1 ? 0.1 : 0.2
            guard attempt < 3, simulatorResourceReadIsTransient(result, command: command),
                  now() + delay < deadline else { throw failure }
            try pause(delay)
            try Task.checkCancellation()
            remaining = deadline - now()
            guard remaining > 0 else { throw failure }
        }
        throw SimulatorResourceMutationError.commandFailed
    }
}

private func simulatorResourceReadIsTransient(_ result: HostProcessResult, command: TKHostCommand) -> Bool {
    guard result.exitCode != 0, !result.stdoutTruncated, !result.stderrTruncated,
          result.sourceCommand == hostSourceCommand(command),
          let stdout = String(data: result.stdoutData, encoding: .utf8),
          stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let stderr = String(data: result.stderrData, encoding: .utf8) else { return false }
    // Match the entire diagnostic, never a substring within an unrelated error.
    // Additional/unknown context is deliberately not retried without a captured fixture.
    let lines = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
    if result.exitCode == 124 {
        let diagnostic = "Failed to start launchd_sim: could not bind to session, launchd_sim may have crashed or quit responding"
        if lines == [diagnostic] || lines == [simulatorResourceNativeErrorHeader(124), diagnostic] { return true }
    }
    let diagnostic = "Domain is tearing down"
    return lines == [diagnostic] || lines == [simulatorResourceNativeErrorHeader(result.exitCode), diagnostic]
}

private func simulatorResourceNativeErrorHeader(_ code: Int32) -> String {
    "An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=\(code)):"
}

private func simulatorResourceReadRetryPause(_ seconds: TimeInterval) throws {
    let deadline = ProcessInfo.processInfo.systemUptime + seconds
    while true {
        try Task.checkCancellation()
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { return }
        Thread.sleep(forTimeInterval: min(remaining, 0.01))
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
        let lines = text.components(separatedBy: .newlines)
        guard let first = lines.first?.trimmingCharacters(in: .whitespaces),
              first == "{" || first == "disabled services = {",
              lines.last?.trimmingCharacters(in: .whitespaces) == "}" else {
            throw ParseError.malformedOutput
        }
        let pattern = #"^\s*"([^"]+)"\s*=>\s*(disabled|enabled|true|false)\s*[,;]?\s*$"#
        let expression = try NSRegularExpression(pattern: pattern)
        var result: [String: Bool] = [:]
        for line in lines.dropFirst().dropLast() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
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
