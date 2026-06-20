import Testing
import TritonKitShared
@testable import TritonKitCLI

extension SchemaFactSourceTests {
    @Test("execution and evidence schemas expose recovery commands and output contracts")
    func executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts() throws {
        let schemas = commandSchemaMap()
        let find = try #require(schemas["find"])
        let wait = try #require(schemas["wait"])
        let tap = try #require(schemas["tap"])
        let clear = try #require(schemas["clear"])
        let press = try #require(schemas["press"])
        let input = try #require(schemas["input"])
        let assert = try #require(schemas["assert"])
        let evidence = try #require(schemas["evidence"])
        let capture = try #require(schemas["capture"])
        let smoke = try #require(schemas["smoke"])
        let record = try #require(schemas["record"])
        let replay = try #require(schemas["replay"])
        let connectedCapabilityNames = Set(connectedCapabilities().map(\.name))

        #expect(find.failureCodes.contains("text_not_found"))
        #expect(find.failureCodes.contains("ambiguous_target"))
        #expect(find.nextCommands.contains("triton tap <query> --json"))
        #expect(find.nextCommands.contains("triton screenshot --output <path> --metadata"))
        expectContract(find, selector: "target.resolution", fields: [
            "query", "source", "strategy", "request", "matchIndex", "matchCount", "candidates",
        ])

        #expect(wait.failureCodes.contains("timeout"))
        #expect(wait.failureCodes.contains("validation_failed"))
        #expect(wait.nextCommands.contains("triton assert text-exists <text> --json"))
        #expect(wait.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        expectContract(wait, selector: "wait.result", fields: [
            "ok", "matched", "condition", "timedOut", "elapsedMs", "pollCount", "lastObservedTextSample", "match",
        ])
        expectContract(wait, selector: "host.harmony-wait", fields: [
            "ok", "action", "platform", "target", "condition", "query", "matched",
            "timedOut", "elapsedMs", "pollCount", "match", "sourceCommands",
        ])
        #expect(!wait.outputContracts.map(\.selector).contains("host.wait"))

        #expect(tap.failureCodes.contains("text_not_found"))
        #expect(tap.failureCodes.contains("validation_failed"))
        #expect(tap.nextCommands.contains("triton wait --text <text> --json"))
        #expect(tap.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        expectContract(tap, selector: "input.result", fields: [
            "ok", "action", "message", "targetOID", "targetClassName", "matchedOID", "activationOID", "strategy",
        ])
        expectContract(tap, selector: "host.harmony-tap", fields: [
            "ok", "action", "platform", "target", "query", "x", "y", "match",
            "sourceCommands", "note",
        ])
        #expect(!tap.outputContracts.map(\.selector).contains("host.tap"))

        let swipe = try #require(schemas["swipe"])
        expectContract(swipe, selector: "input.result", fields: [
            "ok", "action", "message", "targetOID", "targetClassName",
        ])
        expectContract(swipe, selector: "host.harmony-swipe", fields: [
            "ok", "action", "platform", "target", "startX", "startY", "endX", "endY",
            "velocity", "sourceCommands", "note",
        ])
        #expect(!swipe.outputContracts.map(\.selector).contains("host.swipe"))

        let type = try #require(schemas["type"])
        expectContract(type, selector: "input.result", fields: [
            "ok", "action", "message", "targetOID", "targetClassName",
        ])
        expectContract(type, selector: "host.harmony-text-input", fields: [
            "ok", "action", "platform", "target", "x", "y", "secure", "redacted",
            "insertedLength", "sourceCommands", "note",
        ])
        #expect(!type.outputContracts.map(\.selector).contains("host.text-input"))

        let paste = try #require(schemas["paste"])
        expectContract(paste, selector: "input.result", fields: [
            "ok", "action", "message", "targetOID", "targetClassName",
        ])
        expectContract(paste, selector: "host.harmony-text-input", fields: [
            "ok", "action", "platform", "target", "x", "y", "secure", "redacted",
            "insertedLength", "sourceCommands", "note",
        ])
        #expect(!paste.outputContracts.map(\.selector).contains("host.text-input"))
        #expect(clear.providedCapabilities.contains("clear"))
        #expect(clear.providedCapabilities.contains("harmony-clear-text"))
        #expect(clear.outputContracts.map(\.selector) == ["input.result"])
        expectContract(press, selector: "host.harmony-key-action", fields: [
            "ok", "action", "runtimeScope", "target", "selection", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated",
            "stdout", "stderr", "artifacts", "note",
        ])
        #expect(!press.outputContracts.map(\.selector).contains("host.key-action"))

        #expect(input.failureCodes.contains("validation_failed"))
        #expect(input.failureCodes.contains("request_failed"))
        #expect(input.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        #expect(input.providedCapabilities.contains("input"))
        #expect(input.providedCapabilities.contains("tap"))
        #expect(!input.providedCapabilities.contains("press"))
        expectContract(input, selector: "input.result", fields: [
            "ok", "action", "message", "targetOID", "targetClassName",
        ])
        expectContract(input, selector: "input.summary", fields: [
            "ok", "actionCount", "failedCount",
        ])

        #expect(assert.failureCodes.contains("assertion_failed"))
        #expect(assert.failureCodes.contains("validation_failed"))
        #expect(assert.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        expectContract(assert, selector: "assert.result", fields: [
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

        #expect(capture.failureCodes.contains("validation_failed"))
        #expect(capture.artifacts.contains("evidence-bundle"))
        #expect(capture.nextCommands.contains("triton evidence summary <dir.tritonevidence> --json"))
        #expect(Set(capture.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(capture, selector: "evidence.manifest", fields: [
            "ok", "formatVersion", "output", "artifacts", "primaryArtifact", "primaryArtifacts", "skipped", "target", "cli", "run", "screenWorkspace",
        ])

        #expect(Set(smoke.providedCapabilities).isSubset(of: connectedCapabilityNames))

        #expect(Set(record.providedCapabilities).isSubset(of: connectedCapabilityNames))

        #expect(replay.failureCodes.contains("validation_failed"))
        #expect(replay.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
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
        let runtime = try #require(schemas["runtime"])
        let state = try #require(schemas["state"])
        let snapshot = try #require(schemas["snapshot"])
        let observe = try #require(schemas["observe"])
        let webview = try #require(schemas["webview"])
        let route = try #require(schemas["route"])
        let ax = try #require(schemas["ax"])
        let screenshot = try #require(schemas["screenshot"])

        #expect(runtime.failureCodes.contains("server_unavailable"))
        #expect(runtime.failureCodes.contains("target_unavailable"))
        #expect(runtime.nextCommands.contains("triton capabilities --format json"))
        expectContract(runtime, selector: "runtime.manifest", fields: [
            "ok", "platform", "runtime", "transport", "enabled", "sdkVersion", "buildConfiguration",
            "capabilities", "limits", "redaction",
        ])

        #expect(state.failureCodes.contains("server_unavailable"))
        #expect(state.failureCodes.contains("target_unavailable"))
        #expect(state.nextCommands.contains("triton snapshot --json"))
        expectContract(state, selector: "runtime.state", fields: [
            "ok", "capturedAt", "runtime", "targetConnectionState", "app", "scenes",
            "rootController", "visibleController", "firstResponder", "warnings", "unsupported",
        ])

        #expect(snapshot.failureCodes.contains("server_unavailable"))
        #expect(snapshot.failureCodes.contains("target_unavailable"))
        #expect(snapshot.nextCommands.contains("triton assert text-exists <text> --json"))
        expectContract(snapshot, selector: "runtime.snapshot", fields: [
            "ok", "capturedAt", "runtime", "targetConnectionState", "include", "app", "scene",
            "route", "responder", "geometry", "ax", "screenshot", "artifacts", "skipped", "truncation",
        ])

        #expect(observe.failureCodes.contains("target_not_found"))
        #expect(observe.failureCodes.contains("host_command_failed"))
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

        #expect(ax.failureCodes.contains("server_unavailable"))
        #expect(ax.failureCodes.contains("host_command_failed"))
        expectContract(ax, selector: "host.harmony-artifact", fields: [
            "ok", "action", "platform", "target", "artifact", "sourceCommands", "note",
        ])
        #expect(!ax.outputContracts.map(\.selector).contains("host.artifact"))

        #expect(screenshot.failureCodes.contains("server_unavailable"))
        #expect(screenshot.failureCodes.contains("artifact_write_failed"))
        #expect(screenshot.artifacts.contains("screenshot"))
        #expect(screenshot.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        expectContract(screenshot, selector: "screenshot.metadata", fields: [
            "format", "width", "height", "scale", "output", "bytes",
        ])
        expectContract(screenshot, selector: "host.harmony-artifact", fields: [
            "ok", "action", "platform", "target", "artifact", "sourceCommands", "note",
        ])
        #expect(!screenshot.outputContracts.map(\.selector).contains("host.artifact"))
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
        let hierarchy = try #require(schemas["hierarchy"])
        let nodes = try #require(schemas["nodes"])
        let node = try #require(schemas["node"])
        let attrs = try #require(schemas["attrs"])
        let object = try #require(schemas["object"])
        let export = try #require(schemas["export"])
        let geometry = try #require(schemas["geometry"])
        let hit = try #require(schemas["hit"])
        let focus = try #require(schemas["focus"])
        let setText = try #require(schemas["set-text"])
        let selectSegment = try #require(schemas["select-segment"])
        let setSwitch = try #require(schemas["set-switch"])
        let ledger = try #require(schemas["ledger"])

        #expect(list.failureCodes.contains("server_unavailable"))
        #expect(list.nextCommands.contains("triton inspect --target <id> --json"))
        expectContract(list, selector: "targets.list", fields: ["targets"])

        #expect(inspect.failureCodes.contains("target_not_found"))
        #expect(inspect.nextCommands.contains("triton hierarchy --target <id> --json"))
        expectContract(inspect, selector: "target.summary", fields: [
            "id", "transport", "connected", "latestHierarchyAvailable",
            "appName", "bundleIdentifier", "deviceDescription", "osDescription",
        ])

        #expect(hierarchy.failureCodes.contains("hierarchy_unavailable"))
        #expect(hierarchy.artifacts.contains("hierarchy-json"))
        #expect(hierarchy.nextCommands.contains("triton nodes --json"))
        expectContract(hierarchy, selector: "hierarchy.info", fields: [
            "displayItems", "appInfo", "serverVersion", "colorAlias", "collapsedClassList",
        ])
        expectContract(hierarchy, selector: "hierarchy.scene", fields: [
            "platform", "rootId", "viewport", "nodes", "style", "slice", "view", "layer", "visualSources", "raw", "renderHints",
        ])

        #expect(nodes.failureCodes.contains("hierarchy_unavailable"))
        #expect(nodes.nextCommands.contains("triton node --oid <oid> --json"))
        expectContract(nodes, selector: "hierarchy.nodes", fields: ["nodes"])

        #expect(node.failureCodes.contains("node_not_found"))
        #expect(node.failureCodes.contains("ambiguous_target"))
        #expect(node.nextCommands.contains("triton attrs --oid <layerOid> --json"))
        expectContract(node, selector: "hierarchy.node", fields: [
            "oid", "viewOid", "layerOid", "className", "depth", "frame", "hidden", "alpha",
        ])
        expectContract(node, selector: "node.resolve", fields: [
            "ok", "action", "platform", "query", "matchIndex", "matchCount", "node", "candidates",
        ])

        #expect(attrs.failureCodes.contains("node_not_found"))
        #expect(attrs.nextCommands.contains("triton object --oid <oid> --json"))
        expectContract(attrs, selector: "node.attributes", fields: [
            "identifier", "userCustomTitle", "attrSections",
        ])

        #expect(object.failureCodes.contains("node_not_found"))
        #expect(object.nextCommands.contains("triton attrs --oid <oid> --json"))
        expectContract(object, selector: "node.object", fields: [
            "oid", "memoryAddress", "classChainList", "specialTrace", "ivarTraces",
        ])

        #expect(export.failureCodes.contains("artifact_write_failed"))
        #expect(export.artifacts.contains("hierarchy-json"))
        #expect(export.artifacts.contains("export-archive"))
        #expect(export.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        expectContract(export, selector: "export.archive", fields: [
            "schemaVersion", "exportedAt", "target", "hierarchy", "geometry", "accessibility", "screenshot",
        ])

        #expect(geometry.failureCodes.contains("runtime_unavailable"))
        #expect(geometry.nextCommands.contains("triton hit --at <x,y> --json"))
        expectContract(geometry, selector: "geometry.current", fields: [
            "bounds", "safeArea", "scale", "orientation",
        ])

        #expect(hit.failureCodes.contains("validation_failed"))
        #expect(hit.nextCommands.contains("triton tap <query> --at <x,y> --json"))
        expectContract(hit, selector: "hit.result", fields: [
            "x", "y", "node", "centerX", "centerY",
        ])

        for schema in [focus, setText, selectSegment, setSwitch] {
            #expect(schema.failureCodes.contains("target_not_found"))
            #expect(schema.failureCodes.contains("validation_failed"))
            #expect(schema.nextCommands.contains("triton ledger --limit 20 --json"))
            expectContract(schema, selector: "semantic.action", fields: [
                "ok", "action", "strategy", "targetOID", "targetClassName", "elapsedMs", "message", "error", "redaction",
            ])
        }

        #expect(ledger.failureCodes.contains("runtime_unavailable"))
        #expect(ledger.artifacts.contains("runtime-ledger"))
        #expect(ledger.nextCommands.contains("triton evidence --output <dir.tritonevidence> --json"))
        expectContract(ledger, selector: "runtime.ledger", fields: [
            "ok", "entries", "limit", "count", "maxEntries",
        ])
        expectContract(ledger, selector: "runtime.ledger-entry", fields: [
            "id", "timestamp", "source", "requestType", "action", "ok", "elapsedMs", "errorCode",
        ])
    }
}
