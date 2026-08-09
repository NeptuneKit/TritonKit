import ArgumentParser
import Foundation
import TritonKitShared

struct SimTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Tap host-side simulator coordinates",
        shouldDisplay: false
    )

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Screen x coordinate in simulator points") var x: Int
    @Option(help: "Screen y coordinate in simulator points") var y: Int
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(
                    device: simulator,
                    platform: .ios,
                    scope: .simulator
                ),
                hdc: "hdc",
                adb: "adb"
            )
            let result = try runWebHostDeviceInput(
                id: webHostDeviceTargetID(selection.target),
                input: .tap(x: Double(x), y: Double(y))
            )
            guard result.ok else {
                let error = result.error ?? TKCLIErrorDetail(
                    code: "host_input_failed",
                    message: result.message ?? "The iOS Simulator host HID tap was not accepted.",
                    hint: "Verify the simulator is booted and the host HID adapter is available, then retry with the resolved simulator selector."
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(TKCLIErrorResponse(error: error)))
                case .text:
                    print(error.message)
                    if let hint = error.hint {
                        print("hint: \(hint)")
                    }
                }
                throw ExitCode.failure
            }
            switch outputFormat {
            case .json:
                print(try encodeJSON(result))
            case .text:
                print(result.message ?? "iOS Simulator tap submitted through the host HID adapter.")
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
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
        try failHostValidation(
            code: "unsupported_host_input",
            message: "sim type is not supported by the current public simctl io contract.",
            hint: "This Xcode simctl io help does not expose a stable keyboard type primitive. Use embedded runtime semantic input or a pasteboard/debug-hook flow.",
            outputFormat: outputFormat
        )
    }
}
