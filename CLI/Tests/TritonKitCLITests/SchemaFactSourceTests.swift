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
        #expect(status.failureShape?.contains("surface: status") == true)
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
        #expect(plan.usageForms.contains(where: { $0.form == "ios-smoke" }))
        #expect(plan.usageForms.contains(where: { $0.form == "open-url" }))
        #expect(plan.usageForms.contains(where: { $0.form == "webview-check" }))
        expectContract(plan, selector: "plan.next-steps", fields: [
            "ok", "serverReachable", "connected", "runtime", "surface", "mode", "goal", "nextStep", "nextWorkflows", "primaryWorkflowCategory", "primaryExpectedArtifact", "primaryNextAction", "primaryNextActionSource",
            "primaryNextAction.command", "primaryNextAction.args", "primaryNextAction.category", "primaryNextAction.requiresLongRunningProcess", "steps", "afterRecoverySteps", "error",
            "steps[].id", "steps[].command", "steps[].argv", "steps[].category", "steps[].workflowCategories", "steps[].requires",
            "steps[].expectedArtifacts", "steps[].stopConditions",
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

    @Test("xcode schema exposes DerivedData cache semantics for incremental builds")
    func xcodeSchemaExposesDerivedDataCacheSemantics() throws {
        let schemas = commandSchemaMap()
        let xcode = try #require(schemas["xcode"])
        let derivedDataOption = try #require(xcode.options.first { $0.name == "--derived-data-path" })

        #expect(derivedDataOption.defaultValue == ".triton/DerivedData")
        #expect(derivedDataOption.description.contains("incremental"))
        #expect(derivedDataOption.description.contains("cleanup"))
        #expect(derivedDataOption.description.contains("Swift macro"))

        expectContract(xcode, selector: "xcode.final", fields: [
            "derivedDataPath",
            "derivedDataCache",
            "derivedDataCache.path",
            "derivedDataCache.exists",
            "derivedDataCache.cacheState",
            "derivedDataCache.incrementalExpected",
            "derivedDataCache.cleanupPolicy",
            "derivedDataCache.guidance",
            "xcodeDiagnostics",
        ])

        #expect(xcode.failureCodes.contains("swift_macro_plugin_malformed_response"))
        #expect(xcode.failureShape?.contains("swift_macro_plugin_malformed_response") == true)
        #expect(xcode.outputContracts.first { $0.selector == "xcode.final" }?.fields.first { $0.name == "xcodeDiagnostics" }?.description.contains("Swift macro") == true)
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
            "ok", "platform", "targets", "defaultTarget", "sourceCommand",
        ])
        expectContract(target, selector: "host.device-selection", fields: [
            "ok", "platform", "current", "target", "defaultsPath", "selection", "path",
        ])
        expectContract(target, selector: "host.device-ready", fields: [
            "ok", "platform", "target", "ready", "attempt", "sourceCommand", "error",
        ])
    }

    @Test("real-device schemas expose machine-readable contracts")
    func realDeviceSchemasExposeMachineReadableContracts() throws {
        let schemas = commandSchemaMap()
        let device = try #require(schemas["device"])
        let app = try #require(schemas["app"])
        let smoke = try #require(schemas["smoke"])
        let evidence = try #require(schemas["evidence"])

        #expect(device.options.map(\.name).contains("--scope"))
        #expect(device.usageForms.map(\.form).contains("list --platform ios|android|harmony --scope real"))
        #expect(device.failureCodes.contains("android_debugging_disabled"))
        #expect(device.failureCodes.contains("android_package_manager_unavailable"))
        expectContract(device, selector: "host.device-list", fields: [
            "targets[].scope", "targets[].kind", "targets[].blockedReasons", "targets[].sensitive",
        ])
        expectContract(device, selector: "host.device-ready", fields: [
            "sourceCommands", "error",
        ])

        #expect(app.options.map(\.name).contains("--scope"))
        #expect(app.usageForms.map(\.form).contains("install --device <selector> --scope real --app|--apk|--hap <path>"))
        #expect(app.usageForms.map(\.form).contains("launch --device <selector> --scope real --bundle-id|--package-name|--bundle <id>"))
        #expect(app.usageForms.map(\.form).contains("open-url <url> --device <selector> --scope real --bundle-id|--package-name|--bundle <id>"))
        #expect(app.failureCodes.contains("unsupported_host_action"))
        #expect(app.failureCodes.contains("runtime_not_connected"))
        #expect(app.failureCodes.contains("harmony_ability_launch_failed"))

        #expect(smoke.options.map(\.name).contains("--scope"))
        #expect(smoke.examples.contains("triton smoke android --device <android-real-target> --scope real --package com.example.app --activity .MainActivity --open-url example://home --wait-text Ready --evidence /tmp/android-real.tritonevidence --json"))
        #expect(smoke.outputSemantics?.contains("proofSource=runtime") == true)
        #expect(smoke.artifacts.contains("real-device.diagnostics"))
        #expect(smoke.artifacts.contains("host.app-action"))
        #expect(smoke.artifacts.contains("runtime.snapshot"))
        #expect(smoke.artifacts.contains("host.layout"))
        expectContract(smoke, selector: "smoke.result", fields: [
            "steps[].proofSource", "steps[].businessReady", "assertions[].proofSource",
        ])

        #expect(evidence.options.first { $0.name == "--include" }?.description.contains("real-device.diagnostics") == true)
        #expect(evidence.artifacts.contains("real-device.diagnostics"))
        #expect(evidence.artifacts.contains("host.app-action"))
        #expect(evidence.artifacts.contains("runtime.snapshot"))
        #expect(evidence.artifacts.contains("host.layout"))
        #expect(evidence.artifacts.contains("build.summary"))
    }

    @Test("app schema exposes host app subcommands used by plans")
    func appSchemaExposesHostAppSubcommandsUsedByPlans() throws {
        let app = try #require(commandSchemaMap()["app"])
        let subcommands = Dictionary(uniqueKeysWithValues: app.subcommands.map { ($0.name, $0) })

        #expect(Set(subcommands.keys).isSuperset(of: [
            "list", "info", "inspect", "install", "uninstall", "launch",
            "terminate", "go", "open-url", "container", "prefs",
        ]))
        #expect(app.argumentForms.map(\.name).contains("<url>"))
        #expect(subcommands["go"]?.requiredOptions == ["<url>"])
        #expect(subcommands["go"]?.outputSelectors == ["host.app-open-url"])
        #expect(subcommands["open-url"]?.requiredOptions == ["<url>"])
        #expect(subcommands["open-url"]?.outputSelectors == ["host.app-open-url"])
        #expect(subcommands["uninstall"]?.oneOfRequiredOptions.contains(["--bundle"]) == true)
        #expect(subcommands["uninstall"]?.optionalOptions.contains("--target") == true)
        #expect(subcommands["uninstall"]?.optionalOptions.contains("--hdc") == true)
    }

    @Test("build schemas expose real-device build contracts")
    func buildSchemasExposeRealDeviceBuildContracts() throws {
        let schemas = commandSchemaMap()
        let xcode = try #require(schemas["xcode"])
        let build = try #require(schemas["build"])

        #expect(xcode.options.map(\.name).contains("--device"))
        #expect(xcode.examples.contains("triton xcode build --device <ios-real-target> --sdk iphoneos --allow-provisioning-updates --jsonl"))
        #expect(xcode.examples.contains("triton xcode run --device <ios-real-target> --sdk iphoneos --jsonl"))
        #expect(xcode.failureCodes.contains("device_not_ready"))
        #expect(xcode.failureCodes.contains("xcode_signing_failed"))
        #expect(xcode.failureCodes.contains("provisioning_profile_missing"))
        expectContract(xcode, selector: "xcode.final", fields: [
            "device",
        ])

        #expect(build.usageForms.map(\.form).contains("android --project <path> --variant debug"))
        #expect(build.usageForms.map(\.form).contains("harmony --project <path> --module entry --mode debug"))
        #expect(build.examples.contains("triton build android --project /tmp/App --variant debug --jsonl"))
        #expect(build.examples.contains("triton build harmony --project /tmp/HarmonyApp --module entry --mode debug --jsonl"))
        #expect(build.failureCodes.contains("gradle_not_found"))
        #expect(build.failureCodes.contains("apk_artifact_not_found"))
        #expect(build.failureCodes.contains("hvigor_not_found"))
        #expect(build.failureCodes.contains("hap_artifact_not_found"))
        #expect(build.failureCodes.contains("harmony_profile_missing"))
        #expect(build.artifacts.contains("build.summary"))
        #expect(build.jsonlEvents.contains("build.<platform>.summary"))
        #expect(build.finalEventKind == "build.<platform>.summary")
        expectContract(build, selector: "build.progress", fields: [
            "ok", "event", "platform", "message", "sourceCommand",
        ])
        expectContract(build, selector: "build.final", fields: [
            "ok", "action", "platform", "project", "variant", "module", "mode",
            "artifact", "artifactKind", "sourceCommand", "exitCode", "durationMs",
            "error", "note",
        ])

        let android = try #require(build.subcommands.first { $0.name == "android" })
        #expect(android.requiredOptions.contains("--project"))
        #expect(android.optionalOptions.contains("--variant"))
        #expect(android.outputSelectors.contains("build.final"))

        let harmony = try #require(build.subcommands.first { $0.name == "harmony" })
        #expect(harmony.requiredOptions.contains("--project"))
        #expect(harmony.optionalOptions.contains("--module"))
        #expect(harmony.optionalOptions.contains("--mode"))
        #expect(harmony.outputSelectors.contains("build.final"))
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
        #expect(evidence.nextAction?.args == ["capture", "--case", "<case>", "--output", "<dir.tritonevidence>", "--json"])
        #expect(evidence.evidence == ["evidence-bundle"])

        let evidenceSummary = try #require(disconnected["evidence-summary"])
        #expect(evidenceSummary.supported)
        #expect(evidenceSummary.nextAction?.args == ["summary", "<dir.tritonevidence>", "--json"])

        let evidenceRedact = try #require(disconnected["evidence-redact"])
        #expect(evidenceRedact.supported)
        #expect(evidenceRedact.nextAction?.args == ["redact", "<dir.tritonevidence>", "--output", "<safe.tritonevidence>", "--json"])

        let evidenceProjectScreens = try #require(disconnected["evidence-project-screens"])
        #expect(evidenceProjectScreens.supported)
        #expect(evidenceProjectScreens.group == "evidence")
        #expect(evidenceProjectScreens.nextAction?.args == ["project-screens", "<dir.tritonevidence>", "--json"])
        #expect(evidenceProjectScreens.evidence == ["evidence-bundle", "screen-workspace"])

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
        #expect(tap.nextAction?.command == "act")
        #expect(tap.nextAction?.args == ["tap", "<query>", "--json"])
        #expect(tap.evidence == ["input.result", "runtime-ledger"])

        let swipe = try #require(connected["swipe"])
        #expect(swipe.nextAction?.command == "act")
        #expect(swipe.nextAction?.args == ["swipe", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"])
        #expect(swipe.evidence == ["input.result", "runtime-ledger"])

        let harmonyTap = try #require(connected["harmony-tap-text"])
        #expect(harmonyTap.group == "action")
        #expect(harmonyTap.requiredBy.contains("action"))
        #expect(harmonyTap.requiredBy.contains("assert"))
        #expect(harmonyTap.nextAction?.command == "act")
        #expect(harmonyTap.nextAction?.args == ["tap", "<text>", "--platform", "harmony", "--json"])
        #expect(harmonyTap.evidence == ["host-command-json", "host-artifact"])

        let harmonyWait = try #require(connected["harmony-wait-text"])
        #expect(harmonyWait.group == "action")
        #expect(harmonyWait.requiredBy.contains("action"))
        #expect(harmonyWait.nextAction?.command == "wait")
        #expect(harmonyWait.nextAction?.args == ["--platform", "harmony", "--text", "<text>", "--json"])
        #expect(harmonyWait.evidence == ["host-command-json", "host-artifact"])

        let harmonyType = try #require(connected["harmony-type-text"])
        #expect(harmonyType.group == "action")
        #expect(harmonyType.requiredBy.contains("action"))
        #expect(harmonyType.nextAction?.command == "act")
        #expect(harmonyType.nextAction?.args == ["type", "<text>", "--platform", "harmony", "--json"])
        #expect(harmonyType.evidence == ["host-command-json", "host-artifact"])

        let harmonyPress = try #require(connected["harmony-press-key"])
        #expect(harmonyPress.group == "action")
        #expect(harmonyPress.requiredBy.contains("action"))
        #expect(harmonyPress.nextAction?.command == "act")
        #expect(harmonyPress.nextAction?.args == ["press", "<button>", "--platform", "harmony", "--json"])
        #expect(harmonyPress.evidence == ["host-command-json", "host-artifact"])

        let clear = try #require(connected["clear"])
        #expect(clear.nextAction?.command == "act")
        #expect(clear.nextAction?.args == ["clear", "--at", "<x,y>", "--json"])

        let harmonyClear = try #require(connected["harmony-clear-text"])
        #expect(!harmonyClear.supported)
        #expect(harmonyClear.group == "action")
        #expect(harmonyClear.requiredBy.contains("action"))
        #expect(harmonyClear.nextAction?.command == "act")
        #expect(harmonyClear.nextAction?.args == ["clear", "--platform", "harmony", "--json"])
        #expect(harmonyClear.evidence == ["unsupported-envelope", "command-schema"])

        let unavailableHarmonyClear = try #require(unavailableServer["harmony-clear-text"])
        #expect(unavailableHarmonyClear.nextAction?.command == "act")
        #expect(unavailableHarmonyClear.nextAction?.args == ["clear", "--platform", "harmony", "--json"])
        #expect(unavailableHarmonyClear.nextAction?.requiresLongRunningProcess != true)

        let input = try #require(connected["input"])
        #expect(input.nextAction?.command == "act")
        #expect(input.nextAction?.args == ["input", "--json", "--summary", "--strict"])
        #expect(input.evidence == ["input.result", "runtime-ledger"])

        let press = try #require(connected["press"])
        #expect(!press.supported)
        #expect(press.nextAction?.command == "schema")
        #expect(press.nextAction?.args == ["--command", "act", "--json"])
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
            ("harmony-tap-text", "act", ["tap", "<text>", "--platform", "harmony", "--json"]),
            ("harmony-wait-text", "wait", ["--platform", "harmony", "--text", "<text>", "--json"]),
            ("harmony-swipe", "act", ["swipe", "--platform", "harmony", "--start-x", "<x1>", "--start-y", "<y1>", "--end-x", "<x2>", "--end-y", "<y2>", "--json"]),
            ("harmony-type-text", "act", ["type", "<text>", "--platform", "harmony", "--json"]),
            ("harmony-paste-text", "act", ["paste", "<text>", "--platform", "harmony", "--json"]),
            ("harmony-clear-text", "act", ["clear", "--platform", "harmony", "--json"]),
            ("harmony-press-key", "act", ["press", "<button>", "--platform", "harmony", "--json"]),
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
            ("node-resolve", true, "observe", ["action", "assert", "evidence"], ["target.resolution", "surface-tree"], "act", ["find", "<text>", "--json"]),
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
        #expect(observeSchema.providedCapabilities == ["observe", "observe-ios", "observe-android", "observe-harmony"])
        let debugSchema = try #require(schemas["debug"])
        #expect(debugSchema.subcommands.map(\.name).contains("node"))

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
            ("observe-android", "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], true, true, "observe", ["tree", "--platform", "android", "--device", "<selector>", "--json"], "observe", ["tree", "--platform", "android", "--device", "<selector>", "--json"]),
            ("observe-harmony", "observe", ["action", "assert", "evidence"], ["surface-tree", "runtime-ax", "host-layout"], true, true, "observe", ["tree", "--platform", "harmony", "--device", "<selector>", "--json"], "observe", ["tree", "--platform", "harmony", "--device", "<selector>", "--json"]),
            ("node", "observe", ["action", "assert", "evidence"], ["hierarchy-node", "surface-tree"], true, false, "debug", ["node", "--oid", "<oid>", "--json"], "status", ["--json"]),
            ("node-resolve", "observe", ["action", "assert", "evidence"], ["target.resolution", "surface-tree"], true, true, "act", ["find", "<text>", "--json"], "act", ["find", "<text>", "--json"]),
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

}
