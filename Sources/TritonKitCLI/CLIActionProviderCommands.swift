import ArgumentParser
import Foundation
import TritonKitShared

struct ActionProvider: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "action",
        abstract: "Parse external GUI-agent action provider output into a Triton primitive preview",
        subcommands: [
            ActionProviderParse.self,
        ]
    )
}

struct ActionProviderParse: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "parse",
        abstract: "Parse one UI-TARS or AgentCPM-GUI action without executing it"
    )

    @Option(help: "Provider output format: ui-tars or agentcpm-gui") var provider: TKActionProviderOption
    @Option(help: "Raw provider action output") var input: String
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
    @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

    func run() throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let response = try parseActionProviderOutput(provider: provider, input: input)
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("provider: \(response.provider)")
                print("primitive: \(response.primitive)")
                print("command: \(response.commandPreview.joined(separator: " "))")
            }
        } catch let failure as TKActionProviderParseFailure {
            let detail = TKCLIErrorDetail(
                code: failure.code,
                message: failure.message,
                hint: "Use provider ui-tars with Action: click/type/swipe/press/wait/status, or provider agentcpm-gui with POINT/TYPE/PRESS/SWIPE/WAIT/STATUS JSON."
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(TKCLIErrorResponse(error: detail)))
            case .text:
                fputs("\(detail.code): \(detail.message)\n", stderr)
            }
            throw ExitCode.failure
        }
    }
}
