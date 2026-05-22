import Foundation
import TritonKitShared

struct HostToolProbeOutput: Encodable {
    let name: String
    let path: String
    let available: Bool
    let versionSummary: String?
    let error: String?
    let sourceCommand: String
}

struct HostDeviceDoctorOutput: Encodable {
    let ok: Bool
    let platform: String
    let tools: [HostToolProbeOutput]
    let capabilities: [String]
    let artifactsSaved: Bool
}

struct HostDeviceListOutput: Encodable {
    let ok: Bool
    let platform: String
    let targets: [TKHarmonyTarget]
    let defaultTarget: TKHarmonyTarget?
    let sourceCommand: String
}

struct HostDeviceUseOutput: Encodable {
    let ok: Bool
    let platform: String
    let target: TKHarmonyTarget
}

struct HostDeviceReadyEvent: Encodable {
    let ok: Bool
    let platform: String
    let target: TKHarmonyTarget
    let ready: Bool
    let attempt: Int
    let sourceCommand: String
    let error: TKCLIErrorDetail?
}

struct HostRuntimeURLOutput: Encodable {
    let ok: Bool
    let platform: String
    let target: TKHarmonyTarget
    let localPort: Int
    let remotePort: Int
    let baseURL: String
    let forwarded: Bool
    let sourceCommand: String?
    let manifest: TKRuntimeManifestResponse?
    let note: String
}

struct HostHarmonyArtifactOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: TKHarmonyTarget
    let artifact: String
    let sourceCommands: [String]
    let note: String
}

struct HostHarmonyTapOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: TKHarmonyTarget
    let query: String?
    let x: Int
    let y: Int
    let match: TKHarmonyLayoutTextMatch?
    let sourceCommands: [String]
    let note: String
}

struct HostHarmonyWaitOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: TKHarmonyTarget
    let condition: String
    let query: String
    let matched: Bool
    let timedOut: Bool
    let elapsedMs: Int
    let pollCount: Int
    let match: TKHarmonyLayoutTextMatch?
    let sourceCommands: [String]
}

enum HostSimulatorRunError: Error, CustomStringConvertible {
    case simulatorNotFound(String)

    var description: String {
        switch self {
        case .simulatorNotFound(let udid):
            "Simulator was not found: \(udid)"
        }
    }
}

enum HostDeviceRunError: Error, CustomStringConvertible {
    case ambiguousTarget([TKHarmonyTarget])
    case targetOffline(String)
    case targetNotFound(String)

    var description: String {
        switch self {
        case .ambiguousTarget(let targets):
            "Multiple connected Harmony targets found: \(targets.map(\.target).joined(separator: ", "))"
        case .targetOffline(let target):
            "Harmony target is offline: \(target)"
        case .targetNotFound(let target):
            "Harmony target was not found: \(target)"
        }
    }
}

struct HostProcessResult {
    let stdoutData: Data
    let stderrData: Data
    let exitCode: Int32
    let sourceCommand: String
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let stdoutLogPath: String?
    let stderrLogPath: String?
    let stdoutBytes: Int
    let stderrBytes: Int

    var stdout: String {
        String(data: stdoutData, encoding: .utf8) ?? ""
    }

    var stderr: String {
        String(data: stderrData, encoding: .utf8) ?? ""
    }
}

enum HostCommandRunError: Error, CustomStringConvertible {
    case launchFailed(String)
    case timeout(command: TKHostCommand, timeoutSeconds: Double, stdoutLogPath: String?, stderrLogPath: String?)
    case nonZeroExit(command: TKHostCommand, result: HostProcessResult)
    case deviceNotReady(target: String, timeoutSeconds: Double)
    case layoutPathNotFound
    case layoutTextNotFound(String)
    case missingPreferences(path: String)
    case preferenceKeyNotFound(String)

    var description: String {
        switch self {
        case .launchFailed(let message):
            message
        case .timeout(let command, let timeoutSeconds, let stdoutLogPath, let stderrLogPath):
            [
                "Host command timed out after \(timeoutSeconds)s: \(hostSourceCommand(command))",
                stdoutLogPath.map { "stdout: \($0)" },
                stderrLogPath.map { "stderr: \($0)" },
            ].compactMap { $0 }.joined(separator: "\n")
        case .deviceNotReady(let target, let timeoutSeconds):
            "Harmony target \(target) was not ready after \(timeoutSeconds)s"
        case .nonZeroExit(_, let result):
            result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Host command exited \(result.exitCode)" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        case .missingPreferences(let path):
            "Preferences plist not found: \(path)"
        case .preferenceKeyNotFound(let key):
            "Preference key not found: \(key)"
        case .layoutPathNotFound:
            "Harmony uitest dumpLayout output did not include a remote layout path"
        case .layoutTextNotFound(let text):
            "Harmony layout text was not found: \(text)"
        }
    }
}

struct HostSimulatorListOutput: Encodable {
    let ok: Bool
    let simulators: [TKHostSimulatorTarget]
}

struct HostSimulatorUseOutput: Encodable {
    let ok: Bool
    let action: String
    let simulator: TKHostSimulatorTarget
    let defaultsPath: String
}

struct HostSimulatorReadyEvent: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let state: String?
    let ready: Bool
    let attempt: Int
    let elapsedMs: Int
    let sourceCommand: String?
}

struct HostActionOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let tool: String
    let exitCode: Int32
    let riskLevel: String
    let sourceCommand: String
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let stdout: String?
    let stderr: String?
    let artifacts: [String]
    let note: String?
}

struct HostAppContainerOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let kind: String
    let path: String
}

struct HostAppListOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let userOnly: Bool
    let count: Int
    let apps: [TKHostInstalledApp]
}

struct HostAppInfoOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let app: TKHostInstalledApp
}

struct HostPreferencesOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let plistPath: String
    let key: String?
    let value: TKHostPreferenceValue?
    let preferences: [String: TKHostPreferenceValue]?
}

struct HostPreferencesSetOutput: Encodable {
    let ok: Bool
    let action: String
    let simulatorUDID: String
    let bundleID: String
    let plistPath: String
    let key: String
    let previousValue: TKHostPreferenceValue?
    let newValue: TKHostPreferenceValue
    let restartAdvice: String
}

struct HostPreferencePlistUpdateResult {
    let data: Data
    let previousValue: TKHostPreferenceValue?
    let newValue: TKHostPreferenceValue
}
