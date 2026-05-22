import Foundation
import TritonKitShared

enum XcodeProcessDiagnosticsParser {
    static func parse(
        psOutput: String,
        workspace: String? = nil,
        sourceCommand: String = "ps -axo pid=,comm=,etime=,args="
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
            processes: filtered,
            summary: summary,
            sourceCommand: sourceCommand
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
        let names: Set<String> = ["xcodebuild", "swift-build", "SwiftBuildService", "XCBBuildService", "xctest"]
        return names.contains(process.name)
    }

    private static func isBuildServiceName(_ name: String) -> Bool {
        name == "swift-build" || name == "SwiftBuildService" || name == "XCBBuildService"
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

func currentXcodeProcessStatus(workspace: String? = nil) throws -> XcodeProcessStatusOutput {
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
            sourceCommand: hostSourceCommand(pgrep)
        )
    }
    let pids = pidResult.stdout
        .split(whereSeparator: \.isNewline)
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    guard !pids.isEmpty else {
        return try XcodeProcessDiagnosticsParser.parse(
            psOutput: "",
            workspace: workspace,
            sourceCommand: pidResult.sourceCommand
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
        sourceCommand: result.sourceCommand
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
    repeat {
        pollCount += 1
        let status = try statusProvider()
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
    } while Date() <= deadline

    throw XcodeDiagnosticsError.notIdle(status: lastStatus ?? XcodeProcessStatusOutput(
        ok: true,
        active: false,
        workspaceFilter: workspace,
        processes: [],
        summary: XcodeProcessStatusSummary(xcodebuildCount: 0, buildServiceCount: 0, xctestCount: 0, matchingWorkspaceCount: 0),
        sourceCommand: "ps -axo pid=,comm=,etime=,args="
    ))
}
