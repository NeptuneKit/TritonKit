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
    private var _outbound: WebSocketOutboundWriter?
    private var connectionID = 0

    func connect(_ w: WebSocketOutboundWriter) -> Int {
        lock.withLock {
            connectionID += 1
            _outbound = w
            return connectionID
        }
    }

    func disconnect(connectionID id: Int) -> Bool {
        lock.withLock {
            guard connectionID == id else { return false }
            _outbound = nil
            return true
        }
    }

    var outbound: WebSocketOutboundWriter? { lock.withLock { _outbound } }
    var isConnected: Bool { lock.withLock { _outbound != nil } }
}

final class MessageCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}

struct TargetMetadata: Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var deviceDescription: String?
    var osDescription: String?
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

    func summary(connected: Bool) -> TKTargetSummary? {
        guard connected else { return nil }
        return lock.withLock {
            TKTargetSummary(
                connected: true,
                latestHierarchyAvailable: activeHierarchyAvailable,
                appName: metadata?.appName,
                bundleIdentifier: metadata?.bundleIdentifier,
                deviceDescription: metadata?.deviceDescription,
                osDescription: metadata?.osDescription,
                activeHierarchyAvailable: activeHierarchyAvailable,
                cachedHierarchyAvailable: _latestHierarchy != nil,
                hierarchyCacheState: hierarchyCacheState(connected: true),
                identityState: metadata == nil ? "unknown" : "current"
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
            deviceDescription: appInfo["deviceDescription"] as? String,
            osDescription: appInfo["osDescription"] as? String
        )
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
