#if canImport(UIKit)
import UIKit
import Darwin
import CryptoKit
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

/// App-owned state, deliberately independent from any connection or request handler lifetime.
@MainActor
final class TKHighlightSessionManager {
    private final class Mark {
        let target: TKUIKitHighlightProvider.Target
        let original: TKUIKitHighlightProvider.Border
        var applied: TKUIKitHighlightProvider.Border
        var receipt: TKHighlightMarkReceipt
        let intendedKeys: [String]
        var ownershipLost = false
        init(target: TKUIKitHighlightProvider.Target, original: TKUIKitHighlightProvider.Border, applied: TKUIKitHighlightProvider.Border, receipt: TKHighlightMarkReceipt) {
            self.target = target; self.original = original; self.applied = applied; self.receipt = receipt
            intendedKeys = receipt.changedKeys
            self.receipt.changedKeys = []
        }
        var terminal: Bool { [.restored, .alreadyOriginal, .targetGone, .resolvedExternally, .noChange].contains(receipt.outcome) }
    }
    private final class Session {
        let id = UUID().uuidString
        let operationID: String
        let deadline: TimeInterval
        let expiresAt: String
        let marks: [Mark]
        let aliases: [String: String]
        var rendering = true
        var renderObservation = "not_observed"
        var applySucceeded = false
        var applyError: TKHighlightError?
        var reason: String?
        init(operationID: String, deadline: TimeInterval, ttl: Int, marks: [Mark], aliases: [String: String]) {
            self.operationID = operationID; self.deadline = deadline; self.marks = marks; self.aliases = aliases
            expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(ttl)))
        }
        var closed: Bool { marks.allSatisfy(\.terminal) }
    }
    private struct Operation { let payload: Data; let sessionID: String }
    let runtimeInstanceID: String
    private let provider: TKUIKitHighlightProvider
    private let now: () -> TimeInterval
    private let renderOpportunity: (@MainActor () async -> Void)?
    private let operationCapacity: Int
    private let receiptCapacity: Int
    private var operations: [String: Operation] = [:]
    private var sessions: [String: Session] = [:]
    private var terminalOrder: [String] = []
    private var activeID: String?
    private var timer: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?

    init(runtimeInstanceID: String = UUID().uuidString, provider: TKUIKitHighlightProvider? = nil, now: @escaping () -> TimeInterval = TKHighlightSessionManager.continuousSeconds, operationCapacity: Int = 1024, receiptCapacity: Int = 128, renderOpportunity: (@MainActor () async -> Void)? = nil) {
        self.runtimeInstanceID = runtimeInstanceID; self.provider = provider ?? TKUIKitHighlightProvider(); self.now = now
        self.renderOpportunity = renderOpportunity
        self.operationCapacity = max(1, operationCapacity); self.receiptCapacity = max(1, receiptCapacity)
        activationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.expireIfNeeded() }
        }
    }
    deinit { timer?.cancel(); if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) } }

    func capabilities(_ request: TKHighlightCapabilitiesRequest = TKHighlightCapabilitiesRequest()) -> TKHighlightCapabilitiesResponse {
        do { try request.validate(); try checkRuntime(request.runtimeInstanceID) }
        catch { return TKHighlightCapabilitiesResponse(ok: false, runtimeInstanceID: runtimeInstanceID, capability: .unsupported(reason: "stale_or_invalid_request"), error: asError(error)) }
        return TKHighlightCapabilitiesResponse(runtimeInstanceID: runtimeInstanceID, capability: TKHighlightCapability(supported: true, reason: "Optional UIKit provider; OID/scoped identifier selectors, visible ordinary views/layers only. Reusable cell subtrees require an epoch provider and are unsupported here.", provider: "ios_uikit", presets: ["outline"], restorationModes: [.snapshotCompareRestore], nodeKinds: ["UIView", "CALayer"], limits: TKHighlightLimits(maxOperationKeys: operationCapacity, maxTerminalReceipts: receiptCapacity), renderObservation: "main_queue_opportunity"))
    }

    func apply(_ request: TKHighlightApplyRequest) async -> TKHighlightReceipt {
        do {
            try request.validate(); try checkRuntime(request.runtimeInstanceID)
            var canonical = request
            canonical.runtimeInstanceID = runtimeInstanceID
            let canonicalPayload = try canonical.canonicalData()
            guard canonicalPayload.count <= 65_536 else { return failure("validation_failed", "The canonical highlight request exceeds the 64 KiB budget.", operationID: request.operationID) }
            let payload = Data(SHA256.hash(data: canonicalPayload))
            expireIfNeeded()
            if let prior = operations[request.operationID] {
                guard prior.payload == payload else { return failure("highlight_operation_conflict", "This operationID was already used with a different payload.", operationID: request.operationID) }
                guard let session = sessions[prior.sessionID] else { return failure("highlight_receipt_expired", "The operation remains consumed but its terminal receipt has expired.", operationID: request.operationID) }
                while session.rendering { await queueOpportunity() }
                observe(session)
                var replay = receipt(session, ok: session.applySucceeded)
                if let error = session.applyError { replay.error = error; replay.errors.append(error) }
                return replay
            }
            guard operations.count < operationCapacity else { return failure("highlight_capacity_exceeded", "The runtime operation deduplication budget is exhausted; existing keys are never evicted.", operationID: request.operationID) }
            guard activeID == nil else { return failure("highlight_busy", "An active or unresolved highlight session must be cleared first.", operationID: request.operationID) }
            let color = try provider.color(request.spec.color)
            let width = CGFloat(request.spec.width)
            var targets: [(TKHighlightItem, TKUIKitHighlightProvider.Target)] = []
            var aliases: [String: String] = [:]
            var layers: [ObjectIdentifier: String] = [:]
            // Entire batch preflight runs before any setter.
            for item in request.spec.items {
                let target = try provider.resolve(item.selector)
                guard let layer = target.layer else { throw provider.failure("highlight_target_not_found", "The layer was released during resolution.") }
                let identity = ObjectIdentifier(layer)
                if let canonicalMark = layers[identity] { aliases[item.markID] = canonicalMark }
                else { layers[identity] = item.markID; targets.append((item, target)) }
            }
            var marks: [Mark] = []
            for (item, target) in targets {
                guard target.identityValid, let layer = target.layer else { throw provider.failure("highlight_identity_changed", "The target context changed during preflight.") }
                let original = TKUIKitHighlightProvider.Border(layer)
                guard original.width.isFinite else { throw provider.failure("highlight_identity_unverifiable", "The original border width is non-finite.") }
                var keys: [String] = []
                if !TKUIKitHighlightProvider.Border.same(original.color, color) { keys.append("borderColor") }
                if original.width != width { keys.append("borderWidth") }
                let mark = TKHighlightMarkReceipt(markID: item.markID, label: item.label, targetOID: target.oid, provider: "ios_uikit", objectToken: target.token, outcome: keys.isEmpty ? .noChange : .applied, changedKeys: keys, guardKeys: ["borderColor", "borderWidth"])
                marks.append(Mark(target: target, original: original, applied: original, receipt: mark))
            }
            let session = Session(operationID: request.operationID, deadline: now() + TimeInterval(request.ttlSeconds), ttl: request.ttlSeconds, marks: marks, aliases: aliases)
            sessions[session.id] = session
            operations[request.operationID] = Operation(payload: payload, sessionID: session.id)
            activeID = session.closed ? nil : session.id
            var applyError: TKHighlightError?
            // No suspension or transport call between saving originals and applying all groups.
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for mark in marks where mark.receipt.outcome == .applied {
                guard let layer = mark.target.layer, mark.target.identityValid, mark.original.matches(layer) else {
                    applyError = provider.failure("highlight_identity_changed", "A target changed before its write."); break
                }
                if mark.intendedKeys.contains("borderColor") {
                    mark.receipt.changedKeys.append("borderColor")
                    mark.applied = .init(color: color, width: mark.original.width)
                    layer.borderColor = color
                    guard mark.target.identityValid, mark.applied.matches(layer) else {
                        if mark.original.matches(layer) { mark.applied = mark.original; mark.receipt.changedKeys.removeAll { $0 == "borderColor" } }
                        applyError = provider.failure("highlight_restore_failed", "The border color setter was not accepted or reentered business code."); break
                    }
                }
                if mark.intendedKeys.contains("borderWidth") {
                    mark.receipt.changedKeys.append("borderWidth")
                    mark.applied = .init(color: color, width: width)
                    layer.borderWidth = width
                    guard mark.target.identityValid, mark.applied.matches(layer) else {
                        let preceding = TKUIKitHighlightProvider.Border(color: color, width: mark.original.width)
                        if preceding.matches(layer) { mark.applied = preceding; mark.receipt.changedKeys.removeAll { $0 == "borderWidth" } }
                        applyError = provider.failure("highlight_restore_failed", "The border width setter was not accepted or reentered business code."); break
                    }
                }
                mark.applied = TKUIKitHighlightProvider.Border(layer)
            }
            CATransaction.commit()
            if let applyError {
                session.rendering = false; session.reason = "apply_failed"; session.applyError = applyError
                restore(session, ids: nil)
                var result = receipt(session, ok: false); result.error = applyError; result.errors.append(applyError)
                return result
            }
            if session.closed {
                session.rendering = false; session.reason = "no_change"; session.applySucceeded = true; retainTerminal(session)
                return receipt(session, ok: true)
            }
            scheduleExpiry(session, ttl: request.ttlSeconds)
            // A main queue turn is an opportunity, never a frame-presented or visibility assertion.
            await queueOpportunity()
            session.rendering = false; session.renderObservation = "main_queue_opportunity"
            expireIfNeeded()
            observe(session)
            let modifiedMarkInterrupted = session.marks.contains { !$0.receipt.changedKeys.isEmpty && $0.receipt.outcome != .applied }
            if modifiedMarkInterrupted || session.marks.contains(where: { !$0.terminal && $0.receipt.outcome != .applied }) || now() >= session.deadline || session.closed {
                session.reason = "apply_invalidated"
                restore(session, ids: nil)
                var result = receipt(session, ok: false)
                if result.error == nil { result.error = provider.failure("highlight_render_timeout", "The session expired or changed before the render opportunity.") }
                session.applyError = result.error
                return result
            }
            session.applySucceeded = true
            return receipt(session, ok: true)
        } catch { return failure(asError(error), operationID: request.operationID) }
    }

    func status(_ request: TKHighlightStatusRequest) -> TKHighlightReceipt {
        do {
            try request.validate(); try checkRuntime(request.runtimeInstanceID); expireIfNeeded()
            let id = request.sessionID ?? request.operationID.flatMap { operations[$0]?.sessionID }
            guard let id else { return failure("highlight_target_not_found", "The operation is unknown in this runtime.", operationID: request.operationID) }
            guard let session = sessions[id] else { return failure("highlight_receipt_expired", "The terminal session receipt is no longer retained.", operationID: request.operationID, sessionID: id) }
            observe(session)
            return receipt(session, ok: true)
        } catch { return failure(asError(error), operationID: request.operationID, sessionID: request.sessionID) }
    }
    func clear(_ request: TKHighlightClearRequest) -> TKHighlightReceipt {
        do {
            try request.validate(); try checkRuntime(request.runtimeInstanceID)
            guard let session = sessions[request.sessionID] else { return failure("highlight_receipt_expired", "The session is not retained in this runtime.", sessionID: request.sessionID) }
            let known = Set(session.marks.map { $0.receipt.markID }).union(session.aliases.keys)
            guard request.markIDs.allSatisfy(known.contains) else { return failure("validation_failed", "The clear scope contains unknown markIDs; no properties were written.", sessionID: request.sessionID) }
            if now() >= session.deadline { session.reason = "expired" }
            let ids = request.markIDs.isEmpty ? nil : Set(request.markIDs.map { session.aliases[$0] ?? $0 })
            restore(session, ids: ids)
            let selected = session.marks.filter { ids == nil || ids!.contains($0.receipt.markID) }
            var result = receipt(session, ok: selected.allSatisfy { [.restored, .alreadyOriginal, .noChange].contains($0.receipt.outcome) })
            result.requestedMarkIDs = request.markIDs
            return result
        } catch { return failure(asError(error), sessionID: request.sessionID) }
    }
    /// Called before runtime teardown. Failed records remain owned by this manager for inspection.
    func shutdown() -> TKHighlightReceipt? {
        guard let activeID, let session = sessions[activeID] else { return nil }
        session.reason = "runtime_stop"
        restore(session, ids: nil)
        return receipt(session, ok: session.marks.allSatisfy { [.restored, .alreadyOriginal, .noChange].contains($0.receipt.outcome) })
    }
    /// Used by patch/navigation integration before any known overlapping business mutation.
    func ownsBorder(of object: AnyObject) -> Bool {
        guard let activeID, let session = sessions[activeID] else { return false }
        guard let layer = (object as? UIView)?.layer ?? object as? CALayer else { return false }
        return session.marks.contains { !$0.terminal && $0.target.layer === layer }
    }

    private func observe(_ session: Session) {
        for mark in session.marks where !mark.terminal {
            guard let layer = mark.target.layer else { mark.receipt.outcome = .targetGone; mark.receipt.error = nil; mark.receipt.reason = "The original layer has been released; no replacement was located or restored."; continue }
            guard mark.target.identityValid else { mark.ownershipLost = true; mark.receipt.outcome = .identityChanged; mark.receipt.error = provider.failure("highlight_identity_changed", "The original view/window/layer binding is no longer valid; no original properties were written."); continue }
            if hasBorderAnimation(layer) { mark.ownershipLost = true; mark.receipt.outcome = .conflict; mark.receipt.error = provider.failure("highlight_restore_conflict", "A border animation now owns the visual group; current values and animations were preserved."); continue }
            if mark.original.matches(layer) { mark.receipt.outcome = .alreadyOriginal; mark.receipt.restoredTo = .alreadyOriginal; mark.receipt.error = nil; continue }
            if mark.ownershipLost {
                _ = resolveExternal(mark, layer: layer)
                continue
            }
            if !mark.applied.matches(layer) { mark.ownershipLost = true; mark.receipt.outcome = .conflict; mark.receipt.error = provider.failure("highlight_restore_conflict", "Business code changed the border group; the current group was preserved.") }
        }
        if session.closed { retainTerminal(session) }
    }
    private func restore(_ session: Session, ids: Set<String>?) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for mark in session.marks.reversed() where ids == nil || ids!.contains(mark.receipt.markID) {
            guard !mark.terminal else { continue }
            if mark.receipt.changedKeys.isEmpty {
                mark.receipt.outcome = .noChange
                mark.receipt.reason = "This mark performed no accepted property write; business values were preserved without rollback."
                mark.receipt.error = nil
                continue
            }
            guard let layer = mark.target.layer else { mark.receipt.outcome = .targetGone; mark.receipt.error = nil; mark.receipt.reason = "The original layer has been released; no replacement was located or restored."; continue }
            guard mark.target.identityValid else { mark.ownershipLost = true; mark.receipt.outcome = .identityChanged; mark.receipt.error = provider.failure("highlight_identity_changed", "The original view/window/layer binding is no longer valid; no original properties were written."); continue }
            if hasBorderAnimation(layer) { mark.ownershipLost = true; mark.receipt.outcome = .conflict; mark.receipt.error = provider.failure("highlight_restore_conflict", "A border animation now owns the visual group; current values and animations were preserved."); continue }
            if mark.original.matches(layer) { mark.receipt.outcome = .alreadyOriginal; mark.receipt.restoredTo = .alreadyOriginal; mark.receipt.error = nil; continue }
            if mark.ownershipLost, resolveExternal(mark, layer: layer) { continue }
            guard !mark.ownershipLost, mark.applied.matches(layer) else {
                mark.ownershipLost = true; mark.receipt.outcome = .conflict
                mark.receipt.error = provider.failure("highlight_restore_conflict", "Business code changed the border group; no field in this group was restored.")
                continue
            }
            // Whole-group guards passed; write only keys this mark actually changed.
            var intermediate = mark.applied
            if mark.receipt.changedKeys.contains("borderColor") {
                layer.borderColor = mark.original.color
                mark.receipt.restoreWritten = true
                intermediate = .init(color: mark.original.color, width: intermediate.width)
                guard mark.target.identityValid, intermediate.matches(layer) else {
                    mark.ownershipLost = true; mark.receipt.outcome = .restoreFailed
                    mark.receipt.error = provider.failure("highlight_restore_failed", "Restore color readback or identity failed; width was preserved."); continue
                }
            }
            if mark.receipt.changedKeys.contains("borderWidth") { layer.borderWidth = mark.original.width; mark.receipt.restoreWritten = true }
            if mark.target.identityValid, mark.original.matches(layer) {
                mark.receipt.outcome = .restored; mark.receipt.restoredTo = .original; mark.receipt.error = nil
            } else {
                mark.ownershipLost = true; mark.receipt.outcome = .restoreFailed
                mark.receipt.error = provider.failure("highlight_restore_failed", "The original border group could not be verified after restoration.")
            }
        }
        CATransaction.commit()
        if session.closed { retainTerminal(session) }
    }
    private func hasBorderAnimation(_ layer: CALayer) -> Bool {
        (layer.animationKeys() ?? []).contains { TKUIKitHighlightProvider.borderAnimation(layer.animation(forKey: $0)) }
    }
    private func resolveExternal(_ mark: Mark, layer: CALayer) -> Bool {
        guard !mark.receipt.changedKeys.isEmpty, mark.receipt.changedKeys.allSatisfy({ key in
            key == "borderColor" ? !TKUIKitHighlightProvider.Border.same(mark.applied.color, layer.borderColor) : mark.applied.width != layer.borderWidth
        }) else { return false }
        mark.receipt.outcome = .resolvedExternally
        mark.receipt.reason = "Business code replaced all applied fields; original restoration was not performed."
        mark.receipt.error = nil
        return true
    }
    private func receipt(_ session: Session, ok: Bool) -> TKHighlightReceipt {
        let marks = session.marks.map(\.receipt)
        let active = marks.filter { $0.outcome == .applied }.count
        let unsafe = marks.contains { [.conflict, .identityChanged, .restorePending, .restoreFailed, .failed].contains($0.outcome) }
        let deadlinePending = active > 0 && now() >= session.deadline
        let state: TKHighlightSessionState = unsafe ? .needsAttention : session.closed ? .closed : deadlinePending ? .restoring : active == marks.count ? .active : .partiallyActive
        let verified = session.closed && marks.allSatisfy { [.restored, .alreadyOriginal, .noChange].contains($0.outcome) }
        var errors = marks.compactMap(\.error)
        if !ok, errors.isEmpty, marks.contains(where: { $0.outcome == .targetGone }) { errors.append(provider.failure("highlight_target_not_found", "The original target was released; cleanup is complete but restoration was not verified.")) }
        return TKHighlightReceipt(ok: ok, runtimeInstanceID: runtimeInstanceID, operationID: session.operationID, sessionID: session.id, state: state, marks: marks, markAliases: session.aliases, cleanupComplete: session.closed, restorationVerified: verified, residualState: unsafe ? .possible : deadlinePending ? .unknown : .none, renderObservation: session.renderObservation, expiresAt: session.expiresAt, remainingMs: max(0, Int((session.deadline - now()) * 1000)), reason: session.reason, error: ok ? nil : errors.first, errors: errors)
    }
    private func retainTerminal(_ session: Session) {
        if activeID == session.id { activeID = nil; timer?.cancel(); timer = nil }
        if !terminalOrder.contains(session.id) { terminalOrder.append(session.id) }
        while terminalOrder.count > receiptCapacity { sessions.removeValue(forKey: terminalOrder.removeFirst()) }
    }
    private func expireIfNeeded() {
        guard let activeID, let session = sessions[activeID], now() >= session.deadline else { return }
        session.reason = "expired"; restore(session, ids: nil)
    }
    private func scheduleExpiry(_ session: Session, ttl: Int) {
        timer?.cancel()
        timer = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(ttl) * 1_000_000_000) } catch { return }
            self?.expireIfNeeded()
        }
    }
    private func queueOpportunity() async {
        if let renderOpportunity { await renderOpportunity(); return }
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }
    private func checkRuntime(_ requested: String?) throws {
        if let requested, requested != runtimeInstanceID { throw provider.failure("highlight_stale_runtime", "The requested runtimeInstanceID does not match this runtime; no properties were written.") }
    }
    private func asError(_ error: Error) -> TKHighlightError { error as? TKHighlightError ?? provider.failure("validation_failed", error.localizedDescription) }
    private func failure(_ code: String, _ message: String, operationID: String? = nil, sessionID: String? = nil) -> TKHighlightReceipt { failure(provider.failure(code, message), operationID: operationID, sessionID: sessionID) }
    private func failure(_ error: TKHighlightError, operationID: String? = nil, sessionID: String? = nil) -> TKHighlightReceipt { TKHighlightReceipt(ok: false, runtimeInstanceID: runtimeInstanceID, operationID: operationID, sessionID: sessionID, reason: error.code, error: error, errors: [error]) }
    nonisolated static func continuousSeconds() -> TimeInterval {
        var timebase = mach_timebase_info_data_t(); mach_timebase_info(&timebase)
        return Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }
}
#endif
