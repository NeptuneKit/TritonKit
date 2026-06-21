import ArgumentParser
import Foundation
import TritonKitShared

struct VLM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vlm",
        abstract: "Offline VLM grounding utilities for evidence artifacts",
        subcommands: [
            Ground.self,
            Providers.self,
            Compare.self,
            Model.self,
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
        @Option(help: "Provider model id") var model: String?
        @Option(name: .customLong("model-path"), help: "Local mlx-swift-lm model path") var modelPath: String?
        @Option(name: .customLong("api-key-env"), help: "Environment variable containing provider API key") var apiKeyEnv: String?
        @Flag(name: .customLong("allow-remote-vlm"), help: "Allow non-localhost VLM provider requests") var allowRemoteVLM = false
        @Option(name: .customLong("max-tokens"), help: "Maximum provider output tokens") var maxTokens = 64
        @Option(help: "Provider sampling temperature") var temperature: Double = 0
        @Option(help: "Provider seed") var seed = 0
        @Option(name: .customLong("prompt-template"), help: "Prompt template id") var promptTemplate = "gui-grounding-v1"
        @Flag(name: .customLong("allow-model-download"), help: "Allow local provider model download") var allowModelDownload = false
        @Flag(name: .customLong("no-model-download"), help: "Keep model download disabled") var noModelDownload = false
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
                    modelPath: modelPath,
                    apiKeyEnv: apiKeyEnv,
                    allowRemoteVLM: allowRemoteVLM,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    seed: seed,
                    promptTemplate: promptTemplate,
                    allowModelDownload: allowModelDownload && !noModelDownload
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

    struct Providers: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "providers",
            abstract: "List VLM grounding providers"
        )

        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let response = vlmProviderListResponse()
            switch effectiveFormat(format, json: json) {
            case .json:
                print(try encodeJSON(response))
            case .text:
                for provider in response.providers {
                    print("\(provider.id)\t\(provider.kind)\t\(provider.status)")
                }
            }
        }
    }

    struct Compare: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compare",
            abstract: "Compare VLM provider grounding results for one screenshot and target"
        )

        @Option(help: "Screenshot image path") var image: String
        @Option(help: "Target phrase to ground") var target: String
        @Option(name: .customLong("coordinate-contract"), help: "P0E coordinate-contract.json path") var coordinateContract: String
        @Option(name: .customLong("provider"), help: "Provider to compare; repeat for multiple providers") var providers: [String] = []
        @Option(name: .customLong("agreement-threshold-points"), help: "Maximum allowed pairwise runtime-point distance") var agreementThresholdPoints: Double = 24
        @Option(name: .customLong("base-url"), help: "OpenAI-compatible /v1 base URL") var baseURL: String?
        @Option(help: "Provider model id") var model: String?
        @Option(name: .customLong("model-path"), help: "Local mlx-swift-lm model path") var modelPath: String?
        @Option(name: .customLong("api-key-env"), help: "Environment variable containing provider API key") var apiKeyEnv: String?
        @Flag(name: .customLong("allow-remote-vlm"), help: "Allow non-localhost VLM provider requests") var allowRemoteVLM = false
        @Option(name: .customLong("max-tokens"), help: "Maximum provider output tokens") var maxTokens = 64
        @Option(help: "Provider sampling temperature") var temperature: Double = 0
        @Option(help: "Provider seed") var seed = 0
        @Option(name: .customLong("prompt-template"), help: "Prompt template id") var promptTemplate = "gui-grounding-v1"
        @Flag(name: .customLong("allow-model-download"), help: "Allow local provider model download") var allowModelDownload = false
        @Flag(name: .customLong("no-model-download"), help: "Keep model download disabled") var noModelDownload = false
        @Option(name: .customLong("output-dir"), help: "Directory for comparison artifacts") var outputDir: String?
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try compareVLMProviders(
                    image: image,
                    target: target,
                    coordinateContract: coordinateContract,
                    providers: providers,
                    outputDirectory: outputDir,
                    agreementThresholdPoints: agreementThresholdPoints,
                    baseURL: baseURL,
                    model: model,
                    modelPath: modelPath,
                    apiKeyEnv: apiKeyEnv,
                    allowRemoteVLM: allowRemoteVLM,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    seed: seed,
                    promptTemplate: promptTemplate,
                    allowModelDownload: allowModelDownload && !noModelDownload
                )
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("ok: true")
                    print("providers: \(response.results.count)")
                    print("passed: \(response.agreement.passedProviderCount)")
                    print("failed: \(response.agreement.failedProviderCount)")
                    print("overlay: \(response.artifacts.comparisonOverlay)")
                }
            } catch {
                try failVLMGrounding(error, outputFormat: outputFormat)
            }
        }
    }

    struct Model: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "model",
            abstract: "Manage local VLM model cache",
            subcommands: [Download.self, List.self, Inspect.self, Preflight.self, Prune.self, Remove.self]
        )

        struct Download: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "download", abstract: "Download one local VLM model through the external helper")
            @Argument(help: "Model id, for example mlx-community/Qwen2-VL-2B-Instruct-4bit") var model: String
            @Option(help: "Provider id") var provider = "mlx-swift-lm"
            @Option(name: .customLong("cache-dir"), help: "Override local model cache directory") var cacheDir: String?
            @Option(help: "External mlx-swift-lm helper path; defaults to TRITON_MLX_HELPER") var helper: String?
            @Flag(help: "Replace an existing incomplete or ready cache directory") var force = false
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try downloadVLMModel(
                        model,
                        provider: provider,
                        cacheDir: cacheDir,
                        force: force,
                        helperPath: helper
                    )
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(response))
                    case .text:
                        print("ok: \(response.ok)")
                        print("status: \(response.status)")
                        print("path: \(response.modelPath)")
                    }
                } catch {
                    try failVLMGrounding(error, outputFormat: outputFormat)
                }
            }
        }

        struct List: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "list", abstract: "List local VLM models")
            @Option(help: "Provider id") var provider = "mlx-swift-lm"
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try listVLMModels(provider: provider)
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(response))
                    case .text:
                        print("cacheDir: \(response.cacheDir)")
                        for model in response.models {
                            print("\(model.status)\t\(model.sizeBytes)\t\(model.path)")
                        }
                    }
                } catch {
                    try failVLMGrounding(error, outputFormat: outputFormat)
                }
            }
        }

        struct Inspect: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect one local VLM model")
            @Argument(help: "Model id or local path") var model: String
            @Option(help: "Provider id") var provider = "mlx-swift-lm"
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try inspectVLMModel(model, provider: provider)
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(response))
                    case .text:
                        print("status: \(response.model.status)")
                        print("path: \(response.model.path)")
                    }
                } catch {
                    try failVLMGrounding(error, outputFormat: outputFormat)
                }
            }
        }

        struct Preflight: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "preflight", abstract: "Check whether a local VLM model looks usable")
            @Argument(help: "Model id or local path") var model: String
            @Option(help: "Provider id") var provider = "mlx-swift-lm"
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try preflightVLMModel(model, provider: provider)
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(response))
                    case .text:
                        print("ok: \(response.ok)")
                        for check in response.checks {
                            print("\(check.status)\t\(check.name)")
                        }
                    }
                    if !response.ok { throw ExitCode.failure }
                } catch {
                    if error is ExitCode { throw error }
                    try failVLMGrounding(error, outputFormat: outputFormat)
                }
            }
        }

        struct Prune: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "prune", abstract: "Remove incomplete local VLM model cache directories")
            @Option(help: "Provider id") var provider = "mlx-swift-lm"
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try pruneVLMModels(provider: provider)
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(response))
                    case .text:
                        print("removed: \(response.removed.count)")
                        print("kept: \(response.kept.count)")
                    }
                } catch {
                    try failVLMGrounding(error, outputFormat: outputFormat)
                }
            }
        }

        struct Remove: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove one local VLM model")
            @Argument(help: "Model id or local path") var model: String
            @Option(help: "Provider id") var provider = "mlx-swift-lm"
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try removeVLMModel(model, provider: provider)
                    switch outputFormat {
                    case .json:
                        print(try encodeJSON(response))
                    case .text:
                        print("removed: \(response.removed.joined(separator: ","))")
                    }
                } catch {
                    try failVLMGrounding(error, outputFormat: outputFormat)
                }
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
