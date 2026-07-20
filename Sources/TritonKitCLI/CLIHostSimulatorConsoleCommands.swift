import ArgumentParser
import Foundation
import TritonKitShared

struct SimAppConsole: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app-console",
        abstract: "Capture bounded iOS Simulator App stdout/stderr through a merged PTY artifact"
    )

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(name: .customLong("bundle-id"), help: "Installed App bundle identifier") var bundleID: String
    @Option(help: "Merged process stdout/stderr artifact path") var output: String
    @Option(help: "Capture duration in seconds before interrupting simctl and the App") var duration: Double = 10
    @Option(name: .customLong("max-bytes"), help: "Maximum artifact bytes written while continuing to drain process output") var maximumBytes: Int = 10_485_760
    @Option(name: .customLong("env"), help: "Repeatable KEY=VALUE App launch environment; values are redacted from sourceCommand") var launchEnvironment: [String] = []
    @Option(name: .customLong("arg"), help: "Repeatable App launch argument") var launchArguments: [String] = []
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard duration > 0 else {
            try failHostValidation(
                code: "invalid_duration",
                message: "--duration must be greater than 0.",
                hint: "Pass a positive process console capture duration in seconds.",
                outputFormat: outputFormat
            )
        }
        guard maximumBytes > 0 else {
            try failHostValidation(
                code: "invalid_max_bytes",
                message: "--max-bytes must be greater than 0.",
                hint: "Pass a positive maximum artifact size in bytes.",
                outputFormat: outputFormat
            )
        }
        let environment: [String: String]
        do {
            environment = try parseLaunchEnvironment(launchEnvironment)
        } catch {
            try failHostValidation(
                code: "validation_failed",
                message: "\(error)",
                hint: "Pass each App environment value as --env KEY=VALUE.",
                outputFormat: outputFormat
            )
        }
        try runHostSimulatorProcessConsoleCommand(
            simulator: simulator,
            bundleID: bundleID,
            command: TKSimctlCommand.appProcessConsole(
                udid: simulator,
                bundleID: bundleID,
                environment: environment,
                arguments: launchArguments,
                defaultTimeoutSeconds: duration + 10
            ),
            outputPath: output,
            requestedDurationSeconds: duration,
            maximumBytes: maximumBytes,
            outputFormat: outputFormat
        )
    }
}
