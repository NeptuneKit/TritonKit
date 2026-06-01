import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print Triton CLI version and bootstrap defaults")

    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() throws {
        let language = effectiveLanguage(localization.language)
        let response = TKCLIVersionResponse(version: TritonKitBuildInfo.cliVersion, language: language.rawValue)
        switch effectiveFormat(format, json: json) {
        case .json:
            print(try encodeJSON(response))
        case .text:
            switch language {
            case .en:
                print(response.version)
            case .zh:
                print("版本: \(response.version)")
            }
        }
    }
}

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read local TritonKit server status")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let client = TritonKitHTTPClient(host: host, port: port)
        let outputFormat = effectiveFormat(format, json: json)
        let language = effectiveLanguage(localization.language)
        do {
            let status: TKStatusResponse = try await client.getJSON("/status")
            switch outputFormat {
            case .json:
                print(try encodeJSON(TKCLIStatusEnvelope(
                    ok: true,
                    serverReachable: true,
                    connected: status.connected,
                    latestHierarchyAvailable: status.latestHierarchyAvailable,
                    targetCount: status.targetCount,
                    runtime: status.connected ? "embedded" : "none",
                    activeHierarchyAvailable: status.activeHierarchyAvailable,
                    hierarchyCacheState: status.hierarchyCacheState,
                    targetConnectionState: status.targetConnectionState
                )))
            case .text:
                switch language {
                case .en:
                    print("connected: \(status.connected)")
                    print("latestHierarchyAvailable: \(status.latestHierarchyAvailable)")
                    print("activeHierarchyAvailable: \(status.activeHierarchyAvailable ?? (status.connected && status.latestHierarchyAvailable))")
                    print("hierarchyCacheState: \(status.hierarchyCacheState ?? "unknown")")
                    print("targetConnectionState: \(status.targetConnectionState ?? (status.connected ? "connected" : "disconnected"))")
                    print("targetCount: \(status.targetCount)")
                case .zh:
                    print("已连接: \(status.connected)")
                    print("已有最新层级: \(status.latestHierarchyAvailable)")
                    print("当前连接已有层级: \(status.activeHierarchyAvailable ?? (status.connected && status.latestHierarchyAvailable))")
                    print("层级缓存状态: \(status.hierarchyCacheState ?? "unknown")")
                    print("目标连接状态: \(status.targetConnectionState ?? (status.connected ? "connected" : "disconnected"))")
                    print("目标数量: \(status.targetCount)")
                }
            }
        } catch {
            if outputFormat == .json {
                try printCLIError(error, endpoint: "/status", host: host, port: port)
                throw ExitCode.failure
            }
            printCLIErrorText(error, endpoint: "/status", host: host, port: port, language: language)
            throw ExitCode.failure
        }
    }
}

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Diagnose server, target, and runtime capabilities")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .text
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let response = await buildDoctor(host: host, port: port)
        try printDoctor(response, format: effectiveFormat(format, json: json), language: effectiveLanguage(localization.language))
    }
}

struct Capabilities: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print machine-readable Triton runtime capabilities")

    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let response = await buildCapabilities(host: host, port: port)
        try printCapabilities(response, format: effectiveFormat(format, json: json), language: effectiveLanguage(localization.language))
    }
}

struct SchemaCommandLookupError: Error, CustomStringConvertible {
    let command: String

    var description: String {
        "Unknown command schema: \(command)"
    }
}

func buildSchemaResponse(command: String?) throws -> TKCLISchemaResponse {
    let commands = commandSchemas()
    let filtered: [TKCommandSchema]
    if let command {
        filtered = commands.filter { $0.name == command }
        guard !filtered.isEmpty else {
            throw SchemaCommandLookupError(command: command)
        }
    } else {
        filtered = commands
    }
    return TKCLISchemaResponse(commands: filtered)
}

func schemaUnknownCommandErrorResponse(_ error: SchemaCommandLookupError) -> TKCLIErrorResponse {
    TKCLIErrorResponse(error: TKCLIErrorDetail(
        code: "unknown_command_schema",
        message: "Unknown command schema: \(error.command)",
        hint: "Run `triton schema --json` to inspect available command schemas.",
        nextAction: TKCLINextAction(command: "schema", args: ["--json"])
    ))
}

struct Schema: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print machine-readable command schemas and examples")

    @Option(help: "Command name to filter, for example tap or export") var command: String?
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false
    @OptionGroup var localization: LocalizationOptions

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let response = try buildSchemaResponse(command: command)
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print(renderSchema(response, language: effectiveLanguage(localization.language)))
            }
        } catch let error as SchemaCommandLookupError {
            switch outputFormat {
            case .json:
                print(try encodeJSON(schemaUnknownCommandErrorResponse(error)))
            case .text:
                print(error.description)
            }
            throw ExitCode.failure
        }
    }
}
