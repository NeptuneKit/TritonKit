import ArgumentParser
import Foundation
import TritonKitShared

let defaultXcodeDerivedDataPath = ".triton/DerivedData"

func validateXcodeSchemesTimeout(_ value: Double) throws -> Double {
    guard value.isFinite, value > 0 else {
        throw ValidationError("xcode schemes --timeout-seconds must be greater than zero.")
    }
    return value
}

func makeXcodeDerivedDataCacheInfo(path: String?) -> TKXcodeDerivedDataCacheInfo {
    let resolvedPath = (path?.isEmpty == false ? path : nil) ?? defaultXcodeDerivedDataPath
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) && isDirectory.boolValue
    return TKXcodeDerivedDataCacheInfo(
        path: resolvedPath,
        exists: exists,
        cacheState: exists ? "warm" : "empty",
        incrementalExpected: exists,
        cleanupPolicy: "preserve-by-default",
        guidance: "Keep \(resolvedPath) to preserve Xcode incremental build cache; cleanup should not delete it by default."
    )
}

func validateXcodeContainer(workspace: String?, project: String?, package: String?, outputFormat: ClientOutputFormat) throws {
    let containers = [workspace, project, package].compactMap { $0 }.filter { !$0.isEmpty }
    if containers.count > 1 {
        try failHostValidation(
            code: "validation_failed",
            message: "Pass exactly one of --workspace, --project, or --package.",
            hint: "Run `triton xcode discover --path . --json` to inspect candidates.",
            outputFormat: outputFormat
        )
    }
    if containers.isEmpty {
        try failHostValidation(
            code: "validation_failed",
            message: "Xcode workflow requires --workspace, --project, or --package.",
            hint: "Run `triton xcode discover --path . --json` and then `triton xcode use ...`.",
            outputFormat: outputFormat
        )
    }
}

func resolveXcodeContainer(workspace: String? = nil, project: String? = nil, package: String? = nil) throws -> (workspace: String?, project: String?, package: String?) {
    let explicitContainers = [workspace, project, package].compactMap { $0 }.filter { !$0.isEmpty }
    guard explicitContainers.count <= 1 else {
        throw XcodeWorkflowError.ambiguousContainer
    }
    if explicitContainers.count == 1 {
        return (workspace, project, package)
    }
    let defaults = try loadHostWorkspaceDefaults()
    let resolvedWorkspace = defaults?.xcode?.workspace
    let resolvedProject = defaults?.xcode?.project
    let resolvedPackage = defaults?.xcode?.package
    let containers = [resolvedWorkspace, resolvedProject, resolvedPackage].compactMap { $0 }.filter { !$0.isEmpty }
    guard containers.count <= 1 else {
        throw XcodeWorkflowError.ambiguousContainer
    }
    guard containers.count == 1 else {
        throw XcodeWorkflowError.missingContainer
    }
    return (resolvedWorkspace, resolvedProject, resolvedPackage)
}

func resolveXcodeInvocation(
    workspace: String? = nil,
    project: String? = nil,
    package: String? = nil,
    scheme: String? = nil,
    configuration: String? = nil,
    sdk: String? = nil,
    destination: String? = nil,
    simulator: String? = nil,
    device: String? = nil,
    derivedDataPath: String? = nil,
    buildSettings: [String] = []
) throws -> ResolvedXcodeInvocation {
    let hasDevice = hasXcodeSelector(device)
    if hasDevice, hasXcodeSelector(destination) {
        throw HostDeviceSelectionError.parameterConflict(
            "Pass either --device or --destination, not both. Real-device xcodebuild destinations are resolved from the selected target."
        )
    }
    if hasDevice, hasXcodeSelector(simulator) {
        throw HostDeviceSelectionError.parameterConflict(
            "Pass either --simulator or --device, not both."
        )
    }
    if hasDevice,
       let sdk,
       !sdk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       !usesXcodeRealDeviceSDK(sdk) {
        throw ValidationError("--device requires an iPhoneOS SDK when an SDK is explicit.")
    }
    let defaults = try loadHostWorkspaceDefaults()
    let xcode = defaults?.xcode
    let container = try resolveXcodeContainer(workspace: workspace, project: project, package: package)
    let resolvedWorkspace = container.workspace
    let resolvedProject = container.project
    let resolvedPackage = container.package
    guard let resolvedScheme = scheme ?? xcode?.scheme, !resolvedScheme.isEmpty else {
        throw XcodeWorkflowError.missingScheme
    }
    let resolvedConfiguration = configuration ?? xcode?.configuration ?? "Debug"
    let resolvedSimulator = hasDevice ? nil : simulator ?? defaults?.defaultSimulatorUDID
    let resolvedDestination = resolvedXcodeDestination(
        destination: destination,
        defaultDestination: xcode?.destination,
        simulatorUDID: resolvedSimulator,
        device: device,
        simulatorOverridesDefaultDestination: hasXcodeSelector(simulator)
    )
    let resolvedSDK = resolvedXcodeSDK(
        sdk: sdk,
        defaultSDK: xcode?.sdk,
        resolvedDestination: resolvedDestination,
        simulatorUDID: resolvedSimulator,
        device: device
    )
    if !hasDevice,
       usesXcodeRealDeviceSDK(resolvedSDK) || isXcodeRealDeviceDestination(resolvedDestination) {
        throw ValidationError(
            "Physical iOS xcodebuild execution requires --device so Triton can resolve a ready target and keep its raw destination execution-only."
        )
    }
    let resolvedDerivedDataPath = derivedDataPath ?? xcode?.derivedDataPath ?? defaultXcodeDerivedDataPath
    let resolvedBuildSettings = try validateXcodeBuildSettings(buildSettings)
    let derivedDataCache = makeXcodeDerivedDataCacheInfo(path: resolvedDerivedDataPath)
    return ResolvedXcodeInvocation(
        workspace: resolvedWorkspace,
        project: resolvedProject,
        package: resolvedPackage,
        scheme: resolvedScheme,
        configuration: resolvedConfiguration,
        sdk: resolvedSDK,
        destination: resolvedDestination,
        derivedDataPath: resolvedDerivedDataPath,
        buildSettings: resolvedBuildSettings,
        derivedDataCache: derivedDataCache,
        simulatorUDID: resolvedSimulator,
        device: device
    )
}

func validateXcodeBuildSettings(_ values: [String]) throws -> [String] {
    let firstAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_")
    let restAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789")
    for value in values {
        guard let separator = value.firstIndex(of: "=") else {
            throw ValidationError("Xcode build settings must use KEY=VALUE.")
        }
        let key = String(value[..<separator])
        guard let first = key.unicodeScalars.first,
              firstAllowed.contains(first),
              key.unicodeScalars.dropFirst().allSatisfy({ restAllowed.contains($0) }) else {
            throw ValidationError("Xcode build setting key must match [A-Za-z_][A-Za-z0-9_]*: \(key)")
        }
    }
    return values
}

func resolvedXcodeSDK(
    sdk: String?,
    defaultSDK: String?,
    resolvedDestination: String?,
    simulatorUDID: String?,
    device: String?
) -> String? {
    if hasXcodeSelector(device) {
        return "iphoneos"
    }
    if let sdk, !sdk.isEmpty {
        return sdk
    }
    if isSimulatorBuildDestination(resolvedDestination) || hasXcodeSelector(simulatorUDID) {
        return nil
    }
    return defaultSDK
}

func resolvedXcodeDestination(
    destination: String?,
    defaultDestination: String?,
    simulatorUDID: String?,
    device: String?,
    simulatorOverridesDefaultDestination: Bool = true
) -> String? {
    if hasXcodeSelector(device) {
        return nil
    }
    if let destination, !destination.isEmpty {
        return destination
    }
    if simulatorOverridesDefaultDestination, let simulatorUDID, hasXcodeSelector(simulatorUDID) {
        return xcodeSimulatorDestination(selector: simulatorUDID)
    }
    if let defaultDestination, !defaultDestination.isEmpty {
        return defaultDestination
    }
    return simulatorUDID.map(xcodeSimulatorDestination(selector:))
}

func xcodeSimulatorDestination(selector: String) -> String {
    let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized: String
    if trimmed.lowercased().hasPrefix("sim:") {
        normalized = String(trimmed.dropFirst("sim:".count))
    } else {
        normalized = trimmed
    }
    if UUID(uuidString: normalized) != nil {
        return "platform=iOS Simulator,id=\(normalized)"
    }
    return "platform=iOS Simulator,name=\(normalized)"
}

private func hasXcodeSelector(_ value: String?) -> Bool {
    guard let value else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

func usesXcodeRealDeviceSDK(_ sdk: String?) -> Bool {
    guard let sdk else { return false }
    let normalized = sdk.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard normalized.hasPrefix("iphoneos") else { return false }
    let version = normalized.dropFirst("iphoneos".count)
    guard !version.isEmpty else { return true }
    return version
        .split(separator: ".", omittingEmptySubsequences: false)
        .allSatisfy { component in
            !component.isEmpty && component.allSatisfy(\.isNumber)
        }
}

func isXcodeRealDeviceDestination(_ destination: String?) -> Bool {
    guard let destination else { return false }
    let normalized = destination.lowercased()
    return normalized.contains("platform=ios") && !normalized.contains("platform=ios simulator")
}

func redactedXcodeRealDeviceDestination(_ destination: String) -> String {
    guard isXcodeRealDeviceDestination(destination) else { return destination }
    return "platform=iOS,id=<redacted>"
}

func redactedXcodeRealDeviceDestinationInPublicText(_ value: String) -> String {
    guard let expression = try? NSRegularExpression(
        pattern: #"(?i)(?:generic/)?platform=iOS,id=[^\s\"']+"#
    ) else {
        return value
    }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let redactedIdentifiers = expression.stringByReplacingMatches(
        in: value,
        range: range,
        withTemplate: "platform=iOS,id=<redacted>"
    )
    return redactedXcodeRealDeviceNameDestinations(in: redactedIdentifiers)
}

private func redactedXcodeRealDeviceNameDestinations(in value: String) -> String {
    guard let expression = try? NSRegularExpression(
        pattern: #"(?i)(?:generic/)?platform=iOS,name="#
    ) else {
        return value
    }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let matches = expression.matches(in: value, range: range)
    guard !matches.isEmpty else { return value }

    var redacted = ""
    var cursor = value.startIndex
    for match in matches {
        guard let matchRange = Range(match.range, in: value), matchRange.lowerBound >= cursor else {
            continue
        }
        redacted += value[cursor..<matchRange.lowerBound]
        let destinationEnd = value[matchRange.upperBound...].firstIndex(where: \.isNewline) ?? value.endIndex
        redacted += "platform=iOS,id=<redacted>"
        cursor = destinationEnd
    }
    redacted += value[cursor...]
    return redacted
}

func redactedXcodePublicCommandLine(_ commandLine: String, destination: String?) -> String {
    let redacted = redactedXcodeRealDeviceDestinationInPublicText(commandLine)
    guard let destination, isXcodeRealDeviceDestination(destination) else {
        return redacted
    }
    return redacted.replacingOccurrences(
        of: destination,
        with: redactedXcodeRealDeviceDestination(destination)
    )
}

func xcodeRealDeviceDestinationSensitiveValues(_ destination: String?) -> [String] {
    guard let destination, isXcodeRealDeviceDestination(destination) else { return [] }
    let values = destination
        .split(separator: ",")
        .compactMap { component -> String? in
            let component = String(component)
            let normalizedComponent = component.lowercased()
            let prefix: String
            if normalizedComponent.hasPrefix("id=") {
                prefix = "id="
            } else if normalizedComponent.hasPrefix("name=") {
                prefix = "name="
            } else {
                return nil
            }
            let value = String(component.dropFirst(prefix.count))
            return value.isEmpty ? nil : value
        }
    return [destination] + values
}

private func isSimulatorBuildDestination(_ destination: String?) -> Bool {
    guard let destination else { return false }
    return destination.range(of: "platform=iOS Simulator", options: [.caseInsensitive]) != nil
}

enum XcodeWorkflowError: Error, CustomStringConvertible {
    case missingContainer
    case ambiguousContainer
    case missingScheme
    case appPathUnresolved
    case bundleIDUnresolved(String)
    case simulatorRequired
    case conflictingTargetSelectors

    var description: String {
        switch self {
        case .missingContainer:
            "Xcode workflow requires --workspace, --project, or --package, or saved defaults from `triton xcode use`."
        case .ambiguousContainer:
            "Pass exactly one of --workspace, --project, or --package."
        case .missingScheme:
            "Xcode workflow requires --scheme or saved defaults from `triton xcode use`."
        case .appPathUnresolved:
            "Built .app path could not be resolved from xcodebuild build settings."
        case .bundleIDUnresolved(let appPath):
            "Bundle identifier could not be resolved from \(appPath)."
        case .simulatorRequired:
            "Xcode run requires --simulator or `triton sim use <udid>` defaults."
        case .conflictingTargetSelectors:
            "Pass either --simulator or --device, not both."
        }
    }
}

func prepareXcodeRealDeviceInvocation(
    invocation: ResolvedXcodeInvocation,
    resolveSelection: () throws -> HostDeviceSelectionResult
) throws -> PreparedXcodeRealDeviceInvocation {
    guard let selector = invocation.realDeviceSelector,
          !selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ValidationError("Xcode real-device preflight requires --device.")
    }

    let selection = try resolveSelection()
    guard selection.platform == .ios else {
        throw HostDeviceSelectionError.platformMismatch(
            selector: selector,
            expected: .ios,
            actual: selection.platform
        )
    }
    guard selection.target.ready else {
        throw HostCommandRunError.deviceNotReady(
            target: selection.target.target,
            timeoutSeconds: 0
        )
    }
    let rawTarget = selection.target.rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawTarget.isEmpty else {
        throw ValidationError("The selected iOS real device has no executable raw target identifier.")
    }

    return PreparedXcodeRealDeviceInvocation(
        invocation: invocation.withRealDeviceExecutionDestination(rawTarget: rawTarget),
        selection: selection
    )
}

func prepareXcodeRealDeviceInvocation(
    invocation: ResolvedXcodeInvocation
) throws -> PreparedXcodeRealDeviceInvocation {
    guard let selector = invocation.realDeviceSelector,
          !selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ValidationError("Xcode real-device preflight requires --device.")
    }
    return try prepareXcodeRealDeviceInvocation(invocation: invocation) {
        try resolveHostDeviceSelection(
            request: HostDeviceSelectionRequest(
                device: selector,
                platform: .ios,
                scope: .real,
                ready: false
            ),
            hdc: "hdc"
        )
    }
}

func preparedXcodeInvocationForExecution(
    _ invocation: ResolvedXcodeInvocation
) throws -> ResolvedXcodeInvocation {
    guard invocation.hasRealDeviceSelection else {
        return invocation
    }
    if invocation.redactsXcodebuildDestination {
        return invocation
    }
    return try prepareXcodeRealDeviceInvocation(invocation: invocation).invocation
}

func runXcodeBuild(
    invocation: ResolvedXcodeInvocation,
    jsonl: Bool,
    timeout: Double? = nil,
    allowNonZeroExit: Bool = true,
    allowProvisioningUpdates: Bool = false,
    statusProvider: (String?) throws -> XcodeProcessStatusOutput = { try currentXcodeProcessStatus(workspace: $0) }
) throws -> TKXcodeActionSummary {
    let executionInvocation = try preparedXcodeInvocationForExecution(invocation)
    let command = TKXcodebuildCommand.build(
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.xcodebuildDestination,
        derivedDataPath: executionInvocation.derivedDataPath,
        buildSettings: executionInvocation.buildSettings,
        allowProvisioningUpdates: allowProvisioningUpdates,
        redactDestination: executionInvocation.redactsXcodebuildDestination
    ).withTimeout(timeout)
    let (result, durationMs) = try runXcodeHostCommand(command, event: "xcode.build", jsonl: jsonl, allowNonZeroExit: allowNonZeroExit)
    let diagnostics = xcodeBuildOutputDiagnostics(result, redacting: command)
    let ok = result.exitCode == 0
    let workspaceFilter = xcodeWorkspaceFilter(for: executionInvocation)
    let postActionProcessStatus = redactedXcodePostActionProcessStatus(
        xcodePostActionProcessStatusIfInterrupted(
            ok: ok,
            result: result,
            workspaceFilter: workspaceFilter,
            statusProvider: statusProvider
        ),
        command: command
    )
    let failureCode = xcodeBuildFailureCode(
        ok: ok,
        diagnostics: diagnostics,
        result: result,
        postActionProcessStatus: postActionProcessStatus
    )
    return TKXcodeActionSummary(
        ok: ok,
        action: "xcode.build",
        failureCode: failureCode,
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.destination,
        derivedDataPath: executionInvocation.derivedDataPath,
        derivedDataCache: executionInvocation.derivedDataCache,
        simulatorUDID: executionInvocation.simulatorUDID,
        device: executionInvocation.device,
        durationMs: durationMs,
        sourceCommand: result.sourceCommand,
        exitCode: result.exitCode,
        stdoutTruncated: result.stdoutTruncated,
        stderrTruncated: result.stderrTruncated,
        stdoutLogPath: result.stdoutLogPath,
        stderrLogPath: result.stderrLogPath,
        stdoutBytes: result.stdoutBytes,
        stderrBytes: result.stderrBytes,
        xcodeDiagnostics: diagnostics,
        postActionProcessStatus: postActionProcessStatus,
        nextActions: xcodeBuildRecoveryActions(failureCode: failureCode, workspaceFilter: workspaceFilter),
        note: xcodeBuildSummaryNote(
            ok: ok,
            failureCode: failureCode,
            successNote: "Build finished. Use `triton xcode run --jsonl` or verify business readiness with runtime `triton status/wait/assert`.",
            defaultFailureNote: "Build failed. Inspect xcodeDiagnostics first, then stdout/stderr artifacts if needed."
        )
    )
}

func runXcodeTest(
    invocation: ResolvedXcodeInvocation,
    resultBundlePath: String?,
    jsonl: Bool,
    timeout: Double? = nil,
    statusProvider: (String?) throws -> XcodeProcessStatusOutput = { try currentXcodeProcessStatus(workspace: $0) }
) throws -> TKXcodeActionSummary {
    let executionInvocation = try preparedXcodeInvocationForExecution(invocation)
    let command = TKXcodebuildCommand.test(
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.xcodebuildDestination,
        derivedDataPath: executionInvocation.derivedDataPath,
        resultBundlePath: resultBundlePath,
        buildSettings: executionInvocation.buildSettings,
        redactDestination: executionInvocation.redactsXcodebuildDestination
    ).withTimeout(timeout)
    let (result, durationMs) = try runXcodeHostCommand(command, event: "xcode.test", jsonl: jsonl, allowNonZeroExit: true)
    let diagnostics = xcodeBuildOutputDiagnostics(result, redacting: command)
    let ok = result.exitCode == 0
    let workspaceFilter = xcodeWorkspaceFilter(for: executionInvocation)
    let postActionProcessStatus = redactedXcodePostActionProcessStatus(
        xcodePostActionProcessStatusIfInterrupted(
            ok: ok,
            result: result,
            workspaceFilter: workspaceFilter,
            statusProvider: statusProvider
        ),
        command: command
    )
    let failureCode = xcodeBuildFailureCode(
        ok: ok,
        diagnostics: diagnostics,
        result: result,
        postActionProcessStatus: postActionProcessStatus
    )
    let resultDetails = xcodeTestResultBundleDetails(
        resultBundlePath: resultBundlePath,
        redacting: command
    )
    return TKXcodeActionSummary(
        ok: ok,
        action: "xcode.test",
        failureCode: failureCode,
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.destination,
        derivedDataPath: executionInvocation.derivedDataPath,
        derivedDataCache: executionInvocation.derivedDataCache,
        resultBundlePath: resultBundlePath,
        simulatorUDID: executionInvocation.simulatorUDID,
        device: executionInvocation.device,
        durationMs: durationMs,
        sourceCommand: result.sourceCommand,
        exitCode: result.exitCode,
        stdoutTruncated: result.stdoutTruncated,
        stderrTruncated: result.stderrTruncated,
        stdoutLogPath: result.stdoutLogPath,
        stderrLogPath: result.stderrLogPath,
        stdoutBytes: result.stdoutBytes,
        stderrBytes: result.stderrBytes,
        testResultSummary: resultDetails.summary,
        topFailures: resultDetails.topFailures,
        xcresultNote: resultDetails.note,
        xcodeDiagnostics: diagnostics,
        postActionProcessStatus: postActionProcessStatus,
        nextActions: xcodeBuildRecoveryActions(failureCode: failureCode, workspaceFilter: workspaceFilter),
        note: xcodeBuildSummaryNote(
            ok: ok,
            failureCode: failureCode,
            successNote: "Test command finished. Use `triton xcresult summary --path <result.xcresult> --json` or `triton xcresult failures --path <result.xcresult> --json` for structured result parsing.",
            defaultFailureNote: "Test command failed. Inspect xcodeDiagnostics and xcresult details first, then stdout/stderr artifacts if needed."
        )
    )
}

func runXcodeBuildInstallLaunch(
    invocation: ResolvedXcodeInvocation,
    launchEnvironment: [String: String] = [:],
    launchArguments: [String] = [],
    jsonl: Bool,
    timeout: Double? = nil
) throws -> TKXcodeActionSummary {
    if invocation.hasRealDeviceSelection {
        return try runXcodeRealDeviceBuildInstallLaunch(
            invocation: invocation,
            launchEnvironment: launchEnvironment,
            launchArguments: launchArguments,
            jsonl: jsonl,
            timeout: timeout
        )
    }

    guard let simulator = invocation.simulatorUDID, !simulator.isEmpty else {
        throw XcodeWorkflowError.simulatorRequired
    }
    let buildSummary = try runXcodeBuild(invocation: invocation, jsonl: jsonl, timeout: timeout, allowNonZeroExit: true)
    guard buildSummary.ok else {
        return TKXcodeActionSummary(
            ok: false,
            action: "xcode.run",
            failureCode: buildSummary.failureCode,
            workspace: invocation.workspace,
            project: invocation.project,
            package: invocation.package,
            scheme: invocation.scheme,
            configuration: invocation.configuration,
            sdk: invocation.sdk,
            destination: invocation.destination,
            derivedDataPath: invocation.derivedDataPath,
            derivedDataCache: invocation.derivedDataCache,
            simulatorUDID: simulator,
            device: invocation.device,
            durationMs: buildSummary.durationMs,
            sourceCommand: buildSummary.sourceCommand,
            exitCode: buildSummary.exitCode,
            stdoutTruncated: buildSummary.stdoutTruncated,
            stderrTruncated: buildSummary.stderrTruncated,
            stdoutLogPath: buildSummary.stdoutLogPath,
            stderrLogPath: buildSummary.stderrLogPath,
            stdoutBytes: buildSummary.stdoutBytes,
            stderrBytes: buildSummary.stderrBytes,
            xcodeDiagnostics: buildSummary.xcodeDiagnostics,
            postActionProcessStatus: buildSummary.postActionProcessStatus,
            nextActions: buildSummary.nextActions,
            note: "Run build phase failed. Inspect xcodeDiagnostics first, then stdout/stderr artifacts if needed."
        )
    }
    let product = try resolveBuiltAppProduct(
        invocation: invocation,
        timeout: timeout,
        jsonl: jsonl,
        event: "xcode.run.settings"
    )
    let bundleID: String
    if let productBundleID = product.bundleID {
        bundleID = productBundleID
    } else {
        bundleID = try bundleIdentifier(appPath: product.appPath)
    }

    let installCommand = TKSimctlCommand.installApp(udid: simulator, appPath: product.appPath)
    _ = try runXcodeHostCommand(installCommand, event: "xcode.run.install", jsonl: jsonl)
    let launchCommand = TKSimctlCommand.launchApp(
        udid: simulator,
        bundleID: bundleID,
        environment: launchEnvironment,
        arguments: launchArguments
    )
    let (launchResult, launchDurationMs) = try runXcodeHostCommand(launchCommand, event: "xcode.run.launch", jsonl: jsonl)

    return TKXcodeActionSummary(
        ok: true,
        action: "xcode.run",
        workspace: invocation.workspace,
        project: invocation.project,
        package: invocation.package,
        scheme: invocation.scheme,
        configuration: invocation.configuration,
        sdk: invocation.sdk,
        destination: invocation.destination,
        derivedDataPath: invocation.derivedDataPath,
        derivedDataCache: invocation.derivedDataCache,
        appPath: product.appPath,
        bundleID: bundleID,
        simulatorUDID: simulator,
        device: invocation.device,
        durationMs: buildSummary.durationMs + launchDurationMs,
        sourceCommand: launchResult.sourceCommand,
        exitCode: launchResult.exitCode,
        stdoutTruncated: launchResult.stdoutTruncated,
        stderrTruncated: launchResult.stderrTruncated,
        stdoutLogPath: launchResult.stdoutLogPath,
        stderrLogPath: launchResult.stderrLogPath,
        stdoutBytes: launchResult.stdoutBytes,
        stderrBytes: launchResult.stderrBytes,
        note: "App launch was submitted to Simulator. Verify business readiness with `triton status`, `triton wait`, `triton verify`, screenshot, or evidence."
    )
}

func runXcodeRealDevicePreflightThenBuild<Selection, BuildResult>(
    resolveSelection: () throws -> Selection,
    build: () throws -> BuildResult
) throws -> (selection: Selection, buildSummary: BuildResult) {
    let selection = try resolveSelection()
    let buildSummary = try build()
    return (selection: selection, buildSummary: buildSummary)
}

func runXcodeRealDeviceBuildInstallLaunch(
    invocation: ResolvedXcodeInvocation,
    launchEnvironment: [String: String] = [:],
    launchArguments: [String] = [],
    jsonl: Bool,
    timeout: Double? = nil
) throws -> TKXcodeActionSummary {
    guard invocation.hasRealDeviceSelection else {
        throw XcodeWorkflowError.simulatorRequired
    }
    let prepared = try prepareXcodeRealDeviceInvocation(invocation: invocation)
    let executionInvocation = prepared.invocation
    let selection = prepared.selection
    let buildSummary = try runXcodeBuild(
        invocation: executionInvocation,
        jsonl: jsonl,
        timeout: timeout,
        allowNonZeroExit: false
    )
    let product = try resolveBuiltAppProduct(
        invocation: executionInvocation,
        timeout: timeout,
        jsonl: jsonl,
        event: "xcode.run.settings"
    )
    let bundleID: String
    if let productBundleID = product.bundleID {
        bundleID = productBundleID
    } else {
        bundleID = try bundleIdentifier(appPath: product.appPath)
    }

    let installPlan = try planHostAppInstall(
        selection: selection,
        app: product.appPath,
        apk: nil,
        hap: nil,
        adb: "adb",
        hdc: "hdc",
        devicectlArtifacts: nil
    )
    let installCommand = redactingXcodeRealDeviceCommand(
        installPlan.command,
        rawTarget: selection.target.rawTarget
    )
    let (_, installDurationMs) = try runXcodeHostCommand(installCommand, event: "xcode.run.install", jsonl: jsonl)
    let launchPlan = try planHostAppLaunch(
        selection: selection,
        bundleID: bundleID,
        packageName: nil,
        activity: nil,
        bundle: nil,
        ability: nil,
        payloadURL: nil,
        launchEnvironment: launchEnvironment,
        launchArguments: launchArguments,
        adb: "adb",
        hdc: "hdc",
        devicectlArtifacts: nil
    )
    let launchCommand = redactingXcodeRealDeviceCommand(
        launchPlan.command,
        rawTarget: selection.target.rawTarget
    )
    let (launchResult, launchDurationMs) = try runXcodeHostCommand(launchCommand, event: "xcode.run.launch", jsonl: jsonl)

    return TKXcodeActionSummary(
        ok: true,
        action: "xcode.run",
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.destination,
        derivedDataPath: executionInvocation.derivedDataPath,
        derivedDataCache: executionInvocation.derivedDataCache,
        appPath: product.appPath,
        bundleID: bundleID,
        simulatorUDID: nil,
        device: executionInvocation.device,
        durationMs: buildSummary.durationMs + installDurationMs + launchDurationMs,
        sourceCommand: launchResult.sourceCommand,
        exitCode: launchResult.exitCode,
        stdoutTruncated: launchResult.stdoutTruncated,
        stderrTruncated: launchResult.stderrTruncated,
        stdoutLogPath: launchResult.stdoutLogPath,
        stderrLogPath: launchResult.stderrLogPath,
        stdoutBytes: launchResult.stdoutBytes,
        stderrBytes: launchResult.stderrBytes,
        note: "App launch was submitted to the selected real device. Verify business readiness with runtime `triton status/wait/assert`, screenshot, or evidence."
    )
}

func xcodeBuildOutputDiagnostics(
    _ result: HostProcessResult,
    redacting command: TKHostCommand? = nil
) -> [TKXcodeOutputDiagnostic]? {
    let stdout = command.map { redactedXcodePublicText(result.stdout, command: $0) } ?? result.stdout
    let stderr = command.map { redactedXcodePublicText(result.stderr, command: $0) } ?? result.stderr
    guard let diagnostic = XcodeBuildOutputDiagnosticsParser.parse(stdout: stdout, stderr: stderr) else {
        return nil
    }
    return [diagnostic]
}

func redactingXcodeRealDeviceCommand(
    _ command: TKHostCommand,
    rawTarget: String
) -> TKHostCommand {
    let rawTarget = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawTarget.isEmpty else { return command }
    let redactedIndexes = Set(command.arguments.indices.filter { command.arguments[$0] == rawTarget })
    guard !redactedIndexes.isEmpty else { return command }
    return TKHostCommand(
        executable: command.executable,
        arguments: command.arguments,
        workingDirectory: command.workingDirectory,
        environment: command.environment,
        redactedEnvironmentKeys: command.redactedEnvironmentKeys,
        redactedArgumentIndexes: command.redactedArgumentIndexes.union(redactedIndexes),
        riskLevel: command.riskLevel,
        requiredConfig: command.requiredConfig,
        defaultTimeoutSeconds: command.defaultTimeoutSeconds,
        capturesArtifacts: command.capturesArtifacts,
        sensitiveOutput: command.sensitiveOutput,
        stdinData: command.stdinData
    )
}

func xcodeExecutionSensitiveValues(
    command: TKHostCommand,
    additionalSensitiveValues: [String] = []
) -> [String] {
    Set(command.redactedArgumentIndexes
        .compactMap { index in command.arguments.indices.contains(index) ? command.arguments[index] : nil }
        .flatMap { argument -> [String] in
            let exactIdentifiers = argument
                .split(separator: ",")
                .compactMap { component -> String? in
                    let component = String(component)
                    guard component.hasPrefix("id=") else { return nil }
                    let identifier = String(component.dropFirst("id=".count))
                    return identifier.isEmpty ? nil : identifier
            }
            return [argument] + exactIdentifiers
        }
        + additionalSensitiveValues
        .filter { !$0.isEmpty })
        .sorted { $0.count > $1.count }
}

func redactedXcodePublicText(
    _ value: String,
    command: TKHostCommand,
    additionalSensitiveValues: [String] = []
) -> String {
    let redactedPhysicalDestinations = redactedXcodeRealDeviceDestinationInPublicText(value)
    return xcodeExecutionSensitiveValues(
        command: command,
        additionalSensitiveValues: additionalSensitiveValues
    ).reduce(redactedPhysicalDestinations) { partialResult, sensitiveValue in
        partialResult.replacingOccurrences(of: sensitiveValue, with: "<redacted>")
    }
}

func redactedXcodePublicProcessResult(
    _ result: HostProcessResult,
    command: TKHostCommand,
    additionalSensitiveValues: [String] = [],
    redactDevicectlDiscoveryOutput: Bool = false
) -> HostProcessResult {
    let shouldRedactDiscoveryOutput = redactDevicectlDiscoveryOutput && isXcodeRealDeviceDiscoveryCommand(command)
    let publicStdout = shouldRedactDiscoveryOutput
        ? "<redacted devicectl discovery output>"
        : redactedXcodePublicText(
            result.stdout,
            command: command,
            additionalSensitiveValues: additionalSensitiveValues
        )
    let publicStderr = shouldRedactDiscoveryOutput
        ? "<redacted devicectl discovery output>"
        : redactedXcodePublicText(
            result.stderr,
            command: command,
            additionalSensitiveValues: additionalSensitiveValues
        )
    return HostProcessResult(
        stdoutData: Data(publicStdout.utf8),
        stderrData: Data(publicStderr.utf8),
        exitCode: result.exitCode,
        sourceCommand: redactedXcodePublicText(
            result.sourceCommand,
            command: command,
            additionalSensitiveValues: additionalSensitiveValues
        ),
        stdoutTruncated: result.stdoutTruncated,
        stderrTruncated: result.stderrTruncated,
        stdoutLogPath: result.stdoutLogPath,
        stderrLogPath: result.stderrLogPath,
        stdoutBytes: result.stdoutBytes,
        stderrBytes: result.stderrBytes
    )
}

private func isXcodeRealDeviceDiscoveryCommand(_ command: TKHostCommand) -> Bool {
    let directDevicectl = command.executable == "devicectl" || command.executable.hasSuffix("/devicectl")
    let arguments = command.arguments
    return arguments.starts(with: ["devicectl", "list", "devices"])
        || (directDevicectl && arguments.starts(with: ["list", "devices"]))
}

func xcodeBuildFailureCode(
    ok: Bool,
    diagnostics: [TKXcodeOutputDiagnostic]?,
    result: HostProcessResult? = nil,
    postActionProcessStatus: TKXcodePostActionProcessStatus? = nil
) -> String? {
    guard !ok else { return nil }
    if diagnostics?.contains(where: { $0.kind == "swift-macro-plugin-malformed-response" }) == true {
        return "swift_macro_plugin_malformed_response"
    }
    if let result, xcodeBuildWasInterrupted(result) {
        return postActionProcessStatus?.active == true ? "orphaned_xcodebuild" : "xcodebuild_interrupted"
    }
    return "xcodebuild_failed"
}

func xcodePostActionProcessStatusIfInterrupted(
    ok: Bool,
    result: HostProcessResult,
    workspaceFilter: String?,
    statusProvider: (String?) throws -> XcodeProcessStatusOutput = { try currentXcodeProcessStatus(workspace: $0) }
) -> TKXcodePostActionProcessStatus? {
    guard !ok, xcodeBuildWasInterrupted(result) else { return nil }
    guard let status = try? statusProvider(workspaceFilter), status.active else { return nil }
    return status.sharedPostActionStatus()
}

func redactedXcodePostActionProcessStatus(
    _ status: TKXcodePostActionProcessStatus?,
    command: TKHostCommand
) -> TKXcodePostActionProcessStatus? {
    guard let status, !command.redactedArgumentIndexes.isEmpty else {
        return status
    }
    let statusSensitiveValues = status.processes.flatMap {
        xcodeRealDeviceDestinationSensitiveValues($0.destination)
    }
    return TKXcodePostActionProcessStatus(
        active: status.active,
        workspaceFilter: status.workspaceFilter,
        processes: status.processes.map { process in
            TKXcodeActiveProcessSummary(
                pid: process.pid,
                name: process.name,
                commandLine: redactedXcodePublicText(
                    process.commandLine,
                    command: command,
                    additionalSensitiveValues: statusSensitiveValues
                ),
                elapsed: process.elapsed,
                elapsedSeconds: process.elapsedSeconds,
                workspace: process.workspace,
                project: process.project,
                scheme: process.scheme,
                destination: process.destination.map {
                    redactedXcodePublicText(
                        $0,
                        command: command,
                        additionalSensitiveValues: statusSensitiveValues
                    )
                },
                derivedDataPath: process.derivedDataPath,
                confidence: process.confidence
            )
        },
        sourceCommand: redactedXcodePublicText(
            status.sourceCommand,
            command: command,
            additionalSensitiveValues: statusSensitiveValues
        )
    )
}

func xcodeBuildRecoveryActions(failureCode: String?, workspaceFilter: String?) -> [TKCLINextAction]? {
    guard failureCode == "orphaned_xcodebuild" || failureCode == "xcodebuild_interrupted" else {
        return nil
    }
    var waitArgs = ["wait-idle"]
    if let workspaceFilter, !workspaceFilter.isEmpty {
        waitArgs += ["--workspace", workspaceFilter]
    }
    waitArgs += ["--timeout", "120", "--json"]
    return [
        TKCLINextAction(command: "xcode", args: ["status", "--json"], category: "project"),
        TKCLINextAction(command: "xcode", args: waitArgs, category: "project"),
    ]
}

func xcodeBuildSummaryNote(
    ok: Bool,
    failureCode: String?,
    successNote: String,
    defaultFailureNote: String
) -> String {
    if ok { return successNote }
    switch failureCode {
    case "orphaned_xcodebuild":
        return "xcodebuild was interrupted while matching processes are still active. Run `triton xcode status --json`, then `triton xcode wait-idle --workspace <workspace> --timeout 120 --json` or cancel stale PIDs before retrying."
    case "xcodebuild_interrupted":
        return "xcodebuild was interrupted before Triton observed a terminal build result. Run `triton xcode status --json`; if no matching process remains, retry with a longer --timeout or inspect stdout/stderr artifacts."
    default:
        return defaultFailureNote
    }
}

private func xcodeWorkspaceFilter(for invocation: ResolvedXcodeInvocation) -> String? {
    invocation.workspace ?? invocation.project
}

private func xcodeBuildWasInterrupted(_ result: HostProcessResult) -> Bool {
    let combined = [result.stdout, result.stderr]
        .joined(separator: "\n")
        .lowercased()
    let hasInterruptedMarker = combined.contains("build interrupted")
        || combined.contains("test interrupted")
    let hasFailureMarker = combined.contains("build failed")
        || combined.contains("test failed")
    return hasInterruptedMarker || (result.exitCode == 15 && !hasFailureMarker)
}

func runXcodeHostCommand(_ command: TKHostCommand, event: String, jsonl: Bool, allowNonZeroExit: Bool = false) throws -> (HostProcessResult, Int) {
    let startedAt = Date()
    let artifactPaths = try createXcodeArtifactPaths(event: event)
    if jsonl {
        writeJSONLLine(try encodeCompactJSON(TKXcodeProgressEvent(
            event: "\(event).invocation",
            message: "started",
            sourceCommand: hostSourceCommand(command),
            elapsedMs: 0,
            stdoutLogPath: artifactPaths.stdout.path,
            stderrLogPath: artifactPaths.stderr.path,
            stdoutBytes: 0,
            stderrBytes: 0
        )))
    }
    let result = try runStreamingHostCommand(
        command,
        event: event,
        jsonl: jsonl,
        startedAt: startedAt,
        artifactPaths: artifactPaths,
        allowNonZeroExit: allowNonZeroExit
    )
    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
    if jsonl {
        writeJSONLLine(try encodeCompactJSON(TKXcodeProgressEvent(
            event: "\(event).summary",
            message: "finished",
            sourceCommand: result.sourceCommand,
            elapsedMs: durationMs,
            stdoutLogPath: result.stdoutLogPath,
            stderrLogPath: result.stderrLogPath,
            stdoutBytes: result.stdoutBytes,
            stderrBytes: result.stderrBytes
        )))
    }
    return (result, durationMs)
}

func writeJSONLLine(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

struct XcodeArtifactPaths {
    let directory: URL
    let stdout: URL
    let stderr: URL
}

final class HostStreamAccumulator {
    private let maximumBytes: Int
    private let lock = NSLock()
    private var storage = Data()
    private var didTruncate = false
    private var total = 0

    init(maximumBytes: Int = 1_048_576) {
        self.maximumBytes = maximumBytes
    }

    func append(_ data: Data) {
        lock.lock()
        total += data.count
        if storage.count < maximumBytes {
            let remaining = maximumBytes - storage.count
            storage.append(data.prefix(remaining))
        }
        if total > maximumBytes {
            didTruncate = true
        }
        lock.unlock()
    }

    func snapshot() -> (data: Data, truncated: Bool, bytes: Int) {
        lock.lock()
        let value = (storage, didTruncate, total)
        lock.unlock()
        return value
    }
}

func createXcodeArtifactPaths(event: String) throws -> XcodeArtifactPaths {
    let safeEvent = event.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
    }.joined()
    let directoryName = "\(Int(Date().timeIntervalSince1970 * 1000))-\(String(safeEvent))-\(UUID().uuidString)"
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("triton-xcode-artifacts", isDirectory: true)
        .appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return XcodeArtifactPaths(
        directory: directory,
        stdout: directory.appendingPathComponent("stdout.log"),
        stderr: directory.appendingPathComponent("stderr.log")
    )
}

func runStreamingHostCommand(
    _ command: TKHostCommand,
    event: String,
    jsonl: Bool,
    startedAt: Date,
    artifactPaths: XcodeArtifactPaths,
    allowNonZeroExit: Bool = false
) throws -> HostProcessResult {
    let timeoutSeconds = command.defaultTimeoutSeconds
    let process = Process()
    configureHostProcessExecutable(process, command: command)

    FileManager.default.createFile(atPath: artifactPaths.stdout.path, contents: nil)
    FileManager.default.createFile(atPath: artifactPaths.stderr.path, contents: nil)
    let stdoutLog = try FileHandle(forWritingTo: artifactPaths.stdout)
    let stderrLog = try FileHandle(forWritingTo: artifactPaths.stderr)
    defer {
        try? stdoutLog.close()
        try? stderrLog.close()
    }

    let stdout = Pipe()
    let stderr = Pipe()
    let stdoutAccumulator = HostStreamAccumulator()
    let stderrAccumulator = HostStreamAccumulator()
    let printLock = NSLock()
    process.standardOutput = stdout
    process.standardError = stderr

    func emitProgress(_ progress: TKXcodeProgressEvent) {
        guard let line = try? encodeCompactJSON(progress) else { return }
        printLock.lock()
        if jsonl {
            writeJSONLLine(line)
        } else {
            FileHandle.standardError.write(Data((line + "\n").utf8))
        }
        printLock.unlock()
    }

    func handleChunk(_ data: Data, stream: String, log: FileHandle, accumulator: HostStreamAccumulator) {
        guard !data.isEmpty else { return }
        log.write(data)
        accumulator.append(data)
        let snapshot = accumulator.snapshot()
        emitProgress(TKXcodeProgressEvent(
            event: "\(event).\(stream)",
            message: streamingSample(stream: stream, data: data, redacting: command),
            sourceCommand: hostSourceCommand(command),
            elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
            stdoutLogPath: artifactPaths.stdout.path,
            stderrLogPath: artifactPaths.stderr.path,
            stdoutBytes: stream == "stdout" ? snapshot.bytes : stdoutAccumulator.snapshot().bytes,
            stderrBytes: stream == "stderr" ? snapshot.bytes : stderrAccumulator.snapshot().bytes
        ))
    }

    stdout.fileHandleForReading.readabilityHandler = { handle in
        handleChunk(handle.availableData, stream: "stdout", log: stdoutLog, accumulator: stdoutAccumulator)
    }
    stderr.fileHandleForReading.readabilityHandler = { handle in
        handleChunk(handle.availableData, stream: "stderr", log: stderrLog, accumulator: stderrAccumulator)
    }

    do {
        try process.run()
    } catch {
        throw HostCommandRunError.launchFailed(error.localizedDescription)
    }

    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .utility).async {
        process.waitUntilExit()
        semaphore.signal()
    }

    let deadline = Date().addingTimeInterval(timeoutSeconds)
    var nextHeartbeat = Date().addingTimeInterval(10)
    while true {
        let now = Date()
        if now >= deadline {
            process.terminate()
            _ = semaphore.wait(timeout: .now() + 2)
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            emitProgress(TKXcodeProgressEvent(
                event: "\(event).summary",
                message: "timeout after \(timeoutSeconds)s",
                sourceCommand: hostSourceCommand(command),
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: stdoutAccumulator.snapshot().bytes,
                stderrBytes: stderrAccumulator.snapshot().bytes
            ))
            throw HostCommandRunError.timeout(
                command: command,
                timeoutSeconds: timeoutSeconds,
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path
            )
        }
        let waitSeconds = min(1.0, max(0.1, min(deadline.timeIntervalSince(now), nextHeartbeat.timeIntervalSince(now))))
        if semaphore.wait(timeout: .now() + waitSeconds) == .success {
            break
        }
        if Date() >= nextHeartbeat {
            emitProgress(TKXcodeProgressEvent(
                event: "\(event).heartbeat",
                message: "running",
                sourceCommand: hostSourceCommand(command),
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                stdoutLogPath: artifactPaths.stdout.path,
                stderrLogPath: artifactPaths.stderr.path,
                stdoutBytes: stdoutAccumulator.snapshot().bytes,
                stderrBytes: stderrAccumulator.snapshot().bytes
            ))
            nextHeartbeat = Date().addingTimeInterval(10)
        }
    }

    stdout.fileHandleForReading.readabilityHandler = nil
    stderr.fileHandleForReading.readabilityHandler = nil
    handleChunk(stdout.fileHandleForReading.availableData, stream: "stdout", log: stdoutLog, accumulator: stdoutAccumulator)
    handleChunk(stderr.fileHandleForReading.availableData, stream: "stderr", log: stderrLog, accumulator: stderrAccumulator)

    let stdoutSnapshot = stdoutAccumulator.snapshot()
    let stderrSnapshot = stderrAccumulator.snapshot()
    let result = HostProcessResult(
        stdoutData: stdoutSnapshot.data,
        stderrData: stderrSnapshot.data,
        exitCode: process.terminationStatus,
        sourceCommand: hostSourceCommand(command),
        stdoutTruncated: stdoutSnapshot.truncated,
        stderrTruncated: stderrSnapshot.truncated,
        stdoutLogPath: artifactPaths.stdout.path,
        stderrLogPath: artifactPaths.stderr.path,
        stdoutBytes: stdoutSnapshot.bytes,
        stderrBytes: stderrSnapshot.bytes
    )
    if result.exitCode != 0, !allowNonZeroExit {
        throw HostCommandRunError.nonZeroExit(command: command, result: result)
    }
    return result
}

struct XcodeTestResultBundleDetails {
    let summary: TKXcresultSummaryMetrics?
    let topFailures: [TKXcresultFailureRecord]?
    let note: String?
}

func xcodeTestResultBundleDetails(
    resultBundlePath: String?,
    maximumFailures: Int = 3,
    redacting command: TKHostCommand? = nil,
    runCommand: (TKHostCommand) throws -> HostProcessResult = { command in
        try runHostCommand(command, maximumOutputBytes: xcresultInlineJSONLimit)
    }
) -> XcodeTestResultBundleDetails {
    guard let resultBundlePath, !resultBundlePath.isEmpty else {
        return XcodeTestResultBundleDetails(summary: nil, topFailures: nil, note: nil)
    }

    do {
        let summaryResult = try runCommand(TKXcresultCommand.summary(path: resultBundlePath))
        let testsResult = try runCommand(TKXcresultCommand.tests(path: resultBundlePath))
        let output = try makeHostXcresultFailuresOutput(
            path: resultBundlePath,
            includeSensitive: false,
            summaryResult: summaryResult,
            testsResult: testsResult
        )
        let exactValues = command.map { xcodeExecutionSensitiveValues(command: $0) } ?? []
        let publicSummary = exactValues.isEmpty
            ? output.summary
            : TKXcresultRedaction.redact(output.summary, exactValues: exactValues)
        let publicFailures = exactValues.isEmpty
            ? output.failures
            : TKXcresultRedaction.redact(output.failures, exactValues: exactValues)
        let topFailures = Array(publicFailures.prefix(maximumFailures))
        let note = publicFailures.count > maximumFailures
            ? "Showing top \(maximumFailures) of \(publicFailures.count) failures. Use `triton xcresult failures --path <result.xcresult> --json` for the full list."
            : nil
        return XcodeTestResultBundleDetails(
            summary: publicSummary,
            topFailures: topFailures,
            note: note
        )
    } catch {
        let errorDescription = String(describing: error)
        let publicErrorDescription = command.map {
            redactedXcodePublicText(errorDescription, command: $0)
        } ?? TKXcresultRedaction.redact(errorDescription)
        return XcodeTestResultBundleDetails(
            summary: nil,
            topFailures: [],
            note: "Result bundle was not parsed for inline failures: \(publicErrorDescription)"
        )
    }
}

func streamingSample(
    stream: String,
    data: Data,
    maximumBytes: Int = 2_000,
    redacting command: TKHostCommand? = nil
) -> String {
    let prefix = data.prefix(maximumBytes)
    let text = String(data: prefix, encoding: .utf8) ?? "<\(data.count) bytes>"
    let suffix = data.count > maximumBytes ? " ...<truncated>" : ""
    let sample = "\(stream): \(text)\(suffix)"
    return command.map { redactedXcodePublicText(sample, command: $0) } ?? sample
}

func resolveBuiltAppProduct(
    invocation: ResolvedXcodeInvocation,
    timeout: Double? = nil,
    jsonl: Bool = false,
    event: String = "xcode.settings.resolve"
) throws -> TKXcodeBuiltAppProduct {
    let executionInvocation = try preparedXcodeInvocationForExecution(invocation)
    let command = TKXcodebuildCommand.showBuildSettings(
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.xcodebuildDestination,
        derivedDataPath: executionInvocation.derivedDataPath,
        buildSettings: executionInvocation.buildSettings,
        redactDestination: executionInvocation.redactsXcodebuildDestination
    ).withTimeout(timeout)
    let result: HostProcessResult
    if jsonl {
        result = try runXcodeHostCommand(command, event: event, jsonl: true).0
    } else {
        result = try runHostCommand(command)
    }
    do {
        return try TKXcodeBuildSettingsParser.resolveBuiltApp(result.stdoutData)
    } catch {
        throw XcodeWorkflowError.appPathUnresolved
    }
}

func bundleIdentifier(appPath: String) throws -> String {
    let infoURL = URL(fileURLWithPath: appPath).appendingPathComponent("Info.plist")
    let data = try Data(contentsOf: infoURL)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    guard let dictionary = plist as? [String: Any],
          let bundleID = dictionary["CFBundleIdentifier"] as? String,
          !bundleID.isEmpty else {
        throw XcodeWorkflowError.bundleIDUnresolved(appPath)
    }
    return bundleID
}

func printXcodeSummary(_ summary: TKXcodeActionSummary, jsonl: Bool, outputFormat: ClientOutputFormat) throws {
    if jsonl || outputFormat == .json {
        if jsonl {
            print(try encodeCompactJSON(summary))
        } else {
            print(try encodeJSON(summary))
        }
    } else {
        if let appPath = summary.appPath {
            print(appPath)
        } else {
            print(summary.action)
        }
    }
}
