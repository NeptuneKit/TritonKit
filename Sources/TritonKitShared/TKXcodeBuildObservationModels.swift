import Foundation

/// Bounded observations from Xcode output. Counts are log headers, not unique tasks or cache hits.
public struct TKXcodeBuildObservation: Codable, Equatable {
    public let classification: String
    public let source: String
    public let logCoverage: String
    public let taskLogCounts: [String: Int]
    public let diagnosticCounts: [String: Int]
    public let stdoutLogPath: String?
    public let stderrLogPath: String?
    public let note: String

    public init(
        classification: String,
        source: String,
        logCoverage: String,
        taskLogCounts: [String: Int],
        diagnosticCounts: [String: Int],
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        note: String
    ) {
        self.classification = classification
        self.source = source
        self.logCoverage = logCoverage
        self.taskLogCounts = taskLogCounts
        self.diagnosticCounts = diagnosticCounts
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.note = note
    }
}
