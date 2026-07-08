import Foundation

typealias TKWorkspaceTargetResolverProvider = (TKWorkspaceTargetResolveRequest) throws -> TKWorkspaceTargetResolution?

struct TKWorkspaceTargetResolveRequest: Equatable {
    let enabled: Bool
    let selector: String
    let platform: String?
    let scope: String?
    let hdc: String
    let adb: String
}

struct TKWorkspaceTargetResolution: Equatable {
    let selection: HostDeviceSelectionResult
    let sourceCommands: [String]
}

func workspaceTargetResolveRequest(for request: TKWorkspaceRunRequest) -> TKWorkspaceTargetResolveRequest {
    TKWorkspaceTargetResolveRequest(
        enabled: request.resolveTarget,
        selector: request.target,
        platform: request.platform,
        scope: request.scope,
        hdc: request.hdc,
        adb: request.adb
    )
}

func workspaceDefaultTargetResolverProvider(
    _ request: TKWorkspaceTargetResolveRequest
) throws -> TKWorkspaceTargetResolution? {
    guard request.enabled else { return nil }
    let platform = try workspaceHostDevicePlatform(from: request.platform)
    let scope = try workspaceHostDeviceScope(from: request.scope)
    let selection = try resolveHostDeviceSelection(
        request: HostDeviceSelectionRequest(
            device: request.selector,
            platform: platform,
            scope: scope
        ),
        hdc: request.hdc,
        adb: request.adb
    )
    return TKWorkspaceTargetResolution(
        selection: selection,
        sourceCommands: workspaceTargetResolveSourceCommands(for: request)
    )
}

func workspaceRunRequest(
    _ request: TKWorkspaceRunRequest,
    applying resolution: TKWorkspaceTargetResolution?
) -> TKWorkspaceRunRequest {
    guard let resolution else { return request }
    return request.resolvingTarget(
        target: resolution.selection.target.target,
        platform: resolution.selection.platform.rawValue,
        scope: resolution.selection.target.scope ?? request.scope
    )
}

func workspaceRuntimeTarget(for request: TKWorkspaceRunRequest) -> String {
    workspaceRuntimeTarget(
        request.target,
        platform: request.platform,
        scope: request.scope,
        appID: workspaceNonEmpty(request.bundleID) ?? workspaceNonEmpty(request.app)
    )
}

func workspaceRuntimeTarget(
    _ rawTarget: String,
    platform: String?,
    scope: String?,
    appID: String? = nil
) -> String {
    let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    guard workspaceNonEmpty(platform)?.lowercased() == "ios",
          workspaceNonEmpty(scope)?.lowercased() == "simulator",
          !target.isEmpty
    else {
        return rawTarget
    }
    if target == "current" || target == "booted" {
        return target
    }
    if target.hasPrefix("triton:") {
        return workspaceRuntimeAppTarget(target, appID: appID)
    }
    if target.hasPrefix("sim:") {
        return workspaceRuntimeAppTarget(
            "triton:ios-simulator:\(String(target.dropFirst(4)))",
            appID: appID
        )
    }
    if target.hasPrefix("host:ios:") {
        return workspaceRuntimeAppTarget(
            "triton:ios-simulator:\(String(target.dropFirst("host:ios:".count)))",
            appID: appID
        )
    }
    return workspaceRuntimeAppTarget("triton:ios-simulator:\(target)", appID: appID)
}

private func workspaceRuntimeAppTarget(_ target: String, appID: String?) -> String {
    guard !target.contains("/app:"),
          let appID = workspaceNonEmpty(appID)
    else {
        return target
    }
    return "\(target)/app:\(appID)"
}

extension TKWorkspaceRunRequest {
    func resolvingTarget(target: String, platform: String?, scope: String?) -> TKWorkspaceRunRequest {
        TKWorkspaceRunRequest(
            runsDirectory: runsDirectory,
            runID: runID,
            target: target,
            platform: platform,
            scope: scope,
            app: app,
            goal: goal,
            actionPolicy: actionPolicy,
            appMode: appMode,
            bundleID: bundleID,
            packageName: packageName,
            activity: activity,
            bundle: bundle,
            ability: ability,
            adb: adb,
            dryModelFixture: dryModelFixture,
            llmProvider: llmProvider,
            llmBaseURL: llmBaseURL,
            llmModel: llmModel,
            llmAPIKeyEnv: llmAPIKeyEnv,
            allowRemoteLLM: allowRemoteLLM,
            vlmProvider: vlmProvider,
            vlmBaseURL: vlmBaseURL,
            vlmModel: vlmModel,
            vlmModelPath: vlmModelPath,
            vlmHelper: vlmHelper,
            vlmAllowModelDownload: vlmAllowModelDownload,
            vlmAPIKeyEnv: vlmAPIKeyEnv,
            allowRemoteVLM: allowRemoteVLM,
            maxSteps: maxSteps,
            allowedActions: allowedActions,
            stopConditions: stopConditions,
            observationFixture: observationFixture,
            observeLive: observeLive,
            observeKind: observeKind,
            observeMaxNodes: observeMaxNodes,
            observeOutput: observeOutput,
            observeRuntimeBaseURL: observeRuntimeBaseURL,
            observeHost: observeHost,
            observePort: observePort,
            hdc: hdc,
            businessReadyText: businessReadyText,
            businessReadyLiveWait: businessReadyLiveWait,
            businessReadyAssert: businessReadyAssert,
            businessReadyTimeout: businessReadyTimeout,
            businessReadyInterval: businessReadyInterval,
            resolveTarget: resolveTarget,
            executeActions: executeActions
        )
    }
}

func workspaceRunTarget(
    for request: TKWorkspaceRunRequest,
    targetResolution: TKWorkspaceTargetResolution?
) -> TKWorkspaceRunTarget {
    let targetMetadata = workspaceTargetMetadata(platform: request.platform, scope: request.scope)
    guard let targetResolution else {
        return TKWorkspaceRunTarget(
            id: request.target,
            platform: targetMetadata.platform,
            scope: targetMetadata.scope,
            capabilities: workspaceTargetCapabilities(for: request)
        )
    }
    let hostTarget = targetResolution.selection.target
    return TKWorkspaceRunTarget(
        id: hostTarget.id,
        platform: targetResolution.selection.platform.rawValue,
        scope: hostTarget.scope ?? targetMetadata.scope,
        capabilities: workspaceTargetCapabilities(for: request),
        resolved: true,
        selector: targetResolution.selection.selector,
        hostTarget: hostTarget.target,
        source: hostTarget.source,
        state: hostTarget.state,
        ready: hostTarget.ready,
        name: hostTarget.name,
        runtime: hostTarget.runtime,
        kind: hostTarget.kind,
        sourceCommands: targetResolution.sourceCommands
    )
}

func workspaceTargetArtifact(for target: TKWorkspaceRunTarget) -> [String: Any] {
    var artifact: [String: Any] = [
        "target": target.id,
        "platform": target.platform,
        "scope": target.scope,
        "capabilities": target.capabilities,
    ]
    if let resolved = target.resolved {
        artifact["resolved"] = resolved
    }
    if let selector = workspaceNonEmpty(target.selector) {
        artifact["selector"] = selector
    }
    if let hostTarget = workspaceNonEmpty(target.hostTarget) {
        artifact["hostTarget"] = hostTarget
    }
    if let source = workspaceNonEmpty(target.source) {
        artifact["source"] = source
    }
    if let state = workspaceNonEmpty(target.state) {
        artifact["state"] = state
    }
    if let ready = target.ready {
        artifact["ready"] = ready
    }
    if let name = workspaceNonEmpty(target.name) {
        artifact["name"] = name
    }
    if let runtime = workspaceNonEmpty(target.runtime) {
        artifact["runtime"] = runtime
    }
    if let kind = workspaceNonEmpty(target.kind) {
        artifact["kind"] = kind
    }
    if let sourceCommands = target.sourceCommands, !sourceCommands.isEmpty {
        artifact["sourceCommands"] = sourceCommands
    }
    return artifact
}

func workspaceTargetResolveSourceCommands(for request: TKWorkspaceTargetResolveRequest) -> [String] {
    var argv = ["triton", "target", "resolve", request.selector]
    if let platform = workspaceNonEmpty(request.platform) {
        argv.append(contentsOf: ["--platform", platform])
    }
    if let scope = workspaceNonEmpty(request.scope) {
        argv.append(contentsOf: ["--scope", scope])
    }
    if request.hdc != "hdc" {
        argv.append(contentsOf: ["--hdc", request.hdc])
    }
    if request.adb != "adb" {
        argv.append(contentsOf: ["--adb", request.adb])
    }
    argv.append("--json")
    return [argv.map(shellEscaped).joined(separator: " ")]
}

private func workspaceHostDevicePlatform(from raw: String?) throws -> HostDevicePlatform? {
    guard let raw = workspaceNonEmpty(raw) else { return nil }
    guard let platform = HostDevicePlatform(rawValue: raw) else {
        throw RuntimeError("Invalid workspace target platform: \(raw). Expected ios, android, or harmony.")
    }
    return platform
}

private func workspaceHostDeviceScope(from raw: String?) throws -> HostDeviceScope? {
    guard let raw = workspaceNonEmpty(raw) else { return nil }
    guard let scope = HostDeviceScope(rawValue: raw) else {
        throw RuntimeError("Invalid workspace target scope: \(raw). Expected simulator, emulator, real, or all.")
    }
    return scope
}

private func workspaceTargetCapabilities(for request: TKWorkspaceRunRequest) -> [String] {
    let metadata = workspaceTargetMetadata(platform: request.platform, scope: request.scope)
    switch metadata.platform {
    case "ios", "android", "harmony":
        return ["screenshot", "hierarchy", "input"]
    default:
        return ["screenshot", "hierarchy", "input"]
    }
}
