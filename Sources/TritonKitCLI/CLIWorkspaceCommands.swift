import ArgumentParser
import Foundation
import TritonKitShared

struct Workspace: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace",
        abstract: "Create and inspect local agent workspace runs",
        subcommands: [Run.self, Inspect.self, Stop.self, ExportFlow.self]
    )

    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run",
            abstract: "Create a local workspace run facts directory"
        )

        @Option(help: "Target id. Defaults to current.") var target: String = "current"
        @Option(help: "Target platform fact, for example ios, android, or harmony") var platform: String?
        @Option(help: "Target scope fact, for example simulator, emulator, real, or current") var scope: String?
        @Option(help: "App artifact, bundle id, or app id") var app: String
        @Option(help: "Run goal") var goal: String
        @Option(name: .customLong("runs-dir"), help: "Workspace runs directory") var runsDirectory: String = ".triton/runs"
        @Option(name: .customLong("run-id"), help: "Run id") var runID: String?
        @Option(name: .customLong("action-policy"), help: "Action policy") var actionPolicy: String = "explore"
        @Option(name: .customLong("llm-provider"), help: "LLM provider preflight id, for example mock")
        var llmProvider: String?
        @Option(name: .customLong("vlm-provider"), help: "VLM provider preflight id, for example mock")
        var vlmProvider: String?
        @Flag(name: .customLong("dry-model-fixture"), help: "Append dry model/policy/action/recovery fixture events")
        var dryModelFixture = false
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try runWorkspaceRun(TKWorkspaceRunRequest(
                    runsDirectory: runsDirectory,
                    runID: runID,
                    target: target,
                    platform: platform,
                    scope: scope,
                    app: app,
                    goal: goal,
                    actionPolicy: actionPolicy,
                    dryModelFixture: dryModelFixture,
                    llmProvider: llmProvider,
                    vlmProvider: vlmProvider
                ))
                try printWorkspaceRun(response, format: outputFormat)
            } catch {
                try failWorkspace(error, outputFormat: outputFormat)
            }
        }
    }

    struct Inspect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Inspect a local workspace run"
        )

        @Argument(help: "Run id") var runID: String
        @Option(name: .customLong("runs-dir"), help: "Workspace runs directory") var runsDirectory: String = ".triton/runs"
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                try printWorkspaceInspect(
                    inspectWorkspaceRun(runID: runID, runsDirectory: runsDirectory),
                    format: outputFormat
                )
            } catch {
                try failWorkspace(error, outputFormat: outputFormat)
            }
        }
    }

    struct Stop: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop a local workspace run"
        )

        @Argument(help: "Run id") var runID: String
        @Option(name: .customLong("runs-dir"), help: "Workspace runs directory") var runsDirectory: String = ".triton/runs"
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                try printWorkspaceInspect(
                    stopWorkspaceRun(runID: runID, runsDirectory: runsDirectory),
                    format: outputFormat
                )
            } catch {
                try failWorkspace(error, outputFormat: outputFormat)
            }
        }
    }

    struct ExportFlow: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export-flow",
            abstract: "Export a local workspace run to a flow seed"
        )

        @Argument(help: "Run id") var runID: String
        @Option(help: "Output .tritonflow.yaml file") var output: String
        @Option(name: .customLong("runs-dir"), help: "Workspace runs directory") var runsDirectory: String = ".triton/runs"
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try exportWorkspaceFlow(runID: runID, runsDirectory: runsDirectory, output: output)
                switch outputFormat {
                case .json:
                    print(try encodeJSON(response))
                case .text:
                    print("output: \(response.output)")
                    print("steps: \(response.stepCount)")
                }
            } catch {
                try failWorkspace(error, outputFormat: outputFormat)
            }
        }
    }
}

private func printWorkspaceRun(_ response: TKWorkspaceRunResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("runId: \(response.runID)")
        print("status: \(response.status)")
        print("events: \(response.paths.events)")
    }
}

private func printWorkspaceInspect(_ response: TKWorkspaceInspectResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("runId: \(response.run.runID)")
        print("status: \(response.run.status)")
        print("events: \(response.summary.eventCount)")
        print("atlas: screens=\(response.atlas.screenCount) states=\(response.atlas.stateCount) transitions=\(response.atlas.transitionCount)")
    }
}

private func failWorkspace(_ error: Error, outputFormat: ClientOutputFormat) throws -> Never {
    switch outputFormat {
    case .json:
        print(try encodeJSON(TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "workspace_failed",
            message: "\(error)",
            hint: "Run `triton workspace run --help` for supported arguments."
        ))))
    case .text:
        fputs("error: \(error)\n", stderr)
    }
    throw ExitCode.failure
}
