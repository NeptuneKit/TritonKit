import ArgumentParser
import Darwin
import Foundation
import TritonKitShared

func planCLIBuild(_ request: CLIBuildRequest) throws -> CLIBuildPlan {
    switch request {
    case .android(let project, let gradle, let variant, let device, let timeout, let discoveryRoot):
        let projectRoot = try validateBuildProject(project)
        let executable = try resolveBuildTool(explicit: gradle, wrapperName: "gradlew", fallbackName: "gradle", project: projectRoot, platform: "android")
        return CLIBuildPlan(
            platform: "android",
            action: "build.android",
            project: projectRoot,
            executable: executable,
            arguments: [androidGradleTask(variant: variant)],
            workingDirectory: projectRoot,
            variant: variant,
            module: nil,
            mode: nil,
            device: device,
            timeout: timeout ?? 600,
            discoveryRoot: discoveryRoot
        )
    case .harmony(
        let project,
        let hvigor,
        let module,
        let mode,
        let device,
        let timeout,
        let discoveryRoot,
        let node,
        let javaHome,
        let devecoSdkHome,
        let product,
        let task,
        let noDaemon
    ):
        let projectRoot = try validateBuildProject(project)
        let nodeExecutable = try node.map {
            try resolveBuildTool(explicit: $0, wrapperName: "node", fallbackName: "node", project: projectRoot, platform: "harmony")
        }
        let executable = try resolveHarmonyBuildExecutable(
            hvigor: hvigor,
            node: nodeExecutable,
            project: projectRoot
        )
        let environment = harmonyBuildEnvironment(javaHome: javaHome, devecoSdkHome: devecoSdkHome)
        let arguments = harmonyBuildArguments(
            hvigor: executable.hvigor,
            node: nodeExecutable,
            module: module,
            mode: mode,
            product: product,
            task: task,
            noDaemon: noDaemon
        )
        return CLIBuildPlan(
            platform: "harmony",
            action: "build.harmony",
            project: projectRoot,
            executable: executable.executable,
            arguments: arguments,
            workingDirectory: projectRoot,
            variant: nil,
            module: module,
            mode: mode,
            device: device,
            timeout: timeout ?? 600,
            discoveryRoot: discoveryRoot,
            environment: environment
        )
    }
}

func runCLIBuild(_ request: CLIBuildRequest, jsonl: Bool = false) throws -> TKBuildActionSummary {
    let plan = try planCLIBuild(request)
    return try runCLIBuildPlan(plan, jsonl: jsonl)
}

func runCLIBuildPlan(_ plan: CLIBuildPlan, jsonl: Bool = false) throws -> TKBuildActionSummary {
    let startedAt = Date()
    let logs = try createBuildLogPaths(platform: plan.platform)
    if jsonl {
        writeJSONLLine(try encodeCompactJSON(TKBuildProgressEvent(
            ok: true,
            event: "build.\(plan.platform).invocation",
            platform: plan.platform,
            message: "started",
            sourceCommand: plan.sourceCommand,
            elapsedMs: 0,
            stdoutLogPath: logs.stdoutLogPath,
            stderrLogPath: logs.stderrLogPath
        )))
    }

    let result = try runBuildProcess(plan: plan, logs: logs)
    if result.exitCode != 0 {
        throw CLIBuildError.buildFailed(platform: plan.platform, plan: plan, logs: logs, result: result)
    }

    guard let artifact = discoverBuildArtifact(plan: plan) else {
        throw CLIBuildError.artifactNotFound(platform: plan.platform, plan: plan, logs: logs, result: result)
    }

    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
    let summary = TKBuildActionSummary(
        ok: true,
        action: plan.action,
        platform: plan.platform,
        project: plan.project,
        variant: plan.variant,
        module: plan.module,
        mode: plan.mode,
        device: plan.device,
        artifact: artifact.path,
        artifactPath: artifact.path,
        artifactKind: artifact.kind,
        artifactBytes: artifact.bytes,
        sourceCommand: plan.sourceCommand,
        exitCode: result.exitCode,
        stdoutLogPath: logs.stdoutLogPath,
        stderrLogPath: logs.stderrLogPath,
        stdoutBytes: result.stdoutBytes,
        stderrBytes: result.stderrBytes,
        durationMs: durationMs,
        diagnostics: summarizeBuildDiagnostics(stdoutLogPath: logs.stdoutLogPath, stderrLogPath: logs.stderrLogPath),
        error: nil,
        nextAction: buildNextAction(plan: plan, artifact: artifact),
        note: "Build produced a debug artifact. Install and verify business readiness with app, smoke, wait/assert, or evidence."
    )
    if jsonl {
        writeJSONLLine(try encodeCompactJSON(summary))
    }
    return summary
}

func buildFailureSummary(error: Error, request: CLIBuildRequest?, jsonl: Bool) -> TKBuildActionSummary {
    let detail = buildErrorDetail(error)
    let plan = try? request.map(planCLIBuild)
    let logs = buildErrorLogs(error)
    return TKBuildActionSummary(
        ok: false,
        action: plan?.action ?? buildActionName(request: request),
        platform: plan?.platform ?? buildPlatformName(request: request),
        project: plan?.project ?? buildProjectName(request: request),
        variant: plan?.variant,
        module: plan?.module,
        mode: plan?.mode,
        device: plan?.device,
        artifact: nil,
        artifactPath: nil,
        artifactKind: nil,
        artifactBytes: nil,
        sourceCommand: plan?.sourceCommand,
        exitCode: buildErrorExitCode(error),
        stdoutLogPath: logs?.stdoutLogPath,
        stderrLogPath: logs?.stderrLogPath,
        stdoutBytes: nil,
        stderrBytes: nil,
        durationMs: 0,
        diagnostics: logs.map { summarizeBuildDiagnostics(stdoutLogPath: $0.stdoutLogPath, stderrLogPath: $0.stderrLogPath) },
        error: detail,
        nextAction: detail.nextAction,
        note: "Build did not produce an installable artifact."
    )
}

func buildIOSSummary(
    from summary: TKXcodeActionSummary,
    device: String?
) -> TKBuildActionSummary {
    let artifactPath = summary.appPath
    return TKBuildActionSummary(
        ok: summary.ok,
        action: "build.ios",
        platform: "ios",
        project: summary.workspace ?? summary.project ?? "",
        variant: nil,
        module: nil,
        mode: summary.configuration,
        device: device ?? iosDeviceID(fromDestination: summary.destination),
        artifact: artifactPath,
        artifactPath: artifactPath,
        artifactKind: artifactPath == nil ? nil : "app",
        artifactBytes: artifactPath.flatMap(buildArtifactBytes),
        sourceCommand: summary.sourceCommand,
        exitCode: summary.exitCode,
        stdoutLogPath: summary.stdoutLogPath,
        stderrLogPath: summary.stderrLogPath,
        stdoutBytes: summary.stdoutBytes,
        stderrBytes: summary.stderrBytes,
        durationMs: summary.durationMs,
        diagnostics: xcodeBuildDiagnostics(summary),
        error: nil,
        nextAction: buildIOSNextAction(appPath: artifactPath, device: device ?? iosDeviceID(fromDestination: summary.destination)),
        note: artifactPath == nil
            ? "Xcode build finished. Resolve the built .app path before install, then verify business readiness with app, smoke, wait/assert, or evidence."
            : "Build produced an iOS app bundle. Install and verify business readiness with app, smoke, wait/assert, or evidence."
    )
}

func buildIOSFailureSummary(
    error: Error,
    workspace: String?,
    project: String?,
    device: String?,
    jsonl _: Bool
) -> TKBuildActionSummary {
    let detail = buildXcodeErrorDetail(error)
    return TKBuildActionSummary(
        ok: false,
        action: "build.ios",
        platform: "ios",
        project: workspace ?? project ?? "",
        variant: nil,
        module: nil,
        mode: nil,
        device: device,
        artifact: nil,
        artifactPath: nil,
        artifactKind: nil,
        artifactBytes: nil,
        sourceCommand: xcodeErrorSourceCommand(error),
        exitCode: buildErrorExitCode(error),
        stdoutLogPath: xcodeErrorLogs(error)?.stdoutLogPath,
        stderrLogPath: xcodeErrorLogs(error)?.stderrLogPath,
        stdoutBytes: nil,
        stderrBytes: nil,
        durationMs: 0,
        diagnostics: xcodeErrorLogs(error).map { summarizeBuildDiagnostics(stdoutLogPath: $0.stdoutLogPath, stderrLogPath: $0.stderrLogPath) },
        error: detail,
        nextAction: detail.nextAction,
        note: "Build did not produce an installable iOS app bundle."
    )
}

func printBuildActionSummary(_ summary: TKBuildActionSummary, jsonl: Bool, outputFormat: ClientOutputFormat) throws {
    switch outputFormat {
    case .json:
        if jsonl {
            writeJSONLLine(try encodeCompactJSON(summary))
        } else {
            print(try encodeJSON(summary))
        }
    case .text:
        if let artifact = summary.artifactPath {
            print(artifact)
        } else {
            print(summary.action)
        }
        if let note = summary.note {
            print(note)
        }
    }
}

func buildErrorDetail(_ error: Error) -> TKCLIErrorDetail {
    switch error {
    case let build as CLIBuildError:
        return buildErrorDetail(build)
    case let validation as ValidationError:
        return TKCLIErrorDetail(
            code: "validation_failed",
            message: "\(validation)",
            hint: "Fix the CLI arguments and retry `triton build ... --json`.",
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "build", "--json"], category: "diagnose")
        )
    case let host as HostCommandRunError:
        return TKCLIErrorDetail(
            code: "host_action_failed",
            message: "\(host)",
            hint: "Inspect the build tool, project path, and generated logs.",
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "build", "--json"], category: "diagnose")
        )
    default:
        return TKCLIErrorDetail(
            code: "host_action_failed",
            message: "\(error)",
            hint: "Inspect the build tool, project path, and generated logs.",
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "build", "--json"], category: "diagnose")
        )
    }
}

private func buildErrorDetail(_ error: CLIBuildError) -> TKCLIErrorDetail {
    switch error {
    case .validationFailed(let message):
        return TKCLIErrorDetail(
            code: "validation_failed",
            message: message,
            hint: "Fix the CLI arguments and retry.",
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "build", "--json"], category: "diagnose")
        )
    case .toolNotFound(let platform, let tool, let project):
        return TKCLIErrorDetail(
            code: platform == "android" ? "gradle_not_found" : "hvigor_not_found",
            message: "\(tool) was not found for \(platform) project \(project).",
            hint: "Pass an explicit build tool path or add the wrapper to the project root.",
            nextAction: TKCLINextAction(command: "build", args: [platform, "--project", project, platform == "android" ? "--gradle" : "--hvigor", "<path>", "--json"], category: "project")
        )
    case .commandLaunchFailed(let platform, let plan, _, let message):
        return TKCLIErrorDetail(
            code: platform == "android" ? "gradle_not_found" : "hvigor_not_found",
            message: message,
            hint: "Verify the build executable is runnable.",
            nextAction: TKCLINextAction(command: "build", args: [platform, "--project", plan.project, "--json"], category: "project")
        )
    case .commandTimedOut(let platform, let plan, _, let timeout):
        return TKCLIErrorDetail(
            code: platform == "android" ? "gradle_build_failed" : "hvigor_build_failed",
            message: "Build timed out after \(timeout)s.",
            hint: "Increase --timeout or inspect the stdout/stderr logs.",
            nextAction: TKCLINextAction(command: "build", args: [platform, "--project", plan.project, "--timeout", "\(Int(timeout * 2))", "--jsonl"], category: "project", requiresLongRunningProcess: true)
        )
    case .buildFailed(let platform, let plan, _, _):
        return TKCLIErrorDetail(
            code: platform == "android" ? "gradle_build_failed" : "hvigor_build_failed",
            message: "\(error)",
            hint: "Inspect the build stdout/stderr logs for compiler, signing, or profile diagnostics.",
            nextAction: TKCLINextAction(command: "build", args: [platform, "--project", plan.project, "--jsonl"], category: "project", requiresLongRunningProcess: true)
        )
    case .artifactNotFound(let platform, let plan, _, _):
        return TKCLIErrorDetail(
            code: platform == "android" ? "apk_artifact_not_found" : "hap_artifact_not_found",
            message: "\(error)",
            hint: "Pass --output to the artifact directory or verify the debug build task produced an installable artifact.",
            nextAction: TKCLINextAction(command: "build", args: [platform, "--project", plan.project, "--output", "<artifact-dir>", "--json"], category: "project")
        )
    }
}

private func validateBuildProject(_ project: String) throws -> String {
    let path = URL(fileURLWithPath: project).standardizedFileURL.path
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw CLIBuildError.validationFailed("Build project path does not exist or is not a directory: \(project)")
    }
    return path
}

private func resolveBuildTool(explicit: String?, wrapperName: String, fallbackName: String, project: String, platform: String) throws -> String {
    if let explicit, !explicit.isEmpty {
        if explicit.contains("/") {
            let path = URL(fileURLWithPath: explicit, relativeTo: URL(fileURLWithPath: project)).standardizedFileURL.path
            guard FileManager.default.isExecutableFile(atPath: path) else {
                throw CLIBuildError.toolNotFound(platform: platform, tool: explicit, project: project)
            }
            return path
        }
        guard findExecutableOnPATH(explicit) != nil else {
            throw CLIBuildError.toolNotFound(platform: platform, tool: explicit, project: project)
        }
        return explicit
    }

    let wrapper = URL(fileURLWithPath: project).appendingPathComponent(wrapperName).path
    if FileManager.default.isExecutableFile(atPath: wrapper) {
        return wrapper
    }
    guard findExecutableOnPATH(fallbackName) != nil else {
        throw CLIBuildError.toolNotFound(platform: platform, tool: fallbackName, project: project)
    }
    return fallbackName
}

private func resolveHarmonyBuildExecutable(hvigor: String?, node: String?, project: String) throws -> (executable: String, hvigor: String?) {
    guard let node else {
        let executable = try resolveBuildTool(
            explicit: hvigor,
            wrapperName: "hvigorw",
            fallbackName: "hvigor",
            project: project,
            platform: "harmony"
        )
        return (executable, nil)
    }

    guard let hvigor, !hvigor.isEmpty else {
        throw CLIBuildError.toolNotFound(platform: "harmony", tool: "hvigor.js", project: project)
    }
    if hvigor.contains("/") {
        let path = URL(fileURLWithPath: hvigor, relativeTo: URL(fileURLWithPath: project)).standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIBuildError.toolNotFound(platform: "harmony", tool: hvigor, project: project)
        }
        return (node, path)
    }
    guard findExecutableOnPATH(hvigor) != nil else {
        throw CLIBuildError.toolNotFound(platform: "harmony", tool: hvigor, project: project)
    }
    return (node, hvigor)
}

private func harmonyBuildArguments(
    hvigor: String?,
    node: String?,
    module: String,
    mode: String,
    product: String?,
    task: String?,
    noDaemon: Bool
) -> [String] {
    guard node != nil || task != nil || product != nil || noDaemon else {
        return ["--mode", "\(module)@\(mode)", "assembleHap"]
    }

    let taskName = trimmedBuildValue(task) ?? "assembleHap"
    var arguments: [String] = []
    if let hvigor {
        arguments.append(hvigor)
    }
    arguments.append(taskName)
    if noDaemon {
        arguments.append("--no-daemon")
    }
    if taskName == "assembleApp" || product != nil {
        arguments.append(contentsOf: [
            "-p",
            "product=\(trimmedBuildValue(product) ?? "default")",
            "-p",
            "buildMode=\(mode)",
        ])
    }
    return arguments
}

private func trimmedBuildValue(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func harmonyBuildEnvironment(javaHome: String?, devecoSdkHome: String?) -> [String: String] {
    var environment: [String: String] = [:]
    if let javaHome = javaHome?.trimmingCharacters(in: .whitespacesAndNewlines), !javaHome.isEmpty {
        environment["JAVA_HOME"] = javaHome
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        environment["PATH"] = currentPath.isEmpty ? "\(javaHome)/bin" : "\(javaHome)/bin:\(currentPath)"
    }
    if let devecoSdkHome = devecoSdkHome?.trimmingCharacters(in: .whitespacesAndNewlines), !devecoSdkHome.isEmpty {
        environment["DEVECO_SDK_HOME"] = devecoSdkHome
    }
    return environment
}

private func findExecutableOnPATH(_ name: String) -> String? {
    ProcessInfo.processInfo.environment["PATH"]?
        .split(separator: ":")
        .map(String.init)
        .map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
        .first { FileManager.default.isExecutableFile(atPath: $0) }
}

private func androidGradleTask(variant: String) -> String {
    "assemble" + variant
        .split { !$0.isLetter && !$0.isNumber }
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined()
}

private func createBuildLogPaths(platform: String) throws -> CLIBuildLogPaths {
    let directory = URL(fileURLWithPath: ".triton")
        .appendingPathComponent("build")
        .appendingPathComponent("\(platform)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return CLIBuildLogPaths(
        directory: directory.path,
        stdoutLogPath: directory.appendingPathComponent("stdout.log").path,
        stderrLogPath: directory.appendingPathComponent("stderr.log").path
    )
}

private func runBuildProcess(plan: CLIBuildPlan, logs: CLIBuildLogPaths) throws -> CLIBuildProcessResult {
    let process = Process()
    if plan.executable.contains("/") {
        process.executableURL = URL(fileURLWithPath: plan.executable)
        process.arguments = plan.arguments
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [plan.executable] + plan.arguments
    }
    process.currentDirectoryURL = URL(fileURLWithPath: plan.workingDirectory)
    if !plan.environment.isEmpty {
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in plan.environment {
            environment[key] = value
        }
        process.environment = environment
    }

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
    } catch {
        throw CLIBuildError.commandLaunchFailed(platform: plan.platform, plan: plan, logs: logs, message: error.localizedDescription)
    }

    let stdoutGroup = DispatchGroup()
    let stderrGroup = DispatchGroup()
    var stdoutBytes = 0
    var stderrBytes = 0
    var stdoutError: Error?
    var stderrError: Error?

    stdoutGroup.enter()
    DispatchQueue.global(qos: .utility).async {
        let result = drainBuildPipeToFile(stdout, outputPath: logs.stdoutLogPath)
        stdoutBytes = result.bytes
        stdoutError = result.error
        stdoutGroup.leave()
    }
    stderrGroup.enter()
    DispatchQueue.global(qos: .utility).async {
        let result = drainBuildPipeToFile(stderr, outputPath: logs.stderrLogPath)
        stderrBytes = result.bytes
        stderrError = result.error
        stderrGroup.leave()
    }

    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .utility).async {
        process.waitUntilExit()
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + plan.timeout) == .timedOut {
        process.terminate()
        if semaphore.wait(timeout: .now() + 2) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            _ = semaphore.wait(timeout: .now() + 2)
        }
        _ = stdoutGroup.wait(timeout: .now() + 2)
        _ = stderrGroup.wait(timeout: .now() + 2)
        throw CLIBuildError.commandTimedOut(platform: plan.platform, plan: plan, logs: logs, timeout: plan.timeout)
    }

    stdoutGroup.wait()
    stderrGroup.wait()
    if let stdoutError {
        throw CLIBuildError.commandLaunchFailed(platform: plan.platform, plan: plan, logs: logs, message: stdoutError.localizedDescription)
    }
    if let stderrError {
        throw CLIBuildError.commandLaunchFailed(platform: plan.platform, plan: plan, logs: logs, message: stderrError.localizedDescription)
    }
    return CLIBuildProcessResult(exitCode: process.terminationStatus, stdoutBytes: stdoutBytes, stderrBytes: stderrBytes)
}

private func drainBuildPipeToFile(_ pipe: Pipe, outputPath: String) -> (bytes: Int, error: Error?) {
    do {
        FileManager.default.createFile(atPath: outputPath, contents: nil)
        let output = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
        defer { try? output.close() }
        var bytes = 0
        while true {
            let chunk = pipe.fileHandleForReading.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { break }
            try output.write(contentsOf: chunk)
            bytes += chunk.count
        }
        return (bytes, nil)
    } catch {
        return (0, error)
    }
}

func discoverBuildArtifact(plan: CLIBuildPlan) -> CLIBuildArtifact? {
    let root = plan.discoveryRoot.map { URL(fileURLWithPath: $0, relativeTo: URL(fileURLWithPath: plan.project)).standardizedFileURL.path } ?? plan.project
    let fileExtension = plan.platform == "android" ? "apk" : "hap"
    let kind = fileExtension
    let urls = allFiles(root: root, fileExtension: fileExtension)
    let preferred = urls.sorted { lhs, rhs in
        artifactScore(lhs.path, plan: plan) > artifactScore(rhs.path, plan: plan)
    }.first
    guard let preferred else {
        return nil
    }
    let bytes = (try? FileManager.default.attributesOfItem(atPath: preferred.path)[.size] as? NSNumber)?.intValue ?? 0
    return CLIBuildArtifact(path: preferred.path, kind: kind, bytes: bytes)
}

private func allFiles(root: String, fileExtension: String) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        return []
    }
    return enumerator.compactMap { item in
        guard let url = item as? URL, url.pathExtension.lowercased() == fileExtension else { return nil }
        return url
    }
}

private func artifactScore(_ path: String, plan: CLIBuildPlan) -> Int {
    let lower = path.lowercased()
    var score = 0
    if lower.contains("/outputs/") { score += 100 }
    if let variant = plan.variant?.lowercased(), lower.contains(variant) { score += 20 }
    if let module = plan.module?.lowercased(), lower.contains("/\(module)/") { score += 20 }
    if let mode = plan.mode?.lowercased(), lower.contains(mode) { score += 20 }
    if lower.contains("debug") { score += 10 }
    return score
}

private func buildNextAction(plan: CLIBuildPlan, artifact: CLIBuildArtifact) -> TKCLINextAction {
    if plan.platform == "android" {
        var args = ["install", "--scope", "real", "--platform", "android", "--apk", artifact.path, "--json"]
        if let device = plan.device { args.insert(contentsOf: ["--device", device], at: 1) }
        return TKCLINextAction(command: "app", args: args, category: "act")
    }
    var args = ["install", "--scope", "real", "--platform", "harmony", "--hap", artifact.path, "--json"]
    if let device = plan.device { args.insert(contentsOf: ["--device", device], at: 1) }
    return TKCLINextAction(command: "app", args: args, category: "act")
}

private func buildIOSNextAction(appPath: String?, device: String?) -> TKCLINextAction? {
    guard let appPath else { return nil }
    var args = ["install", "--scope", "real", "--platform", "ios", "--app", appPath, "--json"]
    if let device { args.insert(contentsOf: ["--device", device], at: 1) }
    return TKCLINextAction(command: "app", args: args, category: "act")
}

private func buildArtifactBytes(_ path: String) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue
}

private func iosDeviceID(fromDestination destination: String?) -> String? {
    guard let destination else { return nil }
    return destination
        .split(separator: ",")
        .map(String.init)
        .first { $0.hasPrefix("id=") }
        .map { String($0.dropFirst(3)) }
}

private func xcodeBuildDiagnostics(_ summary: TKXcodeActionSummary) -> CLIBuildDiagnosticsSummary? {
    guard let stdoutLogPath = summary.stdoutLogPath,
          let stderrLogPath = summary.stderrLogPath else {
        return nil
    }
    return summarizeBuildDiagnostics(stdoutLogPath: stdoutLogPath, stderrLogPath: stderrLogPath)
}

private func buildXcodeErrorDetail(_ error: Error) -> TKCLIErrorDetail {
    switch error {
    case let validation as ValidationError:
        return TKCLIErrorDetail(
            code: "validation_failed",
            message: "\(validation)",
            hint: "Fix the CLI arguments and retry `triton build ios ... --json`.",
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "build", "--json"], category: "diagnose")
        )
    case XcodeWorkflowError.missingContainer:
        return TKCLIErrorDetail(
            code: "invalid_workspace_path",
            message: "\(error)",
            hint: "Pass --workspace or --project, or configure defaults with `triton xcode use`.",
            nextAction: TKCLINextAction(command: "xcode", args: ["discover", "--path", ".", "--json"], category: "diagnose")
        )
    case XcodeWorkflowError.ambiguousContainer:
        return TKCLIErrorDetail(
            code: "ambiguous_workspace",
            message: "\(error)",
            hint: "Pass exactly one of --workspace or --project.",
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "build", "--json"], category: "diagnose")
        )
    case XcodeWorkflowError.missingScheme:
        return TKCLIErrorDetail(
            code: "scheme_not_found",
            message: "\(error)",
            hint: "Run `triton xcode schemes --workspace <path> --json` to inspect schemes.",
            nextAction: TKCLINextAction(command: "xcode", args: ["schemes", "--json"], category: "diagnose")
        )
    case let host as HostCommandRunError:
        return buildXcodeHostErrorDetail(host)
    default:
        return TKCLIErrorDetail(
            code: "xcodebuild_failed",
            message: "\(error)",
            hint: "Inspect the xcodebuild output, signing, provisioning profile, device readiness, and DDI state.",
            nextAction: TKCLINextAction(command: "build", args: ["ios", "--jsonl"], category: "project", requiresLongRunningProcess: true)
        )
    }
}

private func buildXcodeHostErrorDetail(_ error: HostCommandRunError) -> TKCLIErrorDetail {
    switch error {
    case .nonZeroExit(let command, let result):
        let combinedOutput = "\(result.stdout)\n\(result.stderr)".lowercased()
        let code: String
        if combinedOutput.contains("provisioning profile") || combinedOutput.contains("profile") {
            code = "provisioning_profile_missing"
        } else if combinedOutput.contains("signing") || combinedOutput.contains("codesign") || combinedOutput.contains("certificate") {
            code = "xcode_signing_failed"
        } else {
            code = "xcodebuild_failed"
        }
        return TKCLIErrorDetail(
            code: code,
            message: "xcodebuild failed with exit \(result.exitCode): \(sourceCommand(command))",
            hint: "Inspect the xcodebuild output, workspace/project, scheme, destination, signing, provisioning profile, and DerivedData path.",
            nextAction: TKCLINextAction(command: "build", args: ["ios", "--jsonl"], category: "project", requiresLongRunningProcess: true)
        )
    case .deviceNotReady(let target, _):
        return TKCLIErrorDetail(
            code: "device_not_ready",
            message: "\(target) is not ready for iOS build/run.",
            hint: "Run `triton device wait-ready --platform ios --scope real --device <selector> --json` and inspect blocked reasons.",
            nextAction: TKCLINextAction(command: "device", args: ["wait-ready", "--platform", "ios", "--scope", "real", "--device", target, "--json"], category: "diagnose")
        )
    case .timeout:
        return TKCLIErrorDetail(
            code: "xcodebuild_failed",
            message: "\(error)",
            hint: "Increase --timeout or inspect xcodebuild stdout/stderr logs.",
            nextAction: TKCLINextAction(command: "build", args: ["ios", "--timeout", "1200", "--jsonl"], category: "project", requiresLongRunningProcess: true)
        )
    default:
        return TKCLIErrorDetail(
            code: "xcodebuild_failed",
            message: "\(error)",
            hint: "Inspect the xcodebuild output, signing, provisioning profile, device readiness, and DDI state.",
            nextAction: TKCLINextAction(command: "build", args: ["ios", "--jsonl"], category: "project", requiresLongRunningProcess: true)
        )
    }
}

private func xcodeErrorLogs(_ error: Error) -> CLIBuildLogPaths? {
    guard case let HostCommandRunError.nonZeroExit(_, result) = error else { return nil }
    guard let stdoutLogPath = result.stdoutLogPath,
          let stderrLogPath = result.stderrLogPath else {
        return nil
    }
    return CLIBuildLogPaths(directory: URL(fileURLWithPath: stdoutLogPath).deletingLastPathComponent().path, stdoutLogPath: stdoutLogPath, stderrLogPath: stderrLogPath)
}

private func xcodeErrorSourceCommand(_ error: Error) -> String? {
    if case let HostCommandRunError.nonZeroExit(command, _) = error {
        return sourceCommand(command)
    }
    return nil
}

private func sourceCommand(_ command: TKHostCommand) -> String {
    ([command.executable] + command.arguments).map(shellEscaped).joined(separator: " ")
}

private func summarizeBuildDiagnostics(stdoutLogPath: String, stderrLogPath: String) -> CLIBuildDiagnosticsSummary {
    let lines = Array((readBuildLogLines(stdoutLogPath) + readBuildLogLines(stderrLogPath)).prefix(2000))
    let warningLines = lines.filter { $0.localizedCaseInsensitiveContains("warning") }
    let errorLines = lines.filter { $0.localizedCaseInsensitiveContains("error") || $0.localizedCaseInsensitiveContains("failed") }
    return CLIBuildDiagnosticsSummary(
        warningCount: warningLines.count,
        errorCount: errorLines.count,
        warningSamples: Array(warningLines.prefix(5)),
        errorSamples: Array(errorLines.prefix(5))
    )
}

private func readBuildLogLines(_ path: String) -> [String] {
    guard let data = FileManager.default.contents(atPath: path),
          let text = String(data: data, encoding: .utf8) else {
        return []
    }
    return text.split(whereSeparator: \.isNewline).map(String.init)
}

private func buildErrorLogs(_ error: Error) -> CLIBuildLogPaths? {
    switch error {
    case let error as CLIBuildError:
        switch error {
        case .commandLaunchFailed(_, _, let logs, _),
             .commandTimedOut(_, _, let logs, _),
             .buildFailed(_, _, let logs, _),
             .artifactNotFound(_, _, let logs, _):
            return logs
        case .validationFailed, .toolNotFound:
            return nil
        }
    default:
        return nil
    }
}

private func buildErrorExitCode(_ error: Error) -> Int32 {
    if case let CLIBuildError.buildFailed(_, _, _, result) = error {
        return result.exitCode
    }
    return 1
}

private func buildActionName(request: CLIBuildRequest?) -> String {
    switch request {
    case .android: return "build.android"
    case .harmony: return "build.harmony"
    case nil: return "build"
    }
}

private func buildPlatformName(request: CLIBuildRequest?) -> String {
    switch request {
    case .android: return "android"
    case .harmony: return "harmony"
    case nil: return "unknown"
    }
}

private func buildProjectName(request: CLIBuildRequest?) -> String {
    switch request {
    case .android(let project, _, _, _, _, _): return project
    case .harmony(let project, _, _, _, _, _, _, _, _, _, _, _, _): return project
    case nil: return ""
    }
}
