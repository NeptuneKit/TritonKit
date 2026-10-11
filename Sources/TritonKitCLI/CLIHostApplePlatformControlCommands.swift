import ArgumentParser

struct DevicePlatformControl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "platform-control", abstract: "Describe watchOS/tvOS public control contracts without executing device input")

    @Option(help: "Apple family: watchos|tvos|visionos|macos") var platform: HostApplePlatformControlPlatform
    @Option(help: "Control vocabulary: crown-rotate|action-button|remote-up|remote-down|remote-left|remote-right|remote-select|remote-menu|focus|side-button|gaze|pinch|scene") var action: HostApplePlatformControlAction
    @Option(help: "watchOS crown delta; finite non-zero value in -1000...1000, required only for crown-rotate") var delta: Double?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let output = try makeApplePlatformControlPlan(platform: platform, action: action, crownDelta: delta)
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text: print("\(output.platform.rawValue)\t\(output.control.rawValue)\t\(output.capabilityState.rawValue)\t\(output.verification)")
            }
        } catch let error as HostApplePlatformControlError {
            try failHostValidation(code: error.code, message: error.message, hint: error.hint, outputFormat: outputFormat)
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
