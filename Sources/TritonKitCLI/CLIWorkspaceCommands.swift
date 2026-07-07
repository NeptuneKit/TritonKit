import ArgumentParser
import Foundation
import TritonKitShared

struct Workspace: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workspace",
        abstract: "Create and inspect local agent workspace runs",
        subcommands: [Run.self, Inspect.self, Stop.self, ExportFlow.self]
    )

    struct Run: AsyncParsableCommand {
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
        @Option(name: .customLong("app-mode"), help: "App lifecycle mode: dry, attach, or launch") var appMode: String = "dry"
        @Option(name: .customLong("bundle-id"), help: "iOS app bundle identifier; defaults to --app for iOS launch")
        var bundleID: String?
        @Option(name: .customLong("package-name"), help: "Android package name; defaults to --app for Android launch")
        var packageName: String?
        @Option(help: "Android activity for explicit component launch")
        var activity: String?
        @Option(help: "Harmony bundle name; defaults to --app for Harmony launch")
        var bundle: String?
        @Option(help: "Harmony ability name")
        var ability: String?
        @Option(name: .customLong("max-steps"), help: "Maximum autonomous runner steps") var maxSteps: Int?
        @Option(name: .customLong("allowed-action"), help: "Allowed runner action. Repeat for multiple values")
        var allowedActions: [String] = []
        @Option(name: .customLong("stop-condition"), help: "Runner stop condition. Repeat for multiple values")
        var stopConditions: [String] = []
        @Option(name: .customLong("observation-fixture"), help: "Observation fixture JSON used to seed initial screen evidence")
        var observationFixture: String?
        @Flag(name: .customLong("observe-live"), help: "Capture initial observation through triton observe")
        var observeLive = false
        @Option(name: .customLong("observe-kind"), help: "Live observation kind: current or tree")
        var observeKind = "tree"
        @Option(name: .customLong("observe-max-nodes"), help: "Maximum nodes for live observation")
        var observeMaxNodes: Int?
        @Option(name: .customLong("observe-output"), help: "Write host layout artifact for live observation")
        var observeOutput: String?
        @Option(name: .customLong("runtime-base-url"), help: "Direct embedded runtime base URL for live observation")
        var observeRuntimeBaseURL: String?
        @Option(name: .customLong("observe-host"), help: "Embedded runtime host for live observation")
        var observeHost = "127.0.0.1"
        @Option(name: .customLong("observe-port"), help: "Embedded runtime port for live observation")
        var observePort = 19421
        @Option(help: "Path to hdc executable for Harmony live observation")
        var hdc = "hdc"
        @Option(name: .customLong("business-ready-text"), help: "Exact visible text that proves business readiness from the initial observation")
        var businessReadyText: String?
        @Flag(name: .customLong("business-ready-live-wait"), help: "Use runtime wait text matching for the business readiness checkpoint")
        var businessReadyLiveWait = false
        @Option(name: .customLong("business-ready-timeout"), help: "Timeout in seconds for --business-ready-live-wait")
        var businessReadyTimeout: Double = 10
        @Option(name: .customLong("business-ready-interval"), help: "Polling interval in seconds for --business-ready-live-wait")
        var businessReadyInterval: Double = 0.5
        @Option(help: "Path to adb executable for Android app launch")
        var adb = "adb"
        @Option(name: .customLong("llm-provider"), help: "LLM provider preflight id, for example mock")
        var llmProvider: String?
        @Option(name: .customLong("vlm-provider"), help: "VLM provider preflight id, for example mock")
        var vlmProvider: String?
        @Flag(name: .customLong("dry-model-fixture"), help: "Append dry model/policy/action/recovery fixture events")
        var dryModelFixture = false
        @Flag(name: .customLong("execute-actions"), help: "Execute model-selected candidate actions through the runtime action provider")
        var executeActions = false
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try await runWorkspaceRunAsync(TKWorkspaceRunRequest(
                    runsDirectory: runsDirectory,
                    runID: runID,
                    target: target,
                    platform: platform,
                    scope: scope,
                    app: app,
                    goal: goal,
                    actionPolicy: actionPolicy,
                    appMode: appMode,
                    bundleID: bundleID,
                    packageName: packageName,
                    activity: activity,
                    bundle: bundle,
                    ability: ability,
                    adb: adb,
                    dryModelFixture: dryModelFixture,
                    llmProvider: llmProvider,
                    vlmProvider: vlmProvider,
                    maxSteps: maxSteps,
                    allowedActions: allowedActions,
                    stopConditions: stopConditions,
                    observationFixture: observationFixture,
                    observeLive: observeLive,
                    observeKind: observeKind,
                    observeMaxNodes: observeMaxNodes,
                    observeOutput: observeOutput,
                    observeRuntimeBaseURL: observeRuntimeBaseURL,
                    observeHost: observeHost,
                    observePort: observePort,
                    hdc: hdc,
                    businessReadyText: businessReadyText,
                    businessReadyLiveWait: businessReadyLiveWait,
                    businessReadyTimeout: businessReadyTimeout,
                    businessReadyInterval: businessReadyInterval,
                    executeActions: executeActions
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
