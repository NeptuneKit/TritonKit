import XCTest
@testable import TritonKitCLI

final class SimulatorPhysicalFootprintTests: XCTestCase {
    let udid = "12345678-1234-1234-1234-123456789ABC"

    func snapshot() throws -> [SimulatorPhysicalFootprint.ProcessEntry] {
        try SimulatorPhysicalFootprint.parseProcessList("""
        1 0 /sbin/launchd
        10 1 /runtime/launchd_sim /devices/\(udid)/data/var/run/launchd_bootstrap
        11 10 /runtime/SpringBoard
        12 11 /runtime/child with spaces
        20 1 /runtime/launchd_sim /devices/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA/data/var/run/launchd_bootstrap
        21 20 /runtime/unrelated
        30 1 /usr/bin/echo /devices/\(udid)/data/var/run/launchd_bootstrap
        """)
    }

    func testOnlySamplesSelectedLaunchdTreeAndCountsExactBytes() throws {
        var sampled = [Int32]()
        let reader = SimulatorPhysicalFootprint(processList: snapshot, sample: { pid in
            sampled.append(pid)
            return UInt64(pid) * 101
        })
        let result = try reader.measure(udid: udid)
        XCTAssertEqual(sampled, [10, 11, 12])
        XCTAssertEqual(result.physicalFootprintBytes, 3333)
        XCTAssertEqual(result.processCount, 3)
        XCTAssertFalse(result.partial)
    }

    func testSamplingRaceIsExplicitlyPartialAndEncoded() throws {
        let reader = SimulatorPhysicalFootprint(processList: snapshot, sample: { pid in
            if pid == 11 { throw SimulatorPhysicalFootprint.Failure.sampleFailed(pid, 3) }
            return 43
        })
        let result = try reader.measure(udid: udid)
        XCTAssertEqual(result.failedPIDs, [11])
        XCTAssertEqual(result.sampledProcessCount, 2)
        XCTAssertEqual(result.physicalFootprintBytes, 86)
        XCTAssertTrue(result.partial)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any]
        XCTAssertEqual(object?["partial"] as? Bool, true)
    }

    func testAllSamplesFailRatherThanClaimZero() throws {
        let reader = SimulatorPhysicalFootprint(processList: snapshot, sample: { _ in
            throw SimulatorPhysicalFootprint.Failure.noSamples
        })
        XCTAssertThrowsError(try reader.measure(udid: udid))
    }

    func testRejectsMissingAmbiguousAndInvalidTargets() throws {
        let entries = try snapshot()
        let missing = SimulatorPhysicalFootprint(processList: { entries.filter { $0.pid != 10 } }, sample: { _ in 1 })
        XCTAssertThrowsError(try missing.measure(udid: udid))
        let duplicate = SimulatorPhysicalFootprint.ProcessEntry(pid: 40, parentPID: 1, arguments: entries[1].arguments)
        let ambiguous = SimulatorPhysicalFootprint(processList: { entries + [duplicate] }, sample: { _ in 1 })
        XCTAssertThrowsError(try ambiguous.measure(udid: udid))
        XCTAssertThrowsError(try ambiguous.measure(udid: "booted"))
    }

    func testMalformedSnapshotAndOverflowFail() throws {
        XCTAssertThrowsError(try SimulatorPhysicalFootprint.parseProcessList("permission denied"))
        XCTAssertThrowsError(try SimulatorPhysicalFootprint.parseProcessList(""))
        let reader = SimulatorPhysicalFootprint(processList: snapshot, sample: { _ in UInt64.max })
        XCTAssertThrowsError(try reader.measure(udid: udid))
    }

    #if os(macOS)
    func testLibprocSamplesCurrentProcess() throws {
        XCTAssertGreaterThan(try SimulatorPhysicalFootprint.hostSample(pid: ProcessInfo.processInfo.processIdentifier), 0)
    }
    #endif
}
