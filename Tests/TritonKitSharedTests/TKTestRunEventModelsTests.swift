import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKTestRunEventModelsTests {
    @Test("writer creates P0C run.json and dot-style events")
    func writerCreatesRunJSONAndEvents() throws {
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
                planRef: nil,
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

        let runData = try Data(contentsOf: root.appendingPathComponent("run/run.json"))
        let run = try JSONDecoder().decode(TKTestRunMetadata.self, from: runData)
        let eventsData = try Data(contentsOf: root.appendingPathComponent("run/events.jsonl"))
        let eventsText = String(decoding: eventsData, as: UTF8.self)
        let parsed = try TKTestRunEventLogParser().parse(eventsData)

        #expect(run.kind == "triton.test.run")
        #expect(run.runID == "run-p0c-001")
        #expect(run.status == .passed)
        #expect(run.evidenceManifestRef == "../manifest.json")
        #expect(eventsText.split(separator: "\n").count == 7)
        #expect(eventsText.hasSuffix("\n"))
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

    @Test("parser validates required fields per event type")
    func parserValidatesRequiredFields() throws {
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
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"assertion.result","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","stepIndex":1,"status":"passed"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "ref")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"artifact.created","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","kind":"screenshot"}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "failure.type")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"failure.recorded","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","stepIndex":1,"failure":{"message":"Text not visible"}}"#.utf8))
        }
        #expect(throws: TKTestRunEventLogParseError.missingRequiredField(line: 1, field: "artifacts.screenshot")) {
            _ = try TKTestRunEventLogParser().parse(Data(#"{"schemaVersion":1,"type":"observation.captured","runId":"run-1","timestamp":"2026-06-20T00:00:00Z","stepIndex":1,"phase":"after","artifacts":{"ax":"../ax.json","hierarchy":"../hierarchy.json"},"screenCandidate":{"screenshotSha256":"sha","axTextHash":"ax","hierarchySha256":"hierarchy","visibleTexts":["Fixture Login"]}}"#.utf8))
        }
    }

    @Test("parser accepts P0E observation events and counts screen candidates")
    func parserAcceptsP0EObservationEvents() throws {
        let data = Data("""
        {"schemaVersion":1,"type":"run.started","runId":"run-p0e-001","timestamp":"2026-06-20T00:00:00Z"}
        {"schemaVersion":1,"type":"observation.captured","runId":"run-p0e-001","timestamp":"2026-06-20T00:00:01Z","stepIndex":1,"phase":"after","artifacts":{"screenshot":"../screenshots/step-001.png","ax":"../debug/step-001-after-ax.json","hierarchy":"../debug/step-001-after-hierarchy.json"},"screenCandidate":{"screenshotSha256":"sha-screen","axTextHash":"sha-ax-text","hierarchySha256":"sha-hierarchy","visibleTexts":["Fixture Login","Go Home"]}}
        {"schemaVersion":1,"type":"run.finished","runId":"run-p0e-001","timestamp":"2026-06-20T00:00:02Z","status":"passed","durationMs":2000}
        """.utf8)

        let parsed = try TKTestRunEventLogParser().parse(data)

        #expect(parsed.summary.observationCount == 1)
        #expect(parsed.events[1].type == .observationCaptured)
        #expect(parsed.events[1].phase == "after")
        #expect(parsed.events[1].artifacts?.screenshot == "../screenshots/step-001.png")
        #expect(parsed.events[1].screenCandidate?.visibleTexts == ["Fixture Login", "Go Home"])
    }

    @Test("writer supports failure event samples")
    func writerSupportsFailureEventSamples() throws {
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
            .appendingPathComponent("triton-test-run-\(UUID().uuidString).tritonevidence")
    }
}
