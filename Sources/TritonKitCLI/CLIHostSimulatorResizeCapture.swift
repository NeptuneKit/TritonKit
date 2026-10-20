import Foundation
import TritonKitShared

func resizeAwareSimulatorScreenshotCommand(_ command: TKHostCommand, simulator: String, probe: IOSSimulatorResizeProbe? = nil, displayProbe: IOSSimulatorDisplayProbe? = { probeIOSSimulatorDisplay(target: $0, environment: $1) }) throws -> TKHostCommand {
    if let displayProbe { try assertIOSSimulatorMainDisplayAllowed(target: simulator, environment: command.environment, probe: displayProbe) }
    let query = probe ?? { probeIOSSimulatorResize(target: $0, environment: $1) }
    let state = query(simulator, command.environment)
    guard let display = try iosSimulatorResizeScreenshotDisplay(state) else { return command }
    guard let index = command.arguments.firstIndex(of: "screenshot"), index + 1 < command.arguments.count else {
        throw IOSSimulatorResizeCaptureError.stateUnknown(.invalidResponse)
    }
    let existing = command.arguments.enumerated().filter { $0.element.hasPrefix("--display=") }
    if !existing.isEmpty {
        guard existing.count == 1, existing[0].element == "--display=\(display)" else {
            throw IOSSimulatorResizeCaptureError.stateUnknown(.invalidResponse)
        }
        return command
    }
    let insertion = index + 1
    var arguments = command.arguments
    arguments.insert("--display=\(display)", at: insertion)
    return TKHostCommand(executable: command.executable, arguments: arguments, workingDirectory: command.workingDirectory,
        environment: command.environment, redactedEnvironmentKeys: command.redactedEnvironmentKeys,
        redactedArgumentIndexes: Set(command.redactedArgumentIndexes.map { $0 >= insertion ? $0 + 1 : $0 }),
        riskLevel: command.riskLevel, requiredConfig: command.requiredConfig, defaultTimeoutSeconds: command.defaultTimeoutSeconds,
        capturesArtifacts: command.capturesArtifacts, sensitiveOutput: command.sensitiveOutput, stdinData: command.stdinData)
}

func assertIOSSimulatorAXActivationAllowed(target: String, probe: IOSSimulatorResizeProbe? = nil, displayProbe: IOSSimulatorDisplayProbe? = { probeIOSSimulatorDisplay(target: $0, environment: $1) }) throws {
    let query = probe ?? { probeIOSSimulatorResize(target: $0, environment: $1) }
    switch query(target, [:]) {
    case .inactive: break
    case .active: throw IOSSimulatorResizeError.activeSession
    case .unknown(let reason): throw IOSSimulatorResizeError.stateUnknown(reason)
    }
    if let displayProbe { try assertIOSSimulatorMainDisplayAllowed(target: target, probe: displayProbe) }
}
