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

struct SimSwipe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swipe",
        abstract: "Swipe host-side simulator coordinates without an embedded server"
    )

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "Swipe start x coordinate in simulator points") var startX: Int
    @Option(help: "Swipe start y coordinate in simulator points") var startY: Int
    @Option(help: "Swipe end x coordinate in simulator points") var endX: Int
    @Option(help: "Swipe end y coordinate in simulator points") var endY: Int
    @Option(help: "Source coordinate-space width; supply together with --height") var width: Int?
    @Option(help: "Source coordinate-space height; supply together with --width") var height: Int?
    @Option(help: "Gesture duration in seconds (0 < duration <= 10)") var duration: Double = 0.35
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard duration.isFinite, duration > 0, duration <= 10 else {
            try failHostValidation(
                code: "invalid_duration",
                message: "sim swipe requires a finite duration greater than zero and at most 10 seconds.",
                hint: "Pass a positive --duration in seconds.",
                outputFormat: outputFormat
            )
        }
        guard [startX, startY, endX, endY].allSatisfy({ (0...1_000_000).contains($0) }),
              (width == nil && height == nil) || (width.map { (1...1_000_000).contains($0) } == true && height.map { (1...1_000_000).contains($0) } == true),
              width.map({ startX <= $0 && endX <= $0 }) ?? true,
              height.map({ startY <= $0 && endY <= $0 }) ?? true else {
            try failHostValidation(code: "validation_failed", message: "Swipe coordinates must be nonnegative and bounded; supply positive --width/--height together with endpoints inside that source space.", hint: "Use Simulator points without dimensions, or pass both dimensions of the source image.", outputFormat: outputFormat)
        }
        do {
            let selection = try resolveHostDeviceSelection(
                request: HostDeviceSelectionRequest(
                    device: simulator,
                    platform: .ios,
                    scope: .simulator,
                    ready: true
                ),
                hdc: "hdc",
                adb: "adb"
            )
            let result = try runSimulatorSwipe(
                selected: selection.target,
                input: .swipe(
                    startX: Double(startX),
                    startY: Double(startY),
                    endX: Double(endX),
                    endY: Double(endY),
                    width: width.map(Double.init),
                    height: height.map(Double.init),
                    duration: duration
                )
            )
            guard result.ok else {
                let error = result.error ?? TKCLIErrorDetail(
                    code: "host_input_failed",
                    message: result.message ?? "The iOS Simulator host HID swipe was not accepted.",
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
                print(result.message ?? "iOS Simulator swipe submitted through the host HID adapter.")
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct SimType: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Reserved host-side simulator text entry; currently unavailable (returns unsupported_host_input)"
    )

    @Option(help: "Simulator UDID or booted") var simulator: String = "booted"
    @Option(help: "ASCII text to validate before returning unsupported_host_input; does not insert text") var text: String
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    private static let unsupportedHint = "Stage text only with `triton sim pasteboard set <text> --simulator <udid|booted> --json`; this does not paste into the focused field. Use embedded runtime semantic input, an app-owned debug hook, or an external keyboard/paste adapter, then verify the field with host AX/observe and the app's saved value."

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        guard !text.isEmpty else {
            try failHostValidation(
                code: "validation_failed",
                message: "sim type requires non-empty --text.",
                hint: "This reserved command validates non-empty ASCII text, then returns unsupported_host_input without inserting it.",
                outputFormat: outputFormat
            )
        }
        guard text.unicodeScalars.allSatisfy(\.isASCII) else {
            try failHostValidation(
                code: "unsupported_text_input",
                message: "sim type rejects non-ASCII text; host text insertion remains unavailable.",
                hint: "Use embedded runtime semantic input or an app-owned debug hook; pasteboard staging still does not insert text.",
                outputFormat: outputFormat
            )
        }
        try failHostValidation(
            code: "unsupported_host_input",
            message: "sim type is not supported by the current public simctl io contract.",
            hint: Self.unsupportedHint,
            outputFormat: outputFormat
        )
    }
}
