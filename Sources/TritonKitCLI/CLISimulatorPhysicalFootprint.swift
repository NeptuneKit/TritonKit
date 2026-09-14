import Foundation
#if os(macOS)
import Darwin
#endif

/// Simulator isolation follows simslim measure.go at f3b979ecd913f56904a9b6100cad1f84fe01d228.
/// Sampling uses libproc's byte-accurate phys_footprint rather than rounded top output or RSS.
struct SimulatorPhysicalFootprint {
    struct ProcessEntry: Equatable {
        let pid: Int32
        let parentPID: Int32
        let arguments: String
    }

    struct Measurement: Codable, Equatable {
        let rootPID: Int32
        let processCount: Int
        let sampledProcessCount: Int
        let physicalFootprintBytes: UInt64
        let failedPIDs: [Int32]
        let partial: Bool
    }

    enum Failure: Error {
        case invalidDevice, malformedSnapshot, missingRoot, ambiguousRoot, unsupportedPlatform
        case processListFailed(Int32), sampleFailed(Int32, Int32), noSamples, overflow
    }

    let processList: () throws -> [ProcessEntry]
    let sample: (Int32) throws -> UInt64

    init(processList: @escaping () throws -> [ProcessEntry] = Self.hostProcessList,
         sample: @escaping (Int32) throws -> UInt64 = Self.hostSample) {
        self.processList = processList
        self.sample = sample
    }

    func measure(udid: String) throws -> Measurement {
        guard UUID(uuidString: udid) != nil else { throw Failure.invalidDevice }
        let entries = try processList()
        guard Set(entries.map(\.pid)).count == entries.count,
              entries.allSatisfy({ $0.pid > 0 && $0.parentPID >= 0 }) else {
            throw Failure.malformedSnapshot
        }
        let marker = "/\(udid.lowercased())/data/var/run/launchd_bootstrap"
        let roots = entries.filter { entry in
            let words = entry.arguments.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let executable = words.first,
                  URL(fileURLWithPath: executable).lastPathComponent == "launchd_sim" else { return false }
            return words.dropFirst().contains { $0.lowercased().contains(marker) }
        }
        guard let root = roots.first else { throw Failure.missingRoot }
        guard roots.count == 1 else { throw Failure.ambiguousRoot }
        let children = Dictionary(grouping: entries, by: \.parentPID)
        var pending = [root.pid]
        var visited = Set<Int32>()
        while let pid = pending.popLast() {
            guard visited.insert(pid).inserted else { continue }
            pending.append(contentsOf: children[pid, default: []].map(\.pid))
        }
        var total: UInt64 = 0
        var failed = [Int32]()
        for pid in visited.sorted() {
            let bytes: UInt64
            do { bytes = try sample(pid) } catch { failed.append(pid); continue }
            let sum = total.addingReportingOverflow(bytes)
            guard !sum.overflow else { throw Failure.overflow }
            total = sum.partialValue
        }
        guard failed.count < visited.count else { throw Failure.noSamples }
        return Measurement(rootPID: root.pid, processCount: visited.count,
                           sampledProcessCount: visited.count - failed.count,
                           physicalFootprintBytes: total, failedPIDs: failed, partial: !failed.isEmpty)
    }

    static func parseProcessList(_ output: String) throws -> [ProcessEntry] {
        let entries = try output.split(separator: "\n").map { line -> ProcessEntry in
            let fields = line.split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard fields.count == 3, let pid = Int32(fields[0]), let parent = Int32(fields[1]),
                  pid > 0, parent >= 0 else { throw Failure.malformedSnapshot }
            return ProcessEntry(pid: pid, parentPID: parent, arguments: String(fields[2]))
        }
        guard !entries.isEmpty else { throw Failure.malformedSnapshot }
        return entries
    }

    static func hostProcessList() throws -> [ProcessEntry] {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axww", "-o", "pid=,ppid=,args="]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure.processListFailed(process.terminationStatus) }
        guard let text = String(data: data, encoding: .utf8) else { throw Failure.malformedSnapshot }
        return try parseProcessList(text)
        #else
        throw Failure.unsupportedPlatform
        #endif
    }

    static func hostSample(pid: Int32) throws -> UInt64 {
        #if os(macOS)
        var usage = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        guard result == 0 else { throw Failure.sampleFailed(pid, errno) }
        return usage.ri_phys_footprint
        #else
        throw Failure.unsupportedPlatform
        #endif
    }
}
