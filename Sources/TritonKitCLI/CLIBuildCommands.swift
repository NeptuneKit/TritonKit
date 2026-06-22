import ArgumentParser
import Foundation

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build cross-platform debug artifacts for real-device install flows",
        subcommands: [
            BuildIOS.self,
            BuildAndroid.self,
            BuildHarmony.self,
        ]
    )
}

struct BuildIOS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ios", abstract: "Build an iOS app for a real device through xcodebuild")

    @Option(help: "Path to .xcworkspace") var workspace: String?
    @Option(help: "Path to .xcodeproj") var project: String?
    @Option(help: "Scheme name") var scheme: String?
    @Option(help: "Build configuration") var configuration: String?
    @Option(help: "SDK; defaults to iphoneos for --device") var sdk: String?
    @Option(help: "Real-device selector or UDID used to synthesize destination") var device: String?
    @Option(help: "Explicit xcodebuild destination") var destination: String?
    @Option(help: "DerivedData path") var derivedDataPath: String?
    @Option(help: "Build timeout in seconds") var timeout: Double?
    @Flag(help: "Emit JSON Lines progress and final summary") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: json or text") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let resolved = try resolveXcodeInvocation(
                workspace: workspace,
                project: project,
                scheme: scheme,
                configuration: configuration,
                sdk: sdk,
                destination: destination,
                simulator: nil,
                device: device,
                derivedDataPath: derivedDataPath
            )
            if jsonl {
                writeJSONLLine(try encodeCompactJSON(TKBuildProgressEvent(
                    ok: true,
                    event: "build.ios.invocation",
                    platform: "ios",
                    message: "started",
                    sourceCommand: nil,
                    elapsedMs: 0,
                    stdoutLogPath: nil,
                    stderrLogPath: nil
                )))
            }
            let summary = try runXcodeBuild(invocation: resolved, jsonl: false, timeout: timeout)
            try printBuildActionSummary(buildIOSSummary(from: summary, device: device), jsonl: jsonl, outputFormat: outputFormat)
        } catch {
            let summary = buildIOSFailureSummary(error: error, workspace: workspace, project: project, device: device, jsonl: jsonl)
            try printBuildActionSummary(summary, jsonl: jsonl, outputFormat: outputFormat)
            throw ExitCode.failure
        }
    }
}

struct BuildAndroid: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "android", abstract: "Build an Android debug APK with Gradle")

    @Option(help: "Android project root") var project: String
    @Option(help: "Gradle or gradlew executable") var gradle: String?
    @Option(help: "Gradle build variant") var variant: String = "debug"
    @Option(help: "Optional real-device selector used only for nextAction") var device: String?
    @Option(help: "Artifact discovery root") var output: String?
    @Option(help: "Build timeout in seconds") var timeout: Double?
    @Flag(help: "Emit JSON Lines progress and final summary") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: json or text") var format: ClientOutputFormat = .json

    func run() async throws {
        let request = CLIBuildRequest.android(project: project, gradle: gradle, variant: variant, device: device, timeout: timeout, discoveryRoot: output)
        try runBuildCommand(request: request, jsonl: jsonl, outputFormat: effectiveFormat(format, json: json))
    }
}

struct BuildHarmony: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "harmony", abstract: "Build a Harmony debug HAP with hvigor")

    @Option(help: "Harmony project root") var project: String
    @Option(help: "hvigor or hvigorw executable") var hvigor: String?
    @Option(help: "Node executable used to run DevEco hvigor.js") var node: String?
    @Option(help: "JAVA_HOME used for DevEco JBR") var javaHome: String?
    @Option(help: "DEVECO_SDK_HOME used for Harmony SDK discovery") var devecoSdkHome: String?
    @Option(help: "DevEco product name passed as -p product=<name>") var product: String?
    @Option(help: "Harmony hvigor task, for example assembleHap or assembleApp") var task: String?
    @Flag(help: "Pass --no-daemon to hvigor") var noDaemon = false
    @Option(help: "Harmony module name") var module: String = "entry"
    @Option(help: "Harmony build mode") var mode: String = "debug"
    @Option(help: "Optional real-device selector used only for nextAction") var device: String?
    @Option(help: "Artifact discovery root") var output: String?
    @Option(help: "Build timeout in seconds") var timeout: Double?
    @Flag(help: "Emit JSON Lines progress and final summary") var jsonl = false
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: json or text") var format: ClientOutputFormat = .json

    func run() async throws {
        let request = CLIBuildRequest.harmony(
            project: project,
            hvigor: hvigor,
            module: module,
            mode: mode,
            device: device,
            timeout: timeout,
            discoveryRoot: output,
            node: node,
            javaHome: javaHome,
            devecoSdkHome: devecoSdkHome,
            product: product,
            task: task,
            noDaemon: noDaemon
        )
        try runBuildCommand(request: request, jsonl: jsonl, outputFormat: effectiveFormat(format, json: json))
    }
}

private func runBuildCommand(request: CLIBuildRequest, jsonl: Bool, outputFormat: ClientOutputFormat) throws {
    do {
        let summary = try runCLIBuild(request, jsonl: jsonl)
        switch outputFormat {
        case .json:
            if !jsonl {
                print(try encodeJSON(summary))
            }
        case .text:
            if let artifact = summary.artifactPath {
                print(artifact)
            }
            if let note = summary.note {
                print(note)
            }
        }
    } catch {
        let summary = buildFailureSummary(error: error, request: request, jsonl: jsonl)
        switch outputFormat {
        case .json:
            if jsonl {
                writeJSONLLine(try encodeCompactJSON(summary))
            } else {
                print(try encodeJSON(summary))
            }
        case .text:
            print(summary.error?.message ?? "\(error)")
            if let hint = summary.error?.hint {
                print("hint: \(hint)")
            }
        }
        throw ExitCode.failure
    }
}
