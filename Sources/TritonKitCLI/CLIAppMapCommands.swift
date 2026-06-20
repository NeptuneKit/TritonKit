import ArgumentParser
import Foundation
import TritonKitShared

struct AppMap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "map",
        abstract: "Project evidence into an app map and export replayable test paths",
        subcommands: [
            Merge.self,
            Inspect.self,
            Paths.self,
            Screens.self,
            Transitions.self,
            Path.self,
            Health.self,
            Suite.self,
            ExportFlow.self,
        ]
    )

    struct Merge: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Merge a .tritonevidence run into a .tritonmap directory")

        @Argument(help: "Input .tritonevidence directory") var evidence: String
        @Option(help: "Output .tritonmap directory") var into: String
        @Flag(help: "Confirm generated replayable paths for inclusion in the smoke suite") var confirm = false
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try mergeTritonAppMap(evidencePath: evidence, into: into, confirm: confirm)
                try printAppMapMerge(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }

    struct Inspect: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Inspect a .tritonmap directory")

        @Argument(help: "Input .tritonmap directory") var map: String
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try inspectTritonAppMap(mapPath: map)
                try printAppMapInspect(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }

    struct Paths: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List replayable paths in a .tritonmap directory")

        @Argument(help: "Input .tritonmap directory") var map: String
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try listTritonAppMapPaths(mapPath: map)
                try printAppMapPaths(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }

    struct Screens: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List screens in a .tritonmap directory")

        @Argument(help: "Input .tritonmap directory") var map: String
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try listTritonAppMapScreens(mapPath: map)
                try printAppMapScreens(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }

    struct Transitions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List transitions in a .tritonmap directory")

        @Argument(help: "Input .tritonmap directory") var map: String
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try listTritonAppMapTransitions(mapPath: map)
                try printAppMapTransitions(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }

    struct Path: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "path",
            abstract: "Inspect one App Map path",
            subcommands: [Show.self]
        )

        struct Show: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Show a path with its screens and transitions")

            @Argument(help: "Input .tritonmap directory") var map: String
            @Option(help: "Path id to show") var path: String
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() async throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try showTritonAppMapPath(mapPath: map, pathID: path)
                    try printAppMapPathShow(response, format: outputFormat)
                } catch {
                    try failAppMap(error, outputFormat: outputFormat)
                }
            }
        }
    }

    struct Health: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Inspect App Map health and coverage gaps")

        @Argument(help: "Input .tritonmap directory") var map: String
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try inspectTritonAppMapHealth(mapPath: map)
                try printAppMapHealth(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }

    struct Suite: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "suite",
            abstract: "Inspect App Map suites",
            subcommands: [Inspect.self]
        )

        struct Inspect: AsyncParsableCommand {
            static let configuration = CommandConfiguration(abstract: "Inspect one suite")

            @Argument(help: "Input .tritonmap directory") var map: String
            @Option(help: "Suite id to inspect") var suite: String = "smoke"
            @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
            @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

            func run() async throws {
                let outputFormat = effectiveFormat(format, json: json)
                do {
                    let response = try inspectTritonAppMapSuite(mapPath: map, suiteID: suite)
                    try printAppMapSuiteInspect(response, format: outputFormat)
                } catch {
                    try failAppMap(error, outputFormat: outputFormat)
                }
            }
        }
    }

    struct ExportFlow: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "export-flow", abstract: "Export a map path to a .tritontest.yaml flow")

        @Argument(help: "Input .tritonmap directory") var map: String
        @Option(help: "Path id to export") var path: String
        @Option(help: "Output .tritontest.yaml file") var out: String
        @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json
        @Flag(name: .customLong("json"), help: "Alias for --format json") var json = false

        func run() async throws {
            let outputFormat = effectiveFormat(format, json: json)
            do {
                let response = try exportTritonAppMapFlow(mapPath: map, pathID: path, output: out)
                try printAppMapExportFlow(response, format: outputFormat)
            } catch {
                try failAppMap(error, outputFormat: outputFormat)
            }
        }
    }
}

func failAppMap(_ error: Error, outputFormat: ClientOutputFormat) throws -> Never {
    let message = "\(error)"
    switch outputFormat {
    case .json:
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "app_map_error",
            message: message,
            hint: "Run `triton schema --command map --json` to inspect App Map commands"
        ))
        print(try encodeJSON(response))
    case .text:
        fputs("error: \(message)\n", stderr)
    }
    throw ExitCode.failure
}

func printAppMapMerge(_ response: TKAppMapMergeResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        print("mapDir: \(response.mapDir)")
        print("screens: \(response.screenCount)")
        print("transitions: \(response.transitionCount)")
        print("paths: \(response.pathCount)")
    }
}

func printAppMapInspect(_ response: TKAppMapInspectResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        print("mapDir: \(response.mapDir)")
        print("screens: \(response.screenCount)")
        print("transitions: \(response.transitionCount)")
        print("paths: \(response.pathCount)")
        print("suites: \(response.suiteCount)")
    }
}

func printAppMapPaths(_ response: TKAppMapPathsResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        for path in response.paths {
            print("- \(path.pathID): \(path.name)")
        }
    }
}

func printAppMapScreens(_ response: TKAppMapScreensResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        for screen in response.screens {
            print("- \(screen.screenID): \(screen.primaryText ?? "")")
        }
    }
}

func printAppMapTransitions(_ response: TKAppMapTransitionsResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        for transition in response.transitions {
            print("- \(transition.transitionID): \(transition.fromScreenID) -> \(transition.toScreenID)")
        }
    }
}

func printAppMapPathShow(_ response: TKAppMapPathShowResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        print("path: \(response.path.pathID)")
        print("transitions: \(response.transitions.count)")
        print("screens: \(response.screens.count)")
    }
}

func printAppMapHealth(_ response: TKAppMapHealthResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        print("observedRuns: \(response.health.observedRuns)")
        print("passCount: \(response.health.passCount)")
        print("failCount: \(response.health.failCount)")
        print("uncoveredScreens: \(response.uncoveredScreenIDs.count)")
        print("uncoveredTransitions: \(response.uncoveredTransitionIDs.count)")
    }
}

func printAppMapSuiteInspect(_ response: TKAppMapSuiteInspectResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        print("suite: \(response.suite.suiteID)")
        print("paths: \(response.paths.count)")
    }
}

func printAppMapExportFlow(_ response: TKAppMapExportFlowResponse, format: ClientOutputFormat) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        print("ok: \(response.ok)")
        print("output: \(response.output)")
        print("steps: \(response.stepCount)")
    }
}
