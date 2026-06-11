import ArgumentParser
import Darwin
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOFoundationCompat
import NIOCore
import TritonKit
import TritonKitShared

final class ConnectionState: @unchecked Sendable {
    private let lock = NSLock()
    private var connectionID = 0
    private var connections: [Int: TargetConnection] = [:]

    func connect(_ w: WebSocketOutboundWriter) -> TargetConnection {
        lock.withLock {
            connectionID += 1
            let connection = TargetConnection(connectionID: connectionID, outbound: w)
            connections[connectionID] = connection
            return connection
        }
    }

    func disconnect(connectionID id: Int) -> Bool {
        lock.withLock {
            connections.removeValue(forKey: id) != nil
        }
    }

    var outbound: WebSocketOutboundWriter? { lock.withLock { resolveLocked(TKLocalTargetID)?.outbound } }
    var isConnected: Bool { lock.withLock { !connections.isEmpty } }
    var targetCount: Int { lock.withLock { connections.count } }

    func summaries() -> [TKTargetSummary] {
        lock.withLock {
            connections.values
                .compactMap { $0.summary() }
                .sorted { $0.id < $1.id }
        }
    }

    func cacheStatus() -> (activeHierarchyAvailable: Bool, latestHierarchyAvailable: Bool, hierarchyCacheState: String) {
        lock.withLock {
            let connected = !connections.isEmpty
            let statuses = connections.values.map { $0.state.cacheStatus(connected: connected) }
            let active = statuses.contains { $0.activeHierarchyAvailable }
            let latest = connections.values.contains { $0.state.latestHierarchy != nil }
            let cacheState: String
            if active {
                cacheState = "active"
            } else if latest {
                cacheState = "stale"
            } else {
                cacheState = "unavailable"
            }
            return (active, latest, cacheState)
        }
    }

    func resolve(_ requested: String?) throws -> TargetConnection {
        let target = requested ?? TKLocalTargetID
        if let connection = lock.withLock({ resolveLocked(target) }) {
            return connection
        }
        let normalized = TKNormalizeTargetID(target)
        let available = summaries()
        if normalized == TKLocalTargetID, available.count > 1 {
            throw TKTargetResolutionError.ambiguous(requested: target, available: available.map(\.id))
        }
        throw TKTargetResolutionError.notFound(target)
    }

    private func resolveLocked(_ requested: String) -> TargetConnection? {
        let normalized = TKNormalizeTargetID(requested)
        if normalized == TKLocalTargetID, connections.count == 1 {
            return connections.values.first
        }
        let matches: [(connection: TargetConnection, summary: TKTargetSummary)] = connections.values.compactMap { connection in
            guard let summary = connection.summary(),
                  summary.id == normalized || summary.simulatorUDID == requested else {
                return nil
            }
            return (connection, summary)
        }
        if matches.count <= 1 {
            return matches.first?.connection
        }
        return matches.first { match in
            match.summary.activeHierarchyAvailable == true || match.summary.hierarchyCacheState == "active"
        }?.connection ?? matches.first?.connection
    }

}

final class TargetConnection: @unchecked Sendable {
    let connectionID: Int
    let outbound: WebSocketOutboundWriter
    let state = TargetState()

    init(connectionID: Int, outbound: WebSocketOutboundWriter) {
        self.connectionID = connectionID
        self.outbound = outbound
    }

    func summary() -> TKTargetSummary? {
        state.summary(connected: true, connectionID: connectionID)
    }
}

final class MessageCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

struct TargetMetadata: Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var platform: String?
    var deviceDescription: String?
    var osDescription: String?
    var simulatorUDID: String?
}

final class TargetState: @unchecked Sendable {
    private let lock = NSLock()
    private var _latestHierarchy: Data?
    private var metadata: TargetMetadata?
    private var activeHierarchyAvailable = false
    private var responses: [Int: Data] = [:]

    var latestHierarchy: Data? {
        lock.withLock { _latestHierarchy }
    }

    func beginConnection() {
        lock.withLock {
            metadata = nil
            activeHierarchyAvailable = false
            responses.removeAll()
        }
    }

    func endConnection() {
        lock.withLock {
            metadata = nil
            activeHierarchyAvailable = false
            responses.removeAll()
        }
    }

    func setLatestHierarchy(_ data: Data) {
        let appInfo = extractAppInfo(fromHierarchy: data)
        lock.withLock {
            _latestHierarchy = data
            activeHierarchyAvailable = true
            if let appInfo {
                metadata = appInfo
            }
        }
    }

    func setLatestAppInfo(_ data: Data) {
        guard let appInfo = extractAppInfo(fromAppInfoPayload: data) else { return }
        lock.withLock {
            metadata = appInfo
        }
    }

    func summary(connected: Bool, connectionID: Int) -> TKTargetSummary? {
        guard connected else { return nil }
        return lock.withLock {
            TKTargetSummary(
                id: targetID(connectionID: connectionID),
                connected: true,
                latestHierarchyAvailable: activeHierarchyAvailable,
                appName: metadata?.appName,
                bundleIdentifier: metadata?.bundleIdentifier,
                deviceDescription: metadata?.deviceDescription,
                osDescription: metadata?.osDescription,
                simulatorUDID: metadata?.simulatorUDID,
                activeHierarchyAvailable: activeHierarchyAvailable,
                cachedHierarchyAvailable: _latestHierarchy != nil,
                hierarchyCacheState: hierarchyCacheState(connected: true),
                identityState: metadata == nil ? "unknown" : "current",
                platform: metadata?.platform
            )
        }
    }

    func cacheStatus(connected: Bool) -> (activeHierarchyAvailable: Bool, hierarchyCacheState: String) {
        lock.withLock {
            (
                activeHierarchyAvailable,
                hierarchyCacheState(connected: connected)
            )
        }
    }

    func storeResponse(id: Int, payload: Data) {
        lock.withLock {
            responses[id] = payload
        }
    }

    func waitForResponse(id: Int, attempts: Int = 25) async -> Data? {
        for _ in 0..<attempts {
            if let data = lock.withLock({ responses.removeValue(forKey: id) }) {
                return data
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func extractAppInfo(fromHierarchy data: Data) -> TargetMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appInfo = json["appInfo"] as? [String: Any] else {
            return nil
        }
        return extractMetadata(from: appInfo)
    }

    private func extractAppInfo(fromAppInfoPayload data: Data) -> TargetMetadata? {
        guard let appInfo = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractMetadata(from: appInfo)
    }

    private func extractMetadata(from appInfo: [String: Any]) -> TargetMetadata {
        TargetMetadata(
            appName: appInfo["appName"] as? String,
            bundleIdentifier: appInfo["appBundleIdentifier"] as? String,
            platform: appInfo["platform"] as? String,
            deviceDescription: appInfo["deviceDescription"] as? String,
            osDescription: appInfo["osDescription"] as? String,
            simulatorUDID: appInfo["simulatorUDID"] as? String
        )
    }

    private func targetID(connectionID: Int) -> String {
        if let simulatorUDID = metadata?.simulatorUDID, !simulatorUDID.isEmpty {
            return "triton:ios-simulator:\(simulatorUDID)"
        }
        return connectionID == 1 ? TKLocalTargetID : "triton:connection:\(connectionID)"
    }

    private func hierarchyCacheState(connected: Bool) -> String {
        if connected && activeHierarchyAvailable { return "active" }
        if _latestHierarchy != nil { return "stale" }
        return "unavailable"
    }
}

/// Thread-safe binary data store keyed by UUID
final class DataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: Data] = [:]

    func put(_ data: Data) -> UUID {
        let id = UUID()
        lock.withLock { storage[id] = data }
        return id
    }

    func get(_ id: UUID) -> Data? {
        lock.withLock { storage[id] }
    }
}

func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) -> Response {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value) else {
        return Response(status: .internalServerError)
    }
    return Response(status: status, headers: [.contentType: "application/json"],
                    body: .init(byteBuffer: ByteBuffer(data: data)))
}

func jsonError(_ message: String, status: HTTPResponse.Status) -> Response {
    jsonError(code: "request_failed", message: message, status: status)
}

func jsonError(
    code: String,
    message: String,
    endpoint: String? = nil,
    hint: String? = nil,
    status: HTTPResponse.Status
) -> Response {
    jsonResponse(
        TKCLIErrorResponse(error: TKCLIErrorDetail(
            code: code,
            message: message,
            endpoint: endpoint,
            hint: hint
        )),
        status: status
    )
}

func jsonError(detail: TKCLIErrorDetail, status: HTTPResponse.Status) -> Response {
    jsonResponse(TKCLIErrorResponse(error: detail), status: status)
}
