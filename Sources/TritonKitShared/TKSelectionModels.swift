import Foundation

/// A short-lived, process-bound reference to the user's explicit selection.
public struct TKSelectionGuard: Codable, Equatable {
    public let runtimeInstanceID: String
    public let selectionID: String
    public let revision: UInt64
    public init(runtimeInstanceID: String, selectionID: String, revision: UInt64) {
        self.runtimeInstanceID = runtimeInstanceID
        self.selectionID = selectionID
        self.revision = revision
    }
    public func validate() throws {
        guard !runtimeInstanceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !selectionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, revision > 0 else {
            throw TKSelectionError(code: "validation_failed", message: "Selection runtime, id and a positive revision are required.")
        }
    }
}

public struct TKSelectionRequest: Codable, Equatable {
    public let runtimeInstanceID: String?
    public init(runtimeInstanceID: String? = nil) { self.runtimeInstanceID = runtimeInstanceID }
}

public struct TKSelectionError: Error, Codable, Equatable {
    public let code: String
    public let message: String
    public init(code: String, message: String) { self.code = code; self.message = message }
}

public struct TKSelectionSnapshot: Codable, Equatable {
    public let id: String
    public let revision: UInt64
    public let selectedAt: Double
    public let expiresAt: Double
    public let sceneID: String
    public let windowID: UInt
    public let rawHitOID: UInt
    public let target: TKAXNode
    public let validity: String
    public let invalidReason: String?
    public let supportedActions: [String]
    public let resolutionReason: String
    public let coordinateSpace: String
    public init(id: String, revision: UInt64, selectedAt: Double, expiresAt: Double,
                sceneID: String, windowID: UInt, rawHitOID: UInt, target: TKAXNode,
                validity: String, invalidReason: String? = nil, supportedActions: [String],
                resolutionReason: String = "exact-view") {
        self.id = id; self.revision = revision; self.selectedAt = selectedAt; self.expiresAt = expiresAt
        self.sceneID = sceneID; self.windowID = windowID; self.rawHitOID = rawHitOID; self.target = target
        self.validity = validity; self.invalidReason = invalidReason; self.supportedActions = supportedActions
        self.resolutionReason = resolutionReason; self.coordinateSpace = "window-points"
    }
}

public struct TKSelectionResponse: Codable, Equatable {
    public let ok: Bool
    public let schemaVersion: Int
    public let runtimeInstanceID: String
    public let revision: UInt64
    public let state: String
    public let selection: TKSelectionSnapshot?
    public let error: TKSelectionError?
    /// `unknown` forbids automatic replay; `not_started` denotes admission refusal.
    public let outcome: String?
    public let uiHealth: TKRuntimeUIHealthSnapshot?
    public init(ok: Bool = true, runtimeInstanceID: String, revision: UInt64 = 0,
                state: String = "none", selection: TKSelectionSnapshot? = nil, error: TKSelectionError? = nil,
                outcome: String? = nil, uiHealth: TKRuntimeUIHealthSnapshot? = nil) {
        self.ok = ok; self.schemaVersion = 1; self.runtimeInstanceID = runtimeInstanceID
        self.revision = revision; self.state = state; self.selection = selection; self.error = error
        self.outcome = outcome; self.uiHealth = uiHealth
    }
}
