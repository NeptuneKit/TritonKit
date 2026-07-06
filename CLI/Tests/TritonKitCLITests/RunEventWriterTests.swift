import Foundation
import Testing
import TritonKitShared

@Suite
struct RunEventWriterTests {
    @Test("P0C writer creates run.json and validates supported events")
    func writerCreatesRunJSONAndValidEvents() throws {
        let root = temporaryRunRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try TKTestRunEventWriter(
            evidenceDirectory: root,
            run: TKTestRunMetadata(
                runID: "run-p0c-001",
                source: "manual-primitive-smoke",
                status: .passed,
                startedAt: "2026-06-20T00:00:00Z",
                endedAt: "2026-06-20T00:00:04Z",
                durationMs: 4000,
                evidenceManifestRef: "../manifest.json"
            )
        )

        try writer.append(.runStarted(runID: "run-p0c-001", timestamp: "2026-06-20T00:00:00Z"))
        try writer.append(.stepStarted(
            runID: "run-p0c-001",
            stepIndex: 0,
            stepID: "manual-000",
            stepType: "launch",
            timestamp: "2026-06-20T00:00:01Z"
        ))
        try writer.append(.commandExecuted(
            runID: "run-p0c-001",
            stepIndex: 0,
            command: ["triton", "xcode", "run"],
            status: .passed,
            exitCode: 0,
            durationMs: 1234,
            timestamp: "2026-06-20T00:00:02Z"
        ))
        try writer.append(.artifactCreated(
            runID: "run-p0c-001",
            stepIndex: 1,
            kind: "screenshot",
            ref: "../screenshot.png",
            sha256: "sha256-pass",
            timestamp: "2026-06-20T00:00:03Z"
        ))
        try writer.append(.assertionResult(
            runID: "run-p0c-001",
            stepIndex: 2,
            status: .passed,
            selector: TKTestRunSelector(text: .init(value: "Fixture Login", match: "exact", source: "ax")),
            timestamp: "2026-06-20T00:00:03Z"
        ))
        try writer.append(.stepFinished(
            runID: "run-p0c-001",
            stepIndex: 0,
            stepID: "manual-000",
            status: .passed,
            durationMs: 1234,
            timestamp: "2026-06-20T00:00:04Z"
        ))
        try writer.append(.runFinished(
            runID: "run-p0c-001",
            status: .passed,
            durationMs: 4000,
            timestamp: "2026-06-20T00:00:04Z"
        ))

        let run = try JSONDecoder().decode(
            TKTestRunMetadata.self,
            from: Data(contentsOf: root.appendingPathComponent("run/run.json"))
        )
        let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: writer.eventsURL))

        #expect(run.kind == "triton.test.run")
        #expect(run.runID == "run-p0c-001")
        #expect(parsed.events.map(\.type.rawValue) == [
            "run.started",
            "step.started",
            "command.executed",
            "artifact.created",
            "assertion.result",
            "step.finished",
            "run.finished",
        ])
        #expect(parsed.summary.status == .passed)
        #expect(parsed.summary.eventCount == 7)
        #expect(parsed.summary.assertionCount == 1)
        #expect(parsed.summary.artifactCount == 1)
    }

    @Test("P0C parser rejects invalid event rows")
    func parserRejectsInvalidEventRows() throws {
        #expect(throws: TKTestRunEventLogParseError.invalidJSON(line: 1)) {
            _ = try TKTestRunEventLogParser().parse(Data("{".utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "schemaVersion")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"type":"run.started","runId":"run-1","timestamp":"2026-06-20T00:00:00Z"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.unknownEventType(line: 1, type: "screen.changed")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"screen.changed","runId":"run-1","timestamp":"2026-06-20T00:00:00Z"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "runId")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"run.started","timestamp":"2026-06-20T00:00:00Z"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "selector")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"assertion.result","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","stepIndex":0,"status":"passed"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "ref")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"artifact.created","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","kind":"screenshot"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "failure.type")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"failure.recorded","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","stepIndex":0,"failure":{"message":"Text not visible"}}"#.utf8))
        }
    }

    @Test("P0C parser supports paused run terminal event")
    func parserSupportsPausedRunTerminalEvent() throws {
        let parsed = try TKTestRunEventLogParser().parse(Data("""
        {"schemaVersion":1,"type":"run.started","runId":"run-paused-001","timestamp":"2026-06-20T00:00:00Z"}
        {"schemaVersion":1,"type":"run.paused","runId":"run-paused-001","timestamp":"2026-06-20T00:00:01Z","status":"paused","durationMs":1000,"phase":"provider_missing"}

        """.utf8))

        #expect(parsed.summary.runID == "run-paused-001")
        #expect(parsed.summary.status == .paused)
        #expect(parsed.events.last?.type == .runPaused)
        #expect(parsed.events.last?.phase == "provider_missing")
    }

    @Test("P0C writer treats paused run as terminal")
    func writerTreatsPausedRunAsTerminal() throws {
        let root = temporaryRunRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try TKTestRunEventWriter(
            evidenceDirectory: root,
            run: TKTestRunMetadata(
                runID: "run-p0c-paused",
                source: "manual-primitive-smoke",
                status: .paused,
                startedAt: "2026-06-20T00:00:00Z",
                endedAt: nil,
                durationMs: nil,
                evidenceManifestRef: "../manifest.json"
            )
        )
        try writer.append(.runStarted(runID: "run-p0c-paused", timestamp: "2026-06-20T00:00:00Z"))
        try writer.append(.init(
            type: .runPaused,
            runID: "run-p0c-paused",
            timestamp: "2026-06-20T00:00:01Z",
            status: .paused,
            durationMs: 1000,
            phase: "provider_missing"
        ))

        #expect(throws: TKTestRunEventLogWriteError.eventLogAlreadyFinished) {
            try writer.append(.failureRecorded(
                runID: "run-p0c-paused",
                stepIndex: 0,
                failure: TKTestRunFailure(type: "late_event", message: "should not append"),
                timestamp: "2026-06-20T00:00:02Z"
            ))
        }
    }

    @Test("P0C writer supports failure recorded events")
    func writerSupportsFailureRecordedEvents() throws {
        let root = temporaryRunRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = try TKTestRunEventWriter(
            evidenceDirectory: root,
            run: TKTestRunMetadata(
                runID: "run-p0c-002",
                source: "manual-primitive-smoke",
                status: .failed,
                startedAt: "2026-06-20T00:00:00Z",
                endedAt: "2026-06-20T00:00:02Z",
                durationMs: 2000,
                evidenceManifestRef: "../manifest.json"
            )
        )
        try writer.append(.runStarted(runID: "run-p0c-002", timestamp: "2026-06-20T00:00:00Z"))
        try writer.append(.failureRecorded(
            runID: "run-p0c-002",
            stepIndex: 2,
            failure: TKTestRunFailure(
                type: "assertion_failed",
                message: "Text not visible: Definitely Not Existing",
                selector: TKTestRunSelector(text: .init(value: "Definitely Not Existing", match: "exact", source: "ax")),
                artifactRefs: ["../screenshot.png", "../ax.json"]
            ),
            timestamp: "2026-06-20T00:00:01Z"
        ))
        try writer.append(.runFinished(
            runID: "run-p0c-002",
            status: .failed,
            durationMs: 2000,
            timestamp: "2026-06-20T00:00:02Z"
        ))

        let parsed = try TKTestRunEventLogParser().parse(Data(contentsOf: writer.eventsURL))

        #expect(parsed.summary.status == .failed)
        #expect(parsed.summary.failureCount == 1)
        #expect(parsed.events[1].failure?.type == "assertion_failed")
        #expect(parsed.events[1].failure?.artifactRefs == ["../screenshot.png", "../ax.json"])
    }

    private func temporaryRunRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("triton-cli-p0c-run-\(UUID().uuidString).tritonevidence")
    }
}
