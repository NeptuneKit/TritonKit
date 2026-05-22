import ArgumentParser
import TritonKitShared

struct WebView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "webview",
        abstract: "Inspect current WebView candidates without claiming DOM or bridge access",
        subcommands: [WebViewList.self, WebViewCurrent.self, WebViewCurrentURL.self, WebViewCall.self, WebViewEvents.self]
    )
}

struct Route: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "route",
        abstract: "Assert route and WebView navigation state",
        subcommands: [RouteAssertCurrentURL.self]
    )
}

struct WebViewEvents: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "events", abstract: "Read buffered opt-in WebView page events")

    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Maximum events to return") var limit: Int = 50
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runWebViewEvents(
            platform: platform,
            target: target,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            limit: limit,
            format: format,
            json: json
        )
    }
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

struct WebViewCurrentURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current-url", abstract: "Resolve the current WebView provider URL")

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
        try await runWebViewCurrentURL(
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

struct RouteAssertCurrentURL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "assert-current-url", abstract: "Assert the current WebView provider URL")

    @Argument(help: "Expected current URL") var expectedURL: String
    @Flag(help: "Compare scheme, host, path, and fragment while ignoring query items") var ignoreQuery = false
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
        try await runRouteAssertCurrentURL(
            expectedURL: expectedURL,
            ignoreQuery: ignoreQuery,
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

struct WebViewCall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "call", abstract: "Call an opt-in WebView bridge method")

    @Argument(help: "Allowlisted method name exposed by window.__tritonBridge.methods") var method: String
    @Option(help: "Bridge argument as key=value. Repeat for multiple arguments.") var arg: [String] = []
    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Select a candidate id from `triton webview list`") var webviewID: String?
    @Option(help: "Expected page session id from `triton webview current`") var pageSessionID: String?
    @Option(help: "Timeout in milliseconds") var timeoutMs: Int?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runWebViewCall(
            method: method,
            args: arg,
            platform: platform,
            target: target,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            webViewID: webviewID,
            pageSessionID: pageSessionID,
            timeoutMs: timeoutMs,
            format: format,
            json: json
        )
    }
}
