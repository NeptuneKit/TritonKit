import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("WorkspaceBusinessReadinessTests")
struct WorkspaceBusinessReadinessTests {
    @Test("workspace run completes from live business wait")
    func workspaceRunCompletesFromLiveBusinessWait() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        var waitRequest: TKWorkspaceBusinessWaitRequest?

        let run = try await runWorkspaceRunAsync(
            TKWorkspaceRunRequest(
                runsDirectory: root.path,
                runID: "run-workspace-business-live-wait",
                target: "triton:ios-simulator:SIM-1",
                app: "com.example.demo",
                goal: "Open dashboard",
                actionPolicy: "explore",
                llmProvider: "mock",
                vlmProvider: "mock",
                observationFixture: fixture.path,
                businessReadyText: "Dashboard",
                businessReadyLiveWait: true,
                businessReadyTimeout: 2.5,
                businessReadyInterval: 0.25
            ),
            businessWaitProvider: { request in
                waitRequest = request
                return successBusinessWaitResult(
                    query: request.query,
                    timeout: request.timeout,
                    interval: request.interval
                )
            }
        )

        #expect(waitRequest?.target == "triton:ios-simulator:SIM-1")
        #expect(waitRequest?.host == "127.0.0.1")
        #expect(waitRequest?.port == 19421)
        #expect(waitRequest?.query == "Dashboard")
        #expect(waitRequest?.timeout == 2.5)
        #expect(waitRequest?.interval == 0.25)
        #expect(run.status == "passed")
        #expect(run.business?.ready == true)
        #expect(run.business?.check == "runtime_wait")
        #expect(run.business?.phase == "wait_matched")

        let runDir = root.appendingPathComponent("run-workspace-business-live-wait", isDirectory: true)
        let businessReady = try JSONSerialization.jsonObject(
            with: Data(contentsOf: runDir.appendingPathComponent("evidence/business/ready.json"))
        ) as? [String: Any]
        #expect(businessReady?["ready"] as? Bool == true)
        #expect(businessReady?["check"] as? String == "runtime_wait")
        #expect(businessReady?["phase"] as? String == "wait_matched")
        #expect(businessReady?["source"] as? String == "runtime.wait")
        #expect(businessReady?["matchedTexts"] as? [String] == ["Dashboard"])
        let wait = businessReady?["wait"] as? [String: Any]
        #expect(wait?["ok"] as? Bool == true)
        #expect(wait?["pollCount"] as? Int == 2)
        #expect(wait?["targetConnectionState"] as? String == "connected")

        let parsed = try TKTestRunEventLogParser().parse(
            Data(contentsOf: runDir.appendingPathComponent("events.jsonl"))
        )
        #expect(parsed.events.first { $0.type.rawValue == "business.ready" }?.phase == "wait_matched")
        #expect(parsed.events.first { $0.type == .verifyChecked }?.status == .passed)
        #expect(parsed.events.last?.type == .runFinished)
        #expect(parsed.summary.status == .passed)
    }

    @Test("workspace HTTP run maps live business wait options")
    func workspaceHTTPRunMapsLiveBusinessWaitOptions() async throws {
        let root = temporaryRunsDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try writeObservationFixture(in: root)
        var waitRequest: TKWorkspaceBusinessWaitRequest?

        let body = try JSONEncoder().encode(TKWorkspaceHTTPRunRequest(
            runsDir: root.path,
            runID: "run-workspace-http-business-live-wait",
            target: "triton:ios-simulator:SIM-2",
            platform: "ios",
            scope: "simulator",
            app: "com.example.demo",
            goal: "Open dashboard",
            actionPolicy: "explore",
            llmProvider: "mock",
            vlmProvider: "mock",
            observationFixture: fixture.path,
            observeHost: "127.0.0.2",
            observePort: 19422,
            businessReadyText: "Dashboard",
            businessReadyLiveWait: true,
            businessReadyTimeout: 3.5,
            businessReadyInterval: 0.75
        ))
        let run = try await handleWorkspaceHTTPRunAsync(body: body, businessWaitProvider: { request in
            waitRequest = request
            return successBusinessWaitResult(
                query: request.query,
                timeout: request.timeout,
                interval: request.interval
            )
        })

        #expect(waitRequest?.target == "triton:ios-simulator:SIM-2")
        #expect(waitRequest?.host == "127.0.0.2")
        #expect(waitRequest?.port == 19422)
        #expect(waitRequest?.query == "Dashboard")
        #expect(waitRequest?.timeout == 3.5)
        #expect(waitRequest?.interval == 0.75)
        #expect(run.status == "passed")
        #expect(run.business?.check == "runtime_wait")
        #expect(run.business?.phase == "wait_matched")
    }

    private func temporaryRunsDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-workspace-business-readiness-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func writeObservationFixture(in root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = root.appendingPathComponent("observation.json")
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
            "visibleTexts": ["Login", "Continue"]
          },
          "sourceCommands": ["triton observe current --json"],
          "changed": true
        }
        """.write(to: fixture, atomically: true, encoding: .utf8)
        return fixture
    }

    private func successBusinessWaitResult(query: String, timeout: Double, interval: Double) -> TKWaitResult {
        TKWaitResult(
            ok: true,
            matched: true,
            condition: "text",
            query: query,
            timedOut: false,
            elapsedMs: 125,
            pollCount: 2,
            timeoutSeconds: timeout,
            intervalSeconds: interval,
            targetConnectionState: "connected",
            hierarchyCacheState: "active",
            lastObservedNodeCount: 3,
            lastObservedTextSample: ["Login", "Dashboard"],
            match: TKWaitMatch(
                text: query,
                role: "button",
                label: query,
                value: nil,
                identifier: "dashboard-button",
                title: query,
                frame: nil,
                targetOID: 42,
                viewOID: 24,
                className: "UIButton",
                source: "ax"
            )
        )
    }
}
