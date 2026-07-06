import Testing
import TritonKitShared
@testable import TritonKitCLI

extension SchemaFactSourceTests {
    @Test("execution and evidence schemas expose recovery commands and output contracts")
    func executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts() throws {
        let schemas = commandSchemaMap()
        let act = try #require(schemas["act"])
        let wait = try #require(schemas["wait"])
        let verify = try #require(schemas["verify"])
        let evidence = try #require(schemas["evidence"])
        let smoke = try #require(schemas["smoke"])
        let record = try #require(schemas["record"])
        let replay = try #require(schemas["replay"])
        let connectedCapabilityNames = Set(connectedCapabilities().map(\.name))

        #expect(act.failureCodes.contains("text_not_found"))
        #expect(act.failureCodes.contains("validation_failed"))
        #expect(act.failureCodes.contains("semantic_action_failed"))
        #expect(act.failureCodes.contains("ios_host_ax_action_unavailable"))
        #expect(act.subcommands.map(\.name).contains("find"))
        #expect(act.subcommands.map(\.name).contains("tap"))
        #expect(act.subcommands.map(\.name).contains("type"))
        #expect(act.subcommands.map(\.name).contains("input"))
        #expect(act.nextCommands.contains("triton verify text-exists <text> --json"))
        #expect(act.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        expectContract(act, selector: "target.resolution", fields: [
            "query", "source", "strategy", "request", "matchIndex", "matchCount", "candidates",
        ])
        expectContract(act, selector: "input.result", fields: [
            "ok", "action", "message", "targetOID", "targetClassName",
        ])
        expectContract(act, selector: "input.summary", fields: [
            "ok", "actionCount", "failedCount",
        ])
        expectContract(act, selector: "host.ios-tap", fields: [
            "ok", "action", "platform", "target", "query", "x", "y", "match",
            "sourceCommands", "note",
        ])
        expectContract(act, selector: "host.harmony-tap", fields: [
            "ok", "action", "platform", "target", "query", "x", "y", "match",
            "sourceCommands", "note",
        ])
        expectContract(act, selector: "host.harmony-swipe", fields: [
            "ok", "action", "platform", "target", "startX", "startY", "endX", "endY",
            "velocity", "sourceCommands", "note",
        ])
        expectContract(act, selector: "host.harmony-text-input", fields: [
            "ok", "action", "platform", "target", "x", "y", "secure", "redacted",
            "insertedLength", "sourceCommands", "note",
        ])
        expectContract(act, selector: "host.harmony-key-action", fields: [
            "ok", "action", "runtimeScope", "target", "selection", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated",
            "stdout", "stderr", "artifacts", "note",
        ])
        expectContract(act, selector: "semantic.action", fields: [
            "ok", "action", "strategy", "targetOID", "targetClassName", "elapsedMs", "message", "error", "redaction",
        ])

        #expect(wait.failureCodes.contains("timeout"))
        #expect(wait.failureCodes.contains("validation_failed"))
        #expect(wait.nextCommands.contains("triton verify text-exists <text> --json"))
        #expect(wait.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        expectContract(wait, selector: "wait.result", fields: [
            "ok", "matched", "condition", "timedOut", "elapsedMs", "pollCount", "lastObservedTextSample", "match",
        ])
        expectContract(wait, selector: "host.harmony-wait", fields: [
            "ok", "action", "platform", "target", "condition", "query", "matched",
            "timedOut", "elapsedMs", "pollCount", "match", "sourceCommands",
        ])
        #expect(!wait.outputContracts.map(\.selector).contains("host.wait"))

        #expect(verify.failureCodes.contains("assertion_failed"))
        #expect(verify.failureCodes.contains("validation_failed"))
        #expect(verify.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        #expect(verify.subcommands.map(\.name).contains("text-exists"))
        #expect(verify.subcommands.map(\.name).contains("text-not-exists"))
        expectContract(verify, selector: "assert.result", fields: [
            "ok", "condition", "query", "count", "matches", "sample", "nearestText", "suggestedCommands",
        ])

        #expect(evidence.failureCodes.contains("validation_failed"))
        #expect(evidence.artifacts.contains("evidence-bundle"))
        #expect(evidence.artifacts.contains("screen-workspace"))
        #expect(evidence.nextCommands.contains("triton evidence summary <dir.tritonevidence> --json"))
        #expect(evidence.nextCommands.contains("triton evidence project-screens <dir.tritonevidence> --json"))
        #expect(Set(evidence.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(evidence, selector: "evidence.manifest", fields: [
            "ok", "formatVersion", "output", "artifacts", "primaryArtifact", "primaryArtifacts", "skipped", "target", "cli", "run", "screenWorkspace",
        ])
        expectContract(evidence, selector: "evidence.summary", fields: [
            "ok", "action", "input", "profile", "output", "artifactCount", "sensitiveArtifactCount", "artifacts", "primaryArtifact", "primaryArtifacts", "screenWorkspace", "suggestedCommands",
        ])
        expectContract(evidence, selector: "evidence.redact", fields: [
            "ok", "action", "input", "output", "profile", "artifactCount", "redactedArtifactCount", "manifest", "primaryArtifact", "primaryArtifacts", "summaryPath", "suggestedCommands",
        ])
        expectContract(evidence, selector: "evidence.screen-workspace-projection", fields: [
            "ok", "evidenceDir", "screensRef", "transitionsRef", "screenCount", "transitionCount", "warningCount", "warnings", "error",
        ])

        #expect(Set(smoke.providedCapabilities).isSubset(of: connectedCapabilityNames))

        #expect(Set(record.providedCapabilities).isSubset(of: connectedCapabilityNames))

        #expect(replay.failureCodes.contains("validation_failed"))
        #expect(replay.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        #expect(replay.nextCommands.contains("triton plan inspect <path.tritonplan> --json"))
        #expect(replay.providedCapabilities.contains("replay-dry-run"))
        #expect(Set(replay.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(replay, selector: "replay.result", fields: [
            "ok", "dryRun", "planName", "stepCount", "executedCount", "failedStepIndex", "failureCode", "failureError",
            "failurePrimaryWorkflowCategory",
            "failureError.code", "failureError.message", "failureError.endpoint", "failureError.hint",
            "failureError.nearestCandidates", "failureError.suggestedCommands", "failureError.candidateCount",
            "failureError.nextAction", "failureError.nextAction.command", "failureError.nextAction.args",
            "failureError.nextAction.category",
            "failureError.nextAction.requiresLongRunningProcess",
            "failureWorkflowCategories", "failurePrimaryRecoveryCategory", "failureRecoveryCategories",
            "failurePrimaryHint",
            "failurePrimaryEndpoint",
            "failurePrimaryNextAction", "failurePrimaryNextAction.command", "failurePrimaryNextAction.args",
            "failurePrimaryNextAction.category", "failurePrimaryNextAction.requiresLongRunningProcess",
            "failurePrimaryArtifact", "failurePrimaryArtifacts",
            "failurePrimarySuggestedCommand",
            "failurePrimaryRecoveryCommand", "failurePrimaryRecoveryCommand.command", "failurePrimaryRecoveryCommand.category",
            "recoveryCommands", "recoveryCommands[].command", "recoveryCommands[].category",
            "elapsedMs", "steps", "suggestedCommands",
            "steps[].index", "steps[].action", "steps[].command", "steps[].argv", "steps[].category",
            "steps[].requires", "steps[].expectedArtifacts", "steps[].stopConditions", "steps[].failureCode", "steps[].error",
            "steps[].error.code", "steps[].error.message", "steps[].error.endpoint", "steps[].error.hint",
            "steps[].error.nearestCandidates", "steps[].error.suggestedCommands", "steps[].error.candidateCount",
            "steps[].error.nextAction", "steps[].error.nextAction.command", "steps[].error.nextAction.args",
            "steps[].error.nextAction.category",
            "steps[].error.nextAction.requiresLongRunningProcess",
        ])
    }

    @Test("observation and runtime schemas expose diagnostic contracts")
    func observationAndRuntimeSchemasExposeDiagnosticContracts() throws {
        let schemas = commandSchemaMap()
        let debug = try #require(schemas["debug"])
        let observe = try #require(schemas["observe"])
        let webview = try #require(schemas["webview"])
        let route = try #require(schemas["route"])
        let screenshot = try #require(schemas["screenshot"])

        #expect(debug.failureCodes.contains("server_unavailable"))
        #expect(debug.failureCodes.contains("target_unavailable"))
        #expect(debug.subcommands.map(\.name).contains("runtime"))
        #expect(debug.subcommands.map(\.name).contains("snapshot"))
        #expect(debug.subcommands.map(\.name).contains("ax"))
        expectContract(debug, selector: "runtime.manifest", fields: [
            "ok", "platform", "runtime", "transport", "enabled", "sdkVersion", "buildConfiguration",
            "capabilities", "limits", "redaction",
        ])

        expectContract(debug, selector: "runtime.state", fields: [
            "ok", "capturedAt", "runtime", "targetConnectionState", "app", "scenes",
            "rootController", "visibleController", "firstResponder", "warnings", "unsupported",
        ])

        expectContract(debug, selector: "runtime.snapshot", fields: [
            "ok", "capturedAt", "runtime", "targetConnectionState", "include", "app", "scene",
            "route", "responder", "geometry", "ax", "screenshot", "artifacts", "skipped", "truncation",
        ])
        expectContract(debug, selector: "ax.nodes", fields: [
            "role", "label", "value", "identifier", "title", "frame", "enabled", "focused",
        ])

        #expect(observe.failureCodes.contains("target_not_found"))
        #expect(observe.failureCodes.contains("host_command_failed"))
        #expect(observe.failureCodes.contains("ios_host_ax_unavailable"))
        #expect(observe.failureCodes.contains("ios_host_ax_tree_unavailable"))
        #expect(observe.providedCapabilities.contains("observe-ios-host-ax"))
        #expect(observe.nextCommands.contains("triton webview current --json"))
        expectContract(observe, selector: "observe.surface", fields: [
            "ok", "action", "platform", "capturedAt", "partial", "target", "primarySource",
            "primarySource.name", "primarySource.available", "primarySource.reason", "primarySource.artifact", "primarySource.sourceCommands", "sources",
            "nodes", "artifacts", "sourceCommands", "note",
        ])

        #expect(webview.failureCodes.contains("webview_not_found"))
        #expect(webview.failureCodes.contains("webview_wait_timeout"))
        #expect(webview.nextCommands.contains("triton route assert-current-url <url> --json"))
        let connectedCapabilityNames = Set(connectedCapabilities().map(\.name))
        #expect(Set(webview.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(webview, selector: "webview.list", fields: [
            "ok", "action", "platform", "capturedAt", "target", "current", "candidates",
            "primarySource", "primarySource.name", "primarySource.available", "primarySource.reason",
            "primarySource.sourceCommands", "sources", "sourceCommands", "note",
        ])
        expectContract(webview, selector: "webview.current", fields: [
            "ok", "action", "platform", "capturedAt", "target", "webView",
            "primarySource", "primarySource.name", "primarySource.available", "primarySource.reason",
            "primarySource.sourceCommands", "sources", "sourceCommands", "note",
        ])
        expectContract(webview, selector: "webview.current-url", fields: [
            "ok", "action", "platform", "capturedAt", "target", "webViewID", "url",
            "title", "pageSessionID", "providerStatus", "bridgeStatus", "sourceCommands",
        ])
        expectContract(webview, selector: "webview.call", fields: [
            "ok", "action", "capturedAt", "platform", "target", "webViewID",
            "pageSessionID", "method", "result", "error", "elapsedMs", "redaction",
        ])
        expectContract(webview, selector: "webview.events", fields: [
            "ok", "action", "capturedAt", "platform", "target", "events", "limit",
            "events[].id", "events[].timestamp", "events[].webViewID", "events[].pageSessionID",
            "events[].name", "events[].payload", "events[].redaction", "events[].source",
        ])
        expectContract(webview, selector: "webview.snapshot", fields: [
            "ok", "action", "capturedAt", "platform", "target", "webView", "include",
            "text", "dom", "forms", "links", "skipped", "truncation", "redaction",
        ])
        expectContract(webview, selector: "webview.wait", fields: [
            "ok", "action", "capturedAt", "platform", "target", "webView", "candidates",
            "condition", "query", "matched", "timedOut", "elapsedMs", "pollCount",
            "lastObservedTextSample", "lastObservedNodeIDs", "lastObservedEventNames", "match", "error",
        ])

        #expect(route.failureCodes.contains("route_mismatch"))
        #expect(route.failureCodes.contains("webview_provider_unavailable"))
        #expect(route.nextCommands.contains("triton webview current-url --json"))
        #expect(Set(route.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(route, selector: "route.current-url-assert", fields: [
            "ok", "action", "status", "expectedURL", "actualURL", "matched", "ignoreQuery",
            "platform", "target", "webViewID", "title", "pageSessionID", "hint",
        ])

        #expect(screenshot.failureCodes.contains("server_unavailable"))
        #expect(screenshot.failureCodes.contains("artifact_write_failed"))
        #expect(screenshot.artifacts.contains("screenshot"))
        #expect(screenshot.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        expectContract(screenshot, selector: "screenshot.metadata", fields: [
            "format", "width", "height", "scale", "output", "bytes",
        ])
        expectContract(screenshot, selector: "host.harmony-artifact", fields: [
            "ok", "action", "platform", "target", "artifact", "sourceCommands", "note",
        ])
        expectContract(screenshot, selector: "host.artifact", fields: [
            "ok", "action", "platform", "target", "selection", "artifact", "format",
            "bytes", "width", "height", "sha256", "capturedAt", "sourceCommands", "note",
        ])
    }

    @Test("host workflow schemas expose target and artifact contracts")
    func hostWorkflowSchemasExposeTargetAndArtifactContracts() throws {
        let schemas = commandSchemaMap()
        let device = try #require(schemas["device"])
        let sim = try #require(schemas["sim"])
        let app = try #require(schemas["app"])
        let smoke = try #require(schemas["smoke"])
        let record = try #require(schemas["record"])

        #expect(device.failureCodes.contains("ambiguous_target"))
        #expect(device.failureCodes.contains("device_not_ready"))
        #expect(device.nextCommands.contains("triton device resolve --device <selector> --json"))
        expectContract(device, selector: "host.device-list", fields: [
            "ok", "platform", "targets", "defaultTarget", "sourceCommand",
        ])
        expectContract(device, selector: "host.device-selection", fields: [
            "ok", "platform", "target", "defaultsPath", "selection",
        ])
        expectContract(device, selector: "host.device-ready", fields: [
            "ok", "platform", "target", "ready", "attempt", "sourceCommand", "error",
        ])

        #expect(sim.failureCodes.contains("simulator_not_found"))
        #expect(sim.failureCodes.contains("host_command_failed"))
        #expect(sim.providedCapabilities.contains("ios-host-ax"))
        #expect(sim.artifacts.contains("simulator-screenshot"))
        #expect(sim.nextCommands.contains("triton sim use <udid> --json"))
        expectContract(sim, selector: "host.simulator-list", fields: [
            "ok", "simulators",
        ])
        expectContract(sim, selector: "host.simulator-screenshot", fields: [
            "ok", "action", "runtimeScope", "target", "tool", "exitCode", "riskLevel",
            "sourceCommand", "stdoutTruncated", "stderrTruncated", "stderr", "artifact",
            "pixelWidth", "pixelHeight", "display", "display.rawLine", "display.displayID",
            "display.screenID", "display.name", "orientationPolicy", "orientationNote", "note",
        ])
        expectContract(sim, selector: "host.simulator-action", fields: [
            "ok", "action", "runtimeScope", "target", "tool", "exitCode", "riskLevel",
            "sourceCommand", "stdoutTruncated", "stderrTruncated", "artifacts", "screenshot", "note",
        ])

        #expect(app.failureCodes.contains("app_launch_failed"))
        #expect(app.failureCodes.contains("host_open_url_failed"))
        #expect(app.nextCommands.contains("triton app go <url>"))
        expectContract(app, selector: "host.app-action", fields: [
            "ok", "action", "runtimeScope", "target", "selection", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated", "artifacts", "note",
            "hostAction", "hostAction.ok", "hostAction.proofSource", "hostAction.businessReady",
            "hostAction.nextAction", "hostAction.nextAction.command", "hostAction.nextAction.args",
            "hostAction.nextAction.category", "hostAction.nextAction.requiresLongRunningProcess",
        ])
        expectContract(app, selector: "host.app-open-url", fields: [
            "ok", "status", "hostAction", "ready", "snapshot",
        ])

        #expect(smoke.failureCodes.contains("smoke_failed"))
        #expect(smoke.failureCodes.contains("target_not_found"))
        #expect(smoke.artifacts.contains("evidence-bundle"))
        #expect(smoke.nextCommands.contains("triton evidence summary <dir.tritonevidence> --json"))
        expectContract(smoke, selector: "smoke.result", fields: [
            "ok", "action", "platform", "status", "target", "steps", "assertions",
            "artifacts", "evidence", "failure", "startedAt", "endedAt", "elapsedMs",
        ])

        #expect(record.failureCodes.contains("validation_failed"))
        #expect(record.artifacts.contains("triton-plan"))
        #expect(record.nextCommands.contains("triton plan inspect <path.tritonplan> --json"))
        expectContract(record, selector: "record.plan", fields: [
            "ok", "output", "templateOnly", "message", "plan",
        ])
    }

    @Test("low-level runtime schemas expose inspection and action contracts")
    func lowLevelRuntimeSchemasExposeInspectionAndActionContracts() throws {
        let schemas = commandSchemaMap()
        let list = try #require(schemas["list"])
        let inspect = try #require(schemas["inspect"])
        let debug = try #require(schemas["debug"])
        let export = try #require(schemas["export"])
        let act = try #require(schemas["act"])

        #expect(list.failureCodes.contains("server_unavailable"))
        #expect(list.nextCommands.contains("triton inspect --target <id> --json"))
        expectContract(list, selector: "targets.list", fields: ["targets"])

        #expect(inspect.failureCodes.contains("target_not_found"))
        #expect(inspect.nextCommands.contains("triton debug hierarchy --target <id> --json"))
        expectContract(inspect, selector: "target.summary", fields: [
            "id", "transport", "connected", "latestHierarchyAvailable",
            "appName", "bundleIdentifier", "deviceDescription", "osDescription",
        ])

        #expect(debug.failureCodes.contains("hierarchy_unavailable"))
        #expect(debug.subcommands.map(\.name).contains("hierarchy"))
        #expect(debug.subcommands.map(\.name).contains("nodes"))
        #expect(debug.subcommands.map(\.name).contains("hit"))
        #expect(debug.subcommands.map(\.name).contains("ledger"))
        expectContract(debug, selector: "hierarchy.info", fields: [
            "displayItems", "appInfo", "serverVersion", "colorAlias", "collapsedClassList",
        ])
        expectContract(debug, selector: "hierarchy.scene", fields: [
            "platform", "rootId", "viewport", "nodes", "style", "slice", "view", "layer", "visualSources", "raw", "renderHints",
        ])

        expectContract(debug, selector: "hierarchy.nodes", fields: ["nodes"])

        expectContract(debug, selector: "hierarchy.node", fields: [
            "oid", "viewOid", "layerOid", "className", "depth", "frame", "hidden", "alpha",
        ])
        expectContract(debug, selector: "node.resolve", fields: [
            "ok", "action", "platform", "query", "matchIndex", "matchCount", "node", "candidates",
        ])

        expectContract(debug, selector: "node.attributes", fields: [
            "identifier", "userCustomTitle", "attrSections",
        ])

        expectContract(debug, selector: "node.object", fields: [
            "oid", "memoryAddress", "classChainList", "specialTrace", "ivarTraces",
        ])

        #expect(export.failureCodes.contains("artifact_write_failed"))
        #expect(export.artifacts.contains("hierarchy-json"))
        #expect(export.artifacts.contains("export-archive"))
        #expect(export.nextCommands.contains("triton evidence capture --case <case> --output <dir.tritonevidence> --json"))
        expectContract(export, selector: "export.archive", fields: [
            "schemaVersion", "exportedAt", "target", "hierarchy", "geometry", "accessibility", "screenshot",
        ])

        expectContract(debug, selector: "geometry.current", fields: [
            "bounds", "safeArea", "scale", "orientation",
        ])

        expectContract(debug, selector: "hit.result", fields: [
            "x", "y", "node", "centerX", "centerY",
        ])

        #expect(act.subcommands.map(\.name).contains("focus"))
        #expect(act.subcommands.map(\.name).contains("set-text"))
        #expect(act.subcommands.map(\.name).contains("select-segment"))
        #expect(act.subcommands.map(\.name).contains("set-switch"))
        expectContract(act, selector: "semantic.action", fields: [
            "ok", "action", "strategy", "targetOID", "targetClassName", "elapsedMs", "message", "error", "redaction",
        ])

        expectContract(debug, selector: "runtime.ledger", fields: [
            "ok", "entries", "limit", "count", "maxEntries",
        ])
        expectContract(debug, selector: "runtime.ledger-entry", fields: [
            "id", "timestamp", "source", "requestType", "action", "ok", "elapsedMs", "errorCode",
        ])
    }
}
