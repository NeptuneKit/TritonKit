import CoreFoundation
import Foundation
import TritonKitShared

/// Diagnostics only: never render payload strings, dictionary keys, SDK versions or error text.
/// Counts are process-wide for the default sink, with constant storage (no per-request history).
/// No verbose mode can opt into raw payload logging. The sink must not reenter this logger.
final class ServerResponseLogger: @unchecked Sendable {
    static let shared = ServerResponseLogger()
    static let maximumLineBytes = 512 // Includes the newline written by log(_:).
    static let healthyPingSummaryInterval: UInt64 = 100

    private let lock = NSLock()
    private let sink: (String) -> Void
    private var received: UInt64 = 0
    private var failures: UInt64 = 0
    private var healthyPings: UInt64 = 0

    init(sink: @escaping (String) -> Void = log) {
        self.sink = sink
    }

    func record(message: TKMessage?, frameBytes: Int, json: Any?, registrationAccepted: Bool? = nil) {
        // Preserve the existing background-heartbeat contract, including its zero log count.
        if message?.type == .ping, message?.id == 0 { return }
        let outcome = Self.outcome(message: message, json: json, registrationAccepted: registrationAccepted)
        lock.withLock {
            received = Self.increment(received)
            if outcome.isFailure { failures = Self.increment(failures) }
            if outcome == .healthyPing {
                healthyPings = Self.increment(healthyPings)
                // First success establishes observability, then one summary per 100 successes.
                guard healthyPings == 1 || healthyPings % Self.healthyPingSummaryInterval == 0 else { return }
            }
            // Every value is a local constant, a closed enum, a count or an integer wire ID.
            // Unknown types and arbitrary error codes deliberately never reach this formatter.
            let type = message?.type.rawValue ?? "unknown"
            let id = message.map { String($0.id) } ?? "none"
            let payloadBytes = message?.payload?.count ?? 0
            let line = "[tritonkit] response type=\(type) id=\(id) frameBytes=\(frameBytes) payloadBytes=\(payloadBytes) outcome=\(outcome.rawValue) received=\(received) failures=\(failures) healthyPings=\(healthyPings)"
            // Fixed-field formatting is bounded even at integer limits. Fail closed if extended.
            sink(line.utf8.count < Self.maximumLineBytes ? line : "[tritonkit] response outcome=metadata_limit")
        }
    }

    private enum Outcome: String {
        case received, success
        case healthyPing = "healthy_ping"
        case remoteFailure = "remote_failure"
        case invalidMessage = "invalid_message"
        case invalidPayload = "invalid_payload"
        case invalidPing = "invalid_ping"
        case unhealthyPing = "unhealthy_ping"
        case registrationRejected = "registration_rejected"

        var isFailure: Bool {
            switch self {
            case .received, .success, .healthyPing: return false
            default: return true
            }
        }
    }

    private static func outcome(message: TKMessage?, json: Any?, registrationAccepted: Bool?) -> Outcome {
        guard let message else { return .invalidMessage }
        guard let payload = message.payload, let json else { return .invalidPayload }
        if let dictionary = json as? [String: Any] {
            if boolean(dictionary["ok"]) == false { return .remoteFailure }
            if let error = dictionary["error"], !(error is NSNull) { return .remoteFailure }
            if let errors = dictionary["errors"] as? [Any], !errors.isEmpty { return .remoteFailure }
            if dictionary["message"] != nil, dictionary["code"] != nil,
               (try? JSONDecoder().decode(TKErrorPayload.self, from: payload)) != nil {
                return .remoteFailure
            }
        }
        if registrationAccepted == false { return .registrationRejected }
        if message.type == .ping {
            guard let ping = try? JSONDecoder().decode(TKRuntimePingResponse.self, from: payload) else {
                return .invalidPing
            }
            guard ping.pong else { return .remoteFailure }
            if let health = ping.uiHealth, health.state != .ready || !health.allowsUIRequests {
                return .unhealthyPing
            }
            return .healthyPing
        }
        if let dictionary = json as? [String: Any], boolean(dictionary["ok"]) == true { return .success }
        return .received
    }

    // JSONSerialization bridges 0/1 to NSNumber too; those are not JSON booleans.
    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func increment(_ count: UInt64) -> UInt64 {
        count == .max ? count : count + 1
    }
}
