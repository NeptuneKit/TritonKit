import ArgumentParser
import TritonKitShared

struct Observe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Observe the current app surface from host and runtime sources",
        subcommands: [ObserveCurrent.self, ObserveTree.self]
    )
}

struct ObserveCurrent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current", abstract: "Read the current visible app snapshot")

    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Maximum nodes to return") var maxNodes: Int?
    @Option(help: "Write host layout artifact to a file for Harmony") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runObserve(
            action: "observe.current",
            platform: platform,
            target: target,
            hdc: hdc,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            maxNodes: maxNodes,
            output: output,
            format: format,
            json: json
        )
    }
}

struct ObserveTree: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tree", abstract: "Read the current visible node tree")

    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Maximum nodes to return") var maxNodes: Int?
    @Option(help: "Write host layout artifact to a file for Harmony") var output: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runObserve(
            action: "observe.tree",
            platform: platform,
            target: target,
            hdc: hdc,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            maxNodes: maxNodes,
            output: output,
            format: format,
            json: json
        )
    }
}

struct NodeResolve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "resolve", abstract: "Resolve a current UI node by text, id, key, accessibility id, or point")

    @Option(help: "Observation platform: ios or harmony") var platform: ObservationPlatform = .ios
    @Option(name: .customLong("text"), help: "Visible text, label, identifier, title, value, key, or accessibility id") var text: String?
    @Option(help: "Target id from `triton list` or Harmony hdc target") var target: String = TKLocalTargetID
    @Option(help: "Path to hdc executable for --platform harmony") var hdc: String = "hdc"
    @Option(help: "Server host for iOS embedded runtime") var host: String = "127.0.0.1"
    @Option(help: "Server port for iOS embedded runtime") var port: Int = 19421
    @Option(help: "Direct embedded runtime base URL, for example http://127.0.0.1:28767") var runtimeBaseURL: String?
    @Option(help: "Select one matching candidate by 1-based index") var index: Int?
    @Option(help: "Restrict matching to bounds: x,y,width,height") var within: String?
    @Option(help: "Restrict matching to candidate containing point: x,y") var at: String?
    @Flag(help: "Include all matching candidates") var all = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() async throws {
        try await runNodeResolve(
            platform: platform,
            text: text,
            target: target,
            hdc: hdc,
            host: host,
            port: port,
            runtimeBaseURL: runtimeBaseURL,
            index: index,
            within: within,
            at: at,
            all: all,
            format: format,
            json: json
        )
    }
}
