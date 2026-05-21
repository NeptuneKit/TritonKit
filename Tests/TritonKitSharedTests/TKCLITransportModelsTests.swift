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
        #expect(TKCLICommandRequest(type: "allAttrGroups").requestType == .allAttrGroups)
        #expect(TKCLICommandRequest(type: "fetchObject").requestType == .fetchObject)
        #expect(TKCLICommandRequest(type: "unsupported").requestType == nil)
    }

    @Test("target summary preserves machine readable identity")
    func targetSummaryIdentity() {
        let target = TKTargetSummary(
            connected: true,
            latestHierarchyAvailable: true,
            appName: "Demo",
            bundleIdentifier: "com.example.demo",
            deviceDescription: "iPhone",
            osDescription: "26.5"
        )

        #expect(target.id == TKLocalTargetID)
        #expect(target.transport == "local-websocket")
        #expect(target.connected)
        #expect(target.latestHierarchyAvailable)
        #expect(target.activeHierarchyAvailable == true)
        #expect(target.cachedHierarchyAvailable == true)
        #expect(target.hierarchyCacheState == "active")
        #expect(target.identityState == "current")
        #expect(target.appName == "Demo")
        #expect(target.bundleIdentifier == "com.example.demo")
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
                TKRuntimeCapability(name: "tap", supported: true),
                TKRuntimeCapability(name: "press", supported: false, reason: "Host-side HID unavailable"),
            ]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKCapabilitiesResponse.self, from: data)

        #expect(decoded.ok)
        #expect(decoded.runtime == "embedded")
        #expect(decoded.activeHierarchyAvailable == true)
        #expect(decoded.hierarchyCacheState == "active")
        #expect(decoded.targetConnectionState == "connected")
        #expect(decoded.capabilities.first(where: { $0.name == "tap" })?.supported == true)
        #expect(decoded.capabilities.first(where: { $0.name == "press" })?.supported == false)
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
        #expect(decoded.commands.first?.inputActions?.first?.type == "tap")
        #expect(decoded.commands.first?.inputActions?.first?.coordinateSpace == "window-points")
        #expect(decoded.commands.first?.inputActions?.first?.oneOfRequired.first == ["x", "y"])
        #expect(decoded.commands.first?.inputActions?.first?.fields.first?.enumValues == ["tap"])
        #expect(decoded.commands.first?.providedCapabilities == ["tap"])
        #expect(decoded.httpManagementAPI.first?.path == "/input")
        #expect(decoded.httpManagementAPI.first?.failureShape.contains("error") == true)
    }

    @Test("workflow plan carries next step and command sequence")
    func workflowPlanShape() throws {
        let plan = TKWorkflowPlanResponse(
            ok: false,
            serverReachable: false,
            connected: false,
            runtime: "unknown",
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
        #expect(decoded.nextStep == "start-server")
        #expect(decoded.steps.first?.command.contains("triton serve") == true)
        #expect(decoded.error?.code == "server_unavailable")
        #expect(decoded.error?.nextAction?.args.contains("19421") == true)
    }
}
