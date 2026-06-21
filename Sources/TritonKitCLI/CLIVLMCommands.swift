import ArgumentParser
import Foundation
import TritonKitShared

struct VLM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vlm",
        abstract: "Offline VLM grounding utilities for evidence artifacts",
        subcommands: [
            Ground.self,
        ]
    )

    struct Ground: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "ground",
            abstract: "Resolve a target phrase to a runtime-point using an offline mock VLM provider"
        )

        @Option(help: "Grounding provider: mock or openai-compatible.") var provider: String = "mock"
        @Option(help: "Screenshot image path") var image: String
        @Option(help: "Target phrase to ground") var target: String
        @Option(name: .customLong("coordinate-contract"), help: "P0E coordinate-contract.json path") var coordinateContract: String
        @Option(name: .customLong("base-url"), help: "OpenAI-compatible /v1 base URL") var baseURL: String?
        @Option(help: "OpenAI-compatible model name") var model: String?
        @Option(name: .customLong("api-key-env"), help: "Environment variable containing provider API key") var apiKeyEnv: String?
        @Flag(name: .customLong("allow-remote-vlm"), help: "Allow non-localhost VLM provider requests") var allowRemoteVLM = false
        @Option(name: .customLong("output-dir"), help: "Directory for overlay/request/response artifacts") var outputDir: String?
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try groundVLMTarget(
                    provider: provider,
                    image: image,
                    target: target,
                    coordinateContract: coordinateContract,
                    outputDirectory: outputDir,
                    baseURL: baseURL,
                    model: model,
                    apiKeyEnv: apiKeyEnv,
                    allowRemoteVLM: allowRemoteVLM
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("ok: true")
                    print("provider: \(response.provider)")
                    print("target: \(response.target)")
                    print("runtimePoint: \(formatDouble(response.point.runtimePoint.x)),\(formatDouble(response.point.runtimePoint.y))")
                    print("overlay: \(response.artifacts.overlay)")
                }
            } catch {
                try failVLMGrounding(error, outputFormat: outputFormat)
            }
        }
    }
}

func failVLMGrounding(_ error: Error, outputFormat: ClientOutputFormat) throws -> Never {
    let detail: TKCLIErrorDetail
    if let failure = error as? TKVLMGroundingFailure {
        detail = TKCLIErrorDetail(
            code: failure.code,
            message: failure.message,
            hint: failure.hint,
            nextAction: TKCLINextAction(
                command: "schema",
                args: ["--command", "vlm", "--json"]
            )
        )
    } else {
        detail = TKCLIErrorDetail(
            code: "vlm_grounding_failed",
            message: "\(error)",
            hint: "Run triton schema --command vlm --json to inspect the grounding contract"
        )
    }
    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: detail)))
    case .text:
        fputs("\(detail.code): \(detail.message)\n", stderr)
        if let hint = detail.hint {
            fputs("hint: \(hint)\n", stderr)
        }
    }
    throw ExitCode.failure
}
