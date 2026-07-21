import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared


func resolveTarget(_ target: String, host: String, port: Int) async throws -> TKTargetSummary {
    let client = TritonKitHTTPClient(host: host, port: port)
    let response: TKTargetsResponse = try await client.getJSON("/targets")
    return try TKResolveTargetSummary(target, in: response.targets)
}

func resolveTarget(
    _ target: String,
    host: String,
    port: Int,
    jsonError: Bool
) async throws -> TKTargetSummary {
    do {
        return try await resolveTarget(target, host: host, port: port)
    } catch {
        if jsonError {
            try printCLIError(error, endpoint: "/targets", host: host, port: port)
            throw ExitCode.failure
        }
        printCLIErrorText(error, endpoint: "/targets", host: host, port: port, language: effectiveLanguage(nil))
        throw ExitCode.failure
    }
}

func resolveRuntimeClient(
    target: String,
    host: String,
    port: Int,
    jsonError: Bool
) async throws -> (summary: TKTargetSummary, client: TritonKitHTTPClient) {
    let summary = try await resolveTarget(target, host: host, port: port, jsonError: jsonError)
    return (summary, TritonKitHTTPClient(host: host, port: port, target: summary.id))
}

func buildCapabilities(host: String, port: Int) async -> TKCapabilitiesResponse {
    let client = TritonKitHTTPClient(host: host, port: port)
    do {
        let status: TKStatusResponse = try await client.getJSON("/status")
        return TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: status.connected,
            latestHierarchyAvailable: status.latestHierarchyAvailable,
            targetCount: status.targetCount,
            runtime: status.connected ? "embedded" : "none",
            capabilities: runtimeCapabilities(host: host, port: port, serverReachable: true, connected: status.connected),
            activeHierarchyAvailable: status.activeHierarchyAvailable,
            hierarchyCacheState: status.hierarchyCacheState,
            targetConnectionState: status.targetConnectionState
        )
    } catch {
        let detail = cliErrorDetail(for: error, endpoint: "/status", host: host, port: port)
        return TKCapabilitiesResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "unknown",
            capabilities: runtimeCapabilities(host: host, port: port, serverReachable: false, connected: false),
            error: detail
        )
    }
}

func runtimeCapabilities(host: String, port: Int, serverReachable: Bool, connected: Bool) -> [TKRuntimeCapability] {
    let requiresRuntime = connected ? nil : "Requires connected embedded TritonKit runtime"
    let requiresWebViewProvider = connected ? nil : "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
    let capabilities: [TKRuntimeCapability] = [
        TKRuntimeCapability(name: "version", supported: true),
        TKRuntimeCapability(name: "cli-update", supported: true),
        TKRuntimeCapability(name: "plan", supported: true),
        TKRuntimeCapability(name: "plan-inspect", supported: true),
        TKRuntimeCapability(name: "record", supported: true),
        TKRuntimeCapability(name: "replay-dry-run", supported: true),
        TKRuntimeCapability(name: "web-device-hub", supported: true),
        TKRuntimeCapability(name: "schema", supported: true),
        TKRuntimeCapability(name: "test-validate", supported: true),
        TKRuntimeCapability(name: "test-normalized-plan", supported: true),
        TKRuntimeCapability(name: "test-run-minimal", supported: true),
        TKRuntimeCapability(name: "test-run-deterministic", supported: true),
        TKRuntimeCapability(name: "test-run-vlm-assisted", supported: true),
        TKRuntimeCapability(name: "test-run-ai-mock", supported: true),
        TKRuntimeCapability(name: "test-report", supported: true),
        TKRuntimeCapability(name: "test-create-from-session", supported: true),
        TKRuntimeCapability(name: "testrec-session-start", supported: true),
        TKRuntimeCapability(name: "testrec-event-ingest", supported: true),
        TKRuntimeCapability(name: "testrec-session-stop", supported: true),
        TKRuntimeCapability(name: "testrec-inspect", supported: true),
        TKRuntimeCapability(name: "testrec-compile", supported: true),
        TKRuntimeCapability(name: "testrec-proposals-inspect", supported: true),
        TKRuntimeCapability(name: "testrec-page-match", supported: true),
        TKRuntimeCapability(name: "testrec-replay-dry-run", supported: true),
        TKRuntimeCapability(name: "testrec-replay-local-simulated", supported: true),
        TKRuntimeCapability(name: "testrec-matrix", supported: true),
        TKRuntimeCapability(name: "action-provider-parse", supported: true),
        TKRuntimeCapability(name: "status", supported: true),
        TKRuntimeCapability(name: "doctor", supported: true),
        TKRuntimeCapability(name: "capabilities", supported: true),
        TKRuntimeCapability(name: "target-list", supported: true),
        TKRuntimeCapability(name: "target-use", supported: true),
        TKRuntimeCapability(name: "target-current", supported: true),
        TKRuntimeCapability(name: "target-resolve", supported: true),
        TKRuntimeCapability(name: "target-wait-ready", supported: true),
        TKRuntimeCapability(name: "runtime-manifest", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-app", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-scene", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-route", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "state-responder", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "snapshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "app-semantic-state", supported: true),
        TKRuntimeCapability(name: "app-semantic-action", supported: true),
        TKRuntimeCapability(name: "media-playback", supported: true),
        TKRuntimeCapability(name: "focus", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "set-text", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "select-segment", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "set-switch", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "semantic-action", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ledger", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "host-device", supported: true),
        TKRuntimeCapability(name: "host-device-selector", supported: true),
        TKRuntimeCapability(name: "device-alias", supported: true),
        TKRuntimeCapability(name: "device-list", supported: true),
        TKRuntimeCapability(name: "device-use", supported: true),
        TKRuntimeCapability(name: "device-current", supported: true),
        TKRuntimeCapability(name: "device-resolve", supported: true),
        TKRuntimeCapability(name: "device-wait-ready", supported: true),
        TKRuntimeCapability(name: "device-screenshot", supported: true),
        TKRuntimeCapability(name: "host-device-screenshot", supported: true),
        TKRuntimeCapability(name: "ios-device", supported: true),
        TKRuntimeCapability(name: "ios-device-list", supported: true),
        TKRuntimeCapability(name: "ios-device-use", supported: true),
        TKRuntimeCapability(name: "ios-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "ios-device-screenshot", supported: true),
        TKRuntimeCapability(name: "ios-screenshot", supported: true),
        TKRuntimeCapability(name: "ios-simulator-screenshot", supported: true),
        TKRuntimeCapability(
            name: "ios-real-device-screenshot",
            supported: false,
            reason: "iOS real-device screenshot is not supported by the current host adapter",
            group: "host",
            requiredBy: ["target", "app", "smoke", "evidence"],
            nextAction: TKCLINextAction(command: "schema", args: ["--command", "screenshot", "--json"]),
            evidence: ["unsupported-envelope", "command-schema"]
        ),
        TKRuntimeCapability(name: "ios-host-ax", supported: true),
        TKRuntimeCapability(name: "ios-host-hid", supported: true),
        TKRuntimeCapability(name: "ios-simulator-host-tap", supported: true),
        TKRuntimeCapability(name: "ios-simulator-host-type", supported: true),
        TKRuntimeCapability(name: "android-device", supported: true),
        TKRuntimeCapability(name: "android-device-doctor", supported: true),
        TKRuntimeCapability(name: "android-device-list", supported: true),
        TKRuntimeCapability(name: "android-device-start", supported: true),
        TKRuntimeCapability(name: "android-device-stop", supported: true),
        TKRuntimeCapability(name: "android-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "android-device-screenshot", supported: true),
        TKRuntimeCapability(name: "android-bridge", supported: true),
        TKRuntimeCapability(name: "android-bridge-install", supported: true),
        TKRuntimeCapability(name: "android-bridge-forward", supported: true),
        TKRuntimeCapability(name: "android-ax", supported: true),
        TKRuntimeCapability(name: "android-hierarchy", supported: true),
        TKRuntimeCapability(name: "device-proxy-ios", supported: true),
        TKRuntimeCapability(name: "device-proxy-android", supported: true),
        TKRuntimeCapability(name: "device-proxy-harmony", supported: true),
        TKRuntimeCapability(name: "network-capture-export", supported: true),
        TKRuntimeCapability(name: "network-certificate-plan", supported: true),
        TKRuntimeCapability(name: "network-certificate-install", supported: true),
        TKRuntimeCapability(name: "harmony-device", supported: true),
        TKRuntimeCapability(name: "harmony-device-doctor", supported: true),
        TKRuntimeCapability(name: "harmony-device-list", supported: true),
        TKRuntimeCapability(name: "harmony-foreground-app-identity", supported: true),
        TKRuntimeCapability(name: "harmony-device-use", supported: true),
        TKRuntimeCapability(name: "harmony-device-start", supported: true),
        TKRuntimeCapability(name: "harmony-device-wait-ready", supported: true),
        TKRuntimeCapability(name: "harmony-device-screenshot", supported: true),
        TKRuntimeCapability(name: "harmony-device-stop", supported: true),
        TKRuntimeCapability(name: "harmony-runtime-url", supported: true),
        TKRuntimeCapability(name: "harmony-app-install", supported: true),
        TKRuntimeCapability(name: "harmony-app-open-url", supported: true),
        TKRuntimeCapability(name: "harmony-app-info", supported: true),
        TKRuntimeCapability(name: "harmony-ax", supported: true),
        TKRuntimeCapability(name: "harmony-hierarchy", supported: true),
        TKRuntimeCapability(name: "harmony-wait-text", supported: true),
        TKRuntimeCapability(name: "harmony-tap-text", supported: true),
        TKRuntimeCapability(name: "harmony-swipe", supported: true),
        TKRuntimeCapability(name: "harmony-type-text", supported: true),
        TKRuntimeCapability(name: "harmony-paste-text", supported: true),
        TKRuntimeCapability(name: "harmony-clear-text", supported: false, reason: "Host-side Harmony clear is not available in the current adapter"),
        TKRuntimeCapability(name: "harmony-press-key", supported: true),
        TKRuntimeCapability(name: "harmony-screenshot", supported: true),
        TKRuntimeCapability(name: "host-simulator", supported: true),
        TKRuntimeCapability(name: "sim-video", supported: true),
        TKRuntimeCapability(name: "sim-logs", supported: true),
        TKRuntimeCapability(name: "sim-app-process-console", supported: true),
        TKRuntimeCapability(name: "sim-diagnostics", supported: true),
        TKRuntimeCapability(name: "sim-runtime", supported: true),
        TKRuntimeCapability(name: "sim-runtime-maintenance", supported: true),
        TKRuntimeCapability(name: "sim-device-maintenance", supported: true),
        TKRuntimeCapability(name: "sim-personalization", supported: true),
        TKRuntimeCapability(name: "sim-status-bar", supported: true),
        TKRuntimeCapability(name: "sim-privacy", supported: true),
        TKRuntimeCapability(name: "sim-location", supported: true),
        TKRuntimeCapability(name: "sim-ui", supported: true),
        TKRuntimeCapability(name: "sim-pasteboard", supported: true),
        TKRuntimeCapability(name: "sim-push", supported: true),
        TKRuntimeCapability(name: "host-app", supported: true),
        TKRuntimeCapability(name: "ios-real-app", supported: true),
        TKRuntimeCapability(name: "ios-real-app-pull", supported: true),
        TKRuntimeCapability(name: "host-app-open-url-ready", supported: true),
        TKRuntimeCapability(name: "host-app-open-url-snapshot", supported: true),
        TKRuntimeCapability(name: "host-preferences", supported: true),
        TKRuntimeCapability(name: "android-app", supported: true),
        TKRuntimeCapability(name: "android-app-inspect", supported: true),
        TKRuntimeCapability(name: "android-app-install", supported: true),
        TKRuntimeCapability(name: "android-app-launch", supported: true),
        TKRuntimeCapability(name: "android-app-terminate", supported: true),
        TKRuntimeCapability(name: "android-app-open-url", supported: true),
        TKRuntimeCapability(name: "harmony-app", supported: true),
        TKRuntimeCapability(name: "xcode-discovery", supported: true),
        TKRuntimeCapability(name: "xcode-defaults", supported: true),
        TKRuntimeCapability(name: "xcode-package-build", supported: true),
        TKRuntimeCapability(name: "xcode-diagnostics", supported: true),
        TKRuntimeCapability(name: "xcodebuild", supported: true),
        TKRuntimeCapability(name: "xcode-build", supported: true),
        TKRuntimeCapability(name: "xcode-test", supported: true),
        TKRuntimeCapability(name: "xcode-run", supported: true),
        TKRuntimeCapability(name: "xcresult-summary", supported: true),
        TKRuntimeCapability(name: "xcresult-failures", supported: true),
        TKRuntimeCapability(name: "xctrace-record", supported: true),
        TKRuntimeCapability(name: "coverage-report", supported: true),
        TKRuntimeCapability(name: "observe", supported: true),
        TKRuntimeCapability(name: "observe-ios", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "observe-ios-host-ax", supported: true),
        TKRuntimeCapability(name: "ios-simulator-host-wait", supported: true),
        TKRuntimeCapability(name: "observe-android", supported: true),
        TKRuntimeCapability(name: "observe-harmony", supported: true),
        TKRuntimeCapability(name: "observe-outline", supported: true),
        TKRuntimeCapability(name: "android-wait-text", supported: true),
        TKRuntimeCapability(name: "android-tap-text", supported: true),
        TKRuntimeCapability(name: "android-swipe", supported: true),
        TKRuntimeCapability(name: "android-type-text", supported: true),
        TKRuntimeCapability(name: "android-paste-text", supported: true),
        TKRuntimeCapability(name: "android-press-key", supported: true),
        TKRuntimeCapability(name: "webview-list", supported: true),
        TKRuntimeCapability(name: "webview-current", supported: true),
        TKRuntimeCapability(name: "webview-current-url", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-snapshot", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-bridge-call", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-events", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-wait", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "webview-aware-tap", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "route-current-url-assert", supported: connected, reason: requiresWebViewProvider),
        TKRuntimeCapability(name: "node-resolve", supported: true),
        TKRuntimeCapability(name: "node-alias-resolve", supported: true),
        TKRuntimeCapability(name: "list", supported: true),
        TKRuntimeCapability(name: "inspect", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hierarchy", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hierarchy-scene", supported: true),
        TKRuntimeCapability(name: "nodes", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "node", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "attrs", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "object", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-json", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "export-archive", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "geometry", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "ax", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "hit", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "screenshot", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "wait", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "capture", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "assert", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "verify", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "verify-text-exists", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "verify-text-not-exists", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "replay", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "evidence", supported: true),
        TKRuntimeCapability(name: "evidence-summary", supported: true),
        TKRuntimeCapability(name: "evidence-redact", supported: true),
        TKRuntimeCapability(name: "evidence-project-workspace", supported: true),
        TKRuntimeCapability(name: "evidence-project-screens", supported: true),
        TKRuntimeCapability(name: "evidence-ingest", supported: true),
        TKRuntimeCapability(name: "sim-media-seed", supported: true),
        TKRuntimeCapability(name: "app-map-merge", supported: true),
        TKRuntimeCapability(name: "app-map-inspect", supported: true),
        TKRuntimeCapability(name: "app-map-paths", supported: true),
        TKRuntimeCapability(name: "app-map-screens", supported: true),
        TKRuntimeCapability(name: "app-map-transitions", supported: true),
        TKRuntimeCapability(name: "app-map-path-show", supported: true),
        TKRuntimeCapability(name: "app-map-path-confirm", supported: true),
        TKRuntimeCapability(name: "app-map-health", supported: true),
        TKRuntimeCapability(name: "app-map-suite-inspect", supported: true),
        TKRuntimeCapability(name: "app-map-suite-edit", supported: true),
        TKRuntimeCapability(name: "app-map-suite-run", supported: true),
        TKRuntimeCapability(name: "app-map-export-flow", supported: true),
        TKRuntimeCapability(name: "app-map-viewer", supported: true),
        TKRuntimeCapability(name: "app-map-vlm-health", supported: true),
        TKRuntimeCapability(name: "vlm-provider-list", supported: true),
        TKRuntimeCapability(name: "vlm-ground-mock", supported: true),
        TKRuntimeCapability(name: "vlm-ground-openai-compatible", supported: true),
        TKRuntimeCapability(name: "vlm-ground-mlx-swift-lm", supported: true),
        TKRuntimeCapability(name: "vlm-provider-compare", supported: true),
        TKRuntimeCapability(name: "vlm-model-cache", supported: true),
        TKRuntimeCapability(name: "vlm-model-download", supported: true),
        TKRuntimeCapability(name: "smoke-ios", supported: true),
        TKRuntimeCapability(name: "smoke-android", supported: true),
        TKRuntimeCapability(name: "smoke-harmony", supported: true),
        TKRuntimeCapability(name: "act", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "tap", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "swipe", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "type", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "paste", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "clear", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "input", supported: connected, reason: requiresRuntime),
        TKRuntimeCapability(name: "press", supported: false, reason: "Host-side HID is not available in the embedded runtime"),
    ]
    return capabilities.map { capability in
        enrichRuntimeCapability(capability, host: host, port: port, serverReachable: serverReachable, connected: connected)
    }
}

func enrichRuntimeCapability(
    _ capability: TKRuntimeCapability,
    host: String,
    port: Int,
    serverReachable: Bool,
    connected: Bool
) -> TKRuntimeCapability {
    TKRuntimeCapability(
        name: capability.name,
        supported: capability.supported,
        reason: capability.reason,
        group: capability.group ?? runtimeCapabilityGroup(for: capability.name),
        requiredBy: capability.requiredBy.isEmpty ? runtimeCapabilityRequiredBy(for: capability.name) : capability.requiredBy,
        nextAction: capability.nextAction ?? runtimeCapabilityNextAction(for: capability.name, host: host, port: port, serverReachable: serverReachable, connected: connected),
        evidence: capability.evidence.isEmpty ? runtimeCapabilityEvidence(for: capability.name) : capability.evidence
    )
}

func runtimeCapabilityGroup(for name: String) -> String {
    switch name {
    case "version", "cli-update", "plan", "record", "replay-dry-run", "web-device-hub", "schema", "status", "doctor", "capabilities":
        return "bootstrap"
    case "test-validate", "test-normalized-plan", "test-run-minimal", "test-run-deterministic", "test-run-vlm-assisted", "test-run-ai-mock", "test-report", "test-create-from-session", "testrec-session-start", "testrec-event-ingest", "testrec-session-stop", "testrec-inspect", "testrec-compile", "testrec-proposals-inspect", "testrec-page-match", "testrec-replay-dry-run", "testrec-replay-local-simulated", "testrec-matrix":
        return "test"
    case "target-list", "target-use", "target-current", "target-resolve", "target-wait-ready":
        return "target"
    case "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "app-semantic-state", "app-semantic-action", "media-playback", "focus", "set-text", "select-segment", "set-switch", "semantic-action", "ledger":
        return "runtime"
    case "xcode-discovery", "xcode-defaults", "xcode-package-build", "xcode-diagnostics", "xcodebuild", "xcode-build", "xcode-test", "xcode-run", "xcresult-summary", "xcresult-failures", "xctrace-record", "coverage-report":
        return "xcode"
    case "host-device", "host-device-selector", "device-alias", "device-list", "device-use", "device-current", "device-resolve", "device-wait-ready", "device-screenshot", "host-device-screenshot", "ios-device", "ios-device-list", "ios-device-use", "ios-device-wait-ready", "ios-device-screenshot", "ios-screenshot", "ios-simulator-screenshot", "ios-host-ax", "ios-host-hid", "ios-simulator-host-type", "android-device", "android-device-doctor", "android-device-list", "android-device-start", "android-device-stop", "android-device-wait-ready", "android-device-screenshot", "android-bridge", "android-bridge-install", "android-bridge-forward", "android-ax", "device-proxy-ios", "device-proxy-android", "device-proxy-harmony", "network-certificate-plan", "network-certificate-install", "harmony-device", "harmony-device-doctor", "harmony-device-list", "harmony-device-start", "harmony-foreground-app-identity", "harmony-device-use", "harmony-device-wait-ready", "harmony-device-screenshot", "harmony-device-stop", "harmony-runtime-url", "harmony-app-install", "harmony-app-open-url", "harmony-ax", "harmony-screenshot", "host-simulator", "sim-video", "sim-logs", "sim-app-process-console", "sim-diagnostics", "sim-runtime", "sim-runtime-maintenance", "sim-device-maintenance", "sim-personalization", "sim-status-bar", "sim-privacy", "sim-location", "sim-ui", "sim-pasteboard", "sim-push", "sim-media-seed", "host-app", "ios-real-app", "ios-real-app-pull", "host-app-open-url-ready", "host-app-open-url-snapshot", "host-preferences", "android-app", "android-app-inspect", "android-app-install", "android-app-launch", "android-app-terminate", "android-app-open-url", "harmony-app", "harmony-app-info":
        return "host"
    case "observe", "observe-ios", "observe-ios-host-ax", "observe-android", "observe-harmony", "observe-outline", "node-resolve", "node-alias-resolve", "list", "inspect", "hierarchy", "hierarchy-scene", "android-hierarchy", "harmony-hierarchy", "nodes", "node", "attrs", "object", "export-json", "export-archive", "geometry", "ax", "hit", "screenshot", "wait":
        return "observe"
    case "webview-list", "webview-current", "webview-current-url", "webview-snapshot", "webview-bridge-call", "webview-events", "webview-wait":
        return "webview"
    case "route-current-url-assert":
        return "route"
    case "capture", "evidence", "evidence-summary", "evidence-redact", "evidence-project-workspace", "evidence-project-screens", "evidence-ingest", "app-map-merge", "app-map-inspect", "app-map-paths", "app-map-screens", "app-map-transitions", "app-map-path-show", "app-map-path-confirm", "app-map-health", "app-map-vlm-health", "app-map-suite-inspect", "app-map-suite-edit", "app-map-suite-run", "app-map-export-flow", "app-map-viewer", "vlm-provider-list", "vlm-ground-mock", "vlm-ground-openai-compatible", "vlm-ground-mlx-swift-lm", "vlm-provider-compare", "vlm-model-cache", "vlm-model-download", "network-capture-export":
        return "evidence"
    case "smoke-ios", "smoke-android", "smoke-harmony":
        return "smoke"
    case "assert", "verify", "verify-text-exists", "verify-text-not-exists":
        return "assert"
    case "plan-inspect", "replay":
        return "replay"
    case "act", "action-provider-parse", "tap", "webview-aware-tap", "swipe", "type", "paste", "clear", "input", "press", "ios-simulator-host-tap", "ios-simulator-host-wait", "android-tap-text", "android-wait-text", "android-swipe", "android-type-text", "android-paste-text", "android-press-key", "harmony-tap-text", "harmony-wait-text", "harmony-swipe", "harmony-type-text", "harmony-paste-text", "harmony-press-key", "harmony-clear-text":
        return "action"
    default:
        return "misc"
    }
}

func runtimeCapabilityRequiredBy(for name: String) -> [String] {
    switch name {
    case "web-device-hub":
        return ["observe", "evidence"]
    case "cli-update":
        return ["runtime"]
    case "test-validate", "test-normalized-plan", "test-run-minimal", "test-run-deterministic", "test-run-vlm-assisted", "test-run-ai-mock", "test-report", "test-create-from-session", "testrec-session-start", "testrec-event-ingest", "testrec-session-stop", "testrec-inspect", "testrec-compile", "testrec-proposals-inspect", "testrec-page-match", "testrec-replay-dry-run", "testrec-replay-local-simulated", "testrec-matrix":
        return ["test"]
    case "target-list", "target-use", "target-current", "target-resolve", "target-wait-ready":
        return ["app", "runtime", "observe", "action", "assert", "evidence", "smoke"]
    case "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "app-semantic-state", "app-semantic-action", "media-playback", "focus", "set-text", "select-segment", "set-switch", "semantic-action", "ledger":
        return ["app", "observe", "action", "assert", "evidence"]
    case "xcode-discovery", "xcode-defaults", "xcode-package-build", "xcode-diagnostics", "xcodebuild", "xcode-build", "xcode-test", "xcode-run", "xcresult-summary", "xcresult-failures", "xctrace-record", "coverage-report":
        return ["project", "xcode", "evidence"]
    case "host-device", "host-device-selector", "device-alias", "device-list", "device-use", "device-current", "device-resolve", "device-wait-ready", "device-screenshot", "host-device-screenshot", "ios-device", "ios-device-list", "ios-device-use", "ios-device-wait-ready", "ios-device-screenshot", "ios-screenshot", "ios-simulator-screenshot", "ios-host-ax", "ios-host-hid", "ios-simulator-host-type", "android-device", "android-device-doctor", "android-device-list", "android-device-start", "android-device-stop", "android-device-wait-ready", "android-device-screenshot", "android-bridge", "android-bridge-install", "android-bridge-forward", "android-ax", "device-proxy-ios", "device-proxy-android", "device-proxy-harmony", "network-certificate-plan", "network-certificate-install", "harmony-device", "harmony-device-doctor", "harmony-device-list", "harmony-device-start", "harmony-foreground-app-identity", "harmony-device-use", "harmony-device-wait-ready", "harmony-device-screenshot", "harmony-device-stop", "harmony-runtime-url", "harmony-app-install", "harmony-app-open-url", "harmony-ax", "harmony-screenshot", "host-simulator", "sim-video", "sim-logs", "sim-app-process-console", "sim-diagnostics", "sim-runtime", "sim-runtime-maintenance", "sim-device-maintenance", "sim-personalization", "sim-status-bar", "sim-privacy", "sim-location", "sim-ui", "sim-pasteboard", "sim-push", "sim-media-seed", "host-app", "ios-real-app", "ios-real-app-pull", "host-app-open-url-ready", "host-app-open-url-snapshot", "host-preferences", "android-app", "android-app-inspect", "android-app-install", "android-app-launch", "android-app-terminate", "android-app-open-url", "harmony-app", "harmony-app-info":
        return ["target", "app", "smoke", "evidence"]
    case "observe", "observe-ios", "observe-ios-host-ax", "observe-android", "observe-harmony", "observe-outline", "node-resolve", "node-alias-resolve", "list", "inspect", "hierarchy", "hierarchy-scene", "android-hierarchy", "harmony-hierarchy", "nodes", "node", "attrs", "object", "export-json", "export-archive", "geometry", "ax", "hit", "screenshot", "wait":
        return ["action", "assert", "evidence"]
    case "webview-list", "webview-current":
        return ["observe", "route", "assert", "evidence"]
    case "webview-current-url", "webview-snapshot", "webview-bridge-call", "webview-events", "webview-wait":
        return ["route", "assert", "evidence", "webview-check"]
    case "webview-aware-tap":
        return ["action", "assert", "evidence"]
    case "route-current-url-assert":
        return ["assert", "smoke", "evidence", "webview-check"]
    case "verify", "verify-text-exists", "verify-text-not-exists":
        return ["assert", "evidence"]
    case "capture", "evidence", "evidence-summary", "evidence-redact", "evidence-project-workspace", "evidence-project-screens", "evidence-ingest", "network-capture-export":
        return ["evidence", "replay"]
    case "app-map-merge", "app-map-inspect", "app-map-paths", "app-map-screens", "app-map-transitions", "app-map-path-show", "app-map-path-confirm", "app-map-health", "app-map-vlm-health", "app-map-suite-inspect", "app-map-suite-edit", "app-map-suite-run", "app-map-export-flow", "app-map-viewer", "vlm-provider-list", "vlm-ground-mock", "vlm-ground-openai-compatible", "vlm-ground-mlx-swift-lm", "vlm-provider-compare", "vlm-model-cache", "vlm-model-download":
        return ["evidence", "test"]
    case "plan-inspect":
        return ["replay"]
    case "smoke-ios", "smoke-android", "smoke-harmony":
        return ["smoke", "evidence", "replay"]
    case "act", "action-provider-parse", "tap", "swipe", "type", "paste", "clear", "input", "press", "ios-simulator-host-tap", "ios-simulator-host-wait", "android-tap-text", "android-wait-text", "android-swipe", "android-type-text", "android-paste-text", "android-press-key", "harmony-tap-text", "harmony-wait-text", "harmony-swipe", "harmony-type-text", "harmony-paste-text", "harmony-press-key", "harmony-clear-text":
        return ["action", "assert", "evidence"]
    default:
        return []
    }
}

func runtimeCapabilityNextAction(
    for name: String,
    host: String,
    port: Int,
    serverReachable: Bool,
    connected: Bool
) -> TKCLINextAction? {
    if !serverReachable, runtimeCapabilityRequiresServer(name) {
        return TKCLINextAction(command: "serve", args: ["--host", host, "--port", String(port)], requiresLongRunningProcess: true)
    }
    if !connected, ["runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "focus", "set-text", "select-segment", "set-switch", "ledger", "inspect", "hierarchy", "nodes", "node", "attrs", "object", "export-json", "export-archive", "geometry", "ax", "hit", "screenshot", "wait", "capture", "assert", "verify", "verify-text-exists", "verify-text-not-exists", "replay", "act", "tap", "swipe", "type", "paste", "clear", "input"].contains(name) {
        return TKCLINextAction(command: "status", args: ["--json"])
    }
    switch name {
    case "web-device-hub":
        return TKCLINextAction(command: "web", args: ["--print-command", "--json"], requiresLongRunningProcess: false)
    case "cli-update":
        return TKCLINextAction(command: "update", args: ["--check", "--json"], requiresLongRunningProcess: false)
    case "test-validate":
        return TKCLINextAction(command: "test", args: ["validate", "<path.tritontest.yaml>", "--json"])
    case "test-normalized-plan":
        return TKCLINextAction(command: "test", args: ["normalize", "<path.tritontest.yaml>", "--json"])
    case "test-run-minimal", "test-run-deterministic":
        return TKCLINextAction(command: "test", args: ["run", "<path.tritontest.yaml>", "--json", "--evidence-dir", "<dir.tritonevidence>"])
    case "test-run-vlm-assisted":
        return TKCLINextAction(command: "test", args: ["run", "<path.tritontest.yaml>", "--json", "--evidence-dir", "<dir.tritonevidence>", "--allow-vlm"])
    case "test-run-ai-mock":
        return TKCLINextAction(command: "test", args: ["run", "<path.tritontest.yaml>", "--json", "--evidence-dir", "<dir.tritonevidence>"])
    case "test-report":
        return TKCLINextAction(command: "test", args: ["report", "<dir.tritonevidence>", "--json"])
    case "test-create-from-session":
        return TKCLINextAction(command: "test", args: ["create", "--from-session", "<dir.tritonevidence>", "--output", "<path.tritontest.yaml>", "--json"])
    case "testrec-session-start":
        return TKCLINextAction(command: "testrec", args: ["start", "--platform", "ios", "--case", "<name>", "--output", "<case.tritontestcase>", "--json"])
    case "testrec-event-ingest":
        return TKCLINextAction(command: "testrec", args: ["event", "--session", "<session-id>", "--kind", "action", "--payload-json", "<json>", "--json"])
    case "testrec-session-stop":
        return TKCLINextAction(command: "testrec", args: ["stop", "--session", "<session-id>", "--json"])
    case "testrec-inspect":
        return TKCLINextAction(command: "testrec", args: ["inspect", "<case.tritontestcase>", "--json"])
    case "testrec-compile":
        return TKCLINextAction(command: "testrec", args: ["compile", "<case.tritontestcase>", "--json"])
    case "testrec-proposals-inspect":
        return TKCLINextAction(command: "testrec", args: ["proposals", "<case.tritontestcase>", "--json"])
    case "testrec-page-match":
        return TKCLINextAction(command: "testrec", args: ["match-page", "<case.tritontestcase>", "--page", "<page>", "--candidate-json", "<json>", "--json"])
    case "testrec-replay-dry-run":
        return TKCLINextAction(command: "testrec", args: ["replay", "<case.tritontestcase>", "--platform", "android", "--dry-run", "--json"])
    case "testrec-replay-local-simulated":
        return TKCLINextAction(command: "testrec", args: ["replay", "<case.tritontestcase>", "--platform", "android", "--executor", "local-simulated", "--target-fingerprints-json", "<json>", "--evidence-dir", "<dir.tritonevidence>", "--json"])
    case "testrec-matrix":
        return TKCLINextAction(command: "testrec", args: ["matrix", "<case.tritontestcase>", "--targets", "ios:sim-a,android:emu-a", "--json"])
    case "action-provider-parse":
        return TKCLINextAction(command: "action", args: ["parse", "--provider", "ui-tars", "--input", "<provider-output>", "--json"])
    case "plan":
        return TKCLINextAction(command: "plan", args: ["--format", "json"])
    case "record":
        return TKCLINextAction(command: "record", args: ["--output", "<file.tritonplan>", "--json"])
    case "replay-dry-run":
        return TKCLINextAction(command: "replay", args: ["<file.tritonplan>", "--dry-run", "--json"])
    case "plan-inspect":
        return TKCLINextAction(command: "plan", args: ["inspect", "<file.tritonplan>", "--json"])
    case "target-list":
        return TKCLINextAction(command: "target", args: ["list", "--json"])
    case "target-use":
        return TKCLINextAction(command: "target", args: ["use", "<selector>", "--json"])
    case "target-current":
        return TKCLINextAction(command: "target", args: ["current", "--json"])
    case "target-resolve":
        return TKCLINextAction(command: "target", args: ["resolve", "<selector>", "--json"])
    case "target-wait-ready":
        return TKCLINextAction(command: "target", args: ["wait-ready", "<selector>", "--json"])
    case "host-device", "host-device-selector", "device-list", "device-resolve":
        return TKCLINextAction(command: "device", args: ["list", "--json"])
    case "device-alias":
        return TKCLINextAction(command: "device", args: ["alias", "list", "--json"])
    case "device-use", "device-current":
        return TKCLINextAction(command: "device", args: ["use", "<selector>", "--json"])
    case "device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--json"])
    case "device-screenshot", "host-device-screenshot", "ios-screenshot", "harmony-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--device", "<selector>", "--output", "<path>", "--json"])
    case "ios-device", "ios-device-list":
        return TKCLINextAction(command: "device", args: ["list", "--platform", "ios", "--json"])
    case "ios-device-use":
        return TKCLINextAction(command: "device", args: ["use", "<selector>", "--platform", "ios", "--json"])
    case "ios-device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--platform", "ios", "--json"])
    case "ios-device-screenshot", "ios-simulator-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--platform", "ios", "--device", "<selector>", "--output", "<path>", "--json"])
    case "ios-real-device-screenshot":
        return TKCLINextAction(command: "schema", args: ["--command", "screenshot", "--json"])
    case "ios-host-ax":
        return TKCLINextAction(command: "debug", args: ["ax", "--platform", "ios", "--json"])
    case "ios-host-hid":
        return TKCLINextAction(command: "schema", args: ["--command", "act", "--json"])
    case "ios-simulator-host-tap":
        return TKCLINextAction(command: "act", args: ["tap", "--platform", "ios", "--device", "<selector>", "--text", "<text>", "--json"])
    case "android-device", "android-device-list":
        return TKCLINextAction(command: "device", args: ["list", "--platform", "android", "--json"])
    case "android-device-doctor":
        return TKCLINextAction(command: "device", args: ["doctor", "--platform", "android", "--json"])
    case "android-device-start":
        return TKCLINextAction(command: "device", args: ["start", "--platform", "android", "--avd", "<name>", "--plan-only", "--json"])
    case "android-device-stop":
        return TKCLINextAction(command: "device", args: ["stop", "--platform", "android", "--device", "<selector>", "--confirm", "--json"])
    case "android-device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--platform", "android", "--json"])
    case "android-device-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--platform", "android", "--device", "<selector>", "--output", "<path>", "--json"])
    case "android-bridge":
        return TKCLINextAction(command: "device", args: ["bridge", "status", "--platform", "android", "--device", "<selector>", "--json"])
    case "android-bridge-install":
        return TKCLINextAction(command: "device", args: ["bridge", "install", "--platform", "android", "--device", "<selector>", "--apk", "<path.apk>", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"])
    case "android-bridge-forward":
        return TKCLINextAction(command: "device", args: ["bridge", "forward", "--platform", "android", "--device", "<selector>", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"])
    case "ios-simulator-host-type":
        return TKCLINextAction(command: "sim", args: ["type", "--simulator", "<udid|booted>", "--text", "<text>", "--json"])
    case "device-proxy-ios":
        return TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", "ios", "--json"])
    case "device-proxy-android":
        return TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", "android", "--json"])
    case "device-proxy-harmony":
        return TKCLINextAction(command: "device", args: ["proxy", "doctor", "--platform", "harmony", "--json"])
    case "network-capture-export":
        return TKCLINextAction(command: "device", args: ["proxy", "export", "--platform", "<platform>", "--device", "<selector>", "--output", "<path.har|path.ndjson>", "--json"])
    case "network-certificate-plan":
        return TKCLINextAction(command: "device", args: ["proxy", "cert", "plan", "--platform", "<platform>", "--device", "<selector>", "--certificate", "<path.cer>", "--json"])
    case "network-certificate-install":
        return TKCLINextAction(command: "device", args: ["proxy", "cert", "install", "--platform", "<platform>", "--device", "<selector>", "--certificate", "<path.cer>", "--confirm", "--audit-record", "<id>", "--execute-runner", "--json"])
    case "harmony-device", "harmony-device-list", "harmony-foreground-app-identity":
        return TKCLINextAction(command: "device", args: ["list", "--platform", "harmony", "--json"])
    case "harmony-device-doctor":
        return TKCLINextAction(command: "device", args: ["doctor", "--platform", "harmony", "--json"])
    case "harmony-device-use":
        return TKCLINextAction(command: "device", args: ["use", "<selector>", "--platform", "harmony", "--json"])
    case "harmony-device-start":
        return TKCLINextAction(command: "device", args: ["start", "--platform", "harmony", "--hvd", "<name>", "--path", "<deployed-path>", "--plan-only", "--json"])
    case "harmony-device-wait-ready":
        return TKCLINextAction(command: "device", args: ["wait-ready", "<selector>", "--platform", "harmony", "--json"])
    case "harmony-device-screenshot":
        return TKCLINextAction(command: "device", args: ["screenshot", "--platform", "harmony", "--device", "<selector>", "--output", "<path>", "--json"])
    case "harmony-device-stop":
        return TKCLINextAction(command: "device", args: ["stop", "--platform", "harmony", "--device", "<selector>", "--confirm", "--json"])
    case "harmony-runtime-url":
        return TKCLINextAction(command: "device", args: ["runtime-url", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "android-app", "android-app-install":
        return TKCLINextAction(command: "app", args: ["install", "--platform", "android", "--device", "<selector>", "--apk", "<path.apk>", "--json"])
    case "android-app-inspect":
        return TKCLINextAction(command: "app", args: ["inspect", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "android-app-launch":
        return TKCLINextAction(command: "app", args: ["launch", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "android-app-terminate":
        return TKCLINextAction(command: "app", args: ["terminate", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "android-app-open-url":
        return TKCLINextAction(command: "app", args: ["open-url", "<url>", "--platform", "android", "--device", "<selector>", "--package-name", "<package>", "--json"])
    case "harmony-app", "harmony-app-install":
        return TKCLINextAction(command: "app", args: ["install", "--platform", "harmony", "--device", "<selector>", "--hap", "<path.hap>", "--json"])
    case "harmony-app-info":
        return TKCLINextAction(command: "app", args: ["info", "--platform", "harmony", "--device", "<selector>", "--bundle-id", "<bundle-id>", "--json"])
    case "harmony-app-open-url":
        return TKCLINextAction(command: "app", args: ["open-url", "<url>", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "host-simulator":
        return TKCLINextAction(command: "sim", args: ["list", "--json"])
    case "sim-video":
        return TKCLINextAction(command: "sim", args: ["record", "--simulator", "<udid|booted>", "--output", "<path.mov>", "--json"])
    case "sim-logs":
        return TKCLINextAction(command: "sim", args: ["logs", "--simulator", "<udid|booted>", "--output", "<path.ndjson>", "--json"])
    case "sim-app-process-console":
        return TKCLINextAction(command: "sim", args: ["app-console", "--simulator", "<udid|booted>", "--bundle-id", "<bundle-id>", "--output", "<path.log>", "--json"])
    case "sim-diagnostics":
        return TKCLINextAction(command: "sim", args: ["diagnose", "--output", "<path>", "--json"])
    case "sim-runtime":
        return TKCLINextAction(command: "sim", args: ["runtime", "list", "--json"])
    case "sim-runtime-maintenance":
        return TKCLINextAction(command: "sim", args: ["runtime", "verify", "--json"])
    case "sim-device-maintenance":
        return TKCLINextAction(command: "sim", args: ["clone", "<udid>", "--json"])
    case "sim-personalization":
        return TKCLINextAction(command: "sim", args: ["personalization", "scan-and-personalize", "--json"])
    case "sim-status-bar":
        return TKCLINextAction(command: "sim", args: ["status-bar", "list", "--simulator", "<udid|booted>", "--json"])
    case "sim-privacy":
        return TKCLINextAction(command: "sim", args: ["privacy", "grant", "<service>", "<bundle-id>", "--simulator", "<udid|booted>", "--json"])
    case "sim-location":
        return TKCLINextAction(command: "sim", args: ["location", "set", "<lat,lon>", "--simulator", "<udid|booted>", "--json"])
    case "sim-ui":
        return TKCLINextAction(command: "sim", args: ["ui", "appearance", "--simulator", "<udid|booted>", "--json"])
    case "sim-pasteboard":
        return TKCLINextAction(command: "sim", args: ["pasteboard", "get", "--simulator", "<udid|booted>", "--json"])
    case "sim-push":
        return TKCLINextAction(command: "sim", args: ["push", "--bundle-id", "<bundle-id>", "--payload", "<path|->", "--simulator", "<udid|booted>", "--json"])
    case "host-app", "ios-real-app":
        return TKCLINextAction(command: "app", args: ["list", "--device", "<selector>", "--json"])
    case "ios-real-app-pull":
        return TKCLINextAction(command: "app", args: ["pull", "--device", "<selector>", "--bundle-id", "<bundle-id>", "--source", "<path>", "--destination", "<path>", "--json"])
    case "host-app-open-url-ready":
        return TKCLINextAction(command: "app", args: ["go", "<url>", "--device", "<selector>"])
    case "host-app-open-url-snapshot":
        return TKCLINextAction(command: "app", args: ["go", "<url>", "--device", "<selector>"])
    case "host-preferences":
        return TKCLINextAction(command: "app", args: ["prefs", "get", "<key>", "--device", "<selector>", "--bundle-id", "<bundle-id>", "--json"])
    case "xcode-discovery", "xcode-build", "xcode-test", "xcode-run":
        return TKCLINextAction(command: "xcode", args: ["discover", "--path", ".", "--json"])
    case "xcode-package-build":
        return TKCLINextAction(command: "xcode", args: ["build", "--package", "Package.swift", "--scheme", "<scheme>", "--jsonl"])
    case "xcode-defaults":
        return TKCLINextAction(command: "xcode", args: ["status", "--json"])
    case "xcode-diagnostics":
        return TKCLINextAction(command: "xcode", args: ["status", "--json"])
    case "xcodebuild":
        return TKCLINextAction(command: "xcode", args: ["build", "--jsonl"])
    case "xcresult-summary":
        return TKCLINextAction(command: "xcresult", args: ["summary", "--path", "<path.xcresult>", "--json"])
    case "xcresult-failures":
        return TKCLINextAction(command: "xcresult", args: ["failures", "--path", "<path.xcresult>", "--json"])
    case "xctrace-record":
        return TKCLINextAction(command: "xctrace", args: ["record", "--template", "<name>", "--json"])
    case "coverage-report":
        return TKCLINextAction(command: "coverage", args: ["report", "--xcresult", "<path.xcresult>", "--json"])
    case "capture", "evidence":
        return TKCLINextAction(command: "evidence", args: ["capture", "--case", "<case>", "--output", "<dir.tritonevidence>", "--json"])
    case "evidence-summary":
        return TKCLINextAction(command: "evidence", args: ["summary", "<dir.tritonevidence>", "--json"])
    case "evidence-redact":
        return TKCLINextAction(command: "evidence", args: ["redact", "<dir.tritonevidence>", "--output", "<safe.tritonevidence>", "--json"])
    case "evidence-project-workspace":
        return TKCLINextAction(command: "evidence", args: ["project-workspace", "<dir.tritonevidence>", "--json"])
    case "evidence-project-screens":
        return TKCLINextAction(command: "evidence", args: ["project-screens", "<dir.tritonevidence>", "--json"])
    case "evidence-ingest":
        return TKCLINextAction(command: "evidence", args: ["ingest", "--file", "<artifact.json>", "--kind", "app.structured-evidence", "--output", "<dir.tritonevidence>", "--json"])
    case "sim-media-seed":
        return TKCLINextAction(command: "sim", args: ["media", "seed", "--manifest", "<manifest.json>", "--simulator", "<udid|booted>", "--json"])
    case "app-map-merge":
        return TKCLINextAction(command: "map", args: ["merge", "<dir.tritonevidence>", "--into", "<dir.tritonmap>", "--json"])
    case "app-map-inspect":
        return TKCLINextAction(command: "map", args: ["inspect", "<dir.tritonmap>", "--json"])
    case "app-map-paths":
        return TKCLINextAction(command: "map", args: ["paths", "<dir.tritonmap>", "--json"])
    case "app-map-screens":
        return TKCLINextAction(command: "map", args: ["screens", "<dir.tritonmap>", "--json"])
    case "app-map-transitions":
        return TKCLINextAction(command: "map", args: ["transitions", "<dir.tritonmap>", "--json"])
    case "app-map-path-show":
        return TKCLINextAction(command: "map", args: ["path", "show", "<dir.tritonmap>", "--path", "<pathId>", "--json"])
    case "app-map-path-confirm":
        return TKCLINextAction(command: "map", args: ["path", "confirm", "<dir.tritonmap>", "--path", "<pathId>", "--json"])
    case "app-map-health":
        return TKCLINextAction(command: "map", args: ["health", "<dir.tritonmap>", "--json"])
    case "app-map-vlm-health":
        return TKCLINextAction(command: "map", args: ["vlm-health", "<dir.tritonmap>", "--provider", "<provider>", "--json"])
    case "app-map-suite-inspect":
        return TKCLINextAction(command: "map", args: ["suite", "inspect", "<dir.tritonmap>", "--suite", "smoke", "--json"])
    case "app-map-suite-edit":
        return TKCLINextAction(command: "map", args: ["suite", "add-path", "<dir.tritonmap>", "--suite", "smoke", "--path", "<pathId>", "--json"])
    case "app-map-suite-run":
        return TKCLINextAction(command: "map", args: ["suite", "run", "<dir.tritonmap>", "--suite", "smoke", "--evidence-root", "<dir>", "--json"])
    case "app-map-export-flow":
        return TKCLINextAction(command: "map", args: ["export-flow", "<dir.tritonmap>", "--path", "<pathId>", "--out", "<file.tritontest.yaml>", "--json"])
    case "app-map-viewer":
        return TKCLINextAction(command: "map", args: ["viewer", "<dir.tritonmap>", "--output", "<file.html>", "--json"])
    case "vlm-provider-list":
        return TKCLINextAction(command: "vlm", args: ["providers", "--json"])
    case "vlm-ground-mock":
        return TKCLINextAction(command: "vlm", args: ["ground", "--provider", "mock", "--image", "<screenshot.png>", "--target", "<target>", "--coordinate-contract", "<coordinate-contract.json>", "--json"])
    case "vlm-ground-openai-compatible":
        return TKCLINextAction(command: "vlm", args: ["ground", "--provider", "openai-compatible", "--base-url", "<http://127.0.0.1:8000/v1>", "--model", "<model>", "--image", "<screenshot.png>", "--target", "<target>", "--coordinate-contract", "<coordinate-contract.json>", "--json"])
    case "vlm-ground-mlx-swift-lm":
        return TKCLINextAction(command: "vlm", args: ["ground", "--provider", "mlx-swift-lm", "--model-path", "<local-model>", "--image", "<screenshot.png>", "--target", "<target>", "--coordinate-contract", "<coordinate-contract.json>", "--json"])
    case "vlm-provider-compare":
        return TKCLINextAction(command: "vlm", args: ["compare", "--provider", "mock", "--provider", "mlx-swift-lm", "--model-path", "<local-model>", "--image", "<screenshot.png>", "--target", "<target>", "--coordinate-contract", "<coordinate-contract.json>", "--json"])
    case "vlm-model-cache":
        return TKCLINextAction(command: "vlm", args: ["model", "list", "--provider", "mlx-swift-lm", "--json"])
    case "vlm-model-download":
        return TKCLINextAction(command: "vlm", args: ["model", "download", "<model-id>", "--provider", "mlx-swift-lm", "--json"])
    case "smoke-ios":
        return TKCLINextAction(command: "smoke", args: ["ios", "--device", "<device>", "--bundle-id", "<bundle-id>", "--open-url", "<url>", "--wait-text", "<text>", "--json"])
    case "smoke-android":
        return TKCLINextAction(command: "smoke", args: ["android", "--device", "<device>", "--package", "<package>", "--wait-text", "<text>", "--evidence", "<dir.tritonevidence>", "--json"])
    case "smoke-harmony":
        return TKCLINextAction(command: "smoke", args: ["harmony", "--device", "<device>", "--bundle", "<bundle>", "--ability", "<ability>", "--wait-text", "<text>", "--json"])
    case "replay":
        return TKCLINextAction(command: "plan", args: ["inspect", "<file.tritonplan>", "--json"])
    case "runtime-manifest":
        return TKCLINextAction(command: "debug", args: ["runtime", "manifest", "--json"])
    case "state-app":
        return TKCLINextAction(command: "debug", args: ["state", "app", "--json"])
    case "state-scene":
        return TKCLINextAction(command: "debug", args: ["state", "scene", "--json"])
    case "state-route":
        return TKCLINextAction(command: "debug", args: ["state", "route", "--json"])
    case "state-responder":
        return TKCLINextAction(command: "debug", args: ["state", "responder", "--json"])
    case "snapshot", "app-semantic-state", "media-playback":
        return TKCLINextAction(command: "debug", args: ["snapshot", "--json"])
    case "focus":
        return TKCLINextAction(command: "act", args: ["focus", "<selector>", "--json"])
    case "set-text":
        return TKCLINextAction(command: "act", args: ["set-text", "<selector>", "<text>", "--json"])
    case "select-segment":
        return TKCLINextAction(command: "act", args: ["select-segment", "<selector>", "<value>", "--json"])
    case "set-switch":
        return TKCLINextAction(command: "act", args: ["set-switch", "<selector>", "<on|off|toggle>", "--json"])
    case "semantic-action":
        return TKCLINextAction(command: "schema", args: ["--command", "act", "--json"])
    case "app-semantic-action":
        return TKCLINextAction(command: "debug", args: ["snapshot", "--include", "semantic,app,scene", "--json"])
    case "ledger":
        return TKCLINextAction(command: "debug", args: ["ledger", "--limit", "50", "--json"])
    case "observe":
        return TKCLINextAction(command: "observe", args: ["current", "--json"])
    case "observe-ios":
        return TKCLINextAction(command: "observe", args: ["current", "--platform", "ios", "--json"])
    case "observe-ios-host-ax":
        return TKCLINextAction(command: "observe", args: ["tree", "--platform", "ios", "--device", "<selector>", "--json"])
    case "ios-simulator-host-wait":
        return TKCLINextAction(command: "wait", args: ["--platform", "ios", "--device", "<selector>", "--text", "<text>", "--json"])
    case "observe-android":
        return TKCLINextAction(command: "observe", args: ["tree", "--platform", "android", "--device", "<selector>", "--json"])
    case "observe-harmony":
        return TKCLINextAction(command: "observe", args: ["tree", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "hierarchy":
        return TKCLINextAction(command: "debug", args: ["hierarchy", "--platform", "ios", "--target", "<target>", "--json"])
    case "hierarchy-scene":
        return TKCLINextAction(command: "debug", args: ["hierarchy", "--platform", "ios", "--target", "<target>", "--json"])
    case "android-hierarchy":
        return TKCLINextAction(command: "debug", args: ["hierarchy", "--platform", "android", "--device", "<selector>", "--json"])
    case "harmony-hierarchy":
        return TKCLINextAction(command: "debug", args: ["hierarchy", "--platform", "harmony", "--device", "<selector>", "--json"])
    case "android-ax":
        return TKCLINextAction(command: "debug", args: ["ax", "--platform", "android", "--device", "<selector>", "--json"])
    case "android-wait-text":
        return TKCLINextAction(command: "wait", args: ["--platform", "android", "--text", "<text>", "--json"])
    case "android-tap-text":
        return TKCLINextAction(command: "act", args: ["tap", "<text>", "--platform", "android", "--json"])
    case "android-swipe":
        return TKCLINextAction(command: "act", args: ["swipe", "--platform", "android", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
    case "android-type-text":
        return TKCLINextAction(command: "act", args: ["type", "<text>", "--platform", "android", "--json"])
    case "android-paste-text":
        return TKCLINextAction(command: "act", args: ["paste", "<text>", "--platform", "android", "--json"])
    case "android-press-key":
        return TKCLINextAction(command: "act", args: ["press", "<button>", "--platform", "android", "--json"])
    case "node":
        return TKCLINextAction(command: "debug", args: ["node", "--oid", "<oid>", "--json"])
    case "observe-outline":
        return TKCLINextAction(command: "observe", args: ["tree", "--outline", "--json"])
    case "node-resolve":
        return TKCLINextAction(command: "act", args: ["find", "<text>", "--json"])
    case "node-alias-resolve":
        return TKCLINextAction(command: "node", args: ["resolve", "@1", "--json"])
    case "ax":
        return TKCLINextAction(command: "debug", args: ["ax", "--json"])
    case "screenshot":
        return TKCLINextAction(command: "screenshot", args: ["--output", "<path.png>", "--metadata"])
    case "wait":
        return TKCLINextAction(command: "wait", args: ["--text", "<text>", "--json"])
    case "assert":
        return TKCLINextAction(command: "verify", args: ["text-exists", "<text>", "--json"])
    case "verify", "verify-text-exists":
        return TKCLINextAction(command: "verify", args: ["text-exists", "<text>", "--json"])
    case "verify-text-not-exists":
        return TKCLINextAction(command: "verify", args: ["text-not-exists", "<text>", "--json"])
    case "webview-list":
        return TKCLINextAction(command: "webview", args: ["list", "--json"])
    case "webview-current":
        return TKCLINextAction(command: "webview", args: ["current", "--json"])
    case "webview-current-url":
        return TKCLINextAction(command: "webview", args: ["current-url", "--json"])
    case "webview-snapshot":
        return TKCLINextAction(command: "webview", args: ["snapshot", "--include", "metadata,text,forms", "--json"])
    case "webview-bridge-call":
        return TKCLINextAction(command: "webview", args: ["call", "<method>", "--json"])
    case "webview-events":
        return TKCLINextAction(command: "webview", args: ["events", "--limit", "50", "--json"])
    case "webview-wait":
        return TKCLINextAction(command: "webview", args: ["wait", "--text", "<text>", "--json"])
    case "webview-aware-tap":
        return TKCLINextAction(command: "act", args: ["tap", "--webview-aware", "--selector", "<css>", "--expect-text", "<text>", "--json"])
    case "route-current-url-assert":
        return TKCLINextAction(command: "route", args: ["assert-current-url", "<expected-url>", "--json"])
    case "tap":
        return TKCLINextAction(command: "act", args: ["tap", "<query>", "--json"])
    case "act":
        return TKCLINextAction(command: "act", args: ["tap", "<text>", "--json"])
    case "swipe":
        return TKCLINextAction(command: "act", args: ["swipe", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
    case "type":
        return TKCLINextAction(command: "act", args: ["type", "<text>", "--json"])
    case "paste":
        return TKCLINextAction(command: "act", args: ["paste", "<text>", "--json"])
    case "harmony-tap-text":
        return TKCLINextAction(command: "act", args: ["tap", "<text>", "--platform", "harmony", "--json"])
    case "harmony-wait-text":
        return TKCLINextAction(command: "wait", args: ["--platform", "harmony", "--text", "<text>", "--json"])
    case "harmony-ax":
        return TKCLINextAction(command: "debug", args: ["ax", "--platform", "harmony", "--json"])
    case "harmony-swipe":
        return TKCLINextAction(command: "act", args: ["swipe", "--platform", "harmony", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
    case "harmony-type-text":
        return TKCLINextAction(command: "act", args: ["type", "<text>", "--platform", "harmony", "--json"])
    case "harmony-paste-text":
        return TKCLINextAction(command: "act", args: ["paste", "<text>", "--platform", "harmony", "--json"])
    case "harmony-clear-text":
        return TKCLINextAction(command: "act", args: ["clear", "--platform", "harmony", "--json"])
    case "harmony-press-key":
        return TKCLINextAction(command: "act", args: ["press", "<button>", "--platform", "harmony", "--json"])
    case "clear":
        return TKCLINextAction(command: "act", args: ["clear", "--at", "<x,y>", "--json"])
    case "input":
        return TKCLINextAction(command: "act", args: ["input", "--json", "--summary", "--strict"])
    case "press":
        return TKCLINextAction(command: "schema", args: ["--command", "act", "--json"])
    default:
        return nil
    }
}

func runtimeCapabilityRequiresServer(_ name: String) -> Bool {
    [
        "status",
        "runtime-manifest",
        "state-app",
        "state-scene",
        "state-route",
        "state-responder",
        "snapshot",
        "app-semantic-state",
        "app-semantic-action",
        "media-playback",
        "focus",
        "set-text",
        "select-segment",
        "set-switch",
        "ledger",
        "list",
        "inspect",
        "hierarchy",
        "nodes",
        "node",
        "attrs",
        "object",
        "export-json",
        "export-archive",
        "geometry",
        "ax",
        "hit",
        "screenshot",
        "wait",
        "capture",
        "assert",
        "verify",
        "verify-text-exists",
        "verify-text-not-exists",
        "replay",
        "act",
        "tap",
        "swipe",
        "type",
        "paste",
        "clear",
        "input",
    ].contains(name)
}

func runtimeCapabilityEvidence(for name: String) -> [String] {
    switch name {
    case "version", "cli-update", "schema", "status", "doctor", "capabilities", "plan":
        return ["stdout-json", "command-schema"]
    case "test-validate", "test-normalized-plan":
        return ["stdout-json", "command-schema", "test.normalized-plan"]
    case "test-run-minimal", "test-run-deterministic", "test-run-vlm-assisted":
        return ["stdout-json", "command-schema", "test.normalized-plan", "evidence-bundle"]
    case "test-run-ai-mock":
        return ["stdout-json", "command-schema", "test.normalized-plan", "evidence-bundle"]
    case "test-report":
        return ["stdout-json", "command-schema", "evidence-bundle"]
    case "test-create-from-session":
        return ["stdout-json", "command-schema", "evidence-bundle", "test.normalized-plan", "tritontest-yaml"]
    case "testrec-session-start":
        return ["stdout-json", "command-schema", "tritontestcase", "contract-capabilities"]
    case "testrec-event-ingest":
        return ["stdout-json", "command-schema", "tritontestcase", "page-events", "network-capture"]
    case "testrec-session-stop":
        return ["stdout-json", "command-schema", "tritontestcase", "contract-capabilities"]
    case "testrec-inspect":
        return ["stdout-json", "command-schema", "tritontestcase", "contract-capabilities"]
    case "testrec-compile":
        return ["stdout-json", "command-schema", "tritontestcase", "contract-capabilities", "compiled-contract", "compile-proposals"]
    case "testrec-proposals-inspect":
        return ["stdout-json", "command-schema", "tritontestcase", "compile-proposals"]
    case "testrec-page-match":
        return ["stdout-json", "command-schema", "tritontestcase", "compiled-contract", "page-fingerprint-match"]
    case "testrec-replay-dry-run":
        return ["stdout-json", "command-schema", "tritontestcase", "contract-capabilities"]
    case "testrec-replay-local-simulated":
        return ["stdout-json", "command-schema", "tritontestcase", "compiled-contract", "action-map", "page-fingerprint-match", "evidence-bundle"]
    case "testrec-matrix":
        return ["stdout-json", "command-schema", "tritontestcase", "compiled-contract"]
    case "action-provider-parse":
        return ["stdout-json", "command-schema"]
    case "web-device-hub":
        return ["stdout-json", "command-schema"]
    case "record", "replay-dry-run", "plan-inspect":
        return ["tritonplan", "stdout-json"]
    case "target-list", "target-use", "target-current", "target-resolve", "target-wait-ready":
        return ["host-targets.json", "status-json"]
    case "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder", "snapshot", "app-semantic-state", "media-playback":
        return ["runtime-manifest", "snapshot-json"]
    case "focus", "set-text", "select-segment", "set-switch", "semantic-action", "app-semantic-action":
        return ["runtime-provider", "action-result", "runtime-ledger"]
    case "ledger":
        return ["runtime-ledger"]
    case "ios-simulator-host-type":
        return ["unsupported-envelope", "command-schema"]
    case "host-device", "host-device-selector", "device-alias", "device-list", "device-use", "device-current", "device-resolve", "device-wait-ready", "device-screenshot", "host-device-screenshot", "ios-device", "ios-device-list", "ios-device-use", "ios-device-wait-ready", "ios-device-screenshot", "ios-screenshot", "ios-simulator-screenshot", "ios-host-ax", "ios-host-hid", "android-device", "android-device-doctor", "android-device-list", "android-device-start", "android-device-stop", "android-device-wait-ready", "android-device-screenshot", "android-bridge", "android-bridge-install", "android-bridge-forward", "android-ax", "android-hierarchy", "harmony-device", "harmony-device-doctor", "harmony-device-list", "harmony-device-start", "harmony-foreground-app-identity", "harmony-device-use", "harmony-device-wait-ready", "harmony-device-screenshot", "harmony-device-stop", "harmony-runtime-url", "harmony-app-install", "harmony-app-open-url", "harmony-ax", "harmony-hierarchy", "harmony-screenshot", "host-simulator", "sim-video", "sim-logs", "sim-app-process-console", "sim-diagnostics", "sim-runtime", "sim-runtime-maintenance", "sim-device-maintenance", "sim-personalization", "sim-status-bar", "sim-privacy", "sim-location", "sim-ui", "sim-pasteboard", "sim-push", "host-app", "ios-real-app", "ios-real-app-pull", "host-app-open-url-ready", "host-app-open-url-snapshot", "host-preferences", "android-app", "android-app-inspect", "android-app-install", "android-app-launch", "android-app-terminate", "android-app-open-url", "harmony-app", "harmony-app-info":
        return ["host-command-json", "host-artifact"]
    case "device-proxy-ios", "device-proxy-android", "device-proxy-harmony":
        return ["host-command-json", "network-capture", "proxy-restore"]
    case "network-certificate-plan", "network-certificate-install":
        return ["host-command-json", "network-capture"]
    case "observe", "observe-ios", "observe-ios-host-ax", "observe-android", "observe-harmony", "observe-outline":
        return ["surface-tree", "runtime-ax", "host-layout"]
    case "list":
        return ["status-json", "runtime-manifest"]
    case "inspect", "hierarchy", "hierarchy-scene", "nodes":
        return ["surface-tree", "runtime-ax"]
    case "node":
        return ["hierarchy-node", "surface-tree"]
    case "attrs", "object":
        return ["hierarchy-node", "surface-tree"]
    case "node-resolve", "node-alias-resolve":
        return ["target.resolution", "surface-tree"]
    case "export-json":
        return ["surface-tree", "host-artifact"]
    case "export-archive":
        return ["host-artifact", "screenshot-metadata"]
    case "geometry":
        return ["snapshot-json"]
    case "hit":
        return ["target.resolution", "surface-tree"]
    case "webview-list", "webview-current":
        return ["webview-candidates", "host-layout", "runtime-ax"]
    case "webview-current-url":
        return ["webview-provider", "provider-url"]
    case "webview-snapshot":
        return ["webview-provider", "webview-snapshot"]
    case "webview-bridge-call":
        return ["webview-provider", "bridge-call-result"]
    case "webview-events":
        return ["webview-provider", "page-events"]
    case "webview-wait":
        return ["webview-provider", "wait-samples"]
    case "webview-aware-tap":
        return ["webview-provider", "act.webview-aware-tap"]
    case "route-current-url-assert":
        return ["webview-provider", "route-assertion"]
    case "xcode-discovery", "xcode-defaults", "xcode-package-build", "xcode-diagnostics", "xcodebuild", "xcode-build", "xcode-test", "xcode-run", "xcresult-summary", "xcresult-failures", "xctrace-record", "coverage-report":
        return ["xcodebuild-json", "xcresult", "trace", "coverage"]
    case "capture", "evidence", "evidence-summary", "evidence-redact":
        return ["evidence-bundle"]
    case "evidence-ingest":
        return ["evidence-bundle", "app.structured-evidence"]
    case "evidence-project-workspace", "evidence-project-screens":
        return ["evidence-bundle", "screen-workspace"]
    case "sim-media-seed":
        return ["host-command-json", "host-simulator-media-seed"]
    case "app-map-merge", "app-map-inspect", "app-map-paths", "app-map-screens", "app-map-transitions", "app-map-path-show", "app-map-path-confirm", "app-map-health", "app-map-vlm-health", "app-map-suite-inspect", "app-map-suite-edit":
        return ["evidence-bundle", "screen-workspace", "app-map"]
    case "app-map-suite-run":
        return ["evidence-bundle", "screen-workspace", "app-map", "test.normalized-plan"]
    case "app-map-export-flow":
        return ["app-map", "test.normalized-plan"]
    case "app-map-viewer":
        return ["app-map", "app-map-viewer-html"]
    case "vlm-provider-list":
        return ["command-schema"]
    case "vlm-ground-mock":
        return ["vlm-grounding", "vlm-overlay", "coordinate-contract", "screenshot"]
    case "vlm-ground-openai-compatible":
        return ["vlm-grounding", "vlm-overlay", "coordinate-contract", "screenshot"]
    case "vlm-ground-mlx-swift-lm":
        return ["vlm-grounding", "vlm-overlay", "vlm-request", "vlm-response", "vlm-raw-output", "vlm-parsed-point", "vlm-transform", "vlm-model-metadata", "coordinate-contract", "screenshot"]
    case "vlm-provider-compare":
        return ["vlm-grounding", "vlm-overlay", "vlm-compare", "coordinate-contract", "screenshot"]
    case "vlm-model-cache", "vlm-model-download":
        return ["vlm-model-cache", "vlm-model-metadata"]
    case "network-capture-export":
        return ["network-capture", "evidence-bundle"]
    case "smoke-ios", "smoke-android", "smoke-harmony":
        return ["smoke-summary", "evidence-bundle"]
    case "replay":
        return ["tritonplan"]
    case "assert", "verify", "verify-text-exists", "verify-text-not-exists":
        return ["assert.result", "runtime-snapshot"]
    case "ax":
        return ["runtime-ax", "host-layout"]
    case "screenshot":
        return ["screenshot", "screenshot-metadata"]
    case "wait":
        return ["wait.result", "runtime-samples"]
    case "act", "tap", "swipe", "type", "paste", "clear", "input":
        return ["input.result", "runtime-ledger"]
    case "ios-simulator-host-tap", "ios-simulator-host-wait", "android-tap-text", "android-wait-text", "android-swipe", "android-type-text", "android-paste-text", "android-press-key", "harmony-tap-text", "harmony-wait-text", "harmony-swipe", "harmony-type-text", "harmony-paste-text", "harmony-press-key":
        return ["host-command-json", "host-artifact"]
    case "harmony-clear-text":
        return ["unsupported-envelope", "command-schema"]
    case "press":
        return ["unsupported-envelope", "command-schema"]
    default:
        return []
    }
}

func printCapabilities(_ response: TKCapabilitiesResponse, format: ClientOutputFormat, language: CLILanguage = effectiveLanguage(nil)) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        switch language {
        case .en:
            print("ok: \(response.ok)")
            print("serverReachable: \(response.serverReachable)")
            print("connected: \(response.connected)")
            print("latestHierarchyAvailable: \(response.latestHierarchyAvailable)")
            print("activeHierarchyAvailable: \(response.activeHierarchyAvailable ?? (response.connected && response.latestHierarchyAvailable))")
            print("hierarchyCacheState: \(response.hierarchyCacheState ?? "unknown")")
            print("targetConnectionState: \(response.targetConnectionState ?? (response.connected ? "connected" : "disconnected"))")
            print("targetCount: \(response.targetCount)")
            print("runtime: \(response.runtime)")
        case .zh:
            print("正常: \(response.ok)")
            print("服务可达: \(response.serverReachable)")
            print("已连接: \(response.connected)")
            print("已有最新层级: \(response.latestHierarchyAvailable)")
            print("当前连接已有层级: \(response.activeHierarchyAvailable ?? (response.connected && response.latestHierarchyAvailable))")
            print("层级缓存状态: \(response.hierarchyCacheState ?? "unknown")")
            print("目标连接状态: \(response.targetConnectionState ?? (response.connected ? "connected" : "disconnected"))")
            print("目标数量: \(response.targetCount)")
            print("运行时: \(response.runtime)")
        }
        if let error = response.error {
            switch language {
            case .en:
                print("error: \(error.code) \(error.message)")
            case .zh:
                print("错误: \(localizedErrorMessage(error, language: language))")
            }
            if let hint = error.hint {
                switch language {
                case .en:
                    print("hint: \(hint)")
                case .zh:
                    print("提示: \(localizedHint(error, fallback: hint, language: language))")
                }
            }
        }
        print(language == .zh ? "能力:" : "capabilities:")
        for capability in response.capabilities {
            let status = capability.supported
                ? (language == .zh ? "支持" : "supported")
                : (language == .zh ? "不支持" : "unsupported")
            if let reason = capability.reason {
                print("  \(capability.name): \(status) (\(reason))")
            } else {
                print("  \(capability.name): \(status)")
            }
        }
    }
}

func buildDoctor(host: String, port: Int, platform: HostDevicePlatform? = nil) async -> TKDoctorResponse {
    buildDoctorResponse(capabilities: await buildCapabilities(host: host, port: port), host: host, port: port, platform: platform)
}

func buildDoctorResponse(capabilities: TKCapabilitiesResponse, host: String, port: Int, platform: HostDevicePlatform? = nil) -> TKDoctorResponse {
    let checks = doctorChecks(capabilities: capabilities, host: host, port: port, platform: platform)
    let nextCheck = checks.first(where: { $0.status == "fail" })
        ?? checks.first(where: { $0.id == "host-device" })
        ?? checks.first(where: { $0.status == "warn" })
    let nextStep = nextCheck?.id ?? "ready"
    let platformFocused = platform != nil
    return TKDoctorResponse(
        ok: platformFocused ? checks.allSatisfy { $0.status != "fail" } : capabilities.ok && checks.allSatisfy { $0.status != "fail" },
        serverReachable: capabilities.serverReachable,
        connected: capabilities.connected,
        runtime: capabilities.runtime,
        nextStep: nextStep,
        nextWorkflows: nextCheck?.workflowCategories ?? [],
        checks: checks,
        error: platformFocused ? nil : capabilities.error
    )
}

private func doctorChecks(capabilities: TKCapabilitiesResponse, host: String, port: Int, platform: HostDevicePlatform?) -> [TKDoctorCheck] {
    if let platform {
        return platformFocusedDoctorChecks(capabilities: capabilities, host: host, port: port, platform: platform)
    }

    if !capabilities.serverReachable {
        let startServerRelatedCapabilities = capabilities.capabilities.filter { $0.nextAction?.command == "serve" }.map(\.name)
        return [
            TKDoctorCheck(
                id: "start-server",
                status: "fail",
                code: "server_unavailable",
                message: "Local Triton server is not reachable",
                hint: "Start the local control server, then rerun doctor.",
                nextAction: TKCLINextAction(command: "serve", args: ["--host", host, "--port", String(port)], requiresLongRunningProcess: true),
                relatedCapabilities: startServerRelatedCapabilities,
                workflowCategories: workflowCategoriesForCapabilities(startServerRelatedCapabilities, in: capabilities.capabilities)
            ),
            TKDoctorCheck(
                id: "inspect-schema",
                status: "pass",
                code: "schema_available",
                message: "CLI schema is available without a running server",
                hint: "Run schema when an agent needs command contracts before server startup.",
                nextAction: TKCLINextAction(command: "schema", args: ["--json"]),
                relatedCapabilities: ["schema", "plan", "capabilities"],
                workflowCategories: workflowCategoriesForCapabilities(["schema", "plan", "capabilities"], in: capabilities.capabilities)
            ),
        ]
    }

    var checks: [TKDoctorCheck] = [
        TKDoctorCheck(
            id: "server",
            status: "pass",
            code: "server_reachable",
            message: "Local Triton server responded",
            nextAction: TKCLINextAction(command: "status", args: ["--json"]),
            relatedCapabilities: ["status", "capabilities"],
            workflowCategories: workflowCategoriesForCapabilities(["status", "capabilities"], in: capabilities.capabilities)
        ),
    ]

    if capabilities.connected {
        let targetRelatedCapabilities = ["target-current", "runtime-manifest", "snapshot"]
        checks.append(TKDoctorCheck(
            id: "target",
            status: "pass",
            code: "target_connected",
            message: "At least one embedded runtime target is connected",
            nextAction: TKCLINextAction(command: "target", args: ["current", "--json"]),
            relatedCapabilities: targetRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(targetRelatedCapabilities, in: capabilities.capabilities)
        ))
        let runtimeRelatedCapabilities = capabilities.capabilities.filter { $0.group == "runtime" && $0.supported }.map(\.name)
        checks.append(TKDoctorCheck(
            id: "runtime",
            status: "pass",
            code: "runtime_available",
            message: "Embedded runtime capabilities are available",
            nextAction: TKCLINextAction(command: "runtime", args: ["manifest", "--json"]),
            relatedCapabilities: runtimeRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(runtimeRelatedCapabilities, in: capabilities.capabilities)
        ))
    } else {
        let connectTargetRelatedCapabilities = capabilities.capabilities
            .filter { $0.reason?.contains("embedded TritonKit runtime") == true }
            .map(\.name)
        checks.append(TKDoctorCheck(
            id: "connect-target",
            status: "fail",
            code: "target_unavailable",
            message: "Triton server is reachable but no embedded runtime target is connected",
            hint: "Launch an app that embeds TritonKit, or run an Xcode/app workflow that starts it.",
            nextAction: TKCLINextAction(command: "target", args: ["list", "--json"]),
            relatedCapabilities: connectTargetRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(connectTargetRelatedCapabilities, in: capabilities.capabilities)
        ))
    }

    let hostDeviceCapabilities = hostDeviceDoctorCapabilities(platform: platform)
    checks.append(TKDoctorCheck(
        id: "host-device",
        status: "pass",
        code: "host_device_available",
        message: platform.map { "Host-side \($0.rawValue) device workflows are available" } ?? "Host-side device workflows are available",
        hint: "Use device list/doctor before falling back to raw platform tools.",
        nextAction: hostDeviceDoctorNextAction(platform: platform),
        relatedCapabilities: hostDeviceCapabilities,
        workflowCategories: workflowCategoriesForCapabilities(hostDeviceCapabilities, in: capabilities.capabilities)
    ))

    let unsupportedActionNames = capabilities.capabilities
        .filter { $0.group == "action" && !$0.supported && !isInformationalHarmonyActionBoundary($0) }
        .map(\.name)
    if !unsupportedActionNames.isEmpty {
        checks.append(TKDoctorCheck(
            id: "action-surface",
            status: unsupportedActionNames == ["press"] ? "warn" : "fail",
            code: "action_capabilities_limited",
            message: "Some action capabilities are unavailable in the current environment",
            hint: "Use capabilities to inspect per-action reason and nextAction.",
            nextAction: TKCLINextAction(command: "capabilities", args: ["--json"]),
            relatedCapabilities: unsupportedActionNames,
            workflowCategories: workflowCategoriesForCapabilities(unsupportedActionNames, in: capabilities.capabilities)
        ))
    }

    let planRelatedCapabilities = ["plan", "target-list", "evidence-summary"]
    checks.append(TKDoctorCheck(
        id: "plan",
        status: "pass",
        code: "plan_available",
        message: "Task planning is available",
        nextAction: TKCLINextAction(command: "plan", args: ["--json"]),
        relatedCapabilities: planRelatedCapabilities,
        workflowCategories: workflowCategoriesForCapabilities(planRelatedCapabilities, in: capabilities.capabilities)
    ))

    return checks
}

private func platformFocusedDoctorChecks(capabilities: TKCapabilitiesResponse, host: String, port: Int, platform: HostDevicePlatform) -> [TKDoctorCheck] {
    var checks: [TKDoctorCheck] = []

    if capabilities.serverReachable {
        checks.append(TKDoctorCheck(
            id: "server",
            status: "pass",
            code: "server_reachable",
            message: "Local Triton server responded",
            nextAction: TKCLINextAction(command: "status", args: ["--json"]),
            relatedCapabilities: ["status", "capabilities"],
            workflowCategories: workflowCategoriesForCapabilities(["status", "capabilities"], in: capabilities.capabilities)
        ))
    }

    let hostDeviceCapabilities = hostDeviceDoctorCapabilities(platform: platform)
    checks.append(TKDoctorCheck(
        id: "host-device",
        status: "pass",
        code: "host_device_available",
        message: "Host-side \(platform.rawValue) device workflows are available",
        hint: "Use device doctor/list/wait-ready before falling back to raw platform tools.",
        nextAction: hostDeviceDoctorNextAction(platform: platform),
        relatedCapabilities: hostDeviceCapabilities,
        workflowCategories: ["target", "evidence"]
    ))

    if capabilities.serverReachable {
        if capabilities.connected {
            let runtimeRelatedCapabilities = capabilities.capabilities.filter { $0.group == "runtime" && $0.supported }.map(\.name)
            checks.append(TKDoctorCheck(
                id: "runtime",
                status: "pass",
                code: "runtime_available",
                message: "Embedded runtime capabilities are available",
                nextAction: TKCLINextAction(command: "runtime", args: ["manifest", "--json"]),
                relatedCapabilities: runtimeRelatedCapabilities,
                workflowCategories: workflowCategoriesForCapabilities(runtimeRelatedCapabilities, in: capabilities.capabilities)
            ))
        } else {
            let runtimeRelatedCapabilities = capabilities.capabilities
                .filter { $0.reason?.contains("embedded TritonKit runtime") == true }
                .map(\.name)
            checks.append(TKDoctorCheck(
                id: "embedded-runtime",
                status: "warn",
                code: "target_unavailable",
                message: "No embedded runtime target is connected; host-side \(platform.rawValue) workflows can continue without it",
                hint: "Only connect an embedded runtime when the workflow needs in-app DEBUG state.",
                nextAction: TKCLINextAction(command: "target", args: ["list", "--json"]),
                relatedCapabilities: runtimeRelatedCapabilities,
                workflowCategories: workflowCategoriesForCapabilities(runtimeRelatedCapabilities, in: capabilities.capabilities)
            ))
        }
    } else {
        let startServerRelatedCapabilities = capabilities.capabilities.filter { $0.nextAction?.command == "serve" }.map(\.name)
        checks.append(TKDoctorCheck(
            id: "runtime-server",
            status: "warn",
            code: "server_unavailable",
            message: "Local Triton server is not reachable; host-side \(platform.rawValue) device diagnostics do not require it",
            hint: "Start `triton serve` only when the workflow needs embedded runtime state.",
            nextAction: TKCLINextAction(command: "serve", args: ["--host", host, "--port", String(port)], requiresLongRunningProcess: true),
            relatedCapabilities: startServerRelatedCapabilities,
            workflowCategories: workflowCategoriesForCapabilities(startServerRelatedCapabilities, in: capabilities.capabilities)
        ))
    }

    let planRelatedCapabilities = ["plan", "target-list", "evidence-summary"]
    checks.append(TKDoctorCheck(
        id: "plan",
        status: "pass",
        code: "plan_available",
        message: "Task planning is available",
        nextAction: TKCLINextAction(command: "plan", args: ["--platform", platform.rawValue, "--json"]),
        relatedCapabilities: planRelatedCapabilities,
        workflowCategories: workflowCategoriesForCapabilities(planRelatedCapabilities, in: capabilities.capabilities)
    ))

    return checks
}

private func hostDeviceDoctorCapabilities(platform: HostDevicePlatform?) -> [String] {
    switch platform {
    case .ios:
        return ["host-device", "ios-device", "ios-device-list"]
    case .android:
        return ["host-device", "android-device", "android-device-list", "android-device-doctor"]
    case .harmony:
        return ["host-device", "harmony-device", "harmony-device-list", "harmony-device-doctor"]
    case nil:
        return ["host-device", "device-list", "ios-device-list", "android-device-list", "harmony-device-list"]
    }
}

private func hostDeviceDoctorNextAction(platform: HostDevicePlatform?) -> TKCLINextAction {
    if let platform {
        return TKCLINextAction(command: "device", args: ["list", "--platform", platform.rawValue, "--json"])
    }
    return TKCLINextAction(command: "device", args: ["list", "--json"])
}

private func isInformationalHarmonyActionBoundary(_ capability: TKRuntimeCapability) -> Bool {
    guard capability.name.hasPrefix("harmony-") else {
        return false
    }
    return capability.reason?.contains("not available in the current adapter") == true
}

private func workflowCategoriesForCapabilities(
    _ capabilityNames: [String],
    in capabilities: [TKRuntimeCapability]
) -> [String] {
    let capabilityMap = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.name, $0) })
    let taxonomy = [
        "action", "app", "assert", "evidence", "observe", "project",
        "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
    ]
    let categories = Set(capabilityNames.flatMap { capabilityMap[$0]?.requiredBy ?? [] })
    return taxonomy.filter { categories.contains($0) }
}

func printDoctor(_ response: TKDoctorResponse, format: ClientOutputFormat, language: CLILanguage = effectiveLanguage(nil)) throws {
    switch format {
    case .json:
        print(try encodeJSON(response))
    case .text:
        switch language {
        case .en:
            print("ok: \(response.ok)")
            print("serverReachable: \(response.serverReachable)")
            print("connected: \(response.connected)")
            print("runtime: \(response.runtime)")
            print("nextStep: \(response.nextStep)")
        case .zh:
            print("正常: \(response.ok)")
            print("服务可达: \(response.serverReachable)")
            print("已连接: \(response.connected)")
            print("运行时: \(response.runtime)")
            print("下一步: \(response.nextStep)")
        }
        for check in response.checks {
            print("- \(check.id): \(check.status) \(check.code)")
            if let hint = check.hint {
                print("  hint: \(hint)")
            }
            if let nextAction = check.nextAction {
                print("  nextAction: triton \(([nextAction.command] + nextAction.args).joined(separator: " "))")
            }
        }
    }
}


func renderTargetLine(_ target: TKTargetSummary) -> String {
    [
        target.id,
        target.transport,
        target.identityState ?? "-",
        target.hierarchyCacheState ?? "-",
        target.appName ?? "-",
        target.bundleIdentifier ?? "-",
        target.deviceDescription ?? "-",
        target.osDescription ?? "-",
    ].joined(separator: "\t")
}
