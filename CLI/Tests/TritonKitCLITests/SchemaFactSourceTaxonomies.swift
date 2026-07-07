import Testing
import TritonKitShared
@testable import TritonKitCLI

func capabilityGroupTaxonomy() -> Set<String> {
    [
        "action", "assert", "bootstrap", "evidence", "host", "observe",
        "replay", "route", "runtime", "smoke", "target", "webview", "xcode",
        "test",
    ]
}

func capabilityWorkflowTaxonomy() -> Set<String> {
    [
        "action", "app", "assert", "evidence", "observe", "project",
        "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
        "test",
    ]
}

func capabilityEvidenceTaxonomy() -> Set<String> {
    [
        "action-map", "action-result", "assert.result", "bridge-call-result", "command-schema",
        "app-map", "app-map-viewer-html", "app.structured-evidence", "compile-proposals", "compiled-contract", "coordinate-contract", "coverage", "evidence-bundle", "host-artifact", "host-command-json", "host-simulator-media-seed",
        "host-layout", "host-targets.json", "hierarchy-node", "input.result",
        "page-events", "page-fingerprint-match", "page-map", "provider-url", "route-assertion", "runtime-ax",
        "runtime-ledger", "runtime-manifest", "runtime-provider",
        "runtime-samples", "runtime-snapshot", "screenshot", "screenshot-metadata",
        "network-capture", "network-fixture", "network-map", "proxy-restore", "smoke-summary", "snapshot-json", "status-json", "stdout-json",
        "contract-capabilities", "screen-workspace", "surface-tree", "target.resolution", "test.normalized-plan", "trace", "tritonplan", "tritontest-yaml", "tritontestcase",
        "unsupported-envelope", "vlm-compare", "vlm-grounding", "vlm-model-cache", "vlm-model-metadata", "vlm-overlay", "vlm-parsed-point", "vlm-raw-output", "vlm-request", "vlm-response", "vlm-transform", "wait.result", "wait-samples", "webview-candidates",
        "webview-provider", "webview-snapshot", "xcodebuild-json", "xcresult",
    ]
}

func outputContractFormatTaxonomy() -> Set<String> {
    ["json", "jsonl", "archive"]
}

func outputContractKindTaxonomy() -> Set<String> {
    [
        "artifact-envelope",
        "assert-result",
        "app-map-export-flow-result",
        "app-map-health-result",
        "app-map-inspect-result",
        "app-map-merge-result",
        "app-map-path-show-result",
        "app-map-paths-result",
        "app-map-screens-result",
        "app-map-suite-inspect-result",
        "app-map-suite-run-result",
        "app-map-transitions-result",
        "app-map-viewer-result",
        "app-map-vlm-health-result",
        "action-provider-parse-result",
        "ax-node-list",
        "capability-matrix",
        "cli-update-plan",
        "command-schema-list",
        "diagnostic-checks",
        "envelope",
        "evidence-manifest",
        "export-archive",
        "final-event",
        "hierarchy-info",
        "hierarchy-scene",
        "hierarchy-node",
        "hierarchy-node-list",
        "hit-test-result",
        "host-action",
        "host-app-open-url-flow",
        "host-artifact",
        "host-device-list",
        "host-device-bridge",
        "host-device-ready",
        "host-device-selection",
        "host-device-proxy",
        "host-simulator-ax",
        "host-simulator-list",
        "host-simulator-media-seed",
        "host-simulator-screenshot-metadata",
        "input-batch-summary",
        "input-result",
        "node-attributes",
        "node-object",
        "node-resolution",
        "observe-surface",
        "progress-event",
        "recommended-steps",
        "record-plan",
        "replay-plan-summary",
        "replay-result",
        "route-assertion",
        "runtime-ledger",
        "runtime-ledger-entry",
        "runtime-manifest",
        "runtime-node-property-patch",
        "simulator-screenshot",
        "xcode-status",
        "runtime-snapshot",
        "runtime-state",
        "screenshot-metadata",
        "semantic-action-result",
        "screen-workspace-projection-result",
        "smoke-result",
        "status-envelope",
        "target-list",
        "target-resolution",
        "target-summary",
        "test-normalized-plan",
        "test-create-result",
        "testrec-compile",
        "testrec-event",
        "testrec-inspect",
        "testrec-matrix",
        "testrec-page-fingerprint-match",
        "testrec-proposals-inspect",
        "testrec-replay-dry-run",
        "testrec-replay-result",
        "testrec-session-start",
        "testrec-session-stop",
        "test-report",
        "test-run-result",
        "test-validation-result",
        "vlm-ground-result",
        "vlm-compare-result",
        "vlm-model-download-result",
        "vlm-model-inspect-result",
        "vlm-model-list-result",
        "vlm-model-mutation-result",
        "vlm-model-preflight-result",
        "vlm-providers-result",
        "wait-result",
        "webview-bridge-call",
        "webview-candidates",
        "webview-current",
        "webview-events",
        "webview-provider-url",
        "webview-snapshot",
        "webview-wait-result",
        "window-geometry",
    ]
}

func commandOutputFormatTaxonomy() -> Set<String> {
    [
        "archive",
        "auto",
        "file",
        "json",
        "json-metadata",
        "jsonl",
        "logs",
        "text",
        "tree",
    ]
}

func recoveryCommandRootTaxonomy() -> Set<String> {
    [
        "act",
        "action",
        "app",
        "assert",
        "attrs",
        "ax",
        "capabilities",
        "capture",
        "clear",
        "coverage",
        "debug",
        "device",
        "doctor",
        "evidence",
        "export",
        "find",
        "focus",
        "geometry",
        "hierarchy",
        "hit",
        "input",
        "inspect",
        "ledger",
        "list",
        "map",
        "node",
        "nodes",
        "object",
        "observe",
        "paste",
        "plan",
        "press",
        "record",
        "replay",
        "route",
        "runtime",
        "schema",
        "screenshot",
        "select-segment",
        "serve",
        "set-switch",
        "set-text",
        "sim",
        "smoke",
        "snapshot",
        "state",
        "status",
        "swipe",
        "tap",
        "target",
        "test",
        "testrec",
        "type",
        "update",
        "version",
        "verify",
        "vlm",
        "wait",
        "web",
        "webview",
        "xcode",
        "xcresult",
        "xctrace",
    ]
}

func recoveryCommandCategoryTaxonomy() -> Set<String> {
    [
        "act",
        "archive",
        "diagnose",
        "discover",
        "observe",
        "plan",
        "prepare-target",
        "project",
        "replay",
        "smoke",
        "verify",
    ]
}

func recoveryCommandRootCategoryMap() -> [String: String] {
    [
        "act": "act",
        "action": "act",
        "app": "prepare-target",
        "assert": "verify",
        "attrs": "observe",
        "ax": "observe",
        "capabilities": "diagnose",
        "capture": "archive",
        "clear": "act",
        "coverage": "archive",
        "debug": "diagnose",
        "device": "prepare-target",
        "doctor": "diagnose",
        "evidence": "archive",
        "export": "archive",
        "find": "discover",
        "focus": "act",
        "geometry": "observe",
        "hierarchy": "observe",
        "hit": "observe",
        "input": "act",
        "inspect": "discover",
        "ledger": "archive",
        "list": "discover",
        "map": "archive",
        "node": "observe",
        "nodes": "observe",
        "object": "observe",
        "observe": "observe",
        "paste": "act",
        "plan": "plan",
        "press": "act",
        "record": "replay",
        "replay": "replay",
        "route": "verify",
        "runtime": "diagnose",
        "schema": "diagnose",
        "screenshot": "archive",
        "select-segment": "act",
        "serve": "diagnose",
        "set-switch": "act",
        "set-text": "act",
        "sim": "prepare-target",
        "smoke": "smoke",
        "snapshot": "observe",
        "state": "observe",
        "status": "diagnose",
        "swipe": "act",
        "tap": "act",
        "target": "prepare-target",
        "test": "diagnose",
        "testrec": "diagnose",
        "type": "act",
        "update": "diagnose",
        "version": "diagnose",
        "verify": "verify",
        "vlm": "archive",
        "wait": "verify",
        "web": "observe",
        "webview": "observe",
        "xcode": "project",
        "xcresult": "archive",
        "xctrace": "archive",
    ]
}

func recoveryCategories(forFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "ambiguous_target", "android_target_unauthorized", "device_not_ready", "simulator_not_booted", "simulator_not_found", "target_not_found", "target_unavailable":
        return ["discover", "prepare-target", "diagnose"]
    case "ios_host_ax_unsupported_platform":
        return ["diagnose", "plan"]
    case "ambiguous_workspace", "invalid_workspace_path", "scheme_not_found", "workspace_not_found", "xcode_not_idle", "xcodebuild_interrupted", "orphaned_xcodebuild":
        return ["project", "diagnose"]
    case "assertion_failed", "route_mismatch", "text_not_found", "timeout":
        return ["verify", "observe", "archive"]
    case "artifact_write_failed", "file_write_failed", "overwrite_refused":
        return ["archive", "diagnose"]
    case "app_map_error", "unconfirmed_path", "non_replayable_path":
        return ["archive", "plan", "diagnose"]
    case "action_failed", "step_failed":
        return ["act", "observe", "verify", "archive"]
    case "confirmation_required", "destructive_action_requires_policy":
        return ["diagnose", "plan", "act"]
    case "javascript_error":
        return ["diagnose", "observe", "archive"]
    case "stale_node_alias":
        return ["diagnose", "observe", "plan"]
    case "runtime_not_connected":
        return ["diagnose", "prepare-target", "observe"]
    case "device_locked", "device_not_trusted", "ddi_missing", "android_debugging_disabled", "harmony_target_unauthorized", "harmony_debugging_disabled":
        return ["diagnose", "prepare-target"]
    case "debug_runtime_disabled":
        return ["diagnose", "prepare-target", "observe"]
    case "android_bridge_not_installed", "android_bridge_runner_not_configured":
        return ["diagnose", "prepare-target", "plan"]
    case "devicectl_json_missing":
        return ["diagnose", "archive"]
    case "provisioning_profile_missing":
        return ["diagnose", "project"]
    case "swift_macro_plugin_malformed_response":
        return ["diagnose", "project", "archive"]
    case "validation_error", "validation_failed", "unknown_command_schema", "unknown_step", "duplicate_step_id", "session_not_recording":
        return ["diagnose", "plan", "discover", "observe", "archive"]
    case "web_port_in_use":
        return ["diagnose", "plan"]
    case "proxy_visibility_limited":
        return ["diagnose", "plan", "observe", "archive"]
    case "proxy_cert_untrusted", "proxy_runner_not_configured", "proxy_unverified_platform_proxy":
        return ["diagnose", "plan"]
    case "proxy_real_device_not_supported":
        return ["diagnose", "prepare-target", "plan"]
    case "proxy_endpoint_unreachable", "proxy_cert_install_failed", "proxy_start_failed", "proxy_restore_failed":
        return ["diagnose", "plan", "archive"]
    default:
        if failureCode.hasPrefix("ambiguous_") {
            return ["discover", "observe", "prepare-target", "diagnose"]
        }
        if failureCode.hasPrefix("ai_") {
            return ["archive", "diagnose", "plan"]
        }
        if failureCode.hasPrefix("invalid_") {
            return ["diagnose", "project", "plan"]
        }
        if failureCode.hasPrefix("missing_") {
            return ["diagnose", "project", "observe"]
        }
        if failureCode.hasSuffix("_missing") {
            return ["diagnose", "project"]
        }
        if failureCode.hasSuffix("_not_found") {
            return ["discover", "prepare-target", "project", "observe", "diagnose"]
        }
        if failureCode.hasSuffix("_not_available") {
            return ["diagnose", "prepare-target", "observe"]
        }
        if failureCode.hasSuffix("_not_allowed") {
            return ["diagnose", "plan", "observe"]
        }
        if failureCode.hasSuffix("_not_connected") {
            return ["diagnose", "prepare-target", "observe"]
        }
        if failureCode.hasSuffix("_not_supported") {
            return ["diagnose", "plan", "act"]
        }
        if failureCode.hasSuffix("_unavailable") {
            return ["diagnose", "prepare-target", "observe"]
        }
        if failureCode.hasSuffix("_offline") {
            return ["diagnose", "prepare-target"]
        }
        if failureCode.hasSuffix("_timeout") {
            return ["diagnose", "observe", "archive", "verify"]
        }
        if failureCode.hasSuffix("_unresolved") {
            return ["diagnose", "discover", "prepare-target", "project"]
        }
        if failureCode.hasSuffix("_failed") {
            return ["diagnose", "archive", "project", "act", "verify"]
        }
        if failureCode.hasSuffix("_mismatch") {
            return ["verify", "observe", "archive"]
        }
        if failureCode.hasSuffix("_too_large") || failureCode.hasSuffix("_rejected") {
            return ["archive", "diagnose"]
        }
        if failureCode.hasSuffix("_interrupted") {
            return ["diagnose", "observe", "act", "archive"]
        }
        if failureCode.hasSuffix("_conflict") || failureCode.hasSuffix("_required") {
            return ["diagnose", "plan"]
        }
        if failureCode.hasSuffix("_invalid") {
            return ["diagnose", "plan"]
        }
        if failureCode.hasSuffix("_changed") {
            return ["observe", "verify", "archive"]
        }
        if failureCode.hasPrefix("unsupported_") {
            return ["diagnose", "plan"]
        }
        if failureCode.hasPrefix("vlm_") {
            return ["archive", "diagnose", "plan"]
        }
        if failureCode.hasPrefix("mlx_") {
            return ["archive", "diagnose", "plan"]
        }
        if failureCode.hasSuffix("_unsupported") {
            return ["diagnose", "plan"]
        }
        return nil
    }
}

func schemaArtifactTaxonomy() -> Set<String> {
    [
        "app-container",
        "app-map",
        "app-map-viewer-html",
        "app-map.paths",
        "app-map.screens",
        "app-map.suites",
        "app-map.transitions",
        "app-preferences",
        "app.structured-evidence",
        "action-map",
        "ax",
        "build.summary",
        "compile-proposals",
        "compiled-contract",
        "contract-capabilities",
        "coverage-json",
        "coordinate-contract",
        "evidence-bundle",
        "export-archive",
        "geometry",
        "harmony-layout",
        "hierarchy",
        "hierarchy-json",
        "host.app-action",
        "host.layout",
        "host-artifacts",
        "logs",
        "manifest",
        "network-capture",
        "network-fixture",
        "network-map",
        "none-inline-summary",
        "page-map",
        "proxy-restore",
        "result-bundle",
        "real-device.diagnostics",
        "runtime-ledger",
        "runtime.snapshot",
        "runtime-snapshot",
        "screenshot",
        "screenshots",
        "screen-workspace",
        "screen-workspace.screens",
        "screen-workspace.transitions",
        "simulator-diagnostics",
        "simulator-logs",
        "simulator-screenshot",
        "simulator-video",
        "stderr-log",
        "stdout-log",
        "trace",
        "triton-plan",
        "tritontest-yaml",
        "tritontestcase",
        "vlm-compare",
        "vlm-grounding",
        "vlm-model-cache",
        "vlm-model-metadata",
        "vlm-overlay",
        "vlm-parsed-point",
        "vlm-raw-output",
        "vlm-request",
        "vlm-response",
        "vlm-transform",
        "workspace-recovery-proposal",
        "xcode-artifacts",
    ]
}
