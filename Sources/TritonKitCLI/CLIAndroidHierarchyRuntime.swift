import Foundation
import TritonKitShared

enum AndroidObserveError: Error, Equatable, CustomStringConvertible {
    case hierarchyUnavailable(reason: String)
    var code: String { "hierarchy_unavailable" }
    var description: String {
        switch self {
        case .hierarchyUnavailable(let reason): return reason
        }
    }
}

struct AndroidHierarchyCapture {
    let data: Data
    let collected: TKBoundedNodeCollection<TKAndroidUIAutomatorNodeSummary>
    let sourceCommands: [String]
}

/// A successful shell exit is not evidence that UIAutomator created a new tree.
/// Observation and coordinate-resolution consumers share this freshness boundary.
func captureAndroidHierarchy(
    serial: String,
    adb: String = "adb",
    maxNodes: Int? = nil,
    runner: AndroidObserveHostRunner = { try runHostCommand($0) }
) throws -> AndroidHierarchyCapture {
    let remotePath = "/sdcard/triton-window-\(UUID().uuidString).xml"
    let dump = TKAndroidADBCommand.uiautomatorDump(serial: serial, remotePath: remotePath, executable: adb)
    let read = TKAndroidADBCommand.readFile(serial: serial, remotePath: remotePath, executable: adb)
    let cleanup = TKAndroidADBCommand.removeFile(serial: serial, remotePath: remotePath, executable: adb).withTimeout(3)
    // Only the UUID path owned by this capture is ever removed. A cleanup failure
    // cannot turn a failed capture into success or mask its original error.
    defer { _ = try? runner(cleanup) }
    let dumped: HostProcessResult
    do {
        dumped = try runner(dump)
    } catch HostCommandRunError.nonZeroExit {
        throw AndroidObserveError.hierarchyUnavailable(reason: "Android UIAutomator dump failed; no current hierarchy is available.")
    }
    let dumpText = (dumped.stdout + "\n" + dumped.stderr).lowercased()
    guard dumped.exitCode == 0,
          !dumped.stdoutTruncated, !dumped.stderrTruncated,
          !dumpText.contains("error:"), !dumpText.contains("null root node"),
          (try? TKAndroidUIAutomatorDumpParser.remotePath(from: dumped.stdout)) == remotePath else {
        throw AndroidObserveError.hierarchyUnavailable(reason: "Android UIAutomator did not confirm a fresh hierarchy; retry after a current UI root is available.")
    }
    let result: HostProcessResult
    do {
        result = try runner(read)
    } catch HostCommandRunError.nonZeroExit {
        throw AndroidObserveError.hierarchyUnavailable(reason: "Android UIAutomator did not create a readable current hierarchy.")
    }
    guard result.exitCode == 0, !result.stdoutData.isEmpty, !result.stdoutTruncated else {
        throw AndroidObserveError.hierarchyUnavailable(reason: "Android UIAutomator hierarchy is missing, empty, or truncated.")
    }
    let collected: TKBoundedNodeCollection<TKAndroidUIAutomatorNodeSummary>
    do {
        collected = try TKAndroidUIAutomatorXMLParser.nodeSummaries(in: result.stdoutData, budget: .init(maxNodes: maxNodes ?? 800))
    } catch {
        throw AndroidObserveError.hierarchyUnavailable(reason: "Android UIAutomator hierarchy could not be parsed; no current tree is available.")
    }
    guard !collected.nodes.isEmpty else {
        throw AndroidObserveError.hierarchyUnavailable(reason: "Android UIAutomator returned no hierarchy nodes.")
    }
    return AndroidHierarchyCapture(data: result.stdoutData, collected: collected, sourceCommands: [dumped.sourceCommand, result.sourceCommand, hostSourceCommand(cleanup)])
}
