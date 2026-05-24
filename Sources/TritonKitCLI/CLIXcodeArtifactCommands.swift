import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - Xcode Artifact Commands

struct Xctrace: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xctrace",
        abstract: "Capture Instruments traces through Triton artifact contracts",
        subcommands: [XctraceRecord.self]
    )
}

struct XctraceRecord: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "record", abstract: "Record an Instruments .trace artifact")

    @Option(help: "Instruments template name or path") var template: String = "Time Profiler"
    @Option(help: "Output .trace path") var output: String
    @Option(help: "Simulator/device UDID or name") var device: String?
    @Option(help: "Recording time limit, for example 5s, 500ms, 1m") var timeLimit: String?
    @Flag(help: "Record all processes") var allProcesses = false
    @Option(help: "Attach to process name or pid") var attach: String?
    @Flag(name: .customLong("launch"), help: "Launch a command under Instruments") var launch = false
    @Flag(help: "Append a run to an existing trace") var appendRun = false
    @Option(help: "Run name when appending or labeling the trace") var runName: String?
    @Option(help: "Host command timeout in seconds") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Argument(parsing: .remaining, help: "Optional launch command after --") var launchCommand: [String] = []

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let effectiveAllProcesses = allProcesses || (attach == nil && !launch && launchCommand.isEmpty)
        do {
            try ensureParentDirectory(for: output)
            try runSimpleHostCommand(
                action: "xctrace.record",
                runtimeScope: "host-xcode",
                target: device.map { "device:\($0)" } ?? "host",
                command: TKXctraceCommand.record(
                    template: template,
                    output: output,
                    device: device,
                    timeLimit: timeLimit,
                    allProcesses: effectiveAllProcesses,
                    attach: attach,
                    launchCommand: launch ? launchCommand : [],
                    appendRun: appendRun,
                    runName: runName
                ).withTimeout(timeout),
                outputFormat: outputFormat,
                artifacts: [output],
                note: "Instruments trace recording was written."
            )
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct Coverage: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "coverage",
        abstract: "Extract Xcode coverage reports through bounded artifacts",
        subcommands: [CoverageReport.self]
    )
}

struct CoverageReport: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "report", abstract: "Write xccov report JSON from an .xcresult bundle")

    @Option(help: "Input .xcresult bundle path") var xcresult: String
    @Option(help: "Output JSON artifact path") var output: String
    @Flag(help: "Only list coverage targets") var onlyTargets = false
    @Option(help: "List files for a target") var target: String?
    @Option(help: "List functions for a file name or path") var file: String?
    @Option(help: "Host command timeout in seconds") var timeout: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        let mode: TKXccovReportMode
        do {
            mode = try reportMode()
        } catch let error as ValidationError {
            try failHostValidation(
                code: "validation_failed",
                message: "\(error)",
                hint: "Use only one of --only-targets, --target, or --file.",
                outputFormat: outputFormat
            )
        }
        try runHostCommandCapturingStdoutArtifact(
            action: "coverage.report",
            runtimeScope: "host-xcode",
            target: "xcresult:\(xcresult)",
            command: TKXccovCommand.viewReport(
                xcresult: xcresult,
                mode: mode,
                json: true
            ).withTimeout(timeout),
            outputPath: output,
            outputFormat: outputFormat,
            note: "Coverage report JSON was written."
        )
    }

    private func reportMode() throws -> TKXccovReportMode {
        let selected = [onlyTargets, target != nil, file != nil].filter { $0 }.count
        guard selected <= 1 else {
            throw ValidationError("Use only one of --only-targets, --target, or --file.")
        }
        if onlyTargets {
            return .onlyTargets
        }
        if let target {
            return .filesForTarget(target)
        }
        if let file {
            return .functionsForFile(file)
        }
        return .summary
    }
}
