import ArgumentParser
import Foundation
import TritonKitShared

enum HostDevicePlatform: String, ExpressibleByArgument {
    case ios
    case android
    case harmony
}

extension HostDevicePlatform: Codable {}

enum HostPlatform: String, ExpressibleByArgument {
    case android
    case harmony
}

struct HostToolProbeOutput: Encodable {
    let name: String
    let path: String
    let available: Bool
    let versionSummary: String?
    let error: String?
    let sourceCommand: String
}

struct HostSimulatorScreenshotDisplayMetadata: Encodable, Equatable {
    let rawLine: String?
    let displayID: String?
    let screenID: String?
    let name: String?
}

struct HostSimulatorScreenshotOutput: Encodable {
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
    let stderr: String?
    let artifact: String
    let pixelWidth: Int?
    let pixelHeight: Int?
    let display: HostSimulatorScreenshotDisplayMetadata
    let orientationPolicy: String
    let orientationNote: String
    let note: String
}

struct HostDeviceTarget: Encodable, Equatable {
    let platform: String
    let id: String
    let target: String
    let state: String
    let ready: Bool
    let source: String
    let name: String?
    let runtime: String?
    let transport: String?
}

struct HostTargetAlias: Codable, Equatable {
    let platform: HostDevicePlatform
    let target: String
}

struct HostTargetAliasStore: Codable, Equatable {
    let schemaVersion: Int
    var current: String?
    var aliases: [String: HostTargetAlias]

    init(schemaVersion: Int = 1, current: String? = nil, aliases: [String: HostTargetAlias] = [:]) {
        self.schemaVersion = schemaVersion
        self.current = current
        self.aliases = aliases
    }

    static let empty = HostTargetAliasStore()

    static func filePath(workspace: String) -> String {
        URL(fileURLWithPath: workspace)
            .appendingPathComponent(".triton")
            .appendingPathComponent("host-targets.json")
            .path
    }
}

enum HostDeviceSelectorSource: String, Codable {
    case alias
    case explicit
    case current
    case platformFilter = "platform-filter"
    case globalUnique = "global-unique"
}

struct HostDeviceSelectionRequest: Equatable {
    var device: String?
    var platform: HostDevicePlatform?
    var name: String?
    var runtime: String?
    var state: String?
    var ready: Bool

    init(
        device: String? = nil,
        platform: HostDevicePlatform? = nil,
        name: String? = nil,
        runtime: String? = nil,
        state: String? = nil,
        ready: Bool = false
    ) {
        self.device = device
        self.platform = platform
        self.name = name
        self.runtime = runtime
        self.state = state
        self.ready = ready
    }
}

struct HostDeviceSelectionResult: Encodable, Equatable {
    let platform: HostDevicePlatform
    let target: HostDeviceTarget
    let selector: String
    let source: HostDeviceSelectorSource
    let filters: HostDeviceSelectionFilters
}

struct HostDeviceSelectionFilters: Encodable, Equatable {
    let platform: String?
    let name: String?
    let runtime: String?
    let state: String?
    let ready: Bool

    init(request: HostDeviceSelectionRequest) {
        self.platform = request.platform?.rawValue
        self.name = request.name
        self.runtime = request.runtime
        self.state = request.state
        self.ready = request.ready
    }
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
    let targets: [HostDeviceTarget]
    let defaultTarget: HostDeviceTarget?
    let sourceCommand: String
}

struct HostDeviceUseOutput: Encodable {
    let ok: Bool
    let platform: String
    let target: HostDeviceTarget
    let defaultsPath: String?
    let selection: HostDeviceSelectionResult?
}

struct HostDeviceAliasListOutput: Encodable {
    let ok: Bool
    let current: String?
    let aliases: [String: HostTargetAlias]
    let path: String
}

struct HostDeviceAliasMutationOutput: Encodable {
    let ok: Bool
    let action: String
    let name: String
    let alias: HostTargetAlias?
    let path: String
}

struct HostDeviceCurrentOutput: Encodable {
    let ok: Bool
    let current: String?
    let selection: HostDeviceSelectionResult?
    let path: String
}

struct HostDeviceResolveOutput: Encodable {
    let ok: Bool
    let selection: HostDeviceSelectionResult
}

struct HostDeviceSelectionErrorOutput: Encodable {
    let ok: Bool
    let error: TKCLIErrorDetail
    let candidates: [HostDeviceTarget]
}

struct HostDeviceReadyEvent: Encodable {
    let ok: Bool
    let platform: String
    let target: HostDeviceTarget
    let ready: Bool
    let attempt: Int
    let sourceCommand: String
    let error: TKCLIErrorDetail?
}

struct HostDeviceArtifactOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let selection: HostDeviceSelectionResult?
    let artifact: String
    let sourceCommands: [String]
    let note: String
}

struct HarmonyEmulatorStopPlan {
    let action: String
    let platform: String
    let hvd: String
    let deployedPath: String
    let emulator: String
    let launchdLabel: String?
    let launchdDomain: String?
    let commands: [TKHostCommand]
}

struct HostDeviceStopOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let hvd: String
    let deployedPath: String
    let emulator: String
    let launchdLabel: String?
    let launchdDomain: String?
    let sourceCommands: [String]
    let note: String
}

enum HostDeviceSelectionError: Error, CustomStringConvertible {
    case ambiguousTargets([HostDeviceTarget])
    case targetNotFound(String)
    case platformMismatch(selector: String, expected: HostDevicePlatform, actual: HostDevicePlatform)
    case parameterConflict(String)

    var description: String {
        switch self {
        case .ambiguousTargets(let targets):
            "Multiple connected host devices found: \(targets.map(\.target).joined(separator: ", "))"
        case .targetNotFound(let target):
            "Host device was not found: \(target)"
        case .platformMismatch(let selector, let expected, let actual):
            "Host device selector \(selector) resolved to \(actual.rawValue), but \(expected.rawValue) was requested"
        case .parameterConflict(let message):
            message
        }
    }
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

struct HostHarmonySwipeOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: TKHarmonyTarget
    let startX: Int
    let startY: Int
    let endX: Int
    let endY: Int
    let velocity: Int?
    let sourceCommands: [String]
    let note: String
}

struct HostHarmonyTextInputOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: TKHarmonyTarget
    let x: Int?
    let y: Int?
    let secure: Bool
    let redacted: Bool
    let insertedLength: Int
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

struct HostAndroidTapMatch: Encodable, Equatable {
    let text: String?
    let identifier: String?
    let label: String?
    let role: String?
    let bounds: TKRect?
}

struct HostAndroidArtifactOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let artifact: String
    let sourceCommands: [String]
    let note: String
}

struct HostAndroidTapOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let query: String?
    let x: Int
    let y: Int
    let match: HostAndroidTapMatch?
    let sourceCommands: [String]
    let note: String
}

struct HostAndroidSwipeOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let startX: Int
    let startY: Int
    let endX: Int
    let endY: Int
    let durationMs: Int?
    let sourceCommands: [String]
    let note: String
}

struct HostAndroidTextInputOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let x: Int?
    let y: Int?
    let secure: Bool
    let redacted: Bool
    let insertedLength: Int
    let sourceCommands: [String]
    let note: String
}

struct HostAndroidWaitOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let condition: String
    let query: String
    let matched: Bool
    let timedOut: Bool
    let elapsedMs: Int
    let pollCount: Int
    let match: HostAndroidTapMatch?
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
            "Host device target \(target) was not ready after \(timeoutSeconds)s"
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

enum HostArtifactOutputError: Error, CustomStringConvertible {
    case rejected(path: String, reason: String)

    var description: String {
        switch self {
        case .rejected(let path, let reason):
            "Artifact output path rejected: \(path) (\(reason))"
        }
    }
}

enum XcresultCLIError: Error, CustomStringConvertible {
    case parseFailed(kind: String, underlying: Error)
    case outputTooLarge(kind: String, bytes: Int, maximumBytes: Int)

    var description: String {
        switch self {
        case .parseFailed(let kind, let underlying):
            "Failed to parse xcresult \(kind) JSON: \(underlying)"
        case .outputTooLarge(let kind, let bytes, let maximumBytes):
            "xcresult \(kind) JSON is too large to parse inline: \(bytes) bytes exceeds \(maximumBytes) bytes"
        }
    }
}

struct HostSimulatorListOutput: Encodable {
    let ok: Bool
    let simulators: [TKHostSimulatorTarget]
}

struct HostSimulatorRuntimeListOutput: Encodable {
    let ok: Bool
    let runtimes: [TKHostSimulatorRuntime]
    let count: Int
    let verbose: Bool
    let sourceCommand: String
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

struct HostSimulatorScreenshotMetadata: Encodable, Equatable {
    let path: String
    let contentType: String
    let pixelWidth: Int?
    let pixelHeight: Int?
    let orientationSemantics: String
    let normalizationApplied: Bool
    let normalizationStrategy: String
    let note: String
}

struct HostActionOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let selection: HostDeviceSelectionResult?
    let tool: String
    let exitCode: Int32
    let riskLevel: String
    let sourceCommand: String
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let stdout: String?
    let stderr: String?
    let artifacts: [String]
    let screenshot: HostSimulatorScreenshotMetadata?
    let note: String?

    init(
        ok: Bool,
        action: String,
        runtimeScope: String,
        target: String,
        selection: HostDeviceSelectionResult? = nil,
        tool: String,
        exitCode: Int32,
        riskLevel: String,
        sourceCommand: String,
        stdoutTruncated: Bool,
        stderrTruncated: Bool,
        stdout: String?,
        stderr: String?,
        artifacts: [String],
        screenshot: HostSimulatorScreenshotMetadata? = nil,
        note: String?
    ) {
        self.ok = ok
        self.action = action
        self.runtimeScope = runtimeScope
        self.target = target
        self.selection = selection
        self.tool = tool
        self.exitCode = exitCode
        self.riskLevel = riskLevel
        self.sourceCommand = sourceCommand
        self.stdoutTruncated = stdoutTruncated
        self.stderrTruncated = stderrTruncated
        self.stdout = stdout
        self.stderr = stderr
        self.artifacts = artifacts
        self.screenshot = screenshot
        self.note = note
    }
}

struct HostArtifactCaptureOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let tool: String
    let exitCode: Int32
    let riskLevel: String
    let sourceCommand: String
    let artifact: String
    let stdoutBytes: Int
    let stderrBytes: Int
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let stderr: String?
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
