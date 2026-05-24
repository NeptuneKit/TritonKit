import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKEvidenceRunModelsTests {
    @Test("UX run events round-trip known row kinds and friction taxonomy")
    func eventRoundTrip() throws {
        let events = [
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:13.000Z",
                kind: .runStarted,
                caseName: "login-smoke",
                goal: "完成登录并进入首页",
                persona: "第一次使用的普通用户",
                mode: "external-agent",
                target: TKEvidenceRunTarget(
                    platform: "ios-simulator",
                    simulatorUDID: "SIM-1",
                    bundleID: "cn.example.app",
                    runtimeTargetID: "triton:local"
                ),
                budgets: TKEvidenceRunBudgets(steps: 40, timeoutSeconds: 300),
                credential: TKEvidenceRunCredential(label: "dev-account", username: "test@example.com")
            ),
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:14.000Z",
                kind: .stepStarted,
                step: 1,
                screenshot: "step-001.png",
                debugScreenshot: "debug/step-001-marked.png",
                source: "runtime.screenshot"
            ),
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:15.000Z",
                kind: .toolCall,
                step: 1,
                source: "agent",
                tool: "tap",
                scope: "runtime",
                observation: "我看到登录页。",
                intent: "我要先进入登录流程。",
                input: ["text": .string("登录")]
            ),
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:16.000Z",
                kind: .toolResult,
                step: 1,
                tool: "tap",
                scope: "runtime",
                success: true,
                durationMs: 42,
                artifacts: []
            ),
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:17.000Z",
                kind: .friction,
                step: 2,
                source: "agent",
                frictionKind: .ambiguousLabel,
                detail: "按钮只写了 Go。"
            ),
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:18.000Z",
                kind: .stepCompleted,
                step: 1,
                durationMs: 812,
                status: "completed"
            ),
            TKEvidenceRunEvent(
                runID: "run-1",
                timestamp: "2026-05-21T10:12:19.000Z",
                kind: .runCompleted,
                verdict: .success,
                summary: "登录成功并进入首页。",
                frictionCount: 1,
                wouldRealUserSucceed: true,
                stepCount: 1
            ),
        ]

        let data = try JSONEncoder().encode(events)
        let decoded = try JSONDecoder().decode([TKEvidenceRunEvent].self, from: data)

        #expect(decoded.map(\.kind) == [
            .runStarted,
            .stepStarted,
            .toolCall,
            .toolResult,
            .friction,
            .stepCompleted,
            .runCompleted,
        ])
        #expect(decoded.first?.target?.bundleID == "cn.example.app")
        #expect(decoded.first?.credential?.username == "test@example.com")
        #expect(decoded[2].input?["text"] == .string("登录"))
        #expect(decoded[4].frictionKind == .ambiguousLabel)
        #expect(decoded.last?.verdict == .success)
    }

    @Test("parser tolerates partial tail and summarizes completed run")
    func parseJSONLToleratesPartialTail() throws {
        let jsonl = """
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:13.000Z","kind":"run_started","caseName":"login-smoke"}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:14.000Z","kind":"step_started","step":1,"screenshot":"step-001.png"}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:15.000Z","kind":"friction","step":1,"frictionKind":"dead_end","detail":"无法继续"}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:16.000Z","kind":"run_completed","verdict":"blocked","frictionCount":1,"stepCount":1}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:17.000Z","kind":"tool_call"
        """

        let result = try TKEvidenceRunLogParser().parse(Data(jsonl.utf8))

        #expect(result.events.count == 4)
        #expect(result.truncatedTail == true)
        #expect(result.status == .completed)
        #expect(result.summary.runID == "run-1")
        #expect(result.summary.stepCount == 1)
        #expect(result.summary.frictionCount == 1)
        #expect(result.summary.verdict == .blocked)
        #expect(result.warnings.map(\.code) == ["partial_tail"])
    }

    @Test("parser preserves unknown kinds and reports malformed middle rows")
    func parseJSONLUnknownAndMalformedRows() throws {
        let unknown = """
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:13.000Z","kind":"run_started"}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:14.000Z","kind":"new_future_kind","artifactRefs":["debug/future.json"]}
        """

        let unknownResult = try TKEvidenceRunLogParser().parse(Data(unknown.utf8))

        #expect(unknownResult.events.map(\.kind.rawValue) == ["run_started", "new_future_kind"])
        #expect(unknownResult.warnings.map(\.code) == ["unknown_kind"])
        #expect(unknownResult.events.last?.artifactRefs == ["debug/future.json"])

        let malformedMiddle = """
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:13.000Z","kind":"run_started"}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:14.000Z","kind":"tool_call"
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:15.000Z","kind":"run_completed"}
        """

        #expect(throws: TKEvidenceRunLogParseError.malformedEvent(line: 2)) {
            _ = try TKEvidenceRunLogParser().parse(Data(malformedMiddle.utf8))
        }
    }

    @Test("parser rejects logs where run_started is not first")
    func parseJSONLRequiresRunStartedFirst() throws {
        let jsonl = """
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:13.000Z","kind":"step_started","step":1}
        {"schemaVersion":1,"runId":"run-1","ts":"2026-05-21T10:12:14.000Z","kind":"run_started"}
        """

        #expect(throws: TKEvidenceRunLogParseError.runStartedNotFirst(line: 1)) {
            _ = try TKEvidenceRunLogParser().parse(Data(jsonl.utf8))
        }
    }

    @Test("credential model does not encode secret-shaped fields")
    func credentialEncodesOnlyPublicIdentity() throws {
        let event = TKEvidenceRunEvent(
            runID: "run-1",
            timestamp: "2026-05-21T10:12:13.000Z",
            kind: .runStarted,
            credential: TKEvidenceRunCredential(label: "dev-account", username: "test@example.com")
        )

        let json = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)

        #expect(json.contains("dev-account"))
        #expect(json.contains("test@example.com"))
        #expect(!json.contains("password"))
        #expect(!json.contains("token"))
        #expect(!json.contains("secret"))
    }
}
