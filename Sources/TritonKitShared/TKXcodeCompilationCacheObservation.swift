/// Counts paired replay diagnostics, not individual source files, CAS keys or whole build actions.
public struct TKXcodeCASReplayCounts: Codable, Equatable, Sendable {
    public let hits: Int
    public let misses: Int

    public init(hits: Int, misses: Int) {
        self.hits = hits
        self.misses = misses
    }
}

public struct TKXcodeCompilationCacheObservation: Codable, Equatable, Sendable {
    public let mode: String
    public let xcodeVersion: String
    public let observation: String
    public let logCoverage: String
    public let hits: Int?
    public let misses: Int?
    public let byTask: [String: TKXcodeCASReplayCounts]?

    public init(xcodeVersion: String, logCoverage: String, byTask: [String: TKXcodeCASReplayCounts]) {
        self.mode = "shared"
        self.xcodeVersion = xcodeVersion
        self.observation = byTask.isEmpty ? "unknown" : "observed"
        self.logCoverage = logCoverage
        self.hits = byTask.isEmpty ? nil : byTask.values.reduce(0) { $0 + $1.hits }
        self.misses = byTask.isEmpty ? nil : byTask.values.reduce(0) { $0 + $1.misses }
        self.byTask = byTask.isEmpty ? nil : byTask
    }
}
