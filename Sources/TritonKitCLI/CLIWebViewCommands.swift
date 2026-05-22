import ArgumentParser
import TritonKitShared

struct WebView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "webview",
        abstract: "Inspect current WebView candidates without claiming DOM or bridge access",
        subcommands: [WebViewList.self, WebViewCurrent.self]
    )
}

struct WebViewList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List visible WebView candidates")

    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Write host layout artifact to a file for Harmony") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runWebViewList(
            platform: platform,
            target: target,
            hdc: hdc,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            output: output,
            format: format,
            json: json
        )
    }
}

struct WebViewCurrent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current", abstract: "Resolve the current visible WebView candidate")

    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Select a candidate id from `triton webview list`") var webviewID: String?
    @Option(help: "Write host layout artifact to a file for Harmony") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runWebViewCurrent(
            platform: platform,
            target: target,
            hdc: hdc,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            webViewID: webviewID,
            output: output,
            format: format,
            json: json
        )
    }
}
