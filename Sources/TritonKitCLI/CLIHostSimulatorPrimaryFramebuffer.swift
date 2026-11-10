import CoreFoundation
import Foundation
import TritonKitShared

private func primaryFramebufferBool(_ value: Any?) -> Bool? {
    guard let number = value as? NSNumber,
          CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
    return number.boolValue
}

struct IOSSimulatorPrimaryFramebufferEvidence: Encodable, Equatable {
    let captureScope = "primary-display-framebuffer"
    let displayUniqueID: String
    let resizeState: String
    let resizeReason: String?
    let resizeVerified: Bool
    let inputDispatchVerified = false
    let topologySource = "devicectl.device.info.displays"
}

struct IOSSimulatorPrimaryFramebufferRoute {
    let command: TKHostCommand
    let evidence: IOSSimulatorPrimaryFramebufferEvidence
}

enum IOSSimulatorPrimaryFramebufferDisplay: Equatable {
    case display(String)
    case unknown(IOSSimulatorDisplayUnknownReason)
}

typealias IOSSimulatorPrimaryFramebufferDisplayProbe = (String, [String: String]) -> IOSSimulatorPrimaryFramebufferDisplay

func classifyIOSSimulatorPrimaryFramebufferDisplay(
    data: Data,
    target: String,
    exitCode: Int32,
    expectedArguments: [String],
    allowInactiveVirtualDisplays: Bool = false
) -> IOSSimulatorPrimaryFramebufferDisplay {
    // Keep the established target, full argv, size, outcome, field-type and
    // topology checks. This policy additionally requires a complete singleton.
    switch classifyIOSSimulatorDisplayTopology(data: data, target: target, exitCode: exitCode, expectedArguments: expectedArguments) {
    case .unknown(let reason): return .unknown(reason)
    case .primary: break
    }
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let info = root["info"] as? [String: Any], info["error"] == nil, info["errors"] == nil,
          let result = root["result"] as? [String: Any],
          let displays = result["displays"] as? [[String: Any]], !displays.isEmpty else {
        return .unknown(.invalidResponse)
    }
    let activePrimaryLCD = displays.filter { display in
        guard display["name"] as? String == "LCD",
              primaryFramebufferBool(display["primary"]) == true,
              display["backlightState"] as? String == "activeOn",
              let type = display["type"] as? [String: Any],
              type.keys.count == 1,
              type["integrated"] is [String: Any],
              display["error"] == nil,
              display["errors"] == nil else { return false }
        return true
    }
    guard activePrimaryLCD.count == 1,
          let display = activePrimaryLCD.first,
          let uniqueID = display["uniqueId"] as? String,
          UUID(uuidString: uniqueID) != nil else {
        return .unknown(.invalidResponse)
    }
    if !allowInactiveVirtualDisplays {
        guard displays.count == 1 else { return .unknown(.invalidResponse) }
    } else {
        // An unsupported Resize capability cannot expose an active Resizable
        // surface. Keep the relaxation narrow: only inactive, non-primary
        // virtual displays may accompany the verified primary LCD.
        let extras = displays.filter { $0["uniqueId"] as? String != uniqueID }
        guard extras.allSatisfy({ display in
            guard primaryFramebufferBool(display["primary"]) == false,
                  display["backlightState"] as? String == "off",
                  let type = display["type"] as? [String: Any],
                  type.keys.count == 1,
                  type["virtual"] is [String: Any],
                  display["error"] == nil,
                  display["errors"] == nil else { return false }
            return true
        }) else { return .unknown(.invalidResponse) }
    }
    // Native displays currently binds identity in info.arguments, not result.
    // If a response adds a result identity, a contradiction cannot be ignored.
    if let identity = result["deviceIdentifier"], identity as? String != target {
        return .unknown(.identityMismatch)
    }
    return .display(uniqueID)
}

func probeIOSSimulatorPrimaryFramebufferDisplay(
    target: String,
    environment: [String: String] = [:],
    artifactProvider: (String) throws -> (json: String, log: String) = freshDeviceInfoArtifactPaths,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0, maximumOutputBytes: 16_384) },
    reader: (String, Int) throws -> Data = readBoundedDeviceFilesJSON,
    allowInactiveVirtualDisplays: Bool = false
) -> IOSSimulatorPrimaryFramebufferDisplay {
    switch queryIOSSimulatorDisplaySnapshot(target: target, environment: environment, artifactProvider: artifactProvider, runner: runner, reader: reader) {
    case .unknown(let reason): return .unknown(reason)
    case .response(let data, let exitCode, let arguments):
        return classifyIOSSimulatorPrimaryFramebufferDisplay(data: data, target: target, exitCode: exitCode, expectedArguments: arguments, allowInactiveVirtualDisplays: allowInactiveVirtualDisplays)
    }
}

func primaryFramebufferSimulatorScreenshotRoute(
    _ command: TKHostCommand,
    simulator: String,
    resizeProbe: IOSSimulatorResizeProbe? = nil,
    displayProbe: IOSSimulatorPrimaryFramebufferDisplayProbe? = nil
) throws -> IOSSimulatorPrimaryFramebufferRoute {
    // This helper deliberately accepts only the still-image command built by
    // TKSimctlCommand.screenshot without caller-specified display/type options.
    // Reject malformed commands before either probe or any capture side effect.
    guard UUID(uuidString: simulator) != nil, command.executable == "xcrun",
          command.arguments.count == 5,
          Array(command.arguments.prefix(4)) == ["simctl", "io", simulator, "screenshot"],
          let output = command.arguments.last, !output.isEmpty, !output.hasPrefix("-"),
          !output.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
        throw IOSSimulatorResizeCaptureError.stateUnknown(.invalidResponse)
    }
    let queryResize = resizeProbe ?? { probeIOSSimulatorResize(target: $0, environment: $1) }
    let resize = queryResize(simulator, command.environment)
    let resizeState: String
    let resizeReason: String?
    let resizeVerified: Bool
    switch resize {
    case .inactive:
        resizeState = "inactive"; resizeReason = nil; resizeVerified = true
    case .unknown(.unsupportedDevice):
        resizeState = "unknown"; resizeReason = "unsupportedDevice"; resizeVerified = false
    case .unknown(let reason):
        throw IOSSimulatorResizeCaptureError.stateUnknown(reason)
    case .active:
        throw IOSSimulatorResizeCaptureError.activeSession
    }
    let queryDisplay = displayProbe ?? { probeIOSSimulatorPrimaryFramebufferDisplay(target: $0, environment: $1, allowInactiveVirtualDisplays: resizeReason == "unsupportedDevice") }
    let displayID: String
    switch queryDisplay(simulator, command.environment) {
    case .display(let value):
        guard UUID(uuidString: value) != nil else { throw IOSSimulatorDisplayError.topologyUnknown(.invalidResponse) }
        displayID = value
    case .unknown(let reason): throw IOSSimulatorDisplayError.topologyUnknown(reason)
    }
    var arguments = command.arguments
    arguments.insert(contentsOf: ["--type=png", "--display=\(displayID)"], at: 4)
    let redacted = Set(command.redactedArgumentIndexes.map { $0 >= 4 ? $0 + 2 : $0 }).union([2, 5, 6])
    let routed = TKHostCommand(executable: command.executable, arguments: arguments,
        workingDirectory: command.workingDirectory, environment: command.environment,
        redactedEnvironmentKeys: command.redactedEnvironmentKeys, redactedArgumentIndexes: redacted,
        riskLevel: command.riskLevel, requiredConfig: command.requiredConfig,
        defaultTimeoutSeconds: command.defaultTimeoutSeconds, capturesArtifacts: command.capturesArtifacts,
        sensitiveOutput: command.sensitiveOutput, stdinData: command.stdinData)
    return .init(command: routed, evidence: .init(displayUniqueID: displayID,
        resizeState: resizeState, resizeReason: resizeReason, resizeVerified: resizeVerified))
}
