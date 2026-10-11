import ArgumentParser

struct DevicePlatformControl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "platform-control", abstract: "Describe watchOS/tvOS public control contracts without executing device input")

    @Option(help: "Apple family: watchos|tvos|visionos|macos") var platform: HostApplePlatformControlPlatform
    @Option(help: "Control vocabulary: crown-rotate|action-button|remote-up|remote-down|remote-left|remote-right|remote-select|remote-menu|focus|side-button|gaze|pinch|scene") var action: HostApplePlatformControlAction
    @Option(help: "watchOS crown delta; finite non-zero value in -1000...1000, required only for crown-rotate") var delta: Double?
    @Option(help: "Exact Simulator UDID for an explicit XCTest runner execution") var device: String?
    @Option(name: .customLong("xctestrun"), help: "Absolute private .xctestrun bundle for an explicit runner execution") var xctestrun: String?
    @Option(name: .customLong("test-identifier"), help: "One XCTest target/class[/method] identifier") var testIdentifier: String?
    @Option(name: .customLong("result-bundle"), help: "Fresh private .xcresult path") var resultBundle: String?
    @Option(help: "Runner timeout in seconds") var timeout: Double = 120
    @Option(name: .customLong("audit-record"), help: "Opaque audit record for explicit runner execution") var auditRecord: String?
    @Flag(name: .customLong("execute-runner"), help: "Allow one explicit XCTest runner invocation") var executeRunner = false
    @Flag(help: "Confirm the explicit runner input may be delivered") var confirm = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let runnerRequested = executeRunner || confirm || device != nil || xctestrun != nil || testIdentifier != nil || resultBundle != nil || auditRecord != nil
            if runnerRequested {
                guard let device, let xctestrun, let testIdentifier, let auditRecord else {
                    throw HostApplePlatformControlError(code: "runner_options_incomplete", message: "Explicit runner execution requires --device, --xctestrun, --test-identifier, --result-bundle, and --audit-record.", hint: "Omit runner options for fixture-only planning, or provide the complete audited runner request.")
                }
                let request = try makeApplePlatformRunnerRequest(platform: platform, action: action, device: device, xctestrun: xctestrun, testIdentifier: testIdentifier, resultBundle: resultBundle, nonce: auditRecord, timeout: timeout, executeRunner: executeRunner, confirm: confirm, auditRecord: auditRecord)
                let receipt = try executeApplePlatformRunner(request)
                switch outputFormat {
                case .json: print(try encodeJSON(receipt))
                case .text: print("\(receipt.platform.rawValue)\t\(receipt.control.rawValue)\t\(receipt.outcome.rawValue)\t\(receipt.verification)")
                }
                return
            }
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
