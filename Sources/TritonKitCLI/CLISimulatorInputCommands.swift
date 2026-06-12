import ArgumentParser
import Foundation
import TritonKitShared

struct SimTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tap", abstract: "Tap host-side simulator coordinates")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Screen x coordinate in simulator points") var x: Int
    @Option(help: "Screen y coordinate in simulator points") var y: Int
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        try runHostSimulatorInputCommand(
            action: "sim.tap",
            simulator: simulator,
            command: TKSimctlCommand.tap(udid: simulator, x: x, y: y),
            outputFormat: effectiveFormat(format, json: json),
            x: x,
            y: y
        )
    }
}

struct SimType: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type", abstract: "Type ASCII text into the focused simulator field")

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "ASCII text to type into the focused simulator field") var text: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard !text.isEmpty else {
            try failHostValidation(
                code: "validation_failed",
                message: "sim type requires non-empty --text.",
                hint: "Pass ASCII text with --text after focusing the destination field.",
                outputFormat: outputFormat
            )
        }
        guard text.unicodeScalars.allSatisfy(\.isASCII) else {
            try failHostValidation(
                code: "unsupported_text_input",
                message: "sim type currently supports ASCII text only.",
                hint: "Use embedded runtime semantic input, a pasteboard flow, or wait for a Unicode-safe host primitive.",
                outputFormat: outputFormat
            )
        }
        try runHostSimulatorInputCommand(
            action: "sim.type",
            simulator: simulator,
            command: TKSimctlCommand.typeText(udid: simulator, text: text),
            outputFormat: outputFormat,
            insertedLength: text.count,
            textEncoding: "ascii"
        )
    }
}
