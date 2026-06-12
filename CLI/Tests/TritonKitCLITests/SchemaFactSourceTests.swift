import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite
struct SchemaFactSourceTests {
    @Test("agent bootstrap schemas expose recovery commands and output contracts")
    func agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts() throws {
        let schemas = commandSchemaMap()
        let status = try #require(schemas["status"])
        let doctor = try #require(schemas["doctor"])
        let capabilities = try #require(schemas["capabilities"])
        let plan = try #require(schemas["plan"])
        let schema = try #require(schemas["schema"])

        #expect(status.failureCodes.contains("server_unavailable"))
        #expect(status.failureCodes.contains("request_failed"))
        #expect(status.nextCommands.contains("triton serve --host 127.0.0.1 --port 19421"))
        #expect(status.nextCommands.contains("triton doctor --format json"))
        expectContract(status, selector: "status", fields: [
            "ok", "serverReachable", "connected", "targetCount", "runtime", "surface",
            "activeHierarchyAvailable", "hierarchyCacheState", "targetConnectionState",
        ])

        #expect(doctor.failureCodes.contains("server_unavailable"))
        #expect(doctor.failureCodes.contains("target_unavailable"))
        #expect(doctor.nextCommands.contains("triton capabilities --format json"))
        #expect(doctor.nextCommands.contains("triton plan --format json"))
        expectContract(doctor, selector: "doctor", fields: [
            "ok", "serverReachable", "connected", "runtime", "surface", "nextStep", "nextWorkflows", "primaryCapability", "primaryWorkflowCategory", "primaryNextAction", "primaryNextActionSource",
            "primaryNextAction.command", "primaryNextAction.args", "primaryNextAction.category", "primaryNextAction.requiresLongRunningProcess", "checks",
            "checks[].id", "checks[].status", "checks[].code", "checks[].message",
            "checks[].hint", "checks[].nextAction", "checks[].nextAction.command",
            "checks[].nextAction.args", "checks[].nextAction.category",
            "checks[].nextAction.requiresLongRunningProcess",
            "checks[].relatedCapabilities", "checks[].workflowCategories", "error",
        ])

        #expect(capabilities.failureCodes.contains("server_unavailable"))
        #expect(capabilities.failureCodes.contains("target_unavailable"))
        #expect(capabilities.nextCommands.contains("triton schema --json"))
        #expect(capabilities.nextCommands.contains("triton plan --format json"))
        expectContract(capabilities, selector: "capabilities", fields: [
            "ok", "serverReachable", "connected", "targetCount", "runtime", "surface", "capabilities", "primaryCapability", "primaryWorkflowCategory", "primaryEvidence", "primaryNextAction", "primaryNextActionSource",
            "primaryNextAction.command", "primaryNextAction.args", "primaryNextAction.category", "primaryNextAction.requiresLongRunningProcess",
            "capabilities[].name", "capabilities[].supported", "capabilities[].reason",
            "capabilities[].group", "capabilities[].requiredBy", "capabilities[].nextAction",
            "capabilities[].nextAction.command", "capabilities[].nextAction.args",
            "capabilities[].nextAction.category", "capabilities[].nextAction.requiresLongRunningProcess",
            "capabilities[].evidence", "error",
        ])

        #expect(plan.failureCodes.contains("server_unavailable"))
        #expect(plan.failureCodes.contains("target_unavailable"))
        #expect(plan.nextCommands.contains("triton doctor --format json"))
        #expect(plan.nextCommands.contains("triton schema --json"))
        #expect(plan.providedCapabilities.contains("plan"))
        #expect(plan.providedCapabilities.contains("plan-inspect"))
        #expect(plan.outputSemantics?.contains("Triton-first fallback gate") == true)
        #expect(plan.outputSemantics?.contains("missing-schema evidence") == true)
        #expect(plan.usageForms.contains(where: { $0.form == "ios-smoke" }))
        #expect(plan.usageForms.contains(where: { $0.form == "open-url" }))
        #expect(plan.usageForms.contains(where: { $0.form == "webview-check" }))
        expectContract(plan, selector: "plan.next-steps", fields: [
            "ok", "serverReachable", "connected", "runtime", "surface", "mode", "goal", "nextStep", "nextWorkflows", "primaryWorkflowCategory", "primaryExpectedArtifact", "primaryNextAction", "primaryNextActionSource",
            "primaryNextAction.command", "primaryNextAction.args", "primaryNextAction.category", "primaryNextAction.requiresLongRunningProcess", "steps", "error",
            "steps[].id", "steps[].command", "steps[].argv", "steps[].category", "steps[].workflowCategories", "steps[].requires",
            "steps[].expectedArtifacts", "steps[].stopConditions",
            "afterRecoverySteps", "afterRecoverySteps[].id", "afterRecoverySteps[].command", "afterRecoverySteps[].argv",
            "afterRecoverySteps[].category", "afterRecoverySteps[].workflowCategories", "afterRecoverySteps[].requires",
            "afterRecoverySteps[].expectedArtifacts", "afterRecoverySteps[].stopConditions",
        ])
        expectContract(plan, selector: "plan.inspect", fields: [
            "ok", "path", "schemaVersion", "name", "variables", "stepCount", "actions", "target", "steps",
            "steps[].index", "steps[].action", "steps[].command", "steps[].argv", "steps[].category", "steps[].workflowCategories",
            "steps[].requires", "steps[].expectedArtifacts", "steps[].stopConditions", "steps[].validationErrors",
        ])

        #expect(schema.nextCommands.contains("triton schema --command <command> --json"))
        expectContract(schema, selector: "schema.commands", fields: [
            "schemaVersion", "commands",
        ])
    }

    @Test("doctor response exposes ordered recovery checks")
    func doctorResponseExposesOrderedRecoveryChecks() throws {
        let unavailable = buildDoctorResponse(
            capabilities: TKCapabilitiesResponse(
                ok: false,
                serverReachable: false,
                connected: false,
                latestHierarchyAvailable: false,
                targetCount: 0,
                runtime: "unknown",
                capabilities: runtimeCapabilities(host: "127.0.0.1", port: 19421, serverReachable: false, connected: false),
                error: TKCLIErrorDetail(code: "server_unavailable", message: "No server")
            ),
            host: "127.0.0.1",
            port: 19421
        )

        #expect(!unavailable.ok)
        #expect(unavailable.surface == "doctor")
        #expect(unavailable.nextStep == "start-server")
        #expect(unavailable.nextWorkflows.contains("app"))
        #expect(unavailable.nextWorkflows.contains("observe"))
        #expect(unavailable.primaryCapability == "status")
        #expect(unavailable.primaryWorkflowCategory == "app")
        #expect(unavailable.primaryNextAction?.command == "serve")
        #expect(unavailable.primaryNextActionSource == "next-step-check")
        #expect(unavailable.checks.first?.code == "server_unavailable")
        #expect(unavailable.checks.first?.nextAction?.command == "serve")
        #expect(unavailable.checks.first?.nextAction?.category == "diagnose")
        #expect(unavailable.checks.first?.nextAction?.requiresLongRunningProcess == true)
        #expect(unavailable.checks.first?.relatedCapabilities.contains("status") == true)
        #expect(unavailable.checks.first?.workflowCategories.contains("app") == true)

        let connected = buildDoctorResponse(
            capabilities: TKCapabilitiesResponse(
                ok: true,
                serverReachable: true,
                connected: true,
                latestHierarchyAvailable: true,
                targetCount: 1,
                runtime: "embedded",
                capabilities: runtimeCapabilities(host: "127.0.0.1", port: 19421, serverReachable: true, connected: true)
            ),
            host: "127.0.0.1",
            port: 19421
        )

        #expect(connected.nextStep == "action-surface")
        #expect(connected.surface == "doctor")
        #expect(connected.nextWorkflows == ["action", "assert", "evidence"])
        #expect(connected.primaryCapability == "press")
        #expect(connected.primaryWorkflowCategory == "action")
        #expect(connected.primaryNextAction?.command == "capabilities")
        #expect(connected.primaryNextActionSource == "next-step-check")
        #expect(connected.checks.map(\.id).contains("server"))
        #expect(connected.checks.map(\.id).contains("target"))
        #expect(connected.checks.map(\.id).contains("runtime"))
        #expect(connected.checks.first(where: { $0.id == "action-surface" })?.status == "warn")
        #expect(connected.checks.first(where: { $0.id == "action-surface" })?.relatedCapabilities == ["press"])
        #expect(connected.checks.first(where: { $0.id == "action-surface" })?.workflowCategories == ["action", "assert", "evidence"])
    }

    @Test("target schemas expose discovery and readiness contracts")
    func targetSchemasExposeDiscoveryAndReadinessContracts() throws {
        let schemas = commandSchemaMap()
        let target = try #require(schemas["target"])

        #expect(target.failureCodes.contains("ambiguous_target"))
        #expect(target.failureCodes.contains("target_not_found"))
        #expect(target.nextCommands.contains("triton target resolve <selector> --json"))
        #expect(target.nextCommands.contains("triton target use <selector> --json"))
        #expect(target.nextCommands.contains("triton target wait-ready <selector> --json"))
        expectContract(target, selector: "host.device-list", fields: [
            "ok", "platform", "targets",
            "targets[].appName", "targets[].bundleIdentifier", "targets[].identityState", "targets[].current",
            "defaultTarget", "sourceCommand",
        ])
        expectContract(target, selector: "host.device-selection", fields: [
            "ok", "platform", "current", "target", "defaultsPath", "selection", "path",
        ])
        expectContract(target, selector: "host.device-ready", fields: [
            "ok", "platform", "target", "ready", "attempt", "sourceCommand", "error",
        ])
    }

    @Test("capabilities matrix exposes groups dependencies recovery and evidence")
    func capabilitiesMatrixExposesGroupsDependenciesRecoveryAndEvidence() throws {
        let disconnected = Dictionary(uniqueKeysWithValues: runtimeCapabilities(
            host: "127.0.0.1",
            port: 19421,
            serverReachable: true,
            connected: false
        ).map { ($0.name, $0) })
        let unavailableServer = Dictionary(uniqueKeysWithValues: runtimeCapabilities(
            host: "127.0.0.1",
            port: 19421,
            serverReachable: false,
            connected: false
        ).map { ($0.name, $0) })
        let connected = connectedCapabilityMap()

        let targetList = try #require(disconnected["target-list"])
        #expect(targetList.supported)
        #expect(targetList.group == "target")
        #expect(targetList.requiredBy.contains("smoke"))
        #expect(targetList.nextAction?.command == "target")
        #expect(targetList.nextAction?.args == ["list", "--json"])
        #expect(targetList.evidence.contains("host-targets.json"))

        let disconnectedFixture = TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "none",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: true,
                connected: false
            )
        )
        #expect(disconnectedFixture.primaryCapability == "runtime-manifest")
        #expect(disconnectedFixture.primaryWorkflowCategory == "app")
        #expect(disconnectedFixture.primaryEvidence == "runtime-manifest")
        #expect(disconnectedFixture.primaryNextAction?.command == "status")
        #expect(disconnectedFixture.primaryNextActionSource == "unsupported-capability")

        let runtimeManifest = try #require(disconnected["runtime-manifest"])
        #expect(!runtimeManifest.supported)
        #expect(runtimeManifest.group == "runtime")
        #expect(runtimeManifest.requiredBy.contains("app"))
        #expect(runtimeManifest.nextAction?.command == "status")
        #expect(runtimeManifest.nextAction?.args == ["--json"])
        #expect(runtimeManifest.evidence.contains("runtime-manifest"))

        let runtimeManifestWithServerDown = try #require(unavailableServer["runtime-manifest"])
        #expect(runtimeManifestWithServerDown.nextAction?.command == "serve")
        #expect(runtimeManifestWithServerDown.nextAction?.requiresLongRunningProcess == true)

        let xcodeDiscovery = try #require(disconnected["xcode-discovery"])
        #expect(xcodeDiscovery.group == "xcode")
        #expect(xcodeDiscovery.requiredBy.contains("project"))
        #expect(xcodeDiscovery.nextAction?.command == "xcode")

        let capture = try #require(disconnected["capture"])
        #expect(capture.group == "evidence")
        #expect(capture.requiredBy.contains("replay"))
        #expect(capture.evidence == ["evidence-bundle"])

        let evidence = try #require(disconnected["evidence"])
        #expect(evidence.supported)
        #expect(evidence.group == "evidence")
        #expect(evidence.nextAction?.command == "evidence")
        #expect(evidence.nextAction?.args == ["--output", "<dir.tritonevidence>", "--json"])
        #expect(evidence.evidence == ["evidence-bundle"])

        let evidenceSummary = try #require(disconnected["evidence-summary"])
        #expect(evidenceSummary.supported)
        #expect(evidenceSummary.nextAction?.args == ["summary", "<dir.tritonevidence>", "--json"])

        let evidenceRedact = try #require(disconnected["evidence-redact"])
        #expect(evidenceRedact.supported)
        #expect(evidenceRedact.nextAction?.args == ["redact", "<dir.tritonevidence>", "--output", "<safe.tritonevidence>", "--json"])

        let smokeIOS = try #require(disconnected["smoke-ios"])
        #expect(smokeIOS.supported)
        #expect(smokeIOS.group == "smoke")
        #expect(smokeIOS.nextAction?.command == "smoke")
        #expect(smokeIOS.nextAction?.args.first == "ios")

        let smokeHarmony = try #require(disconnected["smoke-harmony"])
        #expect(smokeHarmony.supported)
        #expect(smokeHarmony.group == "smoke")
        #expect(smokeHarmony.nextAction?.args.first == "harmony")

        let disconnectedObserveIOS = try #require(disconnected["observe-ios"])
        #expect(!disconnectedObserveIOS.supported)
        #expect(disconnectedObserveIOS.group == "observe")
        #expect(disconnectedObserveIOS.nextAction?.command == "observe")
        #expect(disconnectedObserveIOS.nextAction?.args == ["current", "--platform", "ios", "--json"])

        let unavailableObserveIOS = try #require(unavailableServer["observe-ios"])
        #expect(!unavailableObserveIOS.supported)
        #expect(unavailableObserveIOS.group == "observe")
        #expect(unavailableObserveIOS.nextAction?.command == "observe")
        #expect(unavailableObserveIOS.nextAction?.args == ["current", "--platform", "ios", "--json"])
        #expect(unavailableObserveIOS.nextAction?.requiresLongRunningProcess != true)

        let connectedObserveIOS = try #require(connected["observe-ios"])
        #expect(connectedObserveIOS.supported)
        #expect(connectedObserveIOS.group == "observe")
        #expect(connectedObserveIOS.requiredBy.contains("action"))
        #expect(connectedObserveIOS.requiredBy.contains("assert"))
        #expect(connectedObserveIOS.requiredBy.contains("evidence"))
        #expect(connectedObserveIOS.nextAction?.command == "observe")
        #expect(connectedObserveIOS.nextAction?.args == ["current", "--platform", "ios", "--json"])
        #expect(connectedObserveIOS.evidence == ["surface-tree", "runtime-ax", "host-layout"])

        let mediaPlayback = try #require(connected["media-playback"])
        #expect(mediaPlayback.supported)
        #expect(mediaPlayback.group == "observe")
        #expect(mediaPlayback.requiredBy.contains("assert"))
        #expect(mediaPlayback.requiredBy.contains("evidence"))
        #expect(mediaPlayback.nextAction?.command == "snapshot")
        #expect(mediaPlayback.nextAction?.args == ["--include", "media,ax,screenshot-metadata", "--json"])
        #expect(mediaPlayback.evidence == ["runtime-media", "runtime-ax", "screenshot-metadata"])

        let semanticState = try #require(connected["app-semantic-state"])
        #expect(semanticState.supported)
        #expect(semanticState.group == "semantic")
        #expect(semanticState.requiredBy.contains("assert"))
        #expect(semanticState.requiredBy.contains("evidence"))
        #expect(semanticState.nextAction?.command == "snapshot")
        #expect(semanticState.nextAction?.args == ["--include", "semantic,app,scene", "--json"])
        #expect(semanticState.evidence == ["runtime-semantic", "provider-state"])

        let disconnectedSemanticState = try #require(disconnected["app-semantic-state"])
        #expect(!disconnectedSemanticState.supported)
        #expect(disconnectedSemanticState.nextAction?.command == "status")

        let semanticAction = try #require(connected["app-semantic-action"])
        #expect(semanticAction.supported)
        #expect(semanticAction.group == "semantic")
        #expect(semanticAction.reason == nil)
        #expect(semanticAction.nextAction?.command == "snapshot")
        #expect(semanticAction.nextAction?.args == ["--include", "semantic", "--json"])
        #expect(semanticAction.evidence == ["runtime-semantic", "provider-action-catalog"])

        let webViewList = try #require(disconnected["webview-list"])
        #expect(webViewList.supported)
        #expect(webViewList.group == "webview")
        #expect(webViewList.requiredBy.contains("observe"))
        #expect(webViewList.nextAction?.command == "webview")
        #expect(webViewList.nextAction?.args == ["list", "--json"])
        #expect(webViewList.evidence == ["webview-candidates", "host-layout", "runtime-ax"])

        let webViewCurrent = try #require(disconnected["webview-current"])
        #expect(webViewCurrent.supported)
        #expect(webViewCurrent.nextAction?.args == ["current", "--json"])

        let disconnectedCurrentURL = try #require(disconnected["webview-current-url"])
        #expect(!disconnectedCurrentURL.supported)
        #expect(disconnectedCurrentURL.group == "webview")
        #expect(disconnectedCurrentURL.reason?.contains("WebView provider") == true)
        #expect(disconnectedCurrentURL.nextAction?.command == "webview")
        #expect(disconnectedCurrentURL.nextAction?.args == ["current-url", "--json"])

        let unavailableCurrentURL = try #require(unavailableServer["webview-current-url"])
        #expect(unavailableCurrentURL.nextAction?.command == "webview")
        #expect(unavailableCurrentURL.nextAction?.args == ["current-url", "--json"])
        #expect(unavailableCurrentURL.nextAction?.requiresLongRunningProcess != true)

        let connectedCurrentURL = try #require(connected["webview-current-url"])
        #expect(connectedCurrentURL.supported)
        #expect(connectedCurrentURL.nextAction?.command == "webview")
        #expect(connectedCurrentURL.nextAction?.args == ["current-url", "--json"])
        #expect(connectedCurrentURL.evidence == ["webview-provider", "provider-url"])

        let webViewSnapshot = try #require(connected["webview-snapshot"])
        #expect(webViewSnapshot.supported)
        #expect(webViewSnapshot.nextAction?.args == ["snapshot", "--include", "metadata,text,forms", "--json"])
        #expect(webViewSnapshot.evidence == ["webview-provider", "webview-snapshot"])

        let webViewWait = try #require(connected["webview-wait"])
        #expect(webViewWait.supported)
        #expect(webViewWait.nextAction?.args == ["wait", "--text", "<text>", "--json"])

        let routeCurrentURLAssert = try #require(connected["route-current-url-assert"])
        #expect(routeCurrentURLAssert.supported)
        #expect(routeCurrentURLAssert.group == "route")
        #expect(routeCurrentURLAssert.requiredBy.contains("assert"))
        #expect(routeCurrentURLAssert.nextAction?.command == "route")
        #expect(routeCurrentURLAssert.nextAction?.args == ["assert-current-url", "<expected-url>", "--json"])
        #expect(routeCurrentURLAssert.evidence == ["webview-provider", "route-assertion"])

        let disconnectedRouteCurrentURLAssert = try #require(disconnected["route-current-url-assert"])
        #expect(!disconnectedRouteCurrentURLAssert.supported)
        #expect(disconnectedRouteCurrentURLAssert.nextAction?.command == "route")
        #expect(disconnectedRouteCurrentURLAssert.nextAction?.args == ["assert-current-url", "<expected-url>", "--json"])

        let unavailableRouteCurrentURLAssert = try #require(unavailableServer["route-current-url-assert"])
        #expect(!unavailableRouteCurrentURLAssert.supported)
        #expect(unavailableRouteCurrentURLAssert.nextAction?.command == "route")
        #expect(unavailableRouteCurrentURLAssert.nextAction?.args == ["assert-current-url", "<expected-url>", "--json"])
        #expect(unavailableRouteCurrentURLAssert.nextAction?.requiresLongRunningProcess != true)

        let tap = try #require(connected["tap"])
        #expect(tap.group == "action")
        #expect(tap.requiredBy.contains("assert"))
        #expect(tap.nextAction?.command == "tap")
        #expect(tap.nextAction?.args == ["<query>", "--json"])
        #expect(tap.evidence == ["input.result", "runtime-ledger"])

        let swipe = try #require(connected["swipe"])
        #expect(swipe.nextAction?.args == ["--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
        #expect(swipe.evidence == ["input.result", "runtime-ledger"])

        let harmonyTap = try #require(connected["harmony-tap-text"])
        #expect(harmonyTap.group == "action")
        #expect(harmonyTap.requiredBy.contains("action"))
        #expect(harmonyTap.requiredBy.contains("assert"))
        #expect(harmonyTap.nextAction?.command == "tap")
        #expect(harmonyTap.nextAction?.args == ["<text>", "--platform", "harmony", "--json"])
        #expect(harmonyTap.evidence == ["host-command-json", "host-artifact"])

        let iosHostTap = try #require(connected["ios-simulator-host-tap"])
        #expect(!iosHostTap.supported)
        #expect(iosHostTap.reason == "Host-side iOS Simulator input is not available in the current adapter")
        #expect(iosHostTap.group == "host")
        #expect(iosHostTap.requiredBy.contains("action"))
        #expect(iosHostTap.requiredBy.contains("smoke"))
        #expect(iosHostTap.nextAction?.command == "sim")
        #expect(iosHostTap.nextAction?.args == ["tap", "--simulator", "<udid|booted>", "--x", "<x>", "--y", "<y>", "--json"])
        #expect(iosHostTap.evidence == ["unsupported-envelope", "command-schema"])

        let iosHostType = try #require(connected["ios-simulator-host-type"])
        #expect(!iosHostType.supported)
        #expect(iosHostType.reason == "Host-side iOS Simulator input is not available in the current adapter")
        #expect(iosHostType.group == "host")
        #expect(iosHostType.requiredBy.contains("action"))
        #expect(iosHostType.requiredBy.contains("smoke"))
        #expect(iosHostType.nextAction?.command == "sim")
        #expect(iosHostType.nextAction?.args == ["type", "--simulator", "<udid|booted>", "--text", "<text>", "--json"])
        #expect(iosHostType.evidence == ["unsupported-envelope", "command-schema"])

        let harmonyWait = try #require(connected["harmony-wait-text"])
        #expect(harmonyWait.group == "action")
        #expect(harmonyWait.requiredBy.contains("action"))
        #expect(harmonyWait.nextAction?.command == "wait")
        #expect(harmonyWait.nextAction?.args == ["--platform", "harmony", "--text", "<text>", "--json"])
        #expect(harmonyWait.evidence == ["host-command-json", "host-artifact"])

        let harmonyType = try #require(connected["harmony-type-text"])
        #expect(harmonyType.group == "action")
        #expect(harmonyType.requiredBy.contains("action"))
        #expect(harmonyType.nextAction?.command == "type")
        #expect(harmonyType.nextAction?.args == ["<text>", "--platform", "harmony", "--json"])
        #expect(harmonyType.evidence == ["host-command-json", "host-artifact"])

        let harmonyPress = try #require(connected["harmony-press-key"])
        #expect(harmonyPress.group == "action")
        #expect(harmonyPress.requiredBy.contains("action"))
        #expect(harmonyPress.nextAction?.command == "press")
        #expect(harmonyPress.nextAction?.args == ["<button>", "--platform", "harmony", "--json"])
        #expect(harmonyPress.evidence == ["host-command-json", "host-artifact"])

        let clear = try #require(connected["clear"])
        #expect(clear.nextAction?.args == ["--at", "<x,y>", "--json"])

        let harmonyClear = try #require(connected["harmony-clear-text"])
        #expect(!harmonyClear.supported)
        #expect(harmonyClear.group == "action")
        #expect(harmonyClear.requiredBy.contains("action"))
        #expect(harmonyClear.nextAction?.command == "clear")
        #expect(harmonyClear.nextAction?.args == ["--platform", "harmony", "--json"])
        #expect(harmonyClear.evidence == ["unsupported-envelope", "command-schema"])

        let unavailableHarmonyClear = try #require(unavailableServer["harmony-clear-text"])
        #expect(unavailableHarmonyClear.nextAction?.command == "clear")
        #expect(unavailableHarmonyClear.nextAction?.args == ["--platform", "harmony", "--json"])
        #expect(unavailableHarmonyClear.nextAction?.requiresLongRunningProcess != true)

        let input = try #require(connected["input"])
        #expect(input.nextAction?.args == ["--json", "--summary", "--strict"])
        #expect(input.evidence == ["input.result", "runtime-ledger"])

        let press = try #require(connected["press"])
        #expect(!press.supported)
        #expect(press.nextAction?.command == "schema")
        #expect(press.nextAction?.args == ["--command", "press", "--json"])
        #expect(press.evidence == ["unsupported-envelope", "command-schema"])
    }

    @Test("capabilities matrix exposes plan inspect capability")
    func capabilitiesMatrixExposesPlanInspectCapability() throws {
        for fixture in capabilityStateFixtures() {
            let capabilities = Dictionary(uniqueKeysWithValues: fixture.capabilities.map { ($0.name, $0) })
            let planInspect = try #require(capabilities["plan-inspect"])

            #expect(planInspect.supported)
            #expect(planInspect.group == "replay")
            #expect(planInspect.requiredBy.contains("replay"))
            #expect(planInspect.nextAction?.command == "plan")
            #expect(planInspect.nextAction?.args == ["inspect", "<file.tritonplan>", "--json"])
            #expect(planInspect.evidence == ["tritonplan", "stdout-json"])
        }
    }

    @Test("harmony host action capabilities keep server-independent next actions")
    func harmonyHostActionCapabilitiesKeepServerIndependentNextActions() throws {
        let unavailableServer = Dictionary(uniqueKeysWithValues: capabilityStateFixtures()
            .first { $0.name == "server-unreachable" }?
            .capabilities
            .map { ($0.name, $0) } ?? []
        )

        let expectations: [(name: String, command: String, args: [String])] = [
            ("harmony-tap-text", "tap", ["<text>", "--platform", "harmony", "--json"]),
            ("harmony-wait-text", "wait", ["--platform", "harmony", "--text", "<text>", "--json"]),
            ("harmony-swipe", "swipe", ["--platform", "harmony", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"]),
            ("harmony-type-text", "type", ["<text>", "--platform", "harmony", "--json"]),
            ("harmony-paste-text", "paste", ["<text>", "--platform", "harmony", "--json"]),
            ("harmony-clear-text", "clear", ["--platform", "harmony", "--json"]),
            ("harmony-press-key", "press", ["<button>", "--platform", "harmony", "--json"]),
        ]

        for expectation in expectations {
            let capability = try #require(unavailableServer[expectation.name])
            #expect(capability.group == "action")
            #expect(capability.requiredBy.contains("action"))
            #expect(capability.nextAction?.command == expectation.command)
            #expect(capability.nextAction?.args == expectation.args)
            #expect(capability.nextAction?.requiresLongRunningProcess != true)
        }
    }

    @Test("webview provider capabilities keep server-independent next actions")
    func webviewProviderCapabilitiesKeepServerIndependentNextActions() throws {
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()

        let expectations: [(name: String, group: String, requiredBy: [String], evidence: [String], command: String, args: [String])] = [
            ("webview-current-url", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "provider-url"], "webview", ["current-url", "--json"]),
            ("webview-snapshot", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "webview-snapshot"], "webview", ["snapshot", "--include", "metadata,text,forms", "--json"]),
            ("webview-bridge-call", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "bridge-call-result"], "webview", ["call", "<method>", "--json"]),
            ("webview-events", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "page-events"], "webview", ["events", "--limit", "50", "--json"]),
            ("webview-wait", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "wait-samples"], "webview", ["wait", "--text", "<text>", "--json"]),
            ("route-current-url-assert", "route", ["assert", "smoke", "evidence", "webview-check"], ["webview-provider", "route-assertion"], "route", ["assert-current-url", "<expected-url>", "--json"]),
        ]

        for expectation in expectations {
            try assertCapability(
                disconnected,
                name: expectation.name,
                supported: false,
                group: expectation.group,
                requiredByContains: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.command,
                nextActionArgs: expectation.args,
                longRunning: false
            )
            try assertCapability(
                unavailableServer,
                name: expectation.name,
                supported: false,
                group: expectation.group,
                requiredByContains: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.command,
                nextActionArgs: expectation.args,
                longRunning: false
            )
        }
    }

    @Test("discovery capabilities keep server-independent next actions")
    func discoveryCapabilitiesKeepServerIndependentNextActions() throws {
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()

        let expectations: [(
            name: String,
            supportedWhenDisconnected: Bool,
            group: String,
            requiredBy: [String],
            evidence: [String],
            command: String,
            args: [String]
        )] = [
            ("observe-ios", false, "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], "observe", ["current", "--platform", "ios", "--json"]),
            ("observe-android", true, "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], "observe", ["tree", "--platform", "android", "--device", "<selector>", "--json"]),
            ("observe-harmony", true, "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], "observe", ["tree", "--platform", "harmony", "--device", "<selector>", "--json"]),
            ("webview-list", true, "webview", ["observe", "route", "assert", "evidence"], ["webview-candidates", "host-layout", "runtime-ax"], "webview", ["list", "--json"]),
            ("webview-current", true, "webview", ["observe", "route", "assert", "evidence"], ["webview-candidates", "host-layout", "runtime-ax"], "webview", ["current", "--json"]),
            ("node-resolve", true, "observe", ["action", "assert", "evidence"], ["target.resolution", "surface-tree"], "node", ["resolve", "--text", "<text>", "--json"]),
        ]

        for expectation in expectations {
            try assertCapability(
                disconnected,
                name: expectation.name,
                supported: expectation.supportedWhenDisconnected,
                group: expectation.group,
                requiredByExact: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.command,
                nextActionArgs: expectation.args,
                longRunning: false
            )
            try assertCapability(
                unavailableServer,
                name: expectation.name,
                supported: expectation.supportedWhenDisconnected,
                group: expectation.group,
                requiredByExact: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.command,
                nextActionArgs: expectation.args,
                longRunning: false
            )
        }
    }

    @Test("observe and node provided capabilities stay schema-matrix aligned")
    func observeAndNodeProvidedCapabilitiesStaySchemaMatrixAligned() throws {
        let schemas = commandSchemaMap()
        let observeSchema = try #require(schemas["observe"])
        let nodeSchema = try #require(schemas["node"])
        let snapshotSchema = try #require(schemas["snapshot"])
        #expect(observeSchema.providedCapabilities == ["observe", "observe-ios", "media-playback", "observe-android", "observe-harmony"])
        #expect(snapshotSchema.providedCapabilities.contains("app-semantic-state"))
        #expect(snapshotSchema.providedCapabilities.contains("app-semantic-action"))
        expectContract(snapshotSchema, selector: "runtime.snapshot", fields: ["semantic", "semantic.domains[]", "semantic.domains[].state", "semantic.domains[].actions"])
        #expect(nodeSchema.providedCapabilities == ["node", "node-resolve"])

        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()

        let expectations: [(
            name: String,
            group: String,
            requiredBy: [String],
            evidence: [String],
            connectedSupported: Bool,
            disconnectedSupported: Bool,
            connectedCommand: String,
            connectedArgs: [String],
            disconnectedCommand: String,
            disconnectedArgs: [String]
        )] = [
            ("observe", "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], true, true, "observe", ["current", "--json"], "observe", ["current", "--json"]),
            ("observe-ios", "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], true, false, "observe", ["current", "--platform", "ios", "--json"], "observe", ["current", "--platform", "ios", "--json"]),
            ("media-playback", "observe", ["assert", "evidence", "observe"], ["runtime-media", "runtime-ax", "screenshot-metadata"], true, false, "snapshot", ["--include", "media,ax,screenshot-metadata", "--json"], "status", ["--json"]),
            ("observe-android", "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], true, true, "observe", ["tree", "--platform", "android", "--device", "<selector>", "--json"], "observe", ["tree", "--platform", "android", "--device", "<selector>", "--json"]),
            ("observe-harmony", "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], true, true, "observe", ["tree", "--platform", "harmony", "--device", "<selector>", "--json"], "observe", ["tree", "--platform", "harmony", "--device", "<selector>", "--json"]),
            ("node", "observe", ["action", "assert", "evidence"], ["hierarchy-node", "surface-tree"], true, false, "node", ["--oid", "<oid>", "--json"], "status", ["--json"]),
            ("node-resolve", "observe", ["action", "assert", "evidence"], ["target.resolution", "surface-tree"], true, true, "node", ["resolve", "--text", "<text>", "--json"], "node", ["resolve", "--text", "<text>", "--json"]),
        ]

        for expectation in expectations {
            try assertCapability(
                connected,
                name: expectation.name,
                supported: expectation.connectedSupported,
                group: expectation.group,
                requiredByExact: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.connectedCommand,
                nextActionArgs: expectation.connectedArgs
            )
            try assertCapability(
                disconnected,
                name: expectation.name,
                supported: expectation.disconnectedSupported,
                group: expectation.group,
                requiredByExact: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.disconnectedCommand,
                nextActionArgs: expectation.disconnectedArgs
            )
        }
    }

    @Test("webview and route provided capabilities stay schema-matrix aligned")
    func webviewAndRouteProvidedCapabilitiesStaySchemaMatrixAligned() throws {
        let schemas = commandSchemaMap()
        let webviewSchema = try #require(schemas["webview"])
        let routeSchema = try #require(schemas["route"])
        #expect(webviewSchema.providedCapabilities == [
            "webview-list", "webview-current", "webview-current-url",
            "webview-snapshot", "webview-bridge-call", "webview-events", "webview-wait",
        ])
        #expect(routeSchema.providedCapabilities == ["route-current-url-assert"])

        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()

        let expectations: [(
            name: String,
            group: String,
            requiredBy: [String],
            evidence: [String],
            connectedSupported: Bool,
            disconnectedSupported: Bool,
            command: String,
            args: [String]
        )] = [
            ("webview-list", "webview", ["observe", "route", "assert", "evidence"], ["webview-candidates", "host-layout", "runtime-ax"], true, true, "webview", ["list", "--json"]),
            ("webview-current", "webview", ["observe", "route", "assert", "evidence"], ["webview-candidates", "host-layout", "runtime-ax"], true, true, "webview", ["current", "--json"]),
            ("webview-current-url", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "provider-url"], true, false, "webview", ["current-url", "--json"]),
            ("webview-snapshot", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "webview-snapshot"], true, false, "webview", ["snapshot", "--include", "metadata,text,forms", "--json"]),
            ("webview-bridge-call", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "bridge-call-result"], true, false, "webview", ["call", "<method>", "--json"]),
            ("webview-events", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "page-events"], true, false, "webview", ["events", "--limit", "50", "--json"]),
            ("webview-wait", "webview", ["route", "assert", "evidence", "webview-check"], ["webview-provider", "wait-samples"], true, false, "webview", ["wait", "--text", "<text>", "--json"]),
            ("route-current-url-assert", "route", ["assert", "smoke", "evidence", "webview-check"], ["webview-provider", "route-assertion"], true, false, "route", ["assert-current-url", "<expected-url>", "--json"]),
        ]

        for expectation in expectations {
            try assertCapability(
                connected,
                name: expectation.name,
                supported: expectation.connectedSupported,
                group: expectation.group,
                requiredByContains: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.command,
                nextActionArgs: expectation.args
            )
            try assertCapability(
                disconnected,
                name: expectation.name,
                supported: expectation.disconnectedSupported,
                group: expectation.group,
                requiredByContains: expectation.requiredBy,
                evidence: expectation.evidence,
                nextActionCommand: expectation.command,
                nextActionArgs: expectation.args
            )
        }
    }

    @Test("task workflow plans expose executable command sequences")
    func taskWorkflowPlansExposeExecutableCommandSequences() throws {
        let capabilities = TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: true,
            latestHierarchyAvailable: true,
            targetCount: 1,
            runtime: "embedded",
            capabilities: []
        )

        let iosSmoke = buildWorkflowPlan(
            capabilities: capabilities,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "ios-smoke",
                device: "iphone15",
                bundleID: "com.example.app",
                url: "myapp://smoke",
                text: "Home",
                expectedURL: nil,
                evidence: "/tmp/smoke.tritonevidence"
            )
        )
        #expect(iosSmoke.mode == "task")
        #expect(iosSmoke.surface == "plan")
        #expect(iosSmoke.goal == "ios-smoke")
        #expect(iosSmoke.nextStep == "target-list")
        #expect(iosSmoke.nextWorkflows == ["app", "assert", "evidence", "smoke", "target"])
        #expect(iosSmoke.primaryWorkflowCategory == "app")
        #expect(iosSmoke.primaryExpectedArtifact == "stdout-json")
        #expect(iosSmoke.primaryNextAction?.command == "target")
        #expect(iosSmoke.primaryNextAction?.args == ["list", "--host", "127.0.0.1", "--port", "19421", "--json"])
        #expect(iosSmoke.primaryNextActionSource == "next-step-step")
        #expect(iosSmoke.steps.map(\.id).contains("target-resolve"))
        #expect(iosSmoke.steps.map(\.id).contains("ios-smoke"))
        #expect(iosSmoke.steps.map(\.id).contains("ios-host-input-unsupported"))
        #expect(iosSmoke.steps.first(where: { $0.id == "target-list" })?.workflowCategories == ["action", "app", "assert", "evidence", "observe", "runtime", "smoke", "target"])
        #expect(iosSmoke.steps.first(where: { $0.id == "ios-host-input-unsupported" })?.category == "diagnose")
        #expect(iosSmoke.steps.first(where: { $0.id == "ios-host-input-unsupported" })?.argv == ["triton", "schema", "--command", "sim", "--json"])
        #expect(iosSmoke.steps.first(where: { $0.id == "ios-smoke" })?.workflowCategories == ["app", "assert", "evidence", "smoke", "target"])
        #expect(iosSmoke.steps.first(where: { $0.id == "ios-smoke" })?.command.contains("triton smoke ios") == true)
        #expect(iosSmoke.steps.first(where: { $0.id == "evidence-summary" })?.requiresServer == false)

        let openURL = buildWorkflowPlan(
            capabilities: capabilities,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "open-url",
                device: "iphone15",
                bundleID: nil,
                url: "myapp://detail",
                text: "Ready",
                expectedURL: nil,
                evidence: "/tmp/open-url.tritonevidence"
            )
        )
        #expect(openURL.mode == "task")
        #expect(openURL.surface == "plan")
        #expect(openURL.goal == "open-url")
        #expect(openURL.nextWorkflows == ["app", "assert", "evidence", "target"])
        #expect(openURL.primaryWorkflowCategory == "app")
        #expect(openURL.primaryExpectedArtifact == "stdout-json")
        #expect(openURL.primaryNextAction?.command == "target")
        #expect(openURL.primaryNextActionSource == "next-step-step")
        #expect(openURL.steps.map(\.id) == ["target-resolve", "app-open-url", "wait-text", "assert-text", "evidence", "evidence-summary"])
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.workflowCategories == ["app", "assert", "evidence", "target"])
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.command.contains("triton app go") == true)
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.command.contains("--wait-ready") == false)
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.command.contains("--json") == false)
        #expect(openURL.steps.first(where: { $0.id == "evidence-summary" })?.requiresServer == false)

        let webview = buildWorkflowPlan(
            capabilities: capabilities,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "webview-check",
                device: nil,
                bundleID: nil,
                url: nil,
                text: "Loaded",
                expectedURL: "https://example.com",
                evidence: "/tmp/webview.tritonevidence"
            )
        )
        #expect(webview.mode == "task")
        #expect(webview.surface == "plan")
        #expect(webview.goal == "webview-check")
        #expect(webview.nextWorkflows == ["assert", "evidence", "observe", "route", "webview-check"])
        #expect(webview.primaryWorkflowCategory == "observe")
        #expect(webview.primaryExpectedArtifact == "stdout-json")
        #expect(webview.primaryNextAction?.command == "webview")
        #expect(webview.primaryNextActionSource == "next-step-step")
        #expect(webview.steps.map(\.id) == ["webview-current", "route-assert-current-url", "webview-wait", "evidence"])
        #expect(webview.steps.first(where: { $0.id == "webview-current" })?.workflowCategories == ["assert", "evidence", "observe", "route", "webview-check"])
        #expect(webview.steps.first(where: { $0.id == "route-assert-current-url" })?.command.contains("https://example.com") == true)
    }

    @Test("open-url bootstrap plan preserves deferred task workflow")
    func openURLBootstrapPlanPreservesDeferredTaskWorkflow() throws {
        let capabilities = TKCapabilitiesResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "unknown",
            capabilities: [],
            error: TKCLIErrorDetail(code: "server_unavailable", message: "No server")
        )

        let plan = buildWorkflowPlan(
            capabilities: capabilities,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "open-url",
                device: "iphone15",
                bundleID: nil,
                url: "myapp://detail",
                text: "Ready",
                expectedURL: nil,
                evidence: "/tmp/open-url.tritonevidence"
            )
        )

        #expect(plan.mode == "bootstrap")
        #expect(plan.nextStep == "start-server")
        #expect(plan.steps.first?.id == "start-server")
        #expect(plan.afterRecoverySteps.map(\.id) == ["target-resolve", "app-open-url", "wait-text", "assert-text", "evidence", "evidence-summary"])
        #expect(plan.afterRecoverySteps.first(where: { $0.id == "app-open-url" })?.argv == ["triton", "app", "go", "myapp://detail", "--device", "iphone15"])
        #expect(plan.afterRecoverySteps.first(where: { $0.id == "wait-text" })?.expectedArtifacts.contains("wait-result") == true)
        #expect(plan.afterRecoverySteps.first(where: { $0.id == "evidence-summary" })?.requiresServer == false)
    }

    @Test("open-url plan supports Harmony inputs with schema-backed steps")
    func openURLPlanSupportsHarmonyInputsWithSchemaBackedSteps() throws {
        let capabilities = TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: true,
            latestHierarchyAvailable: true,
            targetCount: 1,
            runtime: "host-harmony",
            capabilities: []
        )
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        let plan = buildWorkflowPlan(
            capabilities: capabilities,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "open-url",
                platform: "harmony",
                device: "harmony-a",
                bundleID: nil,
                bundle: "com.example.app",
                ability: "EntryAbility",
                hap: "/tmp/Demo.hap",
                url: "example://home",
                text: "Ready",
                expectedURL: nil,
                evidence: "/tmp/harmony.tritonevidence"
            )
        )

        #expect(plan.mode == "task")
        #expect(plan.goal == "open-url")
        #expect(plan.steps.map(\.id) == ["target-resolve", "install-app", "app-open-url", "wait-text", "capture-screenshot", "evidence-summary"])
        #expect(plan.steps.first(where: { $0.id == "install-app" })?.argv == ["triton", "app", "install", "--device", "harmony-a", "--platform", "harmony", "--hap", "/tmp/Demo.hap", "--json"])
        #expect(plan.steps.first(where: { $0.id == "app-open-url" })?.argv == ["triton", "app", "open-url", "example://home", "--device", "harmony-a", "--platform", "harmony", "--bundle", "com.example.app", "--ability", "EntryAbility", "--json"])
        #expect(plan.steps.first(where: { $0.id == "wait-text" })?.argv == ["triton", "wait", "--platform", "harmony", "--target", "harmony-a", "--text", "Ready", "--timeout", "15", "--json"])
        #expect(plan.steps.first(where: { $0.id == "capture-screenshot" })?.argv == ["triton", "screenshot", "--device", "harmony-a", "--platform", "harmony", "--output", "/tmp/harmony.png", "--json"])
        #expect(plan.steps.first(where: { $0.id == "evidence-summary" })?.argv == ["triton", "evidence", "summary", "/tmp/harmony.tritonevidence", "--json"])

        for step in plan.steps {
            validateSchemaBackedArgv(step.argv, context: "open-url:\(step.id)", schemas: schemas, issues: &issues)
        }
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("workflow plan mode separates bootstrap recovery from task workflows")
    func workflowPlanModeSeparatesBootstrapRecoveryFromTaskWorkflows() {
        let disconnected = TKCapabilitiesResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            latestHierarchyAvailable: false,
            targetCount: 0,
            runtime: "unknown",
            capabilities: []
        )
        let connected = TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: true,
            latestHierarchyAvailable: true,
            targetCount: 1,
            runtime: "embedded",
            capabilities: []
        )

        let bootstrapPlan = buildWorkflowPlan(
            capabilities: disconnected,
            host: "127.0.0.1",
            port: 19421
        )
        let taskPlan = buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "ios-smoke",
                device: "iphone15",
                bundleID: "com.example.app",
                url: "myapp://smoke",
                text: "Home",
                expectedURL: nil,
                evidence: "/tmp/smoke.tritonevidence"
            )
        )

        #expect(bootstrapPlan.mode == "bootstrap")
        #expect(bootstrapPlan.surface == "plan")
        #expect(bootstrapPlan.nextWorkflows.contains("app"))
        #expect(bootstrapPlan.primaryWorkflowCategory == "app")
        #expect(bootstrapPlan.primaryExpectedArtifact == "stdout-json")
        #expect(bootstrapPlan.primaryNextAction?.command == "serve")
        #expect(bootstrapPlan.primaryNextActionSource == "next-step-step")
        #expect(taskPlan.mode == "task")
        #expect(taskPlan.surface == "plan")
        #expect(taskPlan.primaryWorkflowCategory == "app")
        #expect(taskPlan.primaryExpectedArtifact == "stdout-json")
        #expect(taskPlan.primaryNextAction?.command == "target")
        #expect(taskPlan.primaryNextActionSource == "next-step-step")
        #expect(taskPlan.nextWorkflows.contains("smoke"))
    }

    @Test("task workflow plan argv stay aligned with command schemas")
    func taskWorkflowPlanArgvStayAlignedWithCommandSchemas() throws {
        let schemas = commandSchemaMap()
        let plans = workflowPlanFixtures(includeTaskInputs: true).filter { $0.goal != nil }

        var issues = SchemaBackedCommandIssues()

        for plan in plans {
            for step in plan.steps {
                validateSchemaBackedArgv(
                    step.argv,
                    context: "\(plan.goal ?? "unknown")/\(step.id)",
                    schemas: schemas,
                    issues: &issues
                )
            }
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("workflow plan steps expose executable metadata")
    func workflowPlanStepsExposeExecutableMetadata() {
        let schemas = commandSchemaMap()
        let plans = workflowPlanFixtures(includeTaskInputs: true)

        var invalidSteps: [String] = []
        var duplicateSteps: [String] = []
        var issues = SchemaBackedCommandIssues()

        for plan in plans {
            let context = plan.goal ?? plan.nextStep
            let ids = plan.steps.map(\.id)
            if Set(ids).count != ids.count {
                duplicateSteps.append(context)
            }
            for step in plan.steps {
                if step.id.isEmpty || step.title.isEmpty || step.command.isEmpty || step.when.isEmpty || step.expected.isEmpty {
                    invalidSteps.append("\(context):\(step.id)")
                }
                validateSchemaBackedArgv(
                    step.argv,
                    context: "\(context)/\(step.id)",
                    schemas: schemas,
                    issues: &issues
                )
            }
        }

        #expect(invalidSteps == [])
        #expect(duplicateSteps == [])
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("workflow plan next step points to an emitted step")
    func workflowPlanNextStepPointsToAnEmittedStep() {
        let plans = workflowPlanFixtures(includeTaskInputs: true)

        let missing = plans.compactMap { plan -> String? in
            let ids = Set(plan.steps.map(\.id))
            return ids.contains(plan.nextStep) ? nil : "\(plan.goal ?? "general"):\(plan.nextStep)"
        }

        #expect(missing == [])
    }

    @Test("schema command filtering and unknown-command diagnostics are machine-readable")
    func schemaCommandFilteringAndUnknownCommandDiagnosticsAreMachineReadable() throws {
        let response = try buildSchemaResponse(command: "tap")

        #expect(response.schemaVersion == 1)
        #expect(response.commands.map(\.name) == ["tap"])
        #expect(response.httpManagementAPI.isEmpty)

        var lookupError: SchemaCommandLookupError?
        do {
            _ = try buildSchemaResponse(command: "not-a-command")
        } catch let error as SchemaCommandLookupError {
            lookupError = error
        }

        let error = try #require(lookupError)
        let errorResponse = schemaUnknownCommandErrorResponse(error)

        #expect(errorResponse.ok == false)
        #expect(errorResponse.error.code == "unknown_command_schema")
        #expect(errorResponse.error.message.contains("not-a-command"))
        #expect(errorResponse.error.hint == "Run `triton schema --json` to inspect available command schemas.")
        #expect(errorResponse.error.nextAction?.command == "schema")
        #expect(errorResponse.error.nextAction?.args == ["--json"])
    }

    @Test("schema command filtering covers the full command inventory")
    func schemaCommandFilteringCoversTheFullCommandInventory() throws {
        for commandName in commandSchemas().map(\.name) {
            let response = try buildSchemaResponse(command: commandName)
            #expect(response.schemaVersion == 1)
            #expect(response.commands.map(\.name) == [commandName])
            #expect(response.httpManagementAPI.isEmpty)
        }
    }

    @Test("schema next commands expose schema-backed argv")
    func schemaNextCommandsExposeSchemaBackedArgv() {
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        for fixture in schemaNextCommandFixtures(includeSubcommands: false) {
            validateSchemaBackedArgv(
                fixture.argv,
                context: fixture.context,
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("subcommand next commands expose schema-backed argv")
    func subcommandNextCommandsExposeSchemaBackedArgv() {
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        for fixture in schemaNextCommandFixtures(includeSubcommands: true).filter(\.isSubcommand) {
            validateSchemaBackedArgv(
                fixture.argv,
                context: fixture.context,
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("schema command inventory remains stable for agent discovery")
    func schemaCommandInventoryRemainsStableForAgentDiscovery() {
        let commandNames = commandSchemas().map(\.name)

        #expect(commandNames.count == 53)
        #expect(Set(commandNames).count == commandNames.count)
        #expect(commandNames == [
            "version", "serve", "status", "doctor", "plan", "capabilities", "schema",
            "target",
            "xcode", "xcresult", "xctrace", "coverage",
            "runtime", "state", "snapshot", "focus", "set-text", "select-segment", "set-switch", "ledger",
            "device", "sim", "app",
            "list", "inspect", "observe", "webview", "route", "hierarchy", "nodes", "node", "attrs", "object",
            "export", "evidence", "capture", "smoke", "assert", "record", "replay",
            "find", "wait", "ax", "geometry", "hit", "screenshot",
            "tap", "swipe", "type", "paste", "clear", "press", "input",
        ])
    }

    @Test("schema provided capabilities are discoverable in capabilities matrix")
    func schemaProvidedCapabilitiesAreDiscoverableInCapabilitiesMatrix() {
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities))
        let matrixCapabilities = Set(connectedCapabilities().map(\.name))

        let missing = schemaCapabilities.subtracting(matrixCapabilities).sorted()
        #expect(missing == [])
    }

    @Test("schema provided capabilities keep stable metadata across capability states")
    func schemaProvidedCapabilitiesKeepStableMetadataAcrossCapabilityStates() {
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities)).sorted()
        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()

        var missingFromConnected: [String] = []
        var missingFromDisconnected: [String] = []
        var missingFromUnavailableServer: [String] = []
        var groupMismatches: [String] = []
        var requiredByMismatches: [String] = []
        var evidenceMismatches: [String] = []

        for capabilityName in schemaCapabilities {
            guard let connectedCapability = connected[capabilityName] else {
                missingFromConnected.append(capabilityName)
                continue
            }
            guard let disconnectedCapability = disconnected[capabilityName] else {
                missingFromDisconnected.append(capabilityName)
                continue
            }
            guard let unavailableServerCapability = unavailableServer[capabilityName] else {
                missingFromUnavailableServer.append(capabilityName)
                continue
            }

            if connectedCapability.group != disconnectedCapability.group ||
                connectedCapability.group != unavailableServerCapability.group {
                groupMismatches.append(capabilityName)
            }
            if connectedCapability.requiredBy != disconnectedCapability.requiredBy ||
                connectedCapability.requiredBy != unavailableServerCapability.requiredBy {
                requiredByMismatches.append(capabilityName)
            }
            if connectedCapability.evidence != disconnectedCapability.evidence ||
                connectedCapability.evidence != unavailableServerCapability.evidence {
                evidenceMismatches.append(capabilityName)
            }
        }

        #expect(missingFromConnected == [])
        #expect(missingFromDisconnected == [])
        #expect(missingFromUnavailableServer == [])
        #expect(groupMismatches == [])
        #expect(requiredByMismatches == [])
        #expect(evidenceMismatches == [])
    }

    @Test("schema provided capabilities keep schema-backed next actions across capability states")
    func schemaProvidedCapabilitiesKeepSchemaBackedNextActionsAcrossCapabilityStates() {
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities)).sorted()
        let schemas = commandSchemaMap()

        var missingCapabilities: [String] = []
        var missingGroups: [String] = []
        var miscGroups: [String] = []
        var missingEvidence: [String] = []
        var missingNextActions: [String] = []
        var issues = SchemaBackedCommandIssues()

        for fixture in capabilityStateFixtures() {
            let capabilityMap = Dictionary(uniqueKeysWithValues: fixture.capabilities.map { ($0.name, $0) })
            for capabilityName in schemaCapabilities {
                guard let capability = capabilityMap[capabilityName] else {
                    missingCapabilities.append("\(fixture.name):\(capabilityName)")
                    continue
                }

                if capability.group == nil {
                    missingGroups.append("\(fixture.name):\(capabilityName)")
                } else if capability.group == "misc" {
                    miscGroups.append("\(fixture.name):\(capabilityName)")
                }

                if capability.evidence.isEmpty {
                    missingEvidence.append("\(fixture.name):\(capabilityName)")
                }

                guard let nextAction = capability.nextAction else {
                    missingNextActions.append("\(fixture.name):\(capabilityName)")
                    continue
                }

                validateSchemaBackedNextAction(
                    nextAction.command,
                    args: nextAction.args,
                    context: "\(fixture.name):\(capabilityName)",
                    schemas: schemas,
                    issues: &issues
                )
            }
        }

        #expect(missingCapabilities == [])
        #expect(missingGroups == [])
        #expect(miscGroups == [])
        #expect(missingEvidence == [])
        #expect(missingNextActions == [])
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("capability supported and reason keep stable state-machine invariants")
    func capabilitySupportedAndReasonKeepStableStateMachineInvariants() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
        let harmonyClearBoundary = "Host-side Harmony clear is not available in the current adapter"
        let iosHostInputBoundary = "Host-side iOS Simulator input is not available in the current adapter"
        let pressBoundary = "Host-side HID is not available in the embedded runtime"
        let knownUnsupportedReasons = Set([
            requiresRuntime,
            requiresWebViewProvider,
            harmonyClearBoundary,
            iosHostInputBoundary,
            pressBoundary,
        ])

        var supportedWithReason: [String] = []
        var unsupportedWithoutReason: [String] = []
        var unknownUnsupportedReason: [String] = []
        var connectedUnexpectedUnsupported: [String] = []
        var connectedBoundaryReasonMismatch: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                let trimmedReason = capability.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
                if capability.supported {
                    if let reason = trimmedReason, !reason.isEmpty {
                        supportedWithReason.append("\(fixture.name):\(capability.name):\(reason)")
                    }
                    continue
                }

                guard let reason = trimmedReason, !reason.isEmpty else {
                    unsupportedWithoutReason.append("\(fixture.name):\(capability.name)")
                    continue
                }

                if !knownUnsupportedReasons.contains(reason) {
                    unknownUnsupportedReason.append("\(fixture.name):\(capability.name):\(reason)")
                }

                if fixture.name == "runtime-connected" {
                    if !["press", "harmony-clear-text", "ios-simulator-host-tap", "ios-simulator-host-type"].contains(capability.name) {
                        connectedUnexpectedUnsupported.append("\(capability.name):\(reason)")
                    } else if capability.name == "press", reason != pressBoundary {
                        connectedBoundaryReasonMismatch.append("\(capability.name):\(reason)")
                    } else if capability.name == "harmony-clear-text", reason != harmonyClearBoundary {
                        connectedBoundaryReasonMismatch.append("\(capability.name):\(reason)")
                    } else if ["ios-simulator-host-tap", "ios-simulator-host-type"].contains(capability.name), reason != iosHostInputBoundary {
                        connectedBoundaryReasonMismatch.append("\(capability.name):\(reason)")
                    }
                }
            }
        }

        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()
        let connected = connectedCapabilityMap()
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities))

        var reasonDriftAcrossDisconnectedAndUnavailableServer: [String] = []
        for capabilityName in schemaCapabilities.sorted() {
            let disconnectedReason = disconnected[capabilityName]?.reason
            let unavailableServerReason = unavailableServer[capabilityName]?.reason
            if disconnectedReason != unavailableServerReason {
                reasonDriftAcrossDisconnectedAndUnavailableServer.append(
                    "\(capabilityName):disconnected=\(disconnectedReason ?? "nil"):server-unreachable=\(unavailableServerReason ?? "nil")"
                )
            }
        }

        let connectedPress = try #require(connected["press"])
        let disconnectedPress = try #require(disconnected["press"])
        let unavailableServerPress = try #require(unavailableServer["press"])
        #expect(!connectedPress.supported)
        #expect(!disconnectedPress.supported)
        #expect(!unavailableServerPress.supported)
        #expect(connectedPress.reason == pressBoundary)
        #expect(disconnectedPress.reason == pressBoundary)
        #expect(unavailableServerPress.reason == pressBoundary)

        let connectedHarmonyClear = try #require(connected["harmony-clear-text"])
        let disconnectedHarmonyClear = try #require(disconnected["harmony-clear-text"])
        let unavailableServerHarmonyClear = try #require(unavailableServer["harmony-clear-text"])
        #expect(!connectedHarmonyClear.supported)
        #expect(!disconnectedHarmonyClear.supported)
        #expect(!unavailableServerHarmonyClear.supported)
        #expect(connectedHarmonyClear.reason == harmonyClearBoundary)
        #expect(disconnectedHarmonyClear.reason == harmonyClearBoundary)
        #expect(unavailableServerHarmonyClear.reason == harmonyClearBoundary)

        #expect(supportedWithReason == [])
        #expect(unsupportedWithoutReason == [])
        #expect(unknownUnsupportedReason == [])
        #expect(connectedUnexpectedUnsupported == [])
        #expect(connectedBoundaryReasonMismatch == [])
        #expect(reasonDriftAcrossDisconnectedAndUnavailableServer == [])
    }

    @Test("capability reason and next-action keep stable recovery transitions")
    func capabilityReasonAndNextActionKeepStableRecoveryTransitions() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"

        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities))

        var runtimeReasonDisconnectedUnexpectedRecovery: [String] = []
        var runtimeReasonUnavailableUnexpectedRecovery: [String] = []
        var runtimeReasonConnectedReasonLeak: [String] = []

        var webviewReasonDisconnectedUnexpectedRecovery: [String] = []
        var webviewReasonUnavailableUnexpectedRecovery: [String] = []
        var webviewReasonConnectedReasonLeak: [String] = []

        for capabilityName in schemaCapabilities.sorted() {
            guard let connectedCapability = connected[capabilityName],
                  let disconnectedCapability = disconnected[capabilityName],
                  let unavailableServerCapability = unavailableServer[capabilityName] else {
                continue
            }

            if disconnectedCapability.reason == requiresRuntime {
                if connectedCapability.reason != nil {
                    runtimeReasonConnectedReasonLeak.append("\(capabilityName):connected=\(connectedCapability.reason ?? "nil")")
                }

                let disconnectedAction = disconnectedCapability.nextAction
                let unavailableAction = unavailableServerCapability.nextAction
                let connectedAction = connectedCapability.nextAction

                if disconnectedAction?.command == "status" {
                    if unavailableAction?.command != "serve" ||
                        unavailableAction?.args != ["--host", "127.0.0.1", "--port", "19421"] ||
                        unavailableAction?.requiresLongRunningProcess != true {
                        runtimeReasonUnavailableUnexpectedRecovery.append(
                            "\(capabilityName):expected=serve:actual=\(unavailableAction?.command ?? "nil"):\(unavailableAction?.args ?? [])"
                        )
                    }
                } else {
                    if disconnectedAction?.command != connectedAction?.command ||
                        disconnectedAction?.args != connectedAction?.args ||
                        disconnectedAction?.requiresLongRunningProcess == true {
                        runtimeReasonDisconnectedUnexpectedRecovery.append(
                            "\(capabilityName):expected-connected-action:actual=\(disconnectedAction?.command ?? "nil"):\(disconnectedAction?.args ?? [])"
                        )
                    }
                    if unavailableAction?.command != disconnectedAction?.command ||
                        unavailableAction?.args != disconnectedAction?.args ||
                        unavailableAction?.requiresLongRunningProcess == true {
                        runtimeReasonUnavailableUnexpectedRecovery.append(
                            "\(capabilityName):expected-disconnected-action:actual=\(unavailableAction?.command ?? "nil"):\(unavailableAction?.args ?? [])"
                        )
                    }
                }
            }

            if disconnectedCapability.reason == requiresWebViewProvider {
                if connectedCapability.reason != nil {
                    webviewReasonConnectedReasonLeak.append("\(capabilityName):connected=\(connectedCapability.reason ?? "nil")")
                }

                let disconnectedAction = disconnectedCapability.nextAction
                let unavailableAction = unavailableServerCapability.nextAction
                let connectedAction = connectedCapability.nextAction

                if disconnectedAction?.command == "serve" || disconnectedAction?.command == "status" {
                    webviewReasonDisconnectedUnexpectedRecovery.append(
                        "\(capabilityName):unexpected-disconnected-command=\(disconnectedAction?.command ?? "nil")"
                    )
                }
                if unavailableAction?.command == "serve" || unavailableAction?.command == "status" {
                    webviewReasonUnavailableUnexpectedRecovery.append(
                        "\(capabilityName):unexpected-unavailable-command=\(unavailableAction?.command ?? "nil")"
                    )
                }
                if disconnectedAction?.command != connectedAction?.command ||
                    disconnectedAction?.args != connectedAction?.args ||
                    disconnectedAction?.requiresLongRunningProcess == true {
                    webviewReasonDisconnectedUnexpectedRecovery.append(
                        "\(capabilityName):expected-connected-action:actual=\(disconnectedAction?.command ?? "nil"):\(disconnectedAction?.args ?? [])"
                    )
                }
                if unavailableAction?.command != disconnectedAction?.command ||
                    unavailableAction?.args != disconnectedAction?.args ||
                    unavailableAction?.requiresLongRunningProcess == true {
                    webviewReasonUnavailableUnexpectedRecovery.append(
                        "\(capabilityName):expected-disconnected-action:actual=\(unavailableAction?.command ?? "nil"):\(unavailableAction?.args ?? [])"
                    )
                }
            }
        }

        #expect(runtimeReasonConnectedReasonLeak == [])
        #expect(runtimeReasonDisconnectedUnexpectedRecovery == [])
        #expect(runtimeReasonUnavailableUnexpectedRecovery == [])
        #expect(webviewReasonConnectedReasonLeak == [])
        #expect(webviewReasonDisconnectedUnexpectedRecovery == [])
        #expect(webviewReasonUnavailableUnexpectedRecovery == [])
    }

    @Test("capability reason text stays bidirectionally aligned with capability families")
    func capabilityReasonTextStaysBidirectionallyAlignedWithCapabilityFamilies() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
        let harmonyClearBoundary = "Host-side Harmony clear is not available in the current adapter"
        let pressBoundary = "Host-side HID is not available in the embedded runtime"

        let runtimeReasonCapabilities = Set([
            "runtime-manifest", "state-app", "state-scene", "state-route", "state-responder",
            "snapshot", "media-playback", "app-semantic-state", "app-semantic-action", "focus", "set-text", "select-segment", "set-switch", "semantic-action", "ledger",
            "observe-ios",
            "inspect", "hierarchy", "nodes", "node", "attrs", "object",
            "export-json", "export-archive", "geometry", "ax", "hit", "screenshot",
            "wait", "capture", "assert", "replay",
            "tap", "swipe", "type", "paste", "clear", "input",
        ])
        let webviewProviderReasonCapabilities = Set([
            "webview-current-url", "webview-snapshot", "webview-bridge-call",
            "webview-events", "webview-wait", "route-current-url-assert",
        ])

        let connected = connectedCapabilityMap()
        let disconnected = disconnectedCapabilityMap()
        let unavailableServer = unavailableServerCapabilityMap()

        var runtimeReasonToWrongFamily: [String] = []
        var webviewReasonToWrongFamily: [String] = []
        var harmonyClearReasonToWrongFamily: [String] = []
        var pressReasonToWrongFamily: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                switch capability.reason {
                case requiresRuntime:
                    if !runtimeReasonCapabilities.contains(capability.name) {
                        runtimeReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                case requiresWebViewProvider:
                    if !webviewProviderReasonCapabilities.contains(capability.name) {
                        webviewReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                case harmonyClearBoundary:
                    if capability.name != "harmony-clear-text" {
                        harmonyClearReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                case pressBoundary:
                    if capability.name != "press" {
                        pressReasonToWrongFamily.append("\(fixture.name):\(capability.name)")
                    }
                default:
                    break
                }
            }
        }

        #expect(runtimeReasonToWrongFamily == [])
        #expect(webviewReasonToWrongFamily == [])
        #expect(harmonyClearReasonToWrongFamily == [])
        #expect(pressReasonToWrongFamily == [])

        var runtimeFamilyMissingReason: [String] = []
        var webviewFamilyMissingReason: [String] = []
        var boundaryReasonDrift: [String] = []

        for capabilityName in runtimeReasonCapabilities.sorted() {
            let connectedCapability = try #require(connected[capabilityName])
            let disconnectedCapability = try #require(disconnected[capabilityName])
            let unavailableCapability = try #require(unavailableServer[capabilityName])

            if connectedCapability.reason != nil {
                runtimeFamilyMissingReason.append("runtime-connected:\(capabilityName):reason=\(connectedCapability.reason ?? "nil")")
            }
            if disconnectedCapability.reason != requiresRuntime {
                runtimeFamilyMissingReason.append("runtime-disconnected:\(capabilityName):reason=\(disconnectedCapability.reason ?? "nil")")
            }
            if unavailableCapability.reason != requiresRuntime {
                runtimeFamilyMissingReason.append("server-unreachable:\(capabilityName):reason=\(unavailableCapability.reason ?? "nil")")
            }
        }

        for capabilityName in webviewProviderReasonCapabilities.sorted() {
            let connectedCapability = try #require(connected[capabilityName])
            let disconnectedCapability = try #require(disconnected[capabilityName])
            let unavailableCapability = try #require(unavailableServer[capabilityName])

            if connectedCapability.reason != nil {
                webviewFamilyMissingReason.append("runtime-connected:\(capabilityName):reason=\(connectedCapability.reason ?? "nil")")
            }
            if disconnectedCapability.reason != requiresWebViewProvider {
                webviewFamilyMissingReason.append("runtime-disconnected:\(capabilityName):reason=\(disconnectedCapability.reason ?? "nil")")
            }
            if unavailableCapability.reason != requiresWebViewProvider {
                webviewFamilyMissingReason.append("server-unreachable:\(capabilityName):reason=\(unavailableCapability.reason ?? "nil")")
            }
        }

        for fixture in capabilityStateFixtures() {
            let map = Dictionary(uniqueKeysWithValues: fixture.capabilities.map { ($0.name, $0) })
            let press = try #require(map["press"])
            let harmonyClear = try #require(map["harmony-clear-text"])
            if press.reason != pressBoundary {
                boundaryReasonDrift.append("\(fixture.name):press:\(press.reason ?? "nil")")
            }
            if harmonyClear.reason != harmonyClearBoundary {
                boundaryReasonDrift.append("\(fixture.name):harmony-clear-text:\(harmonyClear.reason ?? "nil")")
            }
        }

        #expect(runtimeFamilyMissingReason == [])
        #expect(webviewFamilyMissingReason == [])
        #expect(boundaryReasonDrift == [])
    }

    @Test("capability reason families stay aligned with group workflow and evidence taxonomies")
    func capabilityReasonFamiliesStayAlignedWithGroupWorkflowAndEvidenceTaxonomies() throws {
        let requiresRuntime = "Requires connected embedded TritonKit runtime"
        let requiresWebViewProvider = "Requires WebView provider metadata from embedded runtime or --runtime-base-url"
        let harmonyClearBoundary = "Host-side Harmony clear is not available in the current adapter"
        let iosHostInputBoundary = "Host-side iOS Simulator input is not available in the current adapter"
        let pressBoundary = "Host-side HID is not available in the embedded runtime"

        let runtimeReasonGroups = Set(["runtime", "semantic", "observe", "assert", "evidence", "replay", "action"])
        let webviewReasonGroups = Set(["webview", "route"])
        let webviewEvidenceKeys = Set([
            "webview-provider", "provider-url", "webview-snapshot",
            "bridge-call-result", "page-events", "wait-samples", "route-assertion",
        ])

        let fixtures: [(name: String, map: [String: TKRuntimeCapability])] = [
            ("runtime-disconnected", disconnectedCapabilityMap()),
            ("server-unreachable", unavailableServerCapabilityMap()),
        ]

        var runtimeReasonGroupMismatches: [String] = []
        var runtimeReasonWorkflowMismatches: [String] = []
        var runtimeReasonEvidenceMismatches: [String] = []

        var webviewReasonGroupMismatches: [String] = []
        var webviewReasonWorkflowMismatches: [String] = []
        var webviewReasonEvidenceMismatches: [String] = []

        var boundaryReasonTaxonomyMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.map.values {
                switch capability.reason {
                case requiresRuntime:
                    if let group = capability.group {
                        if !runtimeReasonGroups.contains(group) {
                            runtimeReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=\(group)")
                        }
                    } else {
                        runtimeReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=nil")
                    }
                    if capability.requiredBy.contains("webview-check") {
                        runtimeReasonWorkflowMismatches.append("\(fixture.name):\(capability.name):requiredBy=\(capability.requiredBy)")
                    }
                    let evidence = Set(capability.evidence)
                    if evidence.isEmpty || !evidence.isDisjoint(with: webviewEvidenceKeys) {
                        runtimeReasonEvidenceMismatches.append("\(fixture.name):\(capability.name):evidence=\(capability.evidence)")
                    }

                case requiresWebViewProvider:
                    if let group = capability.group {
                        if !webviewReasonGroups.contains(group) {
                            webviewReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=\(group)")
                        }
                    } else {
                        webviewReasonGroupMismatches.append("\(fixture.name):\(capability.name):group=nil")
                    }
                    if !capability.requiredBy.contains("webview-check") ||
                        !capability.requiredBy.contains("assert") ||
                        !capability.requiredBy.contains("evidence") {
                        webviewReasonWorkflowMismatches.append("\(fixture.name):\(capability.name):requiredBy=\(capability.requiredBy)")
                    }
                    let evidence = Set(capability.evidence)
                    if !evidence.contains("webview-provider") {
                        webviewReasonEvidenceMismatches.append("\(fixture.name):\(capability.name):evidence=\(capability.evidence)")
                    }

                case harmonyClearBoundary:
                    if capability.group != "action" ||
                        !capability.requiredBy.contains("action") ||
                        !capability.requiredBy.contains("assert") ||
                        !capability.requiredBy.contains("evidence") ||
                        Set(capability.evidence) != Set(["unsupported-envelope", "command-schema"]) {
                        boundaryReasonTaxonomyMismatches.append("\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):requiredBy=\(capability.requiredBy):evidence=\(capability.evidence)")
                    }

                case iosHostInputBoundary:
                    if capability.group != "host" ||
                        !capability.requiredBy.contains("action") ||
                        !capability.requiredBy.contains("smoke") ||
                        Set(capability.evidence) != Set(["unsupported-envelope", "command-schema"]) {
                        boundaryReasonTaxonomyMismatches.append("\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):requiredBy=\(capability.requiredBy):evidence=\(capability.evidence)")
                    }

                case pressBoundary:
                    if capability.group != "action" ||
                        !capability.requiredBy.contains("action") ||
                        !capability.requiredBy.contains("assert") ||
                        !capability.requiredBy.contains("evidence") ||
                        Set(capability.evidence) != Set(["unsupported-envelope", "command-schema"]) {
                        boundaryReasonTaxonomyMismatches.append("\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):requiredBy=\(capability.requiredBy):evidence=\(capability.evidence)")
                    }

                default:
                    break
                }
            }
        }

        #expect(runtimeReasonGroupMismatches == [])
        #expect(runtimeReasonWorkflowMismatches == [])
        #expect(runtimeReasonEvidenceMismatches == [])
        #expect(webviewReasonGroupMismatches == [])
        #expect(webviewReasonWorkflowMismatches == [])
        #expect(webviewReasonEvidenceMismatches == [])
        #expect(boundaryReasonTaxonomyMismatches == [])
    }

    @Test("capability requiredBy lanes stay aligned with next-action categories")
    func capabilityRequiredByLanesStayAlignedWithNextActionCategories() throws {
        let fixtures: [(name: String, capabilities: [TKRuntimeCapability])] = capabilityStateFixtures()

        var webviewCheckLaneMismatches: [String] = []
        var xcodeProjectLaneMismatches: [String] = []
        var smokeLaneMismatches: [String] = []
        var routeLaneMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let category = nextAction.category
                let requiredBy = capability.requiredBy
                let descriptor = "\(fixture.name):\(capability.name):category=\(category):requiredBy=\(requiredBy)"

                if requiredBy.contains("webview-check") &&
                    !Set(["observe", "verify"]).contains(category) {
                    webviewCheckLaneMismatches.append(descriptor)
                }

                if (requiredBy.contains("xcode") || requiredBy.contains("project")) &&
                    !Set(["project", "archive"]).contains(category) {
                    xcodeProjectLaneMismatches.append(descriptor)
                }

                if capability.name.hasPrefix("smoke-") && requiredBy.contains("smoke") &&
                    category != "smoke" {
                    smokeLaneMismatches.append(descriptor)
                }

                if (requiredBy.contains("route") || capability.group == "route") &&
                    !Set(["observe", "verify"]).contains(category) {
                    routeLaneMismatches.append(descriptor)
                }
            }
        }

        #expect(webviewCheckLaneMismatches == [])
        #expect(xcodeProjectLaneMismatches == [])
        #expect(smokeLaneMismatches == [])
        #expect(routeLaneMismatches == [])
    }

    @Test("capability group stays aligned with next-action root commands")
    func capabilityGroupStaysAlignedWithNextActionRootCommands() {
        let allowedRootsByGroup: [String: Set<String>] = [
            "bootstrap": ["status", "doctor", "capabilities", "schema", "plan", "record", "replay", "serve"],
            "target": ["target"],
            "runtime": ["runtime", "state", "snapshot", "focus", "set-text", "select-segment", "set-switch", "ledger", "schema", "status", "serve"],
            "semantic": ["snapshot", "status", "serve"],
            "host": ["device", "sim", "app", "ax"],
            "observe": ["observe", "snapshot", "list", "inspect", "hierarchy", "nodes", "node", "attrs", "object", "export", "geometry", "ax", "screenshot", "hit", "wait", "status", "serve"],
            "webview": ["webview"],
            "route": ["route"],
            "evidence": ["evidence", "status", "serve"],
            "assert": ["assert", "status", "serve"],
            "replay": ["plan", "status", "serve"],
            "smoke": ["smoke"],
            "action": ["tap", "swipe", "type", "paste", "clear", "press", "input", "wait", "schema", "status", "serve"],
            "xcode": ["xcode", "xcresult", "xctrace", "coverage"],
        ]

        var unknownGroups: [String] = []
        var mismatchedRoots: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                guard let group = capability.group else {
                    continue
                }
                guard let nextAction = capability.nextAction else {
                    continue
                }
                guard let allowedRoots = allowedRootsByGroup[group] else {
                    unknownGroups.append("\(fixture.name):\(capability.name):group=\(group)")
                    continue
                }
                let root = nextAction.command
                if !allowedRoots.contains(root) {
                    mismatchedRoots.append("\(fixture.name):\(capability.name):group=\(group):root=\(root)")
                }
            }
        }

        #expect(unknownGroups == [])
        #expect(mismatchedRoots == [])
    }

    @Test("capability next-action args keep lane-specific placeholder semantics")
    func capabilityNextActionArgsKeepLaneSpecificPlaceholderSemantics() {
        let fixtures = capabilityStateFixtures()

        var webviewCheckTemplateMismatches: [String] = []
        var routeTemplateMismatches: [String] = []
        var smokeTemplateMismatches: [String] = []
        let webviewCheckNeedsURLOrTextPlaceholders: Set<String> = [
            "route-current-url-assert",
            "webview-wait",
        ]
        let webviewCheckNeedsMethodPlaceholder: Set<String> = [
            "webview-bridge-call",
        ]

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let argSet = Set(args)
                let context = "\(fixture.name):\(capability.name)"

                if capability.requiredBy.contains("webview-check") {
                    if webviewCheckNeedsURLOrTextPlaceholders.contains(capability.name) {
                        let hasURLOrTextPlaceholder =
                            argSet.contains("<expected-url>") ||
                            argSet.contains("<url>") ||
                            argSet.contains("<text>")
                        if !hasURLOrTextPlaceholder {
                            webviewCheckTemplateMismatches.append("\(context):args=\(args)")
                        }
                    }

                    if webviewCheckNeedsMethodPlaceholder.contains(capability.name) && !argSet.contains("<method>") {
                        webviewCheckTemplateMismatches.append("\(context):args=\(args)")
                    }
                }

                if capability.group == "route" || capability.requiredBy.contains("route") {
                    if nextAction.command == "route" && !argSet.contains("<expected-url>") {
                        routeTemplateMismatches.append("\(context):args=\(args)")
                    }
                }

                if capability.name == "smoke-ios" {
                    let required = Set(["ios", "<device>", "<bundle-id>", "<url>", "<text>"])
                    if !required.isSubset(of: argSet) {
                        smokeTemplateMismatches.append("\(context):args=\(args)")
                    }
                }
                if capability.name == "smoke-harmony" {
                    let required = Set(["harmony", "<device>", "<bundle>", "<ability>", "<text>"])
                    if !required.isSubset(of: argSet) {
                        smokeTemplateMismatches.append("\(context):args=\(args)")
                    }
                }
            }
        }

        #expect(webviewCheckTemplateMismatches == [])
        #expect(routeTemplateMismatches == [])
        #expect(smokeTemplateMismatches == [])
    }

    @Test("capability groups keep machine-readable next-action output flags")
    func capabilityGroupsKeepMachineReadableNextActionOutputFlags() {
        let fixtures = capabilityStateFixtures()
        let schemas = commandSchemaMap()

        var missingMachineReadableFlags: [String] = []
        var screenshotObserveMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let argSet = Set(args)
                let context = "\(fixture.name):\(capability.name):group=\(capability.group ?? "nil"):command=\(nextAction.command):args=\(args)"

                if nextAction.command == "serve" {
                    continue
                }

                let hasJSONFlag = argSet.contains("--json") || argSet.contains("--jsonl")
                let hasPlanFormatJSON = args.contains("--format") && args.contains("json")
                let hasScreenshotMetadata = argSet.contains("--metadata")
                let defaultsToJSON = schemas[nextAction.command]?.options.contains {
                    $0.name == "--format" && $0.defaultValue == "json"
                } == true
                if !(hasJSONFlag || hasPlanFormatJSON || hasScreenshotMetadata || defaultsToJSON) {
                    missingMachineReadableFlags.append(context)
                }

                if capability.group == "observe" && nextAction.command == "screenshot" {
                    if !argSet.contains("--metadata") || !argSet.contains("<path.png>") {
                        screenshotObserveMismatches.append(context)
                    }
                }
            }
        }

        #expect(missingMachineReadableFlags == [])
        #expect(screenshotObserveMismatches == [])
    }

    @Test("capability next-action output placeholders stay artifact-typed and explicit")
    func capabilityNextActionOutputPlaceholdersStayArtifactTypedAndExplicit() {
        let fixtures = capabilityStateFixtures()

        let expectedOutputPlaceholdersByCapability: [String: [String]] = [
            "record": ["<file.tritonplan>"],
            "device-screenshot": ["<path>"],
            "host-device-screenshot": ["<path>"],
            "ios-screenshot": ["<path>"],
            "ios-device-screenshot": ["<path>"],
            "android-device-screenshot": ["<path>"],
            "android-ax": ["<path.xml>"],
            "harmony-screenshot": ["<path>"],
            "harmony-device-screenshot": ["<path>"],
            "sim-video": ["<path.mov>"],
            "sim-logs": ["<path.ndjson>"],
            "sim-diagnostics": ["<path>"],
            "capture": ["<dir.tritonevidence>"],
            "evidence": ["<dir.tritonevidence>"],
            "evidence-redact": ["<safe.tritonevidence>"],
            "screenshot": ["<path.png>"],
        ]

        var unknownOutputCapabilities: [String] = []
        var outputPlaceholderMismatches: [String] = []
        var nonPlaceholderOutputs: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let outputValues = args.enumerated().compactMap { index, arg -> String? in
                    guard arg == "--output", args.indices.contains(index + 1) else {
                        return nil
                    }
                    return args[index + 1]
                }

                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"
                if outputValues.contains(where: { !$0.hasPrefix("<") || !$0.hasSuffix(">") }) {
                    nonPlaceholderOutputs.append(context)
                }

                guard !outputValues.isEmpty else {
                    continue
                }

                guard let expected = expectedOutputPlaceholdersByCapability[capability.name] else {
                    unknownOutputCapabilities.append(context)
                    continue
                }
                if outputValues != expected {
                    outputPlaceholderMismatches.append("\(context):expected=\(expected)")
                }
            }
        }

        #expect(unknownOutputCapabilities == [])
        #expect(outputPlaceholderMismatches == [])
        #expect(nonPlaceholderOutputs == [])
    }

    @Test("capability next-action target selector placeholders stay canonical")
    func capabilityNextActionTargetSelectorPlaceholdersStayCanonical() {
        let fixtures = capabilityStateFixtures()

        var deviceSelectorMismatches: [String] = []
        var simulatorSelectorMismatches: [String] = []
        var bundleIDPlaceholderMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                for (index, arg) in args.enumerated() where arg == "--device" {
                    guard args.indices.contains(index + 1) else {
                        deviceSelectorMismatches.append("\(context):missing-device-value")
                        continue
                    }
                    let actual = args[index + 1]
                    let expected = nextAction.command == "smoke" ? "<device>" : "<selector>"
                    if actual != expected {
                        deviceSelectorMismatches.append("\(context):expected=\(expected):actual=\(actual)")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--simulator" {
                    guard args.indices.contains(index + 1) else {
                        simulatorSelectorMismatches.append("\(context):missing-simulator-value")
                        continue
                    }
                    let actual = args[index + 1]
                    if actual != "<udid|booted>" {
                        simulatorSelectorMismatches.append("\(context):expected=<udid|booted>:actual=\(actual)")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--bundle-id" {
                    guard args.indices.contains(index + 1) else {
                        bundleIDPlaceholderMismatches.append("\(context):missing-bundle-id-value")
                        continue
                    }
                    let actual = args[index + 1]
                    if actual != "<bundle-id>" {
                        bundleIDPlaceholderMismatches.append("\(context):expected=<bundle-id>:actual=\(actual)")
                    }
                }
            }
        }

        #expect(deviceSelectorMismatches == [])
        #expect(simulatorSelectorMismatches == [])
        #expect(bundleIDPlaceholderMismatches == [])
    }

    @Test("capability next-action platform flags stay canonical and family-aligned")
    func capabilityNextActionPlatformFlagsStayCanonicalAndFamilyAligned() {
        let fixtures = capabilityStateFixtures()

        var unsupportedPlatformValues: [String] = []
        var harmonyFamilyPlatformMismatches: [String] = []
        var iosFamilyPlatformMismatches: [String] = []
        var androidFamilyPlatformMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                let platformValues = args.enumerated().compactMap { index, arg -> String? in
                    guard arg == "--platform", args.indices.contains(index + 1) else {
                        return nil
                    }
                    return args[index + 1]
                }

                for value in platformValues where !Set(["ios", "android", "harmony"]).contains(value) {
                    unsupportedPlatformValues.append("\(context):platform=\(value)")
                }

                if capability.name.hasPrefix("harmony-") {
                    if !platformValues.isEmpty && !platformValues.allSatisfy({ $0 == "harmony" }) {
                        harmonyFamilyPlatformMismatches.append("\(context):platforms=\(platformValues)")
                    }
                }

                if capability.name.hasPrefix("ios-") || capability.name == "observe-ios" {
                    if !platformValues.isEmpty && !platformValues.allSatisfy({ $0 == "ios" }) {
                        iosFamilyPlatformMismatches.append("\(context):platforms=\(platformValues)")
                    }
                }

                if capability.name.hasPrefix("android-") {
                    if !platformValues.isEmpty && !platformValues.allSatisfy({ $0 == "android" }) {
                        androidFamilyPlatformMismatches.append("\(context):platforms=\(platformValues)")
                    }
                }
            }
        }

        #expect(unsupportedPlatformValues == [])
        #expect(harmonyFamilyPlatformMismatches == [])
        #expect(iosFamilyPlatformMismatches == [])
        #expect(androidFamilyPlatformMismatches == [])
    }

    @Test("capability next-action text placeholders stay canonical")
    func capabilityNextActionTextPlaceholdersStayCanonical() {
        let fixtures = capabilityStateFixtures()

        var textFlagPlaceholderMismatches: [String] = []
        var waitTextFlagPlaceholderMismatches: [String] = []
        var assertTextExistsPlaceholderMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                for (index, arg) in args.enumerated() where arg == "--text" {
                    guard args.indices.contains(index + 1) else {
                        textFlagPlaceholderMismatches.append("\(context):missing-text-value")
                        continue
                    }
                    if args[index + 1] != "<text>" {
                        textFlagPlaceholderMismatches.append("\(context):expected=<text>:actual=\(args[index + 1])")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--wait-text" {
                    guard args.indices.contains(index + 1) else {
                        waitTextFlagPlaceholderMismatches.append("\(context):missing-wait-text-value")
                        continue
                    }
                    if args[index + 1] != "<text>" {
                        waitTextFlagPlaceholderMismatches.append("\(context):expected=<text>:actual=\(args[index + 1])")
                    }
                }

                if nextAction.command == "assert",
                   let textExistsIndex = args.firstIndex(of: "text-exists") {
                    guard args.indices.contains(textExistsIndex + 1) else {
                        assertTextExistsPlaceholderMismatches.append("\(context):missing-assert-text")
                        continue
                    }
                    if args[textExistsIndex + 1] != "<text>" {
                        assertTextExistsPlaceholderMismatches.append("\(context):expected=<text>:actual=\(args[textExistsIndex + 1])")
                    }
                }
            }
        }

        #expect(textFlagPlaceholderMismatches == [])
        #expect(waitTextFlagPlaceholderMismatches == [])
        #expect(assertTextExistsPlaceholderMismatches == [])
    }

    @Test("capability next-action url placeholders stay canonical")
    func capabilityNextActionURLPlaceholdersStayCanonical() {
        let fixtures = capabilityStateFixtures()

        var urlFlagPlaceholderMismatches: [String] = []
        var openURLFlagPlaceholderMismatches: [String] = []
        var appOpenURLArgumentMismatches: [String] = []
        var routeAssertCurrentURLArgumentMismatches: [String] = []

        for fixture in fixtures {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                let args = nextAction.args
                let context = "\(fixture.name):\(capability.name):command=\(nextAction.command):args=\(args)"

                for (index, arg) in args.enumerated() where arg == "--url" {
                    guard args.indices.contains(index + 1) else {
                        urlFlagPlaceholderMismatches.append("\(context):missing-url-value")
                        continue
                    }
                    if args[index + 1] != "<url>" {
                        urlFlagPlaceholderMismatches.append("\(context):expected=<url>:actual=\(args[index + 1])")
                    }
                }

                for (index, arg) in args.enumerated() where arg == "--open-url" {
                    guard args.indices.contains(index + 1) else {
                        openURLFlagPlaceholderMismatches.append("\(context):missing-open-url-value")
                        continue
                    }
                    if args[index + 1] != "<url>" {
                        openURLFlagPlaceholderMismatches.append("\(context):expected=<url>:actual=\(args[index + 1])")
                    }
                }

                if nextAction.command == "app",
                   args.first == "open-url" || args.first == "go" {
                    guard args.indices.contains(1) else {
                        appOpenURLArgumentMismatches.append("\(context):missing-open-url-argument")
                        continue
                    }
                    if args[1] != "<url>" {
                        appOpenURLArgumentMismatches.append("\(context):expected=<url>:actual=\(args[1])")
                    }
                }

                if nextAction.command == "route",
                   args.first == "assert-current-url" {
                    guard args.indices.contains(1) else {
                        routeAssertCurrentURLArgumentMismatches.append("\(context):missing-expected-url-argument")
                        continue
                    }
                    if args[1] != "<expected-url>" {
                        routeAssertCurrentURLArgumentMismatches.append(
                            "\(context):expected=<expected-url>:actual=\(args[1])"
                        )
                    }
                }
            }
        }

        #expect(urlFlagPlaceholderMismatches == [])
        #expect(openURLFlagPlaceholderMismatches == [])
        #expect(appOpenURLArgumentMismatches == [])
        #expect(routeAssertCurrentURLArgumentMismatches == [])
    }

    @Test("capability names remain unique for agent indexing")
    func capabilityNamesRemainUniqueForAgentIndexing() {
        var duplicateSchemaCapabilities: [String] = []

        for schema in commandSchemas() {
            if Set(schema.providedCapabilities).count != schema.providedCapabilities.count {
                duplicateSchemaCapabilities.append(schema.name)
            }
        }

        let matrixCapabilities = connectedCapabilities().map(\.name)
        let duplicateMatrixCapabilities = Set(matrixCapabilities)
            .filter { capability in matrixCapabilities.filter { $0 == capability }.count > 1 }
            .sorted()

        #expect(duplicateSchemaCapabilities == [])
        #expect(duplicateMatrixCapabilities == [])
    }

    @Test("capability planning arrays expose nonempty unique values")
    func capabilityPlanningArraysExposeNonemptyUniqueValues() {
        var emptyRequiredBy: [String] = []
        var duplicateRequiredBy: [String] = []
        var emptyEvidence: [String] = []
        var duplicateEvidence: [String] = []

        let capabilities = connectedCapabilities()

        for capability in capabilities {
            if capability.requiredBy.contains(where: \.isEmpty) {
                emptyRequiredBy.append(capability.name)
            }
            if Set(capability.requiredBy).count != capability.requiredBy.count {
                duplicateRequiredBy.append(capability.name)
            }
            if capability.evidence.contains(where: \.isEmpty) {
                emptyEvidence.append(capability.name)
            }
            if Set(capability.evidence).count != capability.evidence.count {
                duplicateEvidence.append(capability.name)
            }
        }

        #expect(emptyRequiredBy == [])
        #expect(duplicateRequiredBy == [])
        #expect(emptyEvidence == [])
        #expect(duplicateEvidence == [])
    }

    @Test("capability groups stay within the agent taxonomy")
    func capabilityGroupsStayWithinTheAgentTaxonomy() {
        let capabilities = connectedCapabilities()
        let unknownGroups = capabilities
            .filter { !capabilityGroupTaxonomy().contains($0.group ?? "") }
            .map { "\($0.name):\($0.group ?? "nil")" }
            .sorted()

        #expect(unknownGroups == [])
    }

    @Test("capability requiredBy values stay within the workflow taxonomy")
    func capabilityRequiredByValuesStayWithinTheWorkflowTaxonomy() {
        let capabilities = connectedCapabilities()
        let unknownRequiredBy = capabilities
            .flatMap { capability in
                capability.requiredBy
                    .filter { !capabilityWorkflowTaxonomy().contains($0) }
                    .map { "\(capability.name):\($0)" }
            }
            .sorted()

        #expect(unknownRequiredBy == [])
    }

    @Test("capability evidence values stay within the artifact taxonomy")
    func capabilityEvidenceValuesStayWithinTheArtifactTaxonomy() {
        let capabilities = connectedCapabilities()
        let unknownEvidence = capabilities
            .flatMap { capability in
                capability.evidence
                    .filter { !capabilityEvidenceTaxonomy().contains($0) }
                    .map { "\(capability.name):\($0)" }
            }
            .sorted()

        #expect(unknownEvidence == [])
    }

    @Test("capabilities expose at least one evidence source")
    func capabilitiesExposeAtLeastOneEvidenceSource() {
        let capabilities = connectedCapabilities()
        let missingEvidence = capabilities
            .filter(\.evidence.isEmpty)
            .map(\.name)
            .sorted()

        #expect(missingEvidence == [])
    }

    @Test("capability long-running next actions stay explicit")
    func capabilityLongRunningNextActionsStayExplicit() {
        var unexpectedLongRunningActions: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities where capability.nextAction?.requiresLongRunningProcess == true {
                let action = capability.nextAction
                if action?.command != "serve" || action?.args != ["--host", "127.0.0.1", "--port", "19421"] {
                    unexpectedLongRunningActions.append("\(fixture.name):\(capability.name):\(action?.command ?? "nil")")
                }
            }
        }

        #expect(unexpectedLongRunningActions == [])
    }

    @Test("capability next action placeholders are complete argv tokens")
    func capabilityNextActionPlaceholdersAreCompleteArgvTokens() {
        var malformedPlaceholders: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                for arg in capability.nextAction?.args ?? [] where arg.contains("<") || arg.contains(">") {
                    if !isCompletePlaceholderToken(arg) {
                        malformedPlaceholders.append("\(fixture.name):\(capability.name):\(arg)")
                    }
                }
            }
        }

        #expect(malformedPlaceholders == [])
    }

    @Test("capability next actions expose stable recovery categories")
    func capabilityNextActionsExposeStableRecoveryCategories() {
        var missingCategories: [String] = []
        var invalidCategories: [String] = []
        var mismatchedCategories: [String] = []

        for fixture in capabilityStateFixtures() {
            for capability in fixture.capabilities {
                guard let nextAction = capability.nextAction else {
                    continue
                }
                if nextAction.category.isEmpty {
                    missingCategories.append("\(fixture.name):\(capability.name)")
                }
                if !TKCommandRecoveryCommand.categoryTaxonomy.contains(nextAction.category) {
                    invalidCategories.append("\(fixture.name):\(capability.name):\(nextAction.category)")
                }
                guard let expectedCategory = TKCommandRecoveryCommand.category(forRootCommand: nextAction.command) else {
                    mismatchedCategories.append("\(fixture.name):\(capability.name):\(nextAction.command)")
                    continue
                }
                if nextAction.category != expectedCategory {
                    mismatchedCategories.append("\(fixture.name):\(capability.name):expected=\(expectedCategory):actual=\(nextAction.category)")
                }
            }
        }

        #expect(missingCategories == [])
        #expect(invalidCategories == [])
        #expect(mismatchedCategories == [])
    }

    @Test("schema and plan placeholders are complete argv tokens")
    func schemaAndPlanPlaceholdersAreCompleteArgvTokens() {
        var malformedPlaceholders: [String] = []

        let schemaFixtures = schemaNextCommandFixtures(includeSubcommands: true)
            + schemaExampleCommandFixtures()
        for fixture in schemaFixtures {
            malformedPlaceholders.append(contentsOf: malformedPlaceholderTokens(
                in: fixture.argv,
                context: fixture.context
            ))
        }
        for fixture in workflowPlanCommandFixtures(includeTaskInputs: false) {
            malformedPlaceholders.append(contentsOf: malformedPlaceholderTokens(
                in: fixture.command,
                context: fixture.context
            ))
        }

        #expect(malformedPlaceholders == [])
    }

    @Test("workflow plan commands stay single Triton invocations")
    func workflowPlanCommandsStaySingleTritonInvocations() {
        var invalidCommands: [String] = []

        for fixture in workflowPlanCommandFixtures(includeTaskInputs: false) {
            if !isSingleTritonInvocation(fixture.command) {
                invalidCommands.append("\(fixture.context):\(fixture.command)")
            }
        }

        #expect(invalidCommands == [])
    }

    @Test("workflow plan steps expose executable argv")
    func workflowPlanStepsExposeExecutableArgv() {
        var missingArgv: [String] = []
        var invalidArgv: [String] = []
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        for fixture in workflowPlanFixtures(includeTaskInputs: true) {
            for step in fixture.steps {
                let context = "\(fixture.goal ?? "general"):\(step.id)"
                if step.argv.isEmpty {
                    missingArgv.append(context)
                    continue
                }
                if step.argv.first != "triton" || step.argv.contains(where: { $0.isEmpty }) {
                    invalidArgv.append("\(context):\(step.argv.joined(separator: " "))")
                    continue
                }
                validateSchemaBackedArgv(step.argv, context: context, schemas: schemas, issues: &issues)
            }
        }

        #expect(missingArgv == [])
        #expect(invalidArgv == [])
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("workflow plan steps expose stable recovery categories")
    func workflowPlanStepsExposeStableRecoveryCategories() {
        var missingCategories: [String] = []
        var invalidCategories: [String] = []
        var mismatchedCategories: [String] = []

        for plan in workflowPlanFixtures(includeTaskInputs: true) {
            let context = plan.goal ?? "general"
            for step in plan.steps {
                if step.category.isEmpty {
                    missingCategories.append("\(context):\(step.id)")
                }
                if !TKCommandRecoveryCommand.categoryTaxonomy.contains(step.category) {
                    invalidCategories.append("\(context):\(step.id):\(step.category)")
                }
                guard let root = tritonRootCommand(in: step.argv),
                      let expectedCategory = TKCommandRecoveryCommand.category(forRootCommand: root) else {
                    mismatchedCategories.append("\(context):\(step.id):\(step.argv.joined(separator: " "))")
                    continue
                }
                if step.category != expectedCategory {
                    mismatchedCategories.append("\(context):\(step.id):expected=\(expectedCategory):actual=\(step.category)")
                }
            }
        }

        #expect(missingCategories == [])
        #expect(invalidCategories == [])
        #expect(mismatchedCategories == [])
    }

    @Test("workflow plan steps expose structured execution metadata")
    func workflowPlanStepsExposeStructuredExecutionMetadata() {
        var missingRequires: [String] = []
        var missingArtifacts: [String] = []
        var missingStopConditions: [String] = []
        var invalidRequires: [String] = []
        var invalidArtifacts: [String] = []
        var invalidStopConditions: [String] = []

        for fixture in workflowPlanFixtures(includeTaskInputs: true) {
            for step in fixture.steps {
                let context = "\(fixture.goal ?? "general"):\(step.id)"
                if step.requires.isEmpty {
                    missingRequires.append(context)
                }
                if step.expectedArtifacts.isEmpty {
                    missingArtifacts.append(context)
                }
                if step.stopConditions.isEmpty {
                    missingStopConditions.append(context)
                }
                for requirement in step.requires where !isPlanMetadataKey(requirement) {
                    invalidRequires.append("\(context):\(requirement)")
                }
                for artifact in step.expectedArtifacts where !isPlanMetadataKey(artifact) {
                    invalidArtifacts.append("\(context):\(artifact)")
                }
                for condition in step.stopConditions where !isPlanMetadataKey(condition) {
                    invalidStopConditions.append("\(context):\(condition)")
                }
            }
        }

        #expect(missingRequires == [])
        #expect(missingArtifacts == [])
        #expect(missingStopConditions == [])
        #expect(invalidRequires == [])
        #expect(invalidArtifacts == [])
        #expect(invalidStopConditions == [])
    }

    @Test("workflow plan steps expose workflow taxonomy")
    func workflowPlanStepsExposeWorkflowTaxonomy() {
        var missingWorkflows: [String] = []
        var invalidWorkflows: [String] = []

        for plan in workflowPlanFixtures(includeTaskInputs: true) {
            for step in plan.steps {
                let context = "\(plan.goal ?? "general"):\(step.id)"
                if step.workflowCategories.isEmpty {
                    missingWorkflows.append(context)
                }
                for workflow in step.workflowCategories where !capabilityWorkflowTaxonomy().contains(workflow) {
                    invalidWorkflows.append("\(context):\(workflow)")
                }
            }
        }

        #expect(missingWorkflows == [])
        #expect(invalidWorkflows == [])
    }

    @Test("workflow plan nextWorkflows stay within the workflow taxonomy")
    func workflowPlanNextWorkflowsStayWithinTheWorkflowTaxonomy() {
        let unknownValues = workflowPlanFixtures(includeTaskInputs: true)
            .flatMap { plan in
                plan.nextWorkflows
                    .filter { !capabilityWorkflowTaxonomy().contains($0) }
                    .map { "\(plan.goal ?? "general"):\($0)" }
            }
            .sorted()

        #expect(unknownValues == [])
    }

    @Test("plan inspect steps expose schema-backed argv templates")
    func planInspectStepsExposeSchemaBackedArgvTemplates() {
        let schemas = commandSchemaMap()
        let plan = TKReplayPlan(
            name: "inspect-flow",
            variables: ["username", "password"],
            steps: [
                TKReplayPlanStep(action: .tap, text: "登录"),
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )
        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/inspect-flow.tritonplan", plan: plan)

        var issues = SchemaBackedCommandIssues()
        for step in summary.steps {
            validateSchemaBackedArgv(
                step.argv,
                context: "plan.inspect:\(step.index):\(step.action)",
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("plan inspect steps expose workflow taxonomy")
    func planInspectStepsExposeWorkflowTaxonomy() {
        let plan = TKReplayPlan(
            name: "inspect-flow",
            variables: ["username", "password"],
            steps: [
                TKReplayPlanStep(action: .tap, text: "登录"),
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )
        let summary = TKReplayPlanSummary(ok: true, path: "/tmp/inspect-flow.tritonplan", plan: plan)

        #expect(summary.steps[0].workflowCategories == ["action", "assert", "evidence"])
        #expect(summary.steps[1].workflowCategories == ["action", "assert", "evidence"])
        #expect(summary.steps[2].workflowCategories == ["assert", "evidence", "observe"])
        #expect(summary.steps[3].workflowCategories == ["evidence", "replay"])
    }

    @Test("replay step results expose schema-backed argv")
    func replayStepResultsExposeSchemaBackedArgv() throws {
        let schemas = commandSchemaMap()
        let plan = TKReplayPlan(
            name: "replay-flow",
            variables: ["username"],
            steps: [
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )

        var issues = SchemaBackedCommandIssues()

        for (offset, step) in plan.steps.enumerated() {
            let argv = try TKReplayStepExecution.argv(
                for: step,
                planName: plan.name,
                index: offset + 1,
                variables: ["username": "alice"]
            )
            let result = TKReplayStepResult(
                index: offset + 1,
                action: step.action.rawValue,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: argv
            )
            validateSchemaBackedArgv(
                result.argv,
                context: "replay.result:\(result.index):\(result.action)",
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("replay step results expose workflow taxonomy")
    func replayStepResultsExposeWorkflowTaxonomy() throws {
        let plan = TKReplayPlan(
            name: "replay-flow",
            variables: ["username"],
            steps: [
                TKReplayPlanStep(action: .paste, value: "${username}"),
                TKReplayPlanStep(action: .wait, gone: "登录", timeout: 15),
                TKReplayPlanStep(action: .evidence, name: "login-success"),
            ]
        )

        var results: [TKReplayStepResult] = []
        for (offset, step) in plan.steps.enumerated() {
            let argv = try TKReplayStepExecution.argv(
                for: step,
                planName: plan.name,
                index: offset + 1,
                variables: ["username": "alice"]
            )
            results.append(TKReplayStepResult(
                index: offset + 1,
                action: step.action.rawValue,
                ok: true,
                dryRun: true,
                elapsedMs: 0,
                command: argv
            ))
        }

        #expect(results[0].workflowCategories == ["action", "assert", "evidence"])
        #expect(results[1].workflowCategories == ["assert", "evidence", "observe"])
        #expect(results[2].workflowCategories == ["evidence", "replay"])
    }

    @Test("schema next commands stay single Triton invocations")
    func schemaNextCommandsStaySingleTritonInvocations() {
        var invalidCommands: [String] = []

        for fixture in schemaNextCommandFixtures(includeSubcommands: true) {
            if !isSingleTritonInvocation(fixture.command) {
                invalidCommands.append("\(fixture.context):\(fixture.command)")
            }
        }

        #expect(invalidCommands == [])
    }

    @Test("commands that provide capabilities expose output contracts")
    func commandsThatProvideCapabilitiesExposeOutputContracts() {
        let missing = commandSchemas()
            .filter { !$0.providedCapabilities.isEmpty }
            .filter { $0.outputContracts.isEmpty }
            .map(\.name)
            .sorted()

        #expect(missing == [])
    }

    @Test("schema output contracts expose nonempty fields")
    func schemaOutputContractsExposeNonemptyFields() {
        var missingSelectors: [String] = []
        var missingModels: [String] = []
        var emptyFields: [String] = []
        var duplicateFields: [String] = []
        var invalidFields: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                if contract.selector.isEmpty {
                    missingSelectors.append(schema.name)
                }
                if contract.model?.isEmpty ?? true {
                    missingModels.append("\(schema.name):\(contract.selector)")
                }
                if contract.fields.isEmpty {
                    emptyFields.append("\(schema.name):\(contract.selector)")
                }
                let names = contract.fields.map(\.name)
                if Set(names).count != names.count {
                    duplicateFields.append("\(schema.name):\(contract.selector)")
                }
                for field in contract.fields where field.name.isEmpty || field.type.isEmpty || field.description.isEmpty {
                    invalidFields.append("\(schema.name):\(contract.selector):\(field.name)")
                }
            }
        }

        #expect(missingSelectors == [])
        #expect(missingModels == [])
        #expect(emptyFields == [])
        #expect(duplicateFields == [])
        #expect(invalidFields == [])
    }

    @Test("schema output contract field types stay machine readable")
    func schemaOutputContractFieldTypesStayMachineReadable() {
        var invalidTypes: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                for field in contract.fields where !isMachineReadableSchemaType(field.type) {
                    invalidTypes.append("\(schema.name):\(contract.selector):\(field.name):\(field.type)")
                }
            }
        }

        #expect(invalidTypes == [])
    }

    @Test("schema output contract models stay machine readable")
    func schemaOutputContractModelsStayMachineReadable() {
        var invalidModels: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                guard let model = contract.model else {
                    invalidModels.append("\(schema.name):\(contract.selector):nil")
                    continue
                }
                if !isMachineReadableSchemaType(model) {
                    invalidModels.append("\(schema.name):\(contract.selector):\(model)")
                }
            }
        }

        #expect(invalidModels == [])
    }

    @Test("schema output contract formats stay within the agent taxonomy")
    func schemaOutputContractFormatsStayWithinAgentTaxonomy() {
        var invalidFormats: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts where !outputContractFormatTaxonomy().contains(contract.format) {
                invalidFormats.append("\(schema.name):\(contract.selector):\(contract.format)")
            }
        }

        #expect(invalidFormats == [])
    }

    @Test("schema output contract kinds stay within the agent taxonomy")
    func schemaOutputContractKindsStayWithinAgentTaxonomy() {
        var invalidKinds: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts where !outputContractKindTaxonomy().contains(contract.kind) {
                invalidKinds.append("\(schema.name):\(contract.selector):\(contract.kind)")
            }
        }

        #expect(invalidKinds == [])
    }

    @Test("schema output contract selectors remain unique for agent lookup")
    func schemaOutputContractSelectorsRemainUniqueForAgentLookup() {
        var duplicateSelectors: [String] = []

        for schema in commandSchemas() {
            let selectors = schema.outputContracts.map(\.selector)
            let duplicates = Set(selectors)
                .filter { selector in selectors.filter { $0 == selector }.count > 1 }
                .sorted()
            duplicateSelectors.append(contentsOf: duplicates.map { "\(schema.name):\($0)" })
        }

        #expect(duplicateSelectors == [])
    }

    @Test("schema output contract selectors and kinds use stable agent keys")
    func schemaOutputContractSelectorsAndKindsUseStableAgentKeys() {
        var invalidSelectors: [String] = []
        var invalidKinds: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                if !isAgentSelectorKey(contract.selector) {
                    invalidSelectors.append("\(schema.name):\(contract.selector)")
                }
                if !isKebabCaseKey(contract.kind) {
                    invalidKinds.append("\(schema.name):\(contract.selector):\(contract.kind)")
                }
            }
        }

        #expect(invalidSelectors == [])
        #expect(invalidKinds == [])
    }

    @Test("subcommand output selectors stay covered by parent output contracts")
    func subcommandOutputSelectorsStayCoveredByParentOutputContracts() {
        var uncoveredSelectors: [String] = []

        for schema in commandSchemas() {
            let contractSelectors = Set(schema.outputContracts.map(\.selector))
            for subcommand in schema.subcommands {
                let missing = Set(subcommand.outputSelectors).subtracting(contractSelectors).sorted()
                if !missing.isEmpty {
                    uncoveredSelectors.append("\(schema.name) \(subcommand.name): \(missing.joined(separator: ","))")
                }
            }
        }

        #expect(uncoveredSelectors == [])
    }

    @Test("schema failure surfaces expose stable failure codes")
    func schemaFailureSurfacesExposeStableFailureCodes() {
        let missingCodes = commandSchemas()
            .filter { $0.exitCodeOnFailure != 0 || ($0.failureShape?.isEmpty == false) }
            .filter { $0.failureCodes.isEmpty }
            .map(\.name)
            .sorted()

        #expect(missingCodes == [])
    }

    @Test("schema failure shapes describe next action category")
    func schemaFailureShapesDescribeNextActionCategory() {
        let missingCategory = commandSchemas()
            .compactMap { schema -> String? in
                guard let failureShape = schema.failureShape,
                      failureShape.contains("nextAction?"),
                      !failureShape.contains("nextAction.category"),
                      !failureShape.contains("nextAction?{")
                else {
                    return nil
                }
                return schema.name
            }
            .sorted()

        #expect(missingCategory == [])
    }

    @Test("error output contracts expose stable error subfields")
    func errorOutputContractsExposeStableErrorSubfields() {
        let requiredErrorFields: Set<String> = [
            "error.endpoint",
            "error.hint",
            "error.nearestCandidates",
            "error.suggestedCommands",
            "error.candidateCount",
            "error.nextAction",
            "error.nextAction.command",
            "error.nextAction.args",
            "error.nextAction.category",
            "error.nextAction.requiresLongRunningProcess",
        ]
        var missingFields: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                let fields = contract.fields
                let fieldNames = Set(fields.map(\.name))
                let hasCLIError = fields.contains { field in
                    field.name == "error" && field.type == "TKCLIErrorDetail?"
                }
                guard hasCLIError else { continue }

                let missing = requiredErrorFields.subtracting(fieldNames).sorted()
                if !missing.isEmpty {
                    missingFields.append("\(schema.name):\(contract.selector):\(missing.joined(separator: ","))")
                }
            }
        }

        #expect(missingFields == [])
    }

    @Test("nextAction output contracts expose stable next action subfields")
    func nextActionOutputContractsExposeStableNextActionSubfields() {
        let requiredNextActionFields: Set<String> = [
            ".command",
            ".args",
            ".category",
            ".requiresLongRunningProcess",
        ]
        var missingFields: [String] = []

        for schema in commandSchemas() {
            for contract in schema.outputContracts {
                let fields = contract.fields
                let fieldNames = Set(fields.map(\.name))
                let nextActionFields = fields.filter { $0.type == "TKCLINextAction?" }.map(\.name)

                for nextActionField in nextActionFields {
                    let missing = requiredNextActionFields
                        .map { "\(nextActionField)\($0)" }
                        .filter { !fieldNames.contains($0) }
                        .sorted()
                    if !missing.isEmpty {
                        missingFields.append("\(schema.name):\(contract.selector):\(nextActionField):\(missing.joined(separator: ","))")
                    }
                }
            }
        }

        #expect(missingFields == [])
    }

    @Test("schema failure codes use stable snake case")
    func schemaFailureCodesUseStableSnakeCase() {
        var invalidCodes: [String] = []
        var duplicateSurfaces: [String] = []

        for schema in commandSchemas() {
            if Set(schema.failureCodes).count != schema.failureCodes.count {
                duplicateSurfaces.append(schema.name)
            }
            for code in schema.failureCodes where !isSnakeCaseKey(code) {
                invalidCodes.append("\(schema.name):\(code)")
            }

            for subcommand in schema.subcommands {
                let context = "\(schema.name) \(subcommand.name)"
                if Set(subcommand.failureCodes).count != subcommand.failureCodes.count {
                    duplicateSurfaces.append(context)
                }
                for code in subcommand.failureCodes where !isSnakeCaseKey(code) {
                    invalidCodes.append("\(context):\(code)")
                }
            }
        }

        #expect(invalidCodes == [])
        #expect(duplicateSurfaces == [])
    }

    @Test("subcommand failure codes stay covered by parent schemas")
    func subcommandFailureCodesStayCoveredByParentSchemas() {
        var uncovered: [String] = []

        for schema in commandSchemas() {
            let parentCodes = Set(schema.failureCodes)
            for subcommand in schema.subcommands {
                let missing = Set(subcommand.failureCodes).subtracting(parentCodes).sorted()
                if !missing.isEmpty {
                    uncovered.append("\(schema.name) \(subcommand.name): \(missing.joined(separator: ","))")
                }
            }
        }

        #expect(uncovered == [])
    }

    @Test("schema options and subcommands expose nonempty metadata")
    func schemaOptionsAndSubcommandsExposeNonemptyMetadata() {
        var invalidOptions: [String] = []
        var duplicateOptions: [String] = []
        var invalidSubcommands: [String] = []
        var duplicateSubcommands: [String] = []

        for schema in commandSchemas() {
            let optionNames = schema.options.map(\.name)
            if Set(optionNames).count != optionNames.count {
                duplicateOptions.append(schema.name)
            }
            for option in schema.options where option.name.isEmpty || option.type.isEmpty || option.description.isEmpty {
                invalidOptions.append("\(schema.name):\(option.name)")
            }

            let subcommandNames = schema.subcommands.map(\.name)
            if Set(subcommandNames).count != subcommandNames.count {
                duplicateSubcommands.append(schema.name)
            }
            for subcommand in schema.subcommands where subcommand.name.isEmpty || subcommand.summary.isEmpty {
                invalidSubcommands.append("\(schema.name):\(subcommand.name)")
            }
        }

        #expect(invalidOptions == [])
        #expect(duplicateOptions == [])
        #expect(invalidSubcommands == [])
        #expect(duplicateSubcommands == [])
    }

    @Test("schema command subcommand and flag names use stable CLI keys")
    func schemaCommandSubcommandAndFlagNamesUseStableCLIKeys() {
        var invalidCommands: [String] = []
        var invalidFlags: [String] = []
        var invalidSubcommands: [String] = []

        for schema in commandSchemas() {
            if !isKebabCaseKey(schema.name) {
                invalidCommands.append(schema.name)
            }
            for option in schema.options where !isLongOptionKeyExpression(option.name) {
                invalidFlags.append("\(schema.name):\(option.name)")
            }
            for subcommand in schema.subcommands where !isKebabCaseKey(subcommand.name) {
                invalidSubcommands.append("\(schema.name):\(subcommand.name)")
            }
        }

        #expect(invalidCommands == [])
        #expect(invalidFlags == [])
        #expect(invalidSubcommands == [])
    }

    @Test("schema usage forms stay separate from options")
    func schemaUsageFormsStaySeparateFromOptions() {
        var usageOptions: [String] = []
        var invalidUsageForms: [String] = []
        var missingUsageForms: [String] = []

        for schema in commandSchemas() {
            for option in schema.options where option.type == "Subcommand" || option.type == "Task" {
                usageOptions.append("\(schema.name):\(option.name)")
            }

            if !schema.subcommands.isEmpty && schema.usageForms.isEmpty {
                missingUsageForms.append(schema.name)
            }

            for usageForm in schema.usageForms {
                if usageForm.form.isEmpty ||
                    usageForm.description.isEmpty ||
                    !["Subcommand", "Task"].contains(usageForm.kind) {
                    invalidUsageForms.append("\(schema.name):\(usageForm.form)")
                }
            }
        }

        #expect(usageOptions == [])
        #expect(missingUsageForms == [])
        #expect(invalidUsageForms == [])
    }

    @Test("schema argument forms stay separate from options")
    func schemaArgumentFormsStaySeparateFromOptions() {
        var argumentOptions: [String] = []
        var invalidArgumentForms: [String] = []

        for schema in commandSchemas() {
            for option in schema.options where option.name.hasPrefix("<") {
                argumentOptions.append("\(schema.name):\(option.name)")
            }

            for argument in schema.argumentForms {
                if !argument.name.hasPrefix("<") ||
                    !argument.name.hasSuffix(">") ||
                    argument.type.isEmpty ||
                    argument.description.isEmpty {
                    invalidArgumentForms.append("\(schema.name):\(argument.name)")
                }
            }
        }

        #expect(argumentOptions == [])
        #expect(invalidArgumentForms == [])
    }

    @Test("subcommand parameter references stay covered by parent schema")
    func subcommandParameterReferencesStayCoveredByParentSchema() {
        var missingReferences: [String] = []

        for schema in commandSchemas() {
            let knownParameters = schemaKnownParameterKeys(schema)
            for subcommand in schema.subcommands {
                let references = subcommand.requiredOptions +
                    subcommand.optionalOptions +
                    subcommand.oneOfRequiredOptions.flatMap { $0 }

                for reference in references where !knownParameters.contains(reference) {
                    missingReferences.append("\(schema.name) \(subcommand.name):\(reference)")
                }
            }
        }

        #expect(missingReferences == [])
    }

    @Test("command level required options stay direct or subcommand scoped")
    func commandLevelRequiredOptionsStayDirectOrSubcommandScoped() {
        var subcommandScopedRequirements: [String] = []
        var missingReferences: [String] = []

        for schema in commandSchemas() {
            if !schema.subcommands.isEmpty && !schema.requiredOptions.isEmpty {
                subcommandScopedRequirements.append("\(schema.name):\(schema.requiredOptions.joined(separator: ","))")
            }

            guard schema.subcommands.isEmpty else {
                continue
            }

            let knownParameters = schemaKnownParameterKeys(schema)
            for reference in schema.requiredOptions where !knownParameters.contains(reference) {
                missingReferences.append("\(schema.name):\(reference)")
            }
        }

        #expect(subcommandScopedRequirements == [])
        #expect(missingReferences == [])
    }

    @Test("schema default provider references stay schema backed")
    func schemaDefaultProviderReferencesStaySchemaBacked() {
        let schemas = commandSchemaMap()
        var issues = SchemaBackedCommandIssues()

        for schema in commandSchemas() {
            for command in schema.inheritsDefaultsFrom {
                validateSchemaBackedCommandExpression(
                    command,
                    context: "\(schema.name).inheritsDefaultsFrom",
                    schemas: schemas,
                    issues: &issues
                )
            }

            for subcommand in schema.subcommands {
                for command in subcommand.defaultProviders {
                    validateSchemaBackedCommandExpression(
                        command,
                        context: "\(schema.name) \(subcommand.name).defaultProviders",
                        schemas: schemas,
                        issues: &issues
                    )
                }
                for command in subcommand.inheritsDefaultsFrom {
                    validateSchemaBackedCommandExpression(
                        command,
                        context: "\(schema.name) \(subcommand.name).inheritsDefaultsFrom",
                        schemas: schemas,
                        issues: &issues
                    )
                }
            }
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("schema examples and output formats remain agent usable")
    func schemaExamplesAndOutputFormatsRemainAgentUsable() {
        let schemas = commandSchemaMap()
        var missingOutputFormats: [String] = []
        var missingExamples: [String] = []
        var issues = SchemaBackedCommandIssues()

        for schema in commandSchemas() {
            if schema.outputFormats.isEmpty {
                missingOutputFormats.append(schema.name)
            }
            if schema.examples.isEmpty {
                missingExamples.append(schema.name)
            }
        }

        for fixture in schemaExampleCommandFixtures() {
            validateSchemaBackedArgv(
                fixture.argv,
                context: fixture.context,
                schemas: schemas,
                issues: &issues
            )
        }

        #expect(missingOutputFormats == [])
        #expect(missingExamples == [])
        expectNoSchemaBackedCommandIssues(issues)
    }

    @Test("schema output formats stay within the command taxonomy")
    func schemaOutputFormatsStayWithinCommandTaxonomy() {
        var invalidFormats: [String] = []
        var duplicateFormats: [String] = []

        for schema in commandSchemas() {
            for format in schema.outputFormats where !commandOutputFormatTaxonomy().contains(format) {
                invalidFormats.append("\(schema.name):\(format)")
            }
            if Set(schema.outputFormats).count != schema.outputFormats.count {
                duplicateFormats.append(schema.name)
            }
        }

        #expect(invalidFormats == [])
        #expect(duplicateFormats == [])
    }

    @Test("schema artifacts stay within the artifact taxonomy")
    func schemaArtifactsStayWithinTheArtifactTaxonomy() {
        var invalidArtifacts: [String] = []
        var duplicateArtifacts: [String] = []

        for schema in commandSchemas() {
            for artifact in schema.artifacts where !schemaArtifactTaxonomy().contains(artifact) {
                invalidArtifacts.append("\(schema.name):\(artifact)")
            }
            if Set(schema.artifacts).count != schema.artifacts.count {
                duplicateArtifacts.append(schema.name)
            }

            for subcommand in schema.subcommands {
                for artifact in subcommand.artifacts where !schemaArtifactTaxonomy().contains(artifact) {
                    invalidArtifacts.append("\(schema.name) \(subcommand.name):\(artifact)")
                }
                if Set(subcommand.artifacts).count != subcommand.artifacts.count {
                    duplicateArtifacts.append("\(schema.name) \(subcommand.name)")
                }
            }
        }

        #expect(invalidArtifacts == [])
        #expect(duplicateArtifacts == [])
    }

    @Test("schema jsonl events expose stable event keys")
    func schemaJSONLEventsExposeStableEventKeys() {
        var invalidEvents: [String] = []
        var duplicateEvents: [String] = []
        var missingFinalEvents: [String] = []
        var missingJSONLOutputFormat: [String] = []

        for schema in commandSchemas() {
            for event in schema.jsonlEvents where !isAgentEventKey(event, allowingPlaceholders: true) {
                invalidEvents.append("\(schema.name):\(event)")
            }
            if Set(schema.jsonlEvents).count != schema.jsonlEvents.count {
                duplicateEvents.append(schema.name)
            }
            if let finalEventKind = schema.finalEventKind {
                if !isAgentEventKey(finalEventKind, allowingPlaceholders: true) {
                    invalidEvents.append("\(schema.name):\(finalEventKind)")
                }
                if !schema.jsonlEvents.contains(finalEventKind) {
                    missingFinalEvents.append("\(schema.name):\(finalEventKind)")
                }
            }
            if (!schema.jsonlEvents.isEmpty || schema.finalEventKind != nil) && !schema.outputFormats.contains("jsonl") {
                missingJSONLOutputFormat.append(schema.name)
            }

            for subcommand in schema.subcommands {
                for event in subcommand.jsonlEvents where !isAgentEventKey(event, allowingPlaceholders: false) {
                    invalidEvents.append("\(schema.name) \(subcommand.name):\(event)")
                }
                if Set(subcommand.jsonlEvents).count != subcommand.jsonlEvents.count {
                    duplicateEvents.append("\(schema.name) \(subcommand.name)")
                }
                if let finalEventKind = subcommand.finalEventKind {
                    if !isAgentEventKey(finalEventKind, allowingPlaceholders: false) {
                        invalidEvents.append("\(schema.name) \(subcommand.name):\(finalEventKind)")
                    }
                    if !subcommand.jsonlEvents.contains(finalEventKind) {
                        missingFinalEvents.append("\(schema.name) \(subcommand.name):\(finalEventKind)")
                    }
                }
            }
        }

        #expect(invalidEvents == [])
        #expect(duplicateEvents == [])
        #expect(missingFinalEvents == [])
        #expect(missingJSONLOutputFormat == [])
    }

    @Test("retryable schemas expose recovery commands")
    func retryableSchemasExposeRecoveryCommands() {
        var retryableWithoutNextCommands: [String] = []

        for schema in commandSchemas() {
            if schema.retryable && schema.nextCommands.isEmpty {
                retryableWithoutNextCommands.append(schema.name)
            }

            for subcommand in schema.subcommands where subcommand.retryable && subcommand.nextCommands.isEmpty {
                retryableWithoutNextCommands.append("\(schema.name) \(subcommand.name)")
            }
        }

        #expect(retryableWithoutNextCommands == [])
    }

    @Test("failure codes expose a recovery command path")
    func failureCodesExposeARecoveryCommandPath() {
        var failureCodesWithoutRecoveryPath: [String] = []

        for schema in commandSchemas() {
            if !schema.failureCodes.isEmpty && schema.nextCommands.isEmpty {
                failureCodesWithoutRecoveryPath.append(schema.name)
            }

            for subcommand in schema.subcommands
                where !subcommand.failureCodes.isEmpty &&
                subcommand.nextCommands.isEmpty &&
                schema.nextCommands.isEmpty {
                failureCodesWithoutRecoveryPath.append("\(schema.name) \(subcommand.name)")
            }
        }

        #expect(failureCodesWithoutRecoveryPath == [])
    }

    @Test("schema recovery command lists stay clean")
    func schemaRecoveryCommandListsStayClean() {
        var blankRecoveryCommands: [String] = []
        var duplicateRecoveryCommands: [String] = []

        for schema in commandSchemas() {
            collectRecoveryCommandListIssues(
                schema.nextCommands,
                context: schema.name,
                blank: &blankRecoveryCommands,
                duplicate: &duplicateRecoveryCommands
            )

            for subcommand in schema.subcommands {
                collectRecoveryCommandListIssues(
                    subcommand.nextCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    blank: &blankRecoveryCommands,
                    duplicate: &duplicateRecoveryCommands
                )
            }
        }

        #expect(blankRecoveryCommands == [])
        #expect(duplicateRecoveryCommands == [])
    }

    @Test("schema recovery command roots stay within the recovery taxonomy")
    func schemaRecoveryCommandRootsStayWithinRecoveryTaxonomy() {
        var unknownRecoveryRoots: [String] = []

        for fixture in schemaNextCommandFixtures(includeSubcommands: true) {
            guard let root = tritonRootCommand(in: fixture.argv) else {
                unknownRecoveryRoots.append("\(fixture.context):\(fixture.argv.joined(separator: " "))")
                continue
            }
            if !recoveryCommandRootTaxonomy().contains(root) {
                unknownRecoveryRoots.append("\(fixture.context):\(root)")
            }
        }

        #expect(unknownRecoveryRoots == [])
    }

    @Test("schema recovery command roots expose stable categories")
    func schemaRecoveryCommandRootsExposeStableCategories() {
        let rootTaxonomy = recoveryCommandRootTaxonomy()
        let categoryMap = recoveryCommandRootCategoryMap()
        let categoryTaxonomy = recoveryCommandCategoryTaxonomy()

        let missingCategoryRoots = rootTaxonomy.subtracting(categoryMap.keys).sorted()
        let extraCategoryRoots = Set(categoryMap.keys).subtracting(rootTaxonomy).sorted()
        let invalidCategories = categoryMap
            .filter { !categoryTaxonomy.contains($0.value) }
            .map { "\($0.key):\($0.value)" }
            .sorted()

        var uncategorizedRecoveryRoots: [String] = []
        for fixture in schemaNextCommandFixtures(includeSubcommands: true) {
            guard let root = tritonRootCommand(in: fixture.argv) else {
                uncategorizedRecoveryRoots.append("\(fixture.context):\(fixture.argv.joined(separator: " "))")
                continue
            }
            if categoryMap[root] == nil {
                uncategorizedRecoveryRoots.append("\(fixture.context):\(root)")
            }
        }

        #expect(missingCategoryRoots == [])
        #expect(extraCategoryRoots == [])
        #expect(invalidCategories == [])
        #expect(uncategorizedRecoveryRoots == [])
    }

    @Test("schema recovery commands mirror next commands and expose categories")
    func schemaRecoveryCommandsMirrorNextCommandsAndExposeCategories() {
        var mismatchedCommandLists: [String] = []
        var invalidCategories: [String] = []

        #expect(TKCommandRecoveryCommand.rootCommandTaxonomy == recoveryCommandRootTaxonomy())
        #expect(TKCommandRecoveryCommand.categoryTaxonomy == recoveryCommandCategoryTaxonomy())

        for schema in commandSchemas() {
            validateRecoveryCommands(
                schema.recoveryCommands,
                nextCommands: schema.nextCommands,
                context: schema.name,
                mismatchedCommandLists: &mismatchedCommandLists,
                invalidCategories: &invalidCategories
            )

            for subcommand in schema.subcommands {
                validateRecoveryCommands(
                    subcommand.recoveryCommands,
                    nextCommands: subcommand.nextCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    mismatchedCommandLists: &mismatchedCommandLists,
                    invalidCategories: &invalidCategories
                )
            }
        }

        #expect(mismatchedCommandLists == [])
        #expect(invalidCategories == [])
    }

    @Test("schema failure codes map to recovery category families")
    func schemaFailureCodesMapToRecoveryCategoryFamilies() {
        var unmappedFailureCodes: [String] = []
        var invalidRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateFailureCodes(
                schema.failureCodes,
                context: schema.name,
                unmappedFailureCodes: &unmappedFailureCodes,
                invalidRecoveryCategories: &invalidRecoveryCategories
            )

            for subcommand in schema.subcommands {
                validateFailureCodes(
                    subcommand.failureCodes,
                    context: "\(schema.name) \(subcommand.name)",
                    unmappedFailureCodes: &unmappedFailureCodes,
                    invalidRecoveryCategories: &invalidRecoveryCategories
                )
            }
        }

        #expect(unmappedFailureCodes == [])
        #expect(invalidRecoveryCategories == [])
    }

    @Test("artifact failure codes expose archive recovery categories")
    func artifactFailureCodesExposeArchiveRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateArtifactFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateArtifactFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("assertion failure codes expose verify recovery categories")
    func assertionFailureCodesExposeVerifyRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateAssertionFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateAssertionFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("runtime transport failure codes expose diagnose recovery categories")
    func runtimeTransportFailureCodesExposeDiagnoseRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateRuntimeTransportFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateRuntimeTransportFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("target failure codes expose prepare target recovery categories")
    func targetFailureCodesExposePrepareTargetRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateTargetFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateTargetFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("project failure codes expose project recovery categories")
    func projectFailureCodesExposeProjectRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateProjectFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateProjectFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("action failure codes expose act recovery categories")
    func actionFailureCodesExposeActRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateActionFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateActionFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("destructive policy failure codes expose plan recovery categories")
    func destructivePolicyFailureCodesExposePlanRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateDestructivePolicyFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateDestructivePolicyFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("unsupported failure codes expose plan recovery categories")
    func unsupportedFailureCodesExposePlanRecoveryCategories() {
        var missingRecoveryCategories: [String] = []

        for schema in commandSchemas() {
            validateUnsupportedFailureRecovery(
                schema.failureCodes,
                recoveryCommands: schema.recoveryCommands,
                context: schema.name,
                missingRecoveryCategories: &missingRecoveryCategories
            )

            for subcommand in schema.subcommands {
                let recoveryCommands = subcommand.recoveryCommands.isEmpty ?
                    schema.recoveryCommands :
                    subcommand.recoveryCommands
                validateUnsupportedFailureRecovery(
                    subcommand.failureCodes,
                    recoveryCommands: recoveryCommands,
                    context: "\(schema.name) \(subcommand.name)",
                    missingRecoveryCategories: &missingRecoveryCategories
                )
            }
        }

        #expect(missingRecoveryCategories == [])
    }

    @Test("schema examples contain one Triton invocation for agent reuse")
    func schemaExamplesContainOneTritonInvocationForAgentReuse() {
        let invalidExamples = schemaExampleCommandFixtures()
            .filter { tritonInvocationCount(in: $0.command) != 1 }
            .map { "\($0.context):\($0.command)" }
            .sorted()

        #expect(invalidExamples == [])
    }

    @Test("schema provided capabilities expose planning metadata")
    func schemaProvidedCapabilitiesExposePlanningMetadata() throws {
        let schemaCapabilities = Set(commandSchemas().flatMap(\.providedCapabilities))
        let connected = connectedCapabilityMap()

        var missingGroup: [String] = []
        var miscGroup: [String] = []
        var missingNextAction: [String] = []
        var missingEvidence: [String] = []

        for capabilityName in schemaCapabilities.sorted() {
            let capability = try #require(connected[capabilityName])
            if capability.group == nil {
                missingGroup.append(capabilityName)
            }
            if capability.group == "misc" {
                miscGroup.append(capabilityName)
            }
            if capability.nextAction == nil {
                missingNextAction.append(capabilityName)
            }
            if capability.evidence.isEmpty {
                missingEvidence.append(capabilityName)
            }
        }

        #expect(missingGroup == [])
        #expect(miscGroup == [])
        #expect(missingNextAction == [])
        #expect(missingEvidence == [])
    }

    @Test("capability next actions stay aligned with command schemas")
    func capabilityNextActionsStayAlignedWithCommandSchemas() throws {
        let schemas = commandSchemaMap()
        let capabilities = connectedCapabilities()

        var issues = SchemaBackedCommandIssues()

        for capability in capabilities.sorted(by: { $0.name < $1.name }) {
            guard let nextAction = capability.nextAction else { continue }
            validateSchemaBackedNextAction(
                nextAction.command,
                args: nextAction.args,
                context: capability.name,
                schemas: schemas,
                issues: &issues
            )
        }

        expectNoSchemaBackedCommandIssues(issues)
    }

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
        expectContract(wait, selector: "host.android-wait", fields: [
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
        expectContract(tap, selector: "host.android-tap", fields: [
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
        expectContract(press, selector: "host.android-key-action", fields: [
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
        #expect(evidence.nextCommands.contains("triton evidence summary <dir.tritonevidence> --json"))
        #expect(Set(evidence.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(evidence, selector: "evidence.manifest", fields: [
            "ok", "formatVersion", "output", "artifacts", "primaryArtifact", "primaryArtifacts", "skipped", "target", "cli", "run",
        ])
        expectContract(evidence, selector: "evidence.summary", fields: [
            "ok", "action", "input", "profile", "output", "artifactCount", "sensitiveArtifactCount", "artifacts", "primaryArtifact", "primaryArtifacts", "suggestedCommands",
        ])
        expectContract(evidence, selector: "evidence.redact", fields: [
            "ok", "action", "input", "output", "profile", "artifactCount", "redactedArtifactCount", "manifest", "primaryArtifact", "primaryArtifacts", "summaryPath", "suggestedCommands",
        ])

        #expect(capture.failureCodes.contains("validation_failed"))
        #expect(capture.artifacts.contains("evidence-bundle"))
        #expect(capture.nextCommands.contains("triton evidence summary <dir.tritonevidence> --json"))
        #expect(Set(capture.providedCapabilities).isSubset(of: connectedCapabilityNames))
        expectContract(capture, selector: "evidence.manifest", fields: [
            "ok", "formatVersion", "output", "artifacts", "primaryArtifact", "primaryArtifacts", "skipped", "target", "cli", "run",
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
            "capabilities", "semanticDomains", "semanticDomains[].domain", "semanticDomains[].source",
            "semanticDomains[].confidence", "semanticDomains[].schema", "semanticDomains[].actions",
            "semanticDomains[].redaction", "limits", "redaction",
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
            "route", "responder", "media", "geometry", "ax", "screenshot", "artifacts", "skipped", "truncation",
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
        expectContract(ax, selector: "host.android-ax", fields: [
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
        expectContract(screenshot, selector: "host.android-screenshot", fields: [
            "ok", "action", "platform", "target", "artifact", "sourceCommands", "note",
        ])
        #expect(screenshot.providedCapabilities.contains("android-device-screenshot"))
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
            "ok", "platform", "targets",
            "targets[].appName", "targets[].bundleIdentifier", "targets[].identityState", "targets[].current",
            "defaultTarget", "sourceCommand",
        ])
        expectContract(device, selector: "host.device-selection", fields: [
            "ok", "platform", "target", "defaultsPath", "selection",
        ])
        expectContract(device, selector: "host.device-ready", fields: [
            "ok", "platform", "target", "ready", "attempt", "sourceCommand", "error",
        ])
        expectContract(device, selector: "host.android-device", fields: [
            "ok", "platform", "targets", "defaultTarget", "sourceCommand",
        ])

        #expect(sim.failureCodes.contains("simulator_not_found"))
        #expect(sim.failureCodes.contains("host_command_failed"))
        #expect(sim.failureCodes.contains("unsupported_host_input"))
        #expect(sim.failureCodes.contains("unsupported_text_input"))
        #expect(sim.artifacts.contains("simulator-screenshot"))
        #expect(sim.nextCommands.contains("triton sim use <udid> --json"))
        #expect(sim.providedCapabilities.contains("ios-simulator-host-tap"))
        #expect(sim.providedCapabilities.contains("ios-simulator-host-type"))
        let simTap = try #require(sim.subcommands.first(where: { $0.name == "tap" }))
        #expect(simTap.requiredOptions == ["--x", "--y"])
        #expect(simTap.optionalOptions.contains("--simulator"))
        #expect(simTap.outputSelectors == ["host.simulator-input"])
        #expect(simTap.failureCodes.contains("unsupported_host_input"))
        let simType = try #require(sim.subcommands.first(where: { $0.name == "type" }))
        #expect(simType.requiredOptions == ["--text"])
        #expect(simType.optionalOptions.contains("--simulator"))
        #expect(simType.outputSelectors == ["host.simulator-input"])
        #expect(simType.failureCodes.contains("unsupported_host_input"))
        #expect(simType.failureCodes.contains("unsupported_text_input"))
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
        expectContract(sim, selector: "host.simulator-input", fields: [
            "ok", "action", "runtimeScope", "target", "adapter", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated", "textEncoding", "note",
        ])

        #expect(app.failureCodes.contains("app_launch_failed"))
        #expect(app.failureCodes.contains("host_open_url_failed"))
        #expect(app.nextCommands.contains("triton app go <url>"))
        expectContract(app, selector: "host.app-action", fields: [
            "ok", "action", "runtimeScope", "target", "selection", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated", "artifacts", "note",
        ])
        expectContract(app, selector: "host.android-app-inspect", fields: [
            "ok", "action", "simulatorUDID", "bundleID", "app",
        ])
        expectContract(app, selector: "host.android-app-install", fields: [
            "ok", "action", "runtimeScope", "target", "selection", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated", "artifacts", "note",
        ])
        expectContract(app, selector: "host.android-app-launch", fields: [
            "ok", "action", "runtimeScope", "target", "selection", "tool", "exitCode",
            "riskLevel", "sourceCommand", "stdoutTruncated", "stderrTruncated", "artifacts", "note",
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

private func expectContract(
    _ schema: TKCommandSchema,
    selector: String,
    fields expectedFields: [String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let contract = schema.outputContracts.first { $0.selector == selector }
    #expect(contract != nil, sourceLocation: sourceLocation)
    let fieldNames = contract?.fields.map(\.name) ?? []
    for expectedField in expectedFields {
        #expect(fieldNames.contains(expectedField), "Missing \(selector).\(expectedField)", sourceLocation: sourceLocation)
    }
}

private struct SchemaBackedCommandIssues {
    var unknownCommands: [String] = []
    var unknownSubcommands: [String] = []
    var unknownFlags: [String] = []
}

private struct CommandStringFixture {
    let context: String
    let command: String
    let argv: [String]
    let isSubcommand: Bool

    init(context: String, command: String, argv: [String], isSubcommand: Bool = false) {
        self.context = context
        self.command = command
        self.argv = argv
        self.isSubcommand = isSubcommand
    }
}

private func commandSchemaMap() -> [String: TKCommandSchema] {
    Dictionary(uniqueKeysWithValues: commandSchemas().map { ($0.name, $0) })
}

private func capabilityGroupTaxonomy() -> Set<String> {
    [
        "action", "assert", "bootstrap", "evidence", "host", "observe", "semantic",
        "replay", "route", "runtime", "smoke", "target", "webview", "xcode",
    ]
}

private func capabilityWorkflowTaxonomy() -> Set<String> {
    [
        "action", "app", "assert", "evidence", "observe", "project",
        "replay", "route", "runtime", "smoke", "target", "webview-check", "xcode",
    ]
}

private func capabilityEvidenceTaxonomy() -> Set<String> {
    [
        "action-result", "assert.result", "bridge-call-result", "command-schema",
        "coverage", "evidence-bundle", "host-artifact", "host-command-json",
        "host-layout", "host-targets.json", "hierarchy-node", "input.result",
        "page-events", "provider-url", "route-assertion", "runtime-ax",
        "runtime-ledger", "runtime-manifest", "runtime-provider",
        "provider-action-catalog", "provider-state", "runtime-media", "runtime-samples",
        "runtime-semantic", "runtime-snapshot", "screenshot", "screenshot-metadata",
        "smoke-summary", "snapshot-json", "status-json", "stdout-json",
        "surface-tree", "target.resolution", "trace", "tritonplan",
        "unsupported-envelope", "wait.result", "wait-samples", "webview-candidates",
        "webview-provider", "webview-snapshot", "xcodebuild-json", "xcresult",
    ]
}

private func outputContractFormatTaxonomy() -> Set<String> {
    ["json", "jsonl", "archive"]
}

private func outputContractKindTaxonomy() -> Set<String> {
    [
        "artifact-envelope",
        "assert-result",
        "ax-node-list",
        "capability-matrix",
        "command-schema-list",
        "diagnostic-checks",
        "envelope",
        "evidence-manifest",
        "export-archive",
        "final-event",
        "hierarchy-info",
        "hierarchy-node",
        "hierarchy-node-list",
        "hit-test-result",
        "host-action",
        "host-app-open-url-flow",
        "host-artifact",
        "host-device-list",
        "host-device-ready",
        "host-device-selection",
        "host-simulator-list",
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
        "simulator-screenshot",
        "runtime-snapshot",
        "runtime-state",
        "screenshot-metadata",
        "semantic-action-result",
        "smoke-result",
        "status-envelope",
        "target-list",
        "target-resolution",
        "target-summary",
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

private func commandOutputFormatTaxonomy() -> Set<String> {
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

private func recoveryCommandRootTaxonomy() -> Set<String> {
    [
        "app",
        "assert",
        "attrs",
        "ax",
        "capabilities",
        "capture",
        "clear",
        "coverage",
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
        "type",
        "wait",
        "webview",
        "xcode",
        "xcresult",
        "xctrace",
    ]
}

private func recoveryCommandCategoryTaxonomy() -> Set<String> {
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

private func recoveryCommandRootCategoryMap() -> [String: String] {
    [
        "app": "prepare-target",
        "assert": "verify",
        "attrs": "observe",
        "ax": "observe",
        "capabilities": "diagnose",
        "capture": "archive",
        "clear": "act",
        "coverage": "archive",
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
        "type": "act",
        "wait": "verify",
        "webview": "observe",
        "xcode": "project",
        "xcresult": "archive",
        "xctrace": "archive",
    ]
}

private func collectRecoveryCommandListIssues(
    _ commands: [String],
    context: String,
    blank: inout [String],
    duplicate: inout [String]
) {
    for command in commands where command.allSatisfy(\.isWhitespace) {
        blank.append(context)
    }

    let duplicates = Set(commands)
        .filter { command in commands.filter { $0 == command }.count > 1 }
        .sorted()
    duplicate.append(contentsOf: duplicates.map { "\(context):\($0)" })
}

private func validateRecoveryCommands(
    _ recoveryCommands: [TKCommandRecoveryCommand],
    nextCommands: [String],
    context: String,
    mismatchedCommandLists: inout [String],
    invalidCategories: inout [String]
) {
    if recoveryCommands.map(\.command) != nextCommands {
        mismatchedCommandLists.append(context)
    }

    for recoveryCommand in recoveryCommands {
        guard let root = TKCommandRecoveryCommand.rootCommand(in: recoveryCommand.command),
              let expectedCategory = TKCommandRecoveryCommand.category(forRootCommand: root) else {
            invalidCategories.append("\(context):\(recoveryCommand.command)")
            continue
        }
        if recoveryCommand.category != expectedCategory {
            invalidCategories.append("\(context):\(recoveryCommand.command):\(recoveryCommand.category)")
        }
    }
}

private func validateFailureCodes(
    _ failureCodes: [String],
    context: String,
    unmappedFailureCodes: inout [String],
    invalidRecoveryCategories: inout [String]
) {
    for failureCode in failureCodes {
        guard let expectedCategories = recoveryCategories(forFailureCode: failureCode) else {
            unmappedFailureCodes.append("\(context):\(failureCode)")
            continue
        }
        invalidRecoveryCategories.append(
            contentsOf: expectedCategories
                .filter { !TKCommandRecoveryCommand.categoryTaxonomy.contains($0) }
                .sorted()
                .map { "\(context):\(failureCode):\($0)" }
        )
    }
}

private func validateArtifactFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forArtifactFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forArtifactFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "artifact_output_rejected", "artifact_write_failed", "file_write_failed", "overwrite_refused", "xcresult_output_too_large":
        return ["archive"]
    default:
        return nil
    }
}

private func validateAssertionFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forAssertionFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forAssertionFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "assertion_failed", "route_mismatch", "text_not_found":
        return ["verify"]
    default:
        return nil
    }
}

private func validateRuntimeTransportFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forRuntimeTransportFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forRuntimeTransportFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "server_unavailable", "request_failed", "request_timeout", "runtime_unavailable", "runtime_not_connected":
        return ["diagnose"]
    default:
        return nil
    }
}

private func validateTargetFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forTargetFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forTargetFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "ambiguous_target", "device_not_ready", "simulator_not_found", "target_not_found", "target_offline", "target_unavailable":
        return ["prepare-target"]
    default:
        return nil
    }
}

private func validateProjectFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forProjectFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forProjectFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "ambiguous_workspace", "invalid_workspace_path", "scheme_not_found", "workspace_not_found", "xcode_not_idle":
        return ["project"]
    default:
        return nil
    }
}

private func validateActionFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forActionFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forActionFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "action_failed", "step_failed":
        return ["act"]
    default:
        return nil
    }
}

private func validateDestructivePolicyFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forDestructivePolicyFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forDestructivePolicyFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "confirmation_required", "destructive_action_requires_policy":
        return ["plan"]
    default:
        return nil
    }
}

private func validateUnsupportedFailureRecovery(
    _ failureCodes: [String],
    recoveryCommands: [TKCommandRecoveryCommand],
    context: String,
    missingRecoveryCategories: inout [String]
) {
    let availableCategories = Set(recoveryCommands.map(\.category))

    for failureCode in failureCodes {
        guard let requiredCategories = requiredRecoveryCategories(forUnsupportedFailureCode: failureCode) else {
            continue
        }
        if availableCategories.isDisjoint(with: requiredCategories) {
            missingRecoveryCategories.append(
                "\(context):\(failureCode):required=\(requiredCategories.sorted().joined(separator: "|")):available=\(availableCategories.sorted().joined(separator: "|"))"
            )
        }
    }
}

private func requiredRecoveryCategories(forUnsupportedFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "action_not_supported", "unsupported_capability", "unsupported_runtime_scope", "webview_method_not_allowed", "webview_wait_unsupported":
        return ["plan"]
    default:
        return nil
    }
}

private func recoveryCategories(forFailureCode failureCode: String) -> Set<String>? {
    switch failureCode {
    case "ambiguous_target", "android_target_unauthorized", "device_not_ready", "simulator_not_found", "target_not_found", "target_unavailable":
        return ["discover", "prepare-target", "diagnose"]
    case "ambiguous_workspace", "invalid_workspace_path", "scheme_not_found", "workspace_not_found", "xcode_not_idle":
        return ["project", "diagnose"]
    case "assertion_failed", "route_mismatch", "text_not_found", "timeout":
        return ["verify", "observe", "archive"]
    case "artifact_write_failed", "file_write_failed", "overwrite_refused":
        return ["archive", "diagnose"]
    case "action_failed", "step_failed":
        return ["act", "observe", "verify", "archive"]
    case "confirmation_required", "destructive_action_requires_policy":
        return ["diagnose", "plan", "act"]
    case "javascript_error":
        return ["diagnose", "observe", "archive"]
    case "runtime_not_connected":
        return ["diagnose", "prepare-target", "observe"]
    case "validation_failed", "unknown_command_schema":
        return ["diagnose", "plan", "discover", "observe", "archive"]
    default:
        if failureCode.hasPrefix("ambiguous_") {
            return ["discover", "observe", "prepare-target", "diagnose"]
        }
        if failureCode.hasPrefix("invalid_") {
            return ["diagnose", "project", "plan"]
        }
        if failureCode.hasPrefix("missing_") {
            return ["diagnose", "project", "observe"]
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
        if failureCode.hasSuffix("_unsupported") {
            return ["diagnose", "plan"]
        }
        return nil
    }
}

private func schemaArtifactTaxonomy() -> Set<String> {
    [
        "app-container",
        "app-preferences",
        "ax",
        "coverage-json",
        "evidence-bundle",
        "export-archive",
        "geometry",
        "harmony-layout",
        "hierarchy",
        "hierarchy-json",
        "host-artifacts",
        "logs",
        "manifest",
        "none-inline-summary",
        "result-bundle",
        "runtime-ledger",
        "runtime-snapshot",
        "screenshot",
        "screenshots",
        "simulator-diagnostics",
        "simulator-logs",
        "simulator-screenshot",
        "simulator-video",
        "stderr-log",
        "stdout-log",
        "trace",
        "triton-plan",
        "xcode-artifacts",
    ]
}

private func expectNoSchemaBackedCommandIssues(
    _ issues: SchemaBackedCommandIssues,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(issues.unknownCommands == [], sourceLocation: sourceLocation)
    #expect(issues.unknownSubcommands == [], sourceLocation: sourceLocation)
    #expect(issues.unknownFlags == [], sourceLocation: sourceLocation)
}

private func isMachineReadableSchemaType(_ type: String) -> Bool {
    guard !type.isEmpty, !type.contains(where: \.isWhitespace) else {
        return false
    }

    let nonOptional = type.hasSuffix("?") ? String(type.dropLast()) : type
    if nonOptional.contains("|") {
        return nonOptional
            .split(separator: "|", omittingEmptySubsequences: false)
            .allSatisfy { isMachineReadableSchemaType(String($0)) }
    }
    if nonOptional.hasPrefix("[") || nonOptional.hasSuffix("]") {
        guard nonOptional.hasPrefix("["), nonOptional.hasSuffix("]") else {
            return false
        }
        let inner = String(nonOptional.dropFirst().dropLast())
        if inner.contains(":") {
            let keyValue = inner.split(separator: ":", omittingEmptySubsequences: false)
            return keyValue.count == 2 && keyValue.allSatisfy { isSchemaTypeUnion(String($0)) }
        }
        return isSchemaTypeUnion(inner)
    }
    return isSchemaTypeUnion(nonOptional)
}

private func isSchemaTypeUnion(_ type: String) -> Bool {
    let parts = type.split(separator: "|", omittingEmptySubsequences: false)
    guard !parts.isEmpty else {
        return false
    }
    return parts.allSatisfy { part in
        guard let first = part.first, first.isLetter else {
            return false
        }
        return part.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_"
        }
    }
}

private func isAgentSelectorKey(_ key: String) -> Bool {
    let parts = key.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty else {
        return false
    }
    return parts.allSatisfy { isKebabCaseKey(String($0)) }
}

private func isAgentEventKey(_ key: String, allowingPlaceholders: Bool) -> Bool {
    let parts = key.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count >= 2 else {
        return false
    }
    return parts.allSatisfy { part in
        let value = String(part)
        return isKebabCaseKey(value) || (allowingPlaceholders && isCompletePlaceholderToken(value))
    }
}

private func isPlanMetadataKey(_ key: String) -> Bool {
    let parts = key.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty else {
        return false
    }
    return parts.allSatisfy { isKebabCaseKey(String($0)) }
}

private func isKebabCaseKey(_ key: String) -> Bool {
    guard let first = key.first, first.isLowercase else {
        return false
    }
    return key.allSatisfy { character in
        character.isLowercase || character.isNumber || character == "-"
    }
}

private func isSnakeCaseKey(_ key: String) -> Bool {
    guard let first = key.first, first.isLowercase else {
        return false
    }
    return key.allSatisfy { character in
        character.isLowercase || character.isNumber || character == "_"
    }
}

private func isLongOptionKeyExpression(_ key: String) -> Bool {
    let aliases = key.split(separator: "/", omittingEmptySubsequences: false)
    guard !aliases.isEmpty else {
        return false
    }
    return aliases.allSatisfy { alias in
        alias.hasPrefix("--") && isKebabCaseKey(String(alias.dropFirst(2)))
    }
}

private func validateSchemaBackedCommandExpression(
    _ commandString: String,
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    guard let argv = extractSingleTritonInvocationArgv(from: commandString) else {
        issues.unknownCommands.append("\(context): \(commandString)")
        return
    }
    validateSchemaBackedArgv(argv, context: context, schemas: schemas, issues: &issues)
}

private func validateSchemaBackedArgv(
    _ argv: [String],
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    guard argv.first == "triton", argv.count >= 2 else {
        issues.unknownCommands.append("\(context): \(argv.joined(separator: " "))")
        return
    }
    validateSchemaBackedCommand(
        commandName: argv[1],
        args: Array(argv.dropFirst(2)),
        context: context,
        schemas: schemas,
        issues: &issues
    )
}

private func validateSchemaBackedNextAction(
    _ commandName: String,
    args: [String],
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    validateSchemaBackedArgv(["triton", commandName] + args, context: context, schemas: schemas, issues: &issues)
}

private func tritonRootCommand(in commandString: String) -> String? {
    let tokens = commandString.split(separator: " ").map(String.init)
    guard let tritonIndex = tokens.firstIndex(of: "triton"), tokens.count > tritonIndex + 1 else {
        return nil
    }
    return tokens[tritonIndex + 1]
}

private func tritonRootCommand(in argv: [String]) -> String? {
    guard argv.first == "triton", argv.count >= 2 else {
        return nil
    }
    return argv[1]
}

private func tritonInvocationCount(in commandString: String) -> Int {
    commandString.split(separator: " ").filter { $0 == "triton" }.count
}

private func validateSchemaBackedCommand(
    commandName: String,
    args: [String],
    context: String,
    schemas: [String: TKCommandSchema],
    issues: inout SchemaBackedCommandIssues
) {
    guard let schema = schemas[commandName] else {
        issues.unknownCommands.append("\(context): \(commandName)")
        return
    }

    if let subcommand = args.first, !subcommand.hasPrefix("-"), !schema.subcommands.isEmpty {
        if !schema.subcommands.contains(where: { $0.name == subcommand }) {
            issues.unknownSubcommands.append("\(context): \(commandName) \(subcommand)")
        }
    }

    let knownFlags = schemaKnownFlags(schema)
    for flag in args where flag.hasPrefix("--") {
        if !knownFlags.contains(flag) {
            issues.unknownFlags.append("\(context): \(commandName) \(flag)")
        }
    }
}

private func schemaNextCommandFixtures(includeSubcommands: Bool) -> [CommandStringFixture] {
    commandSchemas().flatMap { schema -> [CommandStringFixture] in
        var fixtures: [CommandStringFixture] = []
        for command in schema.nextCommands {
            guard let argv = extractSingleTritonInvocationArgv(from: command) else {
                continue
            }
            fixtures.append(CommandStringFixture(context: schema.name, command: command, argv: argv))
        }
        if includeSubcommands {
            fixtures.append(contentsOf: schema.subcommands.flatMap { subcommand -> [CommandStringFixture] in
                var subcommandFixtures: [CommandStringFixture] = []
                for command in subcommand.nextCommands {
                    guard let argv = extractSingleTritonInvocationArgv(from: command) else {
                        continue
                    }
                    subcommandFixtures.append(CommandStringFixture(
                        context: "\(schema.name) \(subcommand.name)",
                        command: command,
                        argv: argv,
                        isSubcommand: true
                    ))
                }
                return subcommandFixtures
            })
        }
        return fixtures
    }
}

private func schemaExampleCommandFixtures() -> [CommandStringFixture] {
    commandSchemas().flatMap { schema in
        schema.examples.compactMap { command -> CommandStringFixture? in
            guard let argv = extractSingleTritonInvocationArgv(from: command) else {
                return nil
            }
            return CommandStringFixture(context: "\(schema.name)/example", command: command, argv: argv)
        }
    }
}

private func workflowPlanCommandFixtures(includeTaskInputs: Bool) -> [CommandStringFixture] {
    workflowPlanFixtures(includeTaskInputs: includeTaskInputs).flatMap { plan in
        (plan.steps + plan.afterRecoverySteps).map {
            CommandStringFixture(
                context: "\(plan.goal ?? "general"):\($0.id)",
                command: $0.command,
                argv: $0.argv
            )
        }
    }
}

private func workflowPlanFixtures(includeTaskInputs: Bool) -> [TKWorkflowPlanResponse] {
    let disconnected = TKCapabilitiesResponse(
        ok: false,
        serverReachable: false,
        connected: false,
        latestHierarchyAvailable: false,
        targetCount: 0,
        runtime: "unknown",
        capabilities: []
    )
    let targetMissing = TKCapabilitiesResponse(
        ok: true,
        serverReachable: true,
        connected: false,
        latestHierarchyAvailable: false,
        targetCount: 0,
        runtime: "none",
        capabilities: []
    )
    let connected = TKCapabilitiesResponse(
        ok: true,
        serverReachable: true,
        connected: true,
        latestHierarchyAvailable: true,
        targetCount: 1,
        runtime: "embedded",
        capabilities: []
    )

    return [
        buildWorkflowPlan(capabilities: disconnected, host: "127.0.0.1", port: 19421),
        buildWorkflowPlan(capabilities: targetMissing, host: "127.0.0.1", port: 19421),
        buildWorkflowPlan(capabilities: connected, host: "127.0.0.1", port: 19421),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "ios-smoke",
                device: includeTaskInputs ? "iphone15" : nil,
                bundleID: includeTaskInputs ? "com.example.app" : nil,
                url: includeTaskInputs ? "myapp://smoke" : nil,
                text: includeTaskInputs ? "Home" : nil,
                expectedURL: nil,
                evidence: includeTaskInputs ? "/tmp/smoke.tritonevidence" : nil
            )
        ),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "open-url",
                device: includeTaskInputs ? "iphone15" : nil,
                bundleID: nil,
                url: includeTaskInputs ? "myapp://detail" : nil,
                text: includeTaskInputs ? "Ready" : nil,
                expectedURL: nil,
                evidence: includeTaskInputs ? "/tmp/open-url.tritonevidence" : nil
            )
        ),
        buildWorkflowPlan(
            capabilities: connected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "webview-check",
                device: nil,
                bundleID: nil,
                url: nil,
                text: includeTaskInputs ? "Loaded" : nil,
                expectedURL: includeTaskInputs ? "https://example.com" : nil,
                evidence: includeTaskInputs ? "/tmp/webview.tritonevidence" : nil
            )
        ),
    ]
}

private func capabilityStateFixtures() -> [(name: String, capabilities: [TKRuntimeCapability])] {
    [
        (
            name: "server-unreachable",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: false,
                connected: false
            )
        ),
        (
            name: "runtime-disconnected",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: true,
                connected: false
            )
        ),
        (
            name: "runtime-connected",
            capabilities: runtimeCapabilities(
                host: "127.0.0.1",
                port: 19421,
                serverReachable: true,
                connected: true
            )
        ),
    ]
}

private func capabilityMap(state name: String) -> [String: TKRuntimeCapability] {
    Dictionary(uniqueKeysWithValues: capabilityStateFixtures()
        .first { $0.name == name }?
        .capabilities
        .map { ($0.name, $0) } ?? []
    )
}

private func disconnectedCapabilityMap() -> [String: TKRuntimeCapability] {
    capabilityMap(state: "runtime-disconnected")
}

private func unavailableServerCapabilityMap() -> [String: TKRuntimeCapability] {
    capabilityMap(state: "server-unreachable")
}

private func connectedCapabilities() -> [TKRuntimeCapability] {
    capabilityStateFixtures()
        .first { $0.name == "runtime-connected" }?
        .capabilities ?? []
}

private func connectedCapabilityMap() -> [String: TKRuntimeCapability] {
    Dictionary(uniqueKeysWithValues: connectedCapabilities().map { ($0.name, $0) })
}

private func assertCapability(
    _ capabilities: [String: TKRuntimeCapability],
    name: String,
    supported: Bool,
    group: String? = nil,
    requiredByContains: [String] = [],
    requiredByExact: [String]? = nil,
    evidence: [String]? = nil,
    nextActionCommand: String,
    nextActionArgs: [String],
    longRunning: Bool? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let capability = try #require(capabilities[name], sourceLocation: sourceLocation)
    #expect(capability.supported == supported, sourceLocation: sourceLocation)
    if let group {
        #expect(capability.group == group, sourceLocation: sourceLocation)
    }
    if let requiredByExact {
        #expect(capability.requiredBy == requiredByExact, sourceLocation: sourceLocation)
    } else {
        for workflow in requiredByContains {
            #expect(capability.requiredBy.contains(workflow), sourceLocation: sourceLocation)
        }
    }
    if let evidence {
        #expect(capability.evidence == evidence, sourceLocation: sourceLocation)
    }
    #expect(capability.nextAction?.command == nextActionCommand, sourceLocation: sourceLocation)
    #expect(capability.nextAction?.args == nextActionArgs, sourceLocation: sourceLocation)
    if let longRunning {
        #expect(capability.nextAction?.requiresLongRunningProcess == longRunning, sourceLocation: sourceLocation)
    }
}

private func schemaKnownFlags(_ schema: TKCommandSchema) -> Set<String> {
    var flags = Set<String>()
    for option in schema.options {
        flags.formUnion(flagNames(from: option.name))
    }
    for subcommand in schema.subcommands {
        for option in subcommand.requiredOptions {
            flags.formUnion(flagNames(from: option))
        }
        for option in subcommand.optionalOptions {
            flags.formUnion(flagNames(from: option))
        }
        for options in subcommand.oneOfRequiredOptions {
            for option in options {
                flags.formUnion(flagNames(from: option))
            }
        }
    }
    return flags
}

private func schemaKnownParameterKeys(_ schema: TKCommandSchema) -> Set<String> {
    var keys = Set<String>()
    for option in schema.options {
        keys.formUnion(flagNames(from: option.name))
    }
    for argument in schema.argumentForms {
        keys.insert(argument.name)
    }
    return keys
}

private func flagNames(from optionName: String) -> [String] {
    optionName
        .split(separator: "|")
        .flatMap { $0.split(separator: "/") }
        .compactMap { token in
            let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.hasPrefix("--") ? value : nil
        }
}

private func isCompletePlaceholderToken(_ arg: String) -> Bool {
    arg.hasPrefix("<") && arg.hasSuffix(">") && !arg.dropFirst().dropLast().contains("<") && !arg.dropFirst().dropLast().contains(">")
}

private func malformedPlaceholderTokens(in commandString: String, context: String) -> [String] {
    commandString
        .split(separator: " ")
        .map(String.init)
        .filter { $0.contains("<") || $0.contains(">") }
        .filter { !isCompletePlaceholderToken($0) }
        .map { "\(context):\($0)" }
}

private func malformedPlaceholderTokens(in argv: [String], context: String) -> [String] {
    argv
        .filter { $0.contains("<") || $0.contains(">") }
        .filter { !isCompletePlaceholderToken($0) }
        .map { "\(context):\($0)" }
}

private func isSingleTritonInvocation(_ commandString: String) -> Bool {
    let tokens = commandString.split(separator: " ").map(String.init)
    guard tokens.first == "triton" else {
        return false
    }

    let forbiddenTokens: Set<String> = ["|", "&&", "||", ";", "<", ">", ">>", "2>", "2>>"]
    return !tokens.contains(where: { forbiddenTokens.contains($0) || $0.hasPrefix("$(") || $0.hasPrefix("`") })
}

private func extractSingleTritonInvocationArgv(from commandString: String) -> [String]? {
    let tokens = commandString.split(separator: " ").map(String.init)
    guard let tritonIndex = tokens.firstIndex(of: "triton") else {
        return nil
    }

    let stopTokens: Set<String> = ["|", "&&", "||", ";", "<", ">", ">>", "2>", "2>>"]
    var argv: [String] = []
    for token in tokens[tritonIndex...] {
        if stopTokens.contains(token) || token.hasPrefix("$(") || token.hasPrefix("`") {
            break
        }
        argv.append(token)
    }
    return argv.count >= 2 ? argv : nil
}
