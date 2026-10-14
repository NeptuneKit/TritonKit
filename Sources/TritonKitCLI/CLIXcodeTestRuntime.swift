import Foundation
import TritonKitShared

func runXcodeTest(
    invocation: ResolvedXcodeInvocation,
    resultBundlePath: String?,
    onlyTesting: [String] = [],
    jsonl: Bool,
    timeout: Double? = nil,
    progress: XcodeProgressMode = .compact,
    preparedManifest: PreparedTestsManifest? = nil,
    toolchainProvider: () throws -> PreparedTestsToolchain = currentPreparedTestsToolchain,
    statusProvider: (String?) throws -> XcodeProcessStatusOutput = { try currentXcodeProcessStatus(workspace: $0) },
    hostCommandRunner: (TKHostCommand, String, Bool, XcodeProgressMode) throws -> (HostProcessResult, Int) = { command, event, jsonl, progress in
        try runXcodeHostCommand(command, event: event, jsonl: jsonl, allowNonZeroExit: true, progress: progress)
    },
    resultCommandRunner: (TKHostCommand) throws -> HostProcessResult = { command in
        try runHostCommand(command, maximumOutputBytes: xcresultInlineJSONLimit)
    }
) throws -> TKXcodeActionSummary {
    let onlyTesting = try validateXcodeOnlyTesting(onlyTesting)
    let executionInvocation = try preparedXcodeInvocationForExecution(invocation)
    let resolvedResultBundlePath: String?
    let command: TKHostCommand
    if let preparedManifest {
        try validatePreparedTestsManifest(preparedManifest, invocation: executionInvocation, toolchain: toolchainProvider())
        resolvedResultBundlePath = try freshPreparedTestsResultPath(resultBundlePath, package: executionInvocation.package)
        command = TKXcodebuildCommand.testPrepared(artifactPath: preparedManifest.artifact,
            destination: executionInvocation.xcodebuildDestination!, resultBundlePath: resolvedResultBundlePath!,
            onlyTesting: onlyTesting, redactDestination: executionInvocation.redactsXcodebuildDestination).withTimeout(timeout)
    } else {
        resolvedResultBundlePath = xcodePackageArtifactPath(resultBundlePath, package: executionInvocation.package)
        if let resolvedResultBundlePath { try validatePreparedTestsPath(resolvedResultBundlePath, mustBeFresh: true) }
        command = TKXcodebuildCommand.test(
            workspace: executionInvocation.workspace,
            project: executionInvocation.project,
            package: executionInvocation.package,
            scheme: executionInvocation.scheme,
            configuration: executionInvocation.configuration,
            sdk: executionInvocation.sdk,
            destination: executionInvocation.xcodebuildDestination,
            derivedDataPath: executionInvocation.derivedDataPath,
            resultBundlePath: resolvedResultBundlePath,
            buildSettings: executionInvocation.buildSettings,
            onlyTesting: onlyTesting,
            redactDestination: executionInvocation.redactsXcodebuildDestination
        ).withTimeout(timeout)
    }
    let (result, durationMs) = try hostCommandRunner(command, "xcode.test", jsonl, progress)
    if let preparedManifest {
        try validatePreparedTestsManifest(preparedManifest, invocation: executionInvocation, toolchain: toolchainProvider())
    }
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
        resultBundlePath: resolvedResultBundlePath,
        redacting: command,
        runCommand: resultCommandRunner
    )
    var resultIsDirectory: ObjCBool = false
    let resultWasProduced = resolvedResultBundlePath.map {
        FileManager.default.fileExists(atPath: $0, isDirectory: &resultIsDirectory) && resultIsDirectory.boolValue && (try? validatePreparedTestsPath($0)) != nil
    } ?? false
    let preparedResultsComplete = preparedManifest == nil ||
        (resultWasProduced && (resultDetails.summary.map { $0.totalTestCount > 0 && $0.passedTests > 0 && $0.failedTests == 0 && $0.status == "passed" } ?? false))
    return TKXcodeActionSummary(
        ok: ok && preparedResultsComplete,
        action: "xcode.test",
        failureCode: failureCode ?? (preparedResultsComplete ? nil : "prepared_tests_result_incomplete"),
        workspace: executionInvocation.workspace,
        project: executionInvocation.project,
        package: executionInvocation.package,
        scheme: executionInvocation.scheme,
        configuration: executionInvocation.configuration,
        sdk: executionInvocation.sdk,
        destination: executionInvocation.destination,
        derivedDataPath: executionInvocation.derivedDataPath,
        derivedDataCache: observedXcodeDerivedDataCache(executionInvocation.derivedDataCache, result: result),
        resultBundlePath: resolvedResultBundlePath,
        onlyTesting: onlyTesting.isEmpty ? nil : onlyTesting,
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
