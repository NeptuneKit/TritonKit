import Foundation

/// Scan coverage is distinct from compiler-diagnostic parser support.
public struct TKXcodeDiagnosticCoverage: Codable, Equatable {
    public let sources: [String]
    public let bytesScanned: Int
    public let observedBytes: Int
    public let scanLimitBytesPerStream: Int
    public let complete: Bool
    public let truncated: Bool
    public let linesTruncated: Bool
    public let samplesTruncated: Bool
    public let unavailableStreams: [String]

    public init(sources: [String], bytesScanned: Int, observedBytes: Int,
                scanLimitBytesPerStream: Int, complete: Bool, truncated: Bool,
                linesTruncated: Bool, samplesTruncated: Bool, unavailableStreams: [String]) {
        self.sources = sources
        self.bytesScanned = bytesScanned
        self.observedBytes = observedBytes
        self.scanLimitBytesPerStream = scanLimitBytesPerStream
        self.complete = complete
        self.truncated = truncated
        self.linesTruncated = linesTruncated
        self.samplesTruncated = samplesTruncated
        self.unavailableStreams = unavailableStreams
    }
}
