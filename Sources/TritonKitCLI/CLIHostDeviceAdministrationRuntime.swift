import Foundation
import TritonKitShared

private func validateAdministrationInput(operation: DeviceAdministrationOperation, options: DeviceAdministrationOptions) throws {
    let invalid = HostDeviceSelectionError.parameterConflict("Administration is policy-plan-only: require --plan-only, platform ios, real scope, explicit device and positive finite timeout. Diagnose requires private ZIP --output; other operations forbid --output. No administration action is executed.")
    guard options.planOnly, options.platform == .ios, options.scope == .real,
          let device = options.device, !device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          device.utf8.count <= 1024, device.rangeOfCharacter(from: .controlCharacters) == nil else { throw invalid }
    if let timeout = options.timeout { guard timeout.isFinite, timeout > 0 else { throw invalid } }
    if operation == .diagnose {
        guard let output = options.output, output != "-", output.utf8.count <= 16384,
              output.rangeOfCharacter(from: .controlCharacters) == nil, output.lowercased().hasSuffix(".zip"),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw invalid }
    } else { guard options.output == nil else { throw invalid } }
}

func plannedDeviceAdministrationCommand(operation: DeviceAdministrationOperation, nativeIdentifier: String, archiveDestination: String?, timeout: Double?) -> TKHostCommand {
    var args = operation == .diagnose ? ["devicectl", "diagnose", "--devices"] : ["devicectl", "manage", operation.rawValue, "--device"]
    var redacted: Set<Int> = [args.count]; args.append(nativeIdentifier)
    if operation == .diagnose {
        args += ["--no-finder", "--no-include-host-sysdiagnose", "--archive", "--archive-destination"]
        redacted.insert(args.count); args.append(archiveDestination ?? "<planned-private-archive>")
    }
    let seconds = timeout ?? (operation == .diagnose ? 120 : 30)
    args += ["--timeout", String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), ceil(seconds)), "--json-output", "<planned-private-json>", "--log-output", "<planned-private-log>"]
    return TKHostCommand(arguments: args, redactedArgumentIndexes: redacted, riskLevel: operation == .diagnose ? .diagnostic : .breakGlass, requiredConfig: [.target, .artifactDir, .redactionPolicy, .timeout, .auditRecord], defaultTimeoutSeconds: seconds, capturesArtifacts: true, sensitiveOutput: true)
}

func makeDeviceAdministrationPlan(operation: DeviceAdministrationOperation, options: DeviceAdministrationOptions, resolver: ((HostDeviceSelectionRequest) throws -> HostDeviceSelectionResult)? = nil, commandProbe: (AppleHostCommandSpecification) -> HostAppleCommandSupport = { probeAppleHostCommand($0) }) throws -> HostDeviceAdministrationPlanOutput {
    try validateAdministrationInput(operation: operation, options: options)
    let selection: HostDeviceSelectionResult
    do { selection = try (resolver ?? { try resolveHostDeviceSelection(request: $0, hdc: "hdc", adb: "adb") })(HostDeviceSelectionRequest(device: options.device, platform: options.platform, scope: options.scope)) }
    catch { throw HostDeviceAdministrationDiscoveryFailure(error) }
    let target = selection.target
    guard selection.platform == .ios, target.platform == "ios", target.scope == "real", target.kind == "real-device",
          !target.rawTarget.isEmpty, target.rawTarget.utf8.count <= 1024, !target.rawTarget.hasPrefix("-"),
          target.rawTarget.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil else {
        throw HostDeviceSelectionError.parameterConflict("Fresh explicit real-device identity is required; Simulator/invalid native identifiers are not administration targets. No administration action executed.")
    }
    let outputOptions = ["--timeout", "--json-output", "--log-output"]
    let required = operation == .diagnose ? ["--devices", "--archive-destination", "--archive", "--no-finder", "--no-include-host-sysdiagnose"] + outputOptions : ["--device"] + outputOptions
    let helpArgs = operation == .diagnose ? ["devicectl", "diagnose", "--help"] : ["devicectl", "manage", operation.rawValue, "--help"]
    let specification = AppleHostCommandSpecification(name: "devicectl." + (operation == .diagnose ? "diagnose" : "manage-" + operation.rawValue), helpArguments: helpArgs, requiredOptions: required, requiredForDiscovery: false)
    let probed = commandProbe(specification)
    let support = HostAppleCommandSupport(name: probed.name, supported: probed.supported, requiredOptions: probed.requiredOptions, missingOptions: probed.missingOptions, sourceCommand: hostSourceCommand(TKHostCommand(arguments: helpArgs)), error: probed.error == nil ? nil : "help_probe_failed")
    let command = plannedDeviceAdministrationCommand(operation: operation, nativeIdentifier: target.rawTarget, archiveDestination: options.output, timeout: options.timeout)
    let publicID = TKDevicectlDeviceTarget(identifier: target.rawTarget, state: target.state, ready: target.ready, blockedReasons: []).id
    var blockers = ["explicit-execution-policy-required", "real-device-operation-authorization-and-audit-required", "native-fileJSON-result-and-postcondition-required", "physical-execution-acceptance-not-performed"]
    if !support.supported { blockers.append("required-sdk-help-flags-not-advertised") }
    if operation == .diagnose { blockers.append("private-archive-publication-policy-required;content-completeness-not-verified") }
    return HostDeviceAdministrationPlanOutput(action: "device." + operation.rawValue, target: publicID, plannedRiskLevel: command.riskLevel.rawValue, plannedSourceCommand: support.supported ? hostSourceCommand(command) : nil, commandSupport: support, blockedRequirements: blockers, diagnosticScopeHint: operation == .diagnose ? "If executed, CoreDevice collects local host CoreDevice logs plus the explicit device where DDI is already mounted. --no-include-host-sysdiagnose disables only host sysdiagnose, not all host data; no device-only or crash-report equivalence claimed." : nil, archiveDestinationSupplied: options.output != nil)
}
