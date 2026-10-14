import Foundation

/// Diagnostic states describe admission, not the app's business state.
public enum TKRuntimeUIHealthState: String, Codable, Equatable {
    case ready
    case busy
    case timedOut = "timed_out"
    case circuitOpen = "circuit_open"
}

public struct TKRuntimeUIInflightRequest: Codable, Equatable {
    public let token: String
    public let requestID: Int
    public let requestType: String
    public let elapsedMilliseconds: Int
    public let timedOut: Bool

    public init(token: String, requestID: Int, requestType: String, elapsedMilliseconds: Int, timedOut: Bool) {
        self.token = token
        self.requestID = requestID
        self.requestType = requestType
        self.elapsedMilliseconds = elapsedMilliseconds
        self.timedOut = timedOut
    }
}

public struct TKRuntimeUICompletion: Codable, Equatable {
    public let token: String
    public let requestID: Int
    public let requestType: String
    public let timedOut: Bool
    public let producedResponse: Bool

    public init(token: String, requestID: Int, requestType: String, timedOut: Bool, producedResponse: Bool) {
        self.token = token
        self.requestID = requestID
        self.requestType = requestType
        self.timedOut = timedOut
        self.producedResponse = producedResponse
    }
}

public struct TKRuntimeUIHealthSnapshot: Codable, Equatable {
    public let state: TKRuntimeUIHealthState
    public let allowsUIRequests: Bool
    public let inflight: TKRuntimeUIInflightRequest?
    public let consecutiveTimeouts: Int
    public let failureThreshold: Int
    public let timeoutMilliseconds: Int
    public let lastCompletion: TKRuntimeUICompletion?
    /// Timeout cannot cancel UIKit/MainActor work. Inspect state before an explicit recovery;
    /// never automatically retry an action whose response timed out.
    public let recoveryHint: String?

    public init(state: TKRuntimeUIHealthState, allowsUIRequests: Bool, inflight: TKRuntimeUIInflightRequest?, consecutiveTimeouts: Int, failureThreshold: Int, timeoutMilliseconds: Int, lastCompletion: TKRuntimeUICompletion?) {
        self.state = state
        self.allowsUIRequests = allowsUIRequests
        self.inflight = inflight
        self.consecutiveTimeouts = consecutiveTimeouts
        self.failureThreshold = failureThreshold
        self.timeoutMilliseconds = timeoutMilliseconds
        self.lastCompletion = lastCompletion
        self.recoveryHint = state == .timedOut || state == .circuitOpen
            ? "UI work may still be running. Do not replay actions automatically. Probe ping for completion; if blocked, explicitly relaunch the app/runtime and observe its state before issuing a new action."
            : nil
    }
}

/// Additive wire extension; old pong payloads and old clients remain compatible.
public struct TKRuntimePingResponse: Codable, Equatable {
    public let pong: Bool
    public let timestamp: TimeInterval
    public let uiHealth: TKRuntimeUIHealthSnapshot?

    public init(pong: Bool, timestamp: TimeInterval, uiHealth: TKRuntimeUIHealthSnapshot? = nil) {
        self.pong = pong
        self.timestamp = timestamp
        self.uiHealth = uiHealth
    }
}

/// Generic observation/legacy errors retain the normal CLI error envelope and diagnostics.
public struct TKRuntimeUIHealthErrorResponse: Codable, Equatable {
    public let ok: Bool
    public let error: TKCLIErrorDetail
    public let outcome: String
    public let uiHealth: TKRuntimeUIHealthSnapshot

    public init(error: TKCLIErrorDetail, outcome: String, uiHealth: TKRuntimeUIHealthSnapshot) {
        self.ok = false
        self.error = error
        self.outcome = outcome
        self.uiHealth = uiHealth
    }
}
