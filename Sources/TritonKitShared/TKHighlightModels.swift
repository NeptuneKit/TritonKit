import Foundation

/// Independent, optional property highlighting. Raw original properties stay in the provider.
public struct TKHighlightError: Error, Codable, Equatable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public enum TKHighlightSessionState: String, Codable, Sendable {
    case active
    case partiallyActive = "partially_active"
    case restoring
    case closed
    case needsAttention = "needs_attention"
}

public enum TKHighlightMarkOutcome: String, Codable, Sendable {
    case applied
    case noChange = "no_change"
    case restored
    case alreadyOriginal = "already_original"
    case conflict
    case targetGone = "target_gone"
    case identityChanged = "identity_changed"
    case restorePending = "restore_pending"
    case restoreFailed = "restore_failed"
    case resolvedExternally = "resolved_externally"
    case failed
}

public enum TKHighlightResidualState: String, Codable, Sendable {
    case none, possible, unknown
}

public enum TKHighlightOwnershipAssurance: String, Codable, Sendable {
    case valueGuarded = "value_guarded"
    case versioned
}

public enum TKHighlightRestorationMode: String, Codable, Sendable {
    case snapshotCompareRestore = "snapshot_compare_restore"
    case managedOverride = "managed_override"
}

public enum TKHighlightRestoredTo: String, Codable, Sendable {
    case original
    case currentBase = "current_base"
    case alreadyOriginal = "already_original"
    case none
}

public struct TKHighlightSelector: Codable, Equatable, Sendable {
    public var oid: UInt?
    public var identifier: String?
    public var text: String?
    public var role: String?
    /// Restricts initial lookup to descendants of an existing ancestor object.
    public var withinOID: UInt?

    public init(oid: UInt? = nil, identifier: String? = nil, text: String? = nil, role: String? = nil, withinOID: UInt? = nil) {
        self.oid = oid
        self.identifier = identifier
        self.text = text
        self.role = role
        self.withinOID = withinOID
    }

    public func validate() throws {
        guard [oid != nil, identifier != nil, text != nil].filter({ $0 }).count == 1 else {
            throw validation("Selector requires exactly one of oid, identifier or text.")
        }
        guard oid != 0, withinOID != 0 else { throw validation("Object IDs must be greater than zero.") }
        try nonempty(identifier, name: "identifier")
        try nonempty(text, name: "text")
        try nonempty(role, name: "role")
    }
}

public struct TKHighlightItem: Codable, Equatable, Sendable {
    public var markID: String
    public var label: String?
    public var selector: TKHighlightSelector

    public init(markID: String, label: String? = nil, selector: TKHighlightSelector) {
        self.markID = markID
        self.label = label
        self.selector = selector
    }

    public func validate() throws {
        try nonempty(markID, name: "markID")
        try nonempty(label, name: "label")
        try selector.validate()
    }
}

public struct TKHighlightSpec: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var preset: String
    public var color: String
    public var width: Double
    public var items: [TKHighlightItem]

    public init(schemaVersion: Int = 1, preset: String = "outline", color: String = "#FF453A", width: Double = 3, items: [TKHighlightItem]) {
        self.schemaVersion = schemaVersion
        self.preset = preset
        self.color = color
        self.width = width
        self.items = items
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw validation("Unsupported highlight schemaVersion; expected 1.") }
        guard preset == "outline" else { throw validation("Only the outline preset is supported.") }
        guard color.count == 7, color.first == "#", color.dropFirst().allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw validation("Highlight color must be #RRGGBB.")
        }
        guard width.isFinite, width > 0, width <= 20 else { throw validation("Outline width must be finite and in (0, 20].") }
        guard (1...TKHighlightLimits.default.maxNodes).contains(items.count) else { throw validation("Highlight requires 1–10 items.") }
        guard Set(items.map(\.markID)).count == items.count else { throw validation("Highlight markIDs must be unique.") }
        for item in items { try item.validate() }
    }

    /// Canonical representation for operation deduplication; array order remains significant.
    public func canonicalData() throws -> Data {
        var normalized = self
        normalized.color = color.uppercased()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(normalized)
    }
}

public struct TKHighlightApplyRequest: Codable, Equatable, Sendable {
    public var operationID: String
    public var runtimeInstanceID: String?
    public var ttlSeconds: Int
    public var spec: TKHighlightSpec

    public init(operationID: String, runtimeInstanceID: String? = nil, ttlSeconds: Int = 30, spec: TKHighlightSpec) {
        self.operationID = operationID
        self.runtimeInstanceID = runtimeInstanceID
        self.ttlSeconds = ttlSeconds
        self.spec = spec
    }

    public func validate() throws {
        try nonempty(operationID, name: "operationID")
        try nonempty(runtimeInstanceID, name: "runtimeInstanceID")
        guard (TKHighlightLimits.default.minTTLSeconds...TKHighlightLimits.default.maxTTLSeconds).contains(ttlSeconds) else {
            throw validation("Highlight ttlSeconds must be in 1–300.")
        }
        try spec.validate()
    }

    public func canonicalData() throws -> Data {
        var normalized = self
        normalized.spec.color = spec.color.uppercased()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(normalized)
    }
}

public struct TKHighlightStatusRequest: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var operationID: String?
    public var runtimeInstanceID: String?

    public init(sessionID: String? = nil, operationID: String? = nil, runtimeInstanceID: String? = nil) {
        self.sessionID = sessionID
        self.operationID = operationID
        self.runtimeInstanceID = runtimeInstanceID
    }

    public func validate() throws {
        guard (sessionID == nil) != (operationID == nil) else { throw validation("Status requires exactly one of sessionID or operationID.") }
        try nonempty(sessionID, name: "sessionID")
        try nonempty(operationID, name: "operationID")
        try nonempty(runtimeInstanceID, name: "runtimeInstanceID")
    }
}

public struct TKHighlightClearRequest: Codable, Equatable, Sendable {
    public var sessionID: String
    /// Empty means all marks belonging to this session, never all sessions.
    public var markIDs: [String]
    public var runtimeInstanceID: String?

    public init(sessionID: String, markIDs: [String] = [], runtimeInstanceID: String? = nil) {
        self.sessionID = sessionID
        self.markIDs = markIDs
        self.runtimeInstanceID = runtimeInstanceID
    }

    public func validate() throws {
        try nonempty(sessionID, name: "sessionID")
        try nonempty(runtimeInstanceID, name: "runtimeInstanceID")
        guard markIDs.count <= TKHighlightLimits.default.maxNodes, Set(markIDs).count == markIDs.count else {
            throw validation("Clear markIDs must be unique and contain at most 10 values.")
        }
        for id in markIDs { try nonempty(id, name: "markID") }
    }
}

public struct TKHighlightCapabilitiesRequest: Codable, Equatable, Sendable {
    public var runtimeInstanceID: String?
    public init(runtimeInstanceID: String? = nil) { self.runtimeInstanceID = runtimeInstanceID }
    public func validate() throws { try nonempty(runtimeInstanceID, name: "runtimeInstanceID") }
}

public struct TKHighlightLimits: Codable, Equatable, Sendable {
    public var maxNodes: Int
    public var maxActiveSessions: Int
    public var minTTLSeconds: Int
    public var maxTTLSeconds: Int
    public var defaultTTLSeconds: Int
    public var maxOperationKeys: Int
    public var maxTerminalReceipts: Int
    public static let `default` = TKHighlightLimits()

    public init(maxNodes: Int = 10, maxActiveSessions: Int = 1, minTTLSeconds: Int = 1, maxTTLSeconds: Int = 300, defaultTTLSeconds: Int = 30, maxOperationKeys: Int = 1024, maxTerminalReceipts: Int = 128) {
        self.maxNodes = maxNodes
        self.maxActiveSessions = maxActiveSessions
        self.minTTLSeconds = minTTLSeconds
        self.maxTTLSeconds = maxTTLSeconds
        self.defaultTTLSeconds = defaultTTLSeconds
        self.maxOperationKeys = maxOperationKeys
        self.maxTerminalReceipts = maxTerminalReceipts
    }
}

public struct TKHighlightCapability: Codable, Equatable, Sendable {
    public var supported: Bool
    public var reason: String?
    public var provider: String?
    public var presets: [String]
    public var restorationModes: [TKHighlightRestorationMode]
    public var nodeKinds: [String]
    public var limits: TKHighlightLimits
    /// A render opportunity is not proof that a visible frame was presented.
    public var renderObservation: String

    public init(supported: Bool, reason: String? = nil, provider: String? = nil, presets: [String] = [], restorationModes: [TKHighlightRestorationMode] = [], nodeKinds: [String] = [], limits: TKHighlightLimits = .default, renderObservation: String = "not_observed") {
        self.supported = supported
        self.reason = reason
        self.provider = provider
        self.presets = presets
        self.restorationModes = restorationModes
        self.nodeKinds = nodeKinds
        self.limits = limits
        self.renderObservation = renderObservation
    }

    public static func unsupported(reason: String) -> Self { Self(supported: false, reason: reason) }
}

public struct TKHighlightCapabilitiesResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var runtimeInstanceID: String
    public var capability: TKHighlightCapability
    public var error: TKHighlightError?

    public init(ok: Bool = true, runtimeInstanceID: String, capability: TKHighlightCapability, error: TKHighlightError? = nil) {
        self.ok = ok
        self.runtimeInstanceID = runtimeInstanceID
        self.capability = capability
        self.error = error
    }
}

public struct TKHighlightMarkReceipt: Codable, Equatable, Sendable {
    public var markID: String
    public var canonicalMarkID: String?
    public var label: String?
    public var targetOID: UInt?
    public var provider: String?
    public var objectToken: String?
    public var contentEpoch: String?
    public var outcome: TKHighlightMarkOutcome
    public var group: String
    public var changedKeys: [String]
    public var guardKeys: [String]
    public var restoreWritten: Bool
    public var restorationMode: TKHighlightRestorationMode
    public var restoredTo: TKHighlightRestoredTo
    public var baselineVersionAtApply: String?
    public var baselineVersionCurrent: String?
    public var reason: String?
    public var error: TKHighlightError?

    public init(markID: String, canonicalMarkID: String? = nil, label: String? = nil, targetOID: UInt? = nil, provider: String? = nil, objectToken: String? = nil, contentEpoch: String? = nil, outcome: TKHighlightMarkOutcome, group: String = "border", changedKeys: [String] = [], guardKeys: [String] = [], restoreWritten: Bool = false, restorationMode: TKHighlightRestorationMode = .snapshotCompareRestore, restoredTo: TKHighlightRestoredTo = .none, baselineVersionAtApply: String? = nil, baselineVersionCurrent: String? = nil, reason: String? = nil, error: TKHighlightError? = nil) {
        self.markID = markID
        self.canonicalMarkID = canonicalMarkID
        self.label = label
        self.targetOID = targetOID
        self.provider = provider
        self.objectToken = objectToken
        self.contentEpoch = contentEpoch
        self.outcome = outcome
        self.group = group
        self.changedKeys = changedKeys
        self.guardKeys = guardKeys
        self.restoreWritten = restoreWritten
        self.restorationMode = restorationMode
        self.restoredTo = restoredTo
        self.baselineVersionAtApply = baselineVersionAtApply
        self.baselineVersionCurrent = baselineVersionCurrent
        self.reason = reason
        self.error = error
    }
}

public struct TKHighlightReceipt: Codable, Equatable, Sendable {
    public var ok: Bool
    public var runtimeInstanceID: String
    public var operationID: String?
    public var sessionID: String?
    public var state: TKHighlightSessionState?
    public var marks: [TKHighlightMarkReceipt]
    public var requestedMarkIDs: [String]
    public var markAliases: [String: String]
    public var cleanupComplete: Bool
    public var restorationVerified: Bool
    public var residualState: TKHighlightResidualState
    public var ownershipAssurance: TKHighlightOwnershipAssurance
    public var restorationMode: TKHighlightRestorationMode
    public var renderObservation: String
    public var expiresAt: String?
    public var remainingMs: Int?
    public var reason: String?
    public var error: TKHighlightError?
    public var errors: [TKHighlightError]

    public init(ok: Bool, runtimeInstanceID: String, operationID: String? = nil, sessionID: String? = nil, state: TKHighlightSessionState? = nil, marks: [TKHighlightMarkReceipt] = [], requestedMarkIDs: [String] = [], markAliases: [String: String] = [:], cleanupComplete: Bool = false, restorationVerified: Bool = false, residualState: TKHighlightResidualState = .none, ownershipAssurance: TKHighlightOwnershipAssurance = .valueGuarded, restorationMode: TKHighlightRestorationMode = .snapshotCompareRestore, renderObservation: String = "not_observed", expiresAt: String? = nil, remainingMs: Int? = nil, reason: String? = nil, error: TKHighlightError? = nil, errors: [TKHighlightError] = []) {
        self.ok = ok
        self.runtimeInstanceID = runtimeInstanceID
        self.operationID = operationID
        self.sessionID = sessionID
        self.state = state
        self.marks = marks
        self.requestedMarkIDs = requestedMarkIDs
        self.markAliases = markAliases
        self.cleanupComplete = cleanupComplete
        self.restorationVerified = restorationVerified
        self.residualState = residualState
        self.ownershipAssurance = ownershipAssurance
        self.restorationMode = restorationMode
        self.renderObservation = renderObservation
        self.expiresAt = expiresAt
        self.remainingMs = remainingMs
        self.reason = reason
        self.error = error
        self.errors = errors
    }
}

private func validation(_ message: String) -> TKHighlightError {
    TKHighlightError(code: "validation_failed", message: message)
}

private func nonempty(_ value: String?, name: String) throws {
    guard let value else { return }
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw validation("\(name) must not be empty.")
    }
}

// Input decoding supplies documented defaults and refuses misspelled targeting/style fields.
extension TKHighlightSelector {
    private enum CodingKeys: String, CodingKey, CaseIterable { case oid, identifier, text, role, withinOID }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(oid: try c.decodeIfPresent(UInt.self, forKey: .oid), identifier: try c.decodeIfPresent(String.self, forKey: .identifier), text: try c.decodeIfPresent(String.self, forKey: .text), role: try c.decodeIfPresent(String.self, forKey: .role), withinOID: try c.decodeIfPresent(UInt.self, forKey: .withinOID))
        try validate()
    }
}

extension TKHighlightItem {
    private enum CodingKeys: String, CodingKey, CaseIterable { case markID, label, selector }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(markID: try c.decode(String.self, forKey: .markID), label: try c.decodeIfPresent(String.self, forKey: .label), selector: try c.decode(TKHighlightSelector.self, forKey: .selector))
        try validate()
    }
}

extension TKHighlightSpec {
    private enum CodingKeys: String, CodingKey, CaseIterable { case schemaVersion, preset, color, width, items }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(schemaVersion: try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1, preset: try c.decodeIfPresent(String.self, forKey: .preset) ?? "outline", color: try c.decodeIfPresent(String.self, forKey: .color) ?? "#FF453A", width: try c.decodeIfPresent(Double.self, forKey: .width) ?? 3, items: try c.decode([TKHighlightItem].self, forKey: .items))
        try validate()
    }
}

extension TKHighlightApplyRequest {
    private enum CodingKeys: String, CodingKey, CaseIterable { case operationID, runtimeInstanceID, ttlSeconds, spec }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(operationID: try c.decode(String.self, forKey: .operationID), runtimeInstanceID: try c.decodeIfPresent(String.self, forKey: .runtimeInstanceID), ttlSeconds: try c.decodeIfPresent(Int.self, forKey: .ttlSeconds) ?? 30, spec: try c.decode(TKHighlightSpec.self, forKey: .spec))
        try validate()
    }
}

extension TKHighlightStatusRequest {
    private enum CodingKeys: String, CodingKey, CaseIterable { case sessionID, operationID, runtimeInstanceID }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(sessionID: try c.decodeIfPresent(String.self, forKey: .sessionID), operationID: try c.decodeIfPresent(String.self, forKey: .operationID), runtimeInstanceID: try c.decodeIfPresent(String.self, forKey: .runtimeInstanceID))
        try validate()
    }
}

extension TKHighlightClearRequest {
    private enum CodingKeys: String, CodingKey, CaseIterable { case sessionID, markIDs, runtimeInstanceID }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(sessionID: try c.decode(String.self, forKey: .sessionID), markIDs: try c.decodeIfPresent([String].self, forKey: .markIDs) ?? [], runtimeInstanceID: try c.decodeIfPresent(String.self, forKey: .runtimeInstanceID))
        try validate()
    }
}

extension TKHighlightCapabilitiesRequest {
    private enum CodingKeys: String, CodingKey, CaseIterable { case runtimeInstanceID }
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(runtimeInstanceID: try c.decodeIfPresent(String.self, forKey: .runtimeInstanceID))
        try validate()
    }
}

// Receipts tolerate added evidence fields across versions; omitted evidence never means success.
extension TKHighlightMarkReceipt {
    private enum CodingKeys: String, CodingKey {
        case markID, canonicalMarkID, label, targetOID, provider, objectToken, contentEpoch, outcome, group
        case changedKeys, guardKeys, restoreWritten, restorationMode, restoredTo
        case baselineVersionAtApply, baselineVersionCurrent, reason, error
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            markID: try c.decode(String.self, forKey: .markID),
            canonicalMarkID: try c.decodeIfPresent(String.self, forKey: .canonicalMarkID),
            label: try c.decodeIfPresent(String.self, forKey: .label),
            targetOID: try c.decodeIfPresent(UInt.self, forKey: .targetOID),
            provider: try c.decodeIfPresent(String.self, forKey: .provider),
            objectToken: try c.decodeIfPresent(String.self, forKey: .objectToken),
            contentEpoch: try c.decodeIfPresent(String.self, forKey: .contentEpoch),
            outcome: try c.decode(TKHighlightMarkOutcome.self, forKey: .outcome),
            group: try c.decodeIfPresent(String.self, forKey: .group) ?? "border",
            changedKeys: try c.decodeIfPresent([String].self, forKey: .changedKeys) ?? [],
            guardKeys: try c.decodeIfPresent([String].self, forKey: .guardKeys) ?? [],
            restoreWritten: try c.decodeIfPresent(Bool.self, forKey: .restoreWritten) ?? false,
            restorationMode: try c.decodeIfPresent(TKHighlightRestorationMode.self, forKey: .restorationMode) ?? .snapshotCompareRestore,
            restoredTo: try c.decodeIfPresent(TKHighlightRestoredTo.self, forKey: .restoredTo) ?? .none,
            baselineVersionAtApply: try c.decodeIfPresent(String.self, forKey: .baselineVersionAtApply),
            baselineVersionCurrent: try c.decodeIfPresent(String.self, forKey: .baselineVersionCurrent),
            reason: try c.decodeIfPresent(String.self, forKey: .reason),
            error: try c.decodeIfPresent(TKHighlightError.self, forKey: .error)
        )
    }
}

extension TKHighlightReceipt {
    private enum CodingKeys: String, CodingKey {
        case ok, runtimeInstanceID, operationID, sessionID, state, marks, requestedMarkIDs, markAliases
        case cleanupComplete, restorationVerified, residualState, ownershipAssurance, restorationMode
        case renderObservation, expiresAt, remainingMs, reason, error, errors
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ok: try c.decode(Bool.self, forKey: .ok),
            runtimeInstanceID: try c.decode(String.self, forKey: .runtimeInstanceID),
            operationID: try c.decodeIfPresent(String.self, forKey: .operationID),
            sessionID: try c.decodeIfPresent(String.self, forKey: .sessionID),
            state: try c.decodeIfPresent(TKHighlightSessionState.self, forKey: .state),
            marks: try c.decodeIfPresent([TKHighlightMarkReceipt].self, forKey: .marks) ?? [],
            requestedMarkIDs: try c.decodeIfPresent([String].self, forKey: .requestedMarkIDs) ?? [],
            markAliases: try c.decodeIfPresent([String: String].self, forKey: .markAliases) ?? [:],
            cleanupComplete: try c.decodeIfPresent(Bool.self, forKey: .cleanupComplete) ?? false,
            restorationVerified: try c.decodeIfPresent(Bool.self, forKey: .restorationVerified) ?? false,
            residualState: try c.decodeIfPresent(TKHighlightResidualState.self, forKey: .residualState) ?? .unknown,
            ownershipAssurance: try c.decodeIfPresent(TKHighlightOwnershipAssurance.self, forKey: .ownershipAssurance) ?? .valueGuarded,
            restorationMode: try c.decodeIfPresent(TKHighlightRestorationMode.self, forKey: .restorationMode) ?? .snapshotCompareRestore,
            renderObservation: try c.decodeIfPresent(String.self, forKey: .renderObservation) ?? "not_observed",
            expiresAt: try c.decodeIfPresent(String.self, forKey: .expiresAt),
            remainingMs: try c.decodeIfPresent(Int.self, forKey: .remainingMs),
            reason: try c.decodeIfPresent(String.self, forKey: .reason),
            error: try c.decodeIfPresent(TKHighlightError.self, forKey: .error),
            errors: try c.decodeIfPresent([TKHighlightError].self, forKey: .errors) ?? []
        )
    }
}

private struct HighlightAnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private func rejectUnknownKeys(_ decoder: Decoder, allowed: [String]) throws {
    let container = try decoder.container(keyedBy: HighlightAnyKey.self)
    let unknown = container.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
    guard unknown.isEmpty else { throw validation("Unknown highlight field(s): \(unknown.joined(separator: ", ")).") }
}
