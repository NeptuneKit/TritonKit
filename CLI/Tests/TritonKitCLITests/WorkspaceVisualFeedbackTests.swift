import ArgumentParser
import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("WorkspaceVisualFeedbackTests")
struct WorkspaceVisualFeedbackTests {
    @Test("Visual settle config survives run ID, target and HTTP request copies")
    func requestCopiesAndHTTP() throws {
        let config = try VisualSettleConfiguration(changeThreshold: 0.02, stableWindow: 0.2, timeout: 2)
        let request = baseRequest(directory: "/unused", config: config, runID: nil)
        #expect(try request.resolvingRunID().visualSettle == config)
        #expect(request.resolvingTarget(target: "sim:OTHER", platform: "ios", scope: "simulator").visualSettle == config)
        let http = TKWorkspaceHTTPRunRequest(runsDir: nil, runID: nil, target: "sim:TEST", platform: "ios", app: "com.example.test", goal: "Continue", actionPolicy: nil, observeLive: true, executeActions: true, visualSettle: config)
        let decoded = try JSONDecoder().decode(TKWorkspaceHTTPRunRequest.self, from: JSONEncoder().encode(http))
        #expect(workspaceRunRequest(from: decoded).visualSettle == config)
        let command = try Workspace.Run.parse(["--app", "com.example.test", "--goal", "Continue", "--visual-settle", "--visual-settle-timeout", "2", "--visual-settle-stable-window", "0.2", "--visual-settle-threshold", "0.02"])
        #expect(command.visualSettle)
        #expect(try command.workspaceVisualSettleConfiguration() == config)
    }

    @Test("Unknown and timeout pause after one action without invoking business checks or repeating")
    func uncertainFeedbackStopsLoop() async throws {
        for (state, steps) in [(VisualSettleState.unknown, 1), (.timeout, 1), (.unknown, 3), (.timeout, 3)] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            var actions = 0
            var checks = 0
            var samples = 0
            var observations = 0
            let config = try VisualSettleConfiguration()
            let response = try await runWorkspaceRunAsync(
                baseRequest(directory: directory.path, config: config, steps: steps),
                observeProvider: { request in observations += 1; return observation(request) },
                businessWaitProvider: { _ in checks += 1; throw RuntimeError("Must not check business after uncertain visual feedback") },
                actionExecutionProvider: { request in actions += 1; return executed(request) },
                visualFeedbackProvider: { request in samples += 1; return feedback(state, configuration: request.configuration) }
            )
            #expect(response.status == "paused")
            #expect(response.visualFeedback?.state == state)
            #expect(actions == 1)
            #expect(samples == 1)
            #expect(checks == 0)
            #expect(observations == 1)
            let runDir = directory.appendingPathComponent("run-visual-feedback")
            #expect(FileManager.default.fileExists(atPath: runDir.appendingPathComponent("evidence/visual-settle/0001.json").path))
            let postAction = try JSONSerialization.jsonObject(with: Data(contentsOf: runDir.appendingPathComponent("evidence/observations/0001.json"))) as? [String: Any]
            #expect(postAction?["available"] as? Bool == false)
            #expect(postAction?["nodes"] == nil)
            let atlas = try JSONSerialization.jsonObject(with: Data(contentsOf: runDir.appendingPathComponent("atlas/atlas.json"))) as? [String: Any]
            #expect((atlas?["transitions"] as? [[String: Any]])?.first?["status"] as? String == "executed_unverified")
            #expect((atlas?["screens"] as? [[String: Any]])?.count == 1)
            let transition = (atlas?["transitions"] as? [[String: Any]])?.first
            #expect(transition?["toScreenId"] as? String == transition?["fromScreenId"] as? String)
            let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: runDir.appendingPathComponent("events.jsonl")))
            #expect(parsed.events.filter { $0.type == .observationCaptured }.count == 1)
            #expect(!parsed.events.contains { $0.type == .observationCaptured && $0.phase == "post_action" })
            #expect(parsed.events.last?.type == .runPaused)
            #expect(parsed.events.last?.phase == "visual_" + state.rawValue)
            #expect(parsed.events.contains { $0.type == .flowRecoveryDetected && $0.phase == "visual_" + state.rawValue })
            #expect(!parsed.events.contains { $0.phase == "selector_drift" })
        }
    }

    @Test("Settled pixels do not turn a failed business assertion into verified")
    func settledStillRequiresBusiness() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let response = try await runWorkspaceRunAsync(
            baseRequest(directory: directory.path, config: try VisualSettleConfiguration()),
            observeProvider: observation,
            businessWaitProvider: { request in failedWait(request) },
            actionExecutionProvider: executed,
            visualFeedbackProvider: { request in feedback(.settled, configuration: request.configuration) }
        )
        #expect(response.status == "paused")
        #expect(response.visualFeedback?.state == .settled)
        #expect(response.visualFeedback?.businessVerified == false)
        let atlas = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("run-visual-feedback/atlas/atlas.json"))) as? [String: Any]
        #expect((atlas?["transitions"] as? [[String: Any]])?.first?["status"] as? String == "verification_failed")
    }

    @Test("Disabled visual feedback keeps existing workflow unchanged")
    func disabledDoesNotCapture() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var captured = false
        let response = try await runWorkspaceRunAsync(
            baseRequest(directory: directory.path, config: nil),
            observeProvider: observation,
            businessWaitProvider: failedWait,
            actionExecutionProvider: executed,
            visualFeedbackProvider: { request in captured = true; return feedback(.settled, configuration: request.configuration) }
        )
        #expect(!captured)
        #expect(response.visualFeedback == nil)
    }

    @Test("An unknown runtime input is never verified or automatically replayed, even with ok true")
    func unknownInputStopsAfterOneAttempt() async throws {
        for steps in [1, 3] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            var actions = 0
            var checks = 0
            let response = try await runWorkspaceRunAsync(
                baseRequest(directory: directory.path, config: nil, steps: steps),
                observeProvider: observation,
                businessWaitProvider: { _ in checks += 1; throw RuntimeError("Unknown actions cannot reach verification") },
                actionExecutionProvider: { request in
                    actions += 1
                    return TKWorkspaceActionExecutionResult(ok: true, action: request.action, command: request.command,
                                                            proofSource: "fixture", sourceCommands: [], message: "outcome unknown",
                                                            inputResult: TKInputResult.success(action: "tap", outcome: "unknown"),
                                                            tapResolution: nil)
                }
            )
            #expect(actions == 1)
            #expect(checks == 0)
            #expect(response.status == "paused")
            #expect(response.nextActions.first?.code == "inspect_unknown_action")
            let artifact = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("run-visual-feedback/evidence/actions/action-000.json"))) as? [String: Any]
            #expect(artifact?["ok"] as? Bool == false)
            #expect((artifact?["inputResult"] as? [String: Any])?["ok"] as? Bool == true)
            #expect((artifact?["inputResult"] as? [String: Any])?["outcome"] as? String == "unknown")
        }
    }

    @Test("HTTP actions preserve uncertain visual evidence through inspect and stop")
    func httpFeedbackPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = TKWorkspaceHTTPRunRequest(runsDir: directory.path, runID: "run-visual-feedback", target: "sim:TEST", platform: "ios", scope: "simulator",
                                                app: "com.example.test", goal: "Continue", actionPolicy: "explore", llmProvider: "mock", vlmProvider: "mock",
                                                observeLive: true, businessReadyText: "Dashboard", businessReadyLiveWait: true,
                                                executeActions: true, visualSettle: try VisualSettleConfiguration())
        let response = try await handleWorkspaceHTTPRunAsync(body: JSONEncoder().encode(payload), observeProvider: observation,
                                                             businessWaitProvider: { _ in throw RuntimeError("Must not check unknown visual state") },
                                                             actionExecutionProvider: executed,
                                                             visualFeedbackProvider: { request in feedback(.unknown, configuration: request.configuration) })
        #expect(response.visualFeedback?.state == .unknown)
        #expect(try handleWorkspaceHTTPInspect(runID: response.runID, runsDir: directory.path).run.visualFeedback == response.visualFeedback)
        #expect(try handleWorkspaceHTTPStop(runID: response.runID, runsDir: directory.path).run.visualFeedback == response.visualFeedback)
    }

    @Test("Invalid visual config is rejected at the HTTP boundary")
    func validatesBeforeExecution() async throws {
        var observed = false
        let data = Data(#"{"app":"com.example.test","goal":"Continue","observeLive":true,"executeActions":true,"visualSettle":{"timeout":-1}}"#.utf8)
        do {
            _ = try await handleWorkspaceHTTPRunAsync(body: data, observeProvider: { request in observed = true; return observation(request) })
            Issue.record("Invalid configuration must fail")
        } catch { #expect(!observed) }
    }

    private func baseRequest(directory: String, config: VisualSettleConfiguration?, steps: Int = 1, runID: String? = "run-visual-feedback") -> TKWorkspaceRunRequest {
        TKWorkspaceRunRequest(runsDirectory: directory, runID: runID, target: "sim:TEST", platform: "ios", scope: "simulator", app: "com.example.test", goal: "Continue", actionPolicy: "explore", llmProvider: "mock", vlmProvider: "mock", maxSteps: steps, observeLive: true, businessReadyText: "Dashboard", businessReadyLiveWait: true, executeActions: true, visualSettle: config)
    }

    private func feedback(_ state: VisualSettleState, configuration: VisualSettleConfiguration) -> VisualSettleOutput {
        VisualSettleOutput(ok: state == .settled, action: "observe.settle", state: state, reason: "fixture", businessVerified: false, elapsedMs: 500, sampleCount: 3, lastChangeFraction: state == .settled ? 0 : nil, capturedAt: "2026-10-14T00:00:00Z", source: "fixture", configuration: configuration, comparisonPolicy: "fixture")
    }

    private func observation(_ request: TKWorkspaceLiveObserveRequest) -> ObserveOutput {
        ObserveOutput(ok: true, action: request.action, platform: "ios", capturedAt: "2026-10-14T00:00:00Z", partial: false, target: "sim:TEST", sources: [], nodes: [ObserveNodeOutput(nodeID: "ios-host:1", source: "host-layout", role: "button", text: "Continue", identifier: "continue", frame: nil, enabled: true, focused: false, hidden: false, candidateOnly: false, confidence: 1, capabilities: ["visible", "tap"], missingCapabilities: [])], artifacts: [], sourceCommands: [], note: "fixture")
    }

    private func executed(_ request: TKWorkspaceActionExecutionRequest) -> TKWorkspaceActionExecutionResult {
        TKWorkspaceActionExecutionResult(ok: true, action: request.action, command: request.command, proofSource: "fixture", sourceCommands: [], message: "submitted", inputResult: nil, tapResolution: nil)
    }

    private func failedWait(_ request: TKWorkspaceBusinessWaitRequest) -> TKWaitResult {
        TKWaitResult(ok: false, matched: false, condition: "text", query: request.query, timedOut: true, elapsedMs: 20, pollCount: 1, timeoutSeconds: request.timeout, intervalSeconds: request.interval, targetConnectionState: "connected", hierarchyCacheState: "active", lastObservedNodeCount: 1, lastObservedTextSample: ["Continue"], match: nil)
    }
}
