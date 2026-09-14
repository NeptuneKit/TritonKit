import Foundation

/// Diagnostic RSS only; it is not a physical-footprint measurement.
public struct TKSimulatorProcessMeasurement: Codable, Equatable, Sendable {
    public let pid: Int
    public let memoryBytes: Int64

    public init(pid: Int, memoryBytes: Int64) {
        self.pid = pid
        self.memoryBytes = memoryBytes
    }
}

public enum TKSimulatorMeasurementParser {
    public enum ParseError: Error, Equatable {
        case malformedOutput
        case duplicatePID(Int)
        case overflow
    }

    /// BSD ps reports RSS in KiB. Reject incomplete rows rather than silently
    /// undercounting memory or representing command diagnostics as zero usage.
    public static func parsePS(_ output: String) throws -> [TKSimulatorProcessMeasurement] {
        let lines = output.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { throw ParseError.malformedOutput }
        var processes: [TKSimulatorProcessMeasurement] = []
        var seen: Set<Int> = []
        for (index, line) in lines.enumerated() {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if index == 0, fields == ["PID", "RSS"] { continue }
            guard fields.count == 2, let pid = Int(fields[0]), pid > 0,
                  let kib = Int64(fields[1]), kib >= 0 else {
                throw ParseError.malformedOutput
            }
            guard seen.insert(pid).inserted else { throw ParseError.duplicatePID(pid) }
            let (bytes, overflow) = kib.multipliedReportingOverflow(by: 1024)
            guard !overflow else { throw ParseError.overflow }
            processes.append(.init(pid: pid, memoryBytes: bytes))
        }
        guard !processes.isEmpty else { throw ParseError.malformedOutput }
        return processes
    }

    public static func measurement(udid: String, psOutput: String) throws -> TKSimulatorResourceMeasurement {
        let processes = try parsePS(psOutput)
        var total: Int64 = 0
        for process in processes {
            let (sum, overflow) = total.addingReportingOverflow(process.memoryBytes)
            guard !overflow else { throw ParseError.overflow }
            total = sum
        }
        return .init(udid: udid, memoryBytes: total, processCount: processes.count)
    }
}
