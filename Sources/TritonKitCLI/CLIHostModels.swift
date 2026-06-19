import ArgumentParser
import Foundation
import TritonKitShared

enum HostDevicePlatform: String, ExpressibleByArgument {
    case ios
    case android
    case harmony
}

extension HostDevicePlatform: Codable {}

enum HostDeviceScope: String, ExpressibleByArgument, Codable {
    case simulator
    case emulator
    case real
    case all
}

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

struct HostSimulatorInputOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let adapter: String
    let tool: String
    let exitCode: Int32
    let riskLevel: String
    let sourceCommand: String
    let stdoutTruncated: Bool
    let stderrTruncated: Bool
    let stdout: String?
    let stderr: String?
    let x: Int?
    let y: Int?
    let insertedLength: Int?
    let textEncoding: String?
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
    let scope: String?
    let kind: String?
    let appName: String?
    let bundleIdentifier: String?
    let identityState: String?
    let current: Bool?
    let blockedReasons: [String]
    let sensitive: Bool
    let rawTarget: String

    init(
        platform: String,
        id: String,
        target: String,
        state: String,
        ready: Bool,
        source: String,
        name: String?,
        runtime: String?,
        transport: String?,
        scope: String? = nil,
        kind: String? = nil,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        identityState: String? = nil,
        current: Bool? = nil,
        blockedReasons: [String] = [],
        sensitive: Bool = false,
        rawTarget: String? = nil
    ) {
        self.platform = platform
        self.id = id
        self.target = target
        self.state = state
        self.ready = ready
        self.source = source
        self.name = name
        self.runtime = runtime
        self.transport = transport
        self.scope = scope
        self.kind = kind
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.identityState = identityState
        self.current = current
        self.blockedReasons = blockedReasons
        self.sensitive = sensitive
        self.rawTarget = rawTarget ?? target
    }

    enum CodingKeys: String, CodingKey {
        case platform
        case id
        case target
        case state
        case ready
        case source
        case name
        case runtime
        case transport
        case scope
        case kind
        case appName
        case bundleIdentifier
        case identityState
        case current
        case blockedReasons
        case sensitive
    }
}

struct HostTargetAlias: Codable, Equatable {
    let platform: HostDevicePlatform
    let scope: HostDeviceScope?
    let kind: String?
    let target: String
    let sensitiveRef: String?

    init(
        platform: HostDevicePlatform,
        target: String,
        scope: HostDeviceScope? = nil,
        kind: String? = nil,
        sensitiveRef: String? = nil
    ) {
        self.platform = platform
        self.scope = scope
        self.kind = kind
        self.target = target
        self.sensitiveRef = sensitiveRef
    }
}

struct HostTargetAliasStore: Codable, Equatable {
    let schemaVersion: Int
    var current: String?
    var aliases: [String: HostTargetAlias]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case current
        case aliases
    }

    init(schemaVersion: Int = 2, current: String? = nil, aliases: [String: HostTargetAlias] = [:]) {
        self.schemaVersion = schemaVersion
        self.current = current
        self.aliases = aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.current = try container.decodeIfPresent(String.self, forKey: .current)
        self.aliases = try container.decodeIfPresent([String: HostTargetAlias].self, forKey: .aliases) ?? [:]
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
    var scope: HostDeviceScope?
    var name: String?
    var runtime: String?
    var state: String?
    var ready: Bool

    init(
        device: String? = nil,
        platform: HostDevicePlatform? = nil,
        scope: HostDeviceScope? = nil,
        name: String? = nil,
        runtime: String? = nil,
        state: String? = nil,
        ready: Bool = false
    ) {
        self.device = device
        self.platform = platform
        self.scope = scope
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
    let scope: String?
    let name: String?
    let runtime: String?
    let state: String?
    let ready: Bool

    init(request: HostDeviceSelectionRequest) {
        self.platform = request.platform?.rawValue
        self.scope = request.scope?.rawValue
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
    let sourceCommands: [String]
    let nextAction: TKCLINextAction?

    init(
        ok: Bool,
        platform: String,
        targets: [HostDeviceTarget],
        defaultTarget: HostDeviceTarget?,
        sourceCommand: String,
        sourceCommands: [String]? = nil,
        nextAction: TKCLINextAction? = nil
    ) {
        self.ok = ok
        self.platform = platform
        self.targets = targets
        self.defaultTarget = defaultTarget
        self.sourceCommand = sourceCommand
        self.sourceCommands = sourceCommands ?? [sourceCommand]
        self.nextAction = nextAction
    }
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
    let sourceCommands: [String]
    let error: TKCLIErrorDetail?

    init(
        ok: Bool,
        platform: String,
        target: HostDeviceTarget,
        ready: Bool,
        attempt: Int,
        sourceCommand: String,
        sourceCommands: [String]? = nil,
        error: TKCLIErrorDetail?
    ) {
        self.ok = ok
        self.platform = platform
        self.target = target
        self.ready = ready
        self.attempt = attempt
        self.sourceCommand = sourceCommand
        self.sourceCommands = sourceCommands ?? [sourceCommand]
        self.error = error
    }
}

struct HostScreenshotArtifactMetadata: Encodable, Equatable {
    let bytes: Int
    let width: Int?
    let height: Int?
    let sha256: String
    let capturedAt: String
}

struct HostDeviceArtifactOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let target: HostDeviceTarget
    let selection: HostDeviceSelectionResult?
    let artifact: String
    let format: String
    let bytes: Int
    let width: Int?
    let height: Int?
    let sha256: String
    let capturedAt: String
    let sourceCommands: [String]
    let note: String

    init(
        ok: Bool,
        action: String,
        platform: String,
        target: HostDeviceTarget,
        selection: HostDeviceSelectionResult?,
        artifact: String,
        format: String,
        metadata: HostScreenshotArtifactMetadata,
        sourceCommands: [String],
        note: String
    ) {
        self.ok = ok
        self.action = action
        self.platform = platform
        self.target = target
        self.selection = selection
        self.artifact = artifact
        self.format = format
        self.bytes = metadata.bytes
        self.width = metadata.width
        self.height = metadata.height
        self.sha256 = metadata.sha256
        self.capturedAt = metadata.capturedAt
        self.sourceCommands = sourceCommands
        self.note = note
    }
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

enum AndroidDeviceReadinessError: Error, CustomStringConvertible {
    case unauthorized(String)
    case offline(String)
    case debuggingDisabled(String)
    case packageManagerUnavailable(String, String)

    var description: String {
        switch self {
        case .unauthorized(let target):
            "Android target is unauthorized: \(target)"
        case .offline(let target):
            "Android target is offline: \(target)"
        case .debuggingDisabled(let target):
            "Android debugging is disabled or host permissions are missing for target: \(target)"
        case .packageManagerUnavailable(let target, let detail):
            "Android package manager is unavailable on target \(target): \(detail)"
        }
    }

    var code: String {
        switch self {
        case .unauthorized:
            "android_target_unauthorized"
        case .offline:
            "android_target_offline"
        case .debuggingDisabled:
            "android_debugging_disabled"
        case .packageManagerUnavailable:
            "android_package_manager_unavailable"
        }
    }

    var hint: String {
        switch self {
        case .unauthorized:
            "Authorize USB debugging on the Android device, then rerun `triton device wait-ready --platform android --scope real --json`."
        case .offline:
            "Reconnect the Android device or restart adb, then verify it appears as state=device in `adb devices -l`."
        case .debuggingDisabled:
            "Enable Developer options and USB debugging, and verify host USB permissions allow adb access."
        case .packageManagerUnavailable:
            "Wait for Android boot/package services to finish, unlock if needed, or increase --timeout."
        }
    }
}

enum AndroidADBToolError: Error, CustomStringConvertible {
    case notFound(String)

    var description: String {
        switch self {
        case .notFound(let executable):
            "Android adb executable was not found: \(executable)"
        }
    }

    var code: String {
        switch self {
        case .notFound:
            "android_adb_not_found"
        }
    }

    var hint: String {
        switch self {
        case .notFound:
            "Install Android SDK platform-tools or pass --adb <path> to the Triton command."
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

struct HostActionSubmissionEvidence: Encodable, Equatable {
    let ok: Bool
    let proofSource: String
    let businessReady: Bool
    let nextAction: TKCLINextAction
}

struct HostActionOutput: Encodable {
    let ok: Bool
    let action: String
    let runtimeScope: String
    let target: String
    let selection: HostDeviceSelectionResult?
    let hostAction: HostActionSubmissionEvidence
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
        hostAction: HostActionSubmissionEvidence? = nil,
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
        self.hostAction = hostAction ?? HostActionSubmissionEvidence(
            ok: ok,
            proofSource: "host-action",
            businessReady: false,
            nextAction: TKCLINextAction(command: "smoke", args: ["<platform>", "--device", "<selector>", "--json"])
        )
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
    let valuePlistType: String?
    let preferences: [String: TKHostPreferenceValue]?
    let preferencesPlistTypes: [String: String]?
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
    let previousPlistType: String?
    let newPlistType: String
    let restartAdvice: String
}

struct HostPreferencePlistUpdateResult {
    let data: Data
    let previousValue: TKHostPreferenceValue?
    let newValue: TKHostPreferenceValue
    let previousPlistType: String?
    let newPlistType: String
}
