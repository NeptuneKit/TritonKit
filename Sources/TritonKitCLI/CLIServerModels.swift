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

    var outbound: WebSocketOutboundWriter? { lock.withLock { matchingConnectionsLocked(TKLocalTargetID).first?.connection.outbound } }
    var isConnected: Bool { lock.withLock { connections.values.contains { $0.state.registrationDecision.accepted } } }
    var targetCount: Int { lock.withLock { connections.values.filter { $0.state.registrationDecision.accepted }.count } }

    func registrationResponse() -> RuntimeRegistrationResponse {
        lock.withLock {
            RuntimeRegistrationResponse(
                registrations: connections.values
                    .map { $0.state.registrationDecision }
                    .sorted { ($0.sdkVersion ?? "") < ($1.sdkVersion ?? "") }
            )
        }
    }

    func summaries() -> [TKTargetSummary] {
        lock.withLock {
            connections.values
                .compactMap { $0.summary() }
                .sorted { $0.id < $1.id }
        }
    }

    func cacheStatus() -> (activeHierarchyAvailable: Bool, latestHierarchyAvailable: Bool, hierarchyCacheState: String) {
        lock.withLock {
            let connected = connections.values.contains { $0.state.registrationDecision.accepted }
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
        return try lock.withLock {
            let candidates: [(connection: TargetConnection, summary: TKTargetSummary)] = connections.values.compactMap { connection in
                connection.summary().map { (connection, $0) }
            }
            let summary = try resolveServerTargetSummary(
                requested: target,
                in: candidates.map(\.summary)
            )
            guard let connection = candidates.first(where: { $0.summary.id == summary.id })?.connection else {
                throw TKTargetResolutionError.notFound(target)
            }
            return connection
        }
    }

    private func matchingConnectionsLocked(_ requested: String) -> [(connection: TargetConnection, summary: TKTargetSummary)] {
        let candidates: [(connection: TargetConnection, summary: TKTargetSummary)] = connections.values.compactMap { connection in
            connection.summary().map { (connection, $0) }
        }
        let matchedIDs = Set(
            matchingServerTargetSummaries(
                requested: requested,
                in: candidates.map(\.summary)
            ).map(\.id)
        )
        return candidates.filter { matchedIDs.contains($0.summary.id) }
    }

}

/// Server-side selector compatibility keeps bare Simulator UDIDs as a legacy
/// selector, but never treats a canonical app-scoped target as a UDID alias.
/// That distinction matters for receipt-backed reliability samples: an exact
/// app target that disappeared must fail rather than route a primitive to a
/// different bundle on the same Simulator.
func matchingServerTargetSummaries(
    requested: String,
    in summaries: [TKTargetSummary]
) -> [TKTargetSummary] {
    let normalized = TKNormalizeTargetID(requested)
    if normalized == TKLocalTargetID, summaries.count == 1 {
        return summaries
    }
    let exact = summaries.filter { $0.id == normalized }
    if !exact.isEmpty {
        return exact
    }
    guard !requiresExactServerTargetID(normalized) else {
        return []
    }
    let simulatorSelector = TKIOSSimulatorUDID(fromTargetID: normalized) ?? requested
    return summaries.filter { $0.simulatorUDID == simulatorSelector }
}

func resolveServerTargetSummary(
    requested: String,
    in summaries: [TKTargetSummary]
) throws -> TKTargetSummary {
    let matches = matchingServerTargetSummaries(requested: requested, in: summaries)
    if matches.count == 1, let summary = matches.first {
        return summary
    }
    if matches.count > 1 {
        throw TKTargetResolutionError.ambiguous(requested: requested, available: matches.map(\.id))
    }
    let normalized = TKNormalizeTargetID(requested)
    if normalized == TKLocalTargetID, summaries.count > 1 {
        throw TKTargetResolutionError.ambiguous(requested: requested, available: summaries.map(\.id))
    }
    throw TKTargetResolutionError.notFound(requested)
}

private func requiresExactServerTargetID(_ target: String) -> Bool {
    guard target.hasPrefix(TKIOSSimulatorRuntimeTargetPrefix),
          let separator = target.range(of: "/app:"),
          separator.lowerBound > target.startIndex,
          separator.upperBound < target.endIndex else {
        return false
    }
    let udidStart = target.index(
        target.startIndex,
        offsetBy: TKIOSSimulatorRuntimeTargetPrefix.count
    )
    let udid = String(target[udidStart..<separator.lowerBound])
    let bundleID = String(target[separator.upperBound...])
    guard !udid.isEmpty,
          !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return false
    }
    return target == TKIOSSimulatorRuntimeTargetID(
        simulatorUDID: udid,
        bundleIdentifier: bundleID
    )
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

struct RuntimeRegistrationDecision: Codable, Equatable, Sendable {
    let accepted: Bool
    let state: String
    let code: String
    let reason: String
    let sdkVersion: String?
    let versionSource: String
}

struct RuntimeRegistrationResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let code: String
    let reason: String
    let registrations: [RuntimeRegistrationDecision]

    init(registrations: [RuntimeRegistrationDecision]) {
        self.registrations = registrations
        if registrations.isEmpty {
            self.ok = false
            self.code = "runtime_registration_unobserved"
            self.reason = "No runtime registration is observable; the server cannot determine whether an app process launched."
        } else if let rejected = registrations.first(where: { !$0.accepted }) {
            self.ok = false
            self.code = rejected.code
            self.reason = rejected.reason
        } else {
            self.ok = true
            self.code = "runtime_registration_available"
            self.reason = "At least one compatible embedded runtime registration is available."
        }
    }
}

func legacyWebSocketRegistrationDecision() -> RuntimeRegistrationDecision {
    RuntimeRegistrationDecision(
        accepted: true,
        state: "accepted",
        code: "legacy_websocket_accepted",
        reason: "Legacy embedded runtimes are accepted without a separate registration frame while runtimeManifest compatibility is probed.",
        sdkVersion: nil,
        versionSource: "websocket-legacy-compatible"
    )
}

func runtimeRegistrationDecision(manifestPayload: Data) -> RuntimeRegistrationDecision {
    guard let manifest = try? JSONDecoder().decode(TKRuntimeManifestResponse.self, from: manifestPayload) else {
        return RuntimeRegistrationDecision(
            accepted: false,
            state: "rejected",
            code: "runtime_manifest_invalid",
            reason: "Registration payload does not decode as TKRuntimeManifestResponse.",
            sdkVersion: nil,
            versionSource: "runtime-manifest-invalid"
        )
    }
    guard manifest.platform == "ios", manifest.runtime == "embedded" else {
        return RuntimeRegistrationDecision(
            accepted: false,
            state: "rejected",
            code: "runtime_scope_unsupported",
            reason: "Only the iOS embedded runtime scope is accepted on this WebSocket endpoint.",
            sdkVersion: manifest.sdkVersion,
            versionSource: "runtime-manifest"
        )
    }
    guard manifest.transport == "embedded-websocket" else {
        return RuntimeRegistrationDecision(
            accepted: false,
            state: "rejected",
            code: "runtime_transport_unsupported",
            reason: "Runtime manifest transport must be embedded-websocket.",
            sdkVersion: manifest.sdkVersion,
            versionSource: "runtime-manifest"
        )
    }
    guard manifest.ok, manifest.enabled else {
        return RuntimeRegistrationDecision(
            accepted: false,
            state: "rejected",
            code: "runtime_disabled",
            reason: "Runtime manifest reports that the embedded runtime is disabled.",
            sdkVersion: manifest.sdkVersion,
            versionSource: "runtime-manifest"
        )
    }
    let unverifiedRelease = manifest.sdkVersion.contains("dev")
    return RuntimeRegistrationDecision(
        accepted: true,
        state: "accepted",
        code: "legacy_runtime_manifest_accepted",
        reason: "Legacy runtimes are accepted without a separate registration frame because the runtime manifest matches the compatible embedded WebSocket contract.",
        sdkVersion: manifest.sdkVersion,
        versionSource: unverifiedRelease ? "runtime-manifest-unverified-release" : "runtime-manifest"
    )
}

final class TargetState: @unchecked Sendable {
    private let lock = NSLock()
    private var _latestHierarchy: Data?
    private var metadata: TargetMetadata?
    private var activeHierarchyAvailable = false
    private var responses: [Int: Data] = [:]
    private var _registrationDecision = legacyWebSocketRegistrationDecision()

    var registrationDecision: RuntimeRegistrationDecision {
        lock.withLock { _registrationDecision }
    }

    var latestHierarchy: Data? {
        lock.withLock { _latestHierarchy }
    }

    func beginConnection() {
        lock.withLock {
            metadata = nil
            activeHierarchyAvailable = false
            responses.removeAll()
            _registrationDecision = legacyWebSocketRegistrationDecision()
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

    func setRuntimeRegistrationManifest(_ data: Data) {
        let decision = runtimeRegistrationDecision(manifestPayload: data)
        lock.withLock {
            _registrationDecision = decision
        }
    }

    func summary(connected: Bool, connectionID: Int) -> TKTargetSummary? {
        guard connected, registrationDecision.accepted else { return nil }
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

    func waitForResponse(id: Int, attempts: Int = 100) async -> Data? {
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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let appInfo = (json["appInfo"] as? [String: Any]) ?? json
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
            return TKIOSSimulatorRuntimeTargetID(
                simulatorUDID: simulatorUDID,
                bundleIdentifier: metadata?.bundleIdentifier
            )
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
