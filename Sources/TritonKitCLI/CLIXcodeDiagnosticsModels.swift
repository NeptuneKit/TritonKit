import Foundation
import TritonKitShared

struct XcodeArtifactLogStatus: Codable, Equatable {
    let stdoutLogPath: String?
    let stderrLogPath: String?
    let lastOutputAt: String?
    let stdoutBytes: Int?
    let stderrBytes: Int?
}

struct XcodeProcessSummary: Codable, Equatable {
    let pid: Int
    let name: String
    let commandLine: String
    let elapsed: String?
    let elapsedSeconds: Int?
    let workspace: String?
    let project: String?
    let scheme: String?
    let destination: String?
    let derivedDataPath: String?
    let confidence: String
}

struct XcodeProcessStatusSummary: Codable, Equatable {
    let xcodebuildCount: Int
    let buildServiceCount: Int
    let xctestCount: Int
    let matchingWorkspaceCount: Int
}

struct XcodeProcessStatusOutput: Codable, Equatable {
    let ok: Bool
    let active: Bool
    let workspaceFilter: String?
    let derivedDataCache: TKXcodeDerivedDataCacheInfo
    let processes: [XcodeProcessSummary]
    let summary: XcodeProcessStatusSummary
    let sourceCommand: String
    let stdoutLogPath: String?
    let stderrLogPath: String?
    let lastOutputAt: String?
    let stdoutBytes: Int?
    let stderrBytes: Int?

    init(
        ok: Bool,
        active: Bool,
        workspaceFilter: String?,
        derivedDataCache: TKXcodeDerivedDataCacheInfo = makeXcodeDerivedDataCacheInfo(path: nil),
        processes: [XcodeProcessSummary],
        summary: XcodeProcessStatusSummary,
        sourceCommand: String,
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        lastOutputAt: String? = nil,
        stdoutBytes: Int? = nil,
        stderrBytes: Int? = nil
    ) {
        self.ok = ok
        self.active = active
        self.workspaceFilter = workspaceFilter
        self.derivedDataCache = derivedDataCache
        self.processes = processes
        self.summary = summary
        self.sourceCommand = sourceCommand
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.lastOutputAt = lastOutputAt
        self.stdoutBytes = stdoutBytes
        self.stderrBytes = stderrBytes
    }
}

struct XcodeWaitIdleOutput: Codable, Equatable {
    let ok: Bool
    let action: String
    let idle: Bool
    let workspaceFilter: String?
    let elapsedMs: Int
    let pollCount: Int
    let status: XcodeProcessStatusOutput
}

struct XcodeDerivedDataCacheState: Codable, Equatable {
    let derivedDataPath: String
    let exists: Bool
    let cacheState: String
    let incrementalExpected: Bool
}

enum XcodeDiagnosticsError: Error, Equatable, CustomStringConvertible {
    case notIdle(status: XcodeProcessStatusOutput)

    var description: String {
        switch self {
        case .notIdle(let status):
            let pids = status.processes.map { "\($0.pid)" }.joined(separator: ", ")
            return "Xcode build/test activity is still running" + (pids.isEmpty ? "." : ": \(pids)")
        }
    }
}
