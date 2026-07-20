import ArgumentParser
import TritonKitShared

// MARK: - Xcode Workflow Commands

struct Xcode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcode",
        abstract: "Discover, configure, build, test, and run Xcode projects through Triton contracts",
        subcommands: [
            XcodeDiscover.self,
            XcodeUse.self,
            XcodeSchemes.self,
            XcodeStatus.self,
            XcodeWaitIdle.self,
            XcodeSettings.self,
            XcodeBuild.self,
            XcodeTest.self,
            XcodeRun.self,
        ]
    )
}

struct XcodeDiscover: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover", abstract: "Discover Xcode workspaces, projects, and Swift packages")

    @Option(help: "Repository or workspace root path") var path: String = "."
    @Option(help: "Maximum directory depth to scan") var maxDepth: Int = 2
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let result = try TKXcodeProjectDiscovery.discover(path: path, maxDepth: maxDepth)
            switch outputFormat {
            case .json:
                print(try encodeJSON(result))
            case .text:
                for workspace in result.workspaces { print("workspace\t\(workspace.path)") }
                for project in result.projects { print("project\t\(project.path)") }
                for package in result.packages { print("package\t\(package.path)") }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeUse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use", abstract: "Set workspace Xcode defaults")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Path to Package.swift or its package directory") var package: String?
    @Option(help: "Scheme name") var scheme: String
    @Option(help: "Build configuration") var configuration: String = "Debug"
    @Option(help: "SDK, for example iphonesimulator") var sdk: String = "iphonesimulator"
    @Option(help: "Simulator UDID or name; synthesizes an id= or name= destination") var simulator: String?
    @Option(help: "xcodebuild destination") var destination: String?
    @Option(help: "DerivedData path used as the Xcode incremental build cache; cleanup should preserve it by default") var derivedDataPath: String = defaultXcodeDerivedDataPath
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            try validateXcodeContainer(workspace: workspace, project: project, package: package, outputFormat: outputFormat)
            let existing = (try? loadHostWorkspaceDefaults()) ?? TKHostWorkspaceDefaults()
            let resolvedDestination = destination ?? simulator.map(xcodeSimulatorDestination(selector:))
            let xcode = TKXcodeWorkspaceDefaults(
                workspace: workspace,
                project: project,
                package: package,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: resolvedDestination,
                derivedDataPath: derivedDataPath
            )
            let defaults = TKHostWorkspaceDefaults(
                defaultSimulatorUDID: simulator ?? existing.defaultSimulatorUDID,
                xcode: xcode
            )
            let path = try saveHostWorkspaceDefaults(defaults)
            let output = XcodeUseOutput(
                ok: true,
                action: "xcode.use",
                defaultsPath: path,
                defaults: defaults,
                derivedDataCache: makeXcodeDerivedDataCacheInfo(path: derivedDataPath)
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print(path)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeSchemes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "schemes", abstract: "List Xcode schemes")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Path to Package.swift or its package directory") var package: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveXcodeContainer(workspace: workspace, project: project, package: package)
            let command = TKXcodebuildCommand.listSchemes(workspace: resolved.workspace, project: resolved.project, package: resolved.package)
            let result = try runHostCommand(command)
            let schemes = try TKXcodebuildListParser.parseSchemes(result.stdoutData)
            let output = XcodeSchemesOutput(
                ok: true,
                workspace: resolved.workspace,
                project: resolved.project,
                package: resolved.package,
                schemes: schemes.schemes,
                sourceCommand: result.sourceCommand
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                for scheme in schemes.schemes { print(scheme) }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Inspect active xcodebuild and build-service processes")

    @Option(help: "Only include processes matching this .xcworkspace or .xcodeproj path") var workspace: String?
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let output = try currentXcodeProcessStatus(workspace: workspace)
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                if output.processes.isEmpty {
                    print("idle")
                } else {
                    for process in output.processes {
                        print("\(process.pid)\t\(process.name)\t\(process.workspace ?? "-")\t\(process.scheme ?? "-")")
                    }
                }
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeWaitIdle: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "wait-idle", abstract: "Wait until matching Xcode build/test processes are idle")

    @Option(help: "Only wait for processes matching this .xcworkspace or .xcodeproj path") var workspace: String?
    @Option(help: "Timeout in seconds") var timeout: Double = 120
    @Option(help: "Polling interval in seconds") var interval: Double = 2
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let output = try await waitForXcodeIdle(
                workspace: workspace,
                timeout: timeout,
                interval: interval,
                statusProvider: { try currentXcodeProcessStatus(workspace: workspace) }
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(output))
            case .text:
                print("idle\tpolls=\(output.pollCount)\telapsedMs=\(output.elapsedMs)")
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeSettings: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "settings", abstract: "Resolve Xcode build settings for the selected app product")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Path to Package.swift or its package directory") var package: String?
    @Option(help: "Scheme name") var scheme: String?
    @Option(help: "Build configuration") var configuration: String?
    @Option(help: "SDK, for example iphonesimulator") var sdk: String?
    @Option(help: "xcodebuild destination") var destination: String?
    @Option(help: "Simulator UDID or name used to synthesize an id= or name= destination") var simulator: String?
    @Option(help: "Real-device selector used to synthesize an iphoneos build target") var device: String?
    @Option(help: "DerivedData path used as the Xcode incremental build cache; cleanup should preserve it by default") var derivedDataPath: String?
    @Option(help: "Timeout in seconds") var timeout: Double?
    @Flag(help: "Pass -allowProvisioningUpdates to xcodebuild for automatic signing on real devices") var allowProvisioningUpdates = false
    @Flag(help: "Emit JSON Lines progress") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveXcodeInvocation(
                workspace: workspace,
                project: project,
                package: package,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                simulator: simulator,
                device: device,
                derivedDataPath: derivedDataPath
            )
            let command = TKXcodebuildCommand.showBuildSettings(
                workspace: resolved.workspace,
                project: resolved.project,
                package: resolved.package,
                scheme: resolved.scheme,
                configuration: resolved.configuration,
                sdk: resolved.sdk,
                destination: resolved.destination,
                derivedDataPath: resolved.derivedDataPath
            ).withTimeout(timeout)
            let (result, _) = try runXcodeHostCommand(command, event: "xcode.settings", jsonl: jsonl)
            let product = try TKXcodeBuildSettingsParser.resolveBuiltApp(result.stdoutData)
            let output = XcodeSettingsOutput(
                ok: true,
                invocation: resolved,
                product: product,
                sourceCommand: result.sourceCommand,
                stdoutLogPath: result.stdoutLogPath,
                stderrLogPath: result.stderrLogPath,
                stdoutBytes: result.stdoutBytes,
                stderrBytes: result.stderrBytes
            )
            switch outputFormat {
            case .json:
                print(jsonl ? try encodeCompactJSON(output) : try encodeJSON(output))
            case .text:
                print(product.appPath)
            }
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeBuild: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build", abstract: "Build an Xcode scheme")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Path to Package.swift or its package directory") var package: String?
    @Option(help: "Scheme name") var scheme: String?
    @Option(help: "Build configuration") var configuration: String?
    @Option(help: "SDK, for example iphonesimulator") var sdk: String?
    @Option(help: "xcodebuild destination") var destination: String?
    @Option(help: "Simulator UDID or name used to synthesize an id= or name= destination") var simulator: String?
    @Option(help: "Real-device selector used to synthesize an iphoneos build target") var device: String?
    @Option(help: "DerivedData path used as the Xcode incremental build cache; cleanup should preserve it by default") var derivedDataPath: String?
    @Option(help: "Timeout in seconds") var timeout: Double?
    @Flag(help: "Pass -allowProvisioningUpdates to xcodebuild for automatic signing on real devices") var allowProvisioningUpdates = false
    @Flag(help: "Emit JSON Lines progress") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveXcodeInvocation(
                workspace: workspace,
                project: project,
                package: package,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                simulator: simulator,
                device: device,
                derivedDataPath: derivedDataPath
            )
            let summary = try runXcodeBuild(
                invocation: resolved,
                jsonl: jsonl,
                timeout: timeout,
                allowProvisioningUpdates: allowProvisioningUpdates
            )
            try printXcodeSummary(summary, jsonl: jsonl, outputFormat: outputFormat)
            if !summary.ok {
                throw ExitCode.failure
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeTest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "test", abstract: "Test an Xcode scheme")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Path to Package.swift or its package directory") var package: String?
    @Option(help: "Scheme name") var scheme: String?
    @Option(help: "Build configuration") var configuration: String?
    @Option(help: "SDK, for example iphonesimulator") var sdk: String?
    @Option(help: "xcodebuild destination") var destination: String?
    @Option(help: "Simulator UDID or name used to synthesize an id= or name= destination") var simulator: String?
    @Option(help: "Real-device selector used to synthesize an iphoneos build target") var device: String?
    @Option(help: "DerivedData path used as the Xcode incremental build cache; cleanup should preserve it by default") var derivedDataPath: String?
    @Option(help: "Result bundle output path") var resultBundle: String?
    @Option(help: "Timeout in seconds") var timeout: Double?
    @Flag(help: "Emit JSON Lines progress") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveXcodeInvocation(
                workspace: workspace,
                project: project,
                package: package,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                simulator: simulator,
                device: device,
                derivedDataPath: derivedDataPath
            )
            let summary = try runXcodeTest(invocation: resolved, resultBundlePath: resultBundle, jsonl: jsonl, timeout: timeout)
            try printXcodeSummary(summary, jsonl: jsonl, outputFormat: outputFormat)
            if !summary.ok {
                throw ExitCode.failure
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct XcodeRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Build, install, and launch an Xcode app on a simulator or real device")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Path to Package.swift or its package directory") var package: String?
    @Option(help: "Scheme name") var scheme: String?
    @Option(help: "Build configuration") var configuration: String?
    @Option(help: "SDK, for example iphonesimulator") var sdk: String?
    @Option(help: "xcodebuild destination") var destination: String?
    @Option(help: "Simulator UDID or name; synthesizes an id= or name= destination") var simulator: String?
    @Option(help: "Real-device selector used to build, install, and launch through devicectl") var device: String?
    @Option(help: "DerivedData path used as the Xcode incremental build cache; cleanup should preserve it by default") var derivedDataPath: String?
    @Option(name: .customLong("env"), help: "iOS app launch environment in KEY=VALUE form; values are redacted in output") var launchEnvironment: [String] = []
    @Option(name: .customLong("arg"), help: "Argument passed to the launched iOS app; repeat for multiple arguments") var launchArguments: [String] = []
    @Option(help: "Timeout in seconds") var timeout: Double?
    @Flag(help: "Emit JSON Lines progress") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveXcodeInvocation(
                workspace: workspace,
                project: project,
                package: package,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                simulator: simulator,
                device: device,
                derivedDataPath: derivedDataPath
            )
            let summary = try runXcodeBuildInstallLaunch(
                invocation: resolved,
                launchEnvironment: try parseLaunchEnvironment(launchEnvironment),
                launchArguments: launchArguments,
                jsonl: jsonl,
                timeout: timeout
            )
            try printXcodeSummary(summary, jsonl: jsonl, outputFormat: outputFormat)
        } catch {
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
