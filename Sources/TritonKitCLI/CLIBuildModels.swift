import Foundation
import TritonKitShared

enum CLIBuildRequest {
    case android(project: String, gradle: String?, variant: String, device: String?, timeout: Double?, discoveryRoot: String?)
    case harmony(project: String, hvigor: String?, module: String, mode: String, device: String?, timeout: Double?, discoveryRoot: String?)
}

struct CLIBuildPlan: Equatable {
    let platform: String
    let action: String
    let project: String
    let executable: String
    let arguments: [String]
    let workingDirectory: String
    let variant: String?
    let module: String?
    let mode: String?
    let device: String?
    let timeout: Double
    let discoveryRoot: String?

    var sourceCommand: String {
        ([executable] + arguments).map(shellEscaped).joined(separator: " ")
    }
}

struct CLIBuildLogPaths: Equatable {
    let directory: String
    let stdoutLogPath: String
    let stderrLogPath: String
}

struct CLIBuildProcessResult: Equatable {
    let exitCode: Int32
    let stdoutBytes: Int
    let stderrBytes: Int
}

struct CLIBuildArtifact: Encodable, Equatable {
    let path: String
    let kind: String
    let bytes: Int
}

struct CLIBuildLogSummary: Encodable, Equatable {
    let path: String
    let bytes: Int
}

struct CLIBuildDiagnosticsSummary: Encodable, Equatable {
    let warningCount: Int
    let errorCount: Int
    let warningSamples: [String]
    let errorSamples: [String]
}

struct TKBuildProgressEvent: Encodable, Equatable {
    let ok: Bool
    let event: String
    let platform: String
    let message: String
    let sourceCommand: String?
    let elapsedMs: Int?
    let stdoutLogPath: String?
    let stderrLogPath: String?
}

struct TKBuildActionSummary: Encodable, Equatable {
    let ok: Bool
    let action: String
    let platform: String
    let project: String
    let variant: String?
    let module: String?
    let mode: String?
    let device: String?
    let artifact: String?
    let artifactPath: String?
    let artifactKind: String?
    let artifactBytes: Int?
    let sourceCommand: String?
    let exitCode: Int32
    let stdoutLogPath: String?
    let stderrLogPath: String?
    let stdoutBytes: Int?
    let stderrBytes: Int?
    let durationMs: Int
    let diagnostics: CLIBuildDiagnosticsSummary?
    let error: TKCLIErrorDetail?
    let nextAction: TKCLINextAction?
    let note: String?
}

enum CLIBuildError: Error, CustomStringConvertible {
    case validationFailed(String)
    case toolNotFound(platform: String, tool: String, project: String)
    case commandLaunchFailed(platform: String, plan: CLIBuildPlan, logs: CLIBuildLogPaths, message: String)
    case commandTimedOut(platform: String, plan: CLIBuildPlan, logs: CLIBuildLogPaths, timeout: Double)
    case buildFailed(platform: String, plan: CLIBuildPlan, logs: CLIBuildLogPaths, result: CLIBuildProcessResult)
    case artifactNotFound(platform: String, plan: CLIBuildPlan, logs: CLIBuildLogPaths, result: CLIBuildProcessResult)

    var description: String {
        switch self {
        case .validationFailed(let message):
            message
        case .toolNotFound(let platform, let tool, let project):
            "\(platform) build tool not found: \(tool) in \(project)"
        case .commandLaunchFailed(_, let plan, _, let message):
            "Failed to launch build command `\(plan.sourceCommand)`: \(message)"
        case .commandTimedOut(_, let plan, _, let timeout):
            "Build command timed out after \(timeout)s: \(plan.sourceCommand)"
        case .buildFailed(_, let plan, _, let result):
            "Build command failed with exit \(result.exitCode): \(plan.sourceCommand)"
        case .artifactNotFound(let platform, let plan, _, _):
            "No \(platform == "android" ? "APK" : "HAP") artifact was found after build: \(plan.project)"
        }
    }
}
