import Foundation

public enum TKTestRunStatus: String, Codable, Equatable, Sendable {
    case running
    case passed
    case failed
    case blocked
    case stopped
}

public struct TKTestRunMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let kind: String
    public let runID: String
    public let source: String
    public let status: TKTestRunStatus
    public let startedAt: String
    public let endedAt: String?
    public let durationMs: Int?
    public let planRef: String?
    public let evidenceManifestRef: String

    public init(
        schemaVersion: Int = 1,
        kind: String = "triton.test.run",
        runID: String,
        source: String,
        status: TKTestRunStatus,
        startedAt: String,
        endedAt: String? = nil,
        durationMs: Int? = nil,
        planRef: String? = nil,
        evidenceManifestRef: String = "../manifest.json"
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.runID = runID
        self.source = source
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMs = durationMs
        self.planRef = planRef
        self.evidenceManifestRef = evidenceManifestRef
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case runID = "runId"
        case source
        case status
        case startedAt
        case endedAt
        case durationMs
        case planRef
        case evidenceManifestRef
    }
}

public struct TKTestRunEventType: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let runStarted = Self(rawValue: "run.started")
    public static let targetResolved = Self(rawValue: "target.resolved")
    public static let providerChecked = Self(rawValue: "provider.checked")
    public static let appReady = Self(rawValue: "app.ready")
    public static let stepStarted = Self(rawValue: "step.started")
    public static let commandExecuted = Self(rawValue: "command.executed")
    public static let artifactCreated = Self(rawValue: "artifact.created")
    public static let assertionResult = Self(rawValue: "assertion.result")
    public static let observationCaptured = Self(rawValue: "observation.captured")
    public static let vlmGrounding = Self(rawValue: "vlm.grounding")
    public static let modelDecided = Self(rawValue: "model.decided")
    public static let policyChecked = Self(rawValue: "policy.checked")
    public static let actionExecuted = Self(rawValue: "action.executed")
    public static let verifyChecked = Self(rawValue: "verify.checked")
    public static let flowBootstrapChecked = Self(rawValue: "flow.bootstrap.checked")
    public static let flowBootstrapProposed = Self(rawValue: "flow.bootstrap.proposed")
    public static let flowRecoveryDetected = Self(rawValue: "flow.recovery.detected")
    public static let flowRecoveryProposed = Self(rawValue: "flow.recovery.proposed")
    public static let flowRecoveryApplied = Self(rawValue: "flow.recovery.applied")
    public static let flowRecoveryRejected = Self(rawValue: "flow.recovery.rejected")
    public static let atlasUpdated = Self(rawValue: "atlas.updated")
    public static let flowUpdated = Self(rawValue: "flow.updated")
    public static let stepFinished = Self(rawValue: "step.finished")
    public static let runFinished = Self(rawValue: "run.finished")
    public static let runStopped = Self(rawValue: "run.stopped")
    public static let failureRecorded = Self(rawValue: "failure.recorded")

    public var isKnown: Bool {
        Self.knownValues.contains(rawValue)
    }

    public static let knownValues: Set<String> = [
        "run.started",
        "target.resolved",
        "provider.checked",
        "app.ready",
        "step.started",
        "command.executed",
        "artifact.created",
        "assertion.result",
        "observation.captured",
        "vlm.grounding",
        "model.decided",
        "policy.checked",
        "action.executed",
        "verify.checked",
        "flow.bootstrap.checked",
        "flow.bootstrap.proposed",
        "flow.recovery.detected",
        "flow.recovery.proposed",
        "flow.recovery.applied",
        "flow.recovery.rejected",
        "atlas.updated",
        "flow.updated",
        "step.finished",
        "run.finished",
        "run.stopped",
        "failure.recorded",
    ]
}

public struct TKTestRunTextSelector: Codable, Equatable, Sendable {
    public let value: String
    public let match: String
    public let source: String

    public init(value: String, match: String = "exact", source: String = "ax") {
        self.value = value
        self.match = match
        self.source = source
    }
}

public struct TKTestRunSelector: Codable, Equatable, Sendable {
    public let text: TKTestRunTextSelector?

    public init(text: TKTestRunTextSelector? = nil) {
        self.text = text
    }
}

public struct TKTestRunObservationArtifacts: Codable, Equatable, Sendable {
    public let screenshot: String?
    public let ax: String?
    public let hierarchy: String?

    public init(screenshot: String? = nil, ax: String? = nil, hierarchy: String? = nil) {
        self.screenshot = screenshot
        self.ax = ax
        self.hierarchy = hierarchy
    }
}

public struct TKTestRunScreenCandidate: Codable, Equatable, Sendable {
    public let screenshotSha256: String
    public let axTextHash: String
    public let hierarchySha256: String
    public let visibleTexts: [String]

    public init(
        screenshotSha256: String,
        axTextHash: String,
        hierarchySha256: String,
        visibleTexts: [String]
    ) {
        self.screenshotSha256 = screenshotSha256
        self.axTextHash = axTextHash
        self.hierarchySha256 = hierarchySha256
        self.visibleTexts = visibleTexts
    }
}

public struct TKTestRunFailure: Codable, Equatable, Sendable {
    public let type: String?
    public let message: String
    public let selector: TKTestRunSelector?
    public let artifactRefs: [String]

    public init(
        type: String,
        message: String,
        selector: TKTestRunSelector? = nil,
        artifactRefs: [String] = []
    ) {
        self.type = type
        self.message = message
        self.selector = selector
        self.artifactRefs = artifactRefs
    }

    enum CodingKeys: String, CodingKey {
        case type
        case message
        case selector
        case artifactRefs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.message = try container.decode(String.self, forKey: .message)
        self.selector = try container.decodeIfPresent(TKTestRunSelector.self, forKey: .selector)
        self.artifactRefs = try container.decodeIfPresent([String].self, forKey: .artifactRefs) ?? []
    }
}

public struct TKTestRunEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let type: TKTestRunEventType
    public let runID: String
    public let timestamp: String
    public let stepIndex: Int?
    public let stepID: String?
    public let stepType: String?
    public let command: [String]?
    public let status: TKTestRunStatus?
    public let exitCode: Int?
    public let durationMs: Int?
    public let artifactKind: String?
    public let ref: String?
    public let sha256: String?
    public let selector: TKTestRunSelector?
    public let failure: TKTestRunFailure?
    public let phase: String?
    public let artifacts: TKTestRunObservationArtifacts?
    public let screenCandidate: TKTestRunScreenCandidate?
    public let changed: Bool?
    public let vlmGrounding: TKVLMGroundResponse?

    public init(
        schemaVersion: Int = 1,
        type: TKTestRunEventType,
        runID: String,
        timestamp: String,
        stepIndex: Int? = nil,
        stepID: String? = nil,
        stepType: String? = nil,
        command: [String]? = nil,
        status: TKTestRunStatus? = nil,
        exitCode: Int? = nil,
        durationMs: Int? = nil,
        artifactKind: String? = nil,
        ref: String? = nil,
        sha256: String? = nil,
        selector: TKTestRunSelector? = nil,
        failure: TKTestRunFailure? = nil,
        phase: String? = nil,
        artifacts: TKTestRunObservationArtifacts? = nil,
        screenCandidate: TKTestRunScreenCandidate? = nil,
        changed: Bool? = nil,
        vlmGrounding: TKVLMGroundResponse? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.type = type
        self.runID = runID
        self.timestamp = timestamp
        self.stepIndex = stepIndex
        self.stepID = stepID
        self.stepType = stepType
        self.command = command
        self.status = status
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.artifactKind = artifactKind
        self.ref = ref
        self.sha256 = sha256
        self.selector = selector
        self.failure = failure
        self.phase = phase
        self.artifacts = artifacts
        self.screenCandidate = screenCandidate
        self.changed = changed
        self.vlmGrounding = vlmGrounding
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case type
        case runID = "runId"
        case timestamp
        case stepIndex
        case stepID = "stepId"
        case stepType
        case command
        case status
        case exitCode
        case durationMs
        case artifactKind = "kind"
        case ref
        case sha256
        case selector
        case failure
        case phase
        case artifacts
        case screenCandidate
        case changed
        case vlmGrounding
    }

    public static func runStarted(runID: String, timestamp: String) -> Self {
        Self(type: .runStarted, runID: runID, timestamp: timestamp)
    }

    public static func stepStarted(
        runID: String,
        stepIndex: Int,
        stepID: String,
        stepType: String,
        timestamp: String
    ) -> Self {
        Self(
            type: .stepStarted,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            stepID: stepID,
            stepType: stepType
        )
    }

    public static func commandExecuted(
        runID: String,
        stepIndex: Int,
        command: [String],
        status: TKTestRunStatus,
        exitCode: Int,
        durationMs: Int,
        timestamp: String
    ) -> Self {
        Self(
            type: .commandExecuted,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            command: command,
            status: status,
            exitCode: exitCode,
            durationMs: durationMs
        )
    }

    public static func artifactCreated(
        runID: String,
        stepIndex: Int,
        kind: String,
        ref: String,
        sha256: String? = nil,
        timestamp: String
    ) -> Self {
        Self(
            type: .artifactCreated,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            artifactKind: kind,
            ref: ref,
            sha256: sha256
        )
    }

    public static func assertionResult(
        runID: String,
        stepIndex: Int,
        status: TKTestRunStatus,
        selector: TKTestRunSelector,
        timestamp: String
    ) -> Self {
        Self(
            type: .assertionResult,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            status: status,
            selector: selector
        )
    }

    public static func observationCaptured(
        runID: String,
        stepIndex: Int,
        phase: String,
        artifacts: TKTestRunObservationArtifacts,
        screenCandidate: TKTestRunScreenCandidate,
        changed: Bool? = nil,
        timestamp: String
    ) -> Self {
        Self(
            type: .observationCaptured,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            phase: phase,
            artifacts: artifacts,
            screenCandidate: screenCandidate,
            changed: changed
        )
    }

    public static func vlmGrounding(
        runID: String,
        stepIndex: Int,
        grounding: TKVLMGroundResponse,
        timestamp: String
    ) -> Self {
        Self(
            type: .vlmGrounding,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            vlmGrounding: grounding
        )
    }

    public static func stepFinished(
        runID: String,
        stepIndex: Int,
        stepID: String,
        status: TKTestRunStatus,
        durationMs: Int,
        timestamp: String
    ) -> Self {
        Self(
            type: .stepFinished,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            stepID: stepID,
            status: status,
            durationMs: durationMs
        )
    }

    public static func runFinished(
        runID: String,
        status: TKTestRunStatus,
        durationMs: Int,
        timestamp: String
    ) -> Self {
        Self(
            type: .runFinished,
            runID: runID,
            timestamp: timestamp,
            status: status,
            durationMs: durationMs
        )
    }

    public static func failureRecorded(
        runID: String,
        stepIndex: Int,
        failure: TKTestRunFailure,
        timestamp: String
    ) -> Self {
        Self(
            type: .failureRecorded,
            runID: runID,
            timestamp: timestamp,
            stepIndex: stepIndex,
            failure: failure
        )
    }
}

public struct TKTestRunEventSummary: Codable, Equatable, Sendable {
    public let runID: String?
    public let status: TKTestRunStatus?
    public let eventCount: Int
    public let stepCount: Int
    public let assertionCount: Int
    public let artifactCount: Int
    public let observationCount: Int
    public let failureCount: Int

    public init(
        runID: String? = nil,
        status: TKTestRunStatus? = nil,
        eventCount: Int = 0,
        stepCount: Int = 0,
        assertionCount: Int = 0,
        artifactCount: Int = 0,
        observationCount: Int = 0,
        failureCount: Int = 0
    ) {
        self.runID = runID
        self.status = status
        self.eventCount = eventCount
        self.stepCount = stepCount
        self.assertionCount = assertionCount
        self.artifactCount = artifactCount
        self.observationCount = observationCount
        self.failureCount = failureCount
    }
}

public struct TKTestRunEventParseResult: Codable, Equatable, Sendable {
    public let events: [TKTestRunEvent]
    public let summary: TKTestRunEventSummary

    public init(events: [TKTestRunEvent], summary: TKTestRunEventSummary) {
        self.events = events
        self.summary = summary
    }
}

public enum TKTestRunEventLogParseError: Error, Equatable, CustomStringConvertible {
    case invalidUTF8
    case invalidJSON(line: Int)
    case missingRequiredField(line: Int, field: String)
    case unsupportedSchemaVersion(line: Int, version: Int)
    case unknownEventType(line: Int, type: String)

    public var description: String {
        switch self {
        case .invalidUTF8:
            return "Test run events log is not valid UTF-8"
        case .invalidJSON(let line):
            return "Test run events log contains invalid JSON at line \(line)"
        case .missingRequiredField(let line, let field):
            return "Test run events log line \(line) is missing required field \(field)"
        case .unsupportedSchemaVersion(let line, let version):
            return "Test run events log line \(line) uses unsupported schemaVersion \(version)"
        case .unknownEventType(let line, let type):
            return "Test run events log line \(line) uses unknown event type \(type)"
        }
    }
}

public struct TKTestRunEventLogParser: Sendable {
    public init() {}

    public func parse(_ data: Data) throws -> TKTestRunEventParseResult {
        guard let text = String(data: data, encoding: .utf8) else {
            throw TKTestRunEventLogParseError.invalidUTF8
        }

        let lines = text.components(separatedBy: "\n").enumerated().compactMap { index, line -> (Int, String)? in
            let normalized = line.hasSuffix("\r") ? String(line.dropLast()) : line
            guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (index + 1, normalized)
        }

        var events: [TKTestRunEvent] = []
        for (lineNumber, line) in lines {
            let event = try decodeEvent(Data(line.utf8), lineNumber: lineNumber)
            try validate(event, lineNumber: lineNumber)
            events.append(event)
        }

        let runFinished = events.last { $0.type == .runFinished || $0.type == .runStopped }
        let stepIndexes = Set(events.compactMap(\.stepIndex))
        let summary = TKTestRunEventSummary(
            runID: events.first?.runID,
            status: runFinished?.status,
            eventCount: events.count,
            stepCount: stepIndexes.count,
            assertionCount: events.filter { $0.type == .assertionResult }.count,
            artifactCount: events.filter { $0.type == .artifactCreated }.count,
            observationCount: events.filter { $0.type == .observationCaptured }.count,
            failureCount: events.filter { $0.type == .failureRecorded }.count
        )
        return TKTestRunEventParseResult(events: events, summary: summary)
    }

    private func decodeEvent(_ data: Data, lineNumber: Int) throws -> TKTestRunEvent {
        do {
            return try JSONDecoder().decode(TKTestRunEvent.self, from: data)
        } catch let error as DecodingError {
            if case .keyNotFound(let key, let context) = error {
                let prefix = context.codingPath.map(\.stringValue).joined(separator: ".")
                let field = prefix.isEmpty ? key.stringValue : "\(prefix).\(key.stringValue)"
                throw TKTestRunEventLogParseError.missingRequiredField(line: lineNumber, field: field)
            }
            throw TKTestRunEventLogParseError.invalidJSON(line: lineNumber)
        } catch {
            throw TKTestRunEventLogParseError.invalidJSON(line: lineNumber)
        }
    }

    private func validate(_ event: TKTestRunEvent, lineNumber: Int) throws {
        guard event.schemaVersion == 1 else {
            throw TKTestRunEventLogParseError.unsupportedSchemaVersion(
                line: lineNumber,
                version: event.schemaVersion
            )
        }
        guard event.type.isKnown else {
            throw TKTestRunEventLogParseError.unknownEventType(line: lineNumber, type: event.type.rawValue)
        }

        switch event.type {
        case .runStarted:
            break
        case .targetResolved:
            try require(event.ref, "ref", lineNumber)
        case .providerChecked:
            try require(event.phase, "phase", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .appReady:
            try require(event.phase, "phase", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .stepStarted:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.stepID, "stepId", lineNumber)
            try require(event.stepType, "stepType", lineNumber)
        case .commandExecuted:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.exitCode, "exitCode", lineNumber)
        case .artifactCreated:
            try require(event.artifactKind, "kind", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .assertionResult:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.selector, "selector", lineNumber)
        case .observationCaptured:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.phase, "phase", lineNumber)
            let artifacts = try require(event.artifacts, "artifacts", lineNumber)
            try require(artifacts.screenshot, "artifacts.screenshot", lineNumber)
            try require(artifacts.ax, "artifacts.ax", lineNumber)
            try require(artifacts.hierarchy, "artifacts.hierarchy", lineNumber)
            let screenCandidate = try require(event.screenCandidate, "screenCandidate", lineNumber)
            try requireNonEmpty(screenCandidate.screenshotSha256, "screenCandidate.screenshotSha256", lineNumber)
            try requireNonEmpty(screenCandidate.axTextHash, "screenCandidate.axTextHash", lineNumber)
            try requireNonEmpty(screenCandidate.hierarchySha256, "screenCandidate.hierarchySha256", lineNumber)
        case .vlmGrounding:
            try require(event.stepIndex, "stepIndex", lineNumber)
            let grounding = try require(event.vlmGrounding, "vlmGrounding", lineNumber)
            try requireNonEmpty(grounding.provider, "vlmGrounding.provider", lineNumber)
            try requireNonEmpty(grounding.target, "vlmGrounding.target", lineNumber)
        case .modelDecided:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .policyChecked:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .actionExecuted:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.exitCode, "exitCode", lineNumber)
        case .verifyChecked:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .flowBootstrapChecked:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.phase, "phase", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .flowBootstrapProposed:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .flowRecoveryDetected:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.phase, "phase", lineNumber)
            let failure = try require(event.failure, "failure", lineNumber)
            try require(failure.type, "failure.type", lineNumber)
        case .flowRecoveryProposed:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .flowRecoveryApplied:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.command, "command", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.exitCode, "exitCode", lineNumber)
        case .flowRecoveryRejected:
            try require(event.stepIndex, "stepIndex", lineNumber)
            let failure = try require(event.failure, "failure", lineNumber)
            try require(failure.type, "failure.type", lineNumber)
        case .atlasUpdated:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.ref, "ref", lineNumber)
        case .flowUpdated:
            try require(event.ref, "ref", lineNumber)
        case .stepFinished:
            try require(event.stepIndex, "stepIndex", lineNumber)
            try require(event.stepID, "stepId", lineNumber)
            try require(event.status, "status", lineNumber)
            try require(event.durationMs, "durationMs", lineNumber)
        case .runFinished:
            try require(event.status, "status", lineNumber)
            try require(event.durationMs, "durationMs", lineNumber)
        case .runStopped:
            try require(event.status, "status", lineNumber)
            try require(event.durationMs, "durationMs", lineNumber)
        case .failureRecorded:
            try require(event.stepIndex, "stepIndex", lineNumber)
            let failure = try require(event.failure, "failure", lineNumber)
            try require(failure.type, "failure.type", lineNumber)
        default:
            throw TKTestRunEventLogParseError.unknownEventType(line: lineNumber, type: event.type.rawValue)
        }
    }

    @discardableResult
    private func require<T>(_ value: T?, _ field: String, _ lineNumber: Int) throws -> T {
        guard let value else {
            throw TKTestRunEventLogParseError.missingRequiredField(line: lineNumber, field: field)
        }
        return value
    }

    private func requireNonEmpty(_ value: String, _ field: String, _ lineNumber: Int) throws {
        guard !value.isEmpty else {
            throw TKTestRunEventLogParseError.missingRequiredField(line: lineNumber, field: field)
        }
    }
}

public enum TKTestRunEventLogWriteError: Error, Equatable, CustomStringConvertible {
    case invalidRelativePath(String)
    case eventLogAlreadyFinished
    case runStartedNotFirst

    public var description: String {
        switch self {
        case .invalidRelativePath(let path):
            return "Test run artifact path must be relative and stay inside the evidence directory: \(path)"
        case .eventLogAlreadyFinished:
            return "Test run event log is already finished"
        case .runStartedNotFirst:
            return "Test run event log must start with run.started"
        }
    }
}

public struct TKTestRunEventWriter: Sendable {
    public let evidenceDirectory: URL
    public let runDirectoryURL: URL
    public let runURL: URL
    public let eventsURL: URL

    public init(evidenceDirectory: URL, run: TKTestRunMetadata) throws {
        self.evidenceDirectory = evidenceDirectory
        self.runDirectoryURL = evidenceDirectory.appendingPathComponent("run", isDirectory: true)
        self.runURL = try Self.artifactURL(evidenceDirectory: evidenceDirectory, relativePath: "run/run.json")
        self.eventsURL = try Self.artifactURL(evidenceDirectory: evidenceDirectory, relativePath: "run/events.jsonl")

        try FileManager.default.createDirectory(at: runDirectoryURL, withIntermediateDirectories: true)
        try tkTestRunEncodedJSON(run).write(to: runURL, options: .atomic)
        if !FileManager.default.fileExists(atPath: eventsURL.path) {
            FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        }
    }

    public func append(_ event: TKTestRunEvent) throws {
        let data = try Data(contentsOf: eventsURL)
        let existing = try TKTestRunEventLogParser().parse(data)
        if existing.events.last?.type == .runFinished {
            throw TKTestRunEventLogWriteError.eventLogAlreadyFinished
        }
        if existing.events.isEmpty, event.type != .runStarted {
            throw TKTestRunEventLogWriteError.runStartedNotFirst
        }

        let line = try tkTestRunEncodedJSON(event) + Data("\n".utf8)
        let handle = try FileHandle(forWritingTo: eventsURL)
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(line)
    }

    private static func artifactURL(evidenceDirectory: URL, relativePath: String) throws -> URL {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !components.contains(".."),
              !components.contains(".")
        else {
            throw TKTestRunEventLogWriteError.invalidRelativePath(relativePath)
        }
        return evidenceDirectory.appendingPathComponent(relativePath)
    }
}

private func tkTestRunEncodedJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}
