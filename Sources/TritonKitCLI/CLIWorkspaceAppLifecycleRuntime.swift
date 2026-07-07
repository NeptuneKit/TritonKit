import Foundation
import TritonKitShared

typealias TKWorkspaceAppLifecycleProvider = (TKWorkspaceAppLifecycleRequest) async throws -> TKWorkspaceAppLifecycleEvidence

struct TKWorkspaceAppLifecycleRequest: Equatable {
    let mode: String
    let platform: String?
    let scope: String?
    let target: String
    let app: String
    let bundleID: String?
    let packageName: String?
    let activity: String?
    let bundle: String?
    let ability: String?
    let adb: String
    let hdc: String
}

struct TKWorkspaceAppLifecycleEvidence: Codable, Equatable {
    let mode: String
    let phase: String
    let action: String
    let app: String
    let platform: String?
    let scope: String?
    let target: String?
    let runtimeScope: String?
    let ready: Bool
    let businessReady: Bool
    let submitted: Bool
    let sourceCommands: [String]
    let artifacts: [String]
    let note: String?
}

func workspaceAppLifecycleEvidence(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceAppLifecycleEvidence {
    let lifecycleRequest = try workspaceAppLifecycleRequest(for: request)
    switch lifecycleRequest.mode {
    case "dry":
        return workspaceDryAppLifecycleEvidence(for: lifecycleRequest)
    case "attach":
        return workspaceAttachAppLifecycleEvidence(for: lifecycleRequest)
    default:
        throw RuntimeError("Workspace app mode \(lifecycleRequest.mode) requires the async workspace runtime.")
    }
}

func workspaceAppLifecycleEvidence(
    for request: TKWorkspaceRunRequest,
    provider: TKWorkspaceAppLifecycleProvider
) async throws -> TKWorkspaceAppLifecycleEvidence {
    let lifecycleRequest = try workspaceAppLifecycleRequest(for: request)
    switch lifecycleRequest.mode {
    case "dry":
        return workspaceDryAppLifecycleEvidence(for: lifecycleRequest)
    case "attach":
        return workspaceAttachAppLifecycleEvidence(for: lifecycleRequest)
    case "launch":
        return try await provider(lifecycleRequest)
    default:
        throw RuntimeError("Unsupported workspace app mode \(lifecycleRequest.mode); expected dry, attach, or launch.")
    }
}

func workspaceDefaultAppLifecycleProvider(
    _ request: TKWorkspaceAppLifecycleRequest
) async throws -> TKWorkspaceAppLifecycleEvidence {
    switch request.mode {
    case "dry":
        return workspaceDryAppLifecycleEvidence(for: request)
    case "attach":
        return workspaceAttachAppLifecycleEvidence(for: request)
    case "launch":
        return try workspaceLaunchAppLifecycleEvidence(for: request)
    default:
        throw RuntimeError("Unsupported workspace app mode \(request.mode); expected dry, attach, or launch.")
    }
}

func workspaceAppLifecycleArtifact(_ evidence: TKWorkspaceAppLifecycleEvidence) -> [String: Any] {
    var artifact: [String: Any] = [
        "schemaVersion": 1,
        "kind": "triton.workspace.app-lifecycle",
        "mode": evidence.mode,
        "phase": evidence.phase,
        "action": evidence.action,
        "app": evidence.app,
        "ready": evidence.ready,
        "businessReady": evidence.businessReady,
        "submitted": evidence.submitted,
        "sourceCommands": evidence.sourceCommands,
        "artifacts": evidence.artifacts,
    ]
    if let platform = evidence.platform {
        artifact["platform"] = platform
    }
    if let scope = evidence.scope {
        artifact["scope"] = scope
    }
    if let target = evidence.target {
        artifact["target"] = target
    }
    if let runtimeScope = evidence.runtimeScope {
        artifact["runtimeScope"] = runtimeScope
    }
    if let note = evidence.note {
        artifact["note"] = note
    }
    return artifact
}

private func workspaceAppLifecycleRequest(for request: TKWorkspaceRunRequest) throws -> TKWorkspaceAppLifecycleRequest {
    let mode = try workspaceNormalizedAppMode(request.appMode)
    let platform = workspaceAppLowercased(request.platform)
    let scope = workspaceAppLowercased(request.scope)
    let target = workspaceAppTarget(request.target)
    let bundleID = workspaceAppNilIfEmpty(request.bundleID) ?? (platform == "ios" ? request.app : nil)
    let packageName = workspaceAppNilIfEmpty(request.packageName) ?? (platform == "android" ? request.app : nil)
    let bundle = workspaceAppNilIfEmpty(request.bundle) ?? (platform == "harmony" ? request.app : nil)
    return TKWorkspaceAppLifecycleRequest(
        mode: mode,
        platform: platform,
        scope: scope,
        target: target,
        app: request.app,
        bundleID: bundleID,
        packageName: packageName,
        activity: workspaceAppNilIfEmpty(request.activity),
        bundle: bundle,
        ability: workspaceAppNilIfEmpty(request.ability),
        adb: request.adb,
        hdc: request.hdc
    )
}

private func workspaceDryAppLifecycleEvidence(
    for request: TKWorkspaceAppLifecycleRequest
) -> TKWorkspaceAppLifecycleEvidence {
    TKWorkspaceAppLifecycleEvidence(
        mode: "dry-skeleton",
        phase: "dry-skeleton",
        action: "app.ready",
        app: request.app,
        platform: request.platform,
        scope: request.scope,
        target: request.target,
        runtimeScope: nil,
        ready: false,
        businessReady: false,
        submitted: false,
        sourceCommands: [],
        artifacts: [],
        note: "Dry workspace run; no app lifecycle action was submitted."
    )
}

private func workspaceAttachAppLifecycleEvidence(
    for request: TKWorkspaceAppLifecycleRequest
) -> TKWorkspaceAppLifecycleEvidence {
    TKWorkspaceAppLifecycleEvidence(
        mode: "attach",
        phase: "attached",
        action: "app.attach",
        app: request.app,
        platform: request.platform,
        scope: request.scope,
        target: request.target,
        runtimeScope: workspaceRuntimeScope(platform: request.platform, scope: request.scope),
        ready: false,
        businessReady: false,
        submitted: false,
        sourceCommands: [],
        artifacts: [],
        note: "Attached to an existing app lifecycle; use observation and verification evidence before claiming business readiness."
    )
}

private func workspaceLaunchAppLifecycleEvidence(
    for request: TKWorkspaceAppLifecycleRequest
) throws -> TKWorkspaceAppLifecycleEvidence {
    let platform = try workspaceHostDevicePlatform(from: request.platform)
    let scope = try workspaceHostDeviceScope(from: request.scope)
    let selection = try resolveHostDeviceSelection(
        request: HostDeviceSelectionRequest(
            device: request.target,
            platform: platform,
            scope: scope,
            ready: true
        ),
        hdc: request.hdc,
        adb: request.adb
    )
    let plan = try planHostAppLaunch(
        selection: selection,
        bundleID: request.bundleID,
        packageName: request.packageName,
        activity: request.activity,
        bundle: request.bundle,
        ability: request.ability,
        payloadURL: nil,
        adb: request.adb,
        hdc: request.hdc,
        devicectlArtifacts: nil
    )
    let result = try runHostCommand(plan.command)
    return TKWorkspaceAppLifecycleEvidence(
        mode: "launch",
        phase: "launch_submitted",
        action: plan.action,
        app: request.app,
        platform: request.platform,
        scope: request.scope,
        target: plan.target,
        runtimeScope: plan.runtimeScope,
        ready: false,
        businessReady: false,
        submitted: true,
        sourceCommands: [workspaceAppLaunchCommand(for: request)] + [result.sourceCommand],
        artifacts: plan.artifacts,
        note: "\(plan.note) Workspace app launch only proves submission; follow with observe/wait/verify evidence."
    )
}

private func workspaceNormalizedAppMode(_ rawMode: String) throws -> String {
    let mode = rawMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch mode {
    case "", "dry", "dry-skeleton":
        return "dry"
    case "attach", "launch":
        return mode
    default:
        throw RuntimeError("Unsupported workspace app mode \(rawMode); expected dry, attach, or launch.")
    }
}

private func workspaceHostDevicePlatform(from rawPlatform: String?) throws -> HostDevicePlatform {
    guard let rawPlatform,
          let platform = HostDevicePlatform(rawValue: rawPlatform)
    else {
        throw RuntimeError("Workspace app launch requires --platform ios, android, or harmony.")
    }
    return platform
}

private func workspaceHostDeviceScope(from rawScope: String?) throws -> HostDeviceScope? {
    guard let rawScope else { return nil }
    if rawScope == "current" {
        return nil
    }
    guard let scope = HostDeviceScope(rawValue: rawScope) else {
        throw RuntimeError("Unsupported workspace app scope \(rawScope); expected simulator, emulator, real, or all.")
    }
    return scope
}

private func workspaceRuntimeScope(platform: String?, scope: String?) -> String? {
    guard let platform else { return nil }
    if platform == "ios", scope == "real" {
        return "host-ios-real-device"
    }
    switch platform {
    case "ios":
        return "host-simulator"
    case "android":
        return "host-android"
    case "harmony":
        return "host-harmony"
    default:
        return nil
    }
}

private func workspaceAppLaunchCommand(for request: TKWorkspaceAppLifecycleRequest) -> String {
    var parts = ["triton", "app", "launch"]
    if let platform = request.platform {
        parts += ["--platform", platform]
    }
    parts += ["--device", request.target]
    if let scope = request.scope {
        parts += ["--scope", scope]
    }
    if let bundleID = request.bundleID {
        parts += ["--bundle-id", bundleID]
    }
    if let packageName = request.packageName {
        parts += ["--package-name", packageName]
    }
    if let activity = request.activity {
        parts += ["--activity", activity]
    }
    if let bundle = request.bundle {
        parts += ["--bundle", bundle]
    }
    if let ability = request.ability {
        parts += ["--ability", ability]
    }
    parts.append("--json")
    return parts.joined(separator: " ")
}

private func workspaceAppTarget(_ rawTarget: String) -> String {
    let value = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "current" : value
}

private func workspaceAppLowercased(_ value: String?) -> String? {
    workspaceAppNilIfEmpty(value)?.lowercased()
}

private func workspaceAppNilIfEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty
    else {
        return nil
    }
    return trimmed
}
