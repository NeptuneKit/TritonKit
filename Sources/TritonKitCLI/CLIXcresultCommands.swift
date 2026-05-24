import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - xcresult Commands

private let xcresultInlineJSONLimit = 16 * 1_024 * 1_024

struct Xcresult: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcresult",
        abstract: "Inspect Xcode result bundles through Triton artifact contracts",
        subcommands: [XcresultSummary.self, XcresultFailures.self]
    )
}

struct XcresultSummary: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "summary", abstract: "Read test counts and environment summary from an .xcresult bundle")

    @Option(help: "Input .xcresult bundle path") var path: String
    @Flag(help: "Include private paths, emails, and token-like values in output") var includeSensitive = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let command = TKXcresultCommand.summary(path: path)
            let result = try runHostCommand(command, maximumOutputBytes: xcresultInlineJSONLimit)
            let output = try makeHostXcresultSummaryOutput(path: path, includeSensitive: includeSensitive, result: result)
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print("\(output.summary.result)\tpassed=\(output.summary.passedTests)\tfailed=\(output.summary.failedTests)\tskipped=\(output.summary.skippedTests)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcresultFailures: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "failures", abstract: "Read structured failing test cases from an .xcresult bundle")

    @Option(help: "Input .xcresult bundle path") var path: String
    @Flag(help: "Include private paths, emails, and token-like values in output") var includeSensitive = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let summaryResult = try runHostCommand(TKXcresultCommand.summary(path: path), maximumOutputBytes: xcresultInlineJSONLimit)
            let testsResult = try runHostCommand(TKXcresultCommand.tests(path: path), maximumOutputBytes: xcresultInlineJSONLimit)
            let output = try makeHostXcresultFailuresOutput(path: path, includeSensitive: includeSensitive, summaryResult: summaryResult, testsResult: testsResult)
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                if output.failures.isEmpty {
                    print("no failures")
                } else {
                    for failure in output.failures {
                        var line = "\(failure.targetName)\t\(failure.testName)\t\(failure.message)"
                        if let location = failure.location {
                            line += "\t\(location)"
                        }
                        print(line)
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

func makeHostXcresultSummaryOutput(path: String, includeSensitive: Bool, result: HostProcessResult) throws -> HostXcresultSummaryOutput {
    if result.stdoutTruncated {
        throw XcresultCLIError.outputTooLarge(kind: "summary", bytes: result.stdoutBytes, maximumBytes: xcresultInlineJSONLimit)
    }
    let summary: TKXcresultSummaryMetrics
    do {
        summary = try TKXcresultSummaryParser.parse(result.stdoutData)
    } catch {
        throw XcresultCLIError.parseFailed(kind: "summary", underlying: error)
    }
    let publicPath = includeSensitive ? path : TKXcresultRedaction.redact(path)
    let publicSummary = includeSensitive ? summary : TKXcresultRedaction.redact(summary)
    let publicSourceCommand = includeSensitive ? result.sourceCommand : TKXcresultRedaction.redact(result.sourceCommand)
    return HostXcresultSummaryOutput(
        ok: true,
        action: "xcresult.summary",
        path: publicPath,
        summary: publicSummary,
        sourceCommand: publicSourceCommand,
        redaction: includeSensitive ? "included-sensitive" : "default",
        note: "Use `triton xcresult failures --path <result.xcresult> --json` for a structured failure list."
    )
}

func makeHostXcresultFailuresOutput(path: String, includeSensitive: Bool, summaryResult: HostProcessResult, testsResult: HostProcessResult) throws -> HostXcresultFailuresOutput {
    if summaryResult.stdoutTruncated {
        throw XcresultCLIError.outputTooLarge(kind: "summary", bytes: summaryResult.stdoutBytes, maximumBytes: xcresultInlineJSONLimit)
    }
    let summary: TKXcresultSummaryMetrics
    do {
        summary = try TKXcresultSummaryParser.parse(summaryResult.stdoutData)
    } catch {
        throw XcresultCLIError.parseFailed(kind: "summary", underlying: error)
    }
    if testsResult.stdoutTruncated {
        throw XcresultCLIError.outputTooLarge(kind: "tests", bytes: testsResult.stdoutBytes, maximumBytes: xcresultInlineJSONLimit)
    }
    let failures: [TKXcresultFailureRecord]
    do {
        failures = try TKXcresultTestsParser.parseFailures(testsResult.stdoutData)
    } catch {
        throw XcresultCLIError.parseFailed(kind: "tests", underlying: error)
    }
    let publicPath = includeSensitive ? path : TKXcresultRedaction.redact(path)
    let publicSummary = includeSensitive ? summary : TKXcresultRedaction.redact(summary)
    let publicFailures = includeSensitive ? failures : TKXcresultRedaction.redact(failures)
    let publicSourceCommands = includeSensitive
        ? [summaryResult.sourceCommand, testsResult.sourceCommand]
        : [summaryResult.sourceCommand, testsResult.sourceCommand].map(TKXcresultRedaction.redact(_:))
    return HostXcresultFailuresOutput(
        ok: true,
        action: "xcresult.failures",
        path: publicPath,
        summary: publicSummary,
        failures: publicFailures,
        sourceCommands: publicSourceCommands,
        redaction: includeSensitive ? "included-sensitive" : "default",
        note: publicFailures.isEmpty ? "No failing tests were found in the result bundle." : nil
    )
}

struct HostXcresultSummaryOutput: Encodable {
    let ok: Bool
    let action: String
    let path: String
    let summary: TKXcresultSummaryMetrics
    let sourceCommand: String
    let redaction: String
    let note: String?
}

struct HostXcresultFailuresOutput: Encodable {
    let ok: Bool
    let action: String
    let path: String
    let summary: TKXcresultSummaryMetrics
    let failures: [TKXcresultFailureRecord]
    let sourceCommands: [String]
    let redaction: String
    let note: String?
}
