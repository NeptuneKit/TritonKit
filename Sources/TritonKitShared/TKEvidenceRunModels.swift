import Foundation

public struct TKEvidenceRunEventKind: RawRepresentable, Codable, Equatable, Hashable, Sendable {
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

    public static let runStarted = Self(rawValue: "run_started")
    public static let stepStarted = Self(rawValue: "step_started")
    public static let toolCall = Self(rawValue: "tool_call")
    public static let toolResult = Self(rawValue: "tool_result")
    public static let friction = Self(rawValue: "friction")
    public static let stepCompleted = Self(rawValue: "step_completed")
    public static let runCompleted = Self(rawValue: "run_completed")

    public var isKnown: Bool {
        Self.knownValues.contains(rawValue)
    }

    public static let knownValues: Set<String> = [
        "run_started",
        "step_started",
        "tool_call",
        "tool_result",
        "friction",
        "step_completed",
        "run_completed",
    ]
}

public enum TKEvidenceFrictionKind: String, Codable, Equatable, Sendable {
    case deadEnd = "dead_end"
    case ambiguousLabel = "ambiguous_label"
    case unresponsive
    case confusingCopy = "confusing_copy"
    case unexpectedState = "unexpected_state"
    case authRequired = "auth_required"
    case agentBlocked = "agent_blocked"
}

public enum TKEvidenceRunVerdict: String, Codable, Equatable, Sendable {
    case success
    case failure
    case blocked
}

public struct TKEvidenceRunTarget: Codable, Equatable, Sendable {
    public let platform: String
    public let simulatorUDID: String?
    public let bundleID: String?
    public let runtimeTargetID: String?

    public init(
        platform: String,
        simulatorUDID: String? = nil,
        bundleID: String? = nil,
        runtimeTargetID: String? = nil
    ) {
        self.platform = platform
        self.simulatorUDID = simulatorUDID
        self.bundleID = bundleID
        self.runtimeTargetID = runtimeTargetID
    }
}

public struct TKEvidenceRunBudgets: Codable, Equatable, Sendable {
    public let steps: Int?
    public let timeoutSeconds: Int?

    public init(steps: Int? = nil, timeoutSeconds: Int? = nil) {
        self.steps = steps
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct TKEvidenceRunCredential: Codable, Equatable, Sendable {
    public let label: String?
    public let username: String?

    public init(label: String? = nil, username: String? = nil) {
        self.label = label
        self.username = username
    }
}

public struct TKEvidenceRunEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let eventID: String?
    public let timestamp: String
    public let kind: TKEvidenceRunEventKind
    public let caseName: String?
    public let goal: String?
    public let persona: String?
    public let mode: String?
    public let target: TKEvidenceRunTarget?
    public let budgets: TKEvidenceRunBudgets?
    public let credential: TKEvidenceRunCredential?
    public let step: Int?
    public let screenshot: String?
    public let debugScreenshot: String?
    public let source: String?
    public let tool: String?
    public let scope: String?
    public let observation: String?
    public let intent: String?
    public let input: [String: TKJSONValue]?
    public let success: Bool?
    public let durationMs: Int?
    public let error: String?
    public let artifacts: [String]?
    public let artifactRefs: [String]?
    public let frictionKind: TKEvidenceFrictionKind?
    public let detail: String?
    public let status: String?
    public let verdict: TKEvidenceRunVerdict?
    public let summary: String?
    public let frictionCount: Int?
    public let wouldRealUserSucceed: Bool?
    public let stepCount: Int?

    public init(
        schemaVersion: Int = 1,
        runID: String,
        eventID: String? = nil,
        timestamp: String,
        kind: TKEvidenceRunEventKind,
        caseName: String? = nil,
        goal: String? = nil,
        persona: String? = nil,
        mode: String? = nil,
        target: TKEvidenceRunTarget? = nil,
        budgets: TKEvidenceRunBudgets? = nil,
        credential: TKEvidenceRunCredential? = nil,
        step: Int? = nil,
        screenshot: String? = nil,
        debugScreenshot: String? = nil,
        source: String? = nil,
        tool: String? = nil,
        scope: String? = nil,
        observation: String? = nil,
        intent: String? = nil,
        input: [String: TKJSONValue]? = nil,
        success: Bool? = nil,
        durationMs: Int? = nil,
        error: String? = nil,
        artifacts: [String]? = nil,
        artifactRefs: [String]? = nil,
        frictionKind: TKEvidenceFrictionKind? = nil,
        detail: String? = nil,
        status: String? = nil,
        verdict: TKEvidenceRunVerdict? = nil,
        summary: String? = nil,
        frictionCount: Int? = nil,
        wouldRealUserSucceed: Bool? = nil,
        stepCount: Int? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.eventID = eventID
        self.timestamp = timestamp
        self.kind = kind
        self.caseName = caseName
        self.goal = goal
        self.persona = persona
        self.mode = mode
        self.target = target
        self.budgets = budgets
        self.credential = credential
        self.step = step
        self.screenshot = screenshot
        self.debugScreenshot = debugScreenshot
        self.source = source
        self.tool = tool
        self.scope = scope
        self.observation = observation
        self.intent = intent
        self.input = input
        self.success = success
        self.durationMs = durationMs
        self.error = error
        self.artifacts = artifacts
        self.artifactRefs = artifactRefs
        self.frictionKind = frictionKind
        self.detail = detail
        self.status = status
        self.verdict = verdict
        self.summary = summary
        self.frictionCount = frictionCount
        self.wouldRealUserSucceed = wouldRealUserSucceed
        self.stepCount = stepCount
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID = "runId"
        case eventID = "eventId"
        case timestamp = "ts"
        case kind
        case caseName
        case goal
        case persona
        case mode
        case target
        case budgets
        case credential
        case step
        case screenshot
        case debugScreenshot
        case source
        case tool
        case scope
        case observation
        case intent
        case input
        case success
        case durationMs
        case error
        case artifacts
        case artifactRefs
        case frictionKind
        case detail
        case status
        case verdict
        case summary
        case frictionCount
        case wouldRealUserSucceed
        case stepCount
    }
}

public struct TKEvidenceRunMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let caseName: String?
    public let createdAt: String
    public let eventsPath: String
    public let metaPath: String

    public init(
        schemaVersion: Int = 1,
        runID: String,
        caseName: String? = nil,
        createdAt: String,
        eventsPath: String = "run/events.jsonl",
        metaPath: String = "run/meta.json"
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.caseName = caseName
        self.createdAt = createdAt
        self.eventsPath = eventsPath
        self.metaPath = metaPath
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID = "runId"
        case caseName
        case createdAt
        case eventsPath
        case metaPath
    }
}

public enum TKEvidenceRunParseStatus: String, Codable, Equatable, Sendable {
    case completed
    case incomplete
}

public struct TKEvidenceRunSummary: Codable, Equatable, Sendable {
    public let runID: String?
    public let verdict: TKEvidenceRunVerdict?
    public let frictionCount: Int
    public let stepCount: Int

    public init(
        runID: String? = nil,
        verdict: TKEvidenceRunVerdict? = nil,
        frictionCount: Int = 0,
        stepCount: Int = 0
    ) {
        self.runID = runID
        self.verdict = verdict
        self.frictionCount = frictionCount
        self.stepCount = stepCount
    }
}

public struct TKEvidenceRunParseWarning: Codable, Equatable, Sendable {
    public let line: Int
    public let code: String
    public let message: String
    public let raw: String?

    public init(line: Int, code: String, message: String, raw: String? = nil) {
        self.line = line
        self.code = code
        self.message = message
        self.raw = raw
    }
}

public struct TKEvidenceRunParseResult: Codable, Equatable, Sendable {
    public let events: [TKEvidenceRunEvent]
    public let warnings: [TKEvidenceRunParseWarning]
    public let truncatedTail: Bool
    public let status: TKEvidenceRunParseStatus
    public let summary: TKEvidenceRunSummary

    public init(
        events: [TKEvidenceRunEvent],
        warnings: [TKEvidenceRunParseWarning] = [],
        truncatedTail: Bool = false,
        status: TKEvidenceRunParseStatus,
        summary: TKEvidenceRunSummary
    ) {
        self.events = events
        self.warnings = warnings
        self.truncatedTail = truncatedTail
        self.status = status
        self.summary = summary
    }
}

public enum TKEvidenceRunLogParseError: Error, Equatable, CustomStringConvertible {
    case invalidUTF8
    case malformedEvent(line: Int)
    case runStartedNotFirst(line: Int)
    case unsupportedSchemaVersion(line: Int, version: Int)

    public var description: String {
        switch self {
        case .invalidUTF8:
            return "Evidence run log is not valid UTF-8"
        case .malformedEvent(let line):
            return "Evidence run log contains malformed JSON at line \(line)"
        case .runStartedNotFirst(let line):
            return "Evidence run log must start with run_started; found another event at line \(line)"
        case .unsupportedSchemaVersion(let line, let version):
            return "Evidence run log line \(line) uses unsupported schemaVersion \(version)"
        }
    }
}

public struct TKEvidenceRunLogParser: Sendable {
    public init() {}

    public func parse(_ data: Data) throws -> TKEvidenceRunParseResult {
        guard let text = String(data: data, encoding: .utf8) else {
            throw TKEvidenceRunLogParseError.invalidUTF8
        }

        let physicalLines = text.components(separatedBy: "\n")
        let candidates = physicalLines.enumerated().compactMap { index, line -> (lineNumber: Int, raw: String)? in
            let raw = line.hasSuffix("\r") ? String(line.dropLast()) : line
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            return (index + 1, raw)
        }

        var events: [TKEvidenceRunEvent] = []
        var warnings: [TKEvidenceRunParseWarning] = []
        var truncatedTail = false

        for (candidateIndex, candidate) in candidates.enumerated() {
            do {
                let eventData = Data(candidate.raw.utf8)
                let event = try JSONDecoder().decode(TKEvidenceRunEvent.self, from: eventData)
                guard event.schemaVersion == 1 else {
                    throw TKEvidenceRunLogParseError.unsupportedSchemaVersion(
                        line: candidate.lineNumber,
                        version: event.schemaVersion
                    )
                }
                if !event.kind.isKnown {
                    warnings.append(TKEvidenceRunParseWarning(
                        line: candidate.lineNumber,
                        code: "unknown_kind",
                        message: "Unknown evidence run event kind: \(event.kind.rawValue)",
                        raw: candidate.raw
                    ))
                }
                if events.isEmpty, event.kind != .runStarted {
                    throw TKEvidenceRunLogParseError.runStartedNotFirst(line: candidate.lineNumber)
                }
                events.append(event)
            } catch let error as TKEvidenceRunLogParseError {
                throw error
            } catch {
                if candidateIndex == candidates.indices.last {
                    truncatedTail = true
                    warnings.append(TKEvidenceRunParseWarning(
                        line: candidate.lineNumber,
                        code: "partial_tail",
                        message: "Ignored truncated final JSONL row",
                        raw: candidate.raw
                    ))
                } else {
                    throw TKEvidenceRunLogParseError.malformedEvent(line: candidate.lineNumber)
                }
            }
        }

        let completed = events.last(where: { $0.kind == .runCompleted })
        let frictionCount = completed?.frictionCount ?? events.filter { $0.kind == .friction }.count
        let explicitStepCount = completed?.stepCount
        let observedStepCount = Set(events.compactMap(\.step)).count
        let summary = TKEvidenceRunSummary(
            runID: events.first?.runID,
            verdict: completed?.verdict,
            frictionCount: frictionCount,
            stepCount: explicitStepCount ?? observedStepCount
        )

        return TKEvidenceRunParseResult(
            events: events,
            warnings: warnings,
            truncatedTail: truncatedTail,
            status: completed == nil ? .incomplete : .completed,
            summary: summary
        )
    }
}

public enum TKEvidenceRunLogWriteError: Error, Equatable, CustomStringConvertible {
    case invalidRelativePath(String)
    case artifactAlreadyExists(String)
    case runAlreadyCompleted
    case runStartedNotFirst
    case truncatedTail

    public var description: String {
        switch self {
        case .invalidRelativePath(let path):
            return "Evidence run artifact path must be relative and stay inside the evidence directory: \(path)"
        case .artifactAlreadyExists(let path):
            return "Evidence run artifact already exists: \(path)"
        case .runAlreadyCompleted:
            return "Evidence run log is already completed"
        case .runStartedNotFirst:
            return "Evidence run log must start with run_started"
        case .truncatedTail:
            return "Evidence run log has a truncated tail and cannot be appended safely"
        }
    }
}

public struct TKEvidenceRunLogWriter: Sendable {
    public let evidenceDirectory: URL
    public let runDirectoryURL: URL
    public let eventsURL: URL
    public let metadataURL: URL

    public init(evidenceDirectory: URL, metadata: TKEvidenceRunMetadata) throws {
        self.evidenceDirectory = evidenceDirectory
        self.runDirectoryURL = evidenceDirectory.appendingPathComponent("run", isDirectory: true)
        self.eventsURL = try Self.artifactURL(evidenceDirectory: evidenceDirectory, relativePath: metadata.eventsPath)
        self.metadataURL = try Self.artifactURL(evidenceDirectory: evidenceDirectory, relativePath: metadata.metaPath)

        try FileManager.default.createDirectory(at: runDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: metadataURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encodedJSON(metadata).write(to: metadataURL, options: .atomic)
        try FileManager.default.createDirectory(
            at: eventsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: eventsURL.path) {
            FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        }
    }

    @discardableResult
    public func writeArtifact(_ data: Data, relativePath: String) throws -> String {
        let destination = try Self.artifactURL(evidenceDirectory: evidenceDirectory, relativePath: relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path)) != nil
        {
            throw TKEvidenceRunLogWriteError.artifactAlreadyExists(relativePath)
        }
        try data.write(to: destination, options: .atomic)
        return relativePath
    }

    public func append(_ event: TKEvidenceRunEvent) throws {
        let existing = try TKEvidenceRunLogParser().parse(Data(contentsOf: eventsURL))
        guard existing.status != .completed else {
            throw TKEvidenceRunLogWriteError.runAlreadyCompleted
        }
        guard !existing.truncatedTail else {
            throw TKEvidenceRunLogWriteError.truncatedTail
        }
        if existing.events.isEmpty, event.kind != .runStarted {
            throw TKEvidenceRunLogWriteError.runStartedNotFirst
        }

        let line = try encodedJSON(event) + Data("\n".utf8)
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
            throw TKEvidenceRunLogWriteError.invalidRelativePath(relativePath)
        }
        return evidenceDirectory.appendingPathComponent(relativePath)
    }
}

private func encodedJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}
