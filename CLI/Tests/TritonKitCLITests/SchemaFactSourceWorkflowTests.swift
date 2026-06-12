import Testing
import TritonKitShared
@testable import TritonKitCLI

extension SchemaFactSourceTests {
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
        #expect(iosSmoke.steps.first(where: { $0.id == "target-list" })?.workflowCategories == ["action", "app", "assert", "evidence", "observe", "runtime", "smoke", "target"])
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
        #expect(openURL.steps.map(\.id) == ["target-resolve", "app-open-url", "wait-text", "assert-text", "evidence"])
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.workflowCategories == ["app", "assert", "evidence", "target"])
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.command.contains("triton app go") == true)
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.command.contains("--wait-ready") == false)
        #expect(openURL.steps.first(where: { $0.id == "app-open-url" })?.command.contains("--json") == false)

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

        let networkProxy = buildWorkflowPlan(
            capabilities: capabilities,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "network-proxy",
                device: "emulator-5554",
                platform: "android",
                bundleID: nil,
                url: nil,
                text: nil,
                expectedURL: nil,
                evidence: "/tmp/proxy.tritonevidence",
                proxy: "127.0.0.1:19431",
                mode: "mock",
                output: "/tmp/proxy-session",
                certificate: "/tmp/triton-proxy-ca.cer",
                auditRecord: "ticket-123"
            )
        )
        #expect(networkProxy.mode == "task")
        #expect(networkProxy.surface == "plan")
        #expect(networkProxy.goal == "network-proxy")
        #expect(networkProxy.nextStep == "proxy-probe-plan")
        #expect(networkProxy.nextWorkflows == ["evidence", "target"])
        #expect(networkProxy.primaryWorkflowCategory == "target")
        #expect(networkProxy.primaryExpectedArtifact == "stdout-json")
        #expect(networkProxy.primaryNextAction?.command == "device")
        #expect(networkProxy.primaryNextAction?.args.prefix(2) == ["proxy", "probe"])
        #expect(networkProxy.steps.map(\.id) == ["target-resolve", "proxy-doctor", "proxy-probe-plan", "proxy-cert-plan", "proxy-cert-install", "proxy-serve", "proxy-start-plan", "proxy-start-execute", "proxy-export-plan", "proxy-evidence", "proxy-stop-plan", "proxy-stop-execute"])
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-probe-plan" })?.command.contains("--platform android") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-probe-plan" })?.command.contains("--plan-only") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-plan" })?.command.contains("proxy cert plan") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-plan" })?.command.contains("--certificate /tmp/triton-proxy-ca.cer") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-plan" })?.expectedArtifacts.contains("proxy-certificate") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-install" })?.command.contains("proxy cert install") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-install" })?.command.contains("--audit-record ticket-123") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-install" })?.command.contains("--execute-runner") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-install" })?.requires.contains("operator.approval") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-cert-install" })?.expectedArtifacts.contains("proxy-certificate") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-start-plan" })?.command.contains("--platform android") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-start-plan" })?.command.contains("--plan-only") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-start-execute" })?.command.contains("--proxy 127.0.0.1:19431") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-start-execute" })?.command.contains("--audit-record ticket-123") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-start-execute" })?.command.contains("--execute-runner") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-start-execute" })?.requires.contains("proxy.endpoint.ready") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-evidence" })?.command.contains("--include network.proxy-session") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-stop-plan" })?.command.contains("--restore-snapshot /tmp/proxy-session/restore-state.json") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-stop-plan" })?.expected == "Plan-only response reviews restore snapshot sourceCommands and configured=false")
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-stop-execute" })?.command.contains("--restore-snapshot /tmp/proxy-session/restore-state.json") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-stop-execute" })?.command.contains("--audit-record ticket-123") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-stop-execute" })?.command.contains("--execute-runner") == true)
        #expect(networkProxy.steps.first(where: { $0.id == "proxy-stop-execute" })?.requires.contains("restore-snapshot") == true)
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

        let hostOnlyProxyPlan = buildWorkflowPlan(
            capabilities: disconnected,
            host: "127.0.0.1",
            port: 19421,
            request: WorkflowPlanRequest(
                goal: "network-proxy",
                device: "booted",
                platform: "ios",
                evidence: "/tmp/proxy.tritonevidence",
                proxy: "127.0.0.1:19431",
                mode: "record",
                output: "/tmp/proxy-session",
                certificate: "/tmp/triton-proxy-ca.cer"
            )
        )
        #expect(hostOnlyProxyPlan.ok)
        #expect(hostOnlyProxyPlan.serverReachable == false)
        #expect(hostOnlyProxyPlan.mode == "task")
        #expect(hostOnlyProxyPlan.nextStep == "proxy-probe-plan")
        #expect(hostOnlyProxyPlan.primaryNextAction?.command == "device")
        #expect(hostOnlyProxyPlan.primaryNextAction?.args.prefix(2) == ["proxy", "probe"])
        #expect(hostOnlyProxyPlan.steps.map(\.id).contains("start-server") == false)
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

        #expect(commandNames.count == 54)
        #expect(Set(commandNames).count == commandNames.count)
        #expect(commandNames == [
            "version", "serve", "status", "doctor", "plan", "capabilities", "schema",
            "target",
            "xcode", "xcresult", "xctrace", "coverage", "build",
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
        let pressBoundary = "Host-side HID is not available in the embedded runtime"
        let knownUnsupportedReasons = Set([
            requiresRuntime,
            requiresWebViewProvider,
            harmonyClearBoundary,
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
                    if !["press", "harmony-clear-text"].contains(capability.name) {
                        connectedUnexpectedUnsupported.append("\(capability.name):\(reason)")
                    } else if capability.name == "press", reason != pressBoundary {
                        connectedBoundaryReasonMismatch.append("\(capability.name):\(reason)")
                    } else if capability.name == "harmony-clear-text", reason != harmonyClearBoundary {
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

}
