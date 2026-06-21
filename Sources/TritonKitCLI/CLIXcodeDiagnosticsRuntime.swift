import Foundation
import TritonKitShared

func xcodeDerivedDataCacheState(path: String, fileManager: FileManager = .default) -> XcodeDerivedDataCacheState {
    let exists = fileManager.fileExists(atPath: path)
    return XcodeDerivedDataCacheState(
        derivedDataPath: path,
        exists: exists,
        cacheState: exists ? "warm" : "missing-derived-data",
        incrementalExpected: true
    )
}

enum XcodeBuildOutputDiagnosticsParser {
    static func parse(stdout: String, stderr: String, maximumSamples: Int = 5) -> TKXcodeOutputDiagnostic? {
        let combined = [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !combined.isEmpty else { return nil }

        let samples = combined
            .split(whereSeparator: \.isNewline)
            .compactMap { parseStaleDerivedDataLine(String($0)) }
        guard !samples.isEmpty else { return nil }

        return TKXcodeOutputDiagnostic(
            kind: "stale-derived-data-outside-root",
            message: "xcodebuild reported stale DerivedData files outside the allowed root paths.",
            matchCount: samples.count,
            samples: Array(samples.prefix(maximumSamples)),
            recovery: "Use a fresh --derived-data-path for this checkout or remove the stale .triton/DerivedData directory before retrying.",
            nextAction: TKCLINextAction(
                command: "xcode",
                args: ["build", "--derived-data-path", "<fresh-derived-data-path>", "--jsonl"],
                category: "recover"
            )
        )
    }

    private static func parseStaleDerivedDataLine(_ line: String) -> TKXcodeOutputDiagnosticSample? {
        guard line.contains("Stale file "),
              line.contains(" is located outside of the allowed root paths") else {
            return nil
        }
        guard let pathStart = line.range(of: "Stale file '")?.upperBound,
              let pathEnd = line[pathStart...].firstIndex(of: "'") else {
            return nil
        }
        let path = String(line[pathStart..<pathEnd])
        guard path.contains("/.triton/DerivedData/") || path.contains(".triton/DerivedData/") else {
            return nil
        }
        return TKXcodeOutputDiagnosticSample(
            path: path,
            message: line.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

enum XcodeProcessDiagnosticsParser {
    static func parse(
        psOutput: String,
        workspace: String? = nil,
        derivedDataPath: String? = nil,
        sourceCommand: String = "ps -axo pid=,comm=,etime=,args=",
        latestLogs: XcodeArtifactLogStatus? = nil
    ) throws -> XcodeProcessStatusOutput {
        let allProcesses = psOutput
            .split(whereSeparator: \.isNewline)
            .compactMap(parseLine)
            .filter(isXcodeBuildRelated)
        let filtered = workspace.flatMap { workspace in
            allProcesses.filter { process in
                process.workspace == workspace || process.project == workspace || process.commandLine.contains(workspace)
            }
        } ?? allProcesses
        let summary = XcodeProcessStatusSummary(
            xcodebuildCount: filtered.filter { $0.name == "xcodebuild" }.count,
            buildServiceCount: filtered.filter { isBuildServiceName($0.name) }.count,
            xctestCount: filtered.filter { $0.name == "xctest" }.count,
            matchingWorkspaceCount: workspace == nil ? 0 : filtered.count
        )
        return XcodeProcessStatusOutput(
            ok: true,
            active: !filtered.isEmpty,
            workspaceFilter: workspace,
            derivedDataCache: makeXcodeDerivedDataCacheInfo(
                path: derivedDataPath ?? filtered.first(where: { $0.derivedDataPath != nil })?.derivedDataPath
            ),
            processes: filtered,
            summary: summary,
            sourceCommand: sourceCommand,
            stdoutLogPath: latestLogs?.stdoutLogPath,
            stderrLogPath: latestLogs?.stderrLogPath,
            lastOutputAt: latestLogs?.lastOutputAt,
            stdoutBytes: latestLogs?.stdoutBytes,
            stderrBytes: latestLogs?.stderrBytes
        )
    }

    private static func parseLine(_ line: Substring) -> XcodeProcessSummary? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count >= 4, let pid = Int(parts[0]) else { return nil }
        let commandPath = String(parts[1])
        let elapsed = String(parts[2])
        let commandLine = String(parts[3])
        let name = processName(commandPath: commandPath, commandLine: commandLine)
        return XcodeProcessSummary(
            pid: pid,
            name: name,
            commandLine: commandLine,
            elapsed: elapsed,
            elapsedSeconds: elapsedSeconds(elapsed),
            workspace: argument(after: "-workspace", in: commandLine),
            project: argument(after: "-project", in: commandLine),
            scheme: argument(after: "-scheme", in: commandLine),
            destination: argument(after: "-destination", in: commandLine),
            derivedDataPath: argument(after: "-derivedDataPath", in: commandLine),
            confidence: name == "xcodebuild" ? "medium" : "low"
        )
    }

    private static func processName(commandPath: String, commandLine: String) -> String {
        let commandLineName = commandLine
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { URL(fileURLWithPath: String($0)).lastPathComponent }
        let commandName = URL(fileURLWithPath: commandPath).lastPathComponent
        return commandLineName?.isEmpty == false ? commandLineName! : commandName
    }

    private static func isXcodeBuildRelated(_ process: XcodeProcessSummary) -> Bool {
        guard !process.commandLine.contains("grep xcodebuild") else { return false }
        let names: Set<String> = ["xcodebuild", "SwiftBuildService", "XCBBuildService", "xctest"]
        return names.contains(process.name)
    }

    private static func isBuildServiceName(_ name: String) -> Bool {
        name == "SwiftBuildService" || name == "XCBBuildService"
    }

    private static func argument(after flag: String, in commandLine: String) -> String? {
        let tokens = shellLikeTokens(commandLine)
        guard let index = tokens.firstIndex(of: flag), tokens.indices.contains(index + 1) else {
            return nil
        }
        return tokens[index + 1]
    }

    private static func shellLikeTokens(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        for char in value {
            if escaping {
                current.append(char)
                escaping = false
                continue
            }
            if char == "\\" {
                escaping = true
                continue
            }
            if let activeQuote = quote {
                if char == activeQuote {
                    quote = nil
                } else {
                    current.append(char)
                }
                continue
            }
            if char == "\"" || char == "'" {
                quote = char
                continue
            }
            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func elapsedSeconds(_ elapsed: String) -> Int? {
        let daySplit = elapsed.split(separator: "-", maxSplits: 1).map(String.init)
        let days: Int
        let timePart: String
        if daySplit.count == 2 {
            days = Int(daySplit[0]) ?? 0
            timePart = daySplit[1]
        } else {
            days = 0
            timePart = elapsed
        }
        let components = timePart.split(separator: ":").compactMap { Int($0) }
        switch components.count {
        case 3:
            return days * 86_400 + components[0] * 3_600 + components[1] * 60 + components[2]
        case 2:
            return days * 86_400 + components[0] * 60 + components[1]
        case 1:
            return days * 86_400 + components[0]
        default:
            return nil
        }
    }
}

func latestXcodeArtifactLogStatus(
    artifactsRoot: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("triton-xcode-artifacts", isDirectory: true),
    fileManager: FileManager = .default
) -> XcodeArtifactLogStatus? {
    guard let children = try? fileManager.contentsOfDirectory(
        at: artifactsRoot,
        includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        return nil
    }

    var best: (directory: URL, modifiedAt: Date)?
    for child in children {
        let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        guard values?.isDirectory == true else { continue }
        let stdout = child.appendingPathComponent("stdout.log")
        let stderr = child.appendingPathComponent("stderr.log")
        guard fileManager.fileExists(atPath: stdout.path) || fileManager.fileExists(atPath: stderr.path) else { continue }
        let modifiedAt = [logModificationDate(stdout), logModificationDate(stderr), values?.contentModificationDate]
            .compactMap { $0 }
            .max() ?? Date.distantPast
        if best == nil || modifiedAt > best!.modifiedAt {
            best = (child, modifiedAt)
        }
    }

    guard let best else { return nil }
    let stdout = best.directory.appendingPathComponent("stdout.log")
    let stderr = best.directory.appendingPathComponent("stderr.log")
    let stdoutPath = fileManager.fileExists(atPath: stdout.path) ? stdout.path : nil
    let stderrPath = fileManager.fileExists(atPath: stderr.path) ? stderr.path : nil
    return XcodeArtifactLogStatus(
        stdoutLogPath: stdoutPath,
        stderrLogPath: stderrPath,
        lastOutputAt: ISO8601DateFormatter().string(from: best.modifiedAt),
        stdoutBytes: stdoutPath.map { fileSize(atPath: $0) },
        stderrBytes: stderrPath.map { fileSize(atPath: $0) }
    )
}

private func logModificationDate(_ url: URL) -> Date? {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
}

private func fileSize(atPath path: String) -> Int {
    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue
    return size ?? 0
}

func currentXcodeProcessStatus(workspace: String? = nil) throws -> XcodeProcessStatusOutput {
    let defaults = try? loadHostWorkspaceDefaults()
    let derivedDataPath = defaults?.xcode?.derivedDataPath ?? defaultXcodeDerivedDataPath
    let latestLogs = latestXcodeArtifactLogStatus()
    let pgrep = TKHostCommand(
        executable: "pgrep",
        arguments: ["-f", "xcodebuild|swift-build|SwiftBuildService|XCBBuildService|xctest"],
        defaultTimeoutSeconds: 5
    )
    let pidResult: HostProcessResult
    do {
        pidResult = try runHostCommand(pgrep)
    } catch HostCommandRunError.nonZeroExit {
        return try XcodeProcessDiagnosticsParser.parse(
            psOutput: "",
            workspace: workspace,
            derivedDataPath: derivedDataPath,
            sourceCommand: hostSourceCommand(pgrep),
            latestLogs: latestLogs
        )
    }
    let pids = pidResult.stdout
        .split(whereSeparator: \.isNewline)
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    guard !pids.isEmpty else {
        return try XcodeProcessDiagnosticsParser.parse(
            psOutput: "",
            workspace: workspace,
            derivedDataPath: derivedDataPath,
            sourceCommand: pidResult.sourceCommand,
            latestLogs: latestLogs
        )
    }
    let command = TKHostCommand(
        executable: "ps",
        arguments: ["-p", pids.map(String.init).joined(separator: ","), "-o", "pid=,comm=,etime=,args="],
        defaultTimeoutSeconds: 5
    )
    let result = try runHostCommand(command)
    return try XcodeProcessDiagnosticsParser.parse(
        psOutput: result.stdout,
        workspace: workspace,
        derivedDataPath: derivedDataPath,
        sourceCommand: result.sourceCommand,
        latestLogs: latestLogs
    )
}

func waitForXcodeIdle(
    workspace: String?,
    timeout: Double,
    interval: Double,
    statusProvider: () throws -> XcodeProcessStatusOutput = { try currentXcodeProcessStatus(workspace: nil) }
) async throws -> XcodeWaitIdleOutput {
    let startedAt = Date()
    let deadline = startedAt.addingTimeInterval(timeout)
    var pollCount = 0
    var lastStatus: XcodeProcessStatusOutput?
    var lastTransientError: Error?
    while true {
        pollCount += 1
        let status: XcodeProcessStatusOutput
        do {
            status = try statusProvider()
        } catch let error as HostCommandRunError {
            guard case .timeout = error else {
                throw error
            }
            lastTransientError = error
            if pollCount > 1 && Date() >= deadline {
                break
            }
            try await Task.sleep(nanoseconds: UInt64(max(0.01, interval) * 1_000_000_000))
            continue
        }
        lastStatus = status
        if !status.active {
            return XcodeWaitIdleOutput(
                ok: true,
                action: "xcode.wait-idle",
                idle: true,
                workspaceFilter: workspace,
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                pollCount: pollCount,
                status: status
            )
        }
        if Date() >= deadline {
            break
        }
        try await Task.sleep(nanoseconds: UInt64(max(0.01, interval) * 1_000_000_000))
    }

    if let lastStatus {
        throw XcodeDiagnosticsError.notIdle(status: lastStatus)
    }
    if let lastTransientError {
        throw lastTransientError
    }
    throw XcodeDiagnosticsError.notIdle(status: XcodeProcessStatusOutput(
        ok: true,
        active: false,
        workspaceFilter: workspace,
        derivedDataCache: makeXcodeDerivedDataCacheInfo(path: nil),
        processes: [],
        summary: XcodeProcessStatusSummary(xcodebuildCount: 0, buildServiceCount: 0, xctestCount: 0, matchingWorkspaceCount: 0),
        sourceCommand: "ps -axo pid=,comm=,etime=,args="
    ))
}
