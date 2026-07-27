import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKCLITransportModelsTests {
    @Test("command requests normalize supported request types")
    func commandRequestTypeMapping() {
        #expect(TKCLICommandRequest(type: "ping").requestType == .ping)
        #expect(TKCLICommandRequest(type: "appInfo").requestType == .appInfo)
        #expect(TKCLICommandRequest(type: "hierarchy").requestType == .hierarchy)
        #expect(TKCLICommandRequest(type: "runtimeManifest").requestType == .runtimeManifest)
        #expect(TKCLICommandRequest(type: "manifest").requestType == .runtimeManifest)
        #expect(TKCLICommandRequest(type: "stateApp").requestType == .stateApp)
        #expect(TKCLICommandRequest(type: "state.app").requestType == .stateApp)
        #expect(TKCLICommandRequest(type: "app").requestType == .stateApp)
        #expect(TKCLICommandRequest(type: "stateScene").requestType == .stateScene)
        #expect(TKCLICommandRequest(type: "scene").requestType == .stateScene)
        #expect(TKCLICommandRequest(type: "stateRoute").requestType == .stateRoute)
        #expect(TKCLICommandRequest(type: "route").requestType == .stateRoute)
        #expect(TKCLICommandRequest(type: "stateResponder").requestType == .stateResponder)
        #expect(TKCLICommandRequest(type: "responder").requestType == .stateResponder)
        #expect(TKCLICommandRequest(type: "snapshot").requestType == .runtimeSnapshot)
        #expect(TKCLICommandRequest(type: "runtimeSnapshot").requestType == .runtimeSnapshot)
        #expect(TKCLICommandRequest(type: "semanticAction").requestType == .semanticAction)
        #expect(TKCLICommandRequest(type: "ledger").requestType == .runtimeLedger)
        #expect(TKCLICommandRequest(type: "runtimeLedger").requestType == .runtimeLedger)
        #expect(TKCLICommandRequest(type: "allAttrGroups").requestType == .allAttrGroups)
        #expect(TKCLICommandRequest(type: "fetchObject").requestType == .fetchObject)
        #expect(TKCLICommandRequest(type: "modifyAttribute").requestType == .modifyAttribute)
        #expect(TKCLICommandRequest(type: "node.patch").requestType == .modifyAttribute)
        #expect(TKCLICommandRequest(type: "unsupported").requestType == nil)
    }

    @Test("node property patch request resolves runtime oid from Lookin style node id")
    func nodePropertyPatchRequestResolvesOid() throws {
        let request = TKNodePropertyPatchRequest(
            nodeId: "ios:runtime:1717",
            changes: TKNodePropertyChanges(view: TKNodeViewPropertyChanges(alpha: 0.5))
        )

        #expect(request.resolvedOID == 1717)

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(TKNodePropertyPatchRequest.self, from: data)
        #expect(decoded.resolvedOID == 1717)
        #expect(decoded.changes.view?.alpha == 0.5)
    }

    @Test("target summary preserves machine readable identity")
    func targetSummaryIdentity() {
        let target = TKTargetSummary(
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Demo",
            bundleIdentifier: "com.example.demo",
            deviceDescription: "iPhone",
            osDescription: "26.5",
            simulatorUDID: "SIM-UDID-1"
        )

        #expect(target.id == TKLocalTargetID)
        #expect(target.transport == "local-websocket")
        #expect(target.platform == "ios")
        #expect(target.connected)
        #expect(target.latestHierarchyAvailable)
        #expect(target.activeHierarchyAvailable == true)
        #expect(target.cachedHierarchyAvailable == true)
        #expect(target.hierarchyCacheState == "active")
        #expect(target.identityState == "current")
        #expect(target.appName == "Demo")
        #expect(target.bundleIdentifier == "com.example.demo")
        #expect(target.simulatorUDID == "SIM-UDID-1")
    }

    @Test("target summary preserves simulator identity during JSON roundtrip")
    func targetSummaryPreservesSimulatorIdentity() throws {
        let target = TKTargetSummary(
            id: "triton:ios-simulator:SIM-UDID-2",
            connected: true,
            latestHierarchyAvailable: false,
            simulatorUDID: "SIM-UDID-2",
            identityState: "current"
        )

        let data = try JSONEncoder().encode(target)
        let decoded = try JSONDecoder().decode(TKTargetSummary.self, from: data)

        #expect(decoded.id == "triton:ios-simulator:SIM-UDID-2")
        #expect(decoded.platform == "ios")
        #expect(decoded.simulatorUDID == "SIM-UDID-2")
        #expect(try TKResolveTargetSummary("SIM-UDID-2", in: [decoded]) == decoded)
    }

    @Test("iOS simulator runtime target id can be scoped by bundle")
    func iosSimulatorRuntimeTargetIDCanBeScopedByBundle() throws {
        let demo = TKTargetSummary(
            id: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: "SIM-UDID-4",
                bundleIdentifier: "com.example.demo"
            ),
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Demo",
            bundleIdentifier: "com.example.demo",
            simulatorUDID: "SIM-UDID-4"
        )
        let other = TKTargetSummary(
            id: TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: "SIM-UDID-4",
                bundleIdentifier: "com.example.other"
            ),
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Other",
            bundleIdentifier: "com.example.other",
            simulatorUDID: "SIM-UDID-4"
        )

        #expect(demo.id == "triton:ios-simulator:SIM-UDID-4/app:com.example.demo")
        #expect(TKIOSSimulatorUDID(fromTargetID: demo.id) == "SIM-UDID-4")
        #expect(try TKResolveTargetSummary(demo.id, in: [demo, other]) == demo)
        #expect(throws: TKTargetResolutionError.ambiguous(requested: "SIM-UDID-4", available: [demo.id, other.id])) {
            try TKResolveTargetSummary("SIM-UDID-4", in: [demo, other])
        }
        #expect(throws: TKTargetResolutionError.ambiguous(requested: "triton:ios-simulator:SIM-UDID-4", available: [demo.id, other.id])) {
            try TKResolveTargetSummary("triton:ios-simulator:SIM-UDID-4", in: [demo, other])
        }
    }

    @Test("target summary preserves explicit cross-platform runtime identity")
    func targetSummaryPreservesCrossPlatformRuntimeIdentity() throws {
        let android = TKTargetSummary(
            id: "triton:android-emulator:emulator-5554",
            transport: "local-websocket",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Android Demo",
            bundleIdentifier: "com.example.android",
            deviceDescription: "Pixel Emulator",
            osDescription: "Android 16",
            platform: "android"
        )
        let harmony = TKTargetSummary(
            id: "triton:harmony-emulator:127.0.0.1:10100",
            transport: "local-websocket",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Harmony Demo",
            bundleIdentifier: "com.example.harmony",
            deviceDescription: "DevEco Emulator",
            osDescription: "HarmonyOS NEXT",
            platform: "harmony"
        )

        let data = try JSONEncoder().encode(TKTargetsResponse(targets: [android, harmony]))
        let decoded = try JSONDecoder().decode(TKTargetsResponse.self, from: data)

        #expect(decoded.targets.map(\.platform) == ["android", "harmony"])
    }

    @Test("target summary decodes legacy payloads without platform")
    func targetSummaryDecodesLegacyPayloadWithoutPlatform() throws {
        let data = Data(#"""
        {
          "id": "triton:android-emulator:emulator-5554",
          "transport": "local-websocket",
          "connected": true,
          "latestHierarchyAvailable": true,
          "appName": "Legacy Android",
          "bundleIdentifier": "com.example.legacy",
          "deviceDescription": "Pixel",
          "osDescription": "Android 16"
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(TKTargetSummary.self, from: data)

        #expect(decoded.platform == "android")
        #expect(decoded.hierarchyCacheState == "active")
        #expect(decoded.identityState == "current")
    }

    @Test("command request preserves explicit target during JSON roundtrip")
    func commandRequestPreservesTarget() throws {
        let request = TKCLICommandRequest(
            type: "accessibility",
            payload: Data(#"{"sample":true}"#.utf8),
            target: "triton:ios-simulator:SIM-UDID-3"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(TKCLICommandRequest.self, from: data)

        #expect(decoded.type == "accessibility")
        #expect(decoded.payload == Data(#"{"sample":true}"#.utf8))
        #expect(decoded.target == "triton:ios-simulator:SIM-UDID-3")
    }

    @Test("target resolution auto-selects the only target for default CLI target")
    func targetResolutionAutoSelectsOnlyTarget() throws {
        let target = TKTargetSummary(
            id: "triton:simulator:only",
            transport: "local-websocket",
            connected: true,
            latestHierarchyAvailable: true
        )

        #expect(try TKResolveTargetSummary(TKLocalTargetID, in: [target]) == target)
        #expect(try TKResolveTargetSummary("local", in: [target]) == target)
    }

    @Test("intent-first CLI can omit target when exactly one target exists")
    func intentFirstCLIOmittedTargetResolvesSingleTarget() throws {
        let onlyConnectedTarget = TKTargetSummary(
            id: "triton:demo:single",
            transport: "local-websocket",
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Intent Smoke"
        )

        let resolved = try TKResolveTargetSummary(TKLocalTargetID, in: [onlyConnectedTarget])

        #expect(resolved.id == "triton:demo:single")
        #expect(resolved.appName == "Intent Smoke")
    }

    @Test("target resolution keeps explicit target matching strict")
    func targetResolutionKeepsExplicitMatchingStrict() throws {
        let first = TKTargetSummary(id: "target:first", connected: true, latestHierarchyAvailable: true)
        let second = TKTargetSummary(id: "target:second", connected: true, latestHierarchyAvailable: true)

        #expect(try TKResolveTargetSummary("target:second", in: [first, second]) == second)
        #expect(throws: TKTargetResolutionError.notFound("target:missing")) {
            try TKResolveTargetSummary("target:missing", in: [first])
        }
        #expect(throws: TKTargetResolutionError.ambiguous(requested: TKLocalTargetID, available: ["target:first", "target:second"])) {
            try TKResolveTargetSummary(TKLocalTargetID, in: [first, second])
        }
    }

    @Test("default hierarchy tree noise classes hide UIKit wrappers only")
    func defaultHierarchyTreeNoiseClasses() {
        #expect(TKIsDefaultHiddenHierarchyTreeClass("UITransitionView"))
        #expect(TKIsDefaultHiddenHierarchyTreeClass("UIDropShadowView"))
        #expect(!TKIsDefaultHiddenHierarchyTreeClass("UILayoutContainerView"))
        #expect(!TKIsDefaultHiddenHierarchyTreeClass("RemoteFilesKit.LocalAlbumCardCell"))
    }

    @Test("AX hierarchy map joins AX nodes to hierarchy view object ids")
    func axHierarchyMapJoinsByViewOID() throws {
        let axNodes = [
            TKAXNode(
                role: "window",
                label: nil,
                value: nil,
                identifier: nil,
                title: nil,
                frame: TKRect(x: 0, y: 0, width: 100, height: 100),
                enabled: true,
                focused: false,
                hidden: false,
                targetOID: 1,
                className: "DemoWindow",
                children: [
                    TKAXNode(
                        role: "button",
                        label: "Save",
                        value: nil,
                        identifier: "save",
                        title: nil,
                        frame: TKRect(x: 10, y: 20, width: 40, height: 30),
                        enabled: true,
                        focused: false,
                        hidden: false,
                        targetOID: 11,
                        viewOID: 11,
                        className: "UIButton",
                        children: []
                    ),
                ]
            ),
        ]
        let hierarchyJSON = """
        {
          "displayItems": [
            {
              "alpha": 1,
              "isHidden": false,
              "frame": [[0, 0], [100, 100]],
              "viewObject": {"oid": 1, "classChainList": ["DemoWindow"]},
              "layerObject": {"oid": 2, "classChainList": ["DemoWindow"]},
              "subitems": [
                {
                  "alpha": 1,
                  "isHidden": false,
                  "frame": [[10, 20], [40, 30]],
                  "viewObject": {"oid": 11, "classChainList": ["UIButton"]},
                  "layerObject": {"oid": 12, "classChainList": ["UIButton"]},
                  "subitems": []
                }
              ]
            }
          ]
        }
        """

        let response = try TKBuildAXHierarchyMap(
            axNodes: axNodes,
            hierarchyData: Data(hierarchyJSON.utf8)
        )

        #expect(response.axNodeCount == 2)
        #expect(response.hierarchyNodeCount == 2)
        #expect(response.mappedCount == 2)
        #expect(response.unmatchedCount == 0)
        let button = try #require(response.nodes.first(where: { $0.identifier == "save" }))
        #expect(button.hierarchy?.viewOID == 11)
        #expect(button.hierarchy?.layerOID == 12)
        #expect(button.hierarchy?.className == "UIButton")
        #expect(button.hierarchy?.frame == TKRect(x: 10, y: 20, width: 40, height: 30))
        #expect(button.hierarchy?.path == ["DemoWindow", "UIButton"])
    }

    @Test("status envelope carries bootstrap context")
    func statusEnvelopeShape() throws {
        let response = TKCLIStatusEnvelope(
            ok: true,
            serverReachable: true,
            connected: true,
            latestHierarchyAvailable: true,
            targetCount: 1,
            runtime: "embedded",
            activeHierarchyAvailable: true,
            hierarchyCacheState: "active",
            targetConnectionState: "connected"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKCLIStatusEnvelope.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.surface == "status")
        #expect(decoded.serverReachable)
        #expect(decoded.runtime == "embedded")
        #expect(decoded.targetCount == 1)
        #expect(decoded.activeHierarchyAvailable == true)
        #expect(decoded.hierarchyCacheState == "active")
        #expect(decoded.targetConnectionState == "connected")
    }

    @Test("status envelope distinguishes stale hierarchy cache from active target")
    func statusEnvelopeDistinguishesStaleHierarchyCache() throws {
        let response = TKCLIStatusEnvelope(
            ok: true,
            serverReachable: true,
            connected: false,
            latestHierarchyAvailable: true,
            targetCount: 0,
            runtime: "none",
            activeHierarchyAvailable: false,
            hierarchyCacheState: "stale",
            targetConnectionState: "disconnected"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKCLIStatusEnvelope.self, from: data)

        #expect(decoded.surface == "status")
        #expect(decoded.latestHierarchyAvailable)
        #expect(decoded.activeHierarchyAvailable == false)
        #expect(decoded.hierarchyCacheState == "stale")
        #expect(decoded.targetConnectionState == "disconnected")
    }

    @Test("target summary can expose connected target without stale identity")
    func targetSummaryCanExposeUnknownIdentityWithoutStaleMetadata() throws {
        let target = TKTargetSummary(
            connected: true,
            latestHierarchyAvailable: false,
            activeHierarchyAvailable: false,
            cachedHierarchyAvailable: true,
            hierarchyCacheState: "stale",
            identityState: "unknown"
        )

        let data = try JSONEncoder().encode(TKTargetsResponse(targets: [target]))
        let decoded = try JSONDecoder().decode(TKTargetsResponse.self, from: data)
        let decodedTarget = try #require(decoded.targets.first)

        #expect(decodedTarget.connected)
        #expect(decodedTarget.appName == nil)
        #expect(decodedTarget.bundleIdentifier == nil)
        #expect(decodedTarget.activeHierarchyAvailable == false)
        #expect(decodedTarget.cachedHierarchyAvailable == true)
        #expect(decodedTarget.hierarchyCacheState == "stale")
        #expect(decodedTarget.identityState == "unknown")
    }

    @Test("CLI error envelope is stable JSON")
    func cliErrorEnvelopeShape() throws {
        let response = TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: "server_unavailable",
            message: "Cannot reach TritonKit server",
            endpoint: "http://127.0.0.1:19421/status",
            hint: "Run `triton serve --host 127.0.0.1 --port 19421`",
            nextAction: TKCLINextAction(
                command: "serve",
                args: ["--host", "127.0.0.1", "--port", "19421"],
                requiresLongRunningProcess: true
            )
        ))

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKCLIErrorResponse.self, from: data)

        #expect(!decoded.ok)
        #expect(decoded.error.code == "server_unavailable")
        #expect(decoded.error.endpoint?.contains("/status") == true)
        #expect(decoded.error.hint?.contains("triton serve") == true)
        #expect(decoded.error.nextAction?.command == "serve")
        #expect(decoded.error.nextAction?.requiresLongRunningProcess == true)
    }

    @Test("runtime UI request timeouts explain likely system interruption")
    func runtimeUITimeoutErrorShape() throws {
        let input = TKCLIRuntimeTimeoutErrorDetail(requestType: "input", endpoint: "/request")
        let accessibility = TKCLIRuntimeTimeoutErrorDetail(requestType: "accessibility", endpoint: "/accessibility")
        let ping = TKCLIRuntimeTimeoutErrorDetail(requestType: "ping", endpoint: "/request")

        #expect(input.code == "runtime_ui_interrupted")
        #expect(input.endpoint == "/request")
        #expect(input.hint?.contains("system alert") == true)
        #expect(accessibility.code == "runtime_ui_interrupted")
        #expect(ping.code == "request_timeout")
    }

    @Test("capabilities response describes runtime support")
    func capabilitiesShape() throws {
        let response = TKCapabilitiesResponse(
            ok: true,
            serverReachable: true,
            connected: true,
            latestHierarchyAvailable: true,
            targetCount: 1,
            runtime: "embedded",
            capabilities: [
                TKRuntimeCapability(
                    name: "tap",
                    supported: true,
                    group: "action",
                    requiredBy: ["assert", "evidence"],
                    nextAction: TKCLINextAction(command: "tap", args: ["<query>", "--json"]),
                    evidence: ["input.result"]
                ),
                TKRuntimeCapability(
                    name: "press",
                    supported: false,
                    reason: "Host-side HID unavailable",
                    group: "action",
                    evidence: ["schema:press"]
                ),
            ]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKCapabilitiesResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.surface == "capabilities")
        #expect(decoded.runtime == "embedded")
        #expect(decoded.activeHierarchyAvailable == true)
        #expect(decoded.hierarchyCacheState == "active")
        #expect(decoded.targetConnectionState == "connected")
        #expect(decoded.primaryCapability == "tap")
        #expect(decoded.primaryWorkflowCategory == "assert")
        #expect(decoded.primaryEvidence == "input.result")
        #expect(decoded.primaryNextAction?.command == "tap")
        #expect(decoded.primaryNextActionSource == "actionable-capability")
        #expect(decoded.capabilities.first(where: { $0.name == "tap" })?.supported == true)
        #expect(decoded.capabilities.first(where: { $0.name == "tap" })?.group == "action")
        #expect(decoded.capabilities.first(where: { $0.name == "tap" })?.requiredBy == ["assert", "evidence"])
        #expect(decoded.capabilities.first(where: { $0.name == "tap" })?.nextAction?.command == "tap")
        #expect(decoded.capabilities.first(where: { $0.name == "tap" })?.evidence == ["input.result"])
        #expect(decoded.capabilities.first(where: { $0.name == "press" })?.supported == false)
    }

    @Test("doctor response carries ordered recovery checks")
    func doctorResponseShape() throws {
        let response = TKDoctorResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: "unknown",
            nextStep: "start-server",
            nextWorkflows: ["target", "runtime"],
            checks: [
                TKDoctorCheck(
                    id: "start-server",
                    status: "fail",
                    code: "server_unavailable",
                    message: "Local server is not reachable",
                    hint: "Start server",
                    nextAction: TKCLINextAction(command: "serve", args: ["--host", "127.0.0.1", "--port", "19421"], requiresLongRunningProcess: true),
                    relatedCapabilities: ["status", "runtime-manifest"],
                    workflowCategories: ["runtime", "app"]
                ),
            ],
            error: TKCLIErrorDetail(code: "server_unavailable", message: "No server")
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKDoctorResponse.self, from: data)

        #expect(!decoded.ok)
        #expect(decoded.surface == "doctor")
        #expect(decoded.nextStep == "start-server")
        #expect(decoded.nextWorkflows == ["target", "runtime"])
        #expect(decoded.primaryCapability == "status")
        #expect(decoded.primaryWorkflowCategory == "app")
        #expect(decoded.primaryNextAction?.command == "serve")
        #expect(decoded.primaryNextActionSource == "next-step-check")
        #expect(decoded.checks.first?.id == "start-server")
        #expect(decoded.checks.first?.status == "fail")
        #expect(decoded.checks.first?.nextAction?.command == "serve")
        #expect(decoded.checks.first?.relatedCapabilities == ["status", "runtime-manifest"])
        #expect(decoded.checks.first?.workflowCategories == ["runtime", "app"])
        #expect(decoded.error?.code == "server_unavailable")
    }

    @Test("version and input summary responses are machine readable")
    func bootstrapResponseShapes() throws {
        let version = TKCLIVersionResponse(version: "0.1.0")
        let summary = TKInputBatchSummaryResponse(ok: false, actionCount: 3, failedCount: 1)

        let versionData = try JSONEncoder().encode(version)
        let summaryData = try JSONEncoder().encode(summary)
        let decodedVersion = try JSONDecoder().decode(TKCLIVersionResponse.self, from: versionData)
        let decodedSummary = try JSONDecoder().decode(TKInputBatchSummaryResponse.self, from: summaryData)

        #expect(decodedVersion.ok)
        #expect(decodedVersion.schemaVersion == 1)
        #expect(decodedVersion.defaultPort == 19421)
        #expect(decodedVersion.language == "en")
        #expect(decodedVersion.supportedLanguages == ["en", "zh"])
        #expect(!decodedSummary.ok)
        #expect(decodedSummary.actionCount == 3)
        #expect(decodedSummary.failedCount == 1)
    }

    @Test("CLI schema exposes command options and examples")
    func cliSchemaShape() throws {
        let schema = TKCLISchemaResponse(commands: [
            TKCommandSchema(
                name: "tap",
                summary: "Tap a coordinate or view oid",
                requiresServer: true,
                requiresTarget: true,
                requiresHierarchy: false,
                runtimeScope: "embedded",
                exitCodeOnFailure: 1,
                outputFormats: ["text", "json"],
                options: [
                    TKCommandSchemaOption(name: "--x", type: "Double", description: "Window x coordinate"),
                    TKCommandSchemaOption(name: "--y", type: "Double", description: "Window y coordinate"),
                ],
                examples: ["triton tap --x 270 --y 300 --format json"],
                successShape: "{ ok, action, message, targetOID, targetClassName }",
                outputSemantics: "One compact JSON object on stdout",
                requiredOptions: ["--x|--y or --targetOID"],
                artifacts: ["none"],
                retryable: true,
                nextCommands: ["triton status --format json"],
                outputContracts: [
                    TKCommandOutputContract(
                        selector: "tap.result",
                        format: "json",
                        kind: "envelope",
                        model: "TKInputResult",
                        fields: [
                            TKCommandSchemaField(name: "ok", type: "Bool", description: "Whether the action succeeded"),
                            TKCommandSchemaField(name: "action", type: "String", description: "Action name"),
                        ]
                    ),
                ],
                failureCodes: ["server_unavailable", "target_not_found"],
                subcommands: [
                    TKCommandSubcommandSchema(
                        name: "coordinate",
                        summary: "Tap by coordinate",
                        requiredOptions: [],
                        oneOfRequiredOptions: [["--x", "--y"], ["--targetOID"]],
                        optionalOptions: ["--duration"],
                        defaultProviders: ["triton target use"],
                        outputSelectors: ["tap.result"],
                        failureCodes: ["server_unavailable"]
                    ),
                ],
                inputActions: [
                    TKInputActionSchema(
                        type: "tap",
                        requiredFields: ["type"],
                        optionalFields: ["x", "y", "targetOID"],
                        oneOfRequired: [["x", "y"], ["targetOID"]],
                        coordinateSpace: "window-points",
                        fields: [
                            TKInputActionFieldSchema(
                                name: "type",
                                type: "String",
                                required: true,
                                enumValues: ["tap"],
                                description: "Action discriminator"
                            ),
                            TKInputActionFieldSchema(
                                name: "x",
                                type: "Double",
                                description: "Window x coordinate in points"
                            ),
                        ],
                        example: #"{"type":"tap","x":270,"y":300}"#
                    ),
                ],
                providedCapabilities: ["tap"]
            ),
        ], httpManagementAPI: [
            TKHTTPManagementEndpointSchema(
                method: "POST",
                path: "/input",
                successShape: "TKInputResult",
                failureShape: "{ ok: false, error: { code, message, endpoint, hint } }"
            ),
        ])

        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(TKCLISchemaResponse.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.commands.first?.name == "tap")
        #expect(decoded.commands.first?.requiresTarget == true)
        #expect(decoded.commands.first?.runtimeScope == "embedded")
        #expect(decoded.commands.first?.exitCodeOnFailure == 1)
        #expect(decoded.commands.first?.options.first?.name == "--x")
        #expect(decoded.commands.first?.examples.first?.contains("triton tap") == true)
        #expect(decoded.commands.first?.outputSemantics?.contains("compact JSON") == true)
        #expect(decoded.commands.first?.requiredOptions == ["--x|--y or --targetOID"])
        #expect(decoded.commands.first?.artifacts == ["none"])
        #expect(decoded.commands.first?.retryable == true)
        #expect(decoded.commands.first?.nextCommands == ["triton status --format json"])
        #expect(decoded.commands.first?.outputContracts.first?.selector == "tap.result")
        #expect(decoded.commands.first?.outputContracts.first?.fields.first?.name == "ok")
        #expect(decoded.commands.first?.failureCodes == ["server_unavailable", "target_not_found"])
        #expect(decoded.commands.first?.subcommands.first?.name == "coordinate")
        #expect(decoded.commands.first?.subcommands.first?.oneOfRequiredOptions == [["--x", "--y"], ["--targetOID"]])
        #expect(decoded.commands.first?.subcommands.first?.defaultProviders == ["triton target use"])
        #expect(decoded.commands.first?.subcommands.first?.outputSelectors == ["tap.result"])
        #expect(decoded.commands.first?.inputActions?.first?.type == "tap")
        #expect(decoded.commands.first?.inputActions?.first?.coordinateSpace == "window-points")
        #expect(decoded.commands.first?.inputActions?.first?.oneOfRequired.first == ["x", "y"])
        #expect(decoded.commands.first?.inputActions?.first?.fields.first?.enumValues == ["tap"])
        #expect(decoded.commands.first?.providedCapabilities == ["tap"])
        #expect(decoded.httpManagementAPI.first?.path == "/input")
        #expect(decoded.httpManagementAPI.first?.failureShape.contains("error") == true)
    }

    @Test("CLI schema decodes older command objects without structured contract keys")
    func cliSchemaDefaultsStructuredContractFields() throws {
        let data = Data("""
        {
          "schemaVersion": 1,
          "commands": [
            {
              "name": "status",
              "summary": "Read runtime status",
              "requiresServer": true,
              "requiresTarget": false,
              "outputFormats": ["json"],
              "options": [],
              "examples": ["triton status --json"],
              "subcommands": [
                {
                  "name": "summary",
                  "summary": "Read a summary"
                }
              ]
            }
          ],
          "httpManagementAPI": []
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(TKCLISchemaResponse.self, from: data)
        let command = try #require(decoded.commands.first)

        #expect(command.requiresHierarchy == false)
        #expect(command.runtimeScope == "cli")
        #expect(command.exitCodeOnFailure == 1)
        #expect(command.failureShape?.contains("error") == true)
        #expect(command.requiredOptions == [])
        #expect(command.inheritsDefaultsFrom == [])
        #expect(command.jsonlEvents == [])
        #expect(command.finalEventKind == nil)
        #expect(command.artifacts == [])
        #expect(command.retryable == false)
        #expect(command.nextCommands == [])
        #expect(command.outputContracts == [])
        #expect(command.failureCodes == [])
        #expect(command.subcommands.first?.name == "summary")
        #expect(command.subcommands.first?.requiresServer == false)
        #expect(command.subcommands.first?.requiresTarget == false)
        #expect(command.subcommands.first?.requiresConfirmation == false)
        #expect(command.subcommands.first?.sideEffect == "none")
        #expect(command.subcommands.first?.optionOverrides == [])
        #expect(command.subcommands.first?.requiredOptions == [])
        #expect(command.subcommands.first?.oneOfRequiredOptions == [])
        #expect(command.subcommands.first?.defaultProviders == [])
        #expect(command.subcommands.first?.outputSelectors == [])
        #expect(command.providedCapabilities == [])
    }

    @Test("CLI schema normalizes next action lifecycle failure shapes")
    func cliSchemaNormalizesNextActionLifecycleFailureShapes() throws {
        let oldImplicit = TKCommandSchema(
            name: "old-implicit",
            summary: "Old implicit next action shape",
            requiresServer: false,
            requiresTarget: false,
            outputFormats: ["json"],
            options: [],
            examples: [],
            failureShape: "{ ok:false, error:{ code, message, nextAction? } }"
        )
        let oldExplicit = TKCommandSchema(
            name: "old-explicit",
            summary: "Old explicit next action shape",
            requiresServer: false,
            requiresTarget: false,
            outputFormats: ["json"],
            options: [],
            examples: [],
            failureShape: "{ ok:false, error:{ code, message, nextAction?{ command,args,category,requiresLongRunningProcess? } } }"
        )

        let shapes = try [oldImplicit, oldExplicit].map { schema -> String in
            try #require(schema.failureShape)
        }

        for shape in shapes {
            #expect(shape.contains("command"))
            #expect(shape.contains("args"))
            #expect(shape.contains("category"))
            #expect(shape.contains("requiresLongRunningProcess"))
            #expect(shape.contains("readyEvents"))
            #expect(shape.contains("finalEvents"))
            #expect(shape.contains("terminationSignals"))
        }
    }

    @Test("workflow plan carries next step and command sequence")
    func workflowPlanShape() throws {
        let plan = TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: "unknown",
            mode: "bootstrap",
            goal: "general",
            nextStep: "start-server",
            steps: [
                TKWorkflowPlanStep(
                    id: "start-server",
                    title: "Start Triton server",
                    command: "triton serve --host 127.0.0.1 --port 19421",
                    requiresServer: false,
                    requiresTarget: false,
                    when: "serverReachable == false",
                    expected: "Server listens on 127.0.0.1:19421"
                ),
            ],
            error: TKCLIErrorDetail(
                code: "server_unavailable",
                message: "Could not connect",
                nextAction: TKCLINextAction(
                    command: "serve",
                    args: ["--host", "127.0.0.1", "--port", "19421"],
                    requiresLongRunningProcess: true
                )
            )
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TKWorkflowPlanResponse.self, from: data)

        #expect(!decoded.ok)
        #expect(decoded.surface == "plan")
        #expect(decoded.mode == "bootstrap")
        #expect(decoded.goal == "general")
        #expect(decoded.nextStep == "start-server")
        #expect(decoded.nextWorkflows.contains("app"))
        #expect(decoded.nextWorkflows.contains("observe"))
        #expect(decoded.primaryWorkflowCategory == "app")
        #expect(decoded.primaryExpectedArtifact == "stdout-json")
        #expect(decoded.primaryNextAction?.command == "serve")
        #expect(decoded.primaryNextAction?.args == ["--host", "127.0.0.1", "--port", "19421"])
        #expect(decoded.primaryNextAction?.requiresLongRunningProcess == true)
        #expect(decoded.primaryNextAction?.readyEvents == [])
        #expect(decoded.primaryNextAction?.finalEvents == [])
        #expect(decoded.primaryNextAction?.terminationSignals == ["sigint", "sigterm"])
        #expect(decoded.primaryNextActionSource == "next-step-step")
        #expect(decoded.steps.first?.command.contains("triton serve") == true)
        #expect(decoded.steps.first?.argv == ["triton", "serve", "--host", "127.0.0.1", "--port", "19421"])
        #expect(decoded.steps.first?.workflowCategories.contains("app") == true)
        #expect(decoded.steps.first?.workflowCategories.contains("evidence") == true)
        #expect(decoded.steps.first?.requires == ["cli.available"])
        #expect(decoded.steps.first?.expectedArtifacts.contains("stdout-json") == true)
        #expect(decoded.steps.first?.stopConditions.contains("command.failed") == true)
        #expect(decoded.steps.first?.requiresLongRunningProcess == true)
        #expect(decoded.steps.first?.readyEvents == [])
        #expect(decoded.steps.first?.finalEvents == [])
        #expect(decoded.steps.first?.terminationSignals == ["sigint", "sigterm"])
        #expect(decoded.error?.code == "server_unavailable")
        #expect(decoded.error?.nextAction?.args.contains("19421") == true)
    }

    @Test("workflow plan step decodes long running lifecycle defaults for older payloads")
    func workflowPlanStepDecodesLongRunningLifecycleDefaultsForOlderPayloads() throws {
        let data = Data(
            """
            {
              "id": "proxy-serve",
              "title": "Start proxy",
              "command": "triton device proxy serve --listen 127.0.0.1:19431 --output /tmp/proxy --mode record --jsonl",
              "requiresServer": false,
              "requiresTarget": false,
              "when": "before proxy start",
              "expected": "proxy.serve.ready"
            }
            """.utf8
        )

        let step = try JSONDecoder().decode(TKWorkflowPlanStep.self, from: data)

        #expect(Array(step.argv.prefix(4)) == ["triton", "device", "proxy", "serve"])
        #expect(step.requiresLongRunningProcess == true)
        #expect(step.readyEvents == ["proxy.serve.ready"])
        #expect(step.finalEvents == ["proxy.serve.summary"])
        #expect(step.terminationSignals == ["sigint", "sigterm"])
    }

    @Test("next action decodes long running lifecycle defaults for older payloads")
    func nextActionDecodesLongRunningLifecycleDefaultsForOlderPayloads() throws {
        let serveData = Data(
            """
            {
              "command": "serve",
              "args": ["--host", "127.0.0.1", "--port", "19421"],
              "category": "app"
            }
            """.utf8
        )
        let proxyServeData = Data(
            """
            {
              "command": "device",
              "args": ["proxy", "serve", "--listen", "127.0.0.1:19431", "--output", "/tmp/proxy", "--mode", "record", "--jsonl"],
              "category": "plan"
            }
            """.utf8
        )

        let serve = try JSONDecoder().decode(TKCLINextAction.self, from: serveData)
        let proxyServe = try JSONDecoder().decode(TKCLINextAction.self, from: proxyServeData)
        let proxyServeFromArgv = try #require(TKCLINextAction.fromTritonArgv(["triton"] + [proxyServe.command] + proxyServe.args))

        #expect(serve.requiresLongRunningProcess == true)
        #expect(serve.readyEvents == [])
        #expect(serve.finalEvents == [])
        #expect(serve.terminationSignals == ["sigint", "sigterm"])
        #expect(proxyServe.requiresLongRunningProcess == true)
        #expect(proxyServe.readyEvents == ["proxy.serve.ready"])
        #expect(proxyServe.finalEvents == ["proxy.serve.summary"])
        #expect(proxyServe.terminationSignals == ["sigint", "sigterm"])
        #expect(proxyServeFromArgv.command == proxyServe.command)
        #expect(proxyServeFromArgv.args == proxyServe.args)
        #expect(proxyServeFromArgv.requiresLongRunningProcess == true)
        #expect(proxyServeFromArgv.readyEvents == ["proxy.serve.ready"])
        #expect(proxyServeFromArgv.finalEvents == ["proxy.serve.summary"])
        #expect(proxyServeFromArgv.terminationSignals == ["sigint", "sigterm"])
    }

    @Test("workflow plan infers mode when decoding older payloads")
    func workflowPlanInfersModeForOlderPayloads() throws {
        let bootstrapData = Data(
            """
            {
              "ok": false,
              "serverReachable": false,
              "connected": false,
              "runtime": "unknown",
              "goal": "general",
              "nextStep": "start-server",
              "steps": []
            }
            """.utf8
        )
        let taskData = Data(
            """
            {
              "ok": true,
              "serverReachable": true,
              "connected": true,
              "runtime": "embedded",
              "goal": "ios-smoke",
              "nextStep": "target-list",
              "steps": []
            }
            """.utf8
        )

        let bootstrapPlan = try JSONDecoder().decode(TKWorkflowPlanResponse.self, from: bootstrapData)
        let taskPlan = try JSONDecoder().decode(TKWorkflowPlanResponse.self, from: taskData)

        #expect(bootstrapPlan.surface == "plan")
        #expect(taskPlan.surface == "plan")
        #expect(bootstrapPlan.mode == "bootstrap")
        #expect(taskPlan.mode == "task")
        #expect(bootstrapPlan.nextWorkflows.contains("app"))
        #expect(bootstrapPlan.primaryWorkflowCategory == "app")
        #expect(bootstrapPlan.primaryExpectedArtifact == "stdout-json")
        #expect(bootstrapPlan.primaryNextAction?.command == "serve")
        #expect(bootstrapPlan.primaryNextActionSource == "default-next-step")
        #expect(taskPlan.primaryWorkflowCategory == "app")
        #expect(taskPlan.primaryExpectedArtifact == "stdout-json")
        #expect(taskPlan.primaryNextAction?.command == "target")
        #expect(taskPlan.primaryNextActionSource == "default-next-step")
        #expect(taskPlan.nextWorkflows.contains("smoke"))
    }
}
