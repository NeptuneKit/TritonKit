import Foundation
import TritonKitShared

func runHostSimulatorProcessConsoleCommand(
    simulator: String,
    bundleID: String,
    command: TKHostCommand,
    outputPath: String,
    requestedDurationSeconds: Double,
    maximumBytes: Int,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let preflightCommand = TKSimctlCommand.appInfo(udid: simulator, bundleID: bundleID)
        let preflightSourceCommand = hostSourceCommand(preflightCommand)
        do {
            let preflight = try runHostCommand(preflightCommand)
            _ = try TKSimctlAppInfoParser.parseAppInfo(preflight.stdoutData, bundleID: bundleID)
        } catch {
            throw HostSimulatorProcessConsoleError.appUnavailable(
                bundleID: bundleID,
                sourceCommand: preflightSourceCommand,
                reason: "\(error)"
            )
        }
        let result = try runHostCommandWritingCombinedOutputArtifact(
            command,
            outputPath: outputPath,
            interruptAfter: requestedDurationSeconds,
            maximumBytes: maximumBytes
        )
        let output = HostSimulatorProcessConsoleOutput(
            ok: true,
            action: "sim.app-console",
            runtimeScope: "host-simulator",
            target: "sim:\(simulator)",
            bundleID: bundleID,
            tool: command.executable,
            exitCode: result.exitCode,
            riskLevel: command.riskLevel.rawValue,
            sourceCommand: result.sourceCommand,
            sourceCommands: [preflightSourceCommand, result.sourceCommand],
            artifact: outputPath,
            artifactBytes: result.artifactBytes,
            observedBytes: result.observedBytes,
            artifactTruncated: result.artifactTruncated,
            maximumBytes: maximumBytes,
            requestedDurationSeconds: requestedDurationSeconds,
            elapsedDurationSeconds: result.elapsedDurationSeconds,
            captureEndedBy: result.captureEndedBy,
            terminationReason: result.terminationReason,
            sourcesCaptured: ["process-stdout", "process-stderr"],
            streamLayout: "merged-pty",
            artifactSensitive: true,
            note: result.artifactTruncated
                ? "App process console was captured through a merged PTY and truncated at --max-bytes. The command terminates any running App instance before launch."
                : "App process console was captured through a merged PTY. The command terminates any running App instance before launch."
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(output))
        case .text:
            print(outputPath)
            print(output.note)
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}
