import Foundation
import TritonKitShared

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
        let limit = max(0, min(3, maximumFailures))
        let boundedSummary = try boundedXcodeInlineValue(publicSummary)
        let boundedFailures = try publicFailures.prefix(limit).map { try boundedXcodeInlineValue($0) }
        let topFailures = boundedFailures.map(\.value)
        var notes: [String] = []
        if publicFailures.count > limit {
            notes.append("Showing top \(limit) of \(publicFailures.count) failures.")
        }
        if boundedSummary.truncated || boundedFailures.contains(where: \.truncated) {
            notes.append("Inline details were truncated to bounded text and array samples.")
        }
        let note = notes.isEmpty ? nil : (notes + ["Use `triton xcresult failures --path <result.xcresult> --json` for the full list."]).joined(separator: " ")
        return XcodeTestResultBundleDetails(
            summary: boundedSummary.value,
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
            note: "Result bundle was not parsed for inline failures: \(String(publicErrorDescription.prefix(2_000)))"
        )
    }
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

/// Keep result counts and DTO fields while bounding potentially huge xcresult
/// prose and collections. Full details remain available via `xcresult failures`.
private func boundedXcodeInlineValue<Value: Codable>(_ value: Value) throws -> (value: Value, truncated: Bool) {
    var remainingTextBytes = 8_192
    var truncated = false
    func bounded(_ object: Any) -> Any {
        if let text = object as? String {
            let limit = min(2_000, remainingTextBytes)
            let bytes = Data(text.utf8)
            remainingTextBytes -= min(limit, bytes.count)
            guard bytes.count > limit else { return text }
            truncated = true
            return String(decoding: bytes.prefix(limit), as: UTF8.self) + " ...<truncated>"
        }
        if let items = object as? [Any] {
            if items.count > 8 { truncated = true }
            return items.prefix(8).map(bounded)
        }
        if let fields = object as? [String: Any] {
            // Spend the text budget on the outcome before optional metadata.
            let outcomeKeys = ["result", "status", "testName", "message"]
            let keys = outcomeKeys.filter { fields[$0] != nil }
                + fields.keys.filter { !outcomeKeys.contains($0) }.sorted()
            return Dictionary(uniqueKeysWithValues: keys.map { ($0, bounded(fields[$0]!)) })
        }
        return object
    }
    let encoded = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: encoded)
    let boundedData = try JSONSerialization.data(withJSONObject: bounded(object))
    return (try JSONDecoder().decode(Value.self, from: boundedData), truncated)
}
