import Foundation
import TritonKitShared

enum HostAppOpenURLFlowStatus: String, Codable {
    case pass
    case fail
}

struct HostAppOpenURLHostStep: Codable, Equatable {
    let ok: Bool
    let target: String
    let sourceCommand: String
    let elapsedMs: Int
}

struct HostAppOpenURLReadySummary: Codable, Equatable {
    let ok: Bool
    let connected: Bool
    let latestHierarchyAvailable: Bool
    let activeHierarchyAvailable: Bool?
    let targetConnectionState: String?
    let hierarchyCacheState: String?
    let targetCount: Int
    let pollCount: Int
    let elapsedMs: Int
}

struct HostAppOpenURLSnapshotSummary: Codable, Equatable {
    let ok: Bool
    let capturedAt: String
    let runtime: String
    let targetConnectionState: String?
    let include: [String]
    let appName: String?
    let bundleIdentifier: String?
    let sceneCount: Int?
    let windowCount: Int?
    let visibleControllerClass: String?
    let visibleControllerTitle: String?
    let selectedTabTitle: String?
    let axNodeCount: Int?
    let artifacts: [String]
    let skipped: [String]
    let truncated: Bool
}

struct HostAppOpenURLFlowSummary: Codable, Equatable {
    let ok: Bool
    let action: String
    let status: HostAppOpenURLFlowStatus
    let platform: String
    let url: String
    let simulator: String
    let runtimeTarget: String
    let hostAction: HostAppOpenURLHostStep
    let ready: HostAppOpenURLReadySummary?
    let snapshot: HostAppOpenURLSnapshotSummary?
    let elapsedMs: Int
    let note: String
}

struct IOSAppOpenURLFlowOptions {
    let simulator: String
    let runtimeTarget: String
    let url: String
    let waitReady: Bool
    let snapshot: Bool
    let snapshotInclude: [String]
    let maxAXNodes: Int?
    let host: String
    let port: Int
    let timeout: Double
    let interval: Double
}

struct IOSAppOpenURLFlowDependencies {
    var openURL: (String, String) throws -> HostAppOpenURLHostStep
    var status: (String, Int) async throws -> TKStatusResponse
    var snapshot: (String, String, Int, [String], Int?) async throws -> TKRuntimeSnapshotResponse

    static func live() -> IOSAppOpenURLFlowDependencies {
        IOSAppOpenURLFlowDependencies(
            openURL: { simulator, url in
                let startedAt = Date()
                let result = try runHostCommand(TKSimctlCommand.openURL(udid: simulator, url: url))
                return HostAppOpenURLHostStep(
                    ok: true,
                    target: "sim:\(simulator)",
                    sourceCommand: result.sourceCommand,
                    elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000)
                )
            },
            status: { host, port in
                try await TritonKitHTTPClient(host: host, port: port).getJSON("/status")
            },
            snapshot: { target, host, port, include, maxAXNodes in
                let client = TritonKitHTTPClient(host: host, port: port, target: target)
                let request = TKRuntimeSnapshotRequest(include: include, maxAXNodes: maxAXNodes)
                let payload = try JSONEncoder().encode(request)
                let data = try await client.request(type: "runtimeSnapshot", payload: payload)
                return try JSONDecoder().decode(TKRuntimeSnapshotResponse.self, from: data)
            }
        )
    }
}

func runIOSAppOpenURLFlow(
    options: IOSAppOpenURLFlowOptions,
    dependencies: IOSAppOpenURLFlowDependencies = .live()
) async throws -> HostAppOpenURLFlowSummary {
    let startedAt = Date()
    let hostAction = try dependencies.openURL(options.simulator, options.url)
    let shouldWaitReady = options.waitReady || options.snapshot
    let ready = shouldWaitReady
        ? try await waitForIOSRuntimeReady(options: options, dependencies: dependencies, startedAt: startedAt)
        : nil
    let snapshot = options.snapshot
        ? summarizeSnapshot(try await dependencies.snapshot(options.runtimeTarget, options.host, options.port, options.snapshotInclude, options.maxAXNodes))
        : nil

    return HostAppOpenURLFlowSummary(
        ok: true,
        action: "app.open-url",
        status: .pass,
        platform: "ios",
        url: options.url,
        simulator: options.simulator,
        runtimeTarget: options.runtimeTarget,
        hostAction: hostAction,
        ready: ready,
        snapshot: snapshot,
        elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000),
        note: "URL was submitted and runtime verification completed."
    )
}

private func waitForIOSRuntimeReady(
    options: IOSAppOpenURLFlowOptions,
    dependencies: IOSAppOpenURLFlowDependencies,
    startedAt: Date
) async throws -> HostAppOpenURLReadySummary {
    let deadline = Date().addingTimeInterval(options.timeout)
    var pollCount = 0
    var lastStatus: TKStatusResponse?
    repeat {
        pollCount += 1
        let status = try await dependencies.status(options.host, options.port)
        lastStatus = status
        let hierarchyReady = status.activeHierarchyAvailable ?? status.latestHierarchyAvailable
        if status.connected && hierarchyReady && status.targetConnectionState != "disconnected" {
            return HostAppOpenURLReadySummary(
                ok: true,
                connected: status.connected,
                latestHierarchyAvailable: status.latestHierarchyAvailable,
                activeHierarchyAvailable: status.activeHierarchyAvailable,
                targetConnectionState: status.targetConnectionState,
                hierarchyCacheState: status.hierarchyCacheState,
                targetCount: status.targetCount,
                pollCount: pollCount,
                elapsedMs: Int(Date().timeIntervalSince(startedAt) * 1000)
            )
        }
        if Date() >= deadline {
            break
        }
        try await Task.sleep(nanoseconds: UInt64(max(0.01, options.interval) * 1_000_000_000))
    } while Date() <= deadline

    if let lastStatus {
        throw RuntimeError("Runtime was not ready after open-url: connected=\(lastStatus.connected), hierarchy=\(lastStatus.hierarchyCacheState ?? "unknown"), target=\(lastStatus.targetConnectionState ?? "unknown")")
    }
    throw RuntimeError("Runtime was not reachable after open-url.")
}

private func summarizeSnapshot(_ snapshot: TKRuntimeSnapshotResponse) -> HostAppOpenURLSnapshotSummary {
    HostAppOpenURLSnapshotSummary(
        ok: snapshot.ok,
        capturedAt: snapshot.capturedAt,
        runtime: snapshot.runtime,
        targetConnectionState: snapshot.targetConnectionState,
        include: snapshot.include,
        appName: snapshot.app?.displayName,
        bundleIdentifier: snapshot.app?.bundleIdentifier,
        sceneCount: snapshot.app?.sceneCount,
        windowCount: snapshot.app?.windowCount,
        visibleControllerClass: snapshot.route?.visibleController?.className,
        visibleControllerTitle: snapshot.route?.visibleController?.title,
        selectedTabTitle: snapshot.route?.tab?.selectedTitle,
        axNodeCount: snapshot.ax?.count,
        artifacts: snapshot.artifacts.map(\.name),
        skipped: snapshot.skipped.map(\.name),
        truncated: snapshot.truncation.truncated
    )
}
