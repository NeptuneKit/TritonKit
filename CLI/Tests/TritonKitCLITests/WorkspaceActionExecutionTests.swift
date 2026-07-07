import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("WorkspaceActionExecutionTests")
struct WorkspaceActionExecutionTests {
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

    private func temporaryRunsDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-workspace-action-execution-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func writeObservationFixture(
        in root: URL,
        visibleTexts: [String] = ["Login", "Continue"]
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
            "screenshot": "fixtures/login.png",
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

    private func successfulActionExecution(
        for request: TKWorkspaceActionExecutionRequest
    ) -> TKWorkspaceActionExecutionResult {
        TKWorkspaceActionExecutionResult(
            ok: true,
            action: request.action,
            command: request.command,
            proofSource: "runtime.input",
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
            tapResolution: nil
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
