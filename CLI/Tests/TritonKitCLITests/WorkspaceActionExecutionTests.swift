import AppKit
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("WorkspaceActionExecutionTests")
struct WorkspaceActionExecutionTests {
    @Test("workspace run resolves host target before lifecycle observation and action")
    func workspaceRunResolvesHostTargetBeforeLifecycleObservationAndAction() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let selected = HostDeviceTarget(
            platform: "ios",
            id: "host:ios:SIM-1",
            target: "SIM-1",
            state: "Booted",
            ready: true,
            source: "xcrun simctl",
            name: "iPhone 17",
            runtime: "iOS 26.5",
            transport: nil,
            scope: "simulator",
            kind: "simulator"
        )
        var resolveRequest: TKWorkspaceTargetResolveRequest?
        var lifecycleRequest: TKWorkspaceAppLifecycleRequest?
        var observeRequests: [TKWorkspaceLiveObserveRequest] = []
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-resolved-target",
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Open next screen",
                actionPolicy: "explore",
                appMode: "launch",
                bundleID: "com.example.demo",
                llmProvider: "mock",
                vlmProvider: "mock",
                observeLive: true,
                observeKind: "tree",
                resolveTarget: true,
                executeActions: true
            ),
            targetResolver: { request in
                resolveRequest = request
                return TKWorkspaceTargetResolution(
                    selection: HostDeviceSelectionResult(
                        platform: .ios,
                        target: selected,
                        selector: "booted",
                        source: .explicit,
                        filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "booted", platform: .ios, scope: .simulator))
                    ),
                    sourceCommands: ["triton target resolve booted --platform ios --scope simulator --json"]
                )
            },
            observeProvider: { request in
                observeRequests.append(request)
                return fakeLiveObserveOutput(for: request, visibleTexts: ["Welcome", "Continue"], artifactStem: "resolved")
            },
            appLifecycleProvider: { request in
                lifecycleRequest = request
                return TKWorkspaceAppLifecycleEvidence(
                    mode: "launch",
                    phase: "launch_submitted",
                    action: "app.launch",
                    app: request.app,
                    platform: request.platform,
                    scope: request.scope,
                    target: request.target,
                    runtimeScope: "host-simulator",
                    ready: false,
                    businessReady: false,
                    submitted: true,
                    sourceCommands: ["triton app launch --target \(request.target) --bundle-id \(request.bundleID ?? "") --json"],
                    artifacts: [],
                    note: nil
                )
            },
            actionExecutionProvider: { request in
                actionRequest = request
                return successfulActionExecution(for: request)
            }
        )

        #expect(resolveRequest?.enabled == true)
        #expect(resolveRequest?.selector == "booted")
        #expect(resolveRequest?.platform == "ios")
        #expect(resolveRequest?.scope == "simulator")
        #expect(lifecycleRequest?.target == "SIM-1")
        #expect(observeRequests.first?.target == "SIM-1")
        #expect(actionRequest?.target == "SIM-1")
        #expect(run.target.id == "host:ios:SIM-1")
        #expect(run.target.platform == "ios")
        #expect(run.target.scope == "simulator")
        #expect(run.target.resolved == true)
        #expect(run.target.selector == "booted")
        #expect(run.target.hostTarget == "SIM-1")
        #expect(run.target.source == "xcrun simctl")
        #expect(run.target.ready == true)
        #expect(run.target.name == "iPhone 17")
        #expect(run.target.runtime == "iOS 26.5")
        #expect(run.target.kind == "simulator")

        let target = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root
                .appendingPathComponent("run-workspace-resolved-target", isDirectory: true)
                .appendingPathComponent("evidence/model/target.json"))
        ) as? [String: Any]
        #expect(target?["target"] as? String == "host:ios:SIM-1")
        #expect(target?["selector"] as? String == "booted")
        #expect(target?["hostTarget"] as? String == "SIM-1")
        #expect(target?["resolved"] as? Bool == true)
        #expect(target?["sourceCommands"] as? [String] == ["triton target resolve booted --platform ios --scope simulator --json"])
    }

    @Test("workspace run executes candidate action when explicitly enabled")
    func workspaceRunExecutesCandidateActionWhenExplicitlyEnabled() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-execute-action",
                target: "runtime-target-1",
                app: "com.example.demo",
                goal: "Open next screen",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                observeHost: "127.0.0.2",
                observePort: 19422,
                executeActions: true
            ),
            actionExecutionProvider: { request in
                actionRequest = request
                return successfulActionExecution(for: request)
            }
        )

        #expect(actionRequest?.target == "runtime-target-1")
        #expect(actionRequest?.host == "127.0.0.2")
        #expect(actionRequest?.port == 19422)
        #expect(actionRequest?.action == "tap")
        #expect(actionRequest?.query == "Continue")
        #expect(actionRequest?.command == ["triton", "act", "tap", "Continue", "--json"])
        #expect(run.status == "stopped")

        let runDir = root.appendingPathComponent("run-workspace-execute-action", isDirectory: true)
        let action = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/actions/action-000.json"))
        ) as? [String: Any]
        #expect(action?["ok"] as? Bool == true)
        #expect(action?["mode"] as? String == "live-action")
        #expect(action?["proofSource"] as? String == "runtime.input")
        #expect(action?["source"] as? String == "workspace.action-provider")
        #expect(action?["command"] as? [String] == ["triton", "act", "tap", "Continue", "--json"])
        #expect(action?["sourceCommands"] as? [String] == ["triton act tap Continue --json", "runtime input tap"])
        let input = action?["inputResult"] as? [String: Any]
        #expect(input?["ok"] as? Bool == true)
        #expect(input?["action"] as? String == "tap")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let actionEvent = parsed.events.first { $0.type == .actionExecuted }
        #expect(actionEvent?.status == .passed)
        #expect(actionEvent?.ref == "evidence/actions/action-000.json")

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let transition = (atlas?["transitions"] as? [[String: Any]])?.first
        #expect(transition?["status"] as? String == "executed_unverified")
    }

    @Test("workspace run derives explicit action candidate from observation")
    func workspaceRunDerivesExplicitActionCandidateFromObservation() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root, visibleTexts: ["Welcome", "Start"])
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-observation-candidate",
                target: "runtime-target-candidate",
                app: "com.example.demo",
                goal: "Open start screen",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                executeActions: true
            ),
            actionExecutionProvider: { request in
                actionRequest = request
                return successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "stopped")
        #expect(actionRequest?.query == "Start")
        #expect(actionRequest?.command == ["triton", "act", "tap", "Start", "--json"])

        let runDir = root.appendingPathComponent("run-workspace-observation-candidate", isDirectory: true)
        let decision = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/decision-000.json"))
        ) as? [String: Any]
        #expect(decision?["command"] as? [String] == ["triton", "act", "tap", "Start", "--json"])
        #expect(decision?["candidateSource"] as? String == "observation.visibleTexts")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let actionEvent = parsed.events.first { $0.type == .actionExecuted }
        #expect(actionEvent?.command == ["triton", "act", "tap", "Start", "--json"])

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let transition = (atlas?["transitions"] as? [[String: Any]])?.first
        let selector = transition?["selector"] as? [String: Any]
        #expect(selector?["text"] as? String == "Start")
    }

    @Test("workspace model provider output drives explicit action candidate")
    func workspaceModelProviderOutputDrivesExplicitActionCandidate() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root, visibleTexts: ["Welcome", "Begin"])
        var providerRequest: TKWorkspaceModelDecisionRequest?
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-provider-candidate",
                target: "runtime-target-provider",
                app: "com.example.demo",
                goal: "Start onboarding",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                executeActions: true
            ),
            modelDecisionProvider: { request in
                providerRequest = request
                return TKWorkspaceModelDecision(
                    candidate: TKWorkspaceActionCandidate(
                        action: "tap",
                        query: "Begin",
                        source: "llm-vlm.provider"
                    ),
                    confidence: 0.87,
                    summary: "Provider selected the visible onboarding entry.",
                    expected: "Begin opens onboarding.",
                    usedVLM: true,
                    requestContext: [
                        "providerRequestId": "fake-model-request-1",
                    ],
                    bootstrapResponseText: #"{"action":"tap","query":"Begin","confidence":0.87}"#,
                    decisionResponseText: #"{"action":"tap","query":"Begin","confidence":0.87}"#
                )
            },
            actionExecutionProvider: { request in
                actionRequest = request
                return successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "stopped")
        #expect(providerRequest?.visibleTexts == ["Welcome", "Begin"])
        #expect(providerRequest?.allowedActions.contains("tap") == true)
        #expect(actionRequest?.query == "Begin")
        #expect(actionRequest?.command == ["triton", "act", "tap", "Begin", "--json"])

        let runDir = root.appendingPathComponent("run-workspace-provider-candidate", isDirectory: true)
        let decisionRequest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/decision-000-request.redacted.json"))
        ) as? [String: Any]
        #expect(decisionRequest?["providerRequestId"] as? String == "fake-model-request-1")
        #expect(decisionRequest?["visibleTexts"] as? [String] == ["Welcome", "Begin"])

        let decisionResponse = try String(
            contentsOf: runDir.appendingPathComponent("evidence/model/decision-000-response.raw.txt"),
            encoding: .utf8
        )
        #expect(decisionResponse.contains(#""query":"Begin""#))

        let decision = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/decision-000.json"))
        ) as? [String: Any]
        #expect(decision?["command"] as? [String] == ["triton", "act", "tap", "Begin", "--json"])
        #expect(decision?["candidateSource"] as? String == "llm-vlm.provider")
        #expect(decision?["confidence"] as? Double == 0.87)

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let actionEvent = parsed.events.first { $0.type == .actionExecuted }
        #expect(actionEvent?.command == ["triton", "act", "tap", "Begin", "--json"])
    }

    @Test("workspace run grounds tap candidate with VLM before action execution")
    func workspaceRunGroundsTapCandidateWithVLMBeforeActionExecution() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let screenshot = root.appendingPathComponent("login.png")
        try writeFixtureImage(to: screenshot)
        let fixture = try writeObservationFixture(
            in: root,
            visibleTexts: ["Welcome", "Continue"],
            screenshot: screenshot.path
        )
        var groundingRequest: TKWorkspaceVLMGroundingRequest?
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-vlm-grounded-action",
                target: "runtime-target-vlm",
                app: "com.example.demo",
                goal: "Continue onboarding",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                executeActions: true
            ),
            vlmGroundingProvider: { request in
                groundingRequest = request
                return fakeVLMGrounding(for: request)
            },
            actionExecutionProvider: { request in
                actionRequest = request
                return successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "stopped")
        #expect(groundingRequest?.provider == "mock")
        #expect(groundingRequest?.image == screenshot.path)
        #expect(groundingRequest?.target == "Continue")
        #expect(groundingRequest?.coordinateContract.hasSuffix("coordinate-contract.json") == true)
        #expect(groundingRequest?.outputDirectory.hasSuffix("evidence/actions/vlm-000") == true)
        #expect(actionRequest?.vlmGrounding?.target == "Continue")
        #expect(actionRequest?.vlmGrounding?.point.runtimePoint.x == 201)
        #expect(actionRequest?.vlmGrounding?.point.runtimePoint.y == 437)

        let runDir = root.appendingPathComponent("run-workspace-vlm-grounded-action", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("coordinate-contract.json").path))
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/actions/vlm-000/vlm-grounding.json").path))
        let action = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/actions/action-000.json"))
        ) as? [String: Any]
        #expect(action?["proofSource"] as? String == "vlm.grounding+runtime.input")
        #expect(action?["usedVLMGrounding"] as? Bool == true)
        let grounding = action?["vlmGrounding"] as? [String: Any]
        #expect(grounding?["ref"] as? String == "evidence/actions/vlm-000/vlm-grounding.json")
        #expect(grounding?["overlay"] as? String == "evidence/actions/vlm-000/vlm-overlay.png")
    }

    @Test("workspace run passes mlx-swift-lm helper options into VLM grounding")
    func workspaceRunPassesMLXSwiftLMHelperOptionsIntoVLMGrounding() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let screenshot = root.appendingPathComponent("login.png")
        try writeFixtureImage(to: screenshot)
        let fixture = try writeObservationFixture(
            in: root,
            visibleTexts: ["Welcome", "Continue"],
            screenshot: screenshot.path
        )
        let modelPath = root.appendingPathComponent("models/qwen-vl", isDirectory: true).path
        let helperPath = root.appendingPathComponent("bin/triton-mlx-provider").path
        var groundingRequest: TKWorkspaceVLMGroundingRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-mlx-vlm-grounded-action",
                target: "runtime-target-mlx-vlm",
                app: "com.example.demo",
                goal: "Continue onboarding",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mlx-swift-lm",
                vlmModelPath: modelPath,
                vlmHelper: helperPath,
                vlmAllowModelDownload: true,
                observationFixture: fixture.path,
                executeActions: true
            ),
            vlmGroundingProvider: { request in
                groundingRequest = request
                return fakeVLMGrounding(for: request)
            },
            actionExecutionProvider: { request in
                successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "stopped")
        #expect(groundingRequest?.provider == "mlx-swift-lm")
        #expect(groundingRequest?.modelPath == modelPath)
        #expect(groundingRequest?.mlxHelperPath == helperPath)
        #expect(groundingRequest?.allowModelDownload == true)
        #expect(groundingRequest?.model == nil)
        #expect(groundingRequest?.target == "Continue")
    }

    @Test("workspace run pauses with recovery proposal when VLM grounding fails")
    func workspaceRunPausesWithRecoveryProposalWhenVLMGroundingFails() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let screenshot = root.appendingPathComponent("login.png")
        try writeFixtureImage(to: screenshot)
        let fixture = try writeObservationFixture(
            in: root,
            visibleTexts: ["Welcome", "Continue"],
            screenshot: screenshot.path
        )
        var groundingRequest: TKWorkspaceVLMGroundingRequest?
        var actionExecuted = false

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-vlm-grounding-failed",
                target: "runtime-target-vlm-failure",
                app: "com.example.demo",
                goal: "Continue onboarding",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                executeActions: true
            ),
            vlmGroundingProvider: { request in
                groundingRequest = request
                throw TKVLMGroundingFailure(
                    code: "vlm_target_not_visible",
                    message: "The target is not visible in the screenshot.",
                    hint: "Observe again or choose a visible target."
                )
            },
            actionExecutionProvider: { request in
                actionExecuted = true
                return successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "paused")
        #expect(run.nextActions.contains { $0.code == "inspect_vlm_grounding_failure" })
        #expect(groundingRequest?.target == "Continue")
        #expect(actionExecuted == false)

        let runDir = root.appendingPathComponent("run-workspace-vlm-grounding-failed", isDirectory: true)
        let action = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/actions/action-000.json"))
        ) as? [String: Any]
        #expect(action?["ok"] as? Bool == false)
        #expect(action?["failureCode"] as? String == "vlm_target_not_visible")
        #expect(action?["failureKind"] as? String == "vlm_grounding_failed")
        #expect(action?["proofSource"] as? String == "vlm.grounding")
        #expect(action?["usedVLMGrounding"] as? Bool == false)
        let vlmFailure = try #require(action?["vlmGroundingFailure"] as? [String: Any])
        #expect(vlmFailure["code"] as? String == "vlm_target_not_visible")
        #expect(vlmFailure["hint"] as? String == "Observe again or choose a visible target.")

        let recovery = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
        ) as? [String: Any]
        #expect(recovery?["kind"] as? String == "triton.workspace.recovery-proposal")
        #expect(recovery?["failureCode"] as? String == "vlm_target_not_visible")
        #expect(recovery?["trigger"] as? String == "vlm_grounding_failed")
        let diagnosis = try #require(recovery?["diagnosis"] as? [String: Any])
        #expect(diagnosis["type"] as? String == "vlm_grounding_failed")
        let diagnosisRefs = try #require(diagnosis["evidenceRefs"] as? [String])
        #expect(diagnosisRefs.contains("evidence/actions/action-000.json"))
        #expect(diagnosisRefs.contains("evidence/actions/vlm-000/vlm-failure.json"))
        let proposal = try #require(recovery?["proposal"] as? [String: Any])
        #expect(proposal["action"] as? String == "stop")
        #expect(proposal["policyDecision"] as? String == "requires_review")
        let nextActions = try #require(recovery?["nextActions"] as? [[String: Any]])
        #expect(nextActions.first?["code"] as? String == "inspect_vlm_grounding_failure")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type == .actionExecuted }?.status == .failed)
        #expect(parsed.events.first { $0.type == .flowRecoveryDetected }?.failure?.type == "vlm_target_not_visible")
        #expect(parsed.events.last?.type == .runPaused)
    }

    @Test("workspace run verifies business readiness after explicit action execution")
    func workspaceRunVerifiesBusinessReadinessAfterExplicitActionExecution() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        var actionCount = 0
        var waitCount = 0

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-post-action-business-ready",
                target: "runtime-target-post-action",
                app: "com.example.demo",
                goal: "Open dashboard",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                businessReadyText: "Dashboard",
                businessReadyLiveWait: true,
                businessReadyTimeout: 2,
                businessReadyInterval: 0.25,
                executeActions: true
            ),
            businessWaitProvider: { request in
                waitCount += 1
                return actionCount > 0
                    ? successfulBusinessWaitResult(
                        query: request.query,
                        timeout: request.timeout,
                        interval: request.interval
                    )
                    : failedBusinessWaitResult(
                        query: request.query,
                        timeout: request.timeout,
                        interval: request.interval
                    )
            },
            actionExecutionProvider: { request in
                actionCount += 1
                return successfulActionExecution(for: request)
            }
        )

        #expect(actionCount == 1)
        #expect(waitCount == 1)
        #expect(run.status == "passed")
        #expect(run.business?.ready == true)
        #expect(run.business?.check == "runtime_wait")
        #expect(run.business?.phase == "post_action_wait_matched")

        let runDir = root.appendingPathComponent("run-workspace-post-action-business-ready", isDirectory: true)
        let business = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/business/ready.json"))
        ) as? [String: Any]
        #expect(business?["ready"] as? Bool == true)
        #expect(business?["stage"] as? String == "post_action")
        #expect(business?["phase"] as? String == "post_action_wait_matched")
        #expect((business?["evidenceRefs"] as? [String])?.contains("events.jsonl#action.executed") == true)
        #expect((business?["evidenceRefs"] as? [String])?.contains("evidence/actions/action-000.json") == true)

        let verify = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/verify-000.json"))
        ) as? [String: Any]
        #expect(verify?["status"] as? String == "passed")
        #expect(verify?["businessRef"] as? String == "evidence/business/ready.json")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let actionIndex = try #require(parsed.events.firstIndex { $0.type == .actionExecuted })
        let businessIndex = try #require(parsed.events.firstIndex {
            $0.type == .businessReady && $0.phase == "post_action_wait_matched"
        })
        let verifyIndex = try #require(parsed.events.firstIndex {
            $0.type == .verifyChecked && $0.status == .passed
        })
        #expect(actionIndex < businessIndex)
        #expect(businessIndex < verifyIndex)
        #expect(parsed.events.last?.type == .runFinished)
        #expect(parsed.summary.status == .passed)

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let transition = (atlas?["transitions"] as? [[String: Any]])?.first
        #expect(transition?["status"] as? String == "verified")
    }

    @Test("workspace run captures post-action observation and atlas transition")
    func workspaceRunCapturesPostActionObservationAndAtlasTransition() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var observeRequests: [TKWorkspaceLiveObserveRequest] = []
        var actionCount = 0
        var waitCount = 0

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-post-action-observe",
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Open dashboard",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observeLive: true,
                observeKind: "tree",
                observeMaxNodes: 25,
                businessReadyText: "Dashboard",
                businessReadyLiveWait: true,
                businessReadyTimeout: 2,
                businessReadyInterval: 0.25,
                executeActions: true
            ),
            observeProvider: { request in
                observeRequests.append(request)
                return observeRequests.count == 1
                    ? fakeLiveObserveOutput(
                        for: request,
                        visibleTexts: ["Login", "Continue"],
                        artifactStem: "login"
                    )
                    : fakeLiveObserveOutput(
                        for: request,
                        visibleTexts: ["Dashboard"],
                        artifactStem: "dashboard"
                    )
            },
            businessWaitProvider: { request in
                waitCount += 1
                return successfulBusinessWaitResult(
                    query: request.query,
                    timeout: request.timeout,
                    interval: request.interval
                )
            },
            actionExecutionProvider: { request in
                actionCount += 1
                return successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "passed")
        #expect(actionCount == 1)
        #expect(waitCount == 1)
        #expect(observeRequests.count == 2)
        #expect(observeRequests.allSatisfy { $0.action == "observe.tree" })

        let runDir = root.appendingPathComponent("run-workspace-post-action-observe", isDirectory: true)
        let initialObservationURL = runDir.appendingPathComponent("evidence/observations/0000.json")
        let postActionObservationURL = runDir.appendingPathComponent("evidence/observations/0001.json")
        #expect(FileManager.default.fileExists(atPath: initialObservationURL.path))
        #expect(FileManager.default.fileExists(atPath: postActionObservationURL.path))
        let postActionObservation = try JSONSerialization.jsonObject(
            with: Data(contentsOf: postActionObservationURL)
        ) as? [String: Any]
        let postActionNodes = postActionObservation?["nodes"] as? [[String: Any]]
        #expect(postActionNodes?.first?["text"] as? String == "Dashboard")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let observationEvents = parsed.events.filter { $0.type == .observationCaptured }
        #expect(observationEvents.count == 2)
        #expect(observationEvents.first?.stepIndex == 0)
        #expect(observationEvents.first?.phase == "initial")
        #expect(observationEvents.last?.stepIndex == 1)
        #expect(observationEvents.last?.phase == "post_action")
        #expect(observationEvents.last?.screenCandidate?.visibleTexts == ["Dashboard"])

        let actionIndex = try #require(parsed.events.firstIndex { $0.type == .actionExecuted })
        let postObservationIndex = try #require(parsed.events.firstIndex {
            $0.type == .observationCaptured && $0.phase == "post_action"
        })
        let businessIndex = try #require(parsed.events.firstIndex {
            $0.type == .businessReady && $0.phase == "post_action_wait_matched"
        })
        #expect(actionIndex < postObservationIndex)
        #expect(postObservationIndex < businessIndex)

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let screens = atlas?["screens"] as? [[String: Any]]
        let states = atlas?["states"] as? [[String: Any]]
        let transition = (atlas?["transitions"] as? [[String: Any]])?.first
        let coverage = atlas?["coverage"] as? [String: Any]
        #expect(screens?.count == 2)
        #expect(states?.count == 2)
        #expect(screens?.first { $0["screenId"] as? String == "screen_0001" }?["dominantTexts"] as? [String] == ["Dashboard"])
        #expect(states?.first { $0["stateId"] as? String == "state_0001" }?["phase"] as? String == "post_action")
        #expect(transition?["fromScreenId"] as? String == "screen_0000")
        #expect(transition?["toScreenId"] as? String == "screen_0001")
        #expect(transition?["status"] as? String == "verified")
        #expect(coverage?["screenCount"] as? Int == 2)
        #expect(coverage?["stateCount"] as? Int == 2)
        #expect(coverage?["transitionCount"] as? Int == 1)

        let deltas = try String(
            contentsOf: runDir.appendingPathComponent("atlas/deltas.jsonl"),
            encoding: .utf8
        )
        #expect(deltas.contains(#""toScreenId":"screen_0001""#))
    }

    @Test("workspace run continues bounded loop after failed business checkpoint")
    func workspaceRunContinuesBoundedLoopAfterFailedBusinessCheckpoint() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        var observeRequests: [TKWorkspaceLiveObserveRequest] = []
        var decisionRequests: [TKWorkspaceModelDecisionRequest] = []
        var actionRequests: [TKWorkspaceActionExecutionRequest] = []
        var waitCount = 0

        let snapshots: [([String], String)] = [
            (["Login", "Continue"], "login"),
            (["Interstitial", "Next"], "interstitial"),
            (["Dashboard"], "dashboard"),
        ]

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-bounded-loop",
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Reach dashboard through intermediate screen",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                maxSteps: 2,
                observeLive: true,
                observeKind: "tree",
                observeMaxNodes: 25,
                businessReadyText: "Dashboard",
                businessReadyLiveWait: true,
                businessReadyTimeout: 2,
                businessReadyInterval: 0.25,
                executeActions: true
            ),
            observeProvider: { request in
                observeRequests.append(request)
                let snapshot = snapshots[min(observeRequests.count - 1, snapshots.count - 1)]
                return fakeLiveObserveOutput(
                    for: request,
                    visibleTexts: snapshot.0,
                    artifactStem: snapshot.1
                )
            },
            businessWaitProvider: { request in
                waitCount += 1
                if waitCount == 1 {
                    return failedBusinessWaitResult(
                        query: request.query,
                        timeout: request.timeout,
                        interval: request.interval
                    )
                }
                return successfulBusinessWaitResult(
                    query: request.query,
                    timeout: request.timeout,
                    interval: request.interval
                )
            },
            modelDecisionProvider: { request in
                decisionRequests.append(request)
                return workspaceDefaultModelDecision(request)
            },
            actionExecutionProvider: { request in
                actionRequests.append(request)
                return successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "passed")
        #expect(observeRequests.count == 3)
        #expect(decisionRequests.map(\.visibleTexts) == [
            ["Login", "Continue"],
            ["Interstitial", "Next"],
        ])
        #expect(actionRequests.compactMap(\.query) == ["Continue", "Next"])
        #expect(waitCount == 2)

        let runDir = root.appendingPathComponent("run-workspace-bounded-loop", isDirectory: true)
        for relativePath in [
            "evidence/actions/action-000.json",
            "evidence/actions/action-001.json",
            "evidence/model/decision-000.json",
            "evidence/model/decision-001.json",
            "evidence/model/recovery-000.json",
            "evidence/model/verify-000.json",
            "evidence/model/verify-001.json",
            "evidence/observations/0002.json",
        ] {
            #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent(relativePath).path))
        }

        let recovery = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/model/recovery-000.json"))
        ) as? [String: Any]
        #expect(recovery?["schemaVersion"] as? Int == 1)
        #expect(recovery?["kind"] as? String == "triton.workspace.recovery-proposal")
        #expect(recovery?["failureCode"] as? String == "business_checkpoint_missing")
        #expect(recovery?["trigger"] as? String == "business_checkpoint_failed")
        #expect(recovery?["stepIndex"] as? Int == 1)
        let diagnosis = try #require(recovery?["diagnosis"] as? [String: Any])
        #expect(diagnosis["type"] as? String == "business_checkpoint_missing")
        #expect(diagnosis["phase"] as? String == "post_action_wait_timeout")
        #expect(diagnosis["confidence"] as? Double != nil)
        let diagnosisRefs = try #require(diagnosis["evidenceRefs"] as? [String])
        #expect(diagnosisRefs.contains("events.jsonl#business.ready"))
        #expect(diagnosisRefs.contains("events.jsonl#verify.checked"))
        #expect(diagnosisRefs.contains("evidence/model/decision-000.json"))
        #expect(diagnosisRefs.contains("evidence/actions/action-000.json"))
        #expect(diagnosisRefs.contains("evidence/business/ready.json"))
        #expect(diagnosisRefs.contains("evidence/model/verify-000.json"))
        let proposal = try #require(recovery?["proposal"] as? [String: Any])
        #expect(proposal["action"] as? String == "continue")
        #expect(proposal["policyDecision"] as? String == "allowed")
        #expect(proposal["usesLatestObservation"] as? Bool == true)
        #expect(proposal["nextStepIndex"] as? Int == 2)
        #expect(proposal["command"] as? [String] == ["continue"])
        let nextActions = try #require(recovery?["nextActions"] as? [[String: Any]])
        #expect(nextActions.first?["code"] as? String == "continue_from_latest_observation")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        let actionEvents = parsed.events.filter { $0.type == .actionExecuted }
        #expect(actionEvents.map(\.stepIndex) == [1, 2])
        let modelEvents = parsed.events.filter { $0.type == .modelDecided }
        #expect(modelEvents.map(\.stepIndex) == [1, 2])
        let observationEvents = parsed.events.filter { $0.type == .observationCaptured }
        #expect(observationEvents.map(\.stepIndex) == [0, 1, 2])
        #expect(observationEvents.last?.screenCandidate?.visibleTexts == ["Dashboard"])
        let businessEvents = parsed.events.filter { $0.type == .businessReady }
        #expect(businessEvents.map(\.phase) == ["post_action_wait_timeout", "post_action_wait_matched"])
        #expect(parsed.events.last?.type == .runFinished)

        let atlas = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))
        ) as? [String: Any]
        let screens = try #require(atlas?["screens"] as? [[String: Any]])
        let states = try #require(atlas?["states"] as? [[String: Any]])
        let transitions = try #require(atlas?["transitions"] as? [[String: Any]])
        let coverage = try #require(atlas?["coverage"] as? [String: Any])
        #expect(screens.count == 3)
        #expect(states.count == 3)
        #expect(transitions.count == 2)
        #expect(screens.last?["dominantTexts"] as? [String] == ["Dashboard"])
        #expect(transitions.map { $0["transitionId"] as? String } == ["transition_0000", "transition_0001"])
        #expect(transitions.map { $0["status"] as? String } == ["verification_failed", "verified"])
        #expect(transitions.first?["fromScreenId"] as? String == "screen_0000")
        #expect(transitions.first?["toScreenId"] as? String == "screen_0001")
        #expect(transitions.last?["fromScreenId"] as? String == "screen_0001")
        #expect(transitions.last?["toScreenId"] as? String == "screen_0002")
        #expect(coverage["screenCount"] as? Int == 3)
        #expect(coverage["stateCount"] as? Int == 3)
        #expect(coverage["transitionCount"] as? Int == 2)

        let deltas = try String(
            contentsOf: runDir.appendingPathComponent("atlas/deltas.jsonl"),
            encoding: .utf8
        )
        #expect(deltas.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 2)
        #expect(deltas.contains(#""transitionId":"transition_0001""#))

        let appMapRoot = runDir.appendingPathComponent("atlas/app-map", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: appMapRoot.appendingPathComponent("app-map.json").path))
        #expect(FileManager.default.fileExists(atPath: appMapRoot.appendingPathComponent("paths/path-login-dashboard.json").path))
        let appMap = try JSONDecoder().decode(
            TKAppMapDocument.self,
            from: Data(contentsOf: appMapRoot.appendingPathComponent("app-map.json"))
        )
        #expect(appMap.screenCount == 3)
        #expect(appMap.transitionCount == 2)
        #expect(appMap.pathCount == 1)
        let paths = try listTritonAppMapPaths(mapPath: appMapRoot.path)
        #expect(paths.paths.map(\.pathID) == ["path-login-dashboard"])
        #expect(paths.paths.first?.transitions.count == 2)
        #expect(paths.paths.first?.sourceRuns == ["run-workspace-bounded-loop"])
        let inspected = try inspectWorkspaceRun(
            runID: "run-workspace-bounded-loop",
            runsDirectory: root.path
        )
        let appMapSummary = try #require(inspected.appMap)
        #expect(appMapSummary.mapRef == "atlas/app-map/app-map.json")
        #expect(appMapSummary.screenCount == 3)
        #expect(appMapSummary.transitionCount == 2)
        #expect(appMapSummary.pathCount == 1)
        #expect(appMapSummary.pathIDs == ["path-login-dashboard"])
    }

    @Test("workspace app map merge accumulates repeated runs")
    func workspaceAppMapMergeAccumulatesRepeatedRuns() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mapDir = root.appendingPathComponent("workspace.tritonmap", isDirectory: true)

        try await runDashboardPath(runID: "run-workspace-map-merge-1", root: root)
        try await runDashboardPath(runID: "run-workspace-map-merge-2", root: root)

        let firstMerge = try mergeWorkspaceRunAppMap(
            runID: "run-workspace-map-merge-1",
            runsDirectory: root.path,
            mapDirectory: mapDir.path,
            confirm: true
        )
        #expect(firstMerge.screenCount == 3)
        #expect(firstMerge.transitionCount == 2)
        #expect(firstMerge.pathCount == 1)
        #expect(firstMerge.pathIDs == ["path-login-dashboard"])

        let secondMerge = try mergeWorkspaceRunAppMap(
            runID: "run-workspace-map-merge-2",
            runsDirectory: root.path,
            mapDirectory: mapDir.path,
            confirm: true
        )
        #expect(secondMerge.screenCount == 3)
        #expect(secondMerge.transitionCount == 2)
        #expect(secondMerge.pathCount == 1)
        #expect(secondMerge.pathIDs == ["path-login-dashboard"])
        #expect(secondMerge.coverage.observedRuns == 2)
        #expect(secondMerge.coverage.screenCount == 3)
        #expect(secondMerge.coverage.stateCount == 3)
        #expect(secondMerge.coverage.pathCount == 1)
        #expect(secondMerge.coverage.confirmedPathCount == 1)

        let inspect = try inspectTritonAppMap(mapPath: mapDir.path)
        #expect(inspect.screenCount == 3)
        #expect(inspect.transitionCount == 2)
        #expect(inspect.pathCount == 1)
        #expect(inspect.coverage.observedRuns == 2)
        #expect(inspect.coverage.stateCount == 3)
        #expect(inspect.health.observedRuns == 2)
        #expect(inspect.health.passCount == 2)

        let path = try #require(listTritonAppMapPaths(mapPath: mapDir.path).paths.first)
        #expect(path.pathID == "path-login-dashboard")
        #expect(path.sourceRuns == ["run-workspace-map-merge-1", "run-workspace-map-merge-2"])
        #expect(path.health.observedRuns == 2)
        #expect(path.health.passCount == 2)
        #expect(path.confirmed)

        let index = try JSONDecoder().decode(
            TKAppMapDocument.self,
            from: Data(contentsOf: mapDir.appendingPathComponent("app-map.json"))
        )
        #expect(index.coverage?.observedRuns == 2)
        #expect(index.coverage?.stateCount == 3)
        #expect(index.coverage?.confirmedPathCount == 1)

        let startScreen = try JSONDecoder().decode(
            TKAppMapScreen.self,
            from: Data(contentsOf: mapDir.appendingPathComponent("screens/\(path.startScreenID).json"))
        )
        let initialVariant = try #require(startScreen.stateVariants.first { $0.stateID == "state_0000" })
        #expect(initialVariant.runLocalScreenID == "screen_0000")
        #expect(initialVariant.phase == "initial")
        #expect(initialVariant.sourceRuns == ["run-workspace-map-merge-1", "run-workspace-map-merge-2"])
        #expect(initialVariant.visibleTexts.contains("Login"))
        #expect(initialVariant.evidenceRefs.contains("events.jsonl#observation.captured"))
    }

    @Test("workspace run skips explicit action execution after business checkpoint passes")
    func workspaceRunSkipsExplicitActionExecutionAfterBusinessCheckpointPasses() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        var actionCalled = false

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-skip-action-after-business-ready",
                target: "runtime-target-1",
                app: "com.example.demo",
                goal: "Open next screen",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                businessReadyText: "Continue",
                executeActions: true
            ),
            actionExecutionProvider: { request in
                actionCalled = true
                return successfulActionExecution(for: request)
            }
        )

        #expect(actionCalled == false)
        #expect(run.status == "passed")
        let runDir = root.appendingPathComponent("run-workspace-skip-action-after-business-ready", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/actions/action-000.json").path) == false)
    }

    @Test("workspace HTTP run maps explicit action execution option")
    func workspaceHTTPRunMapsExplicitActionExecutionOption() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let body = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(
            runsDir: root.path,
            runID: "run-workspace-http-execute-action",
            target: "runtime-target-http",
            platform: "ios",
            scope: "simulator",
            app: "com.example.demo",
            goal: "Open next screen",
            actionPolicy: "explore",
            llmProvider: "mock",
            vlmProvider: "mock",
            observationFixture: fixture.path,
            observeHost: "127.0.0.3",
            observePort: 19423,
            executeActions: true
        ))
        let run = try await handleWorkspaceHTTPRunAsync(body: body, actionExecutionProvider: { request in
            actionRequest = request
            return successfulActionExecution(for: request)
        })

        #expect(actionRequest?.target == "runtime-target-http")
        #expect(actionRequest?.host == "127.0.0.3")
        #expect(actionRequest?.port == 19423)
        #expect(actionRequest?.platform == "ios")
        #expect(actionRequest?.scope == "simulator")
        #expect(run.status == "stopped")
        let runDir = root.appendingPathComponent("run-workspace-http-execute-action", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/actions/action-000.json").path))
    }

    @Test("workspace HTTP run resolves target before action execution")
    func workspaceHTTPRunResolvesTargetBeforeActionExecution() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        let selected = HostDeviceTarget(
            platform: "android",
            id: "host:android:emulator-5554",
            target: "emulator-5554",
            state: "device",
            ready: true,
            source: "adb",
            name: "Pixel_9",
            runtime: "API 36",
            transport: "local",
            scope: "emulator",
            kind: "emulator"
        )
        var resolveRequest: TKWorkspaceTargetResolveRequest?
        var actionRequest: TKWorkspaceActionExecutionRequest?

        let body = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(
            runsDir: root.path,
            runID: "run-workspace-http-resolve-target",
            target: "android-emulator",
            platform: "android",
            scope: "emulator",
            app: "com.example.demo",
            goal: "Open next screen",
            actionPolicy: "explore",
            llmProvider: "mock",
            vlmProvider: "mock",
            observationFixture: fixture.path,
            resolveTarget: true,
            executeActions: true
        ))
        let run = try await handleWorkspaceHTTPRunAsync(
            body: body,
            targetResolver: { request in
                resolveRequest = request
                return TKWorkspaceTargetResolution(
                    selection: HostDeviceSelectionResult(
                        platform: .android,
                        target: selected,
                        selector: "android-emulator",
                        source: .alias,
                        filters: HostDeviceSelectionFilters(request: HostDeviceSelectionRequest(device: "android-emulator", platform: .android, scope: .emulator))
                    ),
                    sourceCommands: ["triton target resolve android-emulator --platform android --scope emulator --json"]
                )
            },
            actionExecutionProvider: { request in
                actionRequest = request
                return successfulActionExecution(for: request)
            }
        )

        #expect(resolveRequest?.enabled == true)
        #expect(resolveRequest?.selector == "android-emulator")
        #expect(resolveRequest?.platform == "android")
        #expect(resolveRequest?.scope == "emulator")
        #expect(actionRequest?.target == "emulator-5554")
        #expect(actionRequest?.platform == "android")
        #expect(actionRequest?.scope == "emulator")
        #expect(run.target.id == "host:android:emulator-5554")
        #expect(run.target.hostTarget == "emulator-5554")
    }

    private func temporaryRunsDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-workspace-action-execution-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func runDashboardPath(runID: String, root: URL) async throws {
        var observeRequests: [TKWorkspaceLiveObserveRequest] = []
        var waitCount = 0
        let snapshots: [([String], String)] = [
            (["Login", "Continue"], "login"),
            (["Interstitial", "Next"], "interstitial"),
            (["Dashboard"], "dashboard"),
        ]

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: runID,
                target: "booted",
                platform: "ios",
                scope: "simulator",
                app: "com.example.demo",
                goal: "Reach dashboard through intermediate screen",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                maxSteps: 2,
                observeLive: true,
                businessReadyText: "Dashboard",
                businessReadyLiveWait: true,
                businessReadyTimeout: 2,
                businessReadyInterval: 0.25,
                executeActions: true
            ),
            observeProvider: { request in
                observeRequests.append(request)
                let snapshot = snapshots[min(observeRequests.count - 1, snapshots.count - 1)]
                return fakeLiveObserveOutput(
                    for: request,
                    visibleTexts: snapshot.0,
                    artifactStem: snapshot.1
                )
            },
            businessWaitProvider: { request in
                waitCount += 1
                if waitCount == 1 {
                    return failedBusinessWaitResult(
                        query: request.query,
                        timeout: request.timeout,
                        interval: request.interval
                    )
                }
                return successfulBusinessWaitResult(
                    query: request.query,
                    timeout: request.timeout,
                    interval: request.interval
                )
            },
            actionExecutionProvider: { request in
                successfulActionExecution(for: request)
            }
        )

        #expect(run.status == "passed")
    }

    private func writeObservationFixture(
        in root: URL,
        visibleTexts: [String] = ["Login", "Continue"],
        screenshot: String = "fixtures/login.png"
    ) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = root.appendingPathComponent("observation.json")
        let visibleTextsJSON = String(
            data: try JSONEncoder().encode(visibleTexts),
            encoding: .utf8
        ) ?? "[]"
        try """
        {
          "schemaVersion": 1,
          "kind": "triton.workspace.observation-fixture",
          "artifacts": {
            "screenshot": "\(screenshot)",
            "hierarchy": "fixtures/login-hierarchy.json",
            "ax": "fixtures/login-ax.json"
          },
          "screenCandidate": {
            "screenshotSha256": "sha-login-screen",
            "axTextHash": "ax-login-text",
            "hierarchySha256": "hier-login-tree",
            "visibleTexts": \(visibleTextsJSON)
          },
          "sourceCommands": ["triton observe current --json"],
          "changed": true
        }
        """.write(to: fixture, atomically: true, encoding: .utf8)
        return fixture
    }

    private func writeFixtureImage(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let width = 402
        let height = 874
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw RuntimeError("Could not allocate fixture bitmap")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSColor.black.set()
        ("Continue" as NSString).draw(
            at: NSPoint(x: 140, y: 220),
            withAttributes: [.font: NSFont.systemFont(ofSize: 20)]
        )
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RuntimeError("Could not encode fixture image")
        }
        try data.write(to: url, options: .atomic)
    }

    private func fakeVLMGrounding(for request: TKWorkspaceVLMGroundingRequest) -> TKVLMGroundResponse {
        TKVLMGroundResponse(
            provider: request.provider,
            model: request.model,
            baseURL: redactedVLMBaseURL(request.baseURL),
            target: request.target,
            image: TKVLMGroundImage(path: request.image, width: 402, height: 874, sha256: "image-sha"),
            coordinateContract: TKVLMGroundCoordinateContractRef(
                path: request.coordinateContract,
                canonicalTapSpace: "runtime-point"
            ),
            point: TKVLMGroundPoint(
                normalized: TKVLMNormalizedPoint(x: 500, y: 500),
                runtimePoint: TKVLMRuntimePoint(x: 201, y: 437),
                coordinateSpace: "runtime-point"
            ),
            transform: TKVLMCoordinateTransform(
                inputSpace: "normalized_0_1000",
                imageSpace: "image-pixel",
                outputSpace: "runtime-point",
                imageWidth: 402,
                imageHeight: 874,
                runtimeWidth: 402,
                runtimeHeight: 874,
                scale: 1,
                orientation: "portrait",
                source: request.coordinateContract
            ),
            artifacts: TKVLMGroundArtifacts(
                overlay: URL(fileURLWithPath: request.outputDirectory).appendingPathComponent("vlm-overlay.png").path,
                request: URL(fileURLWithPath: request.outputDirectory).appendingPathComponent("vlm-request.redacted.json").path,
                response: URL(fileURLWithPath: request.outputDirectory).appendingPathComponent("vlm-response.json").path
            )
        )
    }

    private func successfulActionExecution(
        for request: TKWorkspaceActionExecutionRequest
    ) -> TKWorkspaceActionExecutionResult {
        TKWorkspaceActionExecutionResult(
            ok: true,
            action: request.action,
            command: request.command,
            proofSource: request.vlmGrounding == nil ? "runtime.input" : "vlm.grounding+runtime.input",
            sourceCommands: [request.command.map { $0 }.joined(separator: " "), "runtime input tap"],
            message: "submitted",
            inputResult: TKInputResult.success(
                action: "tap",
                message: "tap submitted",
                targetOID: 42,
                targetClassName: "UIButton",
                matchedOID: 42,
                matchedClassName: "UIButton",
                activationOID: 42,
                activationClassName: "UIButton",
                strategy: "exact"
            ),
            tapResolution: nil,
            vlmGrounding: request.vlmGrounding
        )
    }

    private func fakeLiveObserveOutput(
        for request: TKWorkspaceLiveObserveRequest,
        visibleTexts: [String],
        artifactStem: String
    ) -> ObserveOutput {
        ObserveOutput(
            ok: true,
            action: request.action,
            platform: request.platform.rawValue,
            capturedAt: "2026-07-07T00:00:00Z",
            partial: false,
            target: "sim:\(request.target)",
            primarySource: ObserveSourceOutput(
                name: "host-layout",
                available: true,
                reason: nil,
                artifact: "fixtures/\(artifactStem)-tree.json",
                sourceCommands: ["triton sim ax --device \(request.target) --json"]
            ),
            sources: [
                ObserveSourceOutput(
                    name: "host-layout",
                    available: true,
                    reason: nil,
                    artifact: "fixtures/\(artifactStem)-tree.json",
                    sourceCommands: ["triton sim ax --device \(request.target) --json"]
                ),
            ],
            nodes: visibleTexts.enumerated().map { index, text in
                ObserveNodeOutput(
                    nodeID: "ios-host:\(index + 1)",
                    source: "host-layout",
                    role: "button",
                    text: text,
                    identifier: "\(text.lowercased())-button",
                    frame: nil,
                    enabled: true,
                    focused: false,
                    hidden: false,
                    candidateOnly: false,
                    confidence: 0.95,
                    capabilities: ["visible", "tap"],
                    missingCapabilities: []
                )
            },
            artifacts: ["fixtures/\(artifactStem)-screenshot.png", "fixtures/\(artifactStem)-tree.json"],
            sourceCommands: ["triton sim ax --device \(request.target) --json"],
            note: "fake live observe"
        )
    }

    private func successfulBusinessWaitResult(query: String, timeout: Double, interval: Double) -> TKWaitResult {
        TKWaitResult(
            ok: true,
            matched: true,
            condition: "text",
            query: query,
            timedOut: false,
            elapsedMs: 140,
            pollCount: 2,
            timeoutSeconds: timeout,
            intervalSeconds: interval,
            targetConnectionState: "connected",
            hierarchyCacheState: "active",
            lastObservedNodeCount: 4,
            lastObservedTextSample: ["Login", query],
            match: TKWaitMatch(
                text: query,
                role: "button",
                label: query,
                value: nil,
                identifier: "dashboard-button",
                title: query,
                frame: nil,
                targetOID: 77,
                viewOID: 70,
                className: "UIButton",
                source: "ax"
            )
        )
    }

    private func failedBusinessWaitResult(query: String, timeout: Double, interval: Double) -> TKWaitResult {
        TKWaitResult(
            ok: false,
            matched: false,
            condition: "text",
            query: query,
            timedOut: true,
            elapsedMs: Int(timeout * 1000),
            pollCount: 1,
            timeoutSeconds: timeout,
            intervalSeconds: interval,
            targetConnectionState: "connected",
            hierarchyCacheState: "active",
            lastObservedNodeCount: 2,
            lastObservedTextSample: ["Login", "Continue"],
            match: nil
        )
    }
}
